#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export QSG_RHI_BACKEND="${QSG_RHI_BACKEND:-opengl}"
python3 - "$root" <<'PY'
import os, pathlib, struct, subprocess, sys, tempfile
root=pathlib.Path(sys.argv[1])
(root/'captures').mkdir(exist_ok=True)
env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='rhi',QT_FORCE_STDERR_LOGGING='1',QT_SCALE_FACTOR='1')
errors=('ReferenceError','TypeError','SyntaxError','Binding loop','failed to load component','is not a type','Cannot assign','Unable to assign')
def run(state,mode,path):
    return subprocess.run(['qml6',str(root/'Main.qml'),'--','--state='+state,'--mode='+mode,'--capture='+str(path)],env=env,capture_output=True,text=True,timeout=20)
with tempfile.TemporaryDirectory(prefix='singlr-capture-') as temp:
    probe=pathlib.Path(temp)/'probe.png'
    try:
        result=run('desktop','dark',probe)
        log=result.stdout+result.stderr
    except subprocess.TimeoutExpired:
        log='RHI: timeout de inicialización';result=None
    if any(e in log for e in errors):
        sys.exit(log)
    if not result or result.returncode or not probe.exists() or 'BACKEND=1;' in log or 'BACKEND=0;' in log:
        env['QT_QUICK_BACKEND']='software'
        print('AVISO: RHI ('+env['QSG_RHI_BACKEND']+') no disponible. SOFTWARE: material mate de respaldo; SIN desenfoque. El cristal real requiere RHI.',flush=True)
    else:
        print('RHI '+env['QSG_RHI_BACKEND']+': cristal con desenfoque real.',flush=True)
    for state,mode in [(s,'dark') for s in ('desktop','search','actions','multitask','controls')]+[('desktop','light')]:
        path=root/'captures'/f'{state}-{mode}.png'
        result=run(state,mode,path)
        log=result.stdout+result.stderr
        if result.returncode or any(e in log for e in errors) or not path.exists():
            sys.exit(log)
        assert struct.unpack('>II',path.read_bytes()[16:24])==(2048,1280),path
        print(log.strip(),flush=True)
print('OK: 6 capturas a 2048×1280; sin errores QML.',flush=True)
PY
