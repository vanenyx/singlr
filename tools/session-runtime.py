#!/usr/bin/env python3
"""Run a real Singlr shell on a private, nested KWin; never use the host bus."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
runtime = runpy.run_path(str(HERE / 'prototype-runtime.py'))
stop = runtime['stop']


def interrupt(signum, frame):
    raise KeyboardInterrupt


def config_hashes():
    home = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config')))
    paths = set()
    for pattern in ('k*', 'plasma*', 'dolphin*'):
        for entry in home.glob(pattern):
            paths.update(entry.rglob('*') if entry.is_dir() else [entry])
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths) if p.is_file()}


def descendants():
    """Subreaper adoption also covers KIO double forks and new process groups."""
    parents = {}
    for directory in Path('/proc').iterdir():
        if directory.name.isdigit():
            try:
                fields = (directory / 'stat').read_text().rsplit(')', 1)[1].split()
                parents[int(directory.name)] = (int(fields[1]), fields[0])
            except (OSError, ValueError, IndexError):
                pass
    owned = {os.getpid()}
    while True:
        more = {pid for pid, (ppid, state) in parents.items() if ppid in owned}
        if more <= owned:
            break
        owned |= more
    return {pid for pid in owned - {os.getpid()} if parents[pid][1] != 'Z'}


def marked_processes(session_id):
    """Find external clients too; exact NUL-delimited environment marker, never cmdline."""
    marker = f'SINGLR_SESSION_ID={session_id}'.encode()
    found = set()
    for directory in Path('/proc').iterdir():
        if not directory.name.isdigit() or int(directory.name) == os.getpid():
            continue
        try:
            if marker in (directory / 'environ').read_bytes().split(b'\0'):
                # Zombies cannot be signalled and must be reaped by their own parent.
                state = (directory / 'stat').read_text().rsplit(')', 1)[1].split()[0]
                if state != 'Z':
                    found.add(int(directory.name))
        except (OSError, ValueError, IndexError):
            pass
    return found


def is_zombie(pid):
    # Un zombi ya terminó: solo espera a que su padre (ajeno) lo recoja.
    try:
        return Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()[0] == 'Z'
    except (OSError, IndexError):
        return True


def clean_children(grace=1.5, session_id=None):
    for sig, delay in ((signal.SIGTERM, grace), (signal.SIGKILL, 0.5)):
        signalled = set()
        deadline = time.monotonic() + delay
        while True:
            remaining = descendants() | (marked_processes(session_id) if session_id else set())
            for pid in remaining - signalled:
                try:
                    os.kill(pid, sig)
                    signalled.add(pid)
                except ProcessLookupError:
                    pass
            # Reap adopted detached children, without racing Popen.wait().
            while True:
                try:
                    if os.waitpid(-1, os.WNOHANG)[0] == 0:
                        break
                except ChildProcessError:
                    break
            if not remaining or time.monotonic() >= deadline:
                break
            time.sleep(0.05)
    remaining = {pid for pid in descendants() | (marked_processes(session_id) if session_id else set())
                 if not is_zombie(pid)}
    names = {pid: Path(f'/proc/{pid}/comm').read_text().strip() if Path(f'/proc/{pid}/comm').exists() else '?' for pid in remaining}
    print(f'SINGLR_CLEANUP remaining={sorted(remaining)} {names}', flush=True)
    return not remaining


def save_descriptor(path, env, shell_pid=None):
    keys = [k for k in env if k.startswith(('XDG_', 'LC_')) or k in (
        'LANG', 'LANGUAGE',
        'DBUS_SESSION_BUS_ADDRESS', 'WAYLAND_DISPLAY', 'QT_QPA_PLATFORM',
        'QT_QPA_PLATFORMTHEME', 'KDE_SESSION_VERSION', 'KDE_FULL_SESSION',
        '_KDE_APPLICATIONS_AS_FORKING', 'SINGLR_SESSION_ID')]
    data = dict(kind='singlr-nested-v1', pid=os.getpid(), shell_pid=shell_pid,
                env={k: env[k] for k in keys})
    temporary = path.with_name(path.name + '.tmp')
    with temporary.open('x') as stream:
        os.chmod(temporary, 0o600)
        json.dump(data, stream)
    temporary.replace(path)


def capture(output, descriptor=None):
    if descriptor is None:
        selected = os.environ.get('SINGLR_SESSION_FILE')
        candidates = [Path(selected)] if selected else list(Path('/tmp').glob('singlr-session-*/session.json'))
        live = []
        for path in candidates:
            try:
                info = path.lstat()
                if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
                    continue
                data = json.loads(path.read_text())
                os.kill(data['pid'], 0)
                if data['kind'] == 'singlr-nested-v1':
                    live.append((path, data))
            except (OSError, ValueError, KeyError):
                continue
        if len(live) != 1:
            raise RuntimeError('Se requiere una sesión viva inequívoca; fija SINGLR_SESSION_FILE al JSON anunciado por run-singlr.sh')
        descriptor, data = live[0]
    else:
        data = json.loads(descriptor.read_text())
    env = os.environ.copy()
    for key in ('DISPLAY', 'WAYLAND_SOCKET', 'DBUS_STARTER_ADDRESS', 'DBUS_STARTER_BUS_TYPE',
                'QT_WAYLAND_SHELL_INTEGRATION', 'XDG_ACTIVATION_TOKEN', 'DESKTOP_STARTUP_ID'):
        env.pop(key, None)
    env.update(data['env'])
    if not shutil.which('spectacle'):
        raise RuntimeError('Falta spectacle; no se instala automáticamente')
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Use a new output to avoid mistaking a stale screenshot for success.
    with tempfile.TemporaryDirectory(prefix='singlr-shot-', dir=output.parent) as directory:
        shot = Path(directory) / 'session.png'
        process = subprocess.Popen(['spectacle', '-b', '-n', '-f', '-o', str(shot)],
                                   env=env, start_new_session=True)
        try:
            code = process.wait(timeout=25)
            if code or not shot.is_file() or shot.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
                raise RuntimeError(f'Spectacle no produjo PNG (exit={code}); revisar ScreenShot2 en el bus privado')
            shot.replace(output)
        finally:
            stop(process)
    print(f'SINGLR_SESSION_CAPTURE {output}', flush=True)


def inside(base, source, width, height, client_kind="singlr"):
    # PR_SET_CHILD_SUBREAPER, Linux: adopt and clean daemonized launchers/apps.
    if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
    env = os.environ.copy()
    if env.get('SINGLR_SESSION_ID') != base.name or not env.get('DBUS_SESSION_BUS_ADDRESS'):
        raise RuntimeError('--inside requiere el entorno privado creado por run-singlr.sh')
    parent = env.pop('SINGLR_PARENT_WAYLAND')
    compositor = client = None
    descriptor = base / 'session.json'
    result = 1
    try:
        compositor_env = env.copy()
        compositor_env['WAYLAND_DISPLAY'] = parent
        compositor = subprocess.Popen([
            'kwin_wayland', '--wayland-display', parent, '--socket', 'singlr-wayland',
            '--width', str(width), '--height', str(height), '--scale', '1', '--output-count', os.environ.get('SINGLR_OUTPUTS', '1'),
            '--no-lockscreen', '--no-global-shortcuts', '--no-kactivities'], env=compositor_env)
        deadline = time.monotonic() + 15
        socket = Path(env['XDG_RUNTIME_DIR']) / 'singlr-wayland'
        while not socket.exists():
            if compositor.poll() is not None:
                raise RuntimeError(f'KWin terminó antes de crear el socket (exit={compositor.returncode})')
            if time.monotonic() > deadline:
                raise RuntimeError('Timeout esperando el socket de KWin anidado')
            time.sleep(0.1)
        env['WAYLAND_DISPLAY'] = 'singlr-wayland'
        # D-Bus activation must inherit the nested display, not the host socket.
        subprocess.run(['dbus-update-activation-environment',
                        *[key for key in env if key.startswith(('XDG_', 'QT_', 'KDE_', '_KDE_'))
                          or key.startswith('LC_') or key in ('WAYLAND_DISPLAY', 'SINGLR_SESSION_ID', 'LANG', 'LANGUAGE')]], env=env, check=True)
        client_env = env.copy()
        if env.get('SINGLR_WAYLAND_DEBUG'):
            client_env['WAYLAND_DEBUG'] = '1'
        # Hold the private compositor/bus open while an external supervisor
        # exercises shell crash/restart. The default runner follows its client.
        command = (['sleep', 'infinity'] if client_kind == 'none' else
                   ['plasmashell'] if client_kind == 'plasma' else
                   [str(ROOT / 'shell/session/qml-shell'), str(source)])
        client = subprocess.Popen(command, env=client_env)
        save_descriptor(descriptor, env, None if client_kind == 'none' else client.pid)
        print(f'SINGLR_SESSION_FILE={descriptor}', flush=True)
        duration = int(env.get('SINGLR_DURATION_MS', '0')) / 1000
        deadline = time.monotonic() + duration if duration else None
        while client.poll() is None and compositor.poll() is None:
            if deadline and time.monotonic() >= deadline:
                result = 0
                break
            time.sleep(0.1)
        else:
            result = client.returncode if client.returncode is not None else compositor.returncode
    finally:
        descriptor.unlink(missing_ok=True)
        # All descendants belong to this private bus; includes clients that setsid().
        ok = clean_children()
        # KWin puede tardar más que el margen en salir tras SIGKILL; se espera a que termine.
        if compositor is not None:
            try:
                compositor.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            ok = ok or not {pid for pid in descendants() if not is_zombie(pid)}
        if not ok:
            result = 1
    return result


def launch(source, size, client_kind="singlr"):
    for command in (('sleep' if client_kind == 'none' else 'plasmashell' if client_kind == 'plasma' else 'qml6'),
                    'kwin_wayland', 'dbus-run-session', 'dbus-update-activation-environment'):
        if not shutil.which(command):
            raise RuntimeError(f'Falta herramienta requerida: {command}')
    parent = os.environ.get('WAYLAND_DISPLAY')
    if not parent:
        raise RuntimeError('Se requiere una sesión Wayland anfitriona; ejecutar fuera del sandbox')
    if not parent.startswith('/'):
        parent = str(Path(os.environ.get('XDG_RUNTIME_DIR', '/nonexistent')) / parent)
    if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
    before = config_hashes()
    code = 1
    try:
        with tempfile.TemporaryDirectory(prefix='singlr-session-') as directory:
            base = Path(directory)
            env = runtime['isolated_environment'](base)
            # Explicit fixture only: never copy the user's desktop preferences.
            if client_kind != 'plasma' and os.environ.get('SINGLR_TEST_WALLPAPER'):
                wallpaper = Path(os.environ['SINGLR_TEST_WALLPAPER']).resolve(strict=True)
                config = Path(env['XDG_CONFIG_HOME']) / 'singlr/singlr.conf'
                config.parent.mkdir()
                config.write_text('[Appearance]\nwallpaper=' + wallpaper.as_uri() + '\n')
            for key in ('DISPLAY', 'WAYLAND_SOCKET', 'DBUS_SESSION_BUS_ADDRESS', 'DBUS_STARTER_ADDRESS',
                        'DBUS_STARTER_BUS_TYPE', 'SESSION_MANAGER', 'QT_WAYLAND_SHELL_INTEGRATION',
                        'XDG_ACTIVATION_TOKEN', 'DESKTOP_STARTUP_ID', '_KDE_APPLICATIONS_AS_SERVICE',
                        '_KDE_APPLICATIONS_AS_SCOPE'):
                env.pop(key, None)
            xdg_runtime = base / 'runtime'
            xdg_runtime.mkdir(mode=0o700)
            env.update(XDG_RUNTIME_DIR=str(xdg_runtime), WAYLAND_DISPLAY='singlr-wayland',
                       SINGLR_PARENT_WAYLAND=parent, SINGLR_SESSION_ID=base.name,
                       # SINGLR_EXTRA_DATA_DIRS antepone rutas (efectos de KWin, temas) para probarlos aislados.
                       XDG_DATA_DIRS=':'.join(filter(None, [os.environ.get('SINGLR_EXTRA_DATA_DIRS', ''), '/usr/local/share:/usr/share'])),
                       XDG_CONFIG_DIRS='/etc/xdg',
                       XDG_CURRENT_DESKTOP='KDE', XDG_SESSION_DESKTOP='Singlr', XDG_SESSION_TYPE='wayland',
                       QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='kde',
                       KDE_FULL_SESSION='true', KDE_SESSION_VERSION='6',
                       _KDE_APPLICATIONS_AS_FORKING='1', QT_FORCE_STDERR_LOGGING='1')
            process = subprocess.Popen(['dbus-run-session', '--', 'bash', str(HERE / 'nested-session.sh'),
                                        str(base / 'bus-address'), '--command', sys.executable, str(Path(__file__).resolve()),
                                        '--inside', str(base), '--entry', str(source), '--size', size,
                                        '--client', client_kind],
                                       env=env, start_new_session=True)
            try:
                code = process.wait()
            finally:
                # Also adopt descendants if the bus/controller has already exited.
                if not clean_children(grace=3, session_id=base.name):
                    code = 1
    finally:
        after = config_hashes()
        changed = sorted(key for key in before.keys() | after.keys() if before.get(key) != after.get(key))
        print(f'SINGLR_HOST_CONFIG files_before={len(before)} files_after={len(after)} equal={not changed}', flush=True)
        if changed:
            print('SINGLR_HOST_CONFIG_CHANGED ' + json.dumps(changed), flush=True)
            code = 1
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--size', default='2048x1280')
    parser.add_argument('--client', choices=('singlr', 'plasma', 'none'), default='singlr',
                        help='Cliente del compositor privado; Plasma usa configuración temporal limpia')
    parser.add_argument('--entry', type=Path, default=ROOT / 'shell/qml/Shell.qml')
    parser.add_argument('--duration', type=float, help='Duración en segundos; sin opción, hasta cerrar KWin o Ctrl+C')
    parser.add_argument('--inside', type=Path, help=argparse.SUPPRESS)
    parser.add_argument('--capture-session', type=Path, metavar='SALIDA.png')
    args = parser.parse_args()
    if args.duration is not None:
        if not 0 < args.duration < float('inf'):
            parser.error('--duration debe ser un número positivo finito')
        os.environ['SINGLR_DURATION_MS'] = str(max(1, round(args.duration * 1000)))
    if args.capture_session:
        capture(args.capture_session)
        return 0
    if args.client == 'singlr' and not args.entry.is_file():
        parser.error(f'No existe el punto de entrada QML: {args.entry}; integra shell/qml/Shell.qml o usa --entry archivo.qml')
    match = re.fullmatch(r'([1-9][0-9]*)[xX]([1-9][0-9]*)', args.size)
    if not match:
        parser.error('--size debe ser WxH con enteros positivos')
    if args.inside:
        return inside(args.inside, args.entry.resolve(), *map(int, match.groups()), args.client)
    return launch(args.entry.resolve(), args.size.lower(), args.client)


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrupt)
    signal.signal(signal.SIGINT, interrupt)
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f'SINGLR_ERROR {error}', file=sys.stderr)
        sys.exit(1)
