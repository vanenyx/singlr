# T202 — sesión real aislada (solución técnica derivada)

Desde la raíz del checkout:

```bash
tools/run-singlr.sh                         # 2048×1280, Shell.qml
tools/run-singlr.sh --size 1600x1000 --entry tests/shell/Probe.qml
# Otra terminal, mientras viva una única sesión:
tools/capture-session.sh /tmp/singlr-session.png
# Con varias sesiones, seleccionar el JSON anunciado por el lanzador:
SINGLR_SESSION_FILE=/tmp/singlr-session-XXXX/session.json tools/capture-session.sh /tmp/singlr-session.png
```

`session-runtime.py` reutiliza el entorno XDG y el cierre de grupos de
`prototype-runtime.py`, y el bootstrap de bus de `nested-session.sh`.
Ejecuta KWin en ventana con bus privado, runtime/socket y config/datos/estado/caché
temporales. Conserva las aplicaciones y los imports del sistema. No inicia
plasmashell, systemd de usuario, KActivities, bloqueo ni atajos globales.
Elimina DISPLAY para evitar que una app X11 termine en el escritorio anfitrión;
este incremento ejecuta clientes Wayland, no inicia Xwayland.

El envoltorio `qml-shell` ejecuta `qml6 -I shell/qml <entrada>`.
LayerShellQt configura cada ventana con attached properties; no se exporta
`QT_WAYLAND_SHELL_INTEGRATION=layer-shell` a aplicaciones hijas. Milou/KIO y las
activaciones D-Bus reciben el display anidado y los XDG temporales. Se fuerza
`_KDE_APPLICATIONS_AS_FORKING=1` para evitar delegar lanzamientos al systemd del
usuario. El controlador Linux es subreaper: adopta y termina también apps que
se separan del grupo con setsid/doble fork. Al cerrar el shell, KWin, Ctrl+C o
SIGTERM, limpia descendientes y temporales. SIGKILL al supervisor no permite
esta garantía. No es un aislamiento para ejecutar aplicaciones no confiables.

Cada ejecución compara SHA-256 de los archivos k*/plasma* del directorio de
configuración anfitrión antes/después y anuncia `SINGLR_HOST_CONFIG ... equal=True`.
Los cambios concurrentes de la sesión anfitriona también se comunicarán como
diferencias: no se restaura ni se escribe esa configuración.

## Permisos reales, versiones y fuentes

Inventario del 24-10-2026: KWin/LayerShellQt/Milou/Plasma Workspace 6.8.1,
Qt Declarative 6.12.0, KIO 6.31.0, Spectacle 6.8.1.

En [KWin v6.8.1, KWinDisplay::allowInterface](https://github.com/KDE/kwin/blob/v6.8.1/src/wayland_server.cpp#L120-L158),
`org_kde_plasma_window_management` se deniega a clientes clasificados como
sandboxed; para clientes nativos ordinarios se permite. `zwlr_layer_shell_v1`
no está en esa lista. Esta versión no consulta `X-KDE-Wayland-Interfaces` para
autorizar esos dos protocolos. Por ello no se instala un .desktop ni se desactiva
seguridad de KWin. La sonda debe comprobar la negociación real fuera del sandbox.

Corroboración local: `/usr/lib/libkwin.so.6.8.1` no contiene la cadena
`X-KDE-Wayland-Interfaces`. Los .desktop de otras aplicaciones aún pueden llevarla;
su presencia no prueba que esta versión la use. No se extrapola a KWin anterior.

[ScreenShot2 v6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/plugins/screenshot/screenshotdbusinterface2.cpp)
publica `org.kde.KWin.ScreenShot2` en `/org/kde/KWin/ScreenShot2`, versión 5.
`CaptureWorkspace` devuelve metadatos y píxeles crudos por descriptor Unix; una
llamada gdbus sin ese transporte no produce PNG. Se reutiliza Spectacle
`-b -n -f -o` sobre el bus privado para capturar la salida completa del compositor,
incluidas las ventanas de apps. `grim` no está disponible. Esta vía aún requiere
la prueba real de captura.

Los attached properties `anchors`, `layer`, `scope`, `exclusionZone` e interacción
de teclado se contrastaron con `LayerShellQtQml.qmltypes` y los headers locales
6.8.1. `Shell::useLayerShell` figura como innecesario desde Qt 6.5 en
`/usr/include/LayerShellQt/shell.h`. TasksModel usa `AppId`, `IsWindow` e `IsMapped`
según los headers y qmltypes locales. Milou usa `ResultsModel.run(QModelIndex)`.
La sonda limita la búsqueda al plugin instalado `krunner_services.so`; su ID se
deriva del nombre del binario según `KPluginMetaData::pluginId()` de KF6 local.

## Verificación fuera del sandbox, a ejecutar por Claude

```bash
cd /home/sunw/Projects/singlr-worktrees/codex-2
command -v konsole
python3 tests/shell/verify-session.py --evidence /tmp/singlr-t202-evidence
# Tras integrar los QML de Codex 1:
tools/check-shell.sh --output /tmp/singlr-shell-windowed.png
tools/run-singlr.sh --size 2048x1280
```

**Bloqueo local adicional:** `command -v konsole` no devuelve ruta,
`pacman -Q konsole` informa paquete ausente y no hay .desktop/servicio Konsole
bajo `/usr/share`. Paquete contrastado: [Arch extra/konsole](https://archlinux.org/packages/extra/x86_64/konsole/).
No se instaló. El verificador falla con ese diagnóstico hasta que el entorno
externo tenga Konsole disponible; resolver la dependencia queda con Claude/creador.

El verificador inicia la sonda con WAYLAND_DEBUG solo en el cliente, espera
`get_layer_surface`, anuncio de window-management, primer frame, resultados
Milou, ejecución y Konsole con `IsWindow` + `IsMapped` en TasksModel.
Luego captura con Spectacle, termina el supervisor por SIGTERM, compara hashes y
busca procesos residuales por el identificador único de sesión en `/proc`.
No usa PID del host ni mata procesos preexistentes. La lectura de `/proc` queda
limitada por los permisos del usuario.

Artefactos: `session.log`, `session.png`, `config-before.json`, `config-after.json`.
Claude debe inspeccionar el PNG: panel anclado arriba y Konsole real debajo,
además de confirmar `T202 PASS`, hashes iguales y residual vacío. Ningún resultado
headless sustituye esta revisión visual. Si falla, devolver `session.log` completo.

`tools/check-shell.sh` hace qmllint con ambos import paths, y carga `Shell.qml --
--windowed --capture=<png>` offscreen con bus deshabilitado/XDG propios. Timeout
de 20 s y error si no hay PNG nuevo. No prueba servicios ni interacción.
La fixture `WindowedFixture.qml` solo comprueba el transporte de ese contrato.

## Evidencia ya ejecutada

Ver `tools/evidence/t202.txt`. Seis pruebas headless con compositor/bus simulados
verifican argumentos, fallos, propagación de entorno y limpieza normal/SIGTERM,
incluido un descendiente con setsid. Lint de la sonda y captura de la fixture:
PASS. Regresión de captura del runtime anterior: PASS con backend software.
`check_setup.py`: PASS; no acredita escritorio.

El intento real de arranque fue bloqueado al crear el bus privado:
`Failed to bind socket ... Operation not permitted` (exit 127).
Los 27 archivos de configuración conservaron sus hashes y no quedaron hijos.
`Shell.qml` aún no existe aquí: check-shell retorna 2 con diagnóstico claro.
No se ha generado una captura de sesión real ni verificado Milou/TasksModel en
KWin real. La aceptación de integración permanece pendiente.
