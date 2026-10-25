# T239 — contrato y evidencia (Codex 2, sin commit)

Soluciones técnicas derivadas de P-016/P-017; no decisiones visuales nuevas.

## Recuperación

Referencia local comprobada: `plasma-workspace 6.8.1-1`, systemd 262.1-1,
Qt 6.12.0; `/usr/lib/systemd/user/plasma-plasmashell.service`:
`Restart=on-failure`, `StartLimitIntervalSec=60s`, `StartLimitBurst=3`.
Se conserva el retardo por defecto de systemd (100 ms). Son **tres arranques**, incluido
el inicial, dentro de 60 segundos; el cuarto intento queda rechazado. No hay
reintento periódico al terminar la ventana de límite: requiere arranque manual.
La salida 0/SIGTERM gestionado es limpia; SIGSEGV/SIGKILL/salida no cero es fallo.
La parada explícita por logout no reinicia. El shell sigue al target por `PartOf`;
el target ahora solo lo solicita por `Wants`, sin `Requires/BindsTo` inversos.
KWin, ksmserver y las aplicaciones sobreviven a un shell agotado.

Se mantiene `Type=simple`: dos unidades con `BusName=org.kde.plasmashell` no
pueden coexistir en el mismo manager. El proceso adquiere ese nombre de forma
exclusiva y ahora falla si no puede, en vez de ofrecer un escritorio parcial.
El proceso nuevo reconstruye System/SecretAgent/Tray y Session. El bus libera
nombres/objetos al morir la conexión; SNI usa un host por PID y relee el watcher;
los atajos cargan las acciones guardadas y reutilizan el backup KWin previo;
Session instancia sus superficies desde el inventario actual de pantallas.
Esto es inspección de implementación, **no evidencia del recorrido tras SIGSEGV**.

`OnFailure` abre una unidad independiente al llegar al fallo final, restaura los
atajos KWin y muestra un diálogo KDE con recuperación manual y acceso al journal.
La notificación no depende del servidor de notificaciones del shell caído.
`kdialog` es dependencia nueva del PKGBUILD, **no está instalado en este entorno**.
El diálogo debe cerrarse antes de repetir otro ensayo de agotamiento (oneshot).

`SyslogIdentifier=singlr-shell`, stdout/stderr a journal y mensajes de arranque
fallido con categoría `singlr.shell`; mensajes de Qt conservan su categoría.
`journalctl --user -u singlr-shell` incluye errores de QML. No se añade logging
periódico. SIGTERM/SIGINT pasan por socket/notifier en lugar del timer de 100 ms.

Configuración real: `$XDG_CONFIG_HOME/singlr/singlr.conf` (por defecto
`~/.config/singlr/singlr.conf`). Antes de cargar QML se migra de esquema 0 sin
versionar a `Config/schemaVersion=1`, sin cambiar Appearance ni claves desconocidas.
Es idempotente, con escritura atómica de QSettings; errores o versiones futuras
se rechazan sin sobrescribirlas. El modo auxiliar `--restore-shortcuts` no migra.

## Fondo

No hay dos Wallpaper en la sesión: Desktop y Session son modos alternativos;
Session tiene un Background por salida. No se usa el fondo como textura de blur
entre ventanas. La fábrica estándar de Qt conserva un QImage además de la textura
tras subirla: `QQuickDefaultTextureFactory::createTexture` en Qt 6.12.0.
Además, vincular sourceSize a la ventana permite tamaños intermedios durante su
configuración. No se ha podido atribuir cuantitativamente el dato previo de ~16 MB.

Se proporciona el tamaño físico de la salida antes de configurar la ventana y
se desactiva la caché de imágenes antiguas. El proveedor nativo usa APIs públicas
QQuickImageProvider/QQuickTextureFactory: decodifica en worker, respeta EXIF,
recorta al centro conservando proporción y devuelve exactamente ancho × alto de
la salida. Al crear la textura libera el QImage de la fábrica. Si se recrea el
contexto, recarga desde el archivo; `image()` también sigue disponible.
No se usa `QSG_TRANSIENT_IMAGES`, APIs privadas ni un parche a Qt/Plasma.
El backend software puede conservar la representación CPU que necesita para pintar.
La decodificación de formatos sin reducción nativa puede tener un pico transitorio.
Si el archivo desaparece, una recreación posterior del contexto no podrá recargarlo.

