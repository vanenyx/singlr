"""T239: real INI migration and recovery unit dependency contract."""
import configparser
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]

class RobustnessTests(unittest.TestCase):
    def test_sigterm_is_clean_and_config_is_migrated_before_qml(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            qml = base / 'Idle.qml'
            qml.write_text('import QtQml\nQtObject {}\n')
            binary = subprocess.check_output([str(ROOT / 'shell/session/build.sh')], text=True).strip()
            process = subprocess.Popen([binary, str(ROOT / 'shell/qml'), str(qml), '--windowed'],
                env=os.environ | {'QT_QPA_PLATFORM': 'offscreen', 'XDG_CONFIG_HOME': tmp,
                                  'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent'},
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 5
                while not (base / 'singlr/singlr.conf').exists() and process.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertIsNone(process.poll())
                self.assertIn('schemaVersion=1', (base / 'singlr/singlr.conf').read_text())
                process.terminate()
                stdout, stderr = process.communicate(timeout=3)
                self.assertEqual(process.returncode, 0, stdout + stderr)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()

    def test_wallpaper_texture_size_release_and_recreation(self):
        with tempfile.TemporaryDirectory() as tmp:
            flags = shlex.split(subprocess.check_output(
                ['pkg-config', '--cflags', '--libs', 'Qt6Quick', 'Qt6Qml', 'Qt6Gui'], text=True))
            binary = str(Path(tmp) / 'wallpaper')
            subprocess.run(['g++', '-std=c++17', '-fPIC', '-I' + str(ROOT / 'shell/session/src'),
                            str(ROOT / 'tests/shell/wallpaper.cpp'), *flags, '-o', binary], check=True)
            subprocess.run([binary], check=True, timeout=15, env=os.environ | {
                'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software', 'QSG_RENDER_LOOP': 'basic'})

    def test_recovery_keeps_workspace_alive(self):
        def unit(name):
            data = configparser.ConfigParser(interpolation=None, strict=False)
            data.read(ROOT / 'session/systemd' / name)
            return data
        shell = configparser.ConfigParser(interpolation=None, strict=False)
        shell.read('/usr/lib/systemd/user/plasma-plasmashell.service')
        self.assertEqual(shell['Service']['Restart'], 'on-failure')
        self.assertEqual(shell['Unit']['StartLimitBurst'], '3')
        self.assertEqual(shell['Unit']['StartLimitIntervalSec'], '60s')
        self.assertEqual(shell['Service']['Type'], 'dbus')
        self.assertEqual(shell['Service']['BusName'], 'org.kde.plasmashell')
        # Inspect every dependency directive (ConfigParser merges duplicate keys).
        for line in Path('/usr/lib/systemd/user/plasma-core.target').read_text().splitlines():
            if line.startswith(('Requires=', 'BindsTo=')):
                self.assertNotIn('plasma-plasmashell.service', line)
        notice = unit('singlr-shell-failed.service')
        self.assertEqual(notice['Service']['Type'], 'oneshot')
        self.assertNotIn('Restart', notice['Service'])

    def test_actual_ini_migration(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            source = base / 'migration.cpp'
            source.write_text(r'''#include "configmigration.h"
#include <QCoreApplication>
#include <QFile>
#include <cassert>
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    const QString file = QString::fromLocal8Bit(argv[1]) + "/nested/singlr.conf";
    assert(SinglrConfig::migrate(file));
    QSettings s(file, QSettings::IniFormat);
    assert(s.value("Config/schemaVersion").toInt() == 1);
    s.clear(); // existing schema 0, with user and unknown future keys
    s.setValue("Appearance/wallpaper", "file:///my wallpaper.jpg");
    s.setValue("Other/custom", 42); s.sync();
    assert(SinglrConfig::migrate(file)); s.sync();
    assert(s.value("Appearance/wallpaper").toString() == "file:///my wallpaper.jpg");
    assert(s.value("Other/custom").toInt() == 42);
    QFile f(file); assert(f.open(QIODevice::ReadOnly)); const auto before = f.readAll(); f.close();
    assert(SinglrConfig::migrate(file));
    assert(f.open(QIODevice::ReadOnly)); assert(f.readAll() == before); f.close();
    for (const auto &version : {QString("2"), QString("invalid"), QString("-1")}) {
        s.setValue("Config/schemaVersion", version); s.sync();
        assert(!SinglrConfig::migrate(file)); s.sync();
        assert(s.value("Config/schemaVersion").toString() == version);
    }
    return 0;
}
''')
            flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'Qt6Core'], text=True))
            binary = base / 'migration'
            subprocess.run(['g++', '-std=c++17', '-fPIC', '-I' + str(ROOT / 'shell/session/src'),
                            str(source), *flags, '-o', str(binary)], check=True)
            subprocess.run([str(binary), tmp], check=True)
