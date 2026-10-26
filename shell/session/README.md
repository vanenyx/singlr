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

## Secretos de red — T266

El agente propio de T214 y su serialización KWallet se retiraron. La sesión
instalada reutiliza `networkmanagement` de plasma-nm, cargado por kded. El centro
de control sigue usando el módulo QML de plasma-nm para listar y conectar redes;
KDE atiende peticiones de secretos de perfiles guardados. No se descarga el módulo
kded durante el login. El antiguo modo `tools/singlr-live.py` queda fuera de T266:
no usar su takeover de networkmanagement con este shell hasta actualizarlo.

El shell se ejecuta dentro de la unidad oficial `plasma-plasmashell.service`,
con disponibilidad Type=dbus y reinicio de Plasma. Véase [sesión](../../session/README.md)
y [handoff T266](../../docs/handoffs/T266-startplasma.md).

## T227: atajos globales (P-015)

Implementa el [contrato de entrada](../../docs/phase1/input-contract.md). Solo al
adquirir `org.kde.plasmashell`, fuera de `--windowed`, registra el dock 1…9 con
Autoloading y el componente `singlr`/«Singlr». Meta+N y Meta+A se asignan como
predeterminados y activos si no hay otro propietario, incluidas secuencias que
los solapen. Los conflictos y métodos QML ausentes quedan en `shell.log`.
`/PlasmaShell.singlrShowApplications` invoca `showApplications()`; los demás
mensajes del puente conservan `toggleLauncher()`.

Antes de modificar las cuatro acciones KWin se guarda un JSON atómico, versión 1,
componente `kwin`, `actions` por nombre y listas de secuencias de hasta cuatro
enteros Qt. Conserva atajos deshabilitados, alternativos y de varios pasos.
`$XDG_RUNTIME_DIR/singlr-live/shortcuts-backup.json` nunca se sobrescribe si existe;
un backup inválido impide aplicar cambios y se conserva. Un bloqueo de archivo
serializa aplicar/restaurar. Meta+Up/Down se liberan primero en las cuatro acciones,
se asignan a maximizar/minimizar y se conservan las demás teclas de Quick Tile.
Las escrituras se comprueban leyendo de nuevo `shortcutKeys`.

SIGTERM/SIGINT se convierten en salida del bucle Qt; `aboutToQuit` restaura.
Una salida temprana del lanzador también intenta restaurar. Solo se borra el
backup tras confirmar todas las escrituras. `stop` ejecuta el modo headless
`--restore-shortcuts` si queda un backup, incluso sin supervisor activo; un error
conserva el archivo y devuelve fallo para reintentar. `--keep-plasma` pasa
`--no-takeover` para evitar una sustitución accidental si Plasma no está presente.

API contrastada con cabeceras locales KGlobalAccel **6.31.0**, Qt **6.12.0** y
[XML D-Bus oficial](https://github.com/KDE/kglobalaccel/blob/master/src/org.kde.KGlobalAccel.xml):
`shortcutKeys(as) → a(ai)`, `setForeignShortcutKeys(as, a(ai))`. Se reutilizan los
operadores D-Bus exportados de `QKeySequence` y se registran `QList<int>`,
`QKeySequence` y `QList<QKeySequence>` como
[KGlobalAccel](https://github.com/KDE/kglobalaccel/blob/master/src/kglobalaccel.cpp).
No se modifican los valores predeterminados de las acciones KWin.

### Comandos para Claude, fuera del sandbox

Tras integrar las funciones QML de Codex 1, en la sesión Wayland real:

```bash
shell/session/build.sh
python3 -m unittest discover -s tests/shell -p 'test_shortcuts.py' -v
python3 -m unittest discover -s tests/shell -p 'test_live_*.py' -v
tools/singlr-live.sh start
python3 -m json.tool "$XDG_RUNTIME_DIR/singlr-live/shortcuts-backup.json"
# Pinza o llamada directa; debe abrir todas las aplicaciones:
qdbus6 org.kde.plasmashell /PlasmaShell singlrShowApplications
# Revisar mensajes de conflicto/métodos ausentes:
rg 'Singlr:|conflicto' "$XDG_RUNTIME_DIR/singlr-live/shell.log"
```

Comprobar Meta y Alt+F1, Meta+1…9 (incluidas posiciones sin aplicación), Meta+N,
Meta+A y Meta+Up/Down con una ventana normal. Revisar que Quick Tile conserva
otros atajos. Si Meta+N/A ya pertenece a otra acción, esa acción debe seguir
funcionando y aparecer el conflicto; no hace falta cambiar atajos para probarlo.
Cambiar un QML para provocar recarga: el backup debe seguir representando el
estado original y Meta+Up/Down deben seguir funcionando.

```bash
tools/singlr-live.sh stop
test ! -e "$XDG_RUNTIME_DIR/singlr-live/shortcuts-backup.json"
# Confirmar en Preferencias de KDE los cuatro atajos previos del JSON.
# Repetir la parada: no debe cambiar nada.
tools/singlr-live.sh stop
# Recuperación directa sin interfaz gráfica, si queda un backup tras un cierre forzado:
shell/session/build/singlr-shell --restore-shortcuts
```

Las pruebas nativas verifican el formato y la política de conflictos sin bus;
una prueba adicional usa exclusivamente un servicio KGlobalAccel simulado en
`dbus-run-session` para aplicar dos veces, conservar backup, restaurar y rechazar
JSON inválido. El sandbox impide crear su socket: esa prueba se marca omitida,
no como integración aprobada. Las pruebas Python cubren el respaldo de `stop`
y la conservación del backup ante errores. La interacción real queda pendiente
de ejecutar estos comandos con Claude; no se ha cambiado la sesión KDE del host.

Evidencia T227 ejecutada en este sandbox (24-10-2026): `build.sh` PASS (solo aviso
preexistente de `useLayerShell`); suite `test_*.py`: **36 pruebas, 34 PASS y 2
omitidas** por sockets D-Bus bloqueados (76,205 s). Las omitidas son la nueva
restauración D-Bus simulada y la prueba D-Bus de tray preexistente. Sonda del
binario real `--restore-shortcuts` sin display y con QPA deliberadamente inválido:
PASS con backup ausente, y fallo esperado conservando un backup inválido.
`check_setup.py` y `git diff --check`: PASS. Sin commit.
