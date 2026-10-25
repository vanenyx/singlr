#!/usr/bin/env bash
# Capture native KRunner matches; never use the current desktop's session bus.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
output=${1:?Usage: tools/capture-command-fixture.sh OUTPUT.json}
cmake --build "$root/build" --target singlr-command-capture -j2 >&2
profile=$(mktemp -d)
trap 'rm -rf -- "$profile"' EXIT
mkdir -p "$profile"/{config,data,cache,state,runtime}
chmod 700 "$profile/runtime"
export XDG_CONFIG_HOME="$profile/config" XDG_DATA_HOME="$profile/data" \
    XDG_CACHE_HOME="$profile/cache" XDG_STATE_HOME="$profile/state" XDG_RUNTIME_DIR="$profile/runtime" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=$profile/no-system-bus" LC_ALL=C.UTF-8 LANGUAGE=es
# Do not leave a partial fixture when the sandbox cannot create a private bus.
dbus-run-session -- timeout 120 "$root/build/shell/command/singlr-command-capture" > "$profile/matches.json"
python3 - "$profile/matches.json" "$output" <<'PY'
import json, pathlib, subprocess, sys
source, destination = map(pathlib.Path, sys.argv[1:])
data = json.loads(source.read_text())
if any(q[mode + 'TimedOut'] for q in data['queries'] for mode in ('general', 'settings')):
    raise SystemExit('Capture timed out; refusing to save an incomplete fixture')
data['provenance'] = {'kind': 'native-private-bus', 'versions': subprocess.check_output(
    ['pacman', '-Q', 'plasma-workspace', 'milou', 'krunner', 'systemsettings'], text=True).splitlines()}
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
PY
