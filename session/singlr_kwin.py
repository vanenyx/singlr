"""Transactional KWin preferences shared by the live and login sessions."""
import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

# P-032: only shell material belongs to Singlr. Everything else is KDE/user policy.
KWIN_SETTINGS = [
    ('Plugins', 'singlr-liquidglassEnabled', 'true'),
    ('Effect-singlrliquidglass', 'Enabled', 'true'),
    ('Effect-singlrliquidglass', 'Intensity', '65'),
]
MATERIAL_KEYS = {(g, k) for g, k, _ in KWIN_SETTINGS}

# Migration only: never apply these keys again. Preserve all accepted journal versions.
DECORATION_KEYS = {('org.kde.kdecoration2', 'library'), ('org.kde.kdecoration2', 'theme')}
WORKSPACE_KEYS = {
    ('TabBox', 'LayoutName'), ('TabBox', 'ShowTabBox'),
    ('Effect-scale', 'OutScale'), ('Effect-scale', 'OutOpacity'), ('Effect-scale', 'InScale'),
    ('Plugins', 'scaleEnabled'), ('Plugins', 'squashEnabled'),
    ('Plugins', 'magiclampEnabled'), ('Plugins', 'maximizeEnabled'),
    ('Plugins', 'singlr-overviewEnabled'), ('Plugins', 'singlr-gesturesEnabled'),
    ('Plugins', 'overviewEnabled'), ('Plugins', 'windowviewEnabled'),
    ('Effect-overview', 'BorderActivate'),
}
RETIRED_KEYS = DECORATION_KEYS | WORKSPACE_KEYS
OVERVIEW_EDGE_KEYS = {('Effect-overview', 'BorderActivate')}
GESTURE_KEYS = {('Plugins', 'overviewEnabled'), ('Plugins', 'windowviewEnabled')}
# These identifiers are retained solely to unload extensions from older installations.
RETIRED_EFFECT = 'singlr-overview'
RETIRED_SCRIPT = 'singlr-gestures'


def material_settings():
    from configparser import ConfigParser, Error
    config = ConfigParser(interpolation=None)
    try:
        config.read(Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'singlr/singlr.conf')
    except (Error, OSError):
        config = ConfigParser(interpolation=None)  # A corrupt preference must not prevent login.
    try:
        intensity = max(0, min(100, config.getint('Appearance', 'intensity', fallback=65)))
    except ValueError:
        intensity = 65
    try:
        reduce = config.getboolean('Accessibility', 'reduceTransparency', fallback=False)
    except ValueError:
        reduce = False
    glass = config.get('Appearance', 'material', fallback='glass') in ('glass', 'liquid')
    return [('Effect-singlrliquidglass', 'Enabled', str(glass and intensity > 0 and not reduce).lower()),
            ('Effect-singlrliquidglass', 'Intensity', str(intensity))]


def backup_path():
    # Persistent journal: XDG_RUNTIME_DIR is lost on logout/reboot.
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'singlr/kwinrc-backup.json'


def read(group, key):
    missing = '__singlr_absent_' + uuid.uuid4().hex
    result = subprocess.run(['kreadconfig6', '--file', 'kwinrc', '--group', group,
                             '--key', key, '--default', missing],
                            check=True, capture_output=True, text=True)
    value = result.stdout.removesuffix('\n')
    return None if value == missing else value


def write(group, key, value):
    command = ['kwriteconfig6', '--file', 'kwinrc', '--group', group, '--key', key]
    subprocess.run(command + (['--delete'] if value is None else [value]),
                   check=True, capture_output=True, text=True)
    # Order durable config writes before removing the recovery journal.
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'kwinrc'
    if config.exists():
        with config.open('rb') as stream:
            os.fsync(stream.fileno())
        sync_directory(config.parent)


