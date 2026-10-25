# T237 — ksmserver, P-017

Solución técnica derivada del encargo, sin instalación ni commit. Qt local
6.12.0, plasma-workspace 6.8.1-1 y KWin 6.8.1-2. `TopBar.qml` también cambia:
contenía otra instancia del controlador retirado.

## Contrato contrastado

Código oficial **v6.8.1**, leído mediante el conector GitHub:

- [ksmserver/main.cpp](https://github.com/KDE/plasma-workspace/blob/v6.8.1/ksmserver/main.cpp):
  `loginMode` selecciona la sesión; por defecto `restorePreviousLogout`.
  Es una `QCoreApplication`: no arranca shell, lanzador ni bloqueador.
- [server.cpp](https://github.com/KDE/plasma-workspace/blob/v6.8.1/ksmserver/server.cpp)
  y [logout.cpp](https://github.com/KDE/plasma-workspace/blob/v6.8.1/ksmserver/logout.cpp):
  publica `SESSION_MANAGER`/`ICEAUTHORITY`, restaura clientes registrados,
  negocia XSMP y guarda `ksmserverrc`. `closeSession()` devuelve un booleano
  diferido; completar esa llamada **no termina por sí solo ksmserver**.
- [plasma-shutdown/shutdown.cpp](https://github.com/KDE/plasma-workspace/blob/v6.8.1/startkde/plasma-shutdown/shutdown.cpp):
  solicita `closeSession()`, guarda el estado fallback, solicita a KWin cerrar
  ventanas Wayland y admite cancelación. En Singlr `plasma-workspace.target`
  está inactivo: KDE usa su rama clásica, pide `quit` a ksmserver y KWin y
  finalmente llama a logind para reboot/poweroff. En Plasma administrado por
  systemd detiene `graphical-session.target`. No hay que falsificar ese target.
- [startplasma.cpp](https://github.com/KDE/plasma-workspace/blob/v6.8.1/startkde/startplasma.cpp):
  espera la desaparición tanto de `org.kde.KWinWrapper` como de
  `org.kde.Shutdown` antes de limpiar el grafo. Singlr mantiene su supervisor:
  `BindsTo` + `After` de ksmserver desactiva el target al salir ese proceso;
  el supervisor espera también a `org.kde.Shutdown`, limpia grafo/entorno,
  restaura KWin y termina únicamente su sesión PAM. Así no corta al helper
  mientras espera polkit/logind para apagar o reiniciar.
- [interfaz KSMServer](https://github.com/KDE/plasma-workspace/blob/v6.8.1/ksmserver/org.kde.KSMServerInterface.xml):
  no exporta señales de cancelación. Tras desaparecer `org.kde.Shutdown`,
  `SinglrSystem` consulta `isShuttingDown()` sin activación: si devuelve falso
  emite `sessionActionCancelled(action)`. El shell muestra un aviso sin Forzar.
  Es una inferencia del estado público: una caída del helper antes de iniciar
  la negociación podría producir el mismo aviso. Si el estado sigue cerrando,
  informa un error; nunca reintenta directamente por logind.
- [restaurador fallback](https://github.com/KDE/plasma-workspace/blob/v6.8.1/startkde/session-restore/restore.cpp)
  y [guardado fallback](https://github.com/KDE/plasma-workspace/blob/v6.8.1/startkde/session-restore/save.cpp):
  **se conserva el autostart KDE**. `restoreSession` restaura clientes gestionados;
  el fallback complementa las apps Wayland sin XSMP y filtra lo ya gestionado.
  Dolphin Wayland puede depender de este complemento; no se promete que una
  llamada aislada a `restoreSession` restaure todas las apps Wayland.

Las unidades KDE instaladas confirman `BusName=org.kde.ksmserver`, orden después
de KWin y `restoreSession` después de `graphical-session.target`. Solo se añaden
dependencias al target Singlr. No se cambia `loginMode`, no se sobrescriben las
sesiones existentes y no se añaden filtros de aplicaciones. La primera entrada
puede restaurar el estado KDE antiguo; después de un cierre correcto queda
guardado el estado actual. Los errores o límites de apps que no cooperan siguen
siendo los de KDE.

El shell lleva `AA_DisableSessionManager`: lo administra el target y no debe
guardarse como aplicación ni salir antes de que otra app pueda cancelar.
La eliminación de `SessionCloseController` quita el modelo de tareas duplicado,
sus temporizadores y la ruta Forzar; P-012 conserva la confirmación en el menú.

## Pruebas automatizadas

```bash
python3 -m unittest discover -s tests/shell -p 'test_session*.py' -v
# Fuera del sandbox: exige ejecutar realmente la prueba con D-Bus simulado.
SINGLR_REQUIRE_SESSION_DBUS=1 python3 -m unittest discover -s tests/shell -p test_session_actions.py -v
tools/check-shell.sh --output /tmp/t237-shell.png
python3 scripts/check_setup.py
systemd-analyze --user verify session/systemd/singlr-workspace.target session/systemd/singlr-shell.service
```

La prueba nativa compila el `System` real. En un bus privado registra servicios
falsos login1/KWin/Accounts/ksmserver y un servicio Shutdown **activable**, que
ejecuta el propio fixture. Comprueba las tres rutas en Singlr/KDE, confirmación
de ausencia antes del fallback, duplicados pendientes, cancelación/reintento,
errores sin bypass, caída del helper y final sin falsa cancelación. No abre el
bus de sistema real. QML prueba confirmación, despacho y aviso de cancelación;
Screens/Resources cubren superficies y liberación del menú tras retirar el
controlador.

## Validación anidada para Claude (pendiente)

Ejecutar desde este checkout, **fuera del sandbox**. Este recorrido no necesita
systemd de usuario ni instala unidades; usa un bus privado y XDG temporal, y
desactiva el bus de sistema para que las pruebas no apaguen el host. No demuestra
el grafo de login instalado: ese grafo requiere después un login desde el greeter.

Preparación en la terminal anfitriona:

```bash
shell/session/build.sh
export SINGLR_T237_CHECKOUT="$PWD"
export SINGLR_T237_STORE="$(mktemp -d /tmp/singlr-t237.XXXXXX)"
case "$WAYLAND_DISPLAY" in
  /*) export SINGLR_T237_PARENT="$WAYLAND_DISPLAY" ;;
  *) export SINGLR_T237_PARENT="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
esac
mkdir -p "$SINGLR_T237_STORE"/{config,data,state,cache,probe}
```

Para **cada entrada**, ejecutar este bloque; repetirlo para la segunda entrada
con el mismo `SINGLR_T237_STORE` (solo runtime/bus se recrean):

```bash
t237_runtime=$(mktemp -d "$SINGLR_T237_STORE/runtime.XXXXXX")
env -u DISPLAY -u WAYLAND_SOCKET -u DBUS_SESSION_BUS_ADDRESS \
    -u DBUS_STARTER_ADDRESS -u DBUS_STARTER_BUS_TYPE -u SESSION_MANAGER \
    -u ICEAUTHORITY -u XAUTHORITY -u QT_WAYLAND_SHELL_INTEGRATION \
    -u XDG_ACTIVATION_TOKEN -u DESKTOP_STARTUP_ID -u QT_WAYLAND_RECONNECT \
    DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent-t237-system-bus \
    XDG_RUNTIME_DIR="$t237_runtime" \
    XDG_CONFIG_HOME="$SINGLR_T237_STORE/config" XDG_CONFIG_DIRS=/etc/xdg \
    XDG_DATA_HOME="$SINGLR_T237_STORE/data" XDG_DATA_DIRS=/usr/local/share:/usr/share \
    XDG_STATE_HOME="$SINGLR_T237_STORE/state" XDG_CACHE_HOME="$SINGLR_T237_STORE/cache" \
    XDG_CURRENT_DESKTOP=Singlr:KDE XDG_SESSION_DESKTOP=Singlr XDG_SESSION_TYPE=wayland \
    KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 QT_QPA_PLATFORM=wayland \
    QT_QPA_PLATFORMTHEME= \
    dbus-run-session -- bash --noprofile --norc
```

**Dentro de esa bash privada**, arrancar compositor y ksmserver:

```bash
cd "$SINGLR_T237_CHECKOUT"
kwin_wayland --wayland-display "$SINGLR_T237_PARENT" --socket t237-wayland \
  --width 1280 --height 800 --no-lockscreen --no-global-shortcuts --no-kactivities \
  >"$XDG_RUNTIME_DIR/kwin.log" 2>&1 &
t237_kwin=$!
export WAYLAND_DISPLAY=t237-wayland
until qdbus6 org.kde.KWin /Session >/dev/null 2>&1; do
  kill -0 "$t237_kwin" || break
  sleep .1
done
dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP \
  XDG_SESSION_DESKTOP XDG_SESSION_TYPE QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME
ksmserver >"$XDG_RUNTIME_DIR/ksmserver.log" 2>&1 &
t237_ksm=$!
until qdbus6 org.kde.ksmserver /KSMServer >/dev/null 2>&1; do
  kill -0 "$t237_ksm" || break
  sleep .1
done
# ksmserver publica ambos valores para las activaciones D-Bus; estos son para
# las aplicaciones lanzadas directamente desde esta bash de prueba.
IFS= read -r SESSION_MANAGER < "$XDG_RUNTIME_DIR/KSMserver_"
export SESSION_MANAGER
for t237_auth in "$XDG_RUNTIME_DIR"/iceauth_*; do export ICEAUTHORITY="$t237_auth"; done
shell/session/build/singlr-shell "$PWD/shell/qml" "$PWD/shell/qml/Shell.qml" \
  >"$XDG_RUNTIME_DIR/shell.log" 2>&1 &
t237_shell=$!
trap 'kill "$t237_shell" "$t237_ksm" "$t237_kwin" 2>/dev/null; wait' EXIT
qdbus6 org.kde.ksmserver /KSMServer org.kde.KSMServerInterface.restoreSession
# Equivalente al autostart KDE conservado en el target instalado:
/usr/lib/plasma-fallback-session-restore
```

Primera entrada: abrir `dolphin "$SINGLR_T237_STORE/probe" &`, comprobar su
ventana y usar **Cerrar sesión** en el menú Singlr (dos clics). Alternativa para
aislar el contrato KDE:

```bash
qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
wait "$t237_ksm"
wait "$t237_kwin"
until test "$(qdbus6 org.freedesktop.DBus /org/freedesktop/DBus \
  org.freedesktop.DBus.NameHasOwner org.kde.Shutdown)" = false; do sleep .1; done
cat "$XDG_CONFIG_HOME/ksmserverrc"
cat "$XDG_STATE_HOME/plasmasessionrestorestaterc" 2>/dev/null
exit
```

Esperado: Dolphin se cierra, ksmserver/KWin terminan y queda estado de sesión.
En la segunda entrada el bloque `restoreSession` + fallback debe reabrir Dolphin
**sin lanzarlo manualmente**. Abrir además Kate, modificar un documento sin
guardarlo, solicitar logout y elegir Cancelar: ksmserver/KWin/shell siguen vivos,
`isShuttingDown` devuelve falso y aparece el aviso; otro intento vuelve a funcionar.
Comprobar que `plasma-ksmserver.service` no trae plasmashell, KRunner ni greeter
de bloqueo: revisar procesos nuevos por entorno `DBUS_SESSION_BUS_ADDRESS` de
esta bash, no por `pgrep` global (el host puede tener esos procesos).
Guardar logs y estado temporal como evidencia; su eliminación es la reversión.

Después, en login Singlr real: comprobar ksmserver activo antes del restaurador,
logout → target inactivo → supervisor terminado → retorno al greeter, y el mismo
recorrido con cancelación. Validar reboot/poweroff solo en el entorno de prueba
autorizado; el bus de sistema está deliberadamente inhabilitado arriba.

Medición P-016 pendiente fuera del sandbox:
`tools/measure-resources.sh --output /tmp/t237-resources` (consulta `--help` para
opciones). La medida del shell y el coste adicional de ksmserver son distintos;
registrar ambos al validar el login real.

## Resultados ejecutados en este worktree

- `test_session*.py`: 24 pruebas, 23 correctas y 1 omitida por imposibilidad de
  crear el socket D-Bus privado (`Operation not permitted`). La prueba D-Bus
  está escrita y compila; **no se declara ejecutada**. El modo nativo offline sí
  pasa. `SINGLR_REQUIRE_SESSION_DBUS=1` convierte la omisión en fallo para Claude.
- QML offscreen, buses desactivados y XDG temporal: SessionMenu **14 correctas**,
  Screens **3**, ResourceLifecycle **7** (incluyen init/cleanup). Hay avisos
  esperados de servicios desconectados y superficies sin Wayland; esto no
  acredita renderizado ni cierre real de aplicaciones.
- `tools/check-shell.sh --output /tmp/t237-shell.png`: compilación nativa,
  qmllint, carga offscreen y captura correctos.
- `tools/check-cmake.sh`: compilación y staging DESTDIR correctos, incluido
  el target actualizado y ausencia del controlador QML retirado. Advertencia
  previa: `LayerShellQt::Shell::useLayerShell()` está deprecado.
- `python3 scripts/check_setup.py`: correcto; `scripts/doctor.py`: inventario.
- `systemd-analyze --user verify ...`: bloqueado por restricciones de sockets
  SO_PASSRIGHTS/SO_PASSCRED; **no acredita el grafo**.
- Pendientes: prueba D-Bus con fixture, ciclo real anidado, login/retorno al
  greeter, cancelación real, reboot/poweroff y medida P-016. No se ha instalado,
  parado ni cambiado la sesión KDE/Singlr activa.

## Validación de Claude (25 oct)

- `SINGLR_REQUIRE_SESSION_DBUS=1` test_session*: 24 OK (se retiró una comprobación
  inválida: Qt no expone NO_AUTO_START en mensajes recibidos). Python completo 65 OK,
  QML 124 OK, `systemd-analyze --user verify` correcto.
- KWin anidado + ksmserver, cuatro entradas: (1) Dolphin abierto → logout: Dolphin se
  cierra, ksmserver y KWin terminan, el estado guarda Dolphin; (2) Dolphin se reabre solo;
  (3) se cierra Dolphin → logout; (4) no se restaura nada. Sin plasmashell, KRunner ni
  bloqueador en el bus de prueba.
- Pendiente: login real desde el greeter (retorno al greeter, cancelación con Kate).

## Cartera KDE (diagnóstico, no es fallo de Singlr)

`ksecretd: error -9` = el descifrado Blowfish con la clave derivada del login da
basura (`backendpersisthandler.cpp`). La cartera se creó por PAM el 22 oct 23:13; la
contraseña de la cuenta se cambió con `passwd` el 23 oct 00:09, y `passwd` no actualiza
la cartera (limitación conocida de KDE). La sesión Plasma siguió abierta hasta el 25,
por eso no se vio antes. Solución estándar: con la cartera abierta, cambiar su contraseña
a la de inicio de sesión (`org.kde.KWallet.changePassword`; con la cartera abierta no pide
la anterior). La realiza el creador: es una credencial suya.

## Cierre (25 oct)

El creador cambió la contraseña de la cartera (antigua → actual) por el diálogo estándar de
KDE, instaló el paquete y entró desde el greeter: sin aviso de cartera, navegadores y
cuentas correctos, logout/restauración como se esperaba. `plasma-ksmserver.service`
activo y sin error -9 de PAM en el nuevo login.
