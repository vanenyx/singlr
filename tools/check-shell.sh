#!/usr/bin/env bash
set -euo pipefail
"$(dirname "$(realpath "$0")")/../shell/session/build.sh" >/dev/null
exec python3 "$(dirname "$(realpath "$0")")/check-shell.py" "$@"
