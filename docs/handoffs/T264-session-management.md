# T264 — Acciones mediante KDE SessionManagement

26 oct 2026 · Codex 1 · `fix/t264-kde-session-management` · sin commit.
Solución técnica derivada del encargo; afecta a Singlr System/Session/Platform.

El shell enlaza `LibKWorkspace` → `PW::KWorkspace`, comprobado en
`/usr/lib/cmake/LibKWorkspace/LibKWorkspaceLibraryTargets.cmake`; el build incremental
usa `/usr/include/kworkspace6` y `-lkworkspace6`. El paquete exige
`plasma-workspace>=6.8` (ya era dependencia) y conserva PowerDevil/KScreenLocker.

Eliminados `loginCall`, sondeo/reconsulta propios de capacidades, `sleepAction`,
`sessionAction`, `terminateSession`, fallback sin ksmserver, watcher de Shutdown,
`shutdownFinished` y estado de solicitud inferido. Las seis capacidades del menú
se leen y notifican desde SessionManagement. No quedan referencias a login1 ni
org.kde.Shutdown en `shell/session/src` o QML ejecutable.

| Acción Singlr | API KDE | Camino comprobado de Plasma instalado |
| --- | --- | --- |
| Bloquear | `lock()` | ScreenSaver `/ScreenSaver`, `Lock`, sujeto a `canLock` |
| Suspender | `suspend()` | backend de libkworkspace → login1 `Suspend(true)` |
| Hibernar | `hibernate()` | backend de libkworkspace → login1 `Hibernate(true)` |
| Cerrar sesión | `requestLogout()` | LogoutPrompt `promptLogout` o Shutdown `logout` |
| Reiniciar | `requestReboot()` | LogoutPrompt `promptReboot` o Shutdown `logoutAndReboot` |
| Apagar | `requestShutdown()` | LogoutPrompt `promptShutDown` o Shutdown `logoutAndShutdown` |

**Corrección de la hipótesis inicial:** libkworkspace6 **6.8.1-1 instalado también
suspende por logind**; no hay un salto a PowerDevil en su backend. Delegar en esta
biblioteca unifica con Plasma, pero no demuestra que el audio/dock se arreglen.
No se fuerza un camino distinto al de KDE para satisfacer aquella hipótesis.

Confirmación: se conserva `ConfirmationMode::Default`, que lee
`ksmserverrc`, grupo General, `confirmLogout` (predeterminado true). Se elimina
la confirmación de doble clic de Singlr para estas tres acciones: ahora la
confirmación y su cancelación pertenecen a KDE. SessionManagement no publica
señales por solicitud de éxito/error/cancelación: se conservan los nombres QML
`sessionActionFailed/Cancelled` por compatibilidad, sin emitir resultados
inventados; `sessionActionPending` queda false. El menú sigue disponible después
de cancelar y respeta `canLock/Logout/Reboot/Shutdown` además de las dos de sueño.

El bloqueo antes de dormir pertenece a KScreenLocker: escucha PrepareForSleep y
aplica LockOnResume; SessionManagement no añade un Lock previo. No se sustituye
esa política ni se toca PAM. Sin ksmserver, SessionManagement sigue enviando la
petición al helper KDE; plasma-shutdown registra el error de closeSession y
continúa con `ksmServerComplete()` → cierre de ventanas Wayland de KWin. Un false
de closeSession cancela. Se respeta este comportamiento de KDE sin añadir un
fallback de Singlr a logind. El arranque dedicado sí asegura ksmserver disponible.

Arranque: el target ya requiere y enlaza su vida a plasma-ksmserver.service;
la unidad KDE declara BusName=org.kde.ksmserver. Se añade al shell el mismo
`After=plasma-ksmserver.service` que usa plasma-plasmashell.service, para heredar
SESSION_MANAGER/ICEAUTHORITY publicados antes de adquirir el nombre. Se revisó
`startsinglr-wayland`; conserva la espera del helper al finalizar el target,
que evita limpiar prematuramente PAM/entorno (no es el sondeo eliminado del shell).
`git stash pop` de «T263 wip» falló por index.lock de solo lectura; se reprodujo
manualmente su único cambio, idéntico. **El stash permanece**, no volver a aplicarlo
sin revisar el cambio ya incorporado.

## Procedencia verificable

