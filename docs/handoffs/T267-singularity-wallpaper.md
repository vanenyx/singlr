# T267 — Fondo opcional Singularidad

Encargo directo del creador, 26 oct 2026: implementar el fondo de partículas
propuesto en esta conversación. Codex 2, un solo escritor. P-031. Afecta a
Desktop, Appearance y Platform; la composición es una propuesta revisable.

## Entrega

- Ajustes → Fondo → Singularidad. Fondo actual conservado: la selección inicial
  sigue siendo `singlr:linear`. Seleccionar Singularidad habilita su animación;
  el interruptor Movimiento permite conservar solo una imagen fija.
- 18 000 / 36 000 / 64 000 partículas (Ligero/Equilibrado/Alto). Un lote de
  triángulos, geometría inmutable, órbitas y estelas calculadas por shaders QSB.
  Perspectiva, núcleo negro con oclusión, arcos de lente artística y luz suave
  local. No navegador, vídeo de fondo, objetos QML por partícula ni física CPU.
- Cursor: paralaje leve con amortiguación; HoverHandler pasivo, únicamente sobre
  el fondo. No seguimiento global ni captura de clics/foco de otras apps.
- Loader destruye el efecto al cambiar de fondo, ocultar su contenedor o elegir
  modo estático. Miniaturas, splash y consumidores sin opt-in usan la imagen
  fija. «Reducir movimiento» también impide crear el renderizador.
- El reloj de 34 ms se detiene ante bloqueo (ScreenSaver), PrepareForSleep,
  DPMS de su pantalla y ventana no expuesta. Nunca inhibe suspensión ni cambia
  el estado de pantallas. Cada salida tiene su instancia y presupuesto propio.
- Preferencias persistentes `wallpaperAnimated`, `wallpaperReactive`,
  `wallpaperQuality`, con valores validados. Error de carga del módulo nativo
  muestra el fotograma estático y aviso en la vista previa.
- `assets/singularity.webp` es un fotograma de nuestro propio shader, 2560×1280;
  se instala junto al QML. Las cuatro referencias del creador no se redistribuyen.

## Compilación y revisión aisladas

No se sobrescribió `build/` (puede estar cargado por el shell del creador), no se
instaló ningún paquete, no se modificaron preferencias reales ni se reinició la
sesión. Compilación de desarrollo en `.local/build-singularity`:

```bash
cmake -S . -B .local/build-singularity -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr \
  -DKDE_INSTALL_LIBDIR=lib -DSINGLR_BUILD_LIQUIDGLASS=OFF
cmake --build .local/build-singularity
cmake --build .local/build-singularity --target singlr-singularity-test
SINGLR_TEST_BUILD_DIR="$PWD/.local/build-singularity" tools/test-singularity.sh
SINGLR_TEST_BUILD_DIR="$PWD/.local/build-singularity" tools/test-qml.sh
SINGLR_TEST_BUILD_DIR="$PWD/.local/build-singularity" tools/test-qml.sh --light
tools/preview-singularity.sh
```

La última orden abre una ventana nativa aislada con movimiento y cursor;
Espacio pausa, Esc cierra. No aplica el fondo al escritorio ni guarda ajustes.
La integración en la sesión instalada requiere reconstruir/actualizar el paquete
y cargar el nuevo módulo nativo en la siguiente sesión, dentro del flujo habitual.
El módulo antiguo puede seguir mostrando el fotograma estático.

## Evidencia

- Qt 6.12.0, KF6 6.31.0, KScreen/Plasma 6.8.1.
- Compilación completa con vidrio OFF y staging DESTDIR correctos, incluido WebP
  y módulo/shaders. No verifica el plugin KWin de vidrio, que no se modificó.
- QML software, XDG y buses aislados: 246 resultados shell + 10 Ajustes por modo
  claro/oscuro, 0 fallos, 5 capturas opcionales omitidas en cada suite shell.
- OpenGL real offscreen: 3 resultados nativos + 3 QML con animación + 3 QML con
  reducir movimiento, 0 fallos. Verifica imagen no vacía, cambio temporal,
  ausencia de ticks al pausar, señales de bloqueo/sueño simuladas, visibilidad,
  destrucción, cursor, preferencias y fallback software en la suite general.
- qmllint de Wallpaper, SingularityWallpaper, Ajustes y preview: sin avisos con
  rutas al módulo nuevo antes de los imports instalados; sintaxis bash correcta.
- `scripts/check_setup.py` correcto. Este check no prueba una sesión de escritorio.
- 5 pruebas de empaquetado correctas; sintaxis de los scripts y PKGBUILD correcta.
- Capturas de Ajustes [oscuro](../../tests/shell/evidence/t267/settings-dark.png) y
  [claro](../../tests/shell/evidence/t267/settings-light.png) inspeccionadas. Imagen final:
  [fotograma](../../shell/qml/Singlr/Ui/assets/singularity.webp).
- [Resumen de resultados](../../tests/shell/evidence/t267/verification.txt).

### Muestra de recursos

[Datos](../../tests/shell/evidence/t267/resources.json). Proceso qmlscene aislado,
ventana offscreen 1920×1080, OpenGL en AMD Radeon 610M, Mesa 26.2.5, kernel
7.2.11-arch1-1. Cuatro fases de 4 s, muestra de 2 s por fase mediante `/proc`;
CPU expresada como porcentaje de un núcleo. Modo Equilibrado:

| Fase | CPU | PSS |
| --- | --- | --- |
| Antes de cargar | 0 % | 28 192 KiB |
| Animación | 1,0 % | 51 191 KiB |
| Pausado con geometría residente | 0 % | 51 195 KiB |
| Tras destruir el efecto | 0 % | 46 178 KiB |

Se liberan los objetos y su lote; el controlador/Qt conservan cachés. No se
promete recuperar toda la memoria del proceso al instante. La muestra es breve,
no compara el escritorio entero y **no mide utilización GPU, energía ni batería**;
no acredita P-016 del shell. El coste crece con las salidas y la calidad.

## Límites pendientes

- Valoración visual del creador; fondo artístico, sin ray tracing relativista.
- DPMS y señales reales de bloqueo/reanudación en una sesión de prueba; aquí se
  verificaron transiciones simuladas del reloj, sin suspender el equipo.
- Multimonitor real, escalado fraccional, otra GPU y consumo GPU/energía.
- Cubrir el escritorio con ventanas no expuestas como tales por Wayland todavía
  no pausa explícitamente el reloj: no se implementa detección global de oclusión.
- Una prueba inicial con Vulkan/offscreen falló en la plataforma; la evidencia
  gráfica de esta entrega corresponde a OpenGL, no a Vulkan.

Contratos consultados: [material Qt Quick](https://doc.qt.io/qt-6/qtquick-scenegraph-custommaterial-example.html),
[QSGMaterialShader](https://doc.qt.io/qt-6/qsgmaterialshader.html),
[Loader](https://doc.qt.io/qt-6/qml-qtquick-loader.html), y cabecera local
`KScreen/kscreendpms/dpms.h` para observación de cambios de DPMS.
