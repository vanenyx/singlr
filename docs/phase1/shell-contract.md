# Contrato del shell — Día 1 (24 oct)

Solución técnica derivada (Claude). No aprueba decisiones visuales.

## Arquitectura mínima
- **Shell QML** ejecutado con `qml6 -I shell/qml shell/qml/Shell.qml`. Sin compilación: no hay cmake ni ECM. El paso a un binario C++ instalable queda pendiente de que el creador instale `cmake ninja extra-cmake-modules`.
- **Capacidades nativas de KDE desde QML, verificadas el 24 oct:**
  - `org.kde.milou`: ResultsModel de KRunner para buscar y lanzar aplicaciones, archivos y acciones.
  - `org.kde.taskmanager`: TasksModel para ventanas abiertas, lanzadores fijados, activar y lanzar.
  - `org.kde.layershell`: superficies del shell sobre KWin.
  - `org.kde.kirigami`: Kirigami.Icon para los iconos de aplicaciones del tema.
- **Ejecución aislada:** KWin anidado con XDG y D-Bus propios. Las apps lanzadas desde el shell se abren dentro de esa sesión. Nunca se toca la sesión KDE habitual.

## Propiedad de archivos
- Codex 1: `shell/qml/**`.
- Codex 2: `tools/**`, `shell/session/**` y `tests/shell/**`.
- Claude: `docs/**`, integración y merge.

## Interfaz entre ambos
- Punto de entrada: `shell/qml/Shell.qml`, con import path `shell/qml`.
- Argumentos de `Qt.application.arguments`:
  - `--windowed`: todas las superficies en una sola ventana, sin layer-shell, para desarrollo y captura offscreen.
  - `--capture=<png>`: captura en modo ventana.
  - Sin argumentos: modo sesión, con superficies layer-shell.
- Lanzador de sesión: `tools/run-singlr.sh [--size WxH]`. Arranca el KWin anidado, prepara el entorno y ejecuta el punto de entrada. Si el archivo no existe, lo dice.
