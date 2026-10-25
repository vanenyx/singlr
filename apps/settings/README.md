# T228 — Ajustes de Singlr

App normal de 880×600, sin layer-shell. `Main.qml` importa el módulo UI por
ruta relativa: se puede abrir con `qml6 apps/settings/Main.qml` desde la raíz.
El `.desktop` debe identificarse como `singlr-settings.desktop` para los accesos
del anillo y del centro de control. El lanzador y el registro D-Bus corresponden
a Codex 2.

## Contrato implementado

`Singlr.Ui.Appearance` usa QtCore.Settings, con `location` en
`StandardPaths.ConfigLocation + /singlr/singlr.conf` y categoría `Appearance`.
Guarda con `setValue()` y `sync()` antes de notificar. Relee mediante
`sync()`/`value()`; no depende de notificaciones entre instancias de Settings.
Modo y acento inválidos recuperan sus valores predeterminados. Los presets son
`singlr:linear` (predeterminado), `singlr:glow`, `singlr:light` y
`singlr:graphite`; también admite imágenes locales `file:///…`.

`Session.reloadSettings()` llama a `Theme.reloadSettings()`: relee el archivo,
restaura enlaces de modo/acento y actualiza la hora. En automático, claro de
07:00 a 18:59; el temporizador revisa cada minuto. `Wallpaper` comparte el fondo
entre la app y la shell, recorta imágenes con PreserveAspectCrop y conserva el
preset predeterminado detrás de una imagen mientras carga o si falla.

La app ejecuta el auxiliar mínimo `apply-settings.py` mediante el DataSource
`executable` de Plasma5Support. Agrupa cambios próximos y serializa procesos.
El auxiliar llama a `plasma-apply-colorscheme BreezeDark|BreezeLight` solo si
`applyToApps` está activo y después llama a:

```
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.singlrReloadSettings
```

Usa `/usr/lib/qt6/bin/qdbus` si no encuentra `qdbus6`. Si la sesión o el esquema
no están disponibles, conserva el guardado y muestra el aviso dentro de la app.
Desactivar «Aplicar también…» deja de enviar cambios de esquema a KDE; no
restaura un esquema anterior. No se ejecutan efectos al abrir la app.

## Presentación e interacción

Propuesta derivada del encargo: navegación tenue de 200 px, contenido estable,
filas de 40 px, separadores discretos, Inter y Phosphor compartidos. Sin
animaciones decorativas. Las muestras mantienen los siete colores solicitados;
el anillo de selección, el segmento y el interruptor usan tonos neutros.
Los controles de Qt Quick tienen nombres accesibles, navegación Tab, activación
por teclado e indicación de foco. El botón de elegir imagen abre FileDialog.

Las superficies translúcidas, pistas, interruptores, errores y perfiles de
batería de la shell ahora usan tokens semánticos de Theme. El blanco de Glass
que permanece es una máscara invisible del shader, independiente del modo.
También se corrigió una referencia inválida a `focusReason` en Tool (Item no
expone esa propiedad); los clics no solicitan foco y el teclado sí.

No había una app inicial que capturar. Evidencia nueva revisada:
[apariencia oscura](captures/appearance-dark.png) y
[fondo en modo claro](captures/wallpaper-light.png).

## Comprobación (Qt 6.12.0)

```
/usr/lib/qt6/bin/qmllint -I shell/qml -i shell/qml/Singlr/Ui/qmldir \
  shell/qml/Shell.qml shell/qml/Singlr/Ui/*.qml \
  shell/qml/Singlr/Shell/*.qml shell/qml/tests/*.qml \
  apps/settings/Main.qml apps/settings/tests/*.qml
```

Exit 0, sin avisos. `git diff --check`: limpio.

Con `QT_QPA_PLATFORM=offscreen`, `QT_QUICK_BACKEND=software`,
`QT_FORCE_STDERR_LOGGING=1`, `XDG_CACHE_HOME` y `XDG_CONFIG_HOME` aislados en
`/tmp`, se ejecutó `qmltestrunner -import shell/qml`:

- `-input shell/qml/tests`: **98 passed, 0 failed**.
- `-input apps/settings/tests`: **7 passed, 0 failed**. Persistencia desde los
  controles, recarga desde otra instancia, valores inválidos, límites horarios,
  fondo fallido y proceso auxiliar con D-Bus deliberadamente inaccesible.
  El aviso de imagen ausente es esperado en esa prueba.
- Auxiliar Python: ambos esquemas y argumentos exactos D-Bus comprobados con
  `subprocess.run` simulado; no se cambió el esquema KDE real.

Capturas con `qml6 apps/settings/Main.qml -- --capture=<ruta.png>` y
`--wallpaper --capture=<ruta.png>`, ambas exit 0. El canvas incluye su propio
fondo para que grabToImage capture también la superficie de la ventana.

API Settings/FileDialog contrastada con documentación oficial Qt 6.12:
https://doc.qt.io/qt-6/qml-qtcore-settings.html y
https://doc.qt.io/qt-6/qml-qtquick-dialogs-filedialog.html.
DataSource y motor executable contrastados con los qmltypes y plugins locales
instalados de Plasma 6.

Pendiente de integración: `.desktop`, script lanzador y exposición D-Bus de
Codex 2, prueba completa en sesión aislada y selección con el diálogo nativo.
No se modificó la sesión KDE habitual. Sin commit.
