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
    flags = subprocess.run(['pkg-config', '--cflags', '--libs', 'Qt6Gui', 'Qt6Qml', 'Qt6Quick', 'Qt6DBus', 'KF6WindowSystem', 'libnm'],
                           capture_output=True, text=True)
    if flags.returncode:
        raise RuntimeError('Faltan cabeceras/metadatos de Qt6 Gui/Qml/Quick o libnm (qt6-base, qt6-declarative, libnm):\n' + flags.stderr)
    command = compiler + ['-std=c++17', '-O2', '-fPIC'] + shlex.split(os.environ.get('CXXFLAGS', ''))
    command += shlex.split(flags.stdout) + [
        # KF6GlobalAccel no instala un .pc: cabeceras y biblioteca directas.
        '-I/usr/include/KF6/KGlobalAccel', '-lKF6GlobalAccel', '-lLayerShellQtInterface',
        '-I/usr/include/KF6/NetworkManagerQt', '-lKF6NetworkManagerQt',
        '-I/usr/include/KF6/KWallet', '-lKF6Wallet',
        '-I/usr/include/KF6/KService', '-I/usr/include/KF6/KConfigCore', '-lKF6Service']
    command += shlex.split(os.environ.get('LDFLAGS', ''))
    libexec = subprocess.run(['pkg-config', '--variable=libexecdir', 'Qt6Core'],
                             check=True, capture_output=True, text=True).stdout.strip()
    moc = Path(libexec) / 'moc'
    sources = sorted((HERE / 'src').glob('*.cpp'))
    fingerprint = hashlib.sha256(json.dumps([command, [str(p) for p in sources], stamp(moc), stamp(compiler[0]),
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
            generated = []
            includes = [flag for flag in command if flag.startswith(('-I', '-D'))]
            for name in ('secretagent', 'tray', 'system'):
                output_moc = Path(directory) / f'moc_{name}.cpp'
                subprocess.run([str(moc), *includes, str(HERE / f'src/{name}.h'), '-o', str(output_moc)],
                               check=True, stdout=sys.stderr)
                generated.append(output_moc)
            # One translation unit preserves one atomic compiler invocation and one
            # complete dependency file, including the moc input and system headers.
            unity = Path(directory) / 'session.cpp'
            unity.write_text(''.join(f'#include "{p}"\n' for p in [*sources, *generated]))
            # -MD includes system headers: a Qt/LayerShellQt update invalidates the cache.
            result = subprocess.run(command + [str(unity), '-MD', '-MF', str(deps), '-o', str(binary)],
                                    stdout=sys.stderr)
            if result.returncode:
                raise RuntimeError('No se pudo compilar el lanzador. Revise el diagnóstico anterior; '
                                   'se requieren las cabeceras Qt6 y LayerShellQt/Shell y '
                                   'libLayerShellQtInterface (layer-shell-qt), NetworkManagerQt y KWallet. No se reutiliza un binario obsoleto.')
            paths = shlex.split(deps.read_text().replace('\\\n', '').split(':', 1)[1])
            dependencies = {str(Path(p).resolve()): stamp(p) for p in paths
                            if Path(p).resolve().parent != Path(directory).resolve()}
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
