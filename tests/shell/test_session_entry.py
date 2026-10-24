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
    def manage(self, action, prefix, *args, ok=True):
        result = subprocess.run([str(SESSION / f'{action}.sh'), '--prefix', str(prefix), *args],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

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
                 patch.object(entry, 'active', return_value=True), \
                 patch.object(entry, 'run') as commands:
                with self.assertRaisesRegex(RuntimeError, 'Otra sesión'):
                    entry.main()
                commands.assert_not_called()

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
                start_index = calls.index(('systemctl', '--user', 'start', 'singlr-workspace.target'))
                self.assertEqual(calls[start_index - 1], ('systemctl', '--user', 'unset-environment',
                                 'DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'XAUTHORITY'))
                self.assertIn(('systemctl', '--user', 'stop', 'singlr-workspace.target',
                               'graphical-session.target'), calls)
                self.assertIn(('systemctl', '--user', 'set-environment', 'DISPLAY=:7'), calls)
                unset = next(call for call in calls if call[:3] == ('systemctl', '--user', 'unset-environment')
                             and 'SINGLR_DEV_ROOT' in call)
                self.assertNotIn('DISPLAY', unset)


if __name__ == '__main__':
    unittest.main()
