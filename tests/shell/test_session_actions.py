"""T264: native protocol test on a private bus; never sends real session actions."""
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
                        '-I' + str(ROOT / 'shell/session/src'), '-I/usr/include/KF6/KService', '-I/usr/include/KF6/KConfigCore',
                        str(ROOT / 'tests/shell/session_actions.cpp'),
                        str(ROOT / 'shell/session/src/system.cpp'), moc,
                        *flags, '-lKF6Service', '-I/usr/include/KF6/KIO', '-I/usr/include/KF6/KIOGui', '-I/usr/include/KF6/KIOCore', '-I/usr/include/KF6/KCoreAddons', '-lKF6KIOGui', '-lKF6CoreAddons', '-lLayerShellQtInterface', '-I/usr/include/kworkspace6', '-lkworkspace6', '-o', cls.binary], check=True, timeout=60)

    def test_disconnected_bus_and_qml_contract(self):
        result = subprocess.run([self.binary, '--offline'], capture_output=True, text=True, timeout=10,
                                env=os.environ | {'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent',
                                                  'DBUS_SYSTEM_BUS_ADDRESS': 'unix:path=/nonexistent'})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS offline', result.stdout)

    def test_kde_test_backend_dispatches_sleep(self):
        result = subprocess.run([self.binary, '--gui-test'], capture_output=True, text=True, timeout=10,
                                env=os.environ | {'PLASMA_SESSION_GUI_TEST': '1',
                                                  'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent',
                                                  'DBUS_SYSTEM_BUS_ADDRESS': 'unix:path=/nonexistent'})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('suspend\nhibernate\nPASS KDE test backend', result.stdout)

    def test_private_bus_session_actions(self):
        if not shutil.which('dbus-run-session'):
            if os.environ.get('SINGLR_REQUIRE_SESSION_DBUS') == '1':
                self.fail('requires dbus-run-session')
            self.skipTest('requires dbus-run-session')
        data = Path(self.tmp.name) / self._testMethodName
        data.mkdir(parents=True)
        runtime = Path(self.tmp.name) / 'runtime'
        runtime.mkdir(mode=0o700)
        env = os.environ | {'XDG_CONFIG_HOME': str(data),
                            'XDG_DATA_HOME': str(data), 'XDG_DATA_DIRS': str(data),
                            'XDG_RUNTIME_DIR': str(runtime),
                            'SINGLR_ACTIVATION_RECORD': str(Path(self.tmp.name) / 'activation')}
        probe = subprocess.run(['dbus-run-session', '--', 'true'], env=env,
                               capture_output=True, text=True, timeout=10)
        if probe.returncode:
            if os.environ.get('SINGLR_REQUIRE_SESSION_DBUS') == '1':
                self.fail(probe.stderr)
            self.skipTest('private D-Bus unavailable: ' + probe.stderr.strip())
        for confirm, denied in ((True, False), (False, False), (True, True)):
            with self.subTest(confirm=confirm, denied=denied):
                (data / 'ksmserverrc').write_text('[General]\nconfirmLogout=' + str(confirm).lower() + '\n')
                record = Path(env['SINGLR_ACTIVATION_RECORD'])
                record.unlink(missing_ok=True)
                case_env = env | ({'SINGLR_TEST_DENIED': '1'} if denied else {})
                # Set the system bus address inside the private daemon's environment.
                result = subprocess.run(['dbus-run-session', '--', 'sh', '-c',
                    'export DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"; exec "$@"',
                    'session-test', self.binary, *([] if confirm else ['--skip-confirmation'])],
                    capture_output=True, text=True, env=case_env, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('PASS session-actions', result.stdout)



if __name__ == '__main__':
    unittest.main()
