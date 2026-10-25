"""T232: native protocol test on a private bus; never sends real session actions."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('g++') and shutil.which('pkg-config'), 'requires Qt6 compiler')
class SessionActionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='singlr-session-actions-')
        cls.addClassCleanup(cls.tmp.cleanup)
        flags = shlex.split(subprocess.check_output(
            ['pkg-config', '--cflags', '--libs', 'Qt6Core', 'Qt6DBus', 'Qt6Gui'], text=True))
        libexec = subprocess.check_output(['pkg-config', '--variable=libexecdir', 'Qt6Core'], text=True).strip()
        moc = str(Path(cls.tmp.name) / 'moc_system.cpp')
        subprocess.run([str(Path(libexec) / 'moc'), str(ROOT / 'shell/session/src/system.h'), '-o', moc], check=True)
        cls.binary = str(Path(cls.tmp.name) / 'session-actions')
        subprocess.run(['g++', '-std=c++17', '-fPIC', '-Wall', '-Wextra',
                        '-I' + str(ROOT / 'shell/session/src'),
                        str(ROOT / 'tests/shell/session_actions.cpp'),
                        str(ROOT / 'shell/session/src/system.cpp'), moc,
                        *flags, '-lLayerShellQtInterface', '-o', cls.binary], check=True, timeout=60)

    def test_disconnected_bus_and_qml_contract(self):
        result = subprocess.run([self.binary, '--offline'], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS offline', result.stdout)

    def test_private_bus_session_actions(self):
        if not shutil.which('dbus-run-session'):
            if os.environ.get('SINGLR_REQUIRE_SESSION_DBUS') == '1':
                self.fail('requires dbus-run-session')
            self.skipTest('requires dbus-run-session')
        probe = subprocess.run(['dbus-run-session', '--', 'true'], capture_output=True, text=True, timeout=10)
        if probe.returncode:
            if os.environ.get('SINGLR_REQUIRE_SESSION_DBUS') == '1':
                self.fail(probe.stderr)
            self.skipTest('private D-Bus unavailable: ' + probe.stderr.strip())
        result = subprocess.run(['dbus-run-session', '--', self.binary], capture_output=True, text=True,
                                env=os.environ | {'DBUS_SYSTEM_BUS_ADDRESS': 'unix:path=/nonexistent'}, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS session-actions', result.stdout)


if __name__ == '__main__':
    unittest.main()
