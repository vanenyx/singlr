#!/usr/bin/env python3
"""Singlr en vivo sobre la sesión Plasma real: reinicia el shell al cambiar shell/qml.

Uso: tools/singlr-live.sh start [--keep-plasma] | stop | status
Por defecto sustituye a plasmashell mientras está activo (autorizado por el creador el 24 oct);
`stop` vuelve a arrancar Plasma. No cambia la configuración de Plasma.
"""
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'session'))
import singlr_kwin

QML = ROOT / 'shell/qml'
STATE = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'singlr-live'
PIDFILE = STATE / 'supervisor.pid'
PLASMA_MARK = STATE / 'plasma-stopped'
NETWORK_MARK = STATE / 'networkmanagement-unloaded'
KWIN_BACKUP = singlr_kwin.backup_path()
AURORAE = Path.home() / '.local/share/aurorae/themes/Singlr'
OVERVIEW = Path.home() / '.local/share/kwin/effects/singlr-overview'
GESTURES = Path.home() / '.local/share/kwin/scripts/singlr-gestures'
PLASMA_UNIT = 'plasma-plasmashell.service'
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


def plasma(action):
    return subprocess.run(['systemctl', '--user', action, PLASMA_UNIT], capture_output=True, text=True)


def network_module(action):
    return subprocess.run(['qdbus6', 'org.kde.kded6', '/kded',
                           f'org.kde.kded6.{action}Module', 'networkmanagement'],
                          capture_output=True, text=True)


def unload_network_module():
    # Mark before mutation so a failed startup can still restore KDE's agent.
    NETWORK_MARK.write_text('1')
    result = network_module('unload')
    if result.returncode or result.stdout.strip().lower() != 'true':
        raise RuntimeError('No se pudo descargar networkmanagement: ' + result.stderr.strip())


SETTINGS_LINKS = [
    (Path.home() / '.local/bin/singlr-settings', 'apps/settings/singlr-settings'),
    (Path.home() / '.local/share/applications/singlr-settings.desktop', 'apps/settings/singlr-settings.desktop'),
]


def apply_settings_app():
    # Enlaces de desarrollo para que «Ajustes de Singlr» aparezca en el lanzador; se retiran al parar.
    root = Path(__file__).resolve().parents[1]
    for link, source in SETTINGS_LINKS:
        link.parent.mkdir(parents=True, exist_ok=True)
        if not link.exists() and not link.is_symlink():
            link.symlink_to(root / source)


def remove_settings_app():
    root = Path(__file__).resolve().parents[1]
    for link, source in SETTINGS_LINKS:
        if link.is_symlink() and link.resolve() == (root / source).resolve():
            link.unlink()


def apply_kwin():
    theme = Path(__file__).resolve().parents[1] / 'decoration/aurorae/Singlr'
    if not (theme / 'decoration.svg').exists():
        return
    AURORAE.parent.mkdir(parents=True, exist_ok=True)
    if not AURORAE.exists():
        AURORAE.symlink_to(theme)
    effect = Path(__file__).resolve().parents[1] / 'kwin/effects/singlr-overview'
    OVERVIEW.parent.mkdir(parents=True, exist_ok=True)
    if not OVERVIEW.exists():
        OVERVIEW.symlink_to(effect)
    gestures = Path(__file__).resolve().parents[1] / 'kwin/scripts/singlr-gestures'
    GESTURES.parent.mkdir(parents=True, exist_ok=True)
    if not GESTURES.exists():
        GESTURES.symlink_to(gestures)
    singlr_kwin.apply(KWIN_BACKUP, recover_pending=True)
    singlr_kwin.reload_kwin(applying=True)


def restore_kwin():
    if singlr_kwin.restore(KWIN_BACKUP):
        singlr_kwin.reload_kwin(applying=False)
        if AURORAE.is_symlink() and AURORAE.resolve() == ROOT / 'decoration/aurorae/Singlr':
            AURORAE.unlink()


