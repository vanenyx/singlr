#!/usr/bin/env python3
"""Side effects requested by the settings app, after QtCore.Settings.sync()."""
import argparse
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--apply-to-apps', action='store_true')
mode = parser.add_mutually_exclusive_group(required=True)
mode.add_argument('--dark', action='store_true')
mode.add_argument('--light', action='store_true')
args = parser.parse_args()
errors = []


def run(command, message):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=10)
        if result.returncode:
            errors.append(message)
    except (OSError, subprocess.TimeoutExpired):
        errors.append(message)


if args.apply_to_apps:
    run(['plasma-apply-colorscheme', 'BreezeDark' if args.dark else 'BreezeLight'],
        'Guardado. No se pudo aplicar el esquema a las apps de KDE.')
qdbus = shutil.which('qdbus6') or '/usr/lib/qt6/bin/qdbus'
run([qdbus, 'org.kde.plasmashell', '/PlasmaShell',
     'org.kde.PlasmaShell.singlrReloadSettings'],
    'Guardado. La sesión Singlr no está disponible para recargar.')
if errors:
    print('\n'.join(errors))
raise SystemExit(bool(errors))
