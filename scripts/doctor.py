#!/usr/bin/env python3
"""Inventario de rutas y versiones sin tocar la sesión de escritorio."""
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def locate(name):
    candidates = [shutil.which(name), str(Path.home() / ".local/bin" / name),
                  str(Path("/usr/lib/qt6/bin") / name)]
    return next((p for p in candidates if p and os.path.isfile(p)
                 and os.access(p, os.X_OK)), None)


def version(command):
    try:
        result = subprocess.run(command, text=True, capture_output=True, timeout=10)
        lines = (result.stdout + result.stderr).strip().splitlines()
        return lines[0][:220] if lines else f"sin salida (código {result.returncode})"
    except (OSError, subprocess.TimeoutExpired) as exc:
        return f"no comprobada: {exc}"


print("Inventario local; las ausencias de desarrollo no bloquean esta fase.")
for name in ("git", "python3", "claude", "codex", "cmake", "ninja",
             "qmllint", "qmlformat", "qmake6", "qtpaths", "plasmashell",
             "kwin_wayland", "plasmoidviewer", "gh"):
    path = locate(name)
    # No arrancar compositores, visores ni clientes agénticos para inventariarlos.
    detail = ""
    if path and name in {"git", "python3", "claude", "cmake", "ninja", "qmllint", "qmlformat"}:
        detail = " | " + version([path, "--version"])
    elif path and name == "qmake6":
        detail = " | " + version([path, "-query", "QT_VERSION"])
    print(f"{name}: {path or 'NO ENCONTRADO'}{detail}")
for key in ("XDG_SESSION_TYPE", "XDG_CURRENT_DESKTOP"):
    print(f"{key}: {os.environ.get(key, 'no disponible')}")
print("Git:", version(["git", "-C", str(ROOT), "status", "--short", "--branch"]))
print("No se ha compilado ni ejecutado Singlr.")
