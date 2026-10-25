"""T240: standalone shell package, real KPackage fallback and fixed QML geometry."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / 'session/shell-package/org.singlr.desktop'


class LockscreenTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='singlr-lockscreen-')
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.package = self.work / 'share/plasma/shells/org.singlr.desktop'
        shutil.copytree(PACKAGE, self.package)
        fonts = self.package / 'contents/fonts'
        fonts.mkdir()
        for font in ('inter/InterVariable.ttf', 'phosphor/Phosphor.ttf'):
            shutil.copy2(ROOT / 'third_party' / font, fonts)
        self.env = os.environ | {'XDG_DATA_DIRS': str(self.work / 'share') + ':/usr/share',
                                 'QT_QPA_PLATFORM': 'offscreen', 'QT_FORCE_STDERR_LOGGING': '1',
                                 'XDG_CONFIG_HOME': str(self.work / 'config')}

    @unittest.skipUnless(shutil.which('c++'), 'requires C++ and KF6Package development files')
    def test_real_package_and_fallback(self):
        flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'Qt6Core'], text=True))
        binary = self.work / 'package-test'
        subprocess.run(['c++', '-std=c++17', '-fPIC', str(ROOT / 'tests/shell/lockscreen_package.cpp'),
                        '-I/usr/include/KF6/KPackage', '-I/usr/include/KF6/KCoreAddons',
                        *flags, '-lKF6Package', '-lKF6CoreAddons', '-o', str(binary)], check=True)
        subprocess.run([str(binary)], env=self.env, check=True, timeout=10)

    @unittest.skipUnless(Path('/usr/lib/qt6/bin/qmltestrunner').is_file(), 'requires Qt Quick Test')
    def test_qml_geometry_and_password(self):
        fixtures = self.work / 'fixtures'
        fixtures.mkdir()
        for source in (ROOT / 'tests/shell/lockscreen').glob('tst_*.qml'):
            (fixtures / source.name).write_text(source.read_text().replace(
                '@LOCKSCREEN@', (self.package / 'contents/lockscreen').as_uri()))
        # Only enums are needed to load MainBlock outside kscreenlocker_greet;
        # no authenticator implementation is substituted in the real greeter.
        imports = self.work / 'imports/org/kde/kscreenlocker'
        imports.mkdir(parents=True)
        (imports / 'qmldir').write_text('module org.kde.kscreenlocker\nsingleton Authenticator 1.0 Authenticator.qml\n')
        (imports / 'Authenticator.qml').write_text(
            'pragma Singleton\nimport QtQuick\nQtObject { enum Kind { Fingerprint = 1, Smartcard = 2 } }\n')
        subprocess.run(['/usr/lib/qt6/bin/qmltestrunner', '-import', str(self.work / 'imports'),
                        '-input', str(fixtures)], env=self.env, check=True, timeout=30)


if __name__ == '__main__':
    unittest.main()
