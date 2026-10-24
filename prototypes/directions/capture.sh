#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$root/captures"
cleanup() {
    python3 - "$root" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
for pattern in ('.blur-*.png','.backend-probe*'):
    for file in root.glob(pattern):
        if file.is_file(): file.unlink()
PY
}
trap cleanup EXIT
cleanup
python3 "$root/common/generate-icons.py"
backend=rhi
# Probe the actual QML scene, not just a driver listing. Offscreen can otherwise
# silently choose software. Python contains driver-abort diagnostics in memory.
probe_status=0
python3 - "$root" <<'PYPROBE' || probe_status=$?
import os, pathlib, subprocess, sys
root=pathlib.Path(sys.argv[1])
env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='rhi',
         QT_FORCE_STDERR_LOGGING='1',QSG_RHI_BACKEND=os.environ.get('QSG_RHI_BACKEND','opengl'))
try:
    result=subprocess.run(['qml6',str(root/'a/Main.qml'),'--','--state=desktop','--mode=dark',
                           '--capture='+str(root/'.backend-probe.png')],
                          env=env,capture_output=True,text=True,timeout=15)
except subprocess.TimeoutExpired:
    print('Diagnóstico GPU: la prueba de renderizado agotó 15 s.',flush=True)
    sys.exit(1)
if result.returncode==0 and (root/'.backend-probe.png').exists():
    print('Backend RHI ('+env['QSG_RHI_BACKEND']+'): captura de prueba correcta.',flush=True)
    sys.exit(0)
log=result.stdout+result.stderr
if any(word in log for word in ('QQmlApplicationEngine failed','ReferenceError','TypeError','SyntaxError')):
    print(log,flush=True)
    sys.exit(2) # A QML failure must never be hidden by switching renderers.
print('Diagnóstico GPU: no se pudo inicializar RHI ('+env['QSG_RHI_BACKEND']+').',flush=True)
sys.exit(1)
PYPROBE
if [[ "$probe_status" == 2 ]]; then exit 2; fi
if [[ "$probe_status" != 0 ]]; then
    backend=software
    echo "AVISO: GPU no disponible en este entorno; se usa software con desenfoque CPU real."
fi

capture() {
    local direction="$1" state="$2" mode="$3" material="$4" name="$5"
    QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 QT_QUICK_BACKEND="$backend" \
      QSG_RHI_BACKEND="${QSG_RHI_BACKEND:-opengl}" \
      timeout 30s qml6 "$root/$direction/Main.qml" -- \
        --state="$state" --mode="$mode" --material="$material" \
        --capture="$root/captures/$name.png"
}
for direction in a b; do
    for state in desktop search multitask controls; do
        capture "$direction" "$state" dark glass "$direction-$state-dark"
    done
    capture "$direction" desktop light glass "$direction-desktop-light"
    capture "$direction" controls dark liquid "$direction-controls-liquid-dark"
done
python3 - "$root" <<'PY'
import pathlib, struct, sys
p = pathlib.Path(sys.argv[1]) / 'captures'
expected={f'{d}-{s}-dark.png' for d in 'ab' for s in ('desktop','search','multitask','controls','controls-liquid')}
expected|={f'{d}-desktop-light.png' for d in 'ab'}
assert {f.name for f in p.glob('*.png')} == expected
for name in sorted(expected):
    file=p/name
    assert struct.unpack('>II',file.read_bytes()[16:24])==(2048,1280),name
    print(name,'2048×1280',file.stat().st_size,'bytes')
print('12 capturas verificadas.')
PY
