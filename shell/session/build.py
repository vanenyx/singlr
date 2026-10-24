#!/usr/bin/env python3
"""Small, locked, atomic incremental build; stdout contains only the executable."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def stamp(path):
    info = Path(path).stat()
    return [info.st_mtime_ns, info.st_size]


def main():
    compiler = shlex.split(os.environ.get('CXX', 'g++'))
    if not compiler or not shutil.which(compiler[0]) or not shutil.which('pkg-config'):
        raise RuntimeError('Se requieren g++ (o CXX) y pkg-config; no se instalan automáticamente')
    compiler[0] = shutil.which(compiler[0])
    flags = subprocess.run(['pkg-config', '--cflags', '--libs', 'Qt6Gui', 'Qt6Qml', 'Qt6Quick'],
                           capture_output=True, text=True)
    if flags.returncode:
        raise RuntimeError('Faltan cabeceras/metadatos de Qt6 Gui/Qml/Quick (qt6-base, qt6-declarative):\n' + flags.stderr)
    command = compiler + ['-std=c++17', '-O2', '-fPIC'] + shlex.split(os.environ.get('CXXFLAGS', ''))
    command += [str(HERE / 'src/main.cpp')] + shlex.split(flags.stdout) + ['-lLayerShellQtInterface']
    command += shlex.split(os.environ.get('LDFLAGS', ''))
    fingerprint = hashlib.sha256(json.dumps([command, stamp(compiler[0]),
                                stamp(__file__)]).encode()).hexdigest()
    build = Path(os.environ.get('SINGLR_BUILD_DIR', str(HERE / 'build'))).resolve()
    build.mkdir(parents=True, exist_ok=True)
    output, state = build / 'singlr-shell', build / 'state.json'
    with (build / '.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            previous = json.loads(state.read_text())
            if (output.is_file() and os.access(output, os.X_OK)
                    and previous['fingerprint'] == fingerprint
                    and previous['output'] == stamp(output)
                    and all(stamp(p) == value for p, value in previous['deps'].items())):
                print(output)
                return
        except (OSError, ValueError, KeyError):
            pass
        with tempfile.TemporaryDirectory(prefix='.compile-', dir=build) as directory:
            binary, deps = Path(directory) / 'singlr-shell', Path(directory) / 'deps.d'
            # -MD includes system headers: a Qt/LayerShellQt update invalidates the cache.
            result = subprocess.run(command + ['-MD', '-MF', str(deps), '-o', str(binary)],
                                    stdout=sys.stderr)
            if result.returncode:
                raise RuntimeError('No se pudo compilar el lanzador. Revise el diagnóstico anterior; '
                                   'se requieren las cabeceras Qt6 y LayerShellQt/Shell y '
                                   'libLayerShellQtInterface (layer-shell-qt). No se reutiliza un binario obsoleto.')
            paths = shlex.split(deps.read_text().replace('\\\n', '').split(':', 1)[1])
            dependencies = {str(Path(p).resolve()): stamp(p) for p in paths}
            binary.replace(output)
            temporary = build / 'state.json.tmp'
            temporary.write_text(json.dumps(dict(fingerprint=fingerprint, deps=dependencies,
                                                 output=stamp(output))))
            temporary.replace(state)
    print(output)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'SINGLR_BUILD_ERROR {error}', file=sys.stderr)
        sys.exit(1)
