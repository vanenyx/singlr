#!/usr/bin/env python3
"""Hermetic offscreen native/QML regression. --before-ref stages historical sources.

This verifies dismissal policy and deferred placement, not Wayland mapping.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before-ref', help='Git revision of system.cpp/h and ScreenSurfaces.qml')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='singlr-surface-test-') as temp:
        base = Path(temp)
        env = os.environ.copy()
        for key, child in [('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data'),
                           ('XDG_RUNTIME_DIR', 'runtime'), ('XDG_CACHE_HOME', 'cache'), ('XDG_STATE_HOME', 'state')]:
            path = base / child
            path.mkdir(mode=0o700)
            env[key] = str(path)
        env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                   DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent',
                   DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent')
        build = ROOT / 'build/output-control'
        configure = ['cmake', '-S', str(Path(__file__).parent)]
        if args.before_ref:
            build = base / 'build'
            source = base / 'session'
            source.mkdir()
            for name in ('system.cpp', 'system.h'):
                (source / name).write_bytes(subprocess.check_output(
                    ['git', 'show', args.before_ref + ':shell/session/src/' + name], cwd=ROOT))
            imports = base / 'qml/Singlr'
            shell = imports / 'Shell'
            shell.mkdir(parents=True)
            (imports / 'Ui').symlink_to(ROOT / 'shell/qml/Singlr/Ui', target_is_directory=True)
            for path in (ROOT / 'shell/qml/Singlr/Shell').iterdir():
                if path.name == 'ScreenSurfaces.qml':
                    (shell / path.name).write_bytes(subprocess.check_output(
                        ['git', 'show', args.before_ref + ':shell/qml/Singlr/Shell/ScreenSurfaces.qml'], cwd=ROOT))
                else:
                    (shell / path.name).symlink_to(path)
            env['SINGLR_TEST_QML_IMPORT'] = str(base / 'qml')
            configure.append('-DSINGLR_TEST_SESSION_SRC=' + str(source))
        else:
            configure.append('-DSINGLR_TEST_SESSION_SRC=' + str(ROOT / 'shell/session/src'))
        with args.output.open('w') as log:
            subprocess.run(configure + ['-B', str(build)], check=True, stdout=log, stderr=subprocess.STDOUT)
            subprocess.run(['cmake', '--build', str(build), '--target', 'singlr-surface-lifecycle', '-j2'],
                           check=True, stdout=log, stderr=subprocess.STDOUT)
            result = subprocess.run([str(build / 'singlr-surface-lifecycle')], env=env,
                                    stdout=log, stderr=subprocess.STDOUT)
        for line in args.output.read_text().splitlines():
            if any(word in line for word in ('PASS ', 'FAIL!', 'Totals:', 'TypeError')):
                print(line)
        return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
