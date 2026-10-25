#!/usr/bin/env python3
"""Change materials ONLY in a marked, disposable run-singlr.sh session; optionally capture it."""
import argparse
import json
import os
from pathlib import Path
import runpy
import stat
import struct
import subprocess
import time
import math

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


def apply_material(run, mode, material, intensity, without_effect=False, diagnostic_overlay=False):
    for group, key, value in [('Appearance', 'material', material),
                              ('Appearance', 'intensity', str(intensity)),
                              ('Accessibility', 'reduceTransparency', 'false')]:
        run('kwriteconfig6', '--file', 'singlr/singlr.conf', '--group', group, '--key', key, '--notify', value)
    # This transaction, its journal, bus and KWin all belong to the temporary profile.
    run(str(ROOT / 'session/singlr-kwin'), '--apply')
    run('plasma-apply-colorscheme', 'BreezeDark' if mode == 'dark' else 'BreezeLight')
    run('qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.singlrReloadSettings')
    # Keep a baseline unloaded across KWin reconfigure, which otherwise reloads enabled plugins.
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Plugins', '--key', 'singlr-liquidglassEnabled', '--notify',
        str(not without_effect).lower())
    # A repeat invocation keeps the transaction snapshot, but must still update live parameters.
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Effect-singlrliquidglass', '--key', 'Enabled', '--notify',
        str(material == 'liquid' and intensity > 0 and not without_effect).lower())
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Effect-singlrliquidglass', '--key', 'Intensity', '--notify', str(intensity))
    run('qdbus6', 'org.kde.KWin', '/KWin', 'org.kde.KWin.reconfigure')
    run('qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.' +
        ('unloadEffect' if without_effect else 'loadEffect'), 'singlr-liquidglass')
    loaded = run('qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.isEffectLoaded', 'singlr-liquidglass')
    if without_effect and loaded == 'true':
        raise RuntimeError('El plugin sigue cargado: baseline inválido')
    if material == 'liquid' and intensity > 0 and not without_effect and loaded != 'true':
        raise RuntimeError('El plugin no está cargado: esta sesión solo demuestra Vidrio de respaldo')
    run('qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.singlrReloadSettings')
    run('kwriteconfig6', '--file', 'kwinrc', '--group', 'Effect-singlrliquidglass',
        '--key', 'DiagnosticOverlay', '--notify', str(diagnostic_overlay).lower())
    run('qdbus6', 'org.kde.KWin', '/KWin', 'org.kde.KWin.reconfigure')
    if loaded == 'true':
        # Same call as Singlr Settings: a loaded effect re-reads its group only on reconfigureEffect.
        run('qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.reconfigureEffect', 'singlr-liquidglass')
    return loaded == 'true'


def effect_diagnostics(run, loaded):
    if not loaded:
        return None
    return json.loads(run('qdbus6', 'org.kde.KWin', '/Effects',
                          'org.kde.kwin.Effects.debug', 'singlr-liquidglass', 'windows'))


def open_surface(run, surface):
    # Idempotent even when the requested panel was already open.
    run('qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.singlrClosePanels')
    time.sleep(.15)
    run('qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.' +
        ('toggleControlCenter' if surface == 'control-center' else 'toggleLauncher'))
    time.sleep(.7)


def panel_windows(diagnostic, surface):
    candidates = [w for w in (diagnostic or {}).get('windows', [])
                  if w['eligible'] and w['visible'] and w['region'][3] > 100]
    return [w for w in candidates if (w['region'][2] == 340 if surface == 'control-center'
                                     else w['region'][2] > 400)]


def panel_edge(diagnostic, surface):
    candidates = panel_windows(diagnostic, surface)
    if not candidates:
        raise RuntimeError('No hay región del panel en el diagnóstico; revisar cliente/blur o usar --edge-rect')
    window = max(candidates, key=lambda w: w['region'][2] * w['region'][3])
    x, y, width, height = window['region']
    # Native compositor coordinates, not the QWindow position guessed by the client.
    x += window['position'][0]
    y += window['position'][1]
    return [max(0, int(x)-12), max(0, int(y)-12), min(256, width), min(96, height)]


def crop_edge(capture, rect, zoom):
    executable = ROOT / 'build/singlr-material-image'
    if not executable.is_file():
        raise RuntimeError('Construye primero: cmake --build build --target singlr-material-image')
    output = capture.with_name(capture.stem + '-edge.png')
    subprocess.run([str(executable), str(capture), str(output), *map(str, rect), str(zoom)],
                   check=True, timeout=20)
    return output


