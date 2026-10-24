#!/usr/bin/env python3
"""Singlr en vivo sobre la sesión Plasma real: reinicia el shell al cambiar shell/qml.

Uso: tools/singlr-live.sh start | stop | status
No modifica Plasma ni su configuración; detenerlo retira las superficies de Singlr.
"""
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / 'shell/qml'
STATE = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'singlr-live'
PIDFILE = STATE / 'supervisor.pid'
LOG = STATE / 'shell.log'


def snapshot():
    return {p: p.stat().st_mtime for p in QML.rglob('*')
            if p.suffix in ('.qml', '.js') or p.name == 'qmldir'}


def running():
    try:
        pid = int(PIDFILE.read_text())
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError):
        return None


def supervise():
    binary = subprocess.run([str(ROOT / 'shell/session/build.sh')], check=True,
                            capture_output=True, text=True).stdout.strip().splitlines()[-1]
    command = [binary, str(QML), str(QML / 'Shell.qml'), '--', '--no-background']
    stop = False

    def finish(*_):
        nonlocal stop
        stop = True
    signal.signal(signal.SIGTERM, finish)
    signal.signal(signal.SIGINT, finish)
    shell = None
    seen = {}
    while not stop:
        current = snapshot()
        if shell is None or shell.poll() is not None or current != seen:
            if shell is not None and shell.poll() is None:
                shell.terminate()
                try:
                    shell.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    shell.kill()
            seen = current
            with LOG.open('a') as log:
                log.write(f'--- {time.strftime("%H:%M:%S")} recarga\n')
                log.flush()
                shell = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                         env={**os.environ, 'QT_FORCE_STDERR_LOGGING': '1'})
            # Si el QML tiene un error, el shell muere: se espera al siguiente cambio.
            time.sleep(1)
            if shell.poll() is not None:
                seen = snapshot()
        time.sleep(0.4)
    if shell is not None and shell.poll() is None:
        shell.terminate()
        shell.wait(timeout=3)
    PIDFILE.unlink(missing_ok=True)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'start'
    STATE.mkdir(parents=True, exist_ok=True)
    if action == 'start':
        if running():
            print('Singlr en vivo ya está activo')
            return 0
        if not os.environ.get('WAYLAND_DISPLAY'):
            print('Se requiere una sesión Wayland', file=sys.stderr)
            return 1
        if os.fork():
            time.sleep(1.5)
            print(f'Singlr en vivo activo. Registro: {LOG}. Para quitarlo: tools/singlr-live.sh stop')
            return 0
        os.setsid()
        PIDFILE.write_text(str(os.getpid()))
        devnull = os.open(os.devnull, os.O_RDWR)
        for fd in (0, 1, 2):
            os.dup2(devnull, fd)
        supervise()
        return 0
    if action == 'stop':
        pid = running()
        if not pid:
            print('Singlr en vivo no está activo')
            return 0
        os.kill(pid, signal.SIGTERM)
        for _ in range(50):
            if not running():
                break
            time.sleep(0.1)
        print('Singlr en vivo detenido')
        return 0
    print('activo' if running() else 'inactivo')
    return 0


if __name__ == '__main__':
    sys.exit(main())
