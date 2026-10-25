#!/usr/bin/env bash
# Outputs disappearing and returning (resume, unplug) with the real shell on a
# virtual KWin and a private bus. Expected: shell alive, one bar and background
# per output and exactly one dock at every step.
# Usage: dbus-run-session -- tests/shell/hotplug-e2e.sh > hotplug.log  (a file, not a pipe:
# bus-activated services inherit stdout and would keep a pipe open)
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
export XDG_RUNTIME_DIR=$(mktemp -d); chmod 700 "$XDG_RUNTIME_DIR"
export XDG_CONFIG_HOME=$XDG_RUNTIME_DIR/config XDG_CACHE_HOME=$XDG_RUNTIME_DIR/cache XDG_STATE_HOME=$XDG_RUNTIME_DIR/state
export QT_FORCE_STDERR_LOGGING=1 DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent
unset WAYLAND_DISPLAY DISPLAY
mkdir -p "$XDG_CONFIG_HOME"
script=$XDG_RUNTIME_DIR/count.js
cat > "$script" <<'JS'
var docks = 0, bars = 0, outputs = {};
for (const w of workspace.windowList()) if (w.resourceClass == "singlr-shell") {
    const g = w.frameGeometry, o = w.output ? w.output.name : "?";
    if (g.height == 28) { bars++; outputs[o] = 1; } else if (g.height == 48) docks++;
}
print("SINGLRCOUNT bars=" + bars + " docks=" + docks + " outputs=" + Object.keys(outputs).length);
JS
kwin_wayland --virtual --output-count 2 --width 1280 --height 800 --socket singlr-hotplug \
    --no-lockscreen --no-global-shortcuts --no-kactivities >"$XDG_RUNTIME_DIR/kwin.log" 2>&1 &
kwin=$!
for _ in $(seq 50); do qdbus6 org.kde.KWin /KWin >/dev/null 2>&1 && break; sleep .2; done
export WAYLAND_DISPLAY=singlr-hotplug QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland
"$root/shell/session/build/singlr-shell" "$root/shell/qml" "$root/shell/qml/Shell.qml" >"$XDG_RUNTIME_DIR/shell.log" 2>&1 &
shell=$!
status=0
check() {
    local id
    id=$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$script" "c$1")
    qdbus6 org.kde.KWin "/Scripting/Script$id" run; sleep .5
    qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "c$1" >/dev/null
    local line; line=$(grep -a SINGLRCOUNT "$XDG_RUNTIME_DIR/kwin.log" | tail -1 | sed 's/.*SINGLRCOUNT //')
    if [ "$line" = "bars=$2 docks=1 outputs=$2" ]; then echo "PASS $1: $line"; else echo "FAIL $1: $line (esperado bars=$2 docks=1)"; status=1; fi
}
sleep 6; check inicio 2
kscreen-doctor output.2.disable >/dev/null 2>&1; sleep 2; check "salida retirada" 1
kscreen-doctor output.2.enable >/dev/null 2>&1; sleep 4; check "salida devuelta" 2
if kill -0 "$shell" 2>/dev/null; then echo "PASS shell vivo"; else echo "FAIL shell terminado"; status=1; fi
if grep -aq "TypeError" "$XDG_RUNTIME_DIR/shell.log"; then echo "FAIL errores QML:"; grep -a TypeError "$XDG_RUNTIME_DIR/shell.log" | sort -u; status=1; fi
kill "$shell" "$kwin" 2>/dev/null; wait 2>/dev/null; rm -rf -- "$XDG_RUNTIME_DIR"
exit $status