Fuentes primarias:
- https://doc.qt.io/qt-6/qquicktexturefactory.html
- https://doc.qt.io/qt-6/qquickimageprovider.html
- https://doc.qt.io/qt-6/qml-qtquick-image.html
- https://raw.githubusercontent.com/qt/qtdeclarative/v6.12.0/src/quick/util/qquickpixmapcache.cpp
- https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html

## Verificaciones y medida

- `python3 -m unittest discover -s tests/shell`: 69 ejecutadas, OK, 3 omitidas por D-Bus privado bloqueado (66 pasadas).
- `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests`:
  128 pasadas, 0 fallos. Incluye geometría de fondo por pantalla y liberación de fuente.
- Prueba nativa: recorte exacto 64×64, ruta con espacios/#/%/Unicode a través del
  proveedor QML real, QImage retenido 16384 → 0 bytes tras crear textura, segunda
  creación y compatibilidad de image(). Render offscreen/software, no medida GPU.
- Migración: configuración nueva, anterior, repetición sin cambios de bytes,
  conservación de ajustes, rechazo de versión futura/inválida. SIGTERM del shell
  nativo probado: código 0 y migración escrita antes de QML.
- `tools/check-cmake.sh`: compilación e instalación DESTDIR pasan, incluida nueva unidad.
- `python3 scripts/check_setup.py`: pasa. `git diff --check`: pasa.
- `systemd-analyze --user verify session/systemd/singlr-{shell.service,shell-failed.service,workspace.target}`:
  bloqueado (exit 1) por restricciones del sandbox sobre sockets SO_PASSRIGHTS/
  SO_PASSCRED; no se presenta como unidad validada por systemd.
- `tools/measure-resources.sh --output /tmp/t239-before` y `--output /tmp/t239-after`:
  ambos bloqueados antes de iniciar shell: dbus-daemon no puede bindear socket privado
  (`Operation not permitted`). Ambos verifican limpieza host `equal=True`. Repetido también con
  `--wallpaper apps/settings/captures/wallpaper-light.png --output /tmp/t239-after-wallpaper`: mismo bloqueo.
  **Sin PSS antes/después y sin ahorro real declarado.** Fuera del sandbox, ejecutar
  ambas revisiones con el mismo archivo de fondo, resolución, backend y configuración.
  La opción nueva --wallpaper siembra solo el INI privado; sin ella el runner usa un
  fondo sólido y no mide el problema de imágenes. El informe incluye ruta y SHA-256:

```bash
tools/measure-resources.sh --wallpaper /ruta/absoluta/fondo.jpg --profile --output /tmp/t239-profile
# Para la comparación principal, sin coste de profiling:
tools/measure-resources.sh --wallpaper /ruta/absoluta/fondo.jpg --output /tmp/t239-baseline-or-after
```

## Procedimiento anidado para Claude (pendiente de ejecutar)

La prueba debe usar bus/Wayland/config privados. No matar el shell de la sesión
habitual ni arrancar los targets instalados para probar en el escritorio anfitrión.
`tools/run-singlr.sh --client none` deja KWin/bus privados vivos sin cliente shell,
y publica session.json con `shell_pid=null`; así el supervisor de pruebas puede
reiniciar su propio proceso sin que el runner cierre KWin al primer fallo.

1. Fuera del sandbox: `tools/run-singlr.sh --client none > /tmp/t239-nested.log 2>&1`.
   Guardar el JSON anunciado por `SINGLR_SESSION_FILE`. Mantener vivo el runner.
