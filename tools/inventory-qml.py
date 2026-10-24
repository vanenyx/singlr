#!/usr/bin/env python3
"""Import probes in separate offscreen processes; no running Plasma shell required."""
import os
from pathlib import Path
import subprocess
import tempfile

modules = ['QtQuick.Effects', 'QtQuick.Shapes', 'QtQuick.Controls', 'QtQuick.Layouts',
           'Qt5Compat.GraphicalEffects', 'org.kde.kirigami', 'org.kde.layershell',
           'Quickshell', 'Quickshell.Wayland']
for file in sorted(Path('/usr/lib/qt6/qml/org/kde/plasma').rglob('qmldir')):
    for line in file.read_text().splitlines():
        if line.startswith('module ') and '.private.' not in line:
            modules.append(line.split()[1])
failed = []
with tempfile.TemporaryDirectory(prefix='singlr-imports-') as directory:
    base = Path(directory)
    env = os.environ.copy()
    env.update(QT_QPA_PLATFORM='offscreen', QT_FORCE_STDERR_LOGGING='1',
               QT_QUICK_CONTROLS_STYLE='Basic', QT_QPA_PLATFORMTHEME='',
               XDG_CONFIG_HOME=str(base / 'config'), XDG_CACHE_HOME=str(base / 'cache'),
               XDG_DATA_HOME=str(base / 'data'), XDG_STATE_HOME=str(base / 'state'))
    for module in modules:
        probe = base / 'Probe.qml'
        probe.write_text('import QtQuick\nimport ' + module + ' as Probe\n'
                         'Item { Component.onCompleted: { console.log("IMPORT_OK"); Qt.quit() } }\n')
        result = subprocess.run(['qml6', str(probe)], env=env, capture_output=True,
                                text=True, timeout=10)
        ok = result.returncode == 0 and 'IMPORT_OK' in result.stderr
        print(f'{module}: {"PASS" if ok else "FAIL"}')
        if not ok:
            failed.append(module)
            print((result.stdout + result.stderr).strip())
    probe = base / 'Probe.qml'
    probe.write_text('import QtQuick\nItem { ShaderEffect {}\n'
                     'Component.onCompleted: { console.log("IMPORT_OK"); Qt.quit() } }\n')
    result = subprocess.run(['qml6', str(probe)], env=env, capture_output=True, text=True, timeout=10)
    print('QtQuick.ShaderEffect: ' + ('PASS' if result.returncode == 0 and 'IMPORT_OK' in result.stderr else 'FAIL'))
print('Import probes only; services, attached properties and GPU rendering require separate integration checks.')
print('Unavailable: ' + ', '.join(failed))
