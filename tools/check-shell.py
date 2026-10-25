#!/usr/bin/env python3
"""Lint and load the shell's windowed capture contract, with temporary XDG paths."""
import argparse
from pathlib import Path
import os
import runpy
import shutil
import signal
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
runtime = runpy.run_path(str(HERE / 'prototype-runtime.py'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--entry', type=Path, default=ROOT / 'shell/qml/Shell.qml')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    source = args.entry.resolve()
    if not source.is_file():
        parser.error(f'No existe {source}; integrar el punto de entrada de Codex 1 antes de verificarlo')
    lint = shutil.which('qmllint') or '/usr/lib/qt6/bin/qmllint'
    qml = shutil.which('qml6')
    if not Path(lint).is_file() or not qml:
        parser.error('Se requieren qmllint y qml6 (qt6-declarative)')
    imports = ROOT / 'shell/qml'
    with tempfile.TemporaryDirectory(prefix='singlr-shell-check-') as directory:
        base = Path(directory)
        env = runtime['isolated_environment'](base)
        env.update(QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='',
                   DBUS_SESSION_BUS_ADDRESS=f'unix:path={base}/disabled-bus',
                   DBUS_SYSTEM_BUS_ADDRESS=f'unix:path={base}/disabled-system-bus')
        env.setdefault('QT_QUICK_BACKEND', 'software')
        for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'QT_WAYLAND_SHELL_INTEGRATION'):
            env.pop(key, None)
        files = sorted(imports.rglob('*.qml')) if source == imports / 'Shell.qml' else [source]
        result = subprocess.run([lint, '-I', '/usr/lib/qt6/qml', '-I', str(ROOT / 'build/qml'), '-I', str(imports), *map(str, files)], env=env)
        if result.returncode:
            return result.returncode
        output = args.output.resolve() if args.output else base / 'shell.png'
        output.parent.mkdir(parents=True, exist_ok=True)
        # Capture into a fresh path first; never pass by observing an old PNG.
        fresh = base / 'capture.png'
        with (base / 'qml.log').open('w+') as log:
            process = subprocess.Popen([qml, '-I', str(imports), str(source), '--', '--windowed',
                                        f'--capture={fresh}'], env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                deadline = time.monotonic() + 20
                while process.poll() is None and not fresh.exists() and time.monotonic() < deadline:
                    time.sleep(0.1)
                # QML grabToImage may create the file before the write completes.
                if fresh.exists():
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        pass
                code = process.poll()
            finally:
                runtime['stop'](process)
            log.seek(0)
            content = log.read()
            print(content, end='')
        if code not in (None, 0) or runtime['ERROR'].search(content) or not fresh.exists():
            print(f'CHECK {source.name}: FAIL (lint pasó; carga/captura falló)', file=sys.stderr)
            return 1
        if fresh.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
            return 1
        shutil.copyfile(fresh, output)
        print(f'CHECK {source.name}: PASS (qmllint + carga offscreen + PNG{": " + str(output) if args.output else " temporal"})')
    return 0


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, runtime['interrupted'])
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
