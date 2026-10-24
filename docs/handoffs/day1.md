# Día 1 — 24 oct 2026

## Hitos
- **H1 ✓** Entorno verificado. Bloqueo: sin `cmake`, `ninja` ni `extra-cmake-modules`. Se trabaja con QML más un lanzador C++ compilado con g++.
- **H2 ✓** Módulos `Singlr.Ui` (tema, iconos, cristal, filas) y `Singlr.Shell`; contrato en `docs/phase1/shell-contract.md`.
- **H3 ✓** Shell integrado en KWin anidado:
  - barra superior: fecha y hora en español y batería real;
  - dock: lanzadores fijados y ventanas reales de TasksModel (activar, minimizar, nueva ventana, cerrar);
  - lanzador de KRunner (Milou) con teclado y acciones Ctrl+K;
  - catálogo de aplicaciones instaladas.
- **H4 ✓** E2E real 12/12 PASS (`tests/shell/e2e.py`). qmllint y carga: PASS. qmltestrunner 15/15. unittest 9/9.
- **H5 ✓** Commits en `main` (sin push).

## Corregido por Claude en integración
- Lanzador C++ que activa layer-shell solo para el shell (`shell/session/src/main.cpp`).
- `transientParent: null` en las ventanas de sesión.
- KRunner bloquea si se consulta antes de que arranque el bucle de eventos: consultas diferidas.
- E2E: reintento de `/Scripting` de KWin, sonda con raíz Item, zombis y espera a KWin al cerrar.

## Pendiente para el 25
- Comprobar en sesión, con interacción manual, el overlay del lanzador, el catálogo, el foco y los indicadores de red y volumen. La E2E no simula teclado ni ratón.
- El cristal en sesión no desenfoca ventanas ajenas: evaluar el blur de KWin (KWindowEffects) desde el lanzador C++.
- Paquete instalable y binario CMake cuando el creador instale `cmake ninja extra-cmake-modules`.
- Centro de control, notificaciones, multitarea y espacios.
