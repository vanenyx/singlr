#!/usr/bin/env python3
"""T258: real Klipper, focus return and paste on a private KWin/bus. Synthetic data only."""
import configparser
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

def read_state(path):
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(path)
    return dict(parser['General']) if parser.has_section('General') else {}

def case(folder, terminal=False, kind='paste'):
    folder.mkdir()
    logpath = folder / 'session.log'
    target = None
    other = None
    with logpath.open('w+') as log:
        process = subprocess.Popen([str(ROOT / 'tools/run-singlr.sh'), '--entry',
            str(ROOT / 'tests/shell/ClipboardPasteProbe.qml')], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            def descriptor():
                log.flush()
                for line in logpath.read_text().splitlines():
                    if line.startswith('SINGLR_SESSION_FILE='):
                        path = Path(line.split('=', 1)[1])
                        if path.exists(): return path
            path = e2e['wait_for'](descriptor, process, 35)
            data = json.loads(path.read_text())
            env = e2e['session_environment'](data)
            state = Path(env['XDG_STATE_HOME'])
            cmd = [str(ROOT / 'build/session/appearance/singlr-clipboard-target'),
                   str(ROOT / 'tests/shell/ClipboardPasteTarget.qml')]
            if terminal: cmd.append('--terminal')
            if kind == 'image': cmd.append('--image')
            target = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
            target_state = state / 'clipboard-target.ini'
            panel_state = state / 'clipboard-probe.ini'
            e2e['wait_for'](lambda: read_state(target_state).get('ready') == 'true', process, 15)
            time.sleep(.5)
            def call(method):
                subprocess.run(['qdbus6', 'org.kde.plasmashell', '/PlasmaShell',
                    'org.kde.PlasmaShell.' + method], env=env, check=True, capture_output=True, timeout=5)
            call('toggleClipboard')
            e2e['wait_for'](lambda: int(read_state(panel_state).get('count', '-1')) >= 2, process, 10)
            e2e['wait_for'](lambda: read_state(panel_state).get('canpaste') == 'true', process, 5)
            initial_order = e2e['wait_for'](lambda: read_state(panel_state).get('historyorder'), process, 5)
            if kind == 'target-gone':
                target.terminate(); target.wait(timeout=5); target = None
                time.sleep(.2)
            elif kind == 'focus-changed':
                other = subprocess.Popen(cmd + ['--other'], env=env, stdout=log, stderr=subprocess.STDOUT)
                e2e['wait_for'](lambda: read_state(state / 'clipboard-target-other.ini').get('ready') == 'true', process, 10)
            call('singlrShowApplications' if kind == 'copy-only' else 'focusDock' if kind == 'same-entry' else 'toggleLauncher')
            if kind in ('copy-only', 'target-gone', 'focus-changed'):
                time.sleep(1.7)
                if read_state(panel_state).get('sent') == 'true': raise RuntimeError('Unexpected paste')
                if kind == 'copy-only' and read_state(target_state).get('content', '') not in ('', '""'):
                    raise RuntimeError('Copy-only changed the target')
                if kind == 'focus-changed' and read_state(state / 'clipboard-target-other.ini').get('content', '') not in ('', '""'):
                    raise RuntimeError('Paste redirected to other window')
                clip = subprocess.check_output(['qdbus6', 'org.kde.klipper', '/klipper', 'getClipboardContents'], env=env, text=True, timeout=5)
                if clip.strip() != 'SINGLR_T258_OLD á\nsegunda línea': raise RuntimeError('Selection not kept for manual paste')
            else:
                e2e['wait_for'](lambda: read_state(panel_state).get('sent') == 'true' or read_state(panel_state).get('failed') == 'true', process, 6)
                if read_state(panel_state).get('failed') == 'true':
                    raise RuntimeError('Bridge refused to paste; inspect private log')
                if kind == 'image':
                    e2e['wait_for'](lambda: read_state(target_state).get('imagereceived') == 'true', process, 6)
                else:
                    expected = 'SINGLR_T258_NEW' if kind == 'same-entry' else 'SINGLR_T258_OLD á\nsegunda línea'
                    e2e['wait_for'](lambda: read_state(target_state).get('content', '').strip('"').replace('\\n', '\n') == expected, process, 6)
                if terminal and read_state(target_state).get('terminalchord') != 'true':
                    raise RuntimeError('Terminal did not receive Ctrl+Shift+V')
            time.sleep(.3)
            if read_state(panel_state).get('historyorder') != initial_order:
                raise RuntimeError('Using history changed copy order')
            result = {'case': 'terminal' if terminal else kind, 'result': 'PASS',
                'real_history': True, 'copy_order_preserved': True, 'terminal_metadata_fixture': terminal}
        finally:
            if other and other.poll() is None:
                other.terminate()
                try: other.wait(timeout=5)
                except subprocess.TimeoutExpired: other.kill(); other.wait()
            if target and target.poll() is None:
                target.terminate()
                try: target.wait(timeout=5)
                except subprocess.TimeoutExpired: target.kill(); target.wait()
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
                try: process.wait(timeout=20)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
    final = logpath.read_text()
    if 'remaining=[]' not in final or 'equal=True' not in final:
        raise RuntimeError('Cleanup or host config hash verification failed')
    (folder / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(result)

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--terminal', action='store_true')
    parser.add_argument('--case', choices=('paste','copy-only','target-gone','focus-changed','same-entry','image'), default='paste')
    args = parser.parse_args()
    case(args.output, args.terminal, args.case)
