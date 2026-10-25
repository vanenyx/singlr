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

KWIN_SETTINGS = [
    ('TabBox', 'LayoutName', 'singlr'),
    ('TabBox', 'ShowTabBox', 'true'),
    ('org.kde.kdecoration2', 'library', 'org.kde.kwin.aurorae'),
    ('org.kde.kdecoration2', 'theme', '__aurorae__svg__Singlr'),
    ('Effect-scale', 'OutScale', '0.4'),
    ('Effect-scale', 'OutOpacity', '0'),
    ('Effect-scale', 'InScale', '0.92'),
    ('Plugins', 'scaleEnabled', 'true'),
    ('Plugins', 'squashEnabled', 'true'),
    ('Plugins', 'magiclampEnabled', 'false'),
    ('Plugins', 'maximizeEnabled', 'true'),
    ('Plugins', 'singlr-overviewEnabled', 'true'),
    ('Plugins', 'singlr-gesturesEnabled', 'true'),
]


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
    if (not isinstance(entries, list) or not entries
            or any(not isinstance(row, list) or len(row) != 3
                   or not all(isinstance(item, str) for item in row[:2])
                   or (row[0], row[1]) not in allowed
                   or (row[2] is not None and not isinstance(row[2], str)) for row in entries)
            or len({(row[0], row[1]) for row in entries}) != len(entries)):
        raise ValueError(f'Backup KWin no reconocido: {path}')
    keys = {(row[0], row[1]) for row in entries}
    legacy = {(group, key) for group, key in allowed if group != 'TabBox'}
    if keys not in (allowed, legacy):
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
        save(path, [[group, key, read(group, key)] for group, key, _ in KWIN_SETTINGS])
        try:
            for group, key, value in KWIN_SETTINGS:
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
    calls = [('/KWin', 'reconfigure'),
             ('/Effects', 'org.kde.kwin.Effects.' + ('loadEffect' if applying else 'unloadEffect'), 'singlr-overview'),
             (('/Scripting', 'org.kde.kwin.Scripting.start') if applying else
              ('/Scripting', 'org.kde.kwin.Scripting.unloadScript', 'singlr-gestures'))]
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
