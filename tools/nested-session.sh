#!/usr/bin/env bash
set -euo pipefail
# Communicate the private bus address to the runner; never expose the host bus.
printf '%s' "$DBUS_SESSION_BUS_ADDRESS" > "$1"
shift
# A full session controller can share the same private-bus bootstrap.
if [[ ${1:-} == --command ]]; then
    shift
    exec "$@"
fi
exec kwin_wayland "$@"