Base: Arch, plasma-workspace/powerdevil 6.8.1-1, Qt 6.12.0.
Cabecera `/usr/include/kworkspace6/sessionmanagement.h`; biblioteca
`/usr/lib/libkworkspace6.so.6.8.1`, build ID
`a7ef23068eac3254ea76f958ac8c28c1fd16f0d3`.
Se inspeccionaron sin ejecutar acciones mediante `nm -D -C`, `objdump -d -C
--no-show-raw-insn`, `strings -el -t x` y `objdump -R -C`:

- SessionManagement: lock 0x21400, requestShutdown 0x22860, requestReboot 0x22b20,
  requestLogout 0x22de0, suspend 0x23000, hibernate 0x231a0;
  confirmLogout 0x274b0 (General/confirmLogout, true).
- Backend de sueño: Suspend 0x28f20, Hibernate 0x291e0; ambas construyen argumento
  true y esperan la respuesta de login1 (`waitForFinished`). No llamada previa a Lock.
- `/usr/bin/plasma-shutdown`: respuesta de closeSession desde 0xb098;
  rama de error 0xb180 registra el fallo y vuelve por 0xb15b/0xb16e a
  ksmServerComplete (0xa9d0), igual que true; false 0xb120 llama
  QCoreApplication::quit. No se ejecutó el helper real.
- `/usr/lib/libKScreenLocker.so.6.8.1`: conexión PrepareForSleep 0x19197;
  política antes de bloquear 0x21840–0x21958, propiedad LockOnResume.
- Unidades instaladas `/usr/lib/systemd/user/plasma-{ksmserver,plasmashell}.service`.

Fuentes oficiales complementarias:
[API y confirmación](https://api.kde.org/legacy/plasma/plasma-workspace/html/sessionmanagement_8cpp_source.html),
[backend logind](https://api.kde.org/legacy/plasma/plasma-workspace/html/sessionmanagementbackend_8cpp_source.html),
[bloqueo de KDE](https://github.com/KDE/kscreenlocker/blob/master/ksldapp.cpp),
[helper de cierre](https://github.com/KDE/plasma-workspace/blob/master/startkde/plasma-shutdown/shutdown.cpp).
Las páginas de API son históricas; la comprobación de **6.8.1** se hizo contra los
binarios/cabeceras locales, no atribuyéndoles la versión de esas páginas. La descarga
del tag 6.8.1 no estuvo disponible (DNS del sandbox/fetch web).

## Verificación

- `shell/session/build.sh`: OK; aviso preexistente de useLayerShell obsoleto.
- `tools/check-cmake.sh`: OK, compilación y DESTDIR verificado; vidrio OFF.
- `python3 scripts/doctor.py`: inventario; `python3 scripts/check_setup.py`: OK.
- `python3 -m unittest discover -s tests/shell -v`: 99 pruebas, 0 fallos,
  4 omitidas por sockets D-Bus del sandbox. Incluye 18 de entrada de sesión.
- Tras ampliar el test de acciones: `python3 -m unittest discover -s tests/shell
  -p test_session_actions.py -v`: 3 pruebas, 0 fallos, 1 omitida. Ejecutadas la
  comparación de capacidades offline y la delegación suspend/hibernate al backend
  oficial de autotest de KDE, con ambos buses deshabilitados.
- La prueba de protocolo actualizada usa **la biblioteca real**, ambos buses
  redirigidos a un daemon privado y un servicio simulado en otro proceso (las
  llamadas de sueño de KDE son síncronas). Cubre confirmación activada/desactivada,
  capacidades denegadas, ausencia de ksmserver y ninguna terminación alternativa.
  **Pendiente ejecutarla fuera del sandbox** con `SINGLR_REQUIRE_SESSION_DBUS=1`:
  aquí dbus-daemon no puede crear el socket (`Operation not permitted`).
- `tools/test-qml.sh` y `tools/test-qml.sh --light`: 245 shell + 9 Ajustes
  por modo, 0 fallos; cinco capturas opcionales omitidas por modo.
- `git diff --check`: OK. Búsqueda
  `rg -n 'login1|org.kde.Shutdown|terminateSession|shutdownFinished|queryCapability'
  shell/session/src shell/qml --glob '!README.md'`: vacía (exit 1 esperado).

No se instaló ni relanzó nada en la sesión activa. Pendientes login real actualizado,
cancelación en el diálogo KDE/aplicación con cambios, XSMP/restore de Chrome y
suspensión física con audio/dock. Esta entrega no certifica esas regresiones resueltas.
