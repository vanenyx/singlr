#!/usr/bin/env python3
"""Change materials ONLY in a marked, disposable run-singlr.sh session; optionally capture it."""
import argparse
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def environment(descriptor):
    descriptor = descriptor.resolve()
    info = descriptor.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError('Descriptor privado del usuario requerido')
    data = json.loads(descriptor.read_text())
    env = data['env']
    if data['kind'] != 'singlr-nested-v1' or env['SINGLR_SESSION_ID'] != descriptor.parent.name:
        raise ValueError('No es una sesión anidada Singlr')
    os.kill(data['pid'], 0)
    for name in ('XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR'):
        if not Path(env[name]).resolve().is_relative_to(descriptor.parent):
            raise ValueError('Se rechazan preferencias fuera del perfil desechable')
    # Do not inherit the desktop's bus or display by accident.
    return dict(env, PATH=os.environ['PATH'], QML_IMPORT_PATH=str(ROOT / 'build/qml'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('descriptor', type=Path)
    parser.add_argument('--mode', choices=('dark', 'light'), required=True)
    parser.add_argument('--material', choices=('solid', 'glass', 'liquid'), required=True)
    parser.add_argument('--intensity', type=int, default=65)
    parser.add_argument('--capture', type=Path)
    parser.add_argument('--without-effect', action='store_true', help='Unload the plugin for a real fallback/baseline comparison')
    args = parser.parse_args()
    if not 0 <= args.intensity <= 100:
        parser.error('Intensidad: 0–100')
    env = environment(args.descriptor)
    def run(*command):
        return subprocess.run(command, env=env, check=True, capture_output=True, text=True, timeout=20).stdout.strip()
    for group, key, value in [('Appearance', 'material', args.material),
                              ('Appearance', 'intensity', str(args.intensity)),
                              ('Accessibility', 'reduceTransparency', 'false')]:
        run('kwriteconfig6', '--file', 'singlr/singlr.conf', '--group', group, '--key', key, '--notify', value)
    # This transaction, its journal, bus and KWin all belong to the temporary profile.
    run(str(ROOT / 'session/singlr-kwin'), '--apply')
    run('plasma-apply-colorscheme', 'BreezeDark' if args.mode == 'dark' else 'BreezeLight')
    run('qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.singlrReloadSettings')
    # Keep a baseline unloaded across KWin reconfigure, which otherwise reloads enabled plugins.
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Plugins', '--key', 'singlr-liquidglassEnabled', '--notify',
        str(not args.without_effect).lower())
    # A repeat invocation keeps the transaction snapshot, but must still update live parameters.
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Effect-singlrliquidglass', '--key', 'Enabled', '--notify',
        str(args.material == 'liquid' and args.intensity > 0 and not args.without_effect).lower())
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Effect-singlrliquidglass', '--key', 'Intensity', '--notify', str(args.intensity))
    run('qdbus6', 'org.kde.KWin', '/KWin', 'org.kde.KWin.reconfigure')
    run('qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.' +
        ('unloadEffect' if args.without_effect else 'loadEffect'), 'singlr-liquidglass')
    loaded = run('qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.isEffectLoaded', 'singlr-liquidglass')
    if args.without_effect and loaded == 'true':
        raise RuntimeError('El plugin sigue cargado: baseline inválido')
    if args.material == 'liquid' and not args.without_effect and loaded != 'true':
        raise RuntimeError('El plugin no está cargado: esta sesión solo demuestra Vidrio de respaldo')
    run('qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.singlrReloadSettings')
    if args.capture:
        time.sleep(0.5)
        runpy.run_path(str(ROOT / 'tools/session-runtime.py'))['capture'](args.capture, args.descriptor)
    print(json.dumps(dict(mode=args.mode, material=args.material, intensity=args.intensity, pluginLoaded=loaded == 'true')))


if __name__ == '__main__':
    main()
