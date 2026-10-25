# T250 — Command y carga de sesión

## Corrección T251 de Command

El contrato de agregación y el ID `systemsettings` descritos abajo quedan
corregidos por [T251](../handoffs/T251-command-fix.md): ID instalado
`krunner_systemsettings`, origen real por QueryMatch, deduplicación global y
ofertas al final. El contrato KSplash se conserva.

## Contratos

Command conserva Milou/KRunner para aplicaciones, archivos y operaciones. Un segundo
`Milou.ResultsModel`, restringido a `systemsettings`, aporta exclusivamente resultados
reales del runner estándar. Se agrupan en «Configuración», sin duplicarlos en el
runner general. La ejecución y las acciones vuelven al índice actual del modelo
original: KDE decide el KCM y su llamada a systemsettings/kcmshell6. Las páginas
locales se exponen solo con la app de ajustes disponible. Fondo usa `--wallpaper`;
Apariencia y Material abren Apariencia, **donde está Material en este checkout**.
Al integrar la página de Material de Codex 2, conectar su argumento específico;
no se han editado `Main.qml`, `Appearance.qml`, `Theme.qml` ni `Glass.qml`.

Los sinónimos exactos ES/EN reescriben únicamente la consulta del runner de KCM;
no crean resultados. Los términos originales siguen llegando al runner general.
Ctrl+K/clic derecho ofrece «Abrir configuración»; no ofrece fijar un KCM al dock.
Los modelos se destruyen al cerrar Command, y el agregado no tiene temporizadores
periódicos. Las acciones y URLs se copian como valores, sin retener submodelos QML.

La sesión importa sus defaults mediante `XDG_CONFIG_DIRS`, incluido `ksplashrc`,
sin escribir preferencias globales. Respeta `Engine` del usuario. Primero arranca
la unidad KWin, luego encola `plasma-ksplash.service` sin esperar su oneshot y
arranca el target Singlr. La unidad estándar KDE conserva `TimeoutSec=40sec` y
`PartOf=graphical-session.target`; no hay unidad KSplash alternativa ni drop-in.

`SplashBridge` comunica `startPlasma`, observa la disponibilidad real de ksmserver
y comunica `desktop` tras el primer `frameSwapped` de una superficie visible.
Reproduce hitos ya alcanzados si KSplash registra tarde su servicio. KSplash
deduplica etapas y termina al contar seis (`initial`, `kcminit`, `wm`,
`startPlasma`, `ksmserver`, `desktop`). No se simula disponibilidad con un timer.
La conexión de render se retira tras el primer frame. El paquete usa
`Singlr.Ui.SessionSplash`, sin bucles de animación; `Motion` sigue
`AnimationDurationFactor` mediante Kirigami. El color efectivo sigue KDE.

Fuentes contrastadas: paquete instalado `plasma-workspace 6.8.1-1`, unidad local
`/usr/lib/systemd/user/plasma-ksplash.service`; código oficial rama Plasma/6.8:
[startplasma.cpp](https://github.com/KDE/plasma-workspace/blob/Plasma/6.8/startkde/startplasma.cpp)
(`startKSplashViaSystemd`) y
[splashapp.cpp](https://github.com/KDE/plasma-workspace/blob/Plasma/6.8/ksplash/ksplashqml/splashapp.cpp)
(etapas, duplicados y cierre). Qt local 6.12.0.

## Repetir comprobaciones

```bash
cmake -S . -B build -DSINGLR_BUILD_LIQUIDGLASS=OFF
cmake --build build -j2
SINGLR_CAPTURE_T250=1 tools/test-qml.sh
SINGLR_CAPTURE_T250=1 tools/test-qml.sh --light
SINGLR_TEST_ANIMATION_FACTOR=0 tools/test-qml.sh
python3 -m unittest discover -s tests/shell -p test_session_entry.py
python3 scripts/check_setup.py
```

El efecto se desactiva **solo en este build** porque faltan cabeceras Vulkan; no
se cambia el valor por defecto del proyecto ni materiales. Capturas offscreen
reales en `tests/shell/evidence/t250/`; el modelo de Command de las capturas es
un doble explícito, no evidencia de resultados KCM vivos.

## Procedimiento para Claude fuera del sandbox

1. En un perfil temporal o usuario de pruebas, iniciar el entorno anidado con
   `tools/run-singlr.sh --duration 40`. No reutilizar el bus del escritorio.
   Ejecutar en ese bus `qmltestrunner -import shell/qml -import build/qml
   -input tests/shell/command-native`; comprobar consultas wifi/bluetooth/pantalla/
   sonido/teclado, sin módulos inventados ni duplicados. En Command buscar además
   fondo/wallpaper, oscuro/dark y material/glass. Enter y Ctrl+K deben abrir la
   página concreta. Comprobar apertura KCM real y regreso del foco.
2. Con `XDG_CONFIG_HOME` temporal y `QML_IMPORT_PATH=$PWD/build/qml`, ejecutar
   `ksplashqml --test --window --nofork "$PWD/session/look-and-feel/dev.singlr.dark"`
   y el paquete light. Establecer la paleta KDE del perfil a BreezeDark/BreezeLight
   respectivamente; repetir con `[KDE] AnimationDurationFactor=0`. El proceso
   debe terminar por sí mismo en unos seis segundos. No usar el bus habitual.
3. El arranque systemd completo necesita login del usuario dedicado de la batería
   `tests/session/README.md`; un KWin anidado no demuestra el grafo de login.
   Verificar en journal KWin → KSplash → shell/ksmserver, observar el splash y
   comprobar `systemctl --user show plasma-ksplash.service -p ActiveState -p Result`
   tras entrar: `inactive`, `success`, sin esperar el timeout. Probar cancelación
   de apps al salir y vuelta a Plasma; su splash/configuración deben conservarse.
4. Ejecutar `tools/measure-resources.sh --output /tmp/t250-resources` y repetir
   con `--scenario open-panels`; registrar PSS/CPU/GPU antes de integrar. En este
   sandbox falló el socket D-Bus, y los hashes de configuración del host quedaron
   iguales. No hay medición válida ni login real acreditado.
