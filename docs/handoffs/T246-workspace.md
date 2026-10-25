# T246 — Codex 1, Singlr Workspace

Rama `day3/codex1-workspace`, sin commit. Implementación y pruebas listas para
revisión de Claude; integración real bloqueada por sockets del sandbox.

- KPackage Alt+Tab propio, miniaturas/iconos/títulos, selección compartida con
  KWin, clic/flechas; Alt/Shift+Tab/aceptación/cancelación quedan en KWin.
  Empaquetado con tokens compartidos y activación/restauración transaccional.
  Recuperación compatible con journals anteriores sin TabBox.
- Barra con indicador discreto solo para varios escritorios, IDs/nombres reales,
  selección por salida y activación mediante VirtualDesktopManager de KWin.
- Overview comparte materiales, tipografía, Phosphor, foco y movimiento reducido;
  conserva creación/traslado/cambio por APIs KWin, añade confirmación al quitar y
  escritura hacia Command con texto/salida. Ctrl+1…9 selecciona escritorio para
  que escribir números también busque. Puente mínimo en `session/appearance`,
  dentro del módulo Singlr.System existente y del servicio del shell existente.
- Organización documentada con Alt+F3, Meta+←/→ y editor nativo Meta+T.
  No se toca el motor de mosaicos ni los gestos/atajos globales de P-015.

Verificado: build y DESTDIR completos; QML **187 pass, 1 skip en cada modo**;
10 pruebas transaccionales KWin; 5 packaging; setup y sintaxis Python. Overview
compila Ready; lint Overview y switcher devuelve 0 con avisos de metadatos.
El intento de carga completa de TabBox fuera de KWin no terminó y no acredita
runtime. KWin anidado y medición P-016 bloqueados por `Operation not permitted`
al crear socket privado de D-Bus. Hashes anfitriones sin cambios.

Capturas QML reales con miniaturas simuladas:
[oscuro](../../tests/shell/evidence/t246/switcher-dark.png) ·
[claro](../../tests/shell/evidence/t246/switcher-light.png).
[Evidencia](../../tests/shell/evidence/t246/README.md) y
[recorrido anidado](../../session/WORKSPACE.md).

Claude puede ejecutar `python3 tests/shell/workspace-e2e.py --interactive`
fuera del sandbox, comprobar Alt+Tab, arrastre, búsqueda, pantallas y rendimiento,
y presentar capturas de KWin al creador. La propuesta visual no está aprobada;
no se ha recargado, instalado, publicado ni creado commit.
