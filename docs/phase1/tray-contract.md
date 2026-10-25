# T222 / T225 — bandeja del sistema y puente de atajos

Implementación técnica derivada del encargo T222; no fija diseño visual. T225 adapta las llamadas de SystemTray y Dock. Qt local: **6.12.0**; KDE StatusNotifierItem **6.31.0**, Plasma
**6.8.1** (24-10-2026). Sin libdbusmenuqt ni QMenu.

## Disponibilidad y modelo

El lanzador expone la propiedad de contexto `SinglrTray` antes de cargar QML,
solo si adquiere `org.kde.plasmashell` y no recibe `--windowed`.
En `--windowed`, `typeof SinglrTray === "undefined"`. También queda ausente si
otro shell posee el nombre. Guardar el acceso con esa comprobación.

`SinglrTray.items` es un `QAbstractListModel` constante como objeto, con avisos
normales de inserción, retirada y `dataChanged`. Cada fila corresponde a
**(service, path)**; `id` no es una clave única. Roles:

| Rol | Tipo y significado |
| --- | --- |
| service | string: nombre D-Bus anunciado por el watcher, a menudo único `:1.N` |
| path | string: objeto SNI; por defecto `/StatusNotifierItem` |
| id | string: Id del cliente |
| title | string: título del cliente |
| category | string: categoría SNI |
| status | string: `Active` o `NeedsAttention`; `Passive` se conserva internamente y se oculta del modelo |
| iconName | string: IconName; AttentionIconName mientras requiere atención si tiene icono de atención |
| iconSource | url: `image://singlrtray/<clave>?v=<revisión>` o URL vacía |
| toolTipTitle | string: título del ToolTip, sin interpretar HTML |
| itemIsMenu | bool: la acción primaria corresponde al menú |
| menuPath | string: objeto DBusMenu; vacío o `/` significa sin menú exportado |
| hasAttentionIcon | bool: el cliente tiene nombre o pixmap válido de atención, independientemente del estado actual |

Preferir el nombre de tema cuando sea resoluble; `iconSource` ofrece el pixmap
como alternativa. El proveedor `singlrtray` se instala en el mismo motor QML.
Selecciona la imagen válida cuyo lado mayor esté más cerca de 32 px (empate:
ancho mayor) y convierte bytes de red **A,R,G,B** a `QImage::Format_ARGB32`
sin premultiplicar. Descarta dimensiones inválidas, lados mayores de 4096 y
longitudes distintas de `width * height * 4`. NeedsAttention usa el par de
atención cuando tiene nombre o pixmap; si ambos faltan, usa el icono normal.
La URL cambia al cambiar los píxeles; la caché guarda solo una imagen por ítem y
se libera al desregistrarlo. Admite peticiones de imágenes desde otros hilos.

Los cambios NewIcon, NewTitle, NewStatus, NewToolTip, NewAttentionIcon y NewMenu
refrescan GetAll de forma asíncrona, agrupando ráfagas sin publicar respuestas
anteriores a una señal. También se atiende PropertiesChanged. Los Passive
siguen suscritos y reaparecen al activarse. Se reconcilian la lista inicial y las
señales Registered/Unregistered; si cambia el dueño del watcher se limpia el
estado, se vuelve a registrar el host y se obtiene otra lista. El servicio
`org.kde.StatusNotifierHost-<pid>` vive hasta terminar el backend. No sustituye al
watcher de kded6.

## Funciones y menús

```qml
SinglrTray.activate(service, path, x, y)
SinglrTray.secondaryActivate(service, path, x, y)
SinglrTray.scroll(service, path, delta, orientation)
SinglrTray.requestMenu(service, menuPath)
// Señales: menuReady(service, menuPath, items), menuFailed(service, menuPath, error)
SinglrTray.activateMenuItem(service, menuPath, id)
```

Las acciones y la petición de menú son asíncronas. `x`, `y` son coordenadas globales
lógicas del gesto; `delta` conserva el signo y la unidad del evento de rueda
(por ejemplo 120). `orientation` admite `"vertical"` o `"horizontal"`.
Solo se envían acciones a ítems registrados. Para ItemIsMenu, QML debe abrir el
menú de datos; no llamar a ContextMenu, que intentaría abrir un menú nativo.

