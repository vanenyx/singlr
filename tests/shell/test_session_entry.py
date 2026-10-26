"""Installed session dispatch and metadata staging; never contacts the user manager."""
import configparser
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SESSION = ROOT / 'session'


def verify_shell_selection(prefix):
    """Merge the installed drop-in with the real Plasma unit, execute its command
    with recording binaries, and follow the unchanged official Wants chain.
    This checks the executable selected by the graph, not a live login.
    """
    upstream = Path('/usr/lib/systemd/user')
    shell = configparser.ConfigParser(interpolation=None, strict=False)
    original = (upstream / 'plasma-plasmashell.service').read_text()
    shell.read_string(original)
    override = prefix / 'usr/lib/systemd/user/plasma-plasmashell.service.d/50-singlr.conf'
    shell.read_string(override.read_text())
    baseline = configparser.ConfigParser(interpolation=None, strict=False)
    baseline.read_string(original)
    for section in baseline.sections():
        for key, value in baseline[section].items():
            if (section, key) != ('Service', 'execstart'):
                assert shell[section][key] == value, (section, key)
    assert shell['Service']['Type'] == 'dbus'
    assert shell['Service']['BusName'] == 'org.kde.plasmashell'
    assert shell['Service']['Restart'] == 'on-failure'
    assert shell['Unit']['After'] == 'plasma-ksmserver.service'
    assert 'Requires=plasma-workspace.target' in (upstream / 'plasma-workspace-wayland.target').read_text()
    assert 'Requires=plasma-core.target' in (upstream / 'plasma-workspace.target').read_text()
    assert 'Wants=plasma-plasmashell.service' in (upstream / 'plasma-core.target').read_text()
    assert not (prefix / 'usr/lib/systemd/user/singlr-workspace.target').exists()
    assert not (prefix / 'usr/lib/systemd/user/singlr-shell.service').exists()
    command = shlex.split(shell['Service']['ExecStart'])
    dispatcher = prefix / command[0].lstrip('/')
    with tempfile.TemporaryDirectory(prefix='singlr-selection-') as tmp:
        base = Path(tmp)
        recorder = base / 'record'
        recorder.write_text('#!/usr/bin/python3\nimport json,sys\nprint(json.dumps(sys.argv))\n')
        recorder.chmod(0o755)
        # Relocate only the executable paths into the test prefix; no host shell runs.
        plasma = base / 'plasmashell'; plasma.symlink_to(recorder)
        dispatch = base / 'dispatch'
        dispatch.write_text(dispatcher.read_text().replace('/usr/bin/plasmashell', str(plasma)).replace(
            'root=/usr/lib/singlr', 'root=' + shlex.quote(str(prefix / 'usr/lib/singlr'))))
        dispatch.chmod(0o755)
        # A staged real shell must never be executed in this static graph check.
        dispatch.write_text(dispatch.read_text().replace('binary="$root/singlr-shell"',
                                                       'binary=' + shlex.quote(str(base / 'singlr-shell'))))
        (base / 'singlr-shell').symlink_to(recorder)
        for desktop in ('Singlr', 'KDE', ''):
            env = os.environ | {'XDG_SESSION_DESKTOP': desktop}
            env.pop('SINGLR_DEV_ROOT', None)
            result = subprocess.run([str(dispatch)], env=env, text=True, capture_output=True, check=True)
            argv = json.loads(result.stdout)
            if desktop == 'Singlr':
                assert Path(argv[0]).name == 'singlr-shell', argv
                assert argv[1:] == [str(prefix / 'usr/lib/singlr/qml'), str(prefix / 'usr/lib/singlr/qml/Shell.qml')]
            else:
                assert Path(argv[0]).name == 'plasmashell', argv
                assert argv[1:] == ['--no-respawn'], argv


class SessionEntryTests(unittest.TestCase):
    def manage(self, action, prefix, *args, ok=True):
        result = subprocess.run([str(SESSION / f'{action}.sh'), '--prefix', str(prefix), *args],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def test_installed_graph_selects_only_the_session_shell(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.manage('install', Path(tmp))
            verify_shell_selection(Path(tmp))

    def test_kwin_transaction_is_ordered_around_compositor(self):
        prepare = configparser.ConfigParser(interpolation=None)
        prepare.read(SESSION / 'systemd/singlr-kwin-prepare.service')
        self.assertEqual(prepare['Unit']['ConditionEnvironment'], 'XDG_SESSION_DESKTOP=Singlr')
        self.assertEqual(prepare['Unit']['Before'], 'plasma-kwin_wayland.service')
        self.assertEqual(prepare['Unit']['PartOf'], 'graphical-session.target')
        self.assertEqual(prepare['Service']['RemainAfterExit'], 'yes')
        self.assertTrue(prepare['Service']['ExecStart'].endswith('--apply --offline'))
        self.assertTrue(prepare['Service']['ExecStopPost'].endswith('--restore --offline'))

    def test_session_entry_execs_official_startup_with_defaults(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'entry'
            capture = Path(tmp) / 'capture'
            capture.write_text('#!/usr/bin/python3\nimport os,json,sys\nprint(json.dumps([sys.argv[1:],dict(os.environ)]))\n')
            capture.chmod(0o755)
            config = Path(tmp) / 'kreadconfig6'
            config.write_text('#!/bin/sh\nprintf \"%s\\n\" \"${TEST_SYSTEMD_BOOT:-true}\"\n')
            config.chmod(0o755)
            path.write_text((SESSION / 'startsinglr-wayland').read_text().replace(
                '/usr/lib/plasma-dbus-run-session-if-needed', str(capture)))
            path.chmod(0o755)
            test_env = os.environ | {'XDG_CONFIG_DIRS': '/etc/xdg', 'XDG_SESSION_DESKTOP': 'singlr',
                                     'PATH': tmp + ':' + os.environ['PATH']}
            args, env = json.loads(subprocess.check_output([str(path)], text=True, env=test_env))
            self.assertEqual(args, ['/usr/bin/startplasma-wayland'])
            self.assertEqual(env['XDG_SESSION_DESKTOP'], 'Singlr')
            self.assertEqual(env['PLASMA_DEFAULT_SHELL'], 'org.singlr.desktop')
            self.assertEqual(env['XDG_CONFIG_DIRS'], '/usr/lib/singlr/xdg:/etc/xdg')
            refused = subprocess.run([str(path)], text=True, capture_output=True,
                                     env=test_env | {'TEST_SYSTEMD_BOOT': 'False'})
            self.assertEqual(refused.returncode, 1)
            self.assertEqual(refused.stdout, '')
            self.assertIn('requiere systemdBoot', refused.stderr)

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
            self.assertTrue((prefix / 'usr/lib/systemd/user/singlr-kwin-prepare.service').exists())

    def test_symlink_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / 'staging'
            prefix.mkdir()
            (prefix / 'usr').symlink_to(Path(tmp) / 'elsewhere', target_is_directory=True)
            self.manage('install', prefix, '--dry-run', ok=False)
            self.assertFalse((Path(tmp) / 'elsewhere').exists())


if __name__ == '__main__':
    unittest.main()
