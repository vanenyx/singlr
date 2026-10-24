# Sesión Singlr — T211 (preparación, sin instalar)

Esta entrega prepara una entrada Wayland adicional para el greeter. No se ha
instalado ni iniciado. **No es todavía una sesión de producción validada.**
La petición de T211 autoriza esta preparación; el target selectivo y las rutas
son soluciones técnicas derivadas, pendientes de validación en login real.
No se han cambiado decisiones visuales ni archivos de Plasma.

## Investigación local: 24-10-2026

Arch: plasma-workspace 6.8.1-1, kwin 6.8.1-2, plasma-pa 6.8.1-1,
systemd 262.1-1, Qt 6.12.0. Fuentes locales leídas:

- `/usr/share/wayland-sessions/plasma.desktop`: el greeter ejecuta
  `/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland`.
- `startplasma-wayland` es un ELF, no un script. El
  [código oficial v6.8.1](https://github.com/KDE/plasma-workspace/blob/v6.8.1/startkde/startplasma.cpp)
  prepara el entorno y solicita **por nombre fijo**
  `plasma-workspace-wayland.target`; no ofrece un selector de target externo.
  Por eso Singlr no lo envuelve ni lo ejecuta.
- `/usr/lib/systemd/user/plasma-workspace-wayland.target` requiere KWin y
  `plasma-workspace.target`; este requiere `plasma-core.target`, que solicita
  `plasma-plasmashell.service`, kded6 y ksmserver. La unidad de plasmashell
  ejecuta `/usr/bin/plasmashell --no-respawn`.
- `plasma-krunner.service` ejecuta `krunner --daemon` y admite activación D-Bus
  desde `/usr/share/dbus-1/services/org.kde.krunner.service`. No basta con
  omitir el autostart para evitar su activación posterior.
- La unidad instalada `plasma-kwin_wayland.service` tiene `BusName` de readiness
  `org.kde.KWinWrapper`. El
  [wrapper oficial v6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/helpers/wayland_wrapper/kwin_wrapper.cpp)
  publica las variables de display antes de registrar ese nombre; por eso el shell
  se ordena después de esa unidad y no supone `wayland-0`.

Se intentó `systemctl --user list-dependencies plasma-workspace.target --no-pager`:
falló con `Operation not permitted` al conectar al bus del usuario. La cadena
anterior procede de archivos instalados, no de una consulta al estado vivo.
No incluye posibles overrides del usuario o unidades generadas. Repetir ese
comando fuera del sandbox antes de instalar; no se ha consultado ni mutado la
sesión KDE habitual.

## Grafo propio y servicios reutilizados

`singlr-workspace.target` requiere KWin, el shell y `graphical-session.target`.
Solicita kded6, polkit-agent, PowerDevil, KActivities, ambos portales y audio
(PipeWire, compatibilidad PulseAudio y WirePlumber). Las unidades KDE conservan
sus ejecutables y `PartOf=graphical-session.target`. `After=plasma-core.target`
en algunos servicios solo ordena: no introduce una dependencia de arranque.

El target usa `DefaultDependencies=no` con orden explícito para evitar el ciclo
que provocaría ordenar todos sus Wants antes del target: el portal genérico
necesita arrancar después de `graphical-session.target`.

No se requiere `plasma-workspace*.target`, `plasma-core.target`, ksmserver,
restauración de sesión ni `xdg-desktop-autostart.target`; no se disparan
indiscriminadamente los autostarts del usuario. No se instalan masks, overrides,
enlaces Wants ni cambios de enable/disable sobre unidades KDE.

En esta versión **no existe `plasma-kglobalaccel.service`**: KWin integra el
administrador de atajos (`/usr/include/kwin/globalshortcuts.h`, miembro
`KGlobalAccelD`). Tampoco existe `plasma-pa.service`: plasma-pa instala QML de
volumen y `kf6/kded/audioshortcutsservice.so`; kded carga los módulos habilitados
por la configuración existente. No se inventan unidades para ellos.

`singlr-shell.service` usa readiness D-Bus `org.kde.plasmashell`, nombre que el
binario actual ya registra para Meta/lanzador; también registra `org.kde.krunner`.
Se ordena antes de kded6 para reservar esos nombres. Así las llamadas normales
al lanzador llegan a Singlr. No es una prohibición de ejecutar manualmente
plasmashell/KRunner; comprobar los nombres y ausencia de esos procesos en el E2E.

Si el shell o KWin terminan, `BindsTo` desactiva el target. El supervisor permanece
vivo hasta entonces o hasta SIGTERM/INT/HUP, detiene el target y la sesión gráfica,
y restaura las variables gestionadas de systemd. D-Bus no permite borrar variables
de activación: las que no existían se dejan vacías. No se para el bus ni el
sistema de audio, que pueden pertenecer a otros usos del usuario.

## Contrato de empaquetado y desarrollo

El futuro paquete deberá proporcionar:

```text
/usr/lib/singlr/singlr-shell        binario C++ actual
/usr/lib/singlr/qml/Shell.qml       punto de entrada
/usr/lib/singlr/qml/Singlr/**       imports QML completos
```

El servicio llama `/usr/lib/singlr/startsinglr-wayland --shell`, que hace exec del
binario con dos argumentos separados: directorio de imports y `Shell.qml`.
El binario establece layer-shell; no se exporta globalmente un plugin Qt a las apps.

Para desarrollo, `SINGLR_DEV_ROOT=/ruta/absoluta/al/checkout` en el entorno del
lanzador selecciona `shell/session/build/singlr-shell` y `shell/qml` del checkout.
Compilar previamente con `shell/session/build.sh` (fuera de esta entrega); no se
compila durante el login. El lanzador pasa la variable al servicio y la restaura
al salir. Para que el greeter la reciba, habrá que configurar explícitamente su
entorno o un wrapper de desarrollo; no se configura aquí.

`--dry-run` no necesita binario, bus ni permisos de administrador:

```bash
session/startsinglr-wayland --dry-run
SINGLR_DEV_ROOT="$PWD" session/startsinglr-wayland --dry-run
session/install.sh --dry-run
session/install.sh --prefix /tmp/singlr-staging --dry-run
session/uninstall.sh --prefix /tmp/singlr-staging --dry-run
```

`--prefix` es la **raíz de destino/staging**, por defecto `/`. Las rutas internas
siguen siendo `/usr/...`; un staging no es una instalación relocatable ejecutable.

## Instalación y reversión futuras (NO ejecutadas aquí)

Después de empaquetar y validar, el creador podrá ejecutar desde este checkout:

```bash
sudo session/install.sh --prefix / --dry-run
sudo session/install.sh --prefix /
# Tras cerrar Singlr y entrar en Plasma o una TTY:
sudo session/uninstall.sh --prefix / --dry-run
sudo session/uninstall.sh --prefix /
```

El instalador solo copia la entrada, el supervisor y dos unidades propias; escribe
un manifiesto SHA-256 en `/usr/lib/singlr/session-install.json`. **No instala el
binario ni QML**, no ejecuta sudo ni systemctl y no habilita nada. Rechaza cualquier
archivo de destino existente o ruta con symlinks. No implementa upgrades: primero
revertir la versión anterior. La desinstalación precomprueba todos los hashes y
rechaza archivos modificados antes de borrar; conserva binario/QML y archivos
ajenos. Guardar este checkout para invocar `uninstall.sh`.

El futuro paquete debe integrar CMake, reglas de instalación, dependencias y
propiedad de estos archivos; no mezclar gestión manual con propiedad del gestor
de paquetes. CMake y Ninja no están disponibles en este host según doctor.
La entrada Plasma original se conserva y sigue seleccionable. Para refrescar el
user manager, cerrar completamente la sesión del usuario antes del primer login
Singlr o ejecutar `systemctl --user daemon-reload` fuera de esta tarea.

## Verificación ejecutada y pendiente

Ejecutado en sandbox:

- `python3 -m unittest discover -s tests/shell -p test_session_entry.py -v`:
  staging temporal, dry-run sin escrituras, reversión, conservación de payload,
  conflictos, archivo modificado, symlinks, argumentos del shell, rechazo de sesión
  activa y limpieza/restauración tras fallo de arranque: **7 pruebas correctas**.
- `bash -n session/install.sh session/uninstall.sh`: correcto.
- Dry-run de instalación/desinstalación y lanzador: correcto.
- `python3 scripts/check_setup.py`: correcto; `python3 scripts/doctor.py`: inventario.
- Shellcheck: no está disponible; no se instaló.
- `systemd-analyze --user verify session/systemd/singlr-workspace.target session/systemd/singlr-shell.service`:
  devuelve 1 por restricciones de sockets (`SO_PASSRIGHTS`/`SO_PASSCRED`,
  `Operation not permitted`). Un segundo intento sin `--user`, con las rutas
  de unidades locales, encuentra el mismo bloqueo. **Unidades no validadas por verify.**

Repetir verify fuera del sandbox. Antes de instalar, la referencia a
`/usr/lib/singlr/startsinglr-wayland` puede generar un diagnóstico de ejecutable
ausente; comprobar después en staging completo o con el paquete presente. No se
ha probado el grafo real, renderizado, login ni cierre desde el greeter.

Pendientes de aceptación: login en VT real; fallos/cierre de KWin y shell; retorno
al greeter y login Plasma posterior; Meta/Alt+F2 sin KRunner; polkit; audio;
portales (captura, selección y sandbox); energía y bloqueo. No se incluye ksmserver
ni se acredita su API de logout/salvado o bloqueo seguro. Para terminar la prueba
se puede usar `systemctl --user stop singlr-workspace.target` desde una TTY.

La sesión real reutiliza la configuración KDE del usuario: no tiene el aislamiento
XDG del prototipo anidado y los servicios pueden actualizar sus preferencias.
No admite escritorios simultáneos bajo el mismo UID: systemd y los nombres KDE
son compartidos. El supervisor rechaza displays heredados y unidades gráficas
activas antes de mutar el entorno; no debe arrancarse con un compositor ajeno
que no participe en ese grafo. Probar primero con un usuario dedicado.
