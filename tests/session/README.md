# T247 — aceptación de Session y Platform (06/07)

Estos scripts prueban **el paquete instalado en un login Singlr real**, no un KWin
anidado. No están ejecutados sobre la sesión del creador en T247. Los PASS de
infraestructura no acreditan el criterio de completo de Singlr 1.0 §6.
No se modifica autenticación, PAM, contraseñas, masks ni la política de KDE.

## Preparación común

El creador crea un **usuario nuevo dedicado** mediante las herramientas normales
de Arch/KDE, con contraseña que solo él conoce. Sin escritorios simultáneos bajo
el mismo UID. Claude opera desde una terminal de ese usuario, con autorización
para interrumpir **esa sesión de prueba**; nunca desde el escritorio cotidiano.
No iniciar los scripts como root, con sudo, ni dentro de dbus-run-session.

Instalar el paquete construido desde este trabajo (incluye el marcador de carga
QML y singlr-doctor). Dependencias de pruebas: python, systemd, qt6-tools (qdbus6),
libkscreen (kscreen-doctor); makepkg/pacman para el fixture. Son herramientas de
prueba, no se añaden como dependencias del producto. Mantener una TTY accesible.
El canal de desarrollo debe estar desactivado en **el usuario de prueba**; el
script lo rechaza por defecto. `--allow-development` sirve para diagnóstico y no
acredita el shell empaquetado.

En terminal del usuario de prueba, desde este checkout:

```bash
mkdir -m 700 -p "$HOME/t247-evidence"
python3 tests/session/real-session.py startup --evidence "$HOME/t247-evidence/startup.json"
singlr-doctor --output "$HOME/t247-evidence/doctor.json"
```

Toda evidencia es un archivo nuevo 0600. Elegir nombres nuevos en cada repetición.
`real-session.py` devuelve 0 si pasan sus comprobaciones automáticas, 1 ante fallo,
2 ante uso incorrecto. Si hay verificaciones visuales/manuales pendientes, un
PASS automático **no** las convierte en aprobadas. Los errores del comando se
muestran en la terminal; el JSON no guarda salidas libres. No adjuntar el
inventario de HOME ni logs crudos: para incidencias usar solo singlr-doctor.

## Batería reproducible

En los comandos siguientes, `R` es `python3 tests/session/real-session.py` (escribir
el comando completo o definir una función `R() { python3 tests/session/real-session.py "$@"; }`).
`E` puede definirse como `E="$HOME/t247-evidence"`.

| Caso / operador | Precondición | Acción | Comprobación | Limpieza |
| --- | --- | --- | --- | --- |
| Inicio / Claude | Login desde greeter, paquete instalado | `R startup --evidence "$E/start.json"` | Target, KWin, ksmserver, kded y shell activos; sin procesos plasmashell/KRunner del UID; entorno del gestor **y del shell**, display/ICE presentes; nombres D-Bus del shell | Solo lectura, conservar JSON |
| Bloqueo / creador + Claude | Desbloqueado; creador presente | `R lock --execute --evidence "$E/lock.json"` | ScreenSaver activo; marcador positivo `SINGLR_LOCKSCREEN_READY` del QML propio; ausencia de fallback en journal; ScreenSaver inactivo tras contraseña **en greeter**; mismos procesos | Creador desbloquea; nunca se fuerza desbloqueo. Tras 180 s el script falla y mantiene bloqueo seguro |
| Pérdida/retorno de salida (suspensión simulada) / Claude | >=2 salidas activas; obtener ID con `kscreen-doctor -o` | `R outputs --output-id 2 --execute --evidence "$E/outputs.json"` (sustituir ID) | Confirma salida deshabilitada, sesión/shell vivos, salida habilitada otra vez y mismos procesos | `finally` restaura modo/posición/escala/rotación originales y verifica; watchdog separado reintenta a los 15 s incluso si muere la terminal |
| Caída / Claude | Sesión estable, sin recargas concurrentes | `R crash --execute --evidence "$E/crash.json"` | SIGKILL al MainPID propio; nuevo PID y nombres D-Bus recuperados **<3 s**; KWin/ksmserver/target conservados | reset-failed/start del shell incluso tras fallo; no modifica unidades |
| Ráfaga / Claude | Apps de prueba abiertas | `R burst --execute --evidence "$E/burst.json"` | Política efectiva 3 inicios/60 s, Restart=on-failure; caídas sucesivas hasta Result=start-limit-hit, shell failed, servicio de aviso solicitado; KWin/ksmserver/target conservados | Recupera shell y detiene solo el aviso `singlr-shell-failed.service` creado por prueba |
| Reejecución / Claude | Sin instalación concurrente | `R reexec --execute --evidence "$E/reexec.json"` | `systemctl --user daemon-reexec`; gestor responde otra vez, mismos PID+tiempo de inicio de shell/KWin/ksmserver y target activo | No requiere; no reinicia servicios |
| Cierre/restauración / creador + Claude | Kate instalada; documento de prueba, ninguna app personal | Recorrido de dos fases descrito abajo | Nueva sesión completa + guardado normal + reapertura automática y contenido | Cerrar Kate y borrar solo documento de prueba tras verificar |
| Instalación durante sesión / creador + Claude | Fixture ausente; sesión estable | Dos fases descritas abajo con pacman | Paquete realmente instalado y mismos procesos de sesión | `pacman -R singlr-session-probe` por creador |

