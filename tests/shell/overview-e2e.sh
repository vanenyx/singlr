#!/usr/bin/env bash
# Prueba real del efecto singlr-overview en KWin anidado con 3 ventanas de Dolphin.
# Uso: tests/shell/overview-e2e.sh <salida.png>
set -u
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
out="${1:-/tmp/singlr-overview.png}"
work="$(mktemp -d)"
mkdir -p "$work/data/kwin/effects" && cp -a "$root/kwin/effects/singlr-overview" "$work/data/kwin/effects/"
SINGLR_EXTRA_DATA_DIRS="$work/data" SINGLR_DURATION_MS=120000 "$root/tools/run-singlr.sh" > "$work/session.log" 2>&1 &
until grep -q SINGLR_SESSION_FILE "$work/session.log" 2>/dev/null; do sleep 0.5; done
descriptor=$(grep -m1 -oE "/tmp/singlr-session-[^ ]+/session.json" "$work/session.log")
eval "$(python3 -c "import json,shlex,sys;d=json.load(open(sys.argv[1]));print(' '.join('export %s=%s;'%(k,shlex.quote(v)) for k,v in d['env'].items()))" "$descriptor")"
unset DISPLAY
sleep 2
for p in /usr /etc /tmp; do dolphin --new-window "$p" >/dev/null 2>&1 & sleep 1.2; done
sleep 3
echo "carga: $(qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect singlr-overview)"
qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Singlr Overview'
sleep 1.5
timeout 20 spectacle -b -n -f -o "$out" && echo "captura: $out"
grep -E "effect:|main.qml" "$work/session.log" | tail -3
# Fin: cerrar el shell de esta sesión termina la sesión y su limpieza.
for p in $(pgrep -x singlr-shell); do tr '\0' '\n' < /proc/$p/environ | grep -q "SINGLR_SESSION_ID" && kill "$p"; done
wait
rm -rf "$work"
