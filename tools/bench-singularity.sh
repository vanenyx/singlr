#!/usr/bin/env bash
# Private 60 Hz virtual KWin, Vulkan timestamps, 2 s warm-up + 6 s per scenario.
# Usage: SINGLR_TEST_BUILD_DIR=$PWD/.local/build-singularity tools/bench-singularity.sh [log-dir]
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
if [[ ${1:-} == --private ]]; then
    bin=${2:?}; logs=${3:?}
    kwin_pid=""
    cleanup() {
        if [[ -n $kwin_pid ]]; then kill "$kwin_pid" 2>/dev/null || true; wait "$kwin_pid" 2>/dev/null || true; fi
    }
    trap cleanup EXIT
    kwin_wayland --virtual --width 2560 --height 1600 --socket singlr-bench \
        --no-lockscreen --no-global-shortcuts --no-kactivities >"$logs/kwin.log" 2>&1 &
    kwin_pid=$!
    ready=0
    for ((i=0; i<100; i++)); do
        kill -0 "$kwin_pid" 2>/dev/null || { echo 'Private KWin exited; see kwin.log' >&2; exit 1; }
        if [[ -S $XDG_RUNTIME_DIR/singlr-bench ]] && qdbus6 org.kde.KWin /KWin >/dev/null 2>&1; then ready=1; break; fi
        sleep .1
    done
    [[ $ready == 1 ]] || { echo 'Private KWin did not become ready' >&2; exit 1; }
    for quality in 0 1 2; do
        for scenario in idle cursor; do
            # Regular files are essential: D-Bus-activated services inherit stdout.
            WAYLAND_DISPLAY=singlr-bench QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=rhi \
                QSG_RHI_BACKEND=vulkan VK_LOADER_DRIVERS_SELECT="${VK_LOADER_DRIVERS_SELECT:-*radeon*}" \
                timeout 20s "$bin" "$quality" "$scenario" >"$logs/q$quality-$scenario.log" 2>&1
        done
    done
    exit 0
fi
build_dir=${SINGLR_TEST_BUILD_DIR:-$root/.local/build-singularity}
bin="$build_dir/session/appearance/singlr-singularity-bench"
[[ -x $bin ]] || { echo "Build first: cmake --build $build_dir --target singlr-singularity-bench" >&2; exit 2; }
logs=${1:-$root/.local/bench-singularity/$(date +%Y%m%d-%H%M%S)-$$}
mkdir -p "$logs"
logs=$(cd "$logs" && pwd)
# Set isolation before starting D-Bus: activated services inherit the daemon's
# environment, not later exports made by its client.
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" \
XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state" DBUS_SYSTEM_BUS_ADDRESS="unix:path=$tmp/no-system-bus"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY WAYLAND_SOCKET QT_QUICK_BACKEND QT_SCREEN_SCALE_FACTORS
export QT_SCALE_FACTOR=1
# No pipeline here: private bus services must never hold an output pipe open.
dbus-run-session -- "$0" --private "$bin" "$logs" >"$logs/session.log" 2>&1 || {
    echo "Benchmark failed; logs: $logs" >&2; exit 1;
}
python3 - "$logs" <<'PY'
from pathlib import Path
import sys
logs = Path(sys.argv[1])
rows = []
for quality in range(3):
    for scenario in ('idle', 'cursor'):
        lines = (logs / f'q{quality}-{scenario}.log').read_text().splitlines()
        results = [line.split() for line in lines if line.startswith('RESULT ')]
        if len(results) != 1:
            raise SystemExit(f'Missing/ambiguous measurement: q{quality}-{scenario}.log')
        _, q, mode, fps, ms, load, samples, seconds = results[0]
        rows.append(f'| {q} | {mode} | {fps} | {ms} | {load} | {samples} | {seconds} |')
table = '\n'.join(['| Calidad | Escenario | fps | ms GPU/fotograma | Ocupación GPU % | Muestras | Segundos |',
                   '| --- | --- | ---: | ---: | ---: | ---: | ---: |', *rows])
(logs / 'results.md').write_text(table + '\n')
print(table)
print(f'Logs: {logs}')
print('Ocupación = suma de timestamps / tiempo real; no mide toda la GPU. GPU compartida: ruido aproximado ±25 %.')
PY
