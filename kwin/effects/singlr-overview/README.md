> **T246:** el comportamiento y la verificación vigentes están en
> [Workspace](../../../session/WORKSPACE.md). Se comparten los tokens de Singlr.Ui,
> claro/oscuro y movimiento reducido; escribir abre Command; Ctrl+1…9 cambia
> escritorio y eliminar requiere confirmar. Lo que sigue conserva la evidencia
> histórica de T223 (los pasos de copiar el paquete sin adaptar imports ya no aplican).

# Singlr Overview — T223

Efecto declarativo para KWin **6.8.1**, Qt **6.12.0**. Prototipo de la
multitarea solicitada; pendiente de aprobación visual en contexto. No modifica
Overview de Plasma, la shell ni la configuración de la sesión habitual.

## Comportamiento

- Fondo del escritorio real con `#08090a` al 85 %, sin blur. Única animación:
  opacidad de entrada/salida de 120 ms, lineal.
- Escritorios de 160 × 100, nombres de 12 px, borde actual de 1,5 px,
  creación mediante +, cambio sin salir, menú derecho para eliminar y Supr.
  Supr elimina el escritorio del menú abierto o, sin menú, el actual. Nunca
  elimina el último. KWin decide dónde reubicar las ventanas del eliminado.
- Cuadrícula de ventanas normales y diálogos del escritorio, actividad y monitor
  de cada vista. Incluye minimizadas. Proporciones conservadas, separación de
  24 px, iconos originales de 16 px, títulos de 12 px y elipsis. El borde hover
  usa `#26ffffff` (equivalente QML de CSS `#ffffff26`). Borde claro para selección.
- Clic/Enter activa y sale; botón central o × en hover solicita cerrar
  (respeta `closeable`; la aplicación puede mostrar confirmación). Flechas
  navegan por filas/columnas; Esc cierra primero el menú y después la vista;
  1–9 cambia al escritorio correspondiente sin salir.
- Arrastre interno de una ventana sobre un escritorio para moverla. Se muestra
  una etiqueta junto al cursor; no se crean ventanas nativas de drag ni capturas.
  El cambio de pertenencia se difiere al siguiente turno para que la eliminación
  del delegado de origen no interrumpa la liberación del ratón.

Soluciones técnicas derivadas: una vista por monitor de `SceneEffect`, filtros
por salida/actividad, fila horizontal desplazable si no caben los escritorios y
cuadrícula ajustada al espacio. El arrastre entre monitores y el caso de muchas
ventanas en pantallas pequeñas requieren validación; no se promete una cota de
rendimiento. No se añadieron variantes porque la composición viene dada por T223.

## APIs contrastadas

Referencia instalada: `/usr/share/kwin/effects/cube/{metadata.json,contents/ui/}`.
Se usa `KWin.SceneEffect`, `SceneView.screen`, `ShortcutHandler`, `WindowModel`,
`WindowFilterModel` y `WindowThumbnail.client` (ventana real, equivalente al
`wId` del cubo). El thumbnail conserva el contenido de KWin sin capturas.
`Workspace.currentDesktopForScreen()` y `setCurrentDesktopForScreen()` evitan
suponer que todos los monitores tienen el mismo escritorio. `createDesktop()`
recibe posición desde cero; `removeDesktop()` recibe el objeto. Se mueve una
ventana asignando `Window.desktops`, y se activa con `Workspace.activeWindow`.

