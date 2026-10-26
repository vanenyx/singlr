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

## Corrección de entrega tras fondo negro (26 oct, 10:49)

El creador seleccionó el fondo en Ajustes mientras el shell abierto mantenía
el QML y módulo nativo anteriores. El build aislado no actualizaba su canal de
desarrollo: la opción visible aún no era utilizable en esa sesión.

Se publicaron los dos binarios del módulo y sus metadatos en `build/` mediante
reemplazo atómico, con RUNPATH relativo a `$ORIGIN`. Los inodos anteriores se
conservaron en `.local/singularity/dev-module-before-update`, sin truncar las
bibliotecas mapeadas ni reiniciar el shell (PID 33974 conservado). Se comprobó
la carga y renderizado OpenGL del tipo Singularidad desde **build/qml**.
El próximo inicio de la sesión del creador cargará ese módulo; el login en sí
queda pendiente de su comprobación. Los Ajustes abiertos también conservan su
módulo anterior y deben cerrarse y abrirse de nuevo.

Además, `tools/build-package.sh` completó el paquete
`.local/repo/singlr-desktop-0.1.0.r197.g2dad2f8-2-x86_64.pkg.tar.zst`, con fondo,
QML y biblioteca incluidos. No se instaló con pacman. Para el canal de desarrollo
actual no hace falta instalarlo para probar el fondo tras volver a iniciar sesión;
la sesión empaquetada sí requiere actualizarlo.

## Corrección de movimiento en la sesión real (26 oct, 11:00)

El fondo ya aparecía, pero seguía fijo porque el creador tiene
`[KDE] AnimationDurationFactor=0`. El interruptor guardado decía activado aunque
la política global impedía crear el efecto. No era una falla del temporizador.

El creador autorizó explícitamente animar **solo Singularidad**. Se añadió una
excepción persistente `wallpaperMotionOverride` (false por defecto); se muestra
el estado de reducir movimiento y un control propio de excepción en Ajustes.
Sin excepción, Movimiento aparece deshabilitado/apagado; el cursor también se
habilita únicamente si el movimiento efectivo está permitido.

Comprobaciones: 11 resultados de Ajustes con factor 1 y 11 con factor 0, sin
fallos; 9 resultados nativos/GPU, sin fallos. La prueba con factor 0 verifica la
imagen fija inicial, activa la excepción, comprueba avance temporal, vuelve a
retirarla y comprueba destrucción; la preferencia global continúa en 0. Lint y
`git diff --check` correctos.

Se guardó la excepción en la configuración del creador y se reinició únicamente
`plasma-plasmashell.service`, sin propagación de parada a otras unidades. El nuevo
shell PID 67256 registró a las 11:00:06 «Singlr Singularidad: animación activa».
El SHA-256 de kdeglobals antes/después es idéntico. No se cerró la sesión.
Los Ajustes que ya estaban abiertos conservan la UI anterior; cerrarlos y abrirlos
carga el nuevo control. Persisten los límites de GPU/energía y aceptación visual.