2. Crear **copias temporales** en `$XDG_RUNTIME_DIR/systemd/user/` llamadas
   `singlr-t239-shell.service` y `singlr-t239-notice.service` de nuestras dos unidades.
   En la copia del shell retirar Requires/BindsTo/After/Before/PartOf, conservar
   Restart/StartLimit y cambiar OnFailure a la copia notice. ExecStart debe ser
   el binario compilado con rutas absolutas a import `shell/qml` y `Shell.qml`.
   En notice retirar After/PartOf y usar el mismo binario para --restore-shortcuts.
   No modificar ni detener ninguna unidad productiva.
3. Añadir a **ambas copias**, en [Service], `Environment=` con cada par `env` del
   JSON, usando comillas de sintaxis systemd y duplicando `%` como `%%`. Añadir
   `DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent` para que el ensayo gráfico no
   alcance NetworkManager del anfitrión. Sustituir en el texto del aviso los nombres
   de comandos por `singlr-t239-shell`. Requiere kdialog instalado por el paquete.
   El systemctl del operador debe conservar su entorno original para hablar con su
   manager; solo los procesos de las unidades reciben el entorno privado.
4. `systemctl --user daemon-reload` y `systemctl --user start singlr-t239-shell`.
   Desde herramientas con `env` del JSON, registrar propietario de
   org.kde.plasmashell, acciones KGlobalAccel, host e ítems SNI y snapshot KWin
   (helper `kwin_snapshot` de tests/shell/e2e.py). Hacerlo con dos salidas
   (`SINGLR_OUTPUTS=2` al iniciar el runner): un fondo y topbar por salida, un dock.
5. Cronometrar desde `systemctl --user kill --signal=SIGSEGV --kill-whom=main singlr-t239-shell`
   hasta propietario D-Bus nuevo **y** superficies completas: objetivo <3 s, no
   basta con estado active de Type=simple. Verificar acciones funcionales (Meta,
   lanzador, volumen), mismos ítems SNI sin duplicados, ventanas solo del nuevo PID;
   anterior PID ausente. Abrir/cerrar paneles y conectar/desconectar una salida.
   Registrar el tiempo real: el volcado de core puede retrasar la recuperación.
6. Repetir dentro de 60 s hasta que `Result=start-limit-hit`, NRestarts no crezca
   y la copia notice abra exactamente un diálogo. Esperar >60 s: no debe arrancar
   sola. KWin y una aplicación de prueba deben continuar utilizables. Restaurar
   con reset-failed/start manual de la copia. Cerrar notice antes de otro ciclo.
7. `systemctl --user stop singlr-t239-shell` debe dejar estado inactivo limpio sin
   reinicio. Probar además Qt.quit/exit 0. La negociación real de logout/cancelación
   con ksmserver, supervivencia del target y registro NM requieren sesión desechable
   completa: el bus de sistema está excluido deliberadamente del ensayo gráfico.
   Allí repetir fallo manteniendo NM activo y comprobar una sola inscripción de
   `org.singlr.networkmanagement`, más solicitud/cancelación de secreto después
   del reinicio (no registrar contraseñas).
8. Parar ambas copias, retirar sus dos archivos, daemon-reload y reset-failed de
   esos nombres; terminar el runner. Exigir `remaining=[]` y `equal=True` en su log.

La prueba anidada reproduce las directivas de recuperación sin dependencias del
host. La prueba de la unidad/target exactos y logout debe cerrarse en una sesión
Singlr desechable antes de considerar verificada toda la recuperación.

## Validación de Claude (25 oct)
Python 69 OK (con D-Bus real), QML 128/128, `systemd-analyze verify` correcto (solo falta kdialog, que el paquete declara).
KWin anidado con dos salidas, unidad transitoria con la misma política: SIGSEGV → nuevo propietario de
org.kde.plasmashell en 0,83 s con las 48 acciones de atajos registradas, dos veces; al tercer arranque en 60 s
`Result=start-limit-hit`, como `plasma-plasmashell.service` (mismos valores). Pendiente: diálogo de aviso y medida PSS del fondo en la sesión instalada.
