#!/usr/bin/env bash
# QML suites in a hermetic KDE profile: appearance now follows KDE, so the host's
# palette and live session bus must not leak in (no calls reach the running shell).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
build_dir=${SINGLR_TEST_BUILD_DIR:-$root/build}
[ -f "$build_dir/qml/Singlr/System/qmldir" ] || { echo "Falta build/qml: cmake --build build" >&2; exit 2; }
mode=${SINGLR_TEST_MODE:-dark}
capture=""
if [[ ${1:-} == --capture ]]; then capture=${2:?before or after}; shift 2; fi
if [[ ${1:-} == --light ]]; then mode=light; shift; fi
[[ $mode == light || $mode == dark ]] || { echo "Modo inválido" >&2; exit 2; }
scheme=BreezeDark; [[ $mode == dark ]] || scheme=BreezeLight
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/data" "$tmp/runtime"
chmod 700 "$tmp/runtime"
factor=${SINGLR_TEST_ANIMATION_FACTOR:-1}
[[ "$factor" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "Factor de animación inválido" >&2; exit 2; }
printf '[General]\nColorScheme=%s\n[KDE]\nAnimationDurationFactor=%s\n' "$scheme" "$factor" > "$tmp/config/kdeglobals"
cp /usr/share/color-schemes/"$scheme".colors "$tmp/config/kdeglobals.colors" 2>/dev/null || true
cat /usr/share/color-schemes/"$scheme".colors >> "$tmp/config/kdeglobals"
export XDG_DATA_HOME="$tmp/data" XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state" \
       QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde QT_QUICK_BACKEND=software \
       DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp/disabled-session-bus" DBUS_SYSTEM_BUS_ADDRESS="unix:path=$tmp/disabled-system-bus"
# Stage the package exactly as installed, including fonts; use an enum-only
# authenticator boundary for presentation tests (never PAM or the live greeter).
python3 - "$root" "$tmp" <<'PYFIXTURE'
from pathlib import Path
import shutil
import sys
root, tmp = map(Path, sys.argv[1:])
lock = tmp / "package/contents/lockscreen"
shutil.copytree(root / "session/shell-package/org.singlr.desktop/contents/lockscreen", lock)
fonts = lock.parent / "fonts"
fonts.mkdir()
for source in ("inter/InterVariable.ttf", "phosphor/Phosphor.ttf"):
    shutil.copy2(root / "third_party" / source, fonts)
fixtures = tmp / "tests"
fixtures.mkdir()
if (root / "shell/qml/tests/fixtures").is_dir():
    shutil.copytree(root / "shell/qml/tests/fixtures", fixtures / "fixtures")
for source in (root / "shell/qml/tests").glob("*.qml"):
    text = source.read_text().replace('"../../../session/shell-package/org.singlr.desktop/contents/lockscreen"', f'"{lock.as_uri()}"')
    text = text.replace('"../../../apps/settings/Main.qml"', f'"{(root / "apps/settings/Main.qml").as_uri()}"')
    text = text.replace('"../../../session/kwin/tabbox/singlr/contents/ui"', f'"{(root / "session/kwin/tabbox/singlr/contents/ui").as_uri()}"')
    text = text.replace('"../Singlr/Ui/Theme.js"', f'"{(root / "shell/qml/Singlr/Ui/Theme.js").as_uri()}"')
    text = text.replace('"../../../tests/shell/fixtures/command-contract.json"', f'"{(root / "tests/shell/fixtures/command-contract.json").as_uri()}"')
    (fixtures / source.name).write_text(text)
imports = tmp / "imports/org/kde/kscreenlocker"
imports.mkdir(parents=True)
(imports / "qmldir").write_text("module org.kde.kscreenlocker\nsingleton Authenticator 1.0 Authenticator.qml\n")
(imports / "Authenticator.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { enum Kind { Fingerprint = 1, Smartcard = 2 } }\n")
PYFIXTURE
if [[ -n $capture ]]; then
    [[ $capture == before || $capture == after ]] || { echo "Usa --capture before|after" >&2; exit 2; }
    mkdir -p "$root/shell/qml/captures/t244"
    printf '[General]\ncapturePrefix=%s/shell/qml/captures/t244/%s-%s\n' "$root" "$capture" "$mode" > "$tmp/config/t244.ini"
    /usr/lib/qt6/bin/qmltestrunner -import "$tmp/imports" -import "$root/shell/qml" -import "$build_dir/qml" -input "$tmp/tests/tst_AppearanceCapture.qml"
    exit $?
fi
if [[ ${SINGLR_CAPTURE_T250:-0} == 1 ]]; then
    mkdir -p "$root/tests/shell/evidence/t250"
    printf '[General]\ncapturePrefix=%s/tests/shell/evidence/t250/%s\n' "$root" "$mode" > "$tmp/config/t250.ini"
fi
if [[ ${SINGLR_CAPTURE_T254:-0} == 1 ]]; then
    mkdir -p "$root/tests/shell/evidence/t254"
    printf '[General]\ncapturePrefix=%s/tests/shell/evidence/t254/%s\n' "$root" "$mode" > "$tmp/config/t254.ini"
fi
if [[ ${SINGLR_CAPTURE_T255:-0} == 1 ]]; then
    mkdir -p "$root/tests/shell/evidence/t255"
    printf '[General]\ncapturePrefix=%s/tests/shell/evidence/t255/%s\n' "$root" "$mode" > "$tmp/config/t255.ini"
fi
status=0
for suite in "$tmp/tests" "$root/apps/settings/tests"; do
    [ -d "$suite" ] || continue
    /usr/lib/qt6/bin/qmltestrunner -import "$tmp/imports" -import "$root/shell/qml" -import "$build_dir/qml" -input "$suite" || status=1
done
exit $status
