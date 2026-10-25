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

## T214: agente de secretos de NetworkManager

Implementación técnica del [contrato autorizado](../../docs/phase1/secrets-contract.md).
El lanzador adquiere `org.kde.plasmashell` antes de cargar QML y, solo si lo
consigue y no se usa `--windowed`, construye `SecretAgent` y expone `SinglrSecrets`.
NetworkManagerQt registra `org.singlr.networkmanagement` en el bus del sistema.
Las peticiones conservan el mensaje D-Bus original hasta `provide`/`cancel`;
`CancelGetSecrets`, una petición duplicada y la desaparición de NM invalidan el
identificador y emiten `requestCancelled`. `RequestNew` evita leer la contraseña
anterior y emite `retry=true`. Sin permiso de interacción se devuelve `NoSecrets`
si no hay secretos suficientes. Las respuestas contienen solo secretos del ajuste
solicitado, nunca el perfil completo.

Compatibilidad contrastada con fuentes oficiales:

- [plasma-nm v6.8.1, kded/secretagent.cpp](https://github.com/KDE/plasma-nm/blob/v6.8.1/kded/secretagent.cpp):
  carpeta/servicio `Network Management`, clave `{uuid};nombre-del-ajuste`,
  `Setting::secretsToStringMap()` serializado como objeto JSON compacto.
- [QtKeychain, backend Unix](https://github.com/frankosterfeld/qtkeychain/blob/main/qtkeychain/keychain_unix.cpp):
  el backend KWallet usa `NetworkWallet()`, carpeta igual al servicio y entradas
  Password para texto JSON. También lee las entradas Map heredadas.
- Cabeceras instaladas: NetworkManagerQt y KWallet **6.31.0**, plasma-nm **6.8.1**,
  Qt **6.12.0**, revisadas el 24-10-2026. Se usan `Wallet::readMap` para el formato
  heredado y `readPassword`/`writePassword` para el actual, sin migración al leer.

Solo se persisten secretos `AgentOwned`, excluyendo `NotSaved`/`NotRequired` y
los que administra el sistema. Un secreto suministrado por NM prevalece sobre
una entrada antigua. Si KWallet falla, los secretos que traiga la conexión
siguen sirviendo; una contraseña introducida puede usarse sin persistirla.
`SaveSecrets`/`DeleteSecrets` notifican errores de almacenamiento. El borrado
abarca las claves del UUID exacto, incluidos ajustes antiguos.

La interacción de un único campo admite WPA-PSK, SAE, WEP, LEAP y 802.1x cuando
NetworkManagerQt solo requiere `password`. VPN, certificados, PIN y métodos con
varios secretos no tienen UI en este contrato y reciben `NoSecrets` si requieren
interacción. No se implementan plugins de autenticación VPN ni migración desde
archivos de texto históricos de plasma-nm.

El supervisor live descarga `networkmanagement` antes de arrancar en sustitución
y guarda un marcador para recargarlo en `stop` o si falla el arranque. No lo
descarga con `--keep-plasma`. Un fallo al restaurar conserva el marcador para
reintentar con `stop`. No se descarga ningún módulo desde las pruebas unitarias.

Compilación: `build.py` ejecuta el `moc` del `libexecdir` de Qt6Core y compila una
unidad agregada temporal para mantener una única invocación atómica y un archivo
de dependencias completo. Enlaza `KF6NetworkManagerQt` y `KF6Wallet` directamente
y obtiene los includes transitivos de GLib mediante `pkg-config libnm`. La caché
incluye el ejecutable de moc, fuentes y cabeceras; omite los archivos temporales.

### Validación fuera del sandbox (Claude)

Integrar primero el QML de Codex 1 que consume `SinglrSecrets`. Desde una terminal
de la sesión Wayland real, reservar una red de prueba WPA2/SAE y su interfaz;
estos pasos desconectan temporalmente esa interfaz. No introducir contraseñas
en argumentos de comandos, logs o evidencias.

```bash
cd /home/sunw/Projects/singlr-worktrees/codex-2
shell/session/build.sh
python3 -m unittest discover -s tests/shell -p 'test_*.py' -v

nmcli -f DEVICE,TYPE,STATE device
read -r -p 'Interfaz Wi-Fi de prueba: ' WIFI_DEVICE
read -r -p 'SSID de prueba: ' WIFI_SSID
ORIGINAL_UUID=$(nmcli -g GENERAL.CON-UUID device show "$WIFI_DEVICE")
TEST_PROFILE="singlr-t214-$(date +%s)"

tools/singlr-live.sh start
qdbus6 org.kde.kded6 /kded org.kde.kded6.loadedModules
# La lista no debe contener networkmanagement.

nmcli connection add type wifi ifname "$WIFI_DEVICE" con-name "$TEST_PROFILE" \
    ssid "$WIFI_SSID" wifi-sec.key-mgmt wpa-psk wifi-sec.psk-flags 1 \
    connection.autoconnect no
# Para una red exclusivamente WPA3, cambiar wpa-psk por sae.
nmcli --wait 120 connection up id "$TEST_PROFILE" ifname "$WIFI_DEVICE"
```

Mientras espera el último comando, el centro de control debe abrir la fila del
SSID y enfocar su contraseña sin abrir el diálogo de red de KDE. Introducir una
contraseña incorrecta: debe volver a pedirla con «Contraseña incorrecta»
(`RequestNew`). Introducir la correcta: la conexión debe activarse. Si NM termina
la activación tras el fallo en lugar de enviar `RequestNew`, registrar ese resultado
y reactivar el perfil; no dar por validado el camino `retry` sin observarlo.
Para probar cancelación después de las reconexiones siguientes, usar:
`nmcli connection down id "$TEST_PROFILE"`,
`nmcli connection modify id "$TEST_PROFILE" wifi-sec.psk-flags 2` y
`nmcli --wait 120 connection up id "$TEST_PROFILE" ifname "$WIFI_DEVICE"`.
El flag `NotSaved` evita reutilizar la entrada de la cartera. Cancelar en QML:
el comando debe terminar sin quedarse esperando. Para cancelación desde NM,
volver a activar y ejecutar `nmcli connection down id "$TEST_PROFILE"` desde
otra terminal mientras está abierto el campo: debe cerrarse mediante
`requestCancelled`. Después restablecer
`nmcli connection modify id "$TEST_PROFILE" wifi-sec.psk-flags 1`.

```bash
# Tras conectar correctamente: reconectar sin volver a escribir la contraseña.
nmcli connection down id "$TEST_PROFILE"
nmcli --wait 60 connection up id "$TEST_PROFILE" ifname "$WIFI_DEVICE"

# Restaurar KDE y comprobar que puede leer el secreto guardado por Singlr.
tools/singlr-live.sh stop
qdbus6 org.kde.kded6 /kded org.kde.kded6.loadedModules
# Debe volver a incluir networkmanagement.
nmcli connection down id "$TEST_PROFILE"
nmcli --wait 60 connection up id "$TEST_PROFILE" ifname "$WIFI_DEVICE"

# Limpiar únicamente el perfil de prueba; se debe borrar su entrada de KWallet.
nmcli connection delete id "$TEST_PROFILE"
if [ -n "$ORIGINAL_UUID" ] && [ "$ORIGINAL_UUID" != '--' ]; then
    nmcli --wait 60 connection up uuid "$ORIGINAL_UUID" ifname "$WIFI_DEVICE"
fi
tools/singlr-live.sh stop
```

Validar también la dirección KDE → Singlr con un perfil de prueba guardado
previamente por KDE (`psk-flags=1`), y una entrada Map heredada si existe una de
prueba. Para verificar el borrado por Singlr, borrar un perfil de prueba mientras
Singlr está activo y comprobar en KWalletManager que desaparece solo su clave.
No exportar ni fotografiar secretos. Como control, `start --keep-plasma` debe
mantener cargado el módulo, y `tools/check-shell.sh` debe seguir cargando el modo
`--windowed`, sin la propiedad `SinglrSecrets`.

Límites pendientes: las pruebas de formato no acreditan el intercambio D-Bus
real ni acceso a una cartera real. KWallet puede pedir autorización para la nueva
aplicación o desbloquear la cartera; es un diálogo de la cartera independiente
del diálogo de contraseña de red que sustituimos. Una configuración de QtKeychain
forzada a libsecret/otro backend queda fuera de esta compatibilidad directa con
KWallet. SIGKILL del supervisor requiere `tools/singlr-live.sh stop` para restaurar
el módulo; no puede ejecutarse limpieza desde un proceso muerto.

### Evidencia ejecutada en el sandbox (24-10-2026)

- `shell/session/build.sh`: PASS, binario `shell/session/build/singlr-shell`.
  Único aviso: deprecación ya existente de `LayerShellQt::Shell::useLayerShell`.
- `python3 -m unittest discover -s tests/shell -p 'test_*.py' -v`:
  **27 tests, PASS** (24,922 s): formato nativo, flags, restauración kded simulada,
  caché/concurrencia/fallos de build y ciclo de vida de sesiones simulado.
  Incluye detener el agente Singlr antes de restaurar KDE si falla el supervisor.
  Se ajustó el compilador simulado al nuevo orden de argumentos.
- `test_build.py` repetido tras añadir comprobaciones de las nuevas dependencias:
  **PASS** (13,295 s).
- `tools/check-shell.sh --output /tmp/singlr-t214-windowed.png`: **PASS**,
  qmllint y carga/captura offscreen con `qml6`; no ejecuta el agente nativo.
- Sonda QML temporal ejecutada con el binario nativo, `--windowed`, plataforma
  offscreen, XDG temporales y ambos buses deshabilitados: **PASS**, el temporizador
  comprueba `typeof SinglrSecrets === "undefined"` y sale con código 0. Salida:
  `SINGLR_SECRETS_WINDOWED_ABSENT` (requiere `QT_FORCE_STDERR_LOGGING=1`).
- `python3 scripts/check_setup.py` y `git diff --check`: **PASS**.
- `dbus-run-session -- true`: bloqueado, `Failed to bind socket ... Operation
  not permitted`; no se ejecutó integración real con NetworkManager/KWallet.

No se modificó `shell/qml/**`, no se creó commit y no se tocó la sesión KDE activa.

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
