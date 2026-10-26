#!/usr/bin/env bash
# Standalone native window; no shell restart, host preferences or session D-Bus.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
build_dir=${SINGLR_TEST_BUILD_DIR:-$root/.local/build-singularity}
[[ -f "$build_dir/qml/Singlr/System/qmldir" ]] || build_dir="$root/build"
[[ -f "$build_dir/qml/Singlr/System/qmldir" ]] || { echo 'Compila primero el módulo Singlr.System.' >&2; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/config"
printf '[KDE]\nAnimationDurationFactor=1\n' > "$tmp/config/kdeglobals"
export XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state" \
    QML_IMPORT_PATH="$build_dir/qml:$root/shell/qml" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/no-session-bus" DBUS_SYSTEM_BUS_ADDRESS="unix:path=$tmp/no-system-bus"
unset QT_WAYLAND_SHELL_INTEGRATION
qml6 -I "$build_dir/qml" -I "$root/shell/qml" "$root/tests/shell/SingularityPreview.qml"