def sync_directory(directory):
    fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def save(path, entries):
    fd, name = tempfile.mkstemp(prefix='.kwinrc-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(entries, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        sync_directory(path.parent)
    finally:
        Path(name).unlink(missing_ok=True)


@contextmanager
def locked(path):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (path.parent / 'kwinrc.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def entries_from(path):
    entries = json.loads(path.read_text())
    allowed = {(group, key) for group, key, _ in KWIN_SETTINGS}
    restorable = allowed | RETIRED_KEYS
    if (not isinstance(entries, list) or not entries
            or any(not isinstance(row, list) or len(row) != 3
                   or not all(isinstance(item, str) for item in row[:2])
                   or (row[0], row[1]) not in restorable
                   or (row[2] is not None and not isinstance(row[2], str)) for row in entries)
            or len({(row[0], row[1]) for row in entries}) != len(entries)):
        raise ValueError(f'Backup KWin no reconocido: {path}')
    keys = {(row[0], row[1]) for row in entries} - DECORATION_KEYS
    previous = allowed | WORKSPACE_KEYS
    legacy = {pair for pair in previous if pair[0] != 'TabBox'}
    supported = [base - extras - new
                 for base in (previous, legacy, previous - MATERIAL_KEYS, legacy - MATERIAL_KEYS)
                 for extras in (set(), OVERVIEW_EDGE_KEYS)
                 for new in (set(), GESTURE_KEYS)]
    if keys != allowed and keys not in supported:
        raise ValueError(f'Backup KWin incompleto: {path}')
    return entries


def _restore(path):
    if not path.exists():
        return False
    for group, key, value in entries_from(path):
        write(group, key, value)
    # Keep the journal if any write failed; a retry restores the whole set.
    path.unlink()
    sync_directory(path.parent)
    return True


def apply(path=None, *, recover_pending=False):
    path = Path(path) if path is not None else backup_path()
    with locked(path):
        if path.exists():
            if not recover_pending:
                return False  # Never replace the original snapshot on repeat apply.
            _restore(path)
        snapshot = [[group, key, read(group, key)] for group, key, _ in KWIN_SETTINGS]
        save(path, snapshot)
        try:
            for group, key, value in KWIN_SETTINGS:
                write(group, key, value)
            for group, key, value in material_settings():
                write(group, key, value)
        except BaseException:
            _restore(path)
            raise
    return True


def restore(path=None):
    path = Path(path) if path is not None else backup_path()
    with locked(path):
        return _restore(path)


def reload_kwin(*, applying):
    # Best effort only: live KWin may not yet know a newly linked effect.
    calls = []
    if applying:
        calls.extend([('/Effects', 'org.kde.kwin.Effects.unloadEffect', RETIRED_EFFECT),
                      ('/Scripting', 'org.kde.kwin.Scripting.unloadScript', RETIRED_SCRIPT)])
    calls.append(('/KWin', 'reconfigure'))
    if applying:
        # reconfigure does not load default-on effects an older Singlr unloaded
        # live; bring KDE's multitasking back unless the user turned it off.
        calls.extend(('/Effects', 'org.kde.kwin.Effects.loadEffect', effect)
                     for effect in ('overview', 'windowview') if read('Plugins', effect + 'Enabled') != 'false')
    # Restore a pre-existing user effect activation as well as its configuration.
    calls.append(('/Effects', 'org.kde.kwin.Effects.' +
                  ('loadEffect' if applying or read('Plugins', 'singlr-liquidglassEnabled') == 'true' else 'unloadEffect'),
                  'singlr-liquidglass'))
    for call in calls:
        subprocess.run(['qdbus6', 'org.kde.KWin', *call], capture_output=True, timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--apply', action='store_true')
    action.add_argument('--restore', action='store_true')
    parser.add_argument('--offline', action='store_true', help='KWin detenido: no usar D-Bus')
    args = parser.parse_args()
    if args.apply:
        changed = apply(recover_pending=True)
    else:
        changed = restore()
    if changed and not args.offline:
        reload_kwin(applying=args.apply)
    return 0