`requestMenu()` llama AboutToShow(0) y después GetLayout(0, -1, []), mediante
QDBusPendingCallWatcher, incluso si AboutToShow falla o no está implementado.
Emite menuReady con los hijos de la raíz invisible:

```js
[{id: 42, label: "Abrir", enabled: true, visible: true,
  type: "standard", toggleType: "", toggleState: -1,
  iconName: "document-open", children: []}]
```

- `type`: `"separator"` o `"standard"`.
- `toggleType`: `""`, `"checkmark"` o `"radio"`; estado -1 indeterminado, 0 apagado, 1 encendido.
- Se retira `_` de mnemónico; `__` representa un guion bajo literal.
- Valores omitidos: enabled/visible true, type standard, toggleState -1 y cadenas vacías.
- Se conservan las entradas invisibles y deshabilitadas: QML debe ocultarlas o impedir su activación.
- `children` conserva la jerarquía. El parser limita profundidad a 64 y nodos a 10000.
- Un error de GetLayout, firma incorrecta o menú desconocido emite `menuFailed`
  con una cadena de error; un layout válido vacío emite `menuReady` con `[]`.
- Se comprueba que el menú siga anunciado y el watcher siga siendo el mismo
  después de cada respuesta. Los watchers se destruyen con el backend.

Cada llamada tiene timeout de 1500 ms sin bloquear el hilo GUI. No hay caché.
`menu()` se conserva **obsoleto** para sondas y consumidores anteriores; esa
ruta mantiene el comportamiento síncrono y puede bloquear hasta unos 3 s.
SystemTray comprueba la existencia de requestMenu antes de usarla, y recurre a
menu solo para el binario anterior hasta que Claude reinicie el modo en vivo.
La superficie abre con una fila «…» deshabilitada; sustituye el contenido al
recibir menuReady y muestra una fila de error deshabilitada con menuFailed.
Se ignoran respuestas si la superficie está cerrada o service/menuPath no
coinciden con la selección actual. No hay identificador por apertura: peticiones
concurrentes del mismo par service/menuPath comparten esa identidad.

`activateMenuItem` envía Event(id, "clicked", variant(int32(0)), timestamp uint32
en milisegundos). La raíz 0 no es activable. Solo acepta objetos de menú
anunciados por ítems actuales. El exportador decide la acción y el nuevo estado.

`menuChanged(service)` se emite en LayoutUpdated, ItemsPropertiesUpdated,
cambio de objeto Menu y desregistro. Puede invalidar varios ítems de un mismo
servicio. La UI debe cerrar o actualizar el menú abierto y verificar que el ítem
siga presente. No hay caché de layouts en C++.

## SinglrSystem (T225)

Propiedad de contexto registrada con la misma condición de modo sesión que
SinglrTray; ausente en windowed o si otro shell posee org.kde.plasmashell.

- `invokeShortcut(component, action)` envía asíncronamente `action` a
  `org.kde.kglobalaccel /component/<component> org.kde.kglobalaccel.Component.invokeShortcut`.
  Component admite letras ASCII, dígitos y `_`; se ignoran componentes inválidos
  y acciones vacías. Errores D-Bus se registran sin bloquear la UI.
- `overviewAvailable` empieza en false. Al arrancar y cada 10 s consulta
  `org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded("singlr-overview")`.
  Usa QDBusPendingCallWatcher y timeout 1500 ms, sin solapar consultas. Una respuesta
  falsa o error deja false; overviewAvailableChanged se emite solo al cambiar.
- Dock muestra Multitarea solo cuando el puente y el efecto están disponibles,
  e invoca `invokeShortcut("kwin", "Singlr Overview")`.

