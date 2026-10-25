"""T241: native KDE adapter, real Plasma tool and upstream Aurorae lookup."""
import configparser
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def isolated(base):
    env = dict(os.environ)
    for key in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR'):
        path = base / key
        path.mkdir(mode=0o700)
        env[key] = str(path)
    env.update(QT_QPA_PLATFORM='offscreen', DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(base / 'absent-bus'))
    return env


class GtkIntegrationTests(unittest.TestCase):
    def test_native_adapter(self):
        binary = ROOT / 'build/session/appearance/singlr-appearance-test'
        self.assertTrue(binary.is_file(), 'Build target singlr-appearance-test first')
        with tempfile.TemporaryDirectory() as temp:
            result = subprocess.run([str(binary)], env=isolated(Path(temp)),
                                    text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which('plasma-apply-colorscheme'), 'requires Plasma colors tool')
    def test_real_palette_and_persisted_accent_survive_scheme_change(self):
        with tempfile.TemporaryDirectory() as temp:
            env = isolated(Path(temp))
            def run(*args):
                subprocess.run(args, env=env, capture_output=True, check=True, timeout=15)
            run('plasma-apply-colorscheme', 'BreezeDark')
            # Same persistent KConfig preference as the native adapter / Colors KCM.
            run('kwriteconfig6', '--file', 'kdeglobals', '--group', 'General', '--key', 'AccentColor', '235,94,169')
            run('plasma-apply-colorscheme', '--accent-color', '#eb5ea9')
            run('plasma-apply-colorscheme', 'BreezeLight')
            config = configparser.ConfigParser(interpolation=None)
            config.read(Path(env['XDG_CONFIG_HOME']) / 'kdeglobals')
            self.assertEqual(config['Colors:Window']['BackgroundNormal'], '239,240,241')
            self.assertEqual(config['Colors:Window']['DecorationFocus'], '235,94,169')
            self.assertEqual(config['General']['AccentColor'], '235,94,169')

    @unittest.skipUnless(shutil.which('g++'), 'requires compiler and Qt6Svg development files')
    def test_aurorae_user_only_lookup_reproduces_empty_buttons(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            flags = subprocess.run(['pkg-config', '--cflags', '--libs', 'Qt6Gui', 'Qt6Svg'],
                                   capture_output=True, text=True, check=True).stdout
            binary = base / 'gtk-csd'
            subprocess.run(['g++', '-std=c++17', '-fPIC', str(ROOT / 'tests/shell/gtk_csd.cpp'),
                            '-o', str(binary), *shlex.split(flags)], check=True, capture_output=True)
            result = subprocess.run([str(binary), str(ROOT / 'decoration/aurorae/Singlr')],
                                    env=isolated(base), text=True, capture_output=True, check=True)
            self.assertIn('system/source=16/16 user-missing=0/16 temporary-user-copy=16/16', result.stdout)

    @unittest.skipUnless(shutil.which('plasma-apply-lookandfeel'), 'requires Plasma global theme tool')
    def test_color_only_auto_themes_preserve_singlr_decoration(self):
        with tempfile.TemporaryDirectory() as temp:
            env = isolated(Path(temp))
            themes = Path(env['XDG_DATA_HOME']) / 'plasma/look-and-feel'
            themes.parent.mkdir()
            shutil.copytree(ROOT / 'session/look-and-feel', themes)
            kwin = Path(env['XDG_CONFIG_HOME']) / 'kwinrc'
            original = '[org.kde.kdecoration2]\nlibrary=org.kde.kwin.aurorae\ntheme=__aurorae__svg__Singlr\n'
            kwin.write_text(original)
            for theme, background in [('dev.singlr.dark', '32,35,38'), ('dev.singlr.light', '239,240,241')]:
                subprocess.run(['plasma-apply-lookandfeel', '--apply', theme], env=env,
                               capture_output=True, check=True, timeout=15)
                config = configparser.ConfigParser(interpolation=None)
                config.read(Path(env['XDG_CONFIG_HOME']) / 'kdeglobals')
                self.assertEqual(config['Colors:Window']['BackgroundNormal'], background)
                self.assertEqual(kwin.read_text(), original)


if __name__ == '__main__':
    unittest.main()
