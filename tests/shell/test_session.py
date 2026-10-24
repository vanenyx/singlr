"""Headless lifecycle tests. Fake compositor/bus test isolation, never integration."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='singlr-session-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.host = self.base / 'host-config'
        self.host.mkdir()
        (self.host / 'kwinrc').write_text('host config must not change')
        self.entry = self.base / 'Entry.qml'
        self.entry.write_text('import QtQuick\nWindow { visible: true }\n')
        self.env = os.environ | {'PATH': str(self.bin) + ':' + os.environ['PATH'],
                                 'XDG_CONFIG_HOME': str(self.host),
                                 'WAYLAND_DISPLAY': '/tmp/fake-parent-wayland',
                                 'RECORD': str(self.base / 'record.json')}

    def executable(self, name, code):
        path = self.bin / name
        path.write_text('#!/usr/bin/env python3\n' + code)
        path.chmod(0o755)

    def mocks(self, qml_code=None):
        self.executable('dbus-run-session', '''import os,sys
os.environ['DBUS_SESSION_BUS_ADDRESS']='unix:path=/tmp/fake-singlr-bus'
os.execvp(sys.argv[2], sys.argv[2:])
''')
        self.executable('dbus-update-activation-environment', 'import sys\nsys.exit(0)\n')
        self.executable('kwin_wayland', '''import os,time
from pathlib import Path
(Path(os.environ['XDG_RUNTIME_DIR'])/'singlr-wayland').touch()
time.sleep(120)
''')
        self.executable('qml6', qml_code or '''import json,os,subprocess
from pathlib import Path
child=subprocess.Popen(['sleep','120'], start_new_session=True)
Path(os.environ['RECORD']).write_text(json.dumps(dict(env=dict(os.environ), pid=child.pid)))
''')

    def command(self):
        return [str(ROOT / 'tools/run-singlr.sh'), '--entry', str(self.entry), '--size', '800x600']

    def test_missing_entry(self):
        result = subprocess.run([str(ROOT / 'tools/run-singlr.sh'), '--entry', str(self.base / 'missing.qml')],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('No existe el punto de entrada QML', result.stderr)

    def test_invalid_size(self):
        result = subprocess.run(self.command() + ['--size', '0x600'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def assert_cleanup(self, result):
        self.assertIn('SINGLR_CLEANUP remaining=[]', result.stdout)
        self.assertIn('equal=True', result.stdout)
        record = json.loads((self.base / 'record.json').read_text())
        self.assertFalse(Path(f'/proc/{record["pid"]}').exists(), result.stdout + result.stderr)
        env = record['env']
        self.assertEqual(env['WAYLAND_DISPLAY'], 'singlr-wayland')
        self.assertEqual(env['DBUS_SESSION_BUS_ADDRESS'], 'unix:path=/tmp/fake-singlr-bus')
        self.assertEqual(env['_KDE_APPLICATIONS_AS_FORKING'], '1')
        self.assertNotIn('DISPLAY', env)
        self.assertNotIn('QT_WAYLAND_SHELL_INTEGRATION', env)
        for key in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR'):
            self.assertFalse(Path(env[key]).exists(), key)
        self.assertEqual((self.host / 'kwinrc').read_text(), 'host config must not change')

    def test_isolation_and_detached_cleanup(self):
        self.mocks()
        result = subprocess.run(self.command(), env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_cleanup(result)

    def test_sigterm_cleanup(self):
        self.mocks('''import json,os,subprocess,time
from pathlib import Path
child=subprocess.Popen(['sleep','120'], start_new_session=True)
Path(os.environ['RECORD']).write_text(json.dumps(dict(env=dict(os.environ), pid=child.pid)))
time.sleep(120)
''')
        process = subprocess.Popen(self.command(), env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 8
            while not (self.base / 'record.json').exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            self.assertTrue((self.base / 'record.json').exists())
            process.send_signal(signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=12)
            self.assertEqual(process.returncode, 130, stdout + stderr)
            self.assert_cleanup(subprocess.CompletedProcess([], process.returncode, stdout, stderr))
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=12)

    def test_compositor_failure(self):
        self.mocks()
        self.executable('kwin_wayland', 'import sys\nsys.exit(7)\n')
        result = subprocess.run(self.command(), env=self.env, capture_output=True, text=True, timeout=12)
        self.assertEqual(result.returncode, 1)
        self.assertIn('KWin terminó', result.stderr)
        self.assertIn('equal=True', result.stdout)
        self.assertFalse((self.base / 'record.json').exists())

    def test_capture_rejects_no_live_session(self):
        env = self.env | {'SINGLR_SESSION_FILE': str(self.base / 'absent.json')}
        result = subprocess.run([str(ROOT / 'tools/capture-session.sh'), str(self.base / 'shot.png')],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertFalse((self.base / 'shot.png').exists())


if __name__ == '__main__':
    unittest.main()
