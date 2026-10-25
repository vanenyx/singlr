# T249 — tinte y borde óptico

Codex 2, `day3/codex2-liquidglass-fix`, **sin commit**. Compilado y comprobado
en aislamiento; revisión visual de KWin a cargo de Claude, aún pendiente.

## Causa y evidencia

- `Theme.surface` transmitía solo **7,02 %** del fondo en oscuro y **2,99 %**
  en claro a intensidad 65 (`1 - .65 × .108/.046`). El centro de control y el
  lanzador de sesión pintan directamente ese token: no interviene otro `Glass`
  opaco encima. Esto explica el fondo apenas perceptible.
- El brillo máximo anterior era `.145 × .65`, debajo del tinte: en oscuro
  sobrevivían como máximo `.00662` RGB, aproximadamente **1,7 niveles de 255**
  en el pico del borde. La refracción máxima era 2,6 px sobre un fondo ya
  desenfocado. Aunque se ejecutase, su señal visual quedaba casi anulada.
- **No se ha demostrado un fallo de filtro, región o ejecución.** Los logs
  previos `/tmp/claude-1000/perf-wp4/singlr/session.log` sí muestran
  `resourceClass=singlr-shell` para las superficies layer-shell. Se conserva el
  filtro existente. La nota histórica de `e2e.py` sobre identidad no prueba lo
  contrario. No confundir `pluginLoaded=true` con un pase dibujado.
- El [blur oficial de KWin 6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/plugins/blur/blur.cpp)
  pinta el fondo antes de continuar `effects->drawWindow`; el pase Singlr
  permanece antes del contenido de la ventana, después del blur. El estado real
  de región, exclusión, shader y dibujo se registra ahora en cada captura.

## Corrección

- Curva `alpha = 1 - .30 × strength^.35`: **74,2 % de tinte / 25,8 % de fondo**
  a 65; 70/30 a 100. Sólido, intensidad 0, accesibilidad y software siguen opacos.
  Barra, dock y panel comparten el límite de legibilidad.
- Tintas de texto secundario, tenue y acento ajustadas cuando hay transparencia.
  El test usa la curva real, los dos temas, intensidades 0/1/25/65/100 y fondos
  negro/blanco; mínimo calculado **4,748:1** en SDR, contraste por defecto.
  No sustituye muestrear las capturas reales ni valida HDR.
- Liquid: desplazamiento máximo **10,4 px a 65**, banda de borde de 24 px y brillo
  máximo `.80 × strength`, acotado a blanco de referencia antes del tinte.
  Sin nuevas texturas, animaciones ni repintado continuo. Valores visuales
  propuestos para revisión, no aprobación definitiva.
- `/Effects org.kde.kwin.Effects.debug singlr-liquidglass windows` devuelve JSON:
  shader, activación, posición en cadena, escritorio y ventanas con identidad,
  región local, posición global, elegibilidad, BackgroundEffectItem, `draws` y
  `lastResult`. Contadores reiniciados al actualizar configuración/región;
  sin serialización, mensajes ni asignaciones de texto por frame.
- `DiagnosticOverlay=true` colorea de magenta los 8 px interiores del borde
  **en el propio fragment shader**; es una prueba visual del pase, no del material.
  Solo lo escribe el helper en el perfil temporal; la siguiente invocación lo retira.

## Revisión de Claude fuera del sandbox

Desde este checkout, siguiendo el aislamiento de [materials.md](../testing/materials.md):

```sh
cmake -S . -B build -DSINGLR_BUILD_LIQUIDGLASS=ON -DVulkan_INCLUDE_DIR=/tmp/claude-1000/vulkan-headers/include -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build --parallel 2
cmake --build build --target singlr-material-image
stage=$(mktemp -d /tmp/singlr-t249-stage.XXXXXX)
DESTDIR="$stage" cmake --install build
test -s "$stage/usr/lib/qt6/plugins/kwin/effects/plugins/singlr-liquidglass.so"
out=$(mktemp -d /tmp/singlr-t249-review.XXXXXX)
QT_PLUGIN_PATH="$stage/usr/lib/qt6/plugins" QML_IMPORT_PATH="$PWD/build/qml" SINGLR_DEV_ROOT="$PWD" SINGLR_TEST_WALLPAPER="/RUTA/AL/PNG-DEL-CREADOR.png" tools/run-singlr.sh --size 2048x1280 --duration 900 > "$out/session.log" 2>&1 &
```

Copiar el descriptor exacto anunciado por ese log. El runner abre una sesión
nueva: no reutilizar un KWin que ya tenga la biblioteca anterior en memoria.

```sh
export SINGLR_SESSION_FILE=/tmp/singlr-session-REEMPLAZAR/session.json
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --intensity 65 --suite "$out/dark"
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode light --intensity 65 --suite "$out/light"
```

Cada suite abre de forma determinista centro de control y lanzador, captura
Sólido/Vidrio/Liquid sin cambiar su geometría y guarda seis PNG, seis recortes
`*-edge.png` a 4× y seis JSON. La geometría procede de la región recibida por
KWin; se convierte de coordenadas lógicas a píxeles de Spectacle usando el IHDR.
No usa PIL. El recorte automático requiere una salida; `--edge-rect X Y W H`
permite escoger píxeles explícitos. La suite se detiene si Liquid no dibuja el panel.

Si no se aprecia el borde, obtener una captura inequívoca del shader:

```sh
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --material liquid --surface control-center --diagnostic-overlay --capture "$out/diagnostic.png"
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --material liquid --surface control-center --capture "$out/liquid-clean.png"
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --intensity 0 --suite "$out/zero"
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --intensity 100 --suite "$out/maximum"
```

Consultar el JSON del panel: `eligible=true`, región correcta (340 px de ancho en
centro de control; región de contenido en lanzador, nunca fullscreen), `draws>0`
y overlay magenta donde corresponde. Si `lastResult` indica exclusión, recorte
vacío, blit o framebuffer fallido, conservar JSON y log. Un contador de dibujo
sin borde magenta visible tampoco prueba fragmentos correctos.

Comparar Vidrio con el fondo reconocible y desenfocado; Liquid debe desplazar
el fondo en el borde y mostrar brillo adicional. Usar también el fixture estático
`Backdrop.qml` del procedimiento si el fondo no tiene detalle en ese borde.
Cerrar el runner y comprobar `remaining=[]` / `equal=True`. Sin instalación en
la sesión cotidiana ni paquetes nuevos. La medición GPU/PSS de T248 sigue pendiente.

## Verificaciones ejecutadas

Qt 6.12.0, KWin SDK 6.8.1; cabeceras Vulkan existentes, sin instalación:

- Build completo, efecto con `--no-undefined`, factory: 5 passed; settings: 4 passed.
- `tools/test-qml.sh` y `--light`: cada uno 185 + 8 passed, 0 failed, 1 skipped.
  Primer intento encontró un build anterior de Singlr.System sin WorkspaceBridge;
  recompilar el módulo resolvió el fallo, sin cambiar Workspace.
- Python: transacción KWin 13 passed; helper 4 passed (perfil privado, región del
  lanzador, escala 1,25 y crop/zoom QImage real con rechazo fuera de límites).
- GLSL 140 validado con `glslangValidator`; no acredita ejecución del driver.
- `tools/check-cmake.sh`: build/staging correcto, biblioteca sin prefijo `lib`.
- `scripts/check_setup.py` y `git diff --check`: correctos.

No se lanzó KWin ni se modificó la sesión activa. **Faltan las capturas nuevas,
la confirmación visual de refracción/blur/AA y las mediciones reales.**
