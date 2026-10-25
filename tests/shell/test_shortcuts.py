"""P-015: native backup/conflict logic and a private fake KGlobalAccel bus."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(all(shutil.which(tool) for tool in ('g++', 'pkg-config')),
                     'requires native Qt build tools')
class ShortcutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        directory = tempfile.TemporaryDirectory(prefix='singlr-shortcuts-test-')
        cls.addClassCleanup(directory.cleanup)
        cls.binary = str(Path(directory.name) / 'shortcuts-test')
        flags = subprocess.run(['pkg-config', '--cflags', '--libs', 'Qt6Gui', 'Qt6DBus'],
                               check=True, capture_output=True, text=True).stdout
        result = subprocess.run(['g++', '-std=c++17', '-fPIC', '-I/usr/include/KF6/KGlobalAccel',
                                 '-I' + str(ROOT / 'shell/session/src'),
                                 str(ROOT / 'tests/shell/shortcuts.cpp'),
                                 str(ROOT / 'shell/session/src/shortcuts.cpp'),
                                 *shlex.split(flags), '-lKF6GlobalAccel', '-o', cls.binary],
                                capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError(result.stderr)

    def test_backup_and_conflicts(self):
        result = subprocess.run([self.binary, '--unit'], capture_output=True, text=True,
                                env=os.environ | {'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent'}, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS backup, conflicts', result.stdout)

    @unittest.skipUnless(shutil.which('dbus-run-session'), 'requires private D-Bus')
    def test_isolated_dbus_restoration(self):
        result = subprocess.run(['dbus-run-session', '--', self.binary],
                                env=os.environ | {'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent'},
                                capture_output=True, text=True, timeout=30)
        if result.returncode == 127 and 'Failed to bind socket' in result.stderr:
            self.skipTest('sandbox prevents private D-Bus socket; run outside sandbox')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS backup, conflicts, isolated D-Bus', result.stdout)


if __name__ == '__main__':
    unittest.main()
