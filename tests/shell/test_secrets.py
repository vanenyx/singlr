"""T214: exercise native NMQt formatting without contacting NM or KWallet."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('g++') and shutil.which('pkg-config'), 'requires g++ and pkg-config')
class SecretFormatTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='singlr-secrets-test-')
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.binary = str(Path(cls.tmp.name) / 'secretformat-test')
        flags = subprocess.run(['pkg-config', '--cflags', '--libs', 'Qt6Core', 'Qt6DBus', 'libnm'],
                               capture_output=True, text=True, check=True)
        result = subprocess.run(['g++', '-std=c++17', '-fPIC', '-I/usr/include/KF6/NetworkManagerQt',
                                 '-I' + str(ROOT / 'shell/session/src'),
                                 str(ROOT / 'tests/shell/secretformat.cpp'),
                                 str(ROOT / 'shell/session/src/secretformat.cpp'),
                                 *shlex.split(flags.stdout), '-lKF6NetworkManagerQt', '-o', cls.binary],
                                capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError(result.stderr)

    def native(self, case):
        result = subprocess.run([self.binary, case], capture_output=True, text=True, timeout=10,
                                env=os.environ | {'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent',
                                                  'DBUS_SYSTEM_BUS_ADDRESS': 'unix:path=/nonexistent'})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS ' + case, result.stdout)

    def test_kde_json_key_unicode_and_invalid_data(self):
        self.native('json')

    def test_single_password_contract_and_unsupported_settings(self):
        self.native('passwords')

    def test_nmqt_secret_map_roundtrip_and_request_new(self):
        self.native('roundtrip')

    def test_agent_owned_not_saved_not_required(self):
        self.native('flags')


if __name__ == '__main__':
    unittest.main()
