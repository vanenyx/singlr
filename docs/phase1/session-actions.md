# T232 — Acciones de sesión

Solución técnica derivada del encargo T232, sin decisión visual ni cambios en QML.
Implementada en `shell/session/src/system.{h,cpp}` y `session/startsinglr-wayland`.

## Contrato para QML

El contexto existente `SinglrSystem` expone estos métodos `void`, sin bloquear el
hilo de UI: `lockScreen()`, `suspend()`, `hibernate()`, `reboot()`, `powerOff()` y
`logout()`. Invocarlos únicamente desde una acción explícita del usuario, nunca
desde `Component.onCompleted`, un binding o la creación del menú.

| Propiedad de solo lectura | Contrato |
| --- | --- |
| `canSuspend`, `canHibernate` | Inicialmente `false`; consulta asíncrona a logind al crear el backend y cada 10 s. `yes` y `challenge` habilitan; `no`, `na`, respuestas desconocidas y errores deshabilitan. Se consulta otra vez antes de ejecutar. |
| `userName` | Nombre real de AccountsService, después `UserName`; alternativa inmediata: nombre de cuenta POSIX. |
| `userIcon` | URL `file://` de `IconFile` legible de AccountsService; alternativa `~/.face.icon`; cadena vacía si no existe. Apta para `Image.source`. |
| `sessionActionPending` | Evita solicitudes simultáneas mientras se consulta o espera respuesta. No representa la finalización física de un apagado ni el desbloqueo posterior. |

Todas tienen señal `…Changed`. `sessionActionFailed(action, message)` informa
fallos de transporte, falta de capacidad o identificador de sesión. También se
registran con `qWarning`. El frontend puede mostrar ese error y deshabilitar
acciones mientras `sessionActionPending`. Las consultas de metadatos fallidas
conservan las alternativas locales y no generan acciones ni diálogos.

Al cargar **solo hay consultas**: estado del overview, `CanSuspend`,
`CanHibernate`, `FindUserById` y `Properties.GetAll`. No hay operaciones de energía,
cierre, bloqueo, systemctl ni loginctl al construir el backend. Las consultas
D-Bus usan un límite de 3 s; las acciones con autorización, 120 s.

## Comportamiento efectivo

- Bloqueo: bus de sesión, `org.freedesktop.ScreenSaver /ScreenSaver`, interfaz
  `org.freedesktop.ScreenSaver`, `Lock()`. Requiere un locker real registrado;
  no se simula el bloqueo con una ventana Singlr.
- Suspender/hibernar: bus del sistema, `org.freedesktop.login1
  /org/freedesktop/login1`, interfaz `org.freedesktop.login1.Manager`,
  `Suspend(true)` / `Hibernate(true)` después de la comprobación de capacidad.
- Apagar/reiniciar: se consulta asíncronamente el propietario **activo** de
  `org.kde.Shutdown`. Si existe, se llama a ese propietario único en `/Shutdown`,
  interfaz `org.kde.Shutdown`, `logoutAndShutdown()` / `logoutAndReboot()`.
  Este flujo KDE negocia el cierre de aplicaciones y termina llamando a
  `PowerOff(true)` / `Reboot(true)` de logind. Singlr no envía una segunda orden.
  Si no hay propietario activo, se llama directamente a logind con `true`.
  No se activa automáticamente plasma-shutdown ni ksmserver: la mera presencia
  del archivo `.service` no cuenta como servicio activo. En una sesión habitual,
  plasma-shutdown puede no estar activo; en esa ruta directa **no se promete
  negociación de guardado con las aplicaciones**. logind conserva sus inhibidores.
  Un error de KDE no provoca un apagado alternativo, evitando ignorar una
  cancelación o duplicar una orden cuyo resultado se desconoce.
- Logout instalado (`XDG_SESSION_DESKTOP=Singlr`): requiere `XDG_SESSION_ID` y
  solicita `org.freedesktop.systemd1.Manager.StopUnit("singlr-workspace.target",
  "replace")` en el bus de usuario. El shell está incluido en ese target y puede
  desaparecer antes de recibir respuesta. El supervisor `startsinglr-wayland`,
  externo al target, detecta la parada, detiene también `graphical-session.target`,
  restaura el entorno de activación y ejecuta `loginctl terminate-session ID`.
  Esto termina el scope de sesión y sus aplicaciones restantes; nunca se usa
  `terminate-user`. El supervisor también termina ese scope cuando el target cae
  por salida de KWin/shell o recibe una señal, después de un arranque exitoso.
  Aunque falle la limpieza intermedia, intenta terminar el scope en `finally`.
  `XDG_SESSION_ID` se importa explícitamente al entorno del shell. La parada
  conserva `sessionActionPending=true` hasta que desaparece el shell.
