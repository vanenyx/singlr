#!/usr/bin/env python3
"""Stage session metadata only. No systemctl, package installation or shell payload."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
FILES = {
    'usr/share/wayland-sessions/singlr.desktop': ('singlr.desktop', 0o644),
    'usr/lib/singlr/startsinglr-wayland': ('startsinglr-wayland', 0o755),
    'usr/lib/systemd/user/singlr-workspace.target': ('systemd/singlr-workspace.target', 0o644),
    'usr/lib/systemd/user/singlr-shell.service': ('systemd/singlr-shell.service', 0o644),
}
MANIFEST = 'usr/lib/singlr/session-install.json'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(prefix, relative):
    path = prefix / relative
    for part in (path, *path.parents):
        if part.is_symlink():
            raise RuntimeError(f'Se rechaza enlace simbólico: {part}')
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('install', 'uninstall'))
    parser.add_argument('--prefix', default='/', help='raíz de destino/staging, por defecto /')
    parser.add_argument('--dry-run', action='store_true', help='solo mostrar; no escribir ni usar systemd')
    args = parser.parse_args()
    prefix = Path(os.path.abspath(args.prefix))
    if not Path(args.prefix).is_absolute():
        parser.error('--prefix requiere una ruta absoluta')
    manifest = safe_path(prefix, MANIFEST)
    paths = {name: safe_path(prefix, name) for name in FILES}
    if args.action == 'install':
        payload = {name: (HERE / source).read_bytes() for name, (source, _) in FILES.items()}
        for path in (*paths.values(), manifest):
            if path.exists():
                raise RuntimeError(f'No se sobrescribe un archivo existente: {path}')
        for name, path in paths.items():
            print(f'install {FILES[name][1]:04o} {path}')
        print(f'manifest {manifest}')
        if args.dry_run:
            return
        created = []
        try:
            for name, path in paths.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                with path.open('xb') as stream:
                    created.append(path)
                    stream.write(payload[name])
                path.chmod(FILES[name][1])
            with manifest.open('x') as stream:
                created.append(manifest)
                json.dump({name: digest(data) for name, data in payload.items()}, stream, indent=2)
            manifest.chmod(0o644)
        except BaseException:
            for path in reversed(created):
                path.unlink()
            raise
    else:
        if not manifest.exists():
            print(f'No hay instalación administrada: {manifest}')
            return
        hashes = json.loads(manifest.read_text())
        if set(hashes) != set(FILES):
            raise RuntimeError('Manifest no reconocido; no se elimina nada')
        # Validate the complete set before removing anything, even in dry-run.
        for name, path in paths.items():
            if path.exists() and (not path.is_file() or digest(path.read_bytes()) != hashes[name]):
                raise RuntimeError(f'Archivo modificado; no se elimina nada: {path}')
        for path in (*paths.values(), manifest):
            print(f'remove {path}')
        if args.dry_run:
            return
        for path in (*paths.values(), manifest):
            path.unlink(missing_ok=True)
        try:
            (prefix / 'usr/lib/singlr').rmdir()  # Preserve future package payload and foreign files.
        except OSError:
            pass


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError) as error:
        print(f'Singlr: {error}', file=sys.stderr)
        sys.exit(1)
