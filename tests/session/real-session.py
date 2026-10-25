#!/usr/bin/env python3
"""T247: pruebas sobre Singlr instalado. No inicia ni modifica Plasma ajeno."""
import argparse
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


ALLOW_DEVELOPMENT = False

def run(*args, timeout=8):
    p = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError('Comando no disponible/fallido: ' + args[0])
    return p.stdout.strip()


def prop(unit, key):
    return run('systemctl', '--user', 'show', unit, '-p', key, '--value')


def pid(unit):
    return int(prop(unit, 'MainPID'))


def identity(unit):
    p = pid(unit)
    # Start time disambiguates PID reuse; no command line or user data in evidence.
    return [p, Path(f'/proc/{p}/stat').read_text().rsplit(')', 1)[1].split()[19]]


def owner(name):
    return int(run('qdbus6', 'org.freedesktop.DBus', '/org/freedesktop/DBus',
                   'org.freedesktop.DBus.GetConnectionUnixProcessID', name))


def ready():
    p = pid('singlr-shell.service')
    return p > 0 and all(owner(n) == p for n in ('org.kde.plasmashell', 'org.kde.krunner'))


def wait_for(check, seconds=15):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        try:
            if check():
                return
        except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired):
            pass
        time.sleep(.05)
    raise RuntimeError('Tiempo agotado esperando comprobación')


def startup():
    if os.geteuid() == 0 or os.environ.get('XDG_SESSION_TYPE') != 'wayland' or 'Singlr' not in os.environ.get('XDG_CURRENT_DESKTOP', '').split(':'):
        raise RuntimeError('Requiere terminal del usuario de prueba dentro de Singlr Wayland')
    run('pacman', '-Q', 'singlr-desktop')
    for u in ('singlr-workspace.target', 'graphical-session.target', 'singlr-shell.service',
              'plasma-kwin_wayland.service', 'plasma-ksmserver.service', 'plasma-kded6.service'):
        if prop(u, 'ActiveState') != 'active':
            raise RuntimeError('Unidad inactiva: ' + u)
    for proc in Path('/proc').iterdir():
        if proc.name.isdigit():
            try:
                if proc.stat().st_uid == os.getuid() and (proc / 'comm').read_text().strip() in ('plasmashell', 'krunner'):
                    raise RuntimeError('Otro shell/KRunner activo')
            except (FileNotFoundError, PermissionError, ProcessLookupError):
                pass
    env = dict(x.split('=', 1) for x in run('systemctl', '--user', 'show-environment').splitlines() if '=' in x)
    shell_env = dict(x.decode().split('=', 1) for x in Path(f'/proc/{pid("singlr-shell.service")}/environ').read_bytes().split(b'\0') if b'=' in x)
    if shell_env.get('SINGLR_DEV_ROOT') and not ALLOW_DEVELOPMENT:
        raise RuntimeError('Canal de desarrollo activo: desactivar en usuario de prueba o indicar --allow-development (no acredita paquete)')
    expected = {'XDG_SESSION_TYPE': 'wayland', 'XDG_SESSION_DESKTOP': 'Singlr',
                'XDG_CURRENT_DESKTOP': 'Singlr:KDE', 'PLASMA_DEFAULT_SHELL': 'org.singlr.desktop',
                'KDE_FULL_SESSION': 'true', 'KDE_SESSION_VERSION': '6'}
    if any(env.get(k) != v or shell_env.get(k) != v for k, v in expected.items()):
        raise RuntimeError('Entorno de gestor/shell incorrecto')
    if not env.get('WAYLAND_DISPLAY') or not env.get('SESSION_MANAGER'):
        raise RuntimeError('Falta display real o SESSION_MANAGER')
    if os.environ.get('WAYLAND_DISPLAY') != shell_env.get('WAYLAND_DISPLAY') or env.get('WAYLAND_DISPLAY') != shell_env.get('WAYLAND_DISPLAY'):
        raise RuntimeError('Terminal y shell pertenecen a displays distintos')
    session_id = os.environ.get('XDG_SESSION_ID', '')
    if not session_id or run('loginctl', 'show-session', session_id, '-p', 'Type', '--value') != 'wayland':
        raise RuntimeError('No hay login Wayland real de logind')
    if not ready():
        raise RuntimeError('Nombres D-Bus no pertenecen al shell')
    return {u: identity(u) for u in ('singlr-shell.service', 'plasma-kwin_wayland.service', 'plasma-ksmserver.service')}


def unchanged(before, shell=True):
    after = startup()
    for u, value in before.items():
        if (shell or u != 'singlr-shell.service') and after[u] != value:
            raise RuntimeError('Proceso de sesión reemplazado: ' + u)
    return after