def pixel_edge(rect, diagnostic, capture):
    if diagnostic.get('screenCount') != 1:
        raise RuntimeError('Recorte automático requiere una salida; con varias usa --edge-rect en píxeles')
    # PNG IHDR; Qt performs the actual decode/crop. Spectacle can return device
    # pixels even when KWin reports the panel geometry in logical coordinates.
    with capture.open('rb') as stream:
        header = stream.read(24)
    if header[:8] != b'\x89PNG\r\n\x1a\n':
        raise RuntimeError('Captura PNG requerida')
    width, height = struct.unpack('>II', header[16:24])
    ox, oy, vw, vh = diagnostic['virtualGeometry']
    sx, sy = width / vw, height / vh
    if abs(sx-sy) > .01:
        raise RuntimeError('Escala de captura ambigua; usa --edge-rect en píxeles')
    x, y, w, h = rect
    x0, y0 = max(0, math.floor((x-ox)*sx)), max(0, math.floor((y-oy)*sy))
    x1, y1 = min(width, math.ceil((x+w-ox)*sx)), min(height, math.ceil((y+h-oy)*sy))
    return [x0, y0, x1-x0, y1-y0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('descriptor', type=Path)
    parser.add_argument('--mode', choices=('dark', 'light'), required=True)
    parser.add_argument('--material', choices=('solid', 'glass', 'liquid'))
    parser.add_argument('--intensity', type=int, default=65)
    parser.add_argument('--surface', choices=('control-center', 'launcher'), help='Close panels and open this surface')
    parser.add_argument('--capture', type=Path)
    parser.add_argument('--suite', type=Path, help='Capture all three materials on both surfaces, with edge crops and diagnostics')
    parser.add_argument('--edge-rect', type=int, nargs=4, metavar=('X', 'Y', 'WIDTH', 'HEIGHT'), help='Override edge crop in screenshot pixels')
    parser.add_argument('--edge-zoom', type=int, default=4)
    parser.add_argument('--diagnostic-overlay', action='store_true', help='Magenta shader rim; diagnostic captures only')
    parser.add_argument('--without-effect', action='store_true', help='Unload the plugin for a real fallback/baseline comparison')
    args = parser.parse_args()
    if not 0 <= args.intensity <= 100 or not 1 <= args.edge_zoom <= 16:
        parser.error('Intensidad: 0–100; zoom: 1–16')
    if args.suite and (args.capture or args.material or args.without_effect or args.diagnostic_overlay):
        parser.error('--suite no admite --capture, --material, --without-effect ni --diagnostic-overlay')
    if not args.suite and not args.material:
        parser.error('Especifica --material o --suite')
    if args.edge_rect and (min(args.edge_rect[:2]) < 0 or min(args.edge_rect[2:]) < 1):
        parser.error('Recorte: X/Y >= 0, WIDTH/HEIGHT > 0')
    env = environment(args.descriptor)
    def run(*command):
        return subprocess.run(command, env=env, check=True, capture_output=True, text=True, timeout=20).stdout.strip()
    def apply(material, **kwargs):
        return apply_material(run, args.mode, material, args.intensity, **kwargs)
    def save(material, loaded, path, surface=None, rect=None, logical_rect=False):
        time.sleep(.7)
        if path:
            path = path.resolve()
            runpy.run_path(str(ROOT / 'tools/session-runtime.py'))['capture'](path, args.descriptor)
        diagnostic = effect_diagnostics(run, loaded)
        result = dict(mode=args.mode, material=material, intensity=args.intensity,
                      pluginLoaded=loaded, surface=surface, effect=diagnostic)
        if path and rect and logical_rect:
            result['edgeRectLogical'] = rect
            rect = pixel_edge(rect, diagnostic, path)
        if rect:
            result.update(edgeRect=rect, edgeZoom=args.edge_zoom)
        if path:
            # Write evidence even when the shader did not draw: a loaded plugin
            # is not a passing visual review.
            if rect:
                result['edgeCapture'] = str(crop_edge(path, rect, args.edge_zoom))
            path.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result))
        if material == 'liquid' and args.intensity > 0 and surface and not args.without_effect:
            if not any(w['draws'] > 0 for w in panel_windows(diagnostic, surface)):
                raise RuntimeError('Plugin cargado pero sin pases del panel; revisar diagnóstico .json')
    if args.suite:
        for surface in ([args.surface] if args.surface else ['control-center', 'launcher']):
            # Discover the native panel region before an opaque intensity-0 run.
            loaded = apply_material(run, args.mode, 'glass', max(1, args.intensity))
            open_surface(run, surface)
            rect = args.edge_rect or panel_edge(effect_diagnostics(run, loaded), surface)
            for material in ('solid', 'glass', 'liquid'):
                loaded = apply(material)
                save(material, loaded, args.suite / f'{surface}-{material}-{args.mode}.png',
                     surface, rect, not args.edge_rect)
    else:
        loaded = apply(args.material, without_effect=args.without_effect, diagnostic_overlay=args.diagnostic_overlay)
        if args.surface:
            open_surface(run, args.surface)
        rect = args.edge_rect
        if args.capture and args.surface and loaded and not rect:
            rect = panel_edge(effect_diagnostics(run, loaded), args.surface) if args.material != 'solid' and args.intensity else None
        save(args.material, loaded, args.capture, args.surface, rect, bool(rect and not args.edge_rect))


if __name__ == '__main__':
    main()
