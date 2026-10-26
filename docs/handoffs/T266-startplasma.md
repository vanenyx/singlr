# T266 — inicio oficial de Plasma y sustitución exclusiva del shell

26 oct 2026 · Codex 2 · rama `fix/t266-startplasma` · sin commit ni instalación real.
Encargo explícito del creador; diseño de integración derivado. Atiende sobre todo
Singlr Session y Platform; conserva Desktop, System y Appearance. No certifica
Singlr 1.0 ni constituye aprobación visual.

## Diseño elegido y fuentes

`session/startsinglr-wayland` queda reducido a exportar identidad/defaults y hacer
exec del wrapper D-Bus oficial con `/usr/bin/startplasma-wayland`. La entrada
instalada de Plasma confirma ese comando. El wrapper fija exactamente
`XDG_SESSION_DESKTOP=Singlr`; el identificador del greeter puede venir en minúsculas.
`startplasma` fija `XDG_CURRENT_DESKTOP=KDE`, lo cual conserva la integración KDE.
El wrapper rechaza explícitamente systemdBoot=false en startkderc antes de arrancar:
la vía clásica no utiliza la unidad del shell. No escribe ni corrige esa preferencia.

El [inicio oficial v6.8.1](https://github.com/KDE/plasma-workspace/blob/v6.8.1/startkde/startplasma.cpp)
procesa scripts de entorno/locales, sincroniza D-Bus/systemd, resetea fallos,
recarga unidades/generadores y controla cierre/limpieza. Se ejecuta ese código,
sin reproducir sus fases. Los targets instalados consultados fueron
`plasma-workspace-wayland.target`, `plasma-workspace.target`, `plasma-core.target`
y sus directorios wants. KWin, ksmserver, kded, PowerDevil, polkit, portales,
restauración, autostart XDG, DrKonqi y Baloo conservan las dependencias de Plasma.
No se mantiene una copia de su lista. Las activaciones D-Bus y los servicios
opcionales siguen dependiendo de la instalación/configuración de KDE.

Para el shell se elige un **drop-in estático de la unidad oficial**, con
`ExecStart=` vacío seguido de `ExecStart=/usr/lib/singlr/singlr-shell-exec`.
El dispatcher hace exec de Singlr solo si la identidad coincide; en Plasma normal
hace exec de `/usr/bin/plasmashell --no-respawn`. No queda proceso intermediario.
La [semántica de ExecStart y Type=dbus de systemd](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)
permite preservar la unidad, su BusName único y las dependencias oficiales.
No hay dos servicios competidores por `org.kde.plasmashell`: el nombre canónico
es `plasma-plasmashell.service`, incluso cuando el proceso es `singlr-shell`.
Se heredan sin copiar Type=dbus, After=ksmserver, PartOf, Restart=on-failure,
TimeoutSec y los límites de tres arranques/60 s. `plasma-core.target` mantiene la
barrera de disponibilidad; no se introduce un BindsTo fatal con ksmserver/shell.
El aviso independiente de agotamiento se conserva, condicionado a Singlr.

La [opción oficial --shell-plugin de plasmashell](https://github.com/KDE/plasma-workspace/blob/v6.8.1/shell/main.cpp)
selecciona un paquete que carga ShellCorona; no selecciona un ejecutable alternativo.
El shell actual de Singlr es un runtime Qt Quick/layer-shell independiente y no
un paquete de containments de plasmashell. Usar esa opción exigiría reescribirlo;
el drop-in conserva el runtime y el contrato de arranque oficial.

Tampoco se depende de un generador condicionado por variables importadas vía
D-Bus: en [systemd v262, build_generator_environment](https://github.com/systemd/systemd/blob/v262/src/core/manager.c)
parte de transient_environment, mientras SetEnvironment modifica client_environment.
El dispatcher de una unidad sí recibe el entorno efectivo de la sesión. Esto evita
que la elección dependa del momento de arranque del user manager.

Versiones contrastadas con `pacman -Q`: plasma-workspace 6.8.1-1, kwin 6.8.1-2,
systemd 262.1-1, plasma-nm 6.8.1-1. Doctor: Qt 6.12.0, herramientas QML en
`/usr/lib/qt6/bin`. Se leyó la auditoría T265 indicada en el encargo. Las fuentes
remotas se consultaron por web; curl en el sandbox carece de resolución DNS.

## Integraciones conservadas y retiradas

- `singlr-kwin-prepare.service`: oneshot, condicionado a Singlr, requerido y ordenado
  antes de KWin, con RemainAfterExit, StopWhenUnneeded y PartOf de la sesión gráfica.
  Aplica con recuperación previa del journal. ExecStopPost restaura offline después
  de KWin, también si falla parcialmente el apply. El journal y el helper existentes
  no se reescriben. La recuperación opcional al volver a Plasma se conserva.
- XDG_CONFIG_DIRS privado, PLASMA_DEFAULT_SHELL, KSplash/overlay, paquete de bloqueo
  KScreenLocker/PAM y plugin de vidrio permanecen. No hay configuración de autenticación
  propia ni modificación de preferencias del creador durante esta tarea.
- Se retiran el supervisor Python, singlr-workspace.target y singlr-shell.service.
  Desaparecen polling, limpieza manual del entorno, terminate-session y listas propias
  de servicios. El archivo startsinglr-wayland sigue existiendo solo como wrapper.
- Se retiran secretagent y secretformat, su registro en main.cpp, enlaces directos
  NetworkManagerQt/KWallet/libnm, moc y pruebas exclusivas de ese agente. plasma-nm
  permanece como dependencia y kded aporta networkmanagement. El centro de control
  conserva listado/conexión y contraseña inicial para redes nuevas; los secretos de
  perfiles existentes los solicita KDE. Se eliminan las conexiones QML al agente propio.
- CMake instala el dispatcher, ambos drop-ins y la preparación KWin; registra sus
  fuentes para regenerar copias al cambiarlas. PKGBUILD pasa a pkgrel=2 y fija
  plasma-workspace=6.8.1, además del KWin ya fijado por la ABI del vidrio.

## Instalación y reversión

Claude debe crear el commit. Construir después con `tools/build-package.sh` y
actualizar mediante el paquete local **desde Plasma o una TTY, con Singlr cerrado**.
No actualizar/reiniciar unidades en la sesión cotidiana para probar este cambio.
Pacman retira las unidades anteriores porque ya no forman parte del payload.
Una instalación manual antigua debe desinstalarse con su checkout original antes
de pasar a estos metadatos; no mezclar sus archivos con propiedad de pacman.

Payload relevante nuevo/configurado, bajo `/usr`:

```text
lib/singlr/startsinglr-wayland
lib/singlr/singlr-shell-exec
lib/systemd/user/plasma-plasmashell.service.d/50-singlr.conf
lib/systemd/user/plasma-kwin_wayland.service.d/50-singlr-recovery.conf
lib/systemd/user/singlr-kwin-prepare.service
lib/systemd/user/singlr-kwin-recover.service
lib/systemd/user/singlr-shell-failed.service
share/wayland-sessions/singlr.desktop
```

No enable/disable, máscaras, copias de unidades KDE ni cambios en ~/.config.
Desinstalar con Singlr cerrado después de una salida normal; si quedó un journal
pendiente, recuperarlo antes de retirar el helper:
`/usr/lib/singlr/singlr-kwin --restore --offline` desde TTY con KWin detenido.
Retirar el paquete elimina sus drop-ins y Plasma vuelve a su ExecStart original.

## Verificación ejecutada

| Comando | Resultado |
| --- | --- |
| `tools/check-cmake.sh` | 0: compilación, DESTDIR completo y plugin de vidrio ON; payload y selección del shell correctos |
| `python3 -m unittest discover -s tests/shell -p 'test_session*.py' -v` | 18 pruebas: 17 correctas, 1 omitida por bus privado denegado |
| `python3 -m unittest discover -s tests/shell -p test_kwin.py -v` | 20 correctas, incluido KConfig real en XDG temporal |
| `python3 -m unittest discover -s tests/shell -p test_packaging.py -v` | 5 correctas |
| `python3 -m unittest discover -s tests/shell -p test_robustness.py -v` | 4 correctas |
| `python3 -m unittest discover -s tests/shell -p test_lockscreen.py -v` | 2 correctas, con geometría/password y KPackage real |
| `tools/test-qml.sh` | 244 + 9 correctas, 0 fallos, 5 omitidas en la primera suite |
| `python3 -m unittest discover -s tests/shell -p test_build.py -v` | 1 correcta: caché, dependencias, concurrencia y fallo de compilación |
| `python3 scripts/check_setup.py` | 0: configuración/documentos coherentes |
| `python3 scripts/doctor.py` | 0: inventario, sin instalar ni ejecutar el escritorio |
| `git diff --check` | 0 |

`verify_package.py`, invocado en DESTDIR, llama la misma prueba de selección de
`test_session_entry.py`: combina la unidad **instalada de Plasma** y el drop-in
**instalado en el prefijo temporal**; comprueba que la cadena oficial solicita la
unidad y que todas sus propiedades anteriores salvo ExecStart se conservan.
Ejecuta el dispatcher con binarios registradores aislados: Singlr selecciona solo
singlr-shell; KDE y variable vacía seleccionan solo plasmashell --no-respawn.
También prueba el wrapper de entorno y el rechazo de la vía clásica, orden de la transacción KWin y reversión de
metadatos. Es una prueba del grafo en disco/despacho, no un login real de systemd.

`systemd-analyze --user --generators=no verify` sobre las tres unidades auxiliares
no pudo completar (1): SO_PASSRIGHTS/SO_PASSCRED, Operation not permitted.
No se declara validado el grafo vivo. La prueba privada de acciones de sesión
se omite por la misma restricción al crear el socket de dbus-daemon.
La compilación conserva el aviso previo de LayerShellQt::useLayerShell obsoleto.
Los avisos D-Bus/offscreen de QML corresponden a los buses deshabilitados de pruebas.

## Aceptación pendiente con login real

El creador puede revisar los cambios y hacer lo siguiente con un usuario de prueba:

1. Entrar por el greeter en Singlr. Verificar identidad Singlr y entorno de las apps,
   scripts plasma-workspace/env y locales; shell Singlr único, sin proceso plasmashell.
   `systemctl --user show plasma-plasmashell -p ExecStart -p MainPID -p Type -p BusName`
   muestra el dispatcher; comprobar `/proc/<MainPID>/exe` para el binario efectivo.
2. Revisar `systemctl --user list-dependencies plasma-workspace-wayland.target` y
   journal de startplasma, KWin, ksmserver, kded y plasma-plasmashell. Comprobar
   polkit, portales, audio, energía, Baloo y DrKonqi según sus condiciones oficiales.
3. Comprobar splash, vidrio, bloqueo/desbloqueo PAM, red guardada y nueva (incluido
   secreto incorrecto/KWallet). Verificar que kded carga networkmanagement; no alterar
   la preferencia si el usuario lo deshabilitó expresamente.
4. En ese entorno de prueba, provocar una caída aislada del shell: debe reiniciar
   dentro de plasma-plasmashell.service sin cerrar apps ni compositor. Agotar el límite
   debe mostrar el aviso; la recuperación manual usa el nombre canónico de Plasma.
5. Abrir una app compatible con XSMP, cambiar estado, cerrar sesión y cancelar primero
   el cierre: apps y sesión continúan. Completar después el logout y volver a entrar;
   comprobar estado guardado/restaurado y ausencia de apps reaparecidas desde un estado
   anterior. El orden y negociación son los de Plasma, sin promesa para apps sin soporte.
6. Salir normalmente y verificar restauración del journal KWin. Probar recuperación de
   una interrupción solo en usuario/entorno dedicado. Entrar luego en Plasma normal:
   plasmashell sí, singlr-shell no; sin preferencias transaccionales de Singlr heredadas.

No se hizo login, logout, caída, suspensión ni conexión de red reales en esta tarea.
La sesión activa del creador y sus archivos ~/.config no se tocaron.

Fuera del alcance autorizado: `tools/singlr-live.py` todavía descarga el módulo
networkmanagement; no usar ese takeover con el shell nuevo hasta adaptarlo. Algunos
scripts de `tests/session/` y `singlr-doctor` aún consultan singlr-shell.service o
singlr-workspace.target: usar los comandos canónicos anteriores para T266; su
migración requiere un encargo de herramientas. No se modificaron rutas fuera del
alcance para disimular esa diferencia. La sesión del greeter no usa esos scripts.
