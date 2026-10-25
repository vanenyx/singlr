#!/usr/bin/env python3
"""Isolated Qt 6 prototype runner; no installation or session configuration writes."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ERROR = re.compile(r'file:[^\n]*:[0-9]+:[0-9]+:|SINGLR_ERROR|(?:Error|Warning):|ReferenceError:|TypeError:|SyntaxError:|is not (?:installed|a type)|Cannot (?:assign|load)|Unable to assign|Binding loop|Failed to (?:create|load)', re.I)


def stop(process):
    if process is None:
        return
    # Kill the entire owned group, including descendants after leader exit.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()


def isolated_environment(base):
    """Keep system imports/applications, isolate every persistent XDG write."""
    env = os.environ.copy()
    # Native Singlr.System QML module from the development CMake build.
    module_path = str(HERE.parent / 'build/qml')
    env['QML_IMPORT_PATH'] = module_path + (':' + env['QML_IMPORT_PATH'] if env.get('QML_IMPORT_PATH') else '')
    for key, subdir in [('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'),
                        ('XDG_DATA_HOME', 'data'), ('XDG_STATE_HOME', 'state')]:
        path = base / subdir
        path.mkdir(mode=0o700)
        env[key] = str(path)
    return env


def run(source, mode, output=None, size=None, duration=0):
    qml = shutil.which('qml6')
    if not qml:
        raise RuntimeError('qml6 missing (Arch: qt6-declarative)')
    with tempfile.TemporaryDirectory(prefix='singlr-runtime-') as directory:
        base = Path(directory)
        env = isolated_environment(base)
        env['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
        env['QT_QPA_PLATFORMTHEME'] = ''
        env['QT_WAYLAND_SHELL_INTEGRATION'] = 'xdg-shell'
        env['QSG_INFO'] = '1'
        env['QT_FORCE_STDERR_LOGGING'] = '1'
        env['QT_LOGGING_RULES'] = env.get('QT_LOGGING_RULES', '') + ';qt.rhi.*=true'
        options = dict(source=source.as_uri(), duration=duration)
        if size:
            options.update(width=size[0], height=size[1])
        if output:
            options['capture'] = str(output)
        compositor = client = None
        try:
            if mode == 'nested':
                if not shutil.which('kwin_wayland') or not shutil.which('dbus-run-session'):
                    raise RuntimeError('nested requires kwin and dbus-run-session (Arch: kwin, dbus)')
                parent = env.get('WAYLAND_DISPLAY', '')
                if not parent:
                    raise RuntimeError('nested requires a parent Wayland display')
                if not parent.startswith('/'):
                    parent = str(Path(env.get('XDG_RUNTIME_DIR', '')) / parent)
                runtime = base / 'runtime'
                runtime.mkdir(mode=0o700)
                env['XDG_RUNTIME_DIR'] = str(runtime)
                env['QT_QPA_PLATFORM'] = 'wayland'
                env['WAYLAND_DISPLAY'] = parent
                # Private bus, config, runtime/socket and disabled host integrations.
                command = ['dbus-run-session', '--', 'bash', str(HERE / 'nested-session.sh'),
                           str(base / 'bus-address'),
                           '--wayland-display', parent, '--socket', 'singlr-wayland',
                           '--width', '2048', '--height', '1280', '--scale', '1',
                           '--no-lockscreen', '--no-global-shortcuts', '--no-kactivities']
                compositor = subprocess.Popen(command, env=env, start_new_session=True)
                deadline = time.monotonic() + 12
                while not (runtime / 'singlr-wayland').exists():
                    if compositor.poll() is not None:
                        raise RuntimeError(f'nested compositor exited {compositor.returncode} before socket ready')
                    if time.monotonic() > deadline:
                        raise RuntimeError('nested compositor socket timeout')
                    time.sleep(0.1)
                env['WAYLAND_DISPLAY'] = 'singlr-wayland'
                env['DBUS_SESSION_BUS_ADDRESS'] = (base / 'bus-address').read_text()
            elif mode == 'capture':
                env['QT_QPA_PLATFORM'] = 'offscreen'
            else:
                env['QT_QPA_PLATFORM'] = 'wayland' if env.get('WAYLAND_DISPLAY') else 'xcb'
            command = [qml, str(HERE / 'PrototypeHost.qml'), '--', json.dumps(options)]
            client = subprocess.Popen(command, env=env, start_new_session=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            try:
                log, _ = client.communicate(timeout=20 if mode == 'capture' else (duration / 1000 + 15 if duration else None))
            except subprocess.TimeoutExpired:
                stop(client)
                log, _ = client.communicate()
                print(log, end='')
                raise RuntimeError('prototype timed out')
            print(log, end='')
            if 'Loading backend software' in log:
                print('SINGLR_NOTICE software renderer: shader effects unavailable')
            if client.returncode or ERROR.search(log) or 'SINGLR_LOADED' not in log:
                return 1
            if output and ('SINGLR_CAPTURE' not in log or not output.is_file()):
                return 1
            return 0
        finally:
            stop(client)
            stop(compositor)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('source', type=Path)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--window', action='store_true')
    modes.add_argument('--nested', action='store_true')
    modes.add_argument('--capture', type=Path)
    parser.add_argument('--size', help='logical pixels, e.g. 2048x1280')
    args = parser.parse_args()
    source = args.source.resolve()
    if args.check:
        if not source.is_dir():
            parser.error('--check requires a directory')
        # Root entrypoints: immediate .qml files. Put reusable components in subdirs.
        roots = sorted(source.glob('*.qml'))
        if not roots:
            parser.error('no QML roots in directory')
        lint = Path('/usr/lib/qt6/bin/qmllint')
        failed = False
        with tempfile.TemporaryDirectory(prefix='singlr-check-') as directory:
            for index, root in enumerate(roots):
                if lint.is_file():
                    result = subprocess.run([str(lint), '-I', '/usr/lib/qt6/qml', str(root)])
                    root_failed = result.returncode != 0
                else:
                    root_failed = False
                root_failed |= run(root, 'capture', Path(directory) / f'{index}.png', (2048, 1280)) != 0
                failed |= root_failed
                print(f'CHECK {root.name}: {"FAIL" if root_failed else "PASS"}')
        return int(failed)
    if not source.is_file():
        parser.error('QML file does not exist')
    size = None
    if args.size:
        match = re.fullmatch(r'([1-9][0-9]*)[xX]([1-9][0-9]*)', args.size)
        if not match:
            parser.error('--size must be WxH with positive integers')
        size = tuple(map(int, match.groups()))
    if args.capture and not size:
        parser.error('--capture requires --size WxH')
    output = args.capture.resolve() if args.capture else None
    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
    duration = int(os.environ.get('SINGLR_DURATION_MS', '0'))
    return run(source, 'capture' if output else ('nested' if args.nested else 'window'), output, size, duration)


def interrupted(signum, frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(main())
    except (RuntimeError, OSError, ValueError) as error:
        print(f'SINGLR_ERROR {error}', file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
