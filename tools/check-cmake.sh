#!/usr/bin/env bash
set -euo pipefail
if ! command -v cmake >/dev/null 2>&1; then
    echo 'CMake no está disponible; configuración, compilación y DESTDIR pendientes.'
    exit 0
fi
root="$(dirname "$(dirname "$(realpath "$0")")")"
cmake -S "$root" -B "$root/build" -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build "$root/build" --parallel "${CMAKE_BUILD_PARALLEL_LEVEL:-2}"
stage="$(mktemp -d "${TMPDIR:-/tmp}/singlr-cmake.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
DESTDIR="$stage" cmake --install "$root/build"
python3 "$root/tests/shell/verify_package.py" "$stage"
if [[ $(< "$root/build/CMakeCache.txt") == *"SINGLR_BUILD_LIQUIDGLASS:BOOL=ON"* ]]; then
    test -s "$stage/usr/lib/qt6/plugins/kwin/effects/plugins/singlr-liquidglass.so"
    echo 'CMake: pase externo de Vidrio incluido en staging.'
fi
echo 'CMake: compilación e instalación DESTDIR verificadas (staging temporal eliminado).'
