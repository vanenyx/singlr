#!/usr/bin/env python3
"""OUTSIDE SANDBOX: real nested shell, KWin, Milou/Dolphin, TasksModel, PNGs, cleanup."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import runpy
import shutil
import signal
import struct
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
runtime = runpy.run_path(str(ROOT / 'tools/session-runtime.py'))
STEPS = ('dependencias', 'session.json', 'locale', 'superficies KWin', 'PNG escritorio',
         'Milou lanza Dolphin', 'Dolphin en KWin', 'Dolphin en TasksModel',
         'PNG Dolphin', 'cierre por duración', 'procesos eliminados', 'configuración host')


def wait_for(predicate, process, seconds=25):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        if process.poll() is not None:
            raise RuntimeError(f'La sesión terminó prematuramente (exit={process.returncode})')
        time.sleep(0.2)
    raise RuntimeError(f'Timeout ({seconds}s)')


def session_environment(data):
    env = os.environ.copy()
    for key in ('DISPLAY', 'WAYLAND_SOCKET', 'DBUS_STARTER_ADDRESS', 'DBUS_STARTER_BUS_TYPE',
                'QT_WAYLAND_SHELL_INTEGRATION', 'XDG_ACTIVATION_TOKEN', 'DESKTOP_STARTUP_ID'):
        env.pop(key, None)
    env.update(data['env'])
    return env


def kwin_snapshot(env, base, session_log):
    """Fresh KWin snapshot, namespaced by a unique marker; unload after each query.

    API: https://develop.kde.org/docs/plasma/kwin/api/ (windowList,
    resourceClass/resourceName, caption, pid, frameGeometry); KWin 6.8.1.
    D-Bus script path follows the interface verified by Claude on this host.
    """
    marker = 'T204_WINDOWS_' + uuid.uuid4().hex
    script = base / 'windows.js'
    script.write_text('print(' + json.dumps(marker) + ''' + JSON.stringify(workspace.windowList().map(function(w) {
        return {resourceClass: String(w.resourceClass), resourceName: String(w.resourceName),
                caption: String(w.caption), pid: w.pid, layer: w.layer, hidden: w.hidden,
                x: w.frameGeometry.x, y: w.frameGeometry.y, width: w.frameGeometry.width, height: w.frameGeometry.height};
    })));
''')
    def call(path, *args):
        result = subprocess.run(['qdbus6', 'org.kde.KWin', path, *args], env=env,
                                capture_output=True, text=True, timeout=5)
        if result.returncode:
            raise RuntimeError('KWin scripting: ' + result.stderr.strip())
        return result.stdout.strip()
    # KWin publica /Scripting en el bus privado algo después de crear su socket.
    deadline = time.monotonic() + 15
    while True:
        try:
            number = call('/Scripting', 'org.kde.kwin.Scripting.loadScript', str(script), marker)
            break
        except RuntimeError:
            if time.monotonic() > deadline:
                raise
            time.sleep(0.5)
    if not number.isdigit():
        raise RuntimeError('loadScript no devolvió un ID: ' + number)
    try:
        call('/Scripting/Script' + number, 'run')
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            for line in session_log.read_text().splitlines():
                if marker in line:
                    return json.loads(line.split(marker, 1)[1].strip())
            time.sleep(0.05)
        raise RuntimeError('KWin no imprimió el snapshot en session.log')
    finally:
        call('/Scripting', 'org.kde.kwin.Scripting.unloadScript', marker)


def identities(windows):
    return ' '.join(str(w.get(k, '')) for w in windows
                    for k in ('resourceClass', 'resourceName', 'caption')).lower()


def shell_surfaces(windows, shell_pid):
    # Layer-shell scopes are not exposed as resourceClass/caption in KWin 6.8.1.
    # Identify the owning native launcher and the three visible geometries,
    # checking their relative compositor layers instead of assuming WM_CLASS.
    owned = [w for w in windows if w['pid'] == shell_pid and not w['hidden']
             and w['width'] > 0 and w['height'] > 0]
    if len(owned) < 3:
        return False
    background = max(owned, key=lambda w: w['width'] * w['height'])
    bars = [w for w in owned if w != background and w['x'] == background['x']
            and w['y'] == background['y'] and w['width'] == background['width']
            and w['height'] < background['height']]
    docks = [w for w in owned if w != background and w['width'] < background['width']
             and w['y'] + w['height'] == background['y'] + background['height']]
    return any(background['layer'] < d['layer'] < b['layer'] for b in bars for d in docks)


def process_token(pid):
    try:
        fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        return fields[19] if fields[0] != 'Z' else None  # starttime, robust to PID reuse
    except (OSError, IndexError):
        return None


def capture(evidence, name, descriptor, log):
    result = subprocess.run([str(ROOT / 'tools/capture-session.sh'), str(evidence / name)],
                            env=os.environ | {'SINGLR_SESSION_FILE': str(descriptor)},
                            stdout=log, stderr=subprocess.STDOUT, timeout=35)
    png = evidence / name
    if result.returncode or not png.exists():
        raise RuntimeError('Spectacle falló; revisar capture.log')
    data = png.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data) < 24:
        raise RuntimeError('PNG inválido')
    width, height = struct.unpack('>II', data[16:24])
    if not width or not height:
        raise RuntimeError('PNG sin dimensiones')
    return f'{name}: {width}×{height} (se registra escala física, sin exigir 2048×1280)'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path,
                        default=Path('/tmp') / datetime.now().strftime('singlr-t204-%Y%m%d-%H%M%S'))
    parser.add_argument('--duration', type=float, default=100, help='Segundos hasta el cierre automático (default: 100)')
    args = parser.parse_args()
    if not 0 < args.duration < float('inf'):
        parser.error('--duration debe ser positivo y finito')
    evidence = args.evidence.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        parser.error('--evidence debe ser nuevo o estar vacío, para no aceptar evidencia obsoleta')
    evidence.mkdir(parents=True, exist_ok=True)
    outcomes = {}
    def report(step, good, detail=''):
        outcomes[step] = good
        print(f'{"PASS" if good else "FAIL"} {step}' + (f': {detail}' if detail else ''), flush=True)

    process = probe = external = None
    sid = None
    app_tokens = {}
    step = STEPS[0]
    before = runtime['config_hashes']()
    (evidence / 'config-before.json').write_text(json.dumps(before, indent=2))
    try:
        missing = [c for c in ('dolphin', 'qml6', 'qdbus6', 'spectacle', 'kwin_wayland',
                              'dbus-run-session', 'dbus-update-activation-environment') if not shutil.which(c)]
        if missing:
            raise RuntimeError('Faltan: ' + ', '.join(missing))
        build = subprocess.run([str(ROOT / 'shell/session/build.sh')], capture_output=True, text=True)
        (evidence / 'build.log').write_text(build.stdout + build.stderr)
        if build.returncode:
            raise RuntimeError('Fallo de compilación; ver build.log')
        report(step, True)
        with (evidence / 'session.log').open('w') as log, (evidence / 'probe.log').open('w') as probe_log, (
                evidence / 'capture.log').open('w') as capture_log:
            process = subprocess.Popen([str(ROOT / 'tools/run-singlr.sh'), '--duration', str(args.duration)],
                                       stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            step = 'session.json'
            session_log = evidence / 'session.log'
            def descriptor_path():
                for line in session_log.read_text().splitlines():
                    if line.startswith('SINGLR_SESSION_FILE='):
                        path = Path(line.split('=', 1)[1])
                        if path.is_file():
                            return path
            descriptor = wait_for(descriptor_path, process)
            data = json.loads(descriptor.read_text())
            sid = data['env']['SINGLR_SESSION_ID']
            # Descriptor copy is evidence only; the original is removed at shutdown.
            (evidence / 'session.json').write_text(json.dumps(data, indent=2))
            env = session_environment(data)
            report(step, True)
            step = 'locale'
            locale = {k: v for k, v in os.environ.items() if k in ('LANG', 'LANGUAGE') or k.startswith('LC_')}
            if any(data['env'].get(k) != v for k, v in locale.items()):
                raise RuntimeError('El descriptor no conserva el locale del host')
            report(step, True, json.dumps(locale))
            step = 'superficies KWin'
            def surfaces():
                windows = kwin_snapshot(env, evidence, session_log)
                (evidence / 'windows-shell.json').write_text(json.dumps(windows, indent=2))
                return windows if shell_surfaces(windows, data['shell_pid']) else None
            wait_for(surfaces, process)
            report(step, True, 'fondo, barra superior y dock: PID, geometría y orden de capas; launcher oculto')
            step = 'PNG escritorio'
            report(step, True, capture(evidence, 'desktop.png', descriptor, capture_log))
            # Additional external client outside the supervisor's ancestry. Must
            # be collected by the environment marker, even though it has no GUI.
            external = subprocess.Popen(['sleep', '300'], env=env, start_new_session=True)
            # Sin terminal, console.log de QML va al journal salvo que se fuerce stderr.
            probe = subprocess.Popen(['qml6', str(ROOT / 'tests/shell/DolphinProbe.qml')],
                                     env={**env, 'QT_FORCE_STDERR_LOGGING': '1'}, stdout=probe_log, stderr=subprocess.STDOUT, start_new_session=True)
            step = 'Milou lanza Dolphin'
            wait_for(lambda: 'T204_MILOU_LAUNCH true' in (evidence / 'probe.log').read_text(), process)
            report(step, True)
            step = 'Dolphin en KWin'
            def dolphin():
                windows = kwin_snapshot(env, evidence, session_log)
                (evidence / 'windows-dolphin.json').write_text(json.dumps(windows, indent=2))
                return windows if any('dolphin' in identities([w]) and w['width'] > 0 and w['height'] > 0
                                      for w in windows) else None
            windows = wait_for(dolphin, process)
            for window in windows:
                if 'dolphin' in identities([window]):
                    pid = window['pid']
                    token = process_token(pid)
                    if not token:
                        raise RuntimeError(f'No se puede seguir el PID de Dolphin: {pid}')
                    app_tokens[pid] = token
            (evidence / 'app-pids.json').write_text(json.dumps(app_tokens, indent=2))
            report(step, True)
            step = 'Dolphin en TasksModel'
            wait_for(lambda: 'T204_TASKS_PASS' in (evidence / 'probe.log').read_text(), process)
            report(step, True, 'AppId Dolphin, IsWindow=true, IsMapped=true')
            step = 'PNG Dolphin'
            time.sleep(1)
            report(step, True, capture(evidence, 'dolphin.png', descriptor, capture_log))
            step = 'cierre por duración'
            process.wait(timeout=args.duration + 15)
            if process.returncode != 0:
                raise RuntimeError(f'exit={process.returncode}; revisar session.log')
            report(step, True)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        report(step, False, str(error))
    finally:
        if process and process.poll() is None:
            process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                report('cierre por duración', False, 'Supervisor bloqueado; cierre de emergencia')
                runtime['stop'](process)
        residual = runtime['marked_processes'](sid) if sid else set()
        alive = [p.pid for p in (probe, external) if p and p.poll() is None]
        alive += [pid for pid, token in app_tokens.items() if process_token(pid) == token]
        report('procesos eliminados', not residual and not alive and (bool(sid) or (
                   process is not None and (evidence / 'session.log').exists() and
                   'SINGLR_CLEANUP remaining=[]' in (evidence / 'session.log').read_text())),
               f'residuales={sorted(residual)}; clientes externos vivos={alive}')
        # Only after recording a failure, tidy processes belonging to this run.
        for pid in residual | set(alive):
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        for child in (probe, external):
            if child:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=5)
        after = runtime['config_hashes']()
        (evidence / 'config-after.json').write_text(json.dumps(after, indent=2))
        report('configuración host', before == after, f'{len(before)} archivos antes / {len(after)} después')
        for pending in STEPS:
            if pending not in outcomes:
                report(pending, False, 'No ejecutado por fallo anterior')
        (evidence / 'results.json').write_text(json.dumps(outcomes, indent=2))
    good = all(outcomes.values())
    print(f'T204 {"PASS" if good else "FAIL"}; evidencia={evidence}', flush=True)
    print('Revisión visual pendiente: desktop.png y dolphin.png dentro de KWin anidado.')
    return 0 if good else 1


if __name__ == '__main__':
    sys.exit(main())
