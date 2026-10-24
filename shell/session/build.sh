#!/usr/bin/env bash
# Compila el lanzador sin cmake (no instalado): g++ con pkg-config de Qt6 y LayerShellQt.
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
out="$here/build/singlr-shell"
mkdir -p "$here/build"
if [[ ! -x "$out" || "$here/src/main.cpp" -nt "$out" ]]; then
    # shellcheck disable=SC2046
    g++ -std=c++17 -O2 -fPIC "$here/src/main.cpp" -o "$out" \
        $(pkg-config --cflags --libs Qt6Gui Qt6Qml Qt6Quick) -lLayerShellQtInterface
fi
echo "$out"
