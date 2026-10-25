# T252 — intensidad y óptica de materiales

**Entrega inicial histórica. La corrección de Claude la sustituye en [T252-material-correction.md](T252-material-correction.md).**

Codex 2 · `day3/codex2-material-polish` · sin commit. Propuesta visual implementada;
**KWin real y mediciones P-016 pendientes por sandbox**. No se tocó la sesión activa.
Sistema 05 (Appearance), superficies de Desktop/Command/System y herramientas de Platform;
esto no acredita el criterio de escritorio completo de Singlr 1.0.

## Cambios y elección de legibilidad

La curva saturante `1 − .30 × s^.35` queda sustituida por transmisión lineal en RGB de
pantalla: **0 / 21,25 / 42,5 / 63,75 / 85 %** para 0/25/50/75/100. Es lineal en señal
visible, no una calibración psicofísica universal. El shader aplica una compresión suave
por canal `c/(1+.35c)` en oscuro y su complementaria en claro, con saturación .86.
La variación negro–blanco resultante llega aproximadamente al **63 %** a intensidad 100,
frente al 30 % anterior; depende del fondo y de la composición real de KWin.

**AA no se sostiene oscureciendo todo el fondo.** Eso volvía a reducir la transmisión
real al mismo ~30 %. Se eligió la alternativa de capa de legibilidad junto al texto:
`UiText` e `Icon` usan el contorno nativo Qt de un píxel, con el color sólido de `raised`,
cuando `s > .30` y el plugin está disponible. Los dos campos de búsqueda editables usan
una base sólida local; la contraseña Wi-Fi ya está sobre una superficie sólida.
La cara del glifo queda intacta; no se añaden FBO QML, MultiEffect ni relojes para texto.
Los colores secundarios/acento de T249 siguen ofreciendo AA contra ese respaldo.
El contorno es una propuesta perceptible que requiere revisión del creador.

Sin plugin, el tinte usa una curva lineal conservadora de máximo 30 %; la ruta de preview
QML también conserva ese límite, porque no pasa por el shader de KWin. Software, sólido,
intensidad 0 y reducir transparencia siguen opacos. No hay falsa promesa de AA basada
solo en desenfoque, ni lectura de luminancia a CPU/GPU readback durante el producto.

## Óptica e integración

- El plugin procesa ahora **Vidrio y Liquid**. Lee las preferencias existentes
  `singlr/singlr.conf` y la paleta `kdeglobals`, con KConfigWatcher por nombres relativos.
  No añade claves a kwinrc ni altera el journal de restauración. `Enabled` en el grupo
  del efecto conserva su significado previo de habilitar la óptica Liquid.
- Desplazamiento según la normal SDF y el perfil convexo del borde, hasta 18 píxeles
  lógicos; banda ajustada al tamaño (también dock), centro sin refracción.
- Lóbulo especular ancho, cresta Fresnel y luz de rebote opuesta: siguen las normales
  por los cuatro lados y las esquinas. Dispersión RGB hasta ~1 píxel en el borde.
  El centro conserva detalle y Liquid difunde menos que Vidrio.
- Difusión adicional de 13 muestras precomputadas, con radio 0–14 px en Vidrio y
  0–5 px en Liquid, gobernado por intensidad. **El blur nativo previo sigue siendo
  una base fija**: su protocolo no ofrece radio por superficie. No se cambia el blur
  global de las aplicaciones. Se debe revisar en KWin si esa base diluye la lente.
- Margen de muestreo y dependencia de daño de 40 px. El pintado conserva el recorte
  original a la región de blur y daño. Liberación adicional de buffers al ocultarse
  ventanas; sin repintados continuos ni temporizadores. Sombra QML suave existente.
  Coste de frames dañados y corrección de daño parcial/multimonitor aún por medir.

Referencia óptica: [Apple, Meet Liquid Glass, WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/),
reinterpretada como lente estática (P-016), sin reproducir su dinámica continua.
APIs contrastadas con cabeceras locales Qt 6.12.0 / KWin 6.8.1 y el
[blur oficial 6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/plugins/blur/blur.cpp).
No cambian composición, tipografía, iconografía, geometría ni navegación aprobadas.

## Evidencia ejecutada

- `tools/test-qml.sh` y `--light`: resultados finales en
  [verification.txt](../../tests/shell/evidence/t252/verification.txt). Incluyen rasterizado
  del contorno real de UiText, curva completa, fallback, accesibilidad y AA de los tokens.
  Mínimo calculado SDR, contraste por defecto: **4,748:1** (incluye fallback).
  No es una certificación de todos los píxeles de texto ni de HDR.
- Build normal ON con `vulkan-headers` instalado; factory/config del efecto y
  `tools/check-cmake.sh` con staging. Sin descargar cabeceras ni instalar dependencias.
- Prueba EGL del **GLSL de producción**, compilado por Mesa llvmpipe, sobre fondos
  negro/blanco/R/G/B: 3.264.000 píxeles comprobados. Matriz de 60 imágenes y 60 recortes:
  ambos temas, ambos materiales, tres geometrías, cinco intensidades.
  El fixture no incluye el blur previo, widgets reales ni gestión de color de KWin.
  El texto/shadow del fixture son ilustrativos; UiText se verifica por separado.
  [Comparador](../../tests/shell/evidence/t252/index.html),
  [datos](../../tests/shell/evidence/t252/shader-fixture/optics.json).
- `tools/material-review.py --shader-fixture tests/shell/evidence/t252/shader-fixture`
  reproduce esa evidencia sin bus/display. No se interpreta llvmpipe como medida GPU.

## Procedimiento para Claude fuera del sandbox

El probe de runner falló con `dbus-daemon: Failed to bind socket ... Operation not permitted`;
terminó con `remaining=[]` y `files_before=30 files_after=30 equal=True`. Log guardado con
la evidencia. No se pueden producir aquí las capturas reales solicitadas ni frame times.

Construir/stage y arrancar un **KWin nuevo** con el procedimiento de
[materials.md](../testing/materials.md). Usar build ON normal, sin `Vulkan_INCLUDE_DIR`
temporal; mantener fixture/fondo estático y tamaño 2048×1280. Con el descriptor privado:

```sh
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --sweep "$out/t252-dark"
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode light --sweep "$out/t252-light"
```

`--sweep` conserva cada geometría abierta mientras cambia material/intensidad y produce
30 capturas, 30 recortes a 4× y JSON por tema. Incluye dock. Rechaza Liquid sin plugin y
material translúcido con plugin cargado sin pases sobre la superficie. A 0 descubre la
región antes de desactivar blur. Revisar texto pequeño/contorno, placeholders, campos
escritos, bordes en los cuatro lados, cambios de paleta, fondos blanco/negro y el fixture.
La matriz EGL tiene que coincidir en dirección con la UI; no sustituye esta comprobación.

Para frames/GPU/reposo seguir §3–4 de materials.md. Variantes actualizadas: Vidrio sin
plugin, Sólido con plugin cargado/inactivo, Vidrio 25/100 activo y Liquid 25/65/100 activo.
Tres repeticiones alternadas, misma animación, GPU y compositor privado; mediana/p95/p99,
GPU/potencia y reposo sin animación. Verificar que `draws` no aumenta en reposo y buffers
no persisten en paneles cerrados. No integrar como material aceptado ni declarar P-016
medido hasta completar esta revisión; no se ha hecho reload de la sesión del creador.