def restore_shortcuts():
    backup = STATE / 'shortcuts-backup.json'
    if not backup.exists():
        return True
    try:
        binary = subprocess.run([str(ROOT / 'shell/session/build.sh')], check=True,
                                capture_output=True, text=True).stdout.strip().splitlines()[-1]
        result = subprocess.run([binary, '--restore-shortcuts'], capture_output=True, text=True,
                                timeout=30)
        if result.returncode == 0 and not backup.exists():
            return True
        print('No se pudieron restaurar los atajos: ' + result.stderr.strip(), file=sys.stderr)
    except (OSError, subprocess.SubprocessError, IndexError) as error:
        print(f'No se pudieron restaurar los atajos: {error}', file=sys.stderr)
    print('Backup conservado; reintente tools/singlr-live.sh stop', file=sys.stderr)
    return False


def restore_plasma():
    shortcuts_restored = restore_shortcuts()
    restore_kwin()
    if NETWORK_MARK.exists():
        try:
            result = network_module('load')
            restored = result.returncode == 0 and result.stdout.strip().lower() == 'true'
        except OSError:
            restored = False
        if restored:
            NETWORK_MARK.unlink(missing_ok=True)
        else:
            print('No se pudo restaurar networkmanagement; reintente tools/singlr-live.sh stop', file=sys.stderr)
    if PLASMA_MARK.exists():
        # Un arranque/parada rápido puede dejar la unidad en «failed»; se limpia antes de arrancar.
        plasma('reset-failed')
        plasma('start')
        PLASMA_MARK.unlink(missing_ok=True)
    return shortcuts_restored


def supervise(takeover):
    binary = subprocess.run([str(ROOT / 'shell/session/build.sh')], check=True,
                            capture_output=True, text=True).stdout.strip().splitlines()[-1]
    command = [binary, str(QML), str(QML / 'Shell.qml')]
    if not takeover:
        command += ['--', '--no-background', '--no-takeover']
    stop = False

    def finish(*_):
        nonlocal stop
        stop = True
    signal.signal(signal.SIGTERM, finish)
    signal.signal(signal.SIGINT, finish)
    shell = None
    seen = {}
    try:
        while not stop:
            current = snapshot()
            if shell is None or shell.poll() is not None or current != seen:
                if shell is not None and shell.poll() is None:
                    shell.terminate()
                    try:
                        shell.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        shell.kill()
                        shell.wait()
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
    finally:
        # Release Singlr's agent before allowing KDE's to register, including errors.
        if shell is not None and shell.poll() is None:
            shell.terminate()
            try:
                shell.wait(timeout=3)
            except subprocess.TimeoutExpired:
                shell.kill()
                shell.wait()
        restore_plasma()
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
        takeover = '--keep-plasma' not in sys.argv
        try:
            if takeover:
                unload_network_module()
                apply_kwin()
                apply_settings_app()
                if plasma('is-active').stdout.strip() == 'active':
                    PLASMA_MARK.write_text('1')
                    plasma('stop')
                # KRunner vuelve por activación D-Bus al detener Singlr.
                subprocess.run(['kquitapp6', 'krunner'], capture_output=True)
            child = os.fork()
        except (OSError, RuntimeError, subprocess.SubprocessError):
            restore_plasma()
            raise
        if child:
            time.sleep(1.5)
            print(f'Singlr en vivo activo. Registro: {LOG}. Para quitarlo: tools/singlr-live.sh stop')
            return 0
        os.setsid()
        PIDFILE.write_text(str(os.getpid()))
        devnull = os.open(os.devnull, os.O_RDWR)
        for fd in (0, 1, 2):
            os.dup2(devnull, fd)
        try:
            supervise(takeover)
        finally:
            restore_plasma()
            PIDFILE.unlink(missing_ok=True)
        return 0
    if action == 'stop':
        pid = running()
        if not pid:
            restored = restore_plasma()
            print('Singlr en vivo no está activo')
            return 0 if restored else 1
        os.kill(pid, signal.SIGTERM)
        for _ in range(50):
            if not running():
                break
            time.sleep(0.1)
        if running():
            print('Singlr aún se está deteniendo; reintente stop', file=sys.stderr)
            return 1
        restored = restore_shortcuts()
        print('Singlr en vivo detenido')
        return 0 if restored else 1
    print('activo' if running() else 'inactivo')
    return 0


if __name__ == '__main__':
    sys.exit(main())
