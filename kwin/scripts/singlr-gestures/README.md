# Singlr Gestures — T226 / P-015

Script declarativo para KWin 6.8.1:

- Tres dedos abajo alterna mostrar escritorio. Si `singlr-overview` estaba activo
  al comenzar el gesto, lo deja al efecto para cerrar la multitarea.
- Pinza de cuatro dedos hacia dentro llama a
  `org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.singlrShowApplications`.
  Requiere el puente Singlr en ese mismo bus.

Instalación posterior por Claude (no ejecutada):

```bash
mkdir -p ~/.local/share/kwin/scripts/singlr-gestures
cp -a kwin/scripts/singlr-gestures/{metadata.json,contents} \
  ~/.local/share/kwin/scripts/singlr-gestures/
```

Habilitar en `~/.config/kwinrc`, grupo `[Plugins]`:

```ini
singlr-gesturesEnabled=true
```

Recargar scripts mediante la configuración de KWin en la sesión elegida.
Para revertir, deshabilitar esa clave, descargar el script y retirar su carpeta.
La instalación y los gestos físicos se deben validar primero en sesión aislada;
no se modificó la sesión KDE actual. Revisar conflictos con gestos de otros efectos.

## Compatibilidad y comprobación

Tipos, enums y métodos contrastados con el módulo registrado por
`/usr/lib/libkwin.so.6` del paquete `kwin 6.8.1-2`, Qt 6.12.0.
`SwipeGestureHandler` tiene `direction`, `deviceType`, `fingerCount`, `progress`,
`activated` y `cancelled`; no tiene `enabled`. `PinchGestureHandler` usa
`Direction.Contracting`, sin propiedad `deviceType` exportada.
`DBusCall` usa **dbusInterface** y `call()`.

**Ajuste al contrato:** `Workspace.showingDesktop` no está exportado por esta
versión; `Workspace.slotToggleShowDesktop()` ofrece la alternancia requerida.
`Workspace.isEffectActive("singlr-overview")` permite comprobar el efecto sin
D-Bus asíncrono ni un segundo estado compartido.

Referencias oficiales:
[gestos](https://api.kde.org/qml-org-kde-kwin-swipegesturehandler.html),
[cabecera actual](https://raw.githubusercontent.com/KDE/kwin/master/src/scripting/gesturehandler.h).
Se intentó consultar `v6.8.1/src/scripting/gesturehandler.h` y las fuentes Overview
v6.8.x en Invent/GitHub, pero no fueron accesibles desde este entorno. La cabecera
actual sirve solo de contraste; la evidencia de versión son los tipos de la
biblioteca instalada. La consulta exacta del código v6.8.x queda pendiente.

Verificación ejecutada: `qmlplugindump -noinstantiate` con
`LD_PRELOAD=/usr/lib/libkwin.so.6`, y `qmllint -I <imports del dump> -I
/usr/lib/qt6/qml contents/ui/main.qml`: **exit 0**, con avisos por metadatos
incompletos del dumper (notificadores y QString). El comprobador de carga del
efecto, usando la biblioteca real, devuelve **Ready=1, cero errores** para este
script. Esto comprueba compilación QML, no instanciación en KWin ni D-Bus real.
