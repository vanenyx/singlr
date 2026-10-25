"""T222: compile the native backend; pure checks and simulated D-Bus protocol."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('g++') and shutil.which('pkg-config'), 'requires g++ and pkg-config')
class TrayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='singlr-tray-test-')
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.binary = str(Path(cls.tmp.name) / 'tray-test')
        flags = subprocess.run(['pkg-config', '--cflags', '--libs', 'Qt6Core', 'Qt6Gui', 'Qt6DBus', 'Qt6Quick', 'Qt6Qml'],
                               capture_output=True, text=True, check=True)
        flags = shlex.split(flags.stdout)
        libexec = subprocess.run(['pkg-config', '--variable=libexecdir', 'Qt6Core'],
                                 capture_output=True, text=True, check=True).stdout.strip()
        moc = str(Path(cls.tmp.name) / 'moc_tray.cpp')
        subprocess.run([str(Path(libexec) / 'moc'), *[f for f in flags if f.startswith(('-I', '-D'))],
                        str(ROOT / 'shell/session/src/tray.h'), '-o', moc], check=True)
        system_moc = str(Path(cls.tmp.name) / 'moc_system.cpp')
        subprocess.run([str(Path(libexec) / 'moc'), str(ROOT / 'shell/session/src/system.h'), '-o', system_moc], check=True)
        result = subprocess.run(['g++', '-std=c++17', '-fPIC', '-Wall', '-Wextra',
                                 '-I' + str(ROOT / 'shell/session/src'),
                                 str(ROOT / 'tests/shell/tray.cpp'),
                                 str(ROOT / 'shell/session/src/tray.cpp'),
                                 str(ROOT / 'shell/session/src/trayformat.cpp'),
                                 str(ROOT / 'shell/session/src/system.cpp'), moc, system_moc,
                                 *flags, '-o', cls.binary], capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise RuntimeError(result.stderr)
        cls.env = os.environ | {'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
                                'QT_FORCE_STDERR_LOGGING': '1'}

    def native(self, case, command=None):
        result = subprocess.run(command or [self.binary, case], capture_output=True,
                                text=True, timeout=40, env=self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS ' + case, result.stdout)

    def test_argb_network_order_size_selection_and_invalid_pixmaps(self):
        self.native('pixmaps')

    def test_model_visibility_changes_and_image_provider(self):
        self.native('model')

    def test_windowed_launcher_has_no_context_backend(self):
        build = subprocess.run([str(ROOT / 'shell/session/build.sh')], capture_output=True,
                               text=True, check=True, timeout=60)
        result = subprocess.run([build.stdout.strip(), str(ROOT / 'shell/qml'),
                                 str(ROOT / 'tests/shell/TrayProbe.qml'), '--', '--windowed'],
                                capture_output=True, text=True, timeout=15,
                                env=self.env | {'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent',
                                                'DBUS_SYSTEM_BUS_ADDRESS': 'unix:path=/nonexistent'})
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('TRAY_WINDOWED_UNDEFINED true', result.stdout + result.stderr)
        self.assertIn('SYSTEM_WINDOWED_UNDEFINED true', result.stdout + result.stderr)

    def test_qdbusargument_parser_and_host_protocol_on_private_bus(self):
        if not shutil.which('dbus-run-session'):
            if os.environ.get('SINGLR_REQUIRE_TRAY_DBUS') == '1':
                self.fail('requires dbus-run-session')
            self.skipTest('requires dbus-run-session')
        probe = subprocess.run(['dbus-run-session', '--', 'true'], capture_output=True,
                               text=True, env=self.env, timeout=10)
        if probe.returncode:
            reason = 'private D-Bus socket unavailable: ' + probe.stderr.strip()
            if os.environ.get('SINGLR_REQUIRE_TRAY_DBUS') == '1':
                self.fail(reason)
            self.skipTest(reason)
        self.native('wire', ['dbus-run-session', '--', self.binary, 'wire'])


if __name__ == '__main__':
    unittest.main()
