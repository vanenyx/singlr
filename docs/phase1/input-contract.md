# Contrato de gestos y atajos (P-015)

## Shell QML (Codex 1): funciones de `Session` invocadas desde C++
- `showApplications()`: abre el lanzador en la vista de todas las aplicaciones.
- `toggleNotifications()`: abre o cierra el centro de notificaciones.
- `toggleControlCenter()`: abre o cierra el centro de control.
- `activateDockEntry(n)`: n de 1 a 9; equivale al clic en la entrada n del dock (fijadas y después abiertas, sin contar los botones finales).

## Lanzador C++ (Codex 2)
- **D-Bus `org.kde.plasmashell` `/PlasmaShell`** (ya lo atiende el puente): el miembro `singlrShowApplications` llama a `showApplications()`; cualquier otro conserva el comportamiento actual (`toggleLauncher`).
- **KGlobalAccel**, solo en modo sustitución:
  - Componente `plasmashell`, acciones `activate task manager entry 1` … `9`, con el atajo guardado (Meta+1…9), que llaman a `activateDockEntry(n)`.
  - Componente `singlr`, acciones «Mostrar notificaciones» (Meta+N) y «Centro de control» (Meta+A); si hay conflicto con otro componente, se anota y no se pisa.
  - KWin: «Window Maximize» = Meta+↑ y «Window Minimize» = Meta+↓, mediante `setForeignShortcutKeys`. Los atajos previos (incluidos los de «Window Quick Tile Top/Bottom» que usaban esas teclas) se guardan en `$XDG_RUNTIME_DIR/singlr-live/shortcuts-backup.json` y se restauran al cerrar el lanzador o con `tools/singlr-live.sh stop`.

## KWin (Codex 1)
- Efecto `singlr-overview`: `SwipeGestureHandler`, 3 dedos hacia arriba en el panel táctil, con progreso.
- Script declarativo `kwin/scripts/singlr-gestures`: 3 dedos hacia abajo alterna `workspace.showingDesktop`; la pinza de 4 dedos hacia dentro llama por D-Bus a `org.kde.plasmashell /PlasmaShell singlrShowApplications`.