Revisar visualmente tras caída, ráfaga y pérdida de salida: barra/fondo por salida,
un solo dock, foco y teclado, abrir Command, mover una ventana y volver a usar la
app. La medida de recuperación automática alcanza readiness de D-Bus, **no el
primer frame**; medir visualmente/mediante vídeo si se necesita acreditar el
umbral de recuperación perceptible. No hay presupuesto nuevo aprobado aquí.
La recuperación por ráfaga no exige recuperarse en 3 s: debe detener reintentos y
permitir recuperación manual.

La pérdida de una salida ejercita el camino hotplug de suspensión/retorno sin
suspender el equipo ni apagar todas las pantallas. **No acredita suspensión física,
DPMS, ni cero salidas**: KWin protege la última salida. Esos casos quedan pendientes
en hardware; la prueba aislada `tests/shell/hotplug-e2e.sh` es complementaria, no
sustituye esta batería. No deshabilitar a mano la última salida ni cambiar
configuración de seguridad para simularlo.

Si un fallo deja el shell ausente, desde una terminal o TTY del usuario de prueba:

```bash
systemctl --user reset-failed singlr-shell.service
systemctl --user start singlr-shell.service
```

Si falla la prueba del greeter, el creador recupera con el mecanismo KDE/TTY
normal. No matar el locker ni usar métodos de elusión. No ejecutar `lock` sin él.

### Cierre, guardado y restauración (P-017)

1. `R logout-before --evidence "$E/logout-before.json"`.
2. Abrir Kate **sin `--new-instance` ni instancia efímera**, crear un documento con
   el texto `T247 continuidad`, dejar cambios sin guardar. Mantener también Dolphin
   en una carpeta de prueba. Usar «Cerrar sesión» de Singlr.
3. En la petición estándar de guardar de Kate, el creador/operador elige Guardar
   en `$HOME/t247-document.txt`; si primero elige Cancelar, comprobar que se
   conserva la sesión y repetir. No cerrar Kate antes del logout. El greeter debe
   reaparecer sin matar procesos manualmente.
4. Creador entra de nuevo en Singlr; no relanzar Kate/Dolphin manualmente.
   `R logout-after --before "$E/logout-before.json" --evidence "$E/logout-after.json"`.
5. Verificar reapertura automática de apps participantes en XSMP/KDE (no se exige
   que apps sin ese protocolo la implementen), documento exacto, ventanas usables.
   Registrar observación en un archivo local `logout-observation.md` con fecha,
   versiones/apps, guardado, cancelación, retorno al greeter y restauración. El
   script solo certifica cambio completo de procesos e inicio sano, no guardado
   ni restauración de contenido. Un fallo manual bloquea la aceptación aunque
   el JSON automático diga PASS.
6. Cerrar las apps de prueba, borrar el documento y anotar resultado final.

No se modifica ksmserverrc ni se fuerza una política distinta de la estándar.
La confirmación de login del creador registrada en T237 se conserva como evidencia
previa; no sustituye este recorrido completo con guardado.

### Instalación real durante sesión

Desde una carpeta temporal del usuario de prueba, copiar
`tests/session/package-probe/PKGBUILD` y ejecutar `makepkg` (sin `-s`/`-i`, sin root).
Fixture: un archivo de texto bajo `/usr/share`, sin hooks, servicios ni red.

```bash
R continuity-before --evidence "$E/pkg-before.json"
# Creador, mediante el mecanismo administrativo habitual, instala el archivo generado:
# pacman -U /ruta/temporal/singlr-session-probe-1-1-any.pkg.tar.zst
R continuity-after --before "$E/pkg-before.json" --evidence "$E/pkg-after.json"
# Creador desinstala: pacman -R singlr-session-probe
```

