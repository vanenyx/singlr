# Contrato: Ajustes de Singlr

- **Almacenamiento:** `~/.config/singlr/singlr.conf` (INI, QtCore.Settings con `location`), grupo `Appearance`:
  - `mode` = dark | light | auto (auto sigue la hora: claro de 7:00 a 19:00, o el esquema de KDE si se puede leer);
  - `accent` = color en `#rrggbb`;
  - `wallpaper` = `singlr:<preset>` o `file:///ruta`;
  - `applyToApps` = true | false.
- **App:** `apps/settings/Main.qml` (Codex 1), ventana normal ejecutada con `qml6` (no layer-shell), lanzada por `apps/settings/singlr-settings` (script) y con el acceso `apps/settings/singlr-settings.desktop` (Codex 2).
- **Recarga:** tras guardar, la app llama por D-Bus a `org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell singlrReloadSettings`; el lanzador (Codex 2) invoca `reloadSettings()` en Session (Codex 1), que relee el archivo y actualiza Theme y el fondo sin reiniciar.
- **Aplicar a las apps:** si `applyToApps`, la app ejecuta `plasma-apply-colorscheme BreezeDark|BreezeLight` (cambio visible del usuario, reversible desde la propia app).