- Logout en vivo (otro valor o ausencia de `XDG_SESSION_DESKTOP`): delega en
  `org.kde.Shutdown.logout()` si está activo; si no, usa
  `logind.Manager.TerminateSession(XDG_SESSION_ID)`, equivalente D-Bus de
  `loginctl terminate-session ID`. Sin ID no se intenta adivinar otra sesión.
  No se lanza un proceso separado ni un shell de comandos desde el backend.

No se abre el diálogo de confirmación KDE. Polkit puede solicitar autorización
(`interactive=true`) y las aplicaciones pueden mostrar avisos para guardar en
la ruta KDE. La sesión instalada no inicia ksmserver; el logout instalado hace
limpieza de unidades y terminación de procesos, **sin prometer guardado de
ventanas/documentos o restauración de sesión**. Un fallo de logind/polkit se
notifica; no se fuerza la acción ni se elevan privilegios. No hay procesos
auxiliares lanzados y abandonados por SinglrSystem. La limpieza depende de que
systemd/logind respondan correctamente; no se promete eliminar servicios
persistentes de usuario ajenos a `graphical-session.target` o al scope de login.

## Validación sin apagar el equipo

Desde la raíz del checkout, fuera del sandbox que impida sockets Unix:

```bash
SINGLR_REQUIRE_SESSION_DBUS=1 python3 -m unittest discover -s tests/shell -p test_session_actions.py -v
python3 -m unittest discover -s tests/shell -p test_session_entry.py -v
shell/session/build.sh
```

La prueba nativa usa dos conexiones a un bus privado, con servicios falsos para
login1, AccountsService, ScreenSaver, systemd y Shutdown. **Nunca abre el bus de
sistema real**, incluso al comprobar reboot/powerOff/logout. Cubre carga sin
acciones, capacidades, comprobación previa, argumento interactive, rutas con y
sin KDE activo, errores sin reintento destructivo, solicitudes duplicadas,
identidad, logout instalado y falta de ID. La prueba offline comprueba el
metacontrato QML, alternativas sin bus y recuperación de errores. Las pruebas
Python del supervisor verifican orden de limpieza/restauración/terminación,
incluido fallo intermedio, con subprocess simulado.

Consultas reales de solo lectura (no suspenden ni apagan):

```bash
busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend
busctl --system call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.kde.Shutdown
```

Para validar solo el bloqueo, en una sesión de prueba con locker y contraseña
conocida, invocar `SinglrSystem.lockScreen()` desde la UI integrada; alternativa
para verificar el servicio que utiliza:

```bash
busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver Lock
```

Esto **bloquea realmente**; no ejecutar en una sesión anidada sin locker. No
invocar las otras acciones sobre el host para revisar esta entrega. La
validación de logout instalado requiere después un login Singlr desechable.

## Evidencia y versiones

Entorno inspeccionado: Qt 6.12.0, Plasma/kwin 6.8.1, systemd 262.1,
AccountsService 26.27.3. El contrato local de AccountsService se contrastó con
`/usr/share/dbus-1/interfaces/org.freedesktop.Accounts*.xml`; el servicio KDE
con `/usr/share/dbus-1/services/org.kde.Shutdown.service`.

Referencias oficiales consultadas: [Qt asyncCall](https://doc.qt.io/qt-6/qdbusconnection.html#asyncCall),
[login1](https://www.freedesktop.org/software/systemd/man/257/org.freedesktop.login1.html),
[flujo Shutdown KDE](https://github.com/KDE/plasma-workspace/blob/master/startkde/plasma-shutdown/shutdown.cpp)
y [backend logind KDE](https://github.com/KDE/plasma-workspace/blob/master/libkworkspace/sessionmanagementbackend.cpp).
Estas fuentes KDE son de upstream master; no sustituyen una prueba integrada
con el servicio local. Compilación y pruebas del supervisor ejecutadas; el
roundtrip D-Bus simulado está bloqueado aquí por `bind socket: Operation not
permitted`. No se han ejecutado bloqueo, suspensión, hibernación, apagado,
reinicio ni logout reales.
