# Sesión Singlr sobre Plasma — T266

La entrada `singlr.desktop` ejecuta un wrapper de entorno mínimo y hace
`exec /usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland`.
No existe supervisor ni target de workspace propio. Si startkderc deshabilita
explícitamente systemdBoot, se rechaza el login con un error claro antes de iniciar
Plasma: la vía clásica no carga la unidad sustituida. No se modifica esa preferencia. Plasma 6.8.1 prepara entorno,
locales, scripts de usuario, systemd, KWin, restauración y cierre. La identidad
`XDG_SESSION_DESKTOP=Singlr` se fija explícitamente: no depende de cómo el greeter
capitalice el nombre de archivo. `DesktopNames=Singlr;KDE;` conserva compatibilidad
con el greeter; startplasma fija `XDG_CURRENT_DESKTOP=KDE`, como Plasma normal.

## Sustitución del shell

Se instala `plasma-plasmashell.service.d/50-singlr.conf`. Solo sustituye ExecStart
por `/usr/lib/singlr/singlr-shell-exec` y añade el aviso de fallo, condicionado a
Singlr. El dispatcher hace exec de `singlr-shell` si la identidad coincide
exactamente y de `/usr/bin/plasmashell --no-respawn` en cualquier otra sesión.
Se conservan Type=dbus, BusName=org.kde.plasmashell, After=ksmserver, PartOf,
Restart=on-failure y los límites oficiales. Una sola unidad posee el nombre D-Bus;
`plasma-core.target` espera su disponibilidad y mantiene la barrera para el resto.
No hay listas propias de servicios ni relaciones BindsTo con ksmserver o el shell.

El nombre de control y diagnóstico **es `plasma-plasmashell.service`**, también en
Singlr. No se instala `singlr-shell.service` ni se habilita/deshabilita nada:

```sh
systemctl --user status plasma-plasmashell.service
journalctl --user -u plasma-plasmashell.service
# Recuperación manual, únicamente en el login de prueba:
systemctl --user reset-failed plasma-plasmashell.service
systemctl --user start plasma-plasmashell.service
```

`SINGLR_DEV_ROOT=/ruta/absoluta/checkout`, recibido del entorno del greeter,
selecciona el binario previamente compilado de `shell/session/build/` y `shell/qml`.
No compila durante el login. Si falta el binario/QML, falla el shell y se aplica
su política de recuperación; no arranca plasmashell como fallback en Singlr.

## KWin, vidrio, splash y bloqueo

La entrada añade `/usr/lib/singlr/xdg` a XDG_CONFIG_DIRS y exporta
`PLASMA_DEFAULT_SHELL=org.singlr.desktop`. Se conservan el splash KSplash, el
paquete KScreenLocker/PAM y el plugin de vidrio. Plasma añade su directorio
kdedefaults y conserva las preferencias explícitas del usuario.

El drop-in de KWin requiere `singlr-kwin-prepare.service`, condicionado a Singlr,
antes del compositor. Su ExecStart aplica la transacción con recuperación del
journal pendiente. Es oneshot con RemainAfterExit y PartOf=graphical-session.target;
ExecStopPost restaura offline después de KWin, también ante fallo parcial de apply.
StopWhenUnneeded evita dejarlo activo si fracasa el arranque del compositor.
La caída del shell no para esta unidad ni restaura preferencias con KWin vivo.

El journal persiste en `$XDG_STATE_HOME/singlr/kwinrc-backup.json`, con escrituras
atómicas, bloqueo y valores originales. Si hay corte de corriente, el próximo
Singlr recupera antes de aplicar y Plasma normal solicita la recuperación offline
existente, opcional, antes de KWin. Una restauración fallida conserva el journal.
No se cambia el criterio fail-open de recuperación al volver a Plasma.

NetworkManager usa el agente de plasma-nm cargado por kded (`networkmanagement`).
El centro de control conserva la lista, conexión y contraseña inicial para redes
nuevas; las peticiones de secretos de perfiles existentes y KWallet son de KDE.
No registra agente ni almacén propio. No se fuerza un módulo que el usuario haya
deshabilitado expresamente: comprobarlo en el login de prueba.

## Instalación y prueba

`tools/check-cmake.sh` compila e instala todo en DESTDIR temporal; verifica payload,
vidrio y despacho Singlr/Plasma sobre los archivos instalados. No instala en el host.
El paquete Arch instala las unidades y drop-ins mediante CMake. Actualizar desde
el paquete anterior retira automáticamente sus unidades obsoletas. No actualizar
con una sesión Singlr abierta: cerrar primero y usar Plasma o TTY.

`session/install.sh --prefix /tmp/staging` y `uninstall.sh` siguen siendo solo
staging de metadatos, con manifiesto y reversión de hashes; no instalan binario,
QML ni dependencias. No mezclar con pacman. Revertir una instalación manual antigua
con su checkout original antes de instalar estos metadatos.

Fuentes, diseño, evidencia y aceptación de login real:
[handoff T266](../docs/handoffs/T266-startplasma.md).
Las baterías históricas de [tests/session](../tests/session/README.md), el modo
`singlr-live` y algunos diagnósticos todavía se refieren al supervisor/target
anterior: no utilizarlos como certificación del nuevo login. El modo live antiguo
descarga networkmanagement y requiere una actualización separada antes de usarlo
con el shell sin agente. Para esta entrega se prueba la sesión del greeter.
No se admiten escritorios simultáneos del mismo UID, igual que con el Plasma base.
