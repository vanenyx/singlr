# T253 — retirada de Liquid y cobertura de esquinas

Codex 2 · 25 oct 2026 · `day3/codex2-glass-aa` · sin commit.
Encargo explícito: P-020/P-021; sistemas 05 Appearance y 07 Platform.

## Entrega

- Ajustes/Appearance solo permiten `solid|glass`. Al cargar, `material=liquid` se
  persiste como `glass`; se preservan otras claves. Regresión de migración y rechazo
  de nuevas selecciones `liquid`, QML y recuperación del journal verificadas.
- Shader de Vidrio sin refracción, dispersión, especular ni uniform `liquid`.
  Difusión y adaptación de luminancia siguen disponibles. Helper de revisión y
  fixture EGL solo comparan los materiales vigentes.
- Nombre visible **Singlr Glass**. Se conserva **ID/archivo/directorio técnico
  `singlr-liquidglass`**, opción CMake y claves existentes. Renombrarlos exigiría
  trasladar journals originales, soportar dos binarios y revertir dos familias de
  claves. Mantenerlos evita huérfanos y conserva la restauración exacta; no se modifica
  el journal del creador. `Enabled` sigue siendo el espejo de la preferencia de material;
  el lector del pase deriva su actividad de Appearance/accesibilidad.
- Cobertura SDF `clamp(.5-d*viewport.scale(),0,1)`; salida premultiplicada y mezcla
  `GL_ONE, GL_ONE_MINUS_SRC_ALPHA`. Restaura enable, factores separados RGB/alfa y
  ecuaciones de mezcla. No se recorta con wl_region: se dibuja el bounding box con
  margen para AA. Fuera de la cobertura se descarta sin tocar el destino.
- Radio exacto `double` consultado asíncronamente al shell por ID de `wl_surface`.
  Sin respuesta válida queda el blur nativo. Se descartan respuestas caducadas y se
  notifican cambios de radio aunque la región entera no cambie. Qt privado aislado en
  `glassgeometry.h`; nuevo enlace GuiPrivate/wayland-client. Contrato en el README del
  efecto. No se usa D-Bus en el bucle de render.
- Respaldo: región analítica que incluye solo celdas enteras interiores al contorno.
  Su máscara sigue siendo binaria; el protocolo no transmite cobertura. Glass.qml
  explicita AA en máscara/relleno/contorno. Los Rectangles que usan Theme.surfaceBorder
  conservan el AA por defecto de Qt al tener radio. No se cambian los tokens visuales.
- `SINGLR_OUTPUT_SCALE` del runner permite probar escalas 1 y 2 sin tocar la sesión real.

## Evidencia ejecutada

Qt 6.12.0, KWin 6.8.1 (ABI exacta de CMake), wayland-client 1.26.0,
Mesa 26.2.5 / llvmpipe LLVM 23.1.3. Sin instalación ni recarga de la sesión cotidiana.

- `singlr-appearance-test`: 11 pasan, incluida migración.
- `singlr-liquidglass-test`: 7 pasan; factory carga y región interior con radios
  0/8/10/12/12.5/14. `singlr-material-settings-test`: 6 pasan.
- `singlr-material-optics-test`: shader de producción compilado/renderizado por EGL;
  cobertura contra SDF, alfa fraccionaria y premultiplicación a escalas 1/2, radio
  12.5, claro/oscuro; 1 468 800 píxeles de contraste, máximo Y oscuro 0.103079,
  mínimo Y claro 0.486742. Fixture sintética, **no captura de KWin**.
- `tools/test-qml.sh` y `--light`: cada tema 206 shell + 8 Ajustes pasan; 3 capturas
  opcionales omitidas por tema, ningún fallo.
- unittest `test_kwin.py`: 14 pasan (incluido journal previo con claves antiguas);
  `test_material_review.py`: 5 pasan.
- `tools/check-cmake.sh`: build y DESTDIR correctos, plugin y payload verificados.
- `scripts/check_setup.py` y `git diff --check`: correctos.