La instalación administrativa y cualquier contraseña pertenecen al creador; los
scripts no las leen, guardan ni automatizan. Usar las apps mientras instala y
registrar su continuidad. El fixture demuestra una transacción real de pacman;
no incluye actualización de systemd: `reexec` prueba ese evento explícitamente.
Eliminar después la carpeta temporal de compilación. Si pacman no termina bien,
no dar por válida la prueba aunque la sesión siga viva.

## Instalación limpia → desinstalación → Plasma

La instalación/desinstalación del paquete es **global al equipo**, aunque las
preferencias sean por usuario. Hacerlo en VM/equipo de prueba o ventana coordinada
por el creador sin ninguna sesión Singlr abierta de otros usuarios. No quitar el
paquete que sostiene el escritorio cotidiano. Mantener el checkout para auditoría
tras desinstalar. El creador crea y elimina el usuario; estos scripts no administran
cuentas ni grupos.

1. Antes de instalar Singlr: iniciar Plasma con el usuario nuevo, configurar una
   decoración/atajos reconocibles si se desea y cerrar Plasma normalmente. Desde
   su TTY: `python3 tests/session/home-audit.py baseline --output "$HOME/t247-baseline.json"`.
   No copiar configuraciones ni carteras de otro usuario.
2. Creador instala el paquete local con pacman siguiendo [packaging](../../packaging/README.md).
   Volver al greeter, seleccionar Singlr, ejecutar la batería, usar Dolphin/Kate,
   Command, atajos y ajustes. Probar apariencia solo si se quiere conservar esa
   preferencia compartida con Plasma (inventario abajo). Ejecutar singlr-doctor.
3. Cerrar Singlr normalmente. En TTY:
   `python3 tests/session/home-audit.py after-singlr --baseline "$HOME/t247-baseline.json" --output "$HOME/t247-after-singlr.json"`.
   Si queda backup pendiente, **antes de quitar el paquete**, ejecutar
   `/usr/lib/singlr/singlr-kwin --restore --offline` (KWin detenido); un fallo
   conserva el journal y bloquea continuar. Restaurar atajos pendientes con
   `/usr/lib/singlr/singlr-shell --restore-shortcuts` mientras el KGlobalAccel de
   esa sesión aún esté disponible; no borrar backups para hacer pasar la prueba.
4. Si se eligió apariencia automática y quedaron referencias `dev.singlr.light/dark`,
   seleccionar alternativas KDE instaladas desde Configuración del sistema antes
   de quitar el paquete. Es preferencia compartida: no borrar todo kdeglobals.
   Desactivar canal de desarrollo del usuario de prueba si lo hubiera (`tools/dev-channel.sh disable`),
   sin tocar drop-ins ajenos. Creador ejecuta `pacman -R singlr-desktop`, **sin `-Rns`**.
   `systemctl --user daemon-reload` desde TTY. Ejecutar
   `home-audit.py after-remove` con los mismos `--baseline` y un `--output` nuevo.
5. Entrar en Plasma y ejecutar `home-audit.py after-plasma` del mismo modo.
   Confirmar Plasma visible, atajos/decoración originales, apps y preferencias
   conservadas, sin fallos de unidades Singlr. Comparar los JSON localmente: las
   claves de kwinrc y los cuatro atajos transitorios deben coincidir semánticamente
   (no importa reordenación de INI). Archivos compartidos que KDE actualice por
   uso normal requieren revisión; no restaurar archivos enteros sobre una sesión viva.
6. Guardar resultado de la revisión manual. Borrar únicamente evidencias/documentos
   de prueba al terminar; eliminación de usuario queda al creador.

### Inventario de escrituras en HOME

Rutas relativas a XDG_CONFIG_HOME (`~/.config`), salvo indicación. Pacman/CMake no
escriben en HOME. El inventario automático lee solo esta lista y directorios
conocidos, nunca recorre HOME, perfiles de navegador, carteras, `.ssh` ni `.gnupg`.
No es una auditoría de todos los writes de todas las apps Linux abiertas.

