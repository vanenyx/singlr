"""Launcher behavior and packaging contracts; no installation into the user session."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PackagingTests(unittest.TestCase):
    def test_shell_syntax_and_desktop(self):
        for path in ('packaging/arch/PKGBUILD', 'apps/settings/singlr-settings', 'tools/check-cmake.sh'):
            subprocess.run(['bash', '-n', str(ROOT / path)], check=True)
        desktop = (ROOT / 'apps/settings/singlr-settings.desktop').read_text()
        for line in ('Name=Ajustes de Singlr', 'Exec=singlr-settings',
                     'Categories=Settings;', 'Icon=preferences-desktop-theme'):
            self.assertIn(line, desktop.splitlines())

    def test_launcher_dev_installed_and_missing_entry(self):
        with tempfile.TemporaryDirectory(prefix='singlr-launcher-') as directory:
            base = Path(directory)
            fake = base / 'qml6'
            fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\n'
                            'print(json.dumps([sys.argv[1:], os.environ.get("QT_WAYLAND_SHELL_INTEGRATION")]))\n')
            fake.chmod(0o755)
            for installed in (False, True):
                with self.subTest(installed=installed):
                    source = ROOT / 'apps/settings/singlr-settings'
                    launcher = base / ('installed-launcher' if installed else 'dev-launcher')
                    launcher.write_text(source.read_text().replace("installed_root='/usr/lib/singlr'",
                                                                   f"installed_root='{base}/installed'"))
                    launcher.chmod(0o755)
                    payload = base / ('installed' if installed else 'dev checkout')
                    (payload / 'apps/settings').mkdir(parents=True)
                    (payload / 'apps/settings/Main.qml').write_text('// test fixture')
                    env = os.environ | {'PATH': str(base) + ':' + os.environ['PATH'],
                                        'QT_WAYLAND_SHELL_INTEGRATION': 'layer-shell'}
                    env.pop('SINGLR_DEV_ROOT', None)
                    if not installed:
                        env['SINGLR_DEV_ROOT'] = str(payload)
                    result = subprocess.run([str(launcher), '--', 'a b'], env=env,
                                            capture_output=True, text=True, check=True)
                    args, integration = json.loads(result.stdout)
                    self.assertEqual(args, ['-I', str(payload / ('qml' if installed else 'shell/qml')),
                                            str(payload / 'apps/settings/Main.qml'), '--', 'a b'])
                    self.assertIsNone(integration)
                    (payload / 'apps/settings/Main.qml').unlink()
                    result = subprocess.run([str(launcher)], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn('no existe la app', result.stderr)

    def test_check_without_cmake(self):
        with tempfile.TemporaryDirectory(prefix='singlr-no-cmake-') as directory:
            result = subprocess.run(['/bin/bash', str(ROOT / 'tools/check-cmake.sh')],
                                    env=os.environ | {'PATH': directory}, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertIn('CMake no está disponible', result.stdout)

    def test_native_sources_and_package_ids(self):
        cmake = (ROOT / 'shell/session/CMakeLists.txt').read_text()
        for source in (ROOT / 'shell/session/src').glob('*.cpp'):
            self.assertIn('src/' + source.name, cmake)
        for kind, name in [('effects', 'singlr-overview'), ('scripts', 'singlr-gestures')]:
            metadata = json.loads((ROOT / f'kwin/{kind}/{name}/metadata.json').read_text())
            self.assertEqual(metadata['KPlugin']['Id'], name)
        self.assertTrue((ROOT / 'decoration/aurorae/Singlr/Singlrrc').is_file())

    @unittest.skipUnless(shutil.which('g++') and shutil.which('pkg-config'), 'requires Qt build tools')
    def test_reload_bridge(self):
        with tempfile.TemporaryDirectory(prefix='singlr-reload-') as directory:
            binary = str(Path(directory) / 'reload')
            flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'Qt6Qml', 'Qt6DBus'], text=True)
            subprocess.run(['g++', '-std=c++17', '-fPIC', '-I' + str(ROOT / 'shell/session/src'),
                            str(ROOT / 'tests/shell/reload.cpp'), *shlex.split(flags), '-o', binary],
                           check=True, timeout=60)
            subprocess.run([binary], check=True, timeout=20,
                           env=os.environ | {'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent'})


if __name__ == '__main__':
    unittest.main()
