#!/usr/bin/env bash
# GPU and lifecycle checks, isolated from the user's configuration and D-Bus.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
build_dir=${SINGLR_TEST_BUILD_DIR:-$root/build}
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/runtime"
chmod 700 "$tmp/runtime"
printf '[KDE]\nAnimationDurationFactor=1\n' > "$tmp/config/kdeglobals"
export XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state" XDG_RUNTIME_DIR="$tmp/runtime" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/no-session-bus" DBUS_SYSTEM_BUS_ADDRESS="unix:path=$tmp/no-system-bus"
"$build_dir/session/appearance/singlr-singularity-test"
/usr/lib/qt6/bin/qmltestrunner -import "$build_dir/qml" -import "$root/shell/qml" -input "$root/tests/shell/tst_SingularityGpu.qml"
printf '[KDE]\nAnimationDurationFactor=0\n' > "$tmp/config/kdeglobals"
/usr/lib/qt6/bin/qmltestrunner -import "$build_dir/qml" -import "$root/shell/qml" -input "$root/tests/shell/tst_SingularityGpu.qml"