| Ruta / escritor | Tratamiento al salir/desinstalar |
| --- | --- |
| `kwinrc` / helper Singlr | Claves transitorias respaldadas antes de aplicar y restauradas al salir; comparar todas las claves. Recuperar pendientes antes de `pacman -R`. |
| `$XDG_STATE_HOME/singlr/kwinrc-backup.json`, `kwinrc.lock` | Journal privado persistente hasta restauración correcta; JSON debe desaparecer, lock vacío puede permanecer sin preferencias. No borrar para ocultar error. |
| `kglobalshortcutsrc` / KGlobalAccel | Cuatro asignaciones temporales `kwin/Window Maximize`, `Window Minimize`, `Window Quick Tile Top`, `Window Quick Tile Bottom` deben volver. Registros de acciones propias de Singlr/Meta conservan preferencias del usuario; revisar diferencias adicionales, no borrar componentes KDE. |
| `$XDG_RUNTIME_DIR/singlr-live/shortcuts-backup.json` y `.lock` | Backup temporal, restaurado por shell al salir; tras SIGKILL usa recuperación/servicio de fallo. Runtime desaparece con sesión de usuario; pérdida prematura se considera fallo si quedaron atajos alterados. |
| `singlr/singlr.conf`, `singlr/dock.json` | Preferencias persistentes (apariencia/fondo, migración, apps fijadas/orden); se conservan con `pacman -R`. No afectan al shell Plasma. Locks temporales de QSettings/migración se limpian al finalizar. |
| `systemd/user/singlr-shell.service.d/dev-channel.conf` / herramienta dev | Solo al activar explícitamente desarrollo; quitar con `disable` antes de desinstalar. Otros drop-ins son propiedad del usuario; no borrarlos. El drop-in de recuperación KWin del **paquete** vive en `/usr/lib/systemd/user`, no HOME; pacman lo elimina. |
| `kdeglobals` / ajustes de apariencia y herramientas KDE | Preferencia compartida y persistente, **sin backup automático**: `[KDE] AutomaticLookAndFeel`, DefaultLight/DarkLookAndFeel, `[General]` ColorScheme, AccentColor, LastUsedCustomAccentColor, accentColorFromWallpaper y grupos Colors de KDE. Cambiar color en Singlr cambia también Plasma por diseño T241. No se promete rollback de esa elección del usuario. Si quedan referencias `dev.singlr.light/dark`, elegir alternativas KDE instaladas antes de quitar el paquete; el auditor falla tras desinstalar si siguen apuntando a paquetes ausentes. |
| `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `xsettingsd/xsettingsd.conf`, `dconf/user` / sincronización KDE | Apariencia de apps elegida por el usuario; se conserva. Cambios dependen de servicios KDE presentes; revisar inventario local. |
| `ksmserverrc`, `session/*`, `klaunchrc`, `kded6rc`, `plasmanotifyrc`, `plasmaparc`, `kcminputrc`, `kxkbrc` / KDE | Guardado/restauración XSMP, servicios y preferencias de notificaciones/entrada solicitadas por usuario; conservación estándar, no se borran al desinstalar. `plasmashellrc` no debe ser escrito para seleccionar shell Singlr; se inventaría para detectar regresión. |
| `$XDG_CACHE_HOME` y `$XDG_STATE_HOME` de Qt/KDE/apps, `$XDG_DATA_HOME` de servicios KDE | Cachés QML/iconos, historial de actividad y estado normal de apps; no los borra pacman. No copiar ni adjuntar contenidos. No hay nuevos daemons ni almacén de credenciales Singlr en T247. |

KWallet/NetworkManager gestionan sus credenciales con mecanismos KDE existentes;
esta batería no inspecciona ni inventaría su contenido. El auditor muestra todos
los cambios dentro del alcance permitido y falla ante restauración de KWin/atajos
incompleta. Los cambios fuera de él se revisan usando un usuario nuevo y el
inventario de servicios; no se afirma que una lista de hashes pruebe HOME entero
intacto. Mantener intacta configuración implica restaurar los ajustes transitorios
y conservar explícitamente preferencias elegidas, no borrar el estado estándar KDE.

## Infraestructura y contrato oficial

`python3 -m unittest discover -s tests/session -v` valida rechazo de escritorio
ajeno, evidencia privada/no sobrescrita, detección de restauración fallida y filtro
de privacidad del diagnóstico. Son dobles de frontera y XDG temporal.

Contratos: [systemd.service](https://www.freedesktop.org/software/systemd/man/261/systemd.service.html)
(reinicios sujetos a límites), [greeter KDE 6.8.1](https://github.com/KDE/kscreenlocker/blob/v6.8.1/greeter/greeterapp.cpp)
(carga QML y fallback seguro), y [libkscreen doctor](https://github.com/KDE/libkscreen/blob/v6.8.1/src/doctor/doctor.cpp)
(configuración estándar de salidas). Contrastar versión instalada antes de ampliar
soporte. No se cambian APIs ni política de KDE.