def journal(since):
    raw = run('journalctl', '--user', '-b', '--since=@' + str(since), '-o', 'json',
              '--no-pager', '_COMM=kscreenlocker_g')
    return [json.loads(line) for line in raw.splitlines() if line.strip()]


def lock(before):
    active = lambda: run('qdbus6', 'org.freedesktop.ScreenSaver', '/ScreenSaver',
                         'org.freedesktop.ScreenSaver.GetActive') == 'true'
    if active():
        raise RuntimeError('Debe comenzar desbloqueado')
    start = time.time()
    run('qdbus6', 'org.freedesktop.ScreenSaver', '/ScreenSaver', 'org.freedesktop.ScreenSaver.Lock')
    wait_for(active)
    # Constant marker emitted only by our real LockScreenUi root when instantiated.
    wait_for(lambda: any('SINGLR_LOCKSCREEN_READY' in str(r.get('MESSAGE', '')) for r in journal(start)))
    print('Desbloquear en el greeter con el creador; no introducir contraseña en la terminal.', flush=True)
    wait_for(lambda: not active(), 180)
    rows = journal(start)
    if any(any(s in str(r.get('MESSAGE', '')).lower() for s in ('falling back', 'fallbacktheme', 'qml outdated', 'failed to load lockscreen')) for r in rows):
        raise RuntimeError('Fallback del greeter detectado')
    unchanged(before)
    return {'own_qml_instantiated': True, 'unlocked': True, 'fallback_detected': False}


def crash(before, burst=False):
    unit = 'singlr-shell.service'
    if prop(unit, 'StartLimitBurst') != '3' or prop(unit, 'StartLimitIntervalUSec') != '1min' or prop(unit, 'Restart') != 'on-failure':
        raise RuntimeError('Política distinta a Restart=on-failure, 3 inicios / 60 s')
    # Do not rewrite the production policy. Clear only its test counter.
    run('systemctl', '--user', 'reset-failed', unit)
    times = []
    try:
        for _ in range(5 if burst else 1):
            old = pid(unit)
            if not old:
                break
            start = time.monotonic()
            os.kill(old, signal.SIGKILL)
            if burst:
                wait_for(lambda: prop(unit, 'Result') == 'start-limit-hit' or (pid(unit) != old and ready()))
                if prop(unit, 'Result') == 'start-limit-hit':
                    break
            else:
                wait_for(lambda: pid(unit) != old and ready(), 3)
                elapsed = time.monotonic() - start
                if elapsed >= 3:
                    raise RuntimeError('Recuperación D-Bus fuera del umbral <3 s')
                times.append(round(elapsed, 4))
        if burst:
            wait_for(lambda: prop(unit, 'Result') == 'start-limit-hit')
            if prop(unit, 'ActiveState') != 'failed':
                raise RuntimeError('No se detuvo la ráfaga')
            wait_for(lambda: prop('singlr-shell-failed.service', 'ActiveState') in ('active', 'activating'))
        unchanged(before, shell=False) if not burst else None
        for u in ('plasma-kwin_wayland.service', 'plasma-ksmserver.service'):
            if identity(u) != before[u] or prop('singlr-workspace.target', 'ActiveState') != 'active':
                raise RuntimeError('La caída perdió la sesión')
        return {'dbus_recovery_seconds': times, 'burst_limited': burst,
                'visual_recovery': 'PENDING: revisar barra/dock e interacción'}
    finally:
        run('systemctl', '--user', 'reset-failed', unit)
        run('systemctl', '--user', 'start', unit)
        wait_for(ready)
        # OnFailure can have an open kdialog. Stop just the owned test notification.
        run('systemctl', '--user', 'stop', 'singlr-shell-failed.service')


def restore_outputs(enabled):
    rotations = {1: 'normal', 2: 'left', 4: 'inverted', 8: 'right', 16: 'flipped',
                 32: 'flipped90', 64: 'flipped180', 128: 'flipped270'}
    args = []
    for o in enabled:
        prefix = 'output.' + str(o['id']) + '.'
        args += [prefix + 'enable', prefix + 'mode.' + str(o['currentModeId']),
                 prefix + 'position.' + str(o['pos']['x']) + ',' + str(o['pos']['y']),
                 prefix + 'scale.' + str(o['scale']), prefix + 'rotation.' + rotations[o['rotation']]]
    return args


