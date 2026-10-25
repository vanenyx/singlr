#!/usr/bin/env python3
"""Inventario local de configuración; no copia contenido ni visita carteras/credenciales."""
import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import subprocess

# Direct writers and KDE services delegated by the session. Inventory descendants
# of these directories only: never walk HOME, wallets, browser profiles or secrets.
FILES = ('kwinrc', 'kglobalshortcutsrc', 'kdeglobals', 'plasmashellrc', 'ksmserverrc',
         'plasmanotifyrc', 'kcminputrc', 'kxkbrc', 'klaunchrc', 'kded6rc',
         'plasmaparc', 'dconf/user', 'gtk-3.0/settings.ini', 'gtk-4.0/settings.ini', 'xsettingsd/xsettingsd.conf',
         'singlr/singlr.conf', 'singlr/dock.json')
DIRS = ('singlr', 'systemd/user/singlr-shell.service.d', 'session')
RESTORED_SHORTCUTS = ('Window Maximize', 'Window Minimize', 'Window Quick Tile Top', 'Window Quick Tile Bottom')


def digest(path):
    if path.is_symlink():
        return 'SYMLINK: not followed'
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def keys(path):
    if path.is_symlink():
        raise RuntimeError('No se sigue configuración enlazada')
    cfg = configparser.RawConfigParser(strict=False, delimiters=('=',), interpolation=None)
    cfg.optionxform = str
    if path.exists():
        cfg.read(path)
    return {section + '/' + key: hashlib.sha256(value.encode()).hexdigest()
            for section in cfg.sections() for key, value in cfg.items(section)}


def snapshot():
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/nonexistent'))
    paths = set(FILES)
    for directory in DIRS:
        base = config / directory
        if base.is_dir() and not base.is_symlink():
            for folder, dirs, files in os.walk(base, followlinks=False):
                dirs[:] = [d for d in dirs if not (Path(folder) / d).is_symlink()]
                paths.update(str((Path(folder) / f).relative_to(config)) for f in files)
    for relative in paths:
        target = config / relative
        if any(parent.is_symlink() for parent in target.parents if parent != config and config in parent.parents):
            raise RuntimeError('Directorio de configuración enlazado: auditoría requiere perfil nuevo sin enlaces')
    return {'schema': 1, 'files': {p: digest(config / p) for p in sorted(paths)},
            'singlr_appearance_references': any(value in (hashlib.sha256(b'dev.singlr.light').hexdigest(), hashlib.sha256(b'dev.singlr.dark').hexdigest())
                for key, value in keys(config / 'kdeglobals').items() if key in ('KDE/DefaultLightLookAndFeel', 'KDE/DefaultDarkLookAndFeel', 'KDE/LookAndFeelPackage')),
            'kwin_keys': keys(config / 'kwinrc'), 'shortcut_keys': keys(config / 'kglobalshortcutsrc'),
            'pending_kwin_backup': (state / 'singlr/kwinrc-backup.json').exists(),
            'pending_shortcuts_backup': (runtime / 'singlr-live/shortcuts-backup.json').exists(),
            'kwin_lock_residue': (state / 'singlr/kwinrc.lock').exists()}


def compare(before, after):
    changed = sorted(k for k in before['files'].keys() | after['files'].keys()
                     if before['files'].get(k) != after['files'].get(k))
    kwin = sorted(k for k in before['kwin_keys'].keys() | after['kwin_keys'].keys()
                  if before['kwin_keys'].get(k) != after['kwin_keys'].get(k))
    shortcuts = ['kwin/' + k for k in RESTORED_SHORTCUTS
                 if before['shortcut_keys'].get('kwin/' + k) != after['shortcut_keys'].get('kwin/' + k)]
    return {'changed_files_review_locally': changed, 'unrestored_kwin_keys': kwin,
            'unrestored_shortcut_keys': shortcuts,
            'restoration_pass': not kwin and not shortcuts and not after['pending_kwin_backup']
                                and not after['pending_shortcuts_backup'],
            'scope': 'Allowlisted config only. Other changes require manual inventory; see README.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['baseline', 'after-singlr', 'after-remove', 'after-plasma'])
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('No sobrescribe evidencia')
    data = snapshot() | {'phase': args.phase}
    success = True
    if args.phase != 'baseline':
        if not args.baseline:
            parser.error('Falta --baseline')
        before = json.loads(args.baseline.read_text())
        if before.get('phase') != 'baseline':
            parser.error('No es un baseline')
        data['comparison'] = compare(before, data)
        success = data['comparison']['restoration_pass']
    if args.phase in ('after-remove', 'after-plasma'):
        absent = subprocess.run(['pacman', '-Q', 'singlr-desktop'], capture_output=True).returncode == 1
        data['package_removed'] = absent
        residue = [str(p) for p in (Path('/usr/bin/singlr-doctor'), Path('/usr/lib/singlr'),
                    Path('/usr/share/wayland-sessions/singlr.desktop'),
                    Path('/usr/lib/systemd/user/singlr-shell.service'),
                    Path('/usr/lib/systemd/user/plasma-kwin_wayland.service.d/50-singlr-recovery.conf')) if p.exists()]
        data['package_residue'] = residue
        success &= absent and not residue and not data['singlr_appearance_references']
    if args.phase == 'after-plasma':
        plasma = os.environ.get('XDG_CURRENT_DESKTOP') == 'KDE'
        p = subprocess.run(['systemctl', '--user', 'is-active', 'plasma-plasmashell.service'], capture_output=True)
        data['plasma_active'] = plasma and p.returncode == 0
        success &= data['plasma_active']
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        json.dump(data, stream, indent=2)
        stream.write('\n')
    print('PASS alcance automático' if success else 'FAIL: revisar informe local')
    return 0 if success else 1


if __name__ == '__main__':
    raise SystemExit(main())
