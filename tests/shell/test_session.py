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
                                 'SINGLR_BUILD_DIR': str(self.base / 'build'),
                                 'CXX': str(self.bin / 'fake-cxx'),
                                 'LANG': 'C.UTF-8', 'LC_TIME': 'C',
                                 'RECORD': str(self.base / 'record.json')}

    def executable(self, name, code):
        path = self.bin / name
        path.write_text('#!/usr/bin/env python3\n' + code)
        path.chmod(0o755)

    def mocks(self, qml_code=None):
        # Fake only the native launcher for lifecycle tests; the real compiler is
        # checked separately. Preserve qml-shell's build/exec path.
        self.executable('fake-cxx', """import os,sys
from pathlib import Path
out=Path(sys.argv[sys.argv.index('-o')+1])
out.write_text('#!/bin/sh\\nexec qml6 \"$@\"\\n')
out.chmod(0o755)
Path(sys.argv[sys.argv.index('-MF')+1]).write_text('out: ' + str(Path(__file__).resolve()) + '\\n')
""")
        self.executable('dbus-run-session', '''import os,sys
os.environ['DBUS_SESSION_BUS_ADDRESS']='unix:path=/tmp/fake-singlr-bus'
os.execvp(sys.argv[2], sys.argv[2:])
''')
        self.executable('dbus-update-activation-environment', """import json,os,sys
from pathlib import Path
Path(os.environ['RECORD'] + '.activation').write_text(json.dumps(dict(args=sys.argv[1:], env=dict(os.environ))))
""")
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

    def test_plasma_client_uses_private_environment(self):
        self.mocks()
        self.executable('plasmashell', """import json,os,subprocess
from pathlib import Path
child=subprocess.Popen(['sleep','120'], start_new_session=True)
Path(os.environ['RECORD']).write_text(json.dumps(dict(env=dict(os.environ), pid=child.pid)))
""")
        result = subprocess.run(self.command() + ['--client', 'plasma'], env=self.env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assert_cleanup(result)
        self.assertFalse((self.base / 'build').exists(), 'Plasma no debe compilar Singlr')

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
        self.assertEqual(env['LANG'], 'C.UTF-8')
        self.assertEqual(env['LC_TIME'], 'C')
        activation = json.loads(Path(str(self.base / 'record.json') + '.activation').read_text())
        for key in ('LANG', 'LC_TIME', 'SINGLR_SESSION_ID'):
            self.assertIn(key, activation['args'])
            self.assertEqual(activation['env'][key], env[key])
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

    def test_duration_and_external_client_cleanup(self):
        self.mocks("""import json,os,time
from pathlib import Path
Path(os.environ['RECORD']).write_text(json.dumps(dict(env=dict(os.environ), pid=os.getpid())))
time.sleep(120)
""")
        with (self.base / 'session.log').open('w+') as log:
            process = subprocess.Popen(self.command() + ['--duration', '2'], env=self.env,
                                       stdout=log, stderr=subprocess.STDOUT)
            external = unrelated = None
            try:
                deadline = time.monotonic() + 8
                descriptor = None
                while time.monotonic() < deadline and process.poll() is None:
                    lines = (self.base / 'session.log').read_text().splitlines()
                    paths = [Path(line.split('=', 1)[1]) for line in lines
                             if line.startswith('SINGLR_SESSION_FILE=')]
                    if paths and paths[0].exists():
                        descriptor = json.loads(paths[0].read_text())
                        break
                    time.sleep(0.05)
                self.assertIsNotNone(descriptor)
                self.assertEqual(descriptor['env']['LC_TIME'], 'C')
                self.assertEqual(descriptor['env']['LANG'], 'C.UTF-8')
                # Outside the supervisor's ancestry; ignore TERM to exercise KILL.
                external = subprocess.Popen(['python3', '-c',
                    'import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(120)'],
                    env=self.env | descriptor['env'], start_new_session=True)
                unrelated = subprocess.Popen(['sleep', '120'],
                    env=self.env | descriptor['env'] | {'SINGLR_SESSION_ID': descriptor['env']['SINGLR_SESSION_ID'] + '-other'},
                    start_new_session=True)
                process.wait(timeout=15)
                self.assertIsNone(unrelated.poll(), 'No debe matar procesos de otra sesión')
                self.assertEqual(process.returncode, 0, (self.base / 'session.log').read_text())
                self.assertIsNotNone(external.poll(), (self.base / 'session.log').read_text())
                self.assert_cleanup(subprocess.CompletedProcess([], 0,
                    (self.base / 'session.log').read_text(), ''))
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=12)
                if unrelated:
                    unrelated.terminate()
                    unrelated.wait(timeout=5)
                if external:
                    if external.poll() is None:
                        external.kill()
                    external.wait()

    def test_kwin_close_and_sigint_cleanup(self):
        for mode in ('kwin', 'sigint'):
            with self.subTest(mode=mode):
                (self.base / 'record.json').unlink(missing_ok=True)
                self.mocks("""import json,os,subprocess,time
from pathlib import Path
child=subprocess.Popen(['sleep','120'], start_new_session=True)
Path(os.environ['RECORD']).write_text(json.dumps(dict(env=dict(os.environ), pid=child.pid)))
time.sleep(120)
""")
                with (self.base / 'close.log').open('w+') as log:
                    process = subprocess.Popen(self.command(), env=self.env, stdout=log,
                                               stderr=subprocess.STDOUT)
                    try:
                        deadline = time.monotonic() + 8
                        while not (self.base / 'record.json').exists() and time.monotonic() < deadline:
                            time.sleep(0.05)
                        self.assertTrue((self.base / 'record.json').exists())
                        if mode == 'kwin':
                            # Find this session's fake compositor by exact argv and marker.
                            env = json.loads((self.base / 'record.json').read_text())['env']
                            for proc in Path('/proc').iterdir():
                                try:
                                    args = (proc / 'cmdline').read_bytes().split(b'\0')
                                    if str(self.bin / 'kwin_wayland').encode() in args and (
                                        'SINGLR_SESSION_ID=' + env['SINGLR_SESSION_ID']).encode() in (
                                            proc / 'environ').read_bytes().split(b'\0'):
                                        os.kill(int(proc.name), signal.SIGTERM)
                                except (OSError, ValueError):
                                    pass
                        else:
                            process.send_signal(signal.SIGINT)
                        process.wait(timeout=12)
                        self.assertEqual(process.returncode, 241 if mode == 'kwin' else 130,
                                         (self.base / 'close.log').read_text())
                        self.assert_cleanup(subprocess.CompletedProcess([], process.returncode,
                            (self.base / 'close.log').read_text(), ''))
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
