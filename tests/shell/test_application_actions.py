"""T243: desktop actions and KIO launch, isolated from the user's session."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ApplicationActionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='singlr-application-actions-')
        cls.addClassCleanup(cls.tmp.cleanup)
        base = Path(cls.tmp.name)
        flags = shlex.split(subprocess.check_output(
            ['pkg-config', '--cflags', '--libs', 'Qt6Gui', 'Qt6DBus', 'Qt6Test'], text=True))
        libexec = subprocess.check_output(['pkg-config', '--variable=libexecdir', 'Qt6Core'], text=True).strip()
        moc = base / 'moc_system.cpp'
        subprocess.run([str(Path(libexec) / 'moc'), str(ROOT / 'shell/session/src/system.h'), '-o', str(moc)], check=True)
        cls.binary = base / 'application-actions'
        subprocess.run(['g++', '-std=c++17', '-fPIC', '-Wall', '-Wextra',
                        '-I' + str(ROOT / 'shell/session/src'),
                        *['-I/usr/include/KF6/' + name for name in
                          ('KService', 'KConfigCore', 'KIO', 'KIOGui', 'KIOCore', 'KCoreAddons')],
                        str(ROOT / 'tests/shell/application_actions.cpp'),
                        str(ROOT / 'shell/session/src/system.cpp'), str(moc), *flags,
                        '-lKF6Service', '-lKF6KIOGui', '-lKF6CoreAddons', '-lLayerShellQtInterface', '-I/usr/include/kworkspace6', '-lkworkspace6',
                        '-o', str(cls.binary)], check=True, timeout=60)

    def test_list_translation_and_launch(self):
        for language in ('en', 'es', 'fr'):
            with self.subTest(language=language), tempfile.TemporaryDirectory(dir=self.tmp.name) as profile:
                base = Path(profile)
                runtime = base / 'runtime'
                runtime.mkdir(mode=0o700)
                env = os.environ | {
                    'QT_QPA_PLATFORM': 'offscreen', 'QT_QPA_PLATFORMTHEME': '',
                    'LANGUAGE': language, 'LANG': language + '_ES.UTF-8',
                    'XDG_CONFIG_HOME': str(base / 'config'), 'XDG_CACHE_HOME': str(base / 'cache'),
                    'XDG_DATA_HOME': str(base / 'data'), 'XDG_DATA_DIRS': str(base / 'data'),
                    'XDG_RUNTIME_DIR': str(runtime), 'DBUS_SYSTEM_BUS_ADDRESS': 'unix:path=/nonexistent',
                    'KDE_APPLICATIONS_AS_SCOPE': '0', 'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent',
                }
                result = subprocess.run([str(self.binary)], env=env,
                                        capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('PASS application-actions ' + language, result.stdout)


if __name__ == '__main__':
    unittest.main()