Fuentes oficiales de contraste:
[Workspace](https://github.com/KDE/kwin/blob/Plasma/6.8/src/scripting/workspace_wrapper.h),
[modelos](https://github.com/KDE/kwin/blob/Plasma/6.8/src/scripting/windowmodel.h),
[SceneView](https://github.com/KDE/kwin/blob/Plasma/6.8/src/effect/quickeffect.h).
También se verificaron las propiedades en `/usr/include/kwin/window.h` y los
metadatos registrados por **la biblioteca instalada** `/usr/lib/libkwin.so.6`.

### Verificación ejecutada

```bash
bash kwin/effects/singlr-overview/tools/check-qml.sh
```

En esta máquina `/usr/lib/qt6/qml/org/kde/kwin/` **no contiene** `qmldir` ni
`kwin.qmltypes` públicos: el módulo está integrado en KWin. El script genera
metadatos temporales desde la biblioteca real con `qmlplugindump -noinstantiate`
y ejecuta `qmllint -I <imports-temporales> -I /usr/lib/qt6/qml`.
El dumper está obsoleto y pierde información de `QFlags`, listas, tipos de valor,
attached properties y alias como QString; por ello qmllint termina con código **0** pero conserva avisos; no es un lint
limpio. Sin esos metadatos, el lint directo tampoco
resuelve `org.kde.kwin`. No se ocultaron avisos ni se añadieron stubs.

Para comprobar la carga pese a esa limitación, `tools/check-load.cpp` carga la
biblioteca real con `QLibrary` y el QML con `QQmlComponent` en plataforma offscreen:
resultado **Ready (1), cero errores**. Es carga/compilación del componente,
**no instanciación del efecto**, render ni prueba de interacción. No se puede
instanciar Workspace fuera de KWin; por eso el dump usa `-noinstantiate`.
No se instaló nada ni se ejecutó el efecto en la sesión habitual o anidada.

## Instalación y prueba por Claude (no ejecutadas)

Destino solicitado para instalación posterior:

```bash
mkdir -p ~/.local/share/kwin/effects/singlr-overview
cp -a kwin/effects/singlr-overview/metadata.json kwin/effects/singlr-overview/contents \
  ~/.local/share/kwin/effects/singlr-overview/
```

Para probar primero **aislado**, usar otro data/config home y un bus propio.
Ejecutar desde la raíz del repositorio, en una terminal del escritorio anfitrión:

```bash
trial=$(mktemp -d /tmp/singlr-overview-trial.XXXXXX)
mkdir -p "$trial/data/kwin/effects/singlr-overview" "$trial/config"
cp -a kwin/effects/singlr-overview/metadata.json kwin/effects/singlr-overview/contents \
  "$trial/data/kwin/effects/singlr-overview/"
cat > "$trial/config/kwinrc" <<'CONFIG'
[Plugins]
singlr-overviewEnabled=true

[Desktops]
Number=2
Rows=1
CONFIG
XDG_DATA_HOME="$trial/data" XDG_CONFIG_HOME="$trial/config" \
  dbus-run-session -- kwin_wayland --width 1440 --height 900 \
  --socket singlr-overview-test --no-lockscreen --no-kactivities \
  --exit-with-session /usr/bin/konsole
```

La terminal iniciada por KWin pertenece al compositor y al bus anidados. Abrir
allí varias aplicaciones Wayland para la prueba. No usar `--replace`, ni llamar
al bus anfitrión. Al cerrar la terminal de sesión termina ese KWin; conservar
`$trial` para revisar registros o borrarlo después. No se requieren paquetes
nuevos: el ejemplo presupone `konsole` disponible, sustituible por otro cliente.

Desde esa terminal anidada, si hace falta cargarlo explícitamente:

```bash
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect singlr-overview
```

`[Plugins] singlr-overviewEnabled=true` es la habilitación persistente; cargar el
efecto no lo muestra automáticamente. Meta+Tab registra una acción propia con
`name` y `text` **Singlr Overview**. Si existe un conflicto de atajos, resolverlo
en la configuración aislada; el efecto no reconfigura ni desactiva otros efectos.

### Invocación desde el dock por D-Bus

El dock debe usar **el mismo bus de sesión que el KWin objetivo**. La vía de
activación es la acción del componente KWin en KGlobalAccel:

```bash
qdbus6 org.kde.kglobalaccel /component/kwin \
  org.kde.kglobalaccel.Component.shortcutNames
qdbus6 org.kde.kglobalaccel /component/kwin \
  org.kde.kglobalaccel.Component.invokeShortcut 'Singlr Overview'
```

El primer comando permite confirmar que la acción quedó registrada antes de
conectar el botón. `invokeShortcut` alterna entrada/salida como Meta+Tab.
Si `qdbus6` no está en PATH, usar `/usr/lib/qt6/bin/qdbus`. Requiere KGlobalAccel
disponible en ese bus y el efecto cargado; esta llamada queda pendiente de
comprobación en sesión anidada. `activated` es una propiedad QML interna,
no una propiedad exportada automáticamente por D-Bus.

### Recorrido de aceptación pendiente

En la sesión anidada: abrir ventanas apaisadas, verticales y minimizadas;
Meta+Tab y D-Bus; cambiar con clic/1–9 sin salir; crear y eliminar escritorios
(incluido el último); mover por drag y comprobar la pertenencia; navegar con
flechas/Enter/Esc; cerrar con ×/central; comprobar confirmaciones de aplicación,
escalado fraccional, varios monitores, overflow y los dos fundidos.

Reversión de una instalación posterior: descargar solo este efecto con
`qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect singlr-overview`
en el bus correcto, deshabilitar su entrada en el kwinrc correspondiente y retirar
solo su carpeta instalada. La prueba aislada no necesita alterar kwinrc habitual.

## Gestos — T226 / P-015

Tres dedos arriba en panel táctil revela la vista proporcionalmente al progreso;
tres abajo con la vista abierta la cierra. Durante el gesto no hay animación
interpolada; al terminar completa el fundido de 120 ms. `activated` completa la
dirección; `cancelled` resuelve al estado abierto si la opacidad alcanzó 0,5, o al
cerrado en caso contrario. El umbral de 0,5 es una solución técnica derivada.
No se añadió `pragma ComponentBehavior: Bound`.

`SwipeGestureHandler.Direction.Up/Down`, `Device.Touchpad`, `fingerCount`,
`progress`, `progressChanged`, `activated` y `cancelled` se contrastaron con la
biblioteca instalada KWin 6.8.1 y la [documentación oficial](https://api.kde.org/qml-org-kde-kwin-swipegesturehandler.html).
La consulta del código fuente etiquetado v6.8.x no fue accesible; ver el
[detalle de compatibilidad](../../scripts/singlr-gestures/README.md).
Se repitió `tools/check-qml.sh`: qmllint exit 0 con los avisos de metadatos
indicados arriba y carga **Ready=1**, cero errores. Quedan pendientes los gestos
físicos, la cancelación/reversión y la convivencia con otros efectos en KWin real.
