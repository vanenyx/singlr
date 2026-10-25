# Singlr Glass — pase de Vidrio (T253, P-020/P-021)

Difusión y adaptación suave de luminancia sobre el blur nativo de KWin 6.8.1.
Materiales: Sólido y Vidrio. No hay refracción, dispersión ni especular.

Se mantiene **el ID de compatibilidad `singlr-liquidglass`**, el directorio, la opción
`SINGLR_BUILD_LIQUIDGLASS` y el grupo `Effect-singlrliquidglass`. No describen un material
seleccionable: permiten actualizar el plugin sin dejar dos binarios, claves ni journals
huérfanos. Los snapshots antiguos de `singlr_kwin.py` conservan su formato y restauran
exactamente los valores originales. No se migra ni elimina el backup del creador.
`Enabled` es ahora el pase de Vidrio; `Intensity` 0–100. Ajustes migra el valor de material
`liquid` a `glass` una vez; el lector del efecto acepta ese valor antiguo como Vidrio
mientras no se haya abierto Ajustes/shell. Valores nuevos: solo `solid|glass`.

El efecto admite exclusivamente superficies layer-shell `singlr-shell` con región de blur.
Usa BackgroundEffectItem, daños parciales y buffers por vista; no añade temporizadores.
Sin efecto o sin geometría válida se conserva el blur nativo.

## Geometría y AA

El protocolo KDE blur y ext-background-effect-v1 solo llevan `wl_region`; no llevan
radio. El shell rasteriza la región con `roundedBlurRegion()` (`shell/session/src/blurregion.h`,
compartida con el efecto) y el efecto recupera el radio exacto de las filas de la esquina con
`radiusFromInsets()` (pasos de 0,25 px). Sin canal lateral, sin D-Bus y sin API privada de Qt.

SDF en coordenadas lógicas, cobertura `clamp(.5 - d * viewport.scale(), 0, 1)` en píxeles
de dispositivo, salida premultiplicada y `GL_ONE, GL_ONE_MINUS_SRC_ALPHA`. Se guardan y
restauran activación, factores RGB/alfa y ecuaciones de mezcla. Rasterizar el bounding box
(con margen de AA) evita recortar la cobertura con la región entera; cobertura cero
descarta el fragmento. La banda exterior de medio píxel representa cobertura parcial
del contorno, no una extensión óptica.

El respaldo nativo sigue teniendo máscara binaria (limitación de wl_region), con
celdas enteras interiores al radio analítico, también fraccional. No asoma fuera del
tinte QML; `Glass.qml` conserva AA explícito en máscara, relleno y contorno tenue de
1 px. `Theme.surfaceBorder` es color; el AA lo hace el Rectangle que lo dibuja.
No se afirma que la máscara nativa tenga AA ni equivalencia visual con el pase.

## Verificación

```sh
cmake -S . -B build -DSINGLR_BUILD_LIQUIDGLASS=ON -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build --target singlr-liquidglass-test singlr-material-settings-test singlr-appearance-test singlr-material-optics-test
build/kwin/effects/singlr-liquidglass/singlr-liquidglass-test
build/session/appearance/singlr-material-settings-test
QT_QPA_PLATFORM=offscreen DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/no-singlr-test-bus build/session/appearance/singlr-appearance-test
QT_QPA_PLATFORM=offscreen LIBGL_ALWAYS_SOFTWARE=1 build/kwin/effects/singlr-liquidglass/singlr-material-optics-test
bash tools/test-qml.sh
bash tools/test-qml.sh --light
bash tools/check-cmake.sh
```

La fixture EGL compila el shader de producción, comprueba cobertura contra el SDF,
alfa fraccionaria y premultiplicación a escala 1/2 y radios subpíxel, ambos temas,
contraste e intensidad. **No sustituye capturas reales de KWin.**
Ver procedimiento visual y resultados en [T253](../../../docs/handoffs/T253-glass-aa.md).
