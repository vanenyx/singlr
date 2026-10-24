#!/usr/bin/env bash
set -euo pipefail
# Communicate the private bus address to the runner; never expose the host bus.
printf '%s' "$DBUS_SESSION_BUS_ADDRESS" > "$1"
shift
exec kwin_wayland "$@"
