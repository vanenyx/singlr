#!/usr/bin/env bash
# Prueba real de varias pantallas: KWin anidado con 2 salidas; lista las superficies del shell por salida.
set -u
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d)"
SINGLR_OUTPUTS=2 SINGLR_DURATION_MS=60000 "$root/tools/run-singlr.sh" --size 1280x800 > "$work/session.log" 2>&1 &
until grep -q SINGLR_SESSION_FILE "$work/session.log" 2>/dev/null; do sleep 0.5; done
descriptor=$(grep -m1 -oE "/tmp/singlr-session-[^ ]+/session.json" "$work/session.log")
eval "$(python3 -c "import json,shlex,sys;d=json.load(open(sys.argv[1]));print(' '.join('export %s=%s;'%(k,shlex.quote(v)) for k,v in d['env'].items()))" "$descriptor")"
unset DISPLAY
sleep 6
cat > "$work/list.js" <<'JS'
for (const o of workspace.screens) print("SINGLROUT", o.name, o.geometry.x, o.geometry.y, o.geometry.width, o.geometry.height);
for (const w of workspace.windowList()) if (w.resourceClass == "singlr-shell") print("SINGLRSURF", w.output ? w.output.name : "?", w.layer, w.frameGeometry.x, w.frameGeometry.y, w.frameGeometry.width, w.frameGeometry.height);
JS
id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$work/list.js" singlr-screens)
qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run; sleep 1
grep -E "SINGLROUT|SINGLRSURF" "$work/session.log" | sed 's/^js: //'
grep -iE "qml.*(error|TypeError|Reference)" "$work/session.log" | head -3
for p in $(pgrep -x singlr-shell); do tr '\0' '\n' < /proc/$p/environ | grep -q "SINGLR_SESSION_ID" && kill "$p"; done
wait; rm -rf "$work"
