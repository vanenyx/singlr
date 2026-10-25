#!/usr/bin/env bash
# QML suites in a hermetic KDE profile: appearance now follows KDE, so the host's
# palette and live session bus must not leak in (no calls reach the running shell).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
[ -f "$root/build/qml/Singlr/System/qmldir" ] || { echo "Falta build/qml: cmake --build build" >&2; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/config"
factor=${SINGLR_TEST_ANIMATION_FACTOR:-1}
[[ "$factor" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "Factor de animación inválido" >&2; exit 2; }
printf '[General]\nColorScheme=BreezeDark\n[KDE]\nAnimationDurationFactor=%s\n' "$factor" > "$tmp/config/kdeglobals"
cp /usr/share/color-schemes/BreezeDark.colors "$tmp/config/kdeglobals.colors" 2>/dev/null || true
cat /usr/share/color-schemes/BreezeDark.colors >> "$tmp/config/kdeglobals"
export XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state" \
       QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde QT_QUICK_BACKEND=software \
       DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent
status=0
for suite in "$root/shell/qml/tests" "$root/apps/settings/tests"; do
    [ -d "$suite" ] || continue
    /usr/lib/qt6/bin/qmltestrunner -import "$root/shell/qml" -import "$root/build/qml" -input "$suite" || status=1
done
exit $status
