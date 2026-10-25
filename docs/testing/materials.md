# T252 — matriz ampliada

Ver [corrección y límites actuales](../handoffs/T252-material-correction.md).
`--matrix DIR --wallpaper PNG` ejecuta ambos temas, fondo cálido/blanco/negro y las tres
superficies solicitadas (lanzador, centro de control, portapapeles), con cinco intensidades.
`material-review.py --sweep DIR` compara 0/25/50/75/100 en centro de control, lanzador y
dock; repetir con `--mode dark` y `--mode light`. `--shader-fixture DIR` es una prueba
EGL independiente, marcada como tal, que no necesita descriptor ni bus. Vidrio ahora
usa el pase Singlr: para carga inactiva medir **Sólido**, para fallback Vidrio descargado.
Build normal con `vulkan-headers` instalado, sin rutas temporales de cabeceras.

# T248 / T249 — revisión y medición en la laptop AMD + NVIDIA

**Corrección T249:** usar el [procedimiento actualizado](../handoffs/T249-liquidglass-fix.md#revisión-de-claude-fuera-del-sandbox)
para abrir ambos paneles, comparar los tres materiales y guardar recortes QImage a 4×
y diagnósticos de ejecución. Incluye la ruta Vulkan existente sin instalar paquetes.

**Procedimiento preparado, no ejecutado en hardware.** El plugin compila y su factory
carga. La sesión anidada está bloqueada aquí por el bind de sockets del bus privado. No integrar hasta tener esa evidencia y las
mediciones P-016. `Backdrop.qml` solo anima con `--animate`; nunca se instala en el producto.

## 1. Construir y arrancar sin instalar en el equipo

Se requieren las dependencias del PKGBUILD, Spectacle y, para medir intervalos de frames,
MangoHud con soporte OpenGL/EGL. No se instalan automáticamente. Si falta una, registrar el
bloqueo; no sustituir un resultado con un número supuesto.

En este checkout se verificó con cabeceras oficiales temporales en
`/tmp/t248-vulkan/include` (SDK 1.4.335.0) usando `-DVulkan_INCLUDE_DIR=...`; el paquete
normal `vulkan-headers` evita necesitar esa ruta temporal. Desde la raíz del checkout:

```sh
cmake -S . -B build -DSINGLR_BUILD_LIQUIDGLASS=ON -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build --parallel 2
cmake --build build --target singlr-liquidglass-test singlr-material-settings-test singlr-appearance-test
build/kwin/effects/singlr-liquidglass/singlr-liquidglass-test
build/session/appearance/singlr-material-settings-test
tools/test-qml.sh
tools/test-qml.sh --light
tools/check-cmake.sh
stage=$(mktemp -d /tmp/singlr-material-stage.XXXXXX)
DESTDIR="$stage" cmake --install build
test -s "$stage/usr/lib/qt6/plugins/kwin/effects/plugins/singlr-liquidglass.so"
out=$(mktemp -d /tmp/singlr-material-results.XXXXXX)
QT_PLUGIN_PATH="$stage/usr/lib/qt6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}" QML_IMPORT_PATH="$PWD/build/qml" SINGLR_DEV_ROOT="$PWD" tools/run-singlr.sh --size 2048x1280 --duration 900 > "$out/session.log" 2>&1 &
runner=$!
```

El runner anuncia `SINGLR_SESSION_FILE=/tmp/singlr-session-…/session.json` en el log.
En otra terminal del mismo checkout, copiar **esa ruta exacta**:

```sh
export SINGLR_SESSION_FILE=/tmp/singlr-session-REEMPLAZAR/session.json
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --material liquid
```

El helper valida propietario/permisos/marcador y que config/state/runtime estén bajo el
perfil privado, aplica el journal allí y exige `pluginLoaded=true` para Liquid. No usar
qdbus/kwriteconfig directamente en el bus habitual. Revisar el log si la carga devuelve
false o aparece `shader unavailable`: esa sesión solo demuestra el respaldo Vidrio.

Guardar información del **compositor privado**, sin suponer qué GPU está usando:

```sh
python3 - "$SINGLR_SESSION_FILE" <<'PY'
import runpy, subprocess, sys
from pathlib import Path
get_environment = runpy.run_path('tools/material-review.py')['environment']
env = get_environment(Path(sys.argv[1]))
print(subprocess.check_output(['qdbus6', 'org.kde.KWin', '/KWin', 'org.kde.KWin.supportInformation'], env=env, text=True))
PY
```

Anotar GPU/vendor/renderer, versión de driver, KWin, Qt, kernel, alimentación/perfil de
energía, resolución, escala y Hz del monitor padre. Guardar también `lspci -nnk` y
`pacman -Q kwin qt6-base mesa nvidia-utils` (ausencias explícitas). En un equipo híbrido,
NVIDIA presente no significa que componga: esta primera comparación usa la GPU que el
renderer confirma. No cambiar `KWIN_DRM_DEVICES` ni la sesión habitual para medir.

## 2. Seis capturas comparables y respaldo

Mantener el mismo wallpaper, escala, posición del puntero y ventanas. Construir el
helper Qt con `cmake --build build --target singlr-material-image`. La suite abre
centro de control y lanzador y conserva su geometría entre materiales; guarda también
el borde ampliado y un JSON con región recibida y contador de pases del shader.

```sh
shots=$(mktemp -d /tmp/singlr-material-shots.XXXXXX)
for mode in dark light; do
    python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode "$mode" --intensity 65 --suite "$shots/$mode"
done
python3 tools/material-review.py "$SINGLR_SESSION_FILE" --mode dark --material liquid --without-effect --capture "$shots/liquid-fallback-dark.png"
```

Liquid sin plugin debe verse como Vidrio. Volver a Liquid sin `--without-effect` debe cargarlo.
Probar también intensidad 0/100 y reducir transparencia desde Ajustes de la sesión privada.
Abrir/cerrar y recrear lanzador, menús, notificaciones y OSD: comprueba ventanas diferidas,
recortes y que no queda una región de blur fullscreen detrás del lanzador.

Para inspeccionar refracción con una referencia rica en bordes, abrir el fixture dentro
del perfil privado (sin `--animate` para capturas):

```sh
python3 - "$SINGLR_SESSION_FILE" <<'PY'
import runpy, subprocess, sys
from pathlib import Path
get_environment = runpy.run_path('tools/material-review.py')['environment']
env = get_environment(Path(sys.argv[1]))
subprocess.run(['qml6', str(Path('kwin/effects/singlr-liquidglass/tools/Backdrop.qml').resolve())], env=env, check=True)
PY
```

Mover esa ventana debajo del panel y no variar su posición entre materiales. Este fixture
se cierra a los 60 s. Capturar sin HUD; comparar texto pequeño, esquinas, brillo, cromatismo,
bordes de alto contraste, tema claro/oscuro y escalas 100/125/150 %. Aprobación visual pendiente.

## 3. Tiempo de frame y GPU, con/sin efecto

Usar el mismo tamaño, escena y GPU. Hacer tres repeticiones por variante, alternando el
orden: **Vidrio con plugin descargado**, **Sólido con plugin cargado/inactivo**, **Liquid 65**.
Añadir Sólido y Liquid 100. No comparar reposo con una escena animada.

Instrumentar solo el KWin privado mediante un wrapper temporal en PATH. Cerrar el runner
anterior y arrancar otro con los mismos argumentos/plugin path. La variable `out` debe ser
una ruta absoluta de resultados, creada en el paso 1:

```sh
probe=$(mktemp -d /tmp/singlr-mangohud.XXXXXX)
cat > "$probe/kwin_wayland" <<'SH'
#!/bin/sh
exec mangohud /usr/bin/kwin_wayland "$@"
SH
chmod +x "$probe/kwin_wayland"
PATH="$probe:$PATH" MANGOHUD_DLSYM=1 MANGOHUD_CONFIG="no_display,autostart_log=20,log_duration=30,log_interval=0,output_folder=$out,frametime,gpu_stats,gpu_power,gpu_name,permit_upload=0" QT_PLUGIN_PATH="$stage/usr/lib/qt6/plugins" QML_IMPORT_PATH="$PWD/build/qml" SINGLR_DEV_ROOT="$PWD" tools/run-singlr.sh --size 2048x1280 --duration 65 > "$out/measured-session.log" 2>&1
```

En otra terminal: copiar el **nuevo** descriptor, seleccionar la variante con el helper y
abrir el fixture anterior añadiendo `'--', '--animate'` al comando qml6. Abrir el lanzador
sobre el fixture **antes de los 20 s**. Mantenerlo abierto hasta terminar el log de 30 s.
Repetir con una sesión nueva por variante; guardar CSV/log con material, repetición y tema.
Para el baseline usar `--material glass --without-effect`. Para comprobar coste de la carga
inactiva usar `--material solid` sin descargarlo.

Validar primero que MangoHud se adjuntó a **kwin_wayland**, no qml6: debe producir CSV de ese
proceso con frametimes y GPU. Si no engancha EGL o no produce CSV, la medición queda
bloqueada; no interpretar datos del fixture como tiempo del compositor. MangoHud registra
intervalos de presentación/swap, **no duración pura del shader ni GPU timestamp queries**.
Con vsync esos intervalos pueden ser iguales aunque haya más trabajo; acompañarlos de carga
GPU/potencia. No desactivar vsync solo en una variante.

MangoHud admite OpenGL con hooking dlsym y logs configurables según sus
[instrucciones oficiales](https://github.com/flightlessmango/MangoHud) y
[configuración](https://github.com/flightlessmango/MangoHud/blob/master/data/MangoHud.conf).
No usar los FPS como única prueba de «coste cero».

Registrar además ambas GPU durante cada prueba activa. Identificar AMD por `vendor=0x1002`
en `/sys/class/drm/card*/device/vendor`; muestrear `gpu_busy_percent` cada 500 ms y, si está
expuesto, `hwmon/hwmon*/power1_average` (microvatios). Para NVIDIA:

```sh
nvidia-smi --query-gpu=timestamp,pci.bus_id,name,utilization.gpu,power.draw,memory.used --format=csv -lms 500 > "$out/nvidia-active.csv"
```

Detener al acabar los mismos 30 s. Ambos son datos de dispositivo, no atribuibles
exclusivamente a KWin: cerrar cargas ajenas y comparar deltas. `nvidia-smi` puede despertar
la GPU discreta; no usar ese sondeo para afirmar que el efecto la despertó. En reposo,
registrar primero `device/power/runtime_status` de ambas GPU y ejecutar una repetición sin
sondeo NVIDIA. Si un contador no existe o devuelve N/A, registrarlo como no disponible.

Extraer del CSV de cada variante mediana/p95/p99 de frametime, frames por encima de un
periodo de refresco (1000/Hz ms), carga media/p95 GPU y potencia media, anotando las unidades
y columnas reales del CSV de la versión instalada. No usar umbrales nuevos como aprobados.
En anidado hay otro compositor y dos presentaciones: comparar dentro del mismo entorno;
no generalizar esas latencias a la sesión DRM instalada.

## 4. Reposo, memoria y recuperación P-016

Repetir **sin MangoHud ni fixture animado** con plugin descargado/cargado. Descriptores
incluyen `shell_pid`; obtener el PID privado de KWin del árbol del runner y registrar ambos:

```sh
tools/measure-resources.sh --existing-pid PID_SHELL --existing-pid PID_KWIN --phase idle --output /tmp/material-idle
```

Repetir con `--phase open-panels` y `--phase after-close`, guardando rutas diferentes.
Esperar a liberar DeferredLoader tras cerrar, comparar memoria de KWin/texturas, CPU y GPU.
No afirmar eficiencia global usando solo PSS del shell. La prueba obligatoria de laptop
queda pendiente hasta tener medidas; configuración/lint no la sustituyen.

Cerrar el runner (Ctrl+C en su terminal o esperar duración). El log debe terminar con
`SINGLR_CLEANUP remaining=[]` y `SINGLR_HOST_CONFIG ... equal=True`. Eliminar únicamente los
directorios temporales `stage`, `probe` cuando ya no se necesiten; conservar resultados.
Para aceptación real posterior: repetir en sesión Singlr instalada, volver a Plasma y
comprobar restauración exacta de los tres valores KWin. No se realizó aquí.
