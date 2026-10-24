#!/usr/bin/env python3
"""OUTSIDE SANDBOX: validate real protocols, Milou, Konsole, capture and cleanup."""
import argparse
import json
import os
from pathlib import Path
import runpy
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
runtime = runpy.run_path(str(ROOT / 'tools/session-runtime.py'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, default=Path('/tmp/singlr-t202-evidence'))
    args = parser.parse_args()
    if not shutil.which('konsole'):
        parser.error('Falta konsole (paquete Arch extra/konsole); no se instala en este encargo')
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    before = runtime['config_hashes']()
    (evidence / 'config-before.json').write_text(json.dumps(before, indent=2))
    env = os.environ.copy()
    env['SINGLR_WAYLAND_DEBUG'] = '1'
    process = None
    good = False
    try:
        with (evidence / 'session.log').open('w+') as log:
            process = subprocess.Popen([str(ROOT / 'tools/run-singlr.sh'), '--entry',
                                        str(ROOT / 'tests/shell/Probe.qml')], env=env,
                                       stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            deadline = time.monotonic() + 45
            descriptor = None
            while time.monotonic() < deadline and process.poll() is None:
                log.flush()
                content = (evidence / 'session.log').read_text()
                for line in content.splitlines():
                    if line.startswith('SINGLR_SESSION_FILE='):
                        descriptor = Path(line.split('=', 1)[1])
                # Protocol evidence + real mapped task, not merely a model import.
                if descriptor and all(marker in content for marker in (
                    'get_layer_surface(', 'org_kde_plasma_window_management',
                    'SINGLR_PROBE_FRAME', 'SINGLR_PROBE_RESULT',
                    'SINGLR_PROBE_LAUNCH true', 'SINGLR_PROBE_PASS')):
                    # Let the panel reflect PASS and the app draw before capture.
                    time.sleep(1)
                    capture_env = env | {'SINGLR_SESSION_FILE': str(descriptor)}
                    result = subprocess.run([str(ROOT / 'tools/capture-session.sh'),
                                             str(evidence / 'session.png')], env=capture_env,
                                            stdout=log, stderr=subprocess.STDOUT, timeout=35)
                    good = result.returncode == 0
                    break
                time.sleep(0.2)
    finally:
        if process and process.poll() is None:
            # Signal the supervisor only: its finally cleans the entire owned tree.
            process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=12)
            except subprocess.TimeoutExpired:
                good = False
                runtime['stop'](process)
        after = runtime['config_hashes']()
        (evidence / 'config-after.json').write_text(json.dumps(after, indent=2))
    content = (evidence / 'session.log').read_text()
    good &= before == after and 'SINGLR_CLEANUP remaining=[]' in content
    # Check marker on /proc environments to catch detached orphans after exit.
    session_ids = []
    for line in content.splitlines():
        if line.startswith('SINGLR_SESSION_FILE='):
            session_ids.append(Path(line.split('=', 1)[1]).parent.name)
    residual = []
    for proc in Path('/proc').iterdir():
        if proc.name.isdigit():
            try:
                environ = (proc / 'environ').read_bytes().split(b'\0')
                if any(f'SINGLR_SESSION_ID={sid}'.encode() in environ for sid in session_ids):
                    residual.append(int(proc.name))
            except (OSError, PermissionError):
                pass
    good &= not residual
    print(f'T202 {"PASS" if good else "FAIL"}: hashes_equal={before == after}; residual={residual}; evidencia={evidence}')
    print('Revisar visualmente session.png: panel superior y ventana Konsole completa en KWin anidado.')
    return 0 if good else 1


if __name__ == '__main__':
    sys.exit(main())