KWin anidado intentado con `python3 tools/session-runtime.py --duration 8`:
`dbus-daemon: Failed to bind socket ... Operation not permitted`, salida 127.
`SINGLR_CLEANUP remaining=[]`; `SINGLR_HOST_CONFIG files_before=30 files_after=30 equal=True`.
No se pudieron producir capturas reales ni comprobar en ejecución el puente D-Bus,
la restauración GL dentro de KWin o la apariencia final del fallback.

## Procedimiento para Claude fuera del sandbox

Desde este worktree; **no recargar el shell instalado**. El build/staging no modifica KDE.

```bash
cmake -S . -B build -DSINGLR_BUILD_LIQUIDGLASS=ON -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build --parallel 2
cmake --build build --target singlr-material-image
stage=$(mktemp -d /tmp/singlr-t253-stage.XXXXXX)
DESTDIR="$stage" cmake --install build
out=$(mktemp -d /tmp/singlr-t253-review.XXXXXX)
scale=1 # repetir en una sesión nueva con scale=2
QT_PLUGIN_PATH="$stage/usr/lib/qt6/plugins" QML_IMPORT_PATH="$PWD/build/qml" \
SINGLR_DEV_ROOT="$PWD" SINGLR_OUTPUT_SCALE="$scale" \
tools/run-singlr.sh --size 2048x1280 --duration 900 > "$out/session-$scale.log" 2>&1 &
```

Copiar **el descriptor exacto** `SINGLR_SESSION_FILE=...` anunciado en ese log:

```bash
export SINGLR_SESSION_FILE=/tmp/singlr-session-REEMPLAZAR/session.json
for mode in dark light; do
    python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode "$mode" \
        --intensity 65 --edge-zoom 8 --suite "$out/scale-$scale/$mode"
done
```

La suite abre centro de control, lanzador y dock, captura Sólido/Vidrio y guarda PNG,
recorte `*-edge.png` a 8× y JSON. Comprobar `effect.windows[].radius` igual a la propiedad
QML (12/14), `draws > 0`, `lastResult=drawn`; ninguna espera de geometría persistente.
Registrar `supportInformation` del KWin privado y su escala real: si el tamaño de la salida
anidada queda demasiado pequeño a escala 2, repetir con `--size 4096x2560` para mantener
el área lógica comparable. No confundir escala de ventana anfitriona con viewport del hijo.

Para el respaldo repetir los mismos recortes, sin diagnóstico magenta:

```bash
for mode in dark light; do
    for surface in control-center launcher dock; do
        baseline="$out/scale-$scale/$mode/$surface-glass-$mode.json"
        read -r -a rect <<< "$(python3 -c 'import json,sys; print(*json.load(open(sys.argv[1]))["edgeRect"])' "$baseline")"
        python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode "$mode" \
            --material glass --intensity 65 --surface "$surface" --without-effect \
            --edge-rect "${rect[@]}" --edge-zoom 8 \
            --capture "$out/scale-$scale/$mode/$surface-native.png"
    done
done
```

Revisar esquinas contra fondo contrastado (fixture Backdrop.qml o wallpaper de prueba),
a intensidades 65/100: transición parcial continua, sin dientes ni halo exterior, contorno
QML tenue de 1 px. Comparar las esquinas superiores y las inferiores con `--edge-rect`
en píxeles de captura. Mover/abrir/cerrar y recrear paneles; comprobar que no hay un frame
persistente de geometría vieja. El fallback puede conservar escalonado del blur; si resulta
visible, registrar el recorte antes de proponer una curva de tinte distinta.

Esperar el cierre del runner o detener ese PID; exigir limpieza vacía y hashes iguales.
Repetir todo en una sesión nueva con escala 2. Conservar evidencia en
`tests/shell/evidence/t253/nested/`. Pendientes: estas capturas, aceptación visual del creador
y medición GPU/frame time; no se afirma validación del escritorio completo.

Fuentes: cabeceras locales KWin `wayland/surface.h`, `backgroundeffect_v1.h` y Qt
`qpa/qplatformwindow_p.h`; [protocolo KDE blur](https://invent.kde.org/libraries/plasma-wayland-protocols/-/blob/master/src/protocols/blur.xml),
[Rectangle/AA de Qt](https://doc.qt.io/qt-6/qml-qtquick-rectangle.html).