def outputs(before, output):
    data = json.loads(run('kscreen-doctor', '-j'))
    enabled = [o for o in data['outputs'] if o.get('enabled') and o.get('connected')]
    if len(enabled) < 2 or output not in [str(o['id']) for o in enabled]:
        raise RuntimeError('Requiere >=2 salidas conectadas/activas y --output-id válido; conserva una salida')
    def state():
        return next(o['enabled'] for o in json.loads(run('kscreen-doctor', '-j'))['outputs'] if str(o['id']) == output)
    restore = restore_outputs(enabled)  # Validate schema before any mutation.
    # Independent watchdog also re-enables after terminal death; finally is the normal cleanup.
    watchdog = subprocess.Popen([sys.executable, '-c',
        'import subprocess,time; time.sleep(15); subprocess.run(' + repr(['kscreen-doctor', *restore]) + ',stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)'], start_new_session=True)
    try:
        run('kscreen-doctor', 'output.' + output + '.disable')
        wait_for(lambda: not state())
        time.sleep(2)
        unchanged(before)
    finally:
        run('kscreen-doctor', *restore)
        wait_for(state)
        restored = json.loads(run('kscreen-doctor', '-j'))['outputs']
        actual = {str(o['id']): o for o in restored}
        if any(any(actual[str(o['id'])].get(k) != o.get(k) for k in ('enabled', 'pos', 'scale', 'rotation', 'currentModeId')) for o in enabled):
            raise RuntimeError('La topología no quedó restaurada; watchdog reintentará')
        watchdog.terminate()
        watchdog.wait()
    unchanged(before)
    return {'removed_and_returned': True, 'physical_suspend': 'NOT TESTED',
            'zero_outputs': 'NOT TESTED: KWin mantiene la última salida',
            'visual_topology': 'PENDING: barra/fondo por salida, un dock, apps utilizables'}


def save(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as stream:
        json.dump(data, stream, indent=2)
        stream.write('\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['startup', 'lock', 'crash', 'burst', 'reexec', 'outputs',
                                       'continuity-before', 'continuity-after', 'logout-before', 'logout-after'])
    parser.add_argument('--allow-development', action='store_true', help='diagnóstico adicional; no acredita el shell del paquete')
    parser.add_argument('--execute', action='store_true', help='ejecutar acción que interrumpe la sesión de prueba')
    parser.add_argument('--evidence', required=True, type=Path, help='JSON nuevo, nunca sobrescrito')
    parser.add_argument('--before', type=Path, help='evidencia de fase anterior')
    parser.add_argument('--output-id', default='')
    args = parser.parse_args()
    global ALLOW_DEVELOPMENT
    ALLOW_DEVELOPMENT = args.allow_development
    if args.evidence.exists():
        parser.error('La evidencia ya existe')
    mutation = args.case in ('lock', 'crash', 'burst', 'reexec', 'outputs')
    if mutation and not args.execute:
        parser.error('Esta acción requiere --execute dentro del usuario de prueba')
    result = {'development_allowed': args.allow_development, 'case': args.case, 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    try:
        before = startup()
        result['processes'] = before
        if args.case == 'lock':
            result['checks'] = lock(before)
        elif args.case in ('crash', 'burst'):
            result['checks'] = crash(before, args.case == 'burst')
        elif args.case == 'reexec':
            run('systemctl', '--user', 'daemon-reexec', timeout=60)
            wait_for(lambda: prop('singlr-workspace.target', 'ActiveState') == 'active', 60)
            unchanged(before)
        elif args.case == 'outputs':
            result['checks'] = outputs(before, args.output_id)
        elif args.case.endswith('-after'):
            if not args.before:
                raise RuntimeError('Falta --before')
            previous = json.loads(args.before.read_text())
            expected = args.case.replace('-after', '-before')
            if previous.get('case') != expected or previous.get('result') != 'PASS':
                raise RuntimeError('Evidencia previa incorrecta')
            if args.case == 'continuity-after':
                unchanged(previous['processes'])
                run('pacman', '-Q', 'singlr-session-probe')
            elif any(before[u] == previous['processes'][u] for u in before):
                raise RuntimeError('No hubo nueva sesión completa')
            else:
                result['manual'] = 'PENDING: verificar documento guardado y restaurado automáticamente (README)'
        elif args.case == 'continuity-before':
            p = subprocess.run(['pacman', '-Q', 'singlr-session-probe'], capture_output=True)
            if p.returncode == 0:
                raise RuntimeError('El paquete de prueba ya está instalado')
        result['result'] = 'PASS'
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError) as error:
        result['result'] = 'FAIL'
        # No raw subprocess output or arbitrary exception strings in attachable evidence.
        print(str(error), file=sys.stderr)
    save(args.evidence, result)
    print(result['case'] + ': ' + result['result'])
    return 0 if result['result'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
