#!/usr/bin/env python3
"""Outside the sandbox: disposable KWin, two outputs/desktops, real windows and PNGs.

No host bus calls, no installation. --interactive leaves the private session open
for keyboard/drag verification until Enter; only this runner's process is stopped.
"""
import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
e2e = runpy.run_path(str(ROOT / 'tests/shell/e2e.py'))
runtime = e2e['runtime']


def stage_packages(data):
    for source, destination in [
        ('kwin/effects/singlr-overview', 'kwin/effects/singlr-overview'),
        ('kwin/scripts/singlr-gestures', 'kwin/scripts/singlr-gestures'),
        ('session/kwin/tabbox/singlr', 'kwin/tabbox/singlr'),
    ]:
        target = data / destination
        shutil.copytree(ROOT / source, target)
        for qml in target.rglob('*.qml'):
            text = qml.read_text()
            for relative in ('../../../../../shell/qml/Singlr/Ui', '../../../../../../shell/qml/Singlr/Ui'):
                text = text.replace('"' + relative + '"', '"' + (ROOT / 'shell/qml/Singlr/Ui').as_posix() + '"')
            qml.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'tests/shell/evidence/t246/nested')
    parser.add_argument('--interactive', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='singlr-workspace-') as directory:
        base = Path(directory)
        stage_packages(base / 'data')
        env = os.environ | {'SINGLR_EXTRA_DATA_DIRS': str(base / 'data'), 'SINGLR_OUTPUTS': '2',
                            'QML_IMPORT_PATH': str(ROOT / 'build/qml')}
        log_path = out / 'session.log'
        with log_path.open('w') as log:
            process = subprocess.Popen([str(ROOT / 'tools/run-singlr.sh'), '--duration', '600', '--size', '1280x800'],
                                       env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                def descriptor():
                    for line in log_path.read_text().splitlines():
                        if line.startswith('SINGLR_SESSION_FILE='):
                            return Path(line.split('=', 1)[1])
                path = e2e['wait_for'](descriptor, process)
                data = json.loads(path.read_text())
                private = e2e['session_environment'](data)
                private['QML_IMPORT_PATH'] = str(ROOT / 'build/qml')
                def call(service, path, *arguments):
                    return subprocess.check_output(['qdbus6', service, path, *arguments], env=private, text=True, timeout=10).strip()
                def script(code):
                    marker = 'T246_' + uuid.uuid4().hex
                    file = base / (marker + '.js')
                    file.write_text(code)
                    number = call('org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.loadScript', str(file), marker)
                    try:
                        call('org.kde.KWin', '/Scripting/Script' + number, 'run')
                    finally:
                        call('org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.unloadScript', marker)
                # Same transaction as login, but with the private XDG config/state and bus.
                subprocess.run([str(ROOT / 'session/singlr-kwin'), '--apply'], env=private, check=True, timeout=25)
                if call('org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.isEffectLoaded', 'singlr-overview') != 'true':
                    raise RuntimeError('Overview did not load; inspect private KWin log')
                for folder in ('/usr', '/etc', '/tmp'):
                    subprocess.Popen(['dolphin', '--new-window', folder], env=private, stdout=log, stderr=log)
                    time.sleep(1)
                def windows_ready():
                    windows = e2e['kwin_snapshot'](private, base, log_path)
                    return windows if sum('dolphin' in w['resourceClass'].lower() for w in windows) >= 3 else None
                e2e['wait_for'](windows_ready, process)
                script('''
                    while (workspace.desktops.length < 2) workspace.createDesktop(workspace.desktops.length, "Lectura");
                    const windows = workspace.windowList().filter(w => String(w.resourceClass).toLowerCase().includes("dolphin"));
                    windows[0].desktops = [workspace.desktops[1]];
                    workspace.setCurrentDesktopForScreen(workspace.desktops[0], workspace.screens[0]);
                    print("T246_SETUP", workspace.desktops.length, windows[0].desktops[0].id, workspace.screens.length);
                ''')
                time.sleep(.5)
                setup = next((line.split("T246_SETUP", 1)[1].strip().split() for line in log_path.read_text().splitlines() if "T246_SETUP" in line), None)
                if not setup or setup[0] != '2' or setup[-1] != '2':
                    raise RuntimeError('Two desktops/two outputs not confirmed in KWin log')
                runtime['capture'](out / 'desktop.png', path)
                call('org.kde.kglobalaccel', '/component/kwin', 'org.kde.kglobalaccel.Component.invokeShortcut', 'Singlr Overview')
                time.sleep(.5)
                runtime['capture'](out / 'overview.png', path)
                print('Private descriptor:', path, flush=True)
                print('Check Alt+Tab/Shift+Tab, release Alt, Esc; Meta+Tab; desktops, drag, search, Meta+T. See session/WORKSPACE.md.', flush=True)
                if args.interactive:
                    input('Enter ends and cleans ONLY this private session: ')
                else:
                    call('org.kde.kglobalaccel', '/component/kwin', 'org.kde.kglobalaccel.Component.invokeShortcut', 'Singlr Overview')
                    # Real endpoint dispatch preserves the query, including non-ASCII text.
                    call('org.kde.plasmashell', '/SinglrWorkspace', 'org.singlr.Workspace.search', '2+2', 'missing-output')
                    time.sleep(.5)
                    runtime['capture'](out / 'command.png', path)
                (out / 'windows.json').write_text(json.dumps(e2e['kwin_snapshot'](private, base, log_path), indent=2))
            finally:
                process.terminate()
                try:
                    process.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    runtime['stop'](process)
        text = log_path.read_text()
        if 'equal=True' not in text or 'SINGLR_CLEANUP remaining=[]' not in text:
            raise RuntimeError('Missing host config/cleanup evidence; inspect ' + str(log_path))
        if any(message in text for message in ('ReferenceError:', 'TypeError:', 'Cannot instantiate bound component')):
            raise RuntimeError('QML runtime error; inspect ' + str(log_path))
        print('PASS isolated setup/captures/cleanup. Physical keyboard, drag and output routing require the interactive procedure.')


if __name__ == '__main__':
    main()
