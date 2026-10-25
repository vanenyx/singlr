#!/usr/bin/env bash
# Read-only checks against the installed KWin; temporary files only.
set -eu
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
qtbin=/usr/lib/qt6/bin
scratch=$(mktemp -d /tmp/singlr-overview-check.XXXXXX)
trap 'rm -rf -- "$scratch"' EXIT
imports="$scratch/imports"
mkdir -p "$imports/org/kde/kwin"
printf 'module org.kde.kwin\ntypeinfo kwin.qmltypes\ndepends QtQuick\n' > "$imports/org/kde/kwin/qmldir"
# The public module is registered/embedded in libkwin, not a filesystem plugin.
# -noinstantiate is essential: Workspace needs a running compositor.
QT_QPA_PLATFORM=offscreen LD_PRELOAD=/usr/lib/libkwin.so.6 \
    "$qtbin/qmlplugindump" -noinstantiate -nonrelocatable \
    org.kde.kwin 3.0 /usr/lib/qt6/qml > "$imports/org/kde/kwin/kwin.qmltypes"
lint_status=0
"$qtbin/qmllint" -I "$imports" -I /usr/lib/qt6/qml \
    "$root/contents/ui/main.qml" || lint_status=$?
printf 'qmllint exit: %s (runtime dump has incomplete type metadata)\n' "$lint_status"
g++ -fPIC "$root/tools/check-load.cpp" -o "$scratch/check-load" \
    $(pkg-config --cflags --libs Qt6Core Qt6Gui Qt6Qml)
QT_QPA_PLATFORM=offscreen "$scratch/check-load" "$root/contents/ui/main.qml"
# Do not report a clean lint when metadata warnings remain.
exit "$lint_status"
