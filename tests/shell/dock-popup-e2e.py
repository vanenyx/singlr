#!/usr/bin/env python3
"""T259: real dock/popup geometry with reserved space and auto-hide, private KWin only."""
import argparse
import json
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
e2e = runpy.run_path(str(ROOT / 'tests/shell/e2e.py'))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--before', action='store_true', help='Capture HEAD geometry as baseline; no passing-gap assertion')
    args = parser.parse_args()
    folder = args.output.resolve(); folder.mkdir()
    with tempfile.TemporaryDirectory(prefix='singlr-t259-baseline-') as tmp:
        entry = ROOT / 'tests/shell/DockPopupProbe.qml'
        if args.before:
            stage = Path(tmp)
            shell = stage / 'Shell'; shell.mkdir()
            (stage / 'Ui').symlink_to(ROOT / 'shell/qml/Singlr/Ui', target_is_directory=True)
            for source in (ROOT / 'shell/qml/Singlr/Shell').iterdir():
                if source.name not in ('Session.qml', 'TopBar.qml', 'ScreenSurfaces.qml', 'qmldir'):
                    (shell / source.name).symlink_to(source)
            for name in ('Session.qml', 'TopBar.qml', 'ScreenSurfaces.qml'):
                source = subprocess.check_output(['git','show','d1efe95:shell/qml/Singlr/Shell/'+name], cwd=ROOT, text=True)
                if name == 'Session.qml': source = source.replace('ScreenSurfaces', 'HistoricalScreenSurfaces')
                if name == 'ScreenSurfaces.qml': source = source.replace('TopBar {', 'HistoricalTopBar {')
                target = 'Historical'+name if name != 'Session.qml' else name
                (shell / target).write_text(source.replace('import QtQuick\n', 'import QtQuick\nimport Singlr.Shell\n', 1))
            entry = stage / 'DockPopupProbe.qml'
            entry.write_text((ROOT / 'tests/shell/DockPopupProbe.qml').read_text().replace('import Singlr.Shell', 'import "Shell" as Before').replace('controller: Session', 'controller: Before.Session'))
        logpath = folder / 'session.log'
        with logpath.open('w+') as log:
            process = subprocess.Popen([str(ROOT / 'tools/run-singlr.sh'), '--entry', str(entry)], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                def descriptor():
                    for line in logpath.read_text().splitlines():
                        if line.startswith('SINGLR_SESSION_FILE='):
                            path = Path(line.split('=',1)[1])
                            if path.exists(): return path
                desc = e2e['wait_for'](descriptor, process, 35)
                data = json.loads(desc.read_text()); env = e2e['session_environment'](data)
                e2e['wait_for'](lambda: subprocess.run(
                    ['qdbus6','org.kde.plasmashell','/PlasmaShell'], env=env,
                    capture_output=True, timeout=5).returncode == 0, process, 15)
                def call(method):
                    subprocess.run(['qdbus6','org.kde.plasmashell','/PlasmaShell','org.kde.PlasmaShell.'+method], env=env, capture_output=True, check=True, timeout=5)
                rows = []
                for i in range(1 if args.before else 12):
                    call('toggleLauncher'); time.sleep(.5)
                    windows = e2e['kwin_snapshot'](env, folder, logpath)
                    owned = [w for w in windows if w['pid'] == data['shell_pid'] and not w['hidden'] and w['width'] > 0]
                    screen = max(owned, key=lambda w: w['width']*w['height'])
                    height = (40,48,72)[i//2%3]; fixed = bool(i%2)
                    dock = next(w for w in owned if w['height'] == height and w['y'] > screen['height']/2)
                    tip = next(w for w in owned if 2 < w['height'] < 40 and w['width'] < screen['width'] and w['y'] > screen['height']/2 and w != dock)
                    gap = dock['y'] - (tip['y']+tip['height'])
                    row = dict(mode='fixed' if fixed else 'floating', height=height, auto_hide=i>=6, gap=gap, tooltip=tip, dock=dock)
                    rows.append(row)
                    if not args.before and gap != 8: raise RuntimeError('Tooltip gap: '+str(row))
                    if i == 0:
                        with (folder/'capture.log').open('w') as capture_log:
                            e2e['capture'](folder, 'desktop-dark.png', desc, capture_log)
                            if not args.before:
                                call('singlrShowApplications');time.sleep(.2)
                                e2e['capture'](folder, 'desktop-light.png', desc, capture_log)
                    if not args.before and i in (0,1,6,7):
                        call('toggleClipboard');time.sleep(.3)
                        menu_windows = e2e['kwin_snapshot'](env, folder, logpath)
                        menu = next(w for w in menu_windows if w['pid']==data['shell_pid'] and not w['hidden'] and w['width']==240 and w['height']>1)
                        menu_gap = dock['y']-(menu['y']+menu['height'])
                        if menu_gap != 8: raise RuntimeError('Menu gap: '+str(menu_gap))
                        row['menu_gap'] = menu_gap
                (folder/'result.json').write_text(json.dumps(dict(result='BASELINE' if args.before else 'PASS', cases=rows),indent=2)+'\n')
            finally:
                if process.poll() is None:
                    process.send_signal(signal.SIGTERM)
                    try: process.wait(timeout=20)
                    except subprocess.TimeoutExpired: process.kill();process.wait()
        final = logpath.read_text()
        if 'remaining=[]' not in final or 'equal=True' not in final: raise RuntimeError('Cleanup/host hashes failed')
    print('BASELINE' if args.before else 'PASS', folder)

if __name__ == '__main__': main()
