"""T211: staging/reversibility and launcher refusal without a real user bus."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / 'session'
loader = importlib.machinery.SourceFileLoader('login_entry', str(SESSION / 'startsinglr-wayland'))
spec = importlib.util.spec_from_loader(loader.name, loader)
entry = importlib.util.module_from_spec(spec)
loader.exec_module(entry)


class SessionEntryTests(unittest.TestCase):
    def setUp(self):
        splash = patch.object(entry, 'splash_enabled', return_value=True)
        splash.start()
        self.addCleanup(splash.stop)
        patcher = patch.object(entry, 'MANAGER_TIMEOUT', 0)
        patcher.start()
        self.addCleanup(patcher.stop)
        patcher = patch.object(entry, 'shutdown_running', return_value=False)
        self.real_shutdown_running = entry.shutdown_running
        self.shutdown_mock = patcher.start()
        self.addCleanup(patcher.stop)
        for name in ('apply', 'restore'):
            patcher = patch.object(entry.singlr_kwin, name)
            patcher.start()
            self.addCleanup(patcher.stop)

    def manage(self, action, prefix, *args, ok=True):
        result = subprocess.run([str(SESSION / f'{action}.sh'), '--prefix', str(prefix), *args],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_kwin_precedes_start_and_restore_follows_stop_even_on_failure(self):
        for fail_restore in (False, True):
            with self.subTest(fail_restore=fail_restore), tempfile.TemporaryDirectory() as tmp:
                binary = Path(tmp) / 'binary'
                binary.touch(mode=0o755)
                (Path(tmp) / 'Shell.qml').touch()
                events = []

                def restore():
                    events.append('restore-kwin')
                    if fail_restore:
                        raise OSError('fixture restore error')

                with patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}, clear=True), \
                     patch('sys.argv', ['startsinglr-wayland']), \
                     patch.object(entry, 'layout', return_value=(binary, Path(tmp))), \
                     patch.object(entry.os, 'geteuid', return_value=1000), \
                     patch.object(entry.signal, 'signal'), \
                     patch.object(entry, 'active', return_value=False), \
                     patch.object(entry, 'manager_environment', return_value={}), \
                     patch.object(entry.singlr_kwin, 'apply', side_effect=lambda **kw: events.append(('apply', kw))), \
                     patch.object(entry.singlr_kwin, 'restore', side_effect=restore), \
                     patch.object(entry, 'run', side_effect=lambda *args, **kw: events.append(args)):
                    if fail_restore:
                        with self.assertRaises(OSError):
                            entry.main()
                    else:
                        self.assertEqual(entry.main(), 0)
                self.assertEqual(events[0], ('apply', {'recover_pending': True}))
                imported = next(event for event in events
                                if isinstance(event, tuple) and event[0] == 'dbus-update-activation-environment')
                self.assertIn('PLASMA_DEFAULT_SHELL=org.singlr.desktop', imported)
                start = events.index(('systemctl', '--user', 'start', 'singlr-workspace.target'))
                self.assertLess(events.index(imported), start)
                cleared = next(event for event in events
                               if isinstance(event, tuple) and event[:3] == ('systemctl', '--user', 'unset-environment')
                               and 'SINGLR_DEV_ROOT' in event)
                self.assertIn('PLASMA_DEFAULT_SHELL', cleared)
                stop = events.index(('systemctl', '--user', 'stop', 'singlr-workspace.target',
                                     'graphical-session.target'))
                self.assertEqual(events[stop + 1], 'restore-kwin')
                self.assertEqual(events[stop + 2][0], 'dbus-update-activation-environment')

    def test_waits_for_shutdown_helper_after_target_stops(self):
        events = []
        with patch.object(entry, 'active', side_effect=[True, False, False]) as target, \
             patch.object(entry, 'shutdown_running', side_effect=[True, False]) as shutdown, \
             patch.object(entry.time, 'sleep', side_effect=lambda _: events.append('waiting')):
            entry.wait_for_session_end(lambda: False)
        self.assertEqual(target.call_count, 3)
        self.assertEqual(shutdown.call_count, 2)
        self.assertEqual(events, ['waiting', 'waiting'])

    def test_cancellation_keeps_target_and_supervisor_alive(self):
        # ksmserver stays alive when an app cancels: BindsTo does not stop target.
        with patch.object(entry, 'active', return_value=True) as target, \
             patch.object(entry, 'shutdown_running') as shutdown, \
             patch.object(entry.time, 'sleep'), \
             patch.object(entry, 'run') as commands:
            remaining = iter([False, False, True])
            entry.wait_for_session_end(lambda: next(remaining))
        self.assertEqual(target.call_count, 2)
        shutdown.assert_not_called()
        commands.assert_not_called()

    def test_shutdown_owner_query_never_activates_service(self):
        with patch.object(entry, 'run', return_value=subprocess.CompletedProcess(
                [], 0, '{"type":"b","data":[true]}')) as command:
            self.assertTrue(self.real_shutdown_running())
        self.assertEqual(command.call_args.args[-3:], ('NameHasOwner', 's', 'org.kde.Shutdown'))

    def test_session_manager_environment_restored(self):
        with patch.object(entry, 'run') as command:
            entry.restore_environment({'SESSION_MANAGER': 'old-ice', 'ICEAUTHORITY': '/old-auth'},
                                      {'SESSION_MANAGER', 'ICEAUTHORITY'})
        self.assertIn('SESSION_MANAGER=old-ice', command.call_args.args)
        self.assertIn('ICEAUTHORITY=/old-auth', command.call_args.args)

    def test_previous_shell_package_environment_restored(self):
        with patch.object(entry, 'run') as command:
            entry.restore_environment({'PLASMA_DEFAULT_SHELL': 'org.kde.plasma.desktop'},
                                      {'PLASMA_DEFAULT_SHELL'})
        self.assertEqual(command.call_args.args, ('systemctl', '--user', 'set-environment',
                                                'PLASMA_DEFAULT_SHELL=org.kde.plasma.desktop'))

    def test_roundtrip_and_dry_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / 'staging with spaces'
            self.manage('install', prefix, '--dry-run')
            self.assertFalse(prefix.exists())
            self.manage('install', prefix)
            desktop = prefix / 'usr/share/wayland-sessions/singlr.desktop'
            before = desktop.read_bytes()
            self.manage('install', prefix, ok=False)
            self.manage('uninstall', prefix, '--dry-run')
            self.assertEqual(desktop.read_bytes(), before)
            foreign = prefix / 'usr/lib/singlr/singlr-shell'
            foreign.write_text('future package payload')
            self.manage('uninstall', prefix)
            self.assertFalse(desktop.exists())
            self.assertTrue(foreign.exists())
            self.manage('uninstall', prefix)

    def test_conflict_and_modified_uninstall_are_atomic(self):
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp)
            desktop = prefix / 'usr/share/wayland-sessions/singlr.desktop'
            desktop.parent.mkdir(parents=True)
            desktop.write_text('foreign')
            self.manage('install', prefix, ok=False)
            self.assertFalse((prefix / 'usr/lib').exists())
            desktop.unlink()
            self.manage('install', prefix)
            desktop.write_text('modified')
            self.manage('uninstall', prefix, ok=False)
            self.assertTrue((prefix / 'usr/lib/systemd/user/singlr-shell.service').exists())

    def test_symlink_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / 'staging'
            prefix.mkdir()
            (prefix / 'usr').symlink_to(Path(tmp) / 'elsewhere', target_is_directory=True)
            self.manage('install', prefix, '--dry-run', ok=False)
            self.assertFalse((Path(tmp) / 'elsewhere').exists())

    def test_launcher_plan_never_contacts_bus(self):
        with patch.dict(os.environ, {'SINGLR_DEV_ROOT': '/tmp/dev with spaces'}), \
             patch('sys.argv', ['startsinglr-wayland', '--dry-run']), \
             patch.object(entry, 'run', side_effect=AssertionError('unexpected bus call')):
            self.assertEqual(entry.main(), 0)

    def test_shell_argv(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / 'shell/session/build/singlr-shell'
            binary.parent.mkdir(parents=True)
            binary.write_text('binary fixture')
            binary.chmod(0o755)
            qml = root / 'shell/qml'
            qml.mkdir()
            (qml / 'Shell.qml').touch()
            with patch.dict(os.environ, {'SINGLR_DEV_ROOT': str(root)}), \
                 patch('sys.argv', ['startsinglr-wayland', '--shell']), \
                 patch.object(entry.os, 'execv', side_effect=SystemExit) as execute:
                with self.assertRaises(SystemExit):
                    entry.main()
                execute.assert_called_once_with(str(binary), [str(binary), str(qml), str(qml / 'Shell.qml')])

    def test_existing_session_refused_before_environment_mutation(self):
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / 'binary'
            binary.touch(mode=0o755)
            (Path(tmp) / 'Shell.qml').touch()
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}, clear=True), \
                 patch('sys.argv', ['startsinglr-wayland']), \
                 patch.object(entry, 'layout', return_value=(binary, Path(tmp))), \
                 patch.object(entry.os, 'geteuid', return_value=1000), \
                 patch.object(entry, 'active', side_effect=lambda unit: unit != 'singlr-workspace.target'), \
                 patch.object(entry, 'run') as commands:
                with self.assertRaisesRegex(RuntimeError, 'Otra sesión'):
                    entry.main()
                commands.assert_not_called()

    def test_orphaned_singlr_graph_is_stopped_before_a_new_login(self):
        # A previous supervisor died without cleanup (e.g. user manager re-exec):
        # under our lock no Singlr login is alive, so its graph is stopped, not refused.
        state = {'singlr-workspace.target': True}

        def command(*args, **kwargs):
            if args[:3] == ('systemctl', '--user', 'stop') and 'singlr-workspace.target' in args:
                state['singlr-workspace.target'] = False

        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / 'binary'
            binary.touch(mode=0o755)
            (Path(tmp) / 'Shell.qml').touch()
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}, clear=True), \
                 patch('sys.argv', ['startsinglr-wayland']), \
                 patch.object(entry, 'layout', return_value=(binary, Path(tmp))), \
                 patch.object(entry.os, 'geteuid', return_value=1000), \
                 patch.object(entry.signal, 'signal'), \
                 patch.object(entry, 'active', side_effect=lambda unit: state.get(unit, False)), \
                 patch.object(entry, 'manager_environment', return_value={}), \
                 patch.object(entry, 'run', side_effect=command) as commands:
                self.assertEqual(entry.main(), 0)
                calls = [item.args for item in commands.call_args_list]
                stale = calls.index(('systemctl', '--user', 'stop', 'singlr-workspace.target', 'graphical-session.target',
                                     'plasma-ksmserver.service', 'plasma-kwin_wayland.service'))
                self.assertLess(stale, calls.index(('systemctl', '--user', 'start', 'singlr-workspace.target')))

    def test_distribution_defaults_precede_system_config(self):
        with patch.dict(os.environ, {'XDG_CONFIG_DIRS': '/etc/xdg:/opt/xdg'}, clear=True):
            self.assertEqual(entry.config_dirs(), '/usr/lib/singlr/xdg:/etc/xdg:/opt/xdg')
        with patch.dict(os.environ, {'SINGLR_DEV_ROOT': '/dev/root'}, clear=True):
            self.assertEqual(entry.config_dirs(), '/dev/root/session/xdg:/etc/xdg')
        self.assertIn('ColorScheme=BreezeDark', (SESSION / 'xdg/kdeglobals').read_text())

    def test_manager_reexec_is_not_the_end_of_the_session(self):
        # systemctl fails while the user manager re-executes; keep waiting until it answers.
        answers = iter([subprocess.CalledProcessError(1, 'systemctl'), subprocess.CalledProcessError(1, 'systemctl'),
                        subprocess.CompletedProcess('systemctl', 0, 'active\n')])

        def command(*args, **kwargs):
            answer = next(answers)
            if isinstance(answer, Exception):
                raise answer
            return answer

        with patch.object(entry, 'MANAGER_TIMEOUT', 5), patch.object(entry.time, 'sleep'), \
             patch.object(entry, 'run', side_effect=command) as commands:
            self.assertTrue(entry.active('singlr-workspace.target'))
            self.assertEqual(commands.call_count, 3)

    def test_failed_start_stops_graph_and_restores_environment(self):
        def command(*args, **kwargs):
            if args[:3] == ('systemctl', '--user', 'start'):
                raise subprocess.CalledProcessError(1, args)

        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / 'binary'
            binary.touch(mode=0o755)
            (Path(tmp) / 'Shell.qml').touch()
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp}, clear=True), \
                 patch('sys.argv', ['startsinglr-wayland']), \
                 patch.object(entry, 'layout', return_value=(binary, Path(tmp))), \
                 patch.object(entry.os, 'geteuid', return_value=1000), \
                 patch.object(entry.signal, 'signal'), \
                 patch.object(entry, 'active', return_value=False), \
                 patch.object(entry, 'manager_environment', return_value={'DISPLAY': ':7'}), \
                 patch.object(entry, 'run', side_effect=command) as commands:
                with self.assertRaises(subprocess.CalledProcessError):
                    entry.main()
                calls = [item.args for item in commands.call_args_list]
                start_index = calls.index(('systemctl', '--user', 'start', 'plasma-kwin_wayland.service'))
                self.assertEqual(calls[start_index - 1], ('systemctl', '--user', 'unset-environment',
                                 'DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'XAUTHORITY', 'SESSION_MANAGER', 'ICEAUTHORITY'))
                self.assertIn(('systemctl', '--user', 'stop', 'singlr-workspace.target',
                               'graphical-session.target'), calls)
                self.assertIn(('systemctl', '--user', 'set-environment', 'DISPLAY=:7'), calls)
                unset = next(call for call in calls if call[:3] == ('systemctl', '--user', 'unset-environment')
                             and 'SINGLR_DEV_ROOT' in call)
                self.assertNotIn('DISPLAY', unset)

    def test_logout_supervisor_cleans_graph_before_terminating_session(self):
        for cleanup_fails in (False, True):
            with self.subTest(cleanup_fails=cleanup_fails), tempfile.TemporaryDirectory() as tmp:
                binary = Path(tmp) / 'binary'
                binary.touch(mode=0o755)
                (Path(tmp) / 'Shell.qml').touch()

                def command(*args, **kwargs):
                    if cleanup_fails and args[:3] == ('systemctl', '--user', 'stop'):
                        raise subprocess.CalledProcessError(1, args)

                with patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp,
                                             'XDG_SESSION_ID': 'test-session'}, clear=True), \
                     patch('sys.argv', ['startsinglr-wayland']), \
                     patch.object(entry, 'layout', return_value=(binary, Path(tmp))), \
                     patch.object(entry.os, 'geteuid', return_value=1000), \
                     patch.object(entry.signal, 'signal'), \
                     patch.object(entry, 'active', return_value=False), \
                     patch.object(entry, 'manager_environment', return_value={'DISPLAY': ':7'}), \
                     patch.object(entry, 'run', side_effect=command) as commands:
                    if cleanup_fails:
                        with self.assertRaises(subprocess.CalledProcessError):
                            entry.main()
                    else:
                        self.assertEqual(entry.main(), 0)
                    calls = [item.args for item in commands.call_args_list]
                    self.assertIn('XDG_SESSION_ID=test-session', calls[0])
                    self.assertIn(('systemctl', '--user', 'stop', 'singlr-workspace.target',
                                   'graphical-session.target'), calls)
                    self.assertEqual(calls[-1], ('loginctl', 'terminate-session', 'test-session'))
                    self.assertEqual(calls[-2], ('systemctl', '--user', 'set-environment', 'DISPLAY=:7'))


if __name__ == '__main__':
    unittest.main()