Firmas comprobadas en los XML locales
`/usr/share/dbus-1/interfaces/org.kde.kwin.Effects.xml` y
`kf6_org.kde.kglobalaccel.Component.xml`. Patrón de asincronía contrastado con
[QDBusPendingCallWatcher, Qt 6.12](https://doc.qt.io/qt-6/qdbuspendingcallwatcher.html).
No se reinicia ni se modifica la sesión KDE durante las verificaciones.

## Verificación T225

- `shell/session/build.sh`: correcto; único aviso previo de useLayerShell obsoleto.
- `python3 -m unittest discover -s tests/shell -p 'test_*.py' -v`: **31 pruebas,
  30 correctas y 1 omitida** (bus privado no disponible).
- `qmltestrunner -import shell/qml -input shell/qml/tests`, offscreen/software:
  **91 passed, 0 failed**. Incluye backend anterior, carga asíncrona, rechazo de
  respuestas de otro menú/cerrado, errores y visibilidad/activación de Multitarea.
- `qmllint` de los QML adaptados, sus pruebas y TrayProbe: correcto sin avisos.
- `check_setup.py` y `git diff --check`: correctos.
- El fixture C++ de bus privado añade AboutToShow no implementado, GetLayout
  válido/erróneo/firma inválida/demorado con evento GUI intermedio, consulta inicial
  de efecto, polling a false y firma de invokeShortcut. Su ejecución queda
  pendiente fuera del sandbox, que deniega la creación del socket D-Bus.
- La sonda windowed comprueba ausencia tanto de SinglrTray como de SinglrSystem.
- No se ha reiniciado el modo en vivo: Claude debe reiniciarlo para cargar el
  nuevo binario y verificar el efecto real y los menús de aplicaciones reales.

## Comprobaciones T222 y comandos para Claude

Desde este worktree, sin commit:

```bash
shell/session/build.sh
python3 -m unittest discover -s tests/shell -p 'test_tray.py' -v
python3 -m unittest discover -s tests/shell -p 'test_*.py' -v
python3 scripts/check_setup.py
```

Resultado del sandbox: compilación correcta (solo el aviso previo de
`LayerShellQt::Shell::useLayerShell()` obsoleto); suite general **31 pruebas,
30 correctas y 1 omitida**. Tras ajustar las suscripciones a señales, se repitió
la suite T222: **3 correctas y 1 omitida**. `qmllint` de la sonda,
`check_setup.py` y `git diff --check` correctos. Se aisló también el mock de
KWin en `test_live_secrets.py`, que podía acceder al backup de la sesión real.

Las pruebas puras cubren canales/alpha/endianness, tamaño y pixmaps inválidos,
filtrado del modelo, cambios de filas y proveedor de imágenes. Otra prueba carga
el lanzador real con la sonda QML en offscreen y comprueba ausencia en windowed.

El test `wire` usa un proceso exportador simulado y un **bus privado**, mediante
APIs públicas Qt. Así los fixtures `(ia{sv}av)`, `a(iiay)` y `(sa(iiay)ss)` pasan
por serialización D-Bus y llegan al parser como `QDBusArgument` reales. También
comprueba host, modelo inicial/Passive/atención, señales, acciones, orden
AboutToShow/GetLayout, Event, altas/bajas y reinicio del watcher. No toca kded6.
En el sandbox no se puede abrir el socket de ese bus y ese test se omite;
**parser por D-Bus e integración real pendientes fuera del sandbox**.

Fuera del sandbox, exigir que el test de bus se ejecute (que no quede omitido):

```bash
cd /home/sunw/Projects/singlr
SINGLR_REQUIRE_TRAY_DBUS=1 python3 -m unittest discover -s tests/shell -p 'test_tray.py' -v
```

### Aplicación real en la sesión Wayland

Abrir primero una aplicación instalada que anuncie un SNI no Passive y exporte
DBusMenu; por ejemplo KeePassXC con su icono de bandeja habilitado. No se instala
ninguna aplicación desde este encargo. Anotar su identificador desde:

```bash
qdbus6 org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher.RegisteredStatusNotifierItems
```

La sonda `tests/shell/TrayProbe.qml` carga el backend del **lanzador real** y
registra TRAY_ITEM, TRAY_IMAGE_READY, TRAY_MENU y TRAY_MENU_CHANGED. No dibuja la
bandeja definitiva ni sus menús. Ejecutar en una terminal de la sesión Wayland;
la siguiente prueba retira temporalmente los paneles y restaura Plasma al salir.
Si estaba activo el supervisor Singlr, detenerlo primero para evitar recargas:

```bash
tools/singlr-live.sh stop
(
    set -euo pipefail
    tray_plasma_was_active=$(systemctl --user is-active plasma-plasmashell.service || true)
    tray_nm_was_loaded=$(qdbus6 org.kde.kded6 /kded org.kde.kded6.loadedModules | rg -x networkmanagement || true)
    tray_restore() {
        if [ "$tray_nm_was_loaded" = networkmanagement ]; then
            qdbus6 org.kde.kded6 /kded org.kde.kded6.loadModule networkmanagement
        fi
        if [ "$tray_plasma_was_active" = active ]; then
            systemctl --user start plasma-plasmashell.service
        fi
    }
    trap tray_restore EXIT
    if [ "$tray_nm_was_loaded" = networkmanagement ]; then
        qdbus6 org.kde.kded6 /kded org.kde.kded6.unloadModule networkmanagement
    fi
    if [ "$tray_plasma_was_active" = active ]; then
        systemctl --user stop plasma-plasmashell.service
    fi
    QT_FORCE_STDERR_LOGGING=1 shell/session/qml-shell "$PWD/tests/shell/TrayProbe.qml" -- --tray-seconds=20 2>&1 | tee /tmp/singlr-t222-tray.log
)
```

Esperado: TRAY_ITEM con service/path correctos y sin Passive; iconName o pixmap
utilizable; TRAY_MENU con etiquetas legibles, separadores y jerarquía; salida
TRAY_PROBE_DONE con al menos una fila. Una app basada solo en nombres de tema no
produce TRAY_IMAGE_READY: no es un fallo. Mientras corre la sonda, cambiar un
estado del cliente y comprobar otro TRAY_ITEM/TRAY_MENU_CHANGED. Cerrar el cliente
debe retirar la fila; volver a abrirlo debe reincorporarla.

Para comprobar una acción explícita, repetir el bloque anterior añadiendo al
comando `qml-shell` estos argumentos después de `--`, con service e id reales
obtenidos del log (elegir una acción inocua del menú):

```bash
--tray-service=:1.123 --tray-action=menu --tray-menu-id=42
# O, en pasadas separadas:
--tray-service=:1.123 --tray-action=activate
--tray-service=:1.123 --tray-action=secondary
--tray-service=:1.123 --tray-action=scroll
```

La sonda envía solo una acción por pasada; no comprueba su efecto por sí misma.
Verificar el comportamiento en la app. Para reanudar el shell habitual Singlr:
`tools/singlr-live.sh start`. La UI definitiva de ContextMenu y su interacción
quedan para Codex 1 y la revisión visual del creador.

## Fuentes y límites

Firmas contrastadas con `/usr/share/dbus-1/interfaces/kf6_org.kde.StatusNotifierWatcher.xml`,
`kf6_org.kde.StatusNotifierItem.xml` y el adaptador DBusMenu Qt 6.12 instalado.
Referencias primarias:

- [XML SNI de KDE](https://github.com/KDE/kstatusnotifieritem/blob/master/src/org.kde.StatusNotifierItem.xml).
- [Parser/serializador DBusMenu de Qt](https://github.com/qt/qtbase/blob/dev/src/gui/platform/unix/dbusmenu/qdbusmenutypes.cpp).
- [QDBusArgument](https://doc.qt.io/qt-6/qdbusargument.html).

No se implementan OverlayIcon, AttentionMovie, iconos binarios de DBusMenu,
IconThemePath privado del cliente, submenús que exijan AboutToShow por cada id,
ni tokens de activación Wayland. Las acciones se envían sin token: el compositor
puede impedir que una app tome foco. No se garantiza bandeja XEmbed heredada.
Los fallos D-Bus se registran y no abren QMenu ni otro menú nativo.
