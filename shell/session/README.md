# Sesión anidada de Singlr — Día 1 (T202/T204)

Desde la raíz del checkout, fuera del sandbox y dentro de una sesión Wayland:

```bash
tools/run-singlr.sh                         # 2048×1280, hasta cerrar KWin o Ctrl+C
tools/run-singlr.sh --duration 30           # cierre automático tras 30 segundos
tools/run-singlr.sh --size 1600x1000        # tamaño lógico alternativo
# Otra terminal, mientras viva una única sesión:
tools/capture-session.sh /tmp/singlr-session.png
# Con varias sesiones, seleccionar el JSON anunciado por el lanzador:
SINGLR_SESSION_FILE=/tmp/singlr-session-XXXX/session.json tools/capture-session.sh /tmp/singlr-session.png
```

`SINGLR_DURATION_MS` sigue disponible por compatibilidad; `--duration` lo sustituye.
Sin ambos, el supervisor espera indefinidamente. El cierre de la ventana de KWin,
el del shell, SIGTERM y Ctrl+C ejecutan la limpieza; no es necesario buscar procesos
por nombre. SIGKILL al supervisor no permite garantizar esa limpieza.

El lanzador C++ activa layer-shell únicamente para el shell y elimina esa variable
antes de lanzar aplicaciones. KWin, bus D-Bus, socket Wayland y directorios XDG de
configuración, datos, caché y estado son privados y temporales. No arranca
plasmashell, systemd de usuario, KActivities, bloqueo ni atajos globales. Se elimina
DISPLAY para evitar clientes X11 en el host; no se inicia Xwayland.

El supervisor Linux es subreaper y recoge descendientes separados mediante
setsid/doble fork. Además, al cerrar recoge clientes externos cuyo entorno inicial
contenga exactamente `SINGLR_SESSION_ID=<id de esta sesión>` en `/proc/PID/environ`.
Por tanto, las herramientas externas deben conservar el entorno de `session.json`;
el descriptor también incluye `LANG`, `LANGUAGE` y `LC_*`. El bus privado recibe
esas mismas variables para activaciones D-Bus. No se usa `pkill -f`.
La garantía cubre procesos del usuario con `/proc` accesible que conservan el marcador;
no es una barrera de seguridad para aplicaciones no confiables.

Antes/después se comparan SHA-256 de los archivos `k*`, `plasma*` y `dolphin*`
(incluidos sus subdirectorios) en la configuración anfitriona. Se anuncia
`SINGLR_HOST_CONFIG ... equal=True` o se listan diferencias, sin restaurar ni escribir
configuración del host. Cambios concurrentes legítimos del host también pueden
hacer fallar esta comprobación.

## Compilación y checks locales

```bash
shell/session/build.sh
python3 -m unittest discover -s tests/shell -p 'test_*.py' -v
tools/check-shell.sh --output /tmp/singlr-t204-windowed.png
python3 scripts/check_setup.py
```

`build.sh` usa Python, g++ y pkg-config; requiere cabeceras Qt6 Gui/Qml/Quick y
LayerShellQt (`qt6-base`, `qt6-declarative`, `layer-shell-qt` en este host Arch).
Un error conserva el último binario válido pero devuelve fallo, sin ejecutarlo.
El resultado se publica atómicamente, con bloqueo entre compilaciones simultáneas.
La caché registra comando, flags, compilador, fuente y cabeceras transitivas del
sistema (`-MD`). Admite `CXX`, `CXXFLAGS`, `LDFLAGS` y `SINGLR_BUILD_DIR`.
La salida estándar contiene solo la ruta del ejecutable; diagnósticos van a stderr.
`build/` está ignorado por Git; no se versionan binarios.

`check-shell.sh` comprueba primero la compilación del lanzador, después qmllint y
la carga/captura offscreen de `Shell.qml -- --windowed --capture=<PNG>` con XDG y
bus deshabilitado propios. Esto no prueba KWin, Milou ni interacción real.
Las pruebas headless simulan compositor/bus y verifican cierre normal, duración,
SIGINT, SIGTERM, cierre de KWin, subreaper, cliente externo que ignora TERM,
marcadores de otras sesiones y locale en descriptor/activación. La prueba de build
usa el compilador real: caché, cambios de cabecera/flags, concurrencia y fallo.

## E2E real: comandos exactos para Claude

```bash
cd /home/sunw/Projects/singlr-worktrees/codex-2
python3 tests/shell/e2e.py --duration 100 --evidence /tmp/singlr-t204-real
# Revisar visualmente /tmp/singlr-t204-real/desktop.png y dolphin.png.
# Prueba manual de cierre por ventana y otra por Ctrl+C, ambas sin duración:
tools/run-singlr.sh
tools/run-singlr.sh
```

El directorio de evidencia debe ser nuevo o estar vacío. No necesita Konsole.
El E2E imprime PASS/FAIL por paso y devuelve 0 solo si pasan todos:
arranque con duración, descriptor, locale, superficies en KWin por scripting,
captura del escritorio, lanzamiento de Dolphin por Milou desde una sonda QML en
la sesión, ventana Dolphin en KWin y en TasksModel (`IsWindow` + `IsMapped`),
segunda captura, cierre automático, ausencia de procesos y hashes iguales.
Además mantiene un cliente externo `sleep` para comprobar su limpieza.
Se siguen los PID/starttime de Dolphin para detectar fugas aunque pierda el marcador.

KWin 6.8.1 no expone el scope layer-shell como WM_CLASS: el E2E identifica las
superficies por PID del lanzador, geometría y orden de capas (fondo, dock, barra).
El launcher permanece oculto y no se exige una cuarta superficie.
Se conserva el JSON de cada snapshot, logs separados y `results.json`.
Los PNG registran su tamaño físico: en este host pueden ser 2560×1600 para
2048×1280 lógicos; no se trata como fallo. Claude debe inspeccionar ambos PNG.

## Versiones, contratos y evidencia

Inventario local del 24-10-2026: KWin/LayerShellQt/Milou/Plasma Workspace 6.8.1,
Qt Declarative 6.12.0, KIO 6.31.0 y Spectacle 6.8.1.

- [KWin scripting API](https://develop.kde.org/docs/plasma/kwin/api/):
  `windowList`, PID, frameGeometry, layer y hidden; contrastados con headers locales.
- [LayerShellV1Window v6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/layershellv1window.cpp):
  asigna DesktopLayer/BelowLayer/AboveLayer a background/bottom/top.
- [KWinDisplay::allowInterface v6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/wayland_server.cpp):
  window-management se permite a clientes nativos ordinarios; no se instala un
  .desktop ni se cambia seguridad para probarlo.
- [ScreenShot2 v6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/plugins/screenshot/screenshotdbusinterface2.cpp):
  se reutiliza Spectacle `-b -n -f -o` en el bus privado para obtener PNG.
- Los contratos de Milou `ResultsModel.run(QModelIndex)` y TasksModel `AppId`,
  `IsWindow`, `IsMapped` se contrastaron con qmltypes/headers locales.
- [QQmlApplicationEngine Qt 6.12](https://doc.qt.io/qt-6/qqmlapplicationengine.html):
  el lanzador crea el motor e importa el punto de entrada QML.

Evidencia del sandbox T204 en `tools/evidence/t204.txt`. El bus D-Bus real no puede
crear su socket aquí (`Operation not permitted`): el E2E completo y los cierres
manuales quedan pendientes fuera del sandbox. Claude ya verificó arranque y
captura reales antes de T204; eso no acredita los nuevos pasos E2E.
