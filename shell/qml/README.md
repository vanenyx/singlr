# T212 — Audio, multimedia, OSD y centro de control

Encargo explícito del creador; cambios propios solo en `shell/qml/**`, sin
commit. `Session.globalAction(component, name)` y `Session.osdRequest(method,
args)` cumplen el contrato con el lanzador C++ de Claude.

- Audio real con `Volume.PreferredDevice.sink/source`: pasos de 5 %/1 %,
  límite 0–100 %, silencio de salida y micrófono y OSD tras cada operación.
  Dispositivos sin volumen escribible no se modifican.
- `Mpris2Model.currentPlayer`, respetando capacidades: Play/Pause/PlayPause,
  Stop/Next/Previous, Seek ±5 s (microsegundos MPRIS), volumen del reproductor.
- OSD independiente Overlay, 240×44, sin entrada, foco ni zona exclusiva,
  `transientParent: null`, `singlrBlur`/radio 12, entrada/salida 120 ms y
  caducidad reiniciable de 1,5 s. Traduce brillo de pantalla/teclado, audio,
  micrófono, reproductor, conectividad, distribución de teclado, escritorio,
  perfil energético, inhibición y texto; miembros desconocidos se ignoran.
- Los indicadores de red, volumen y batería abren el centro de control de
  340 px bajo la barra a la derecha. Layer-shell Overlay OnDemand únicamente
  mientras se abre; Esc, pérdida de activación o clic en el fondo lo cierran.
  No se añade una superficie de entrada que cubra las aplicaciones.
- NetworkManager: activar Wi-Fi, conexión actual, redes desplegables,
  conexiones guardadas y nuevas redes abiertas/OWE o con contraseña
  WEP/WPA/WPA2/WPA3 personal mediante `Handler`. Escaneo al abrir y cada 15 s
  mientras permanece abierto; errores de activación visibles.
- BluezQt: activar adaptadores y conectar/desconectar dispositivos emparejados.
  Audio: deslizadores de salida/micrófono y selección del dispositivo por defecto.
  Brillo por pantalla desde `ScreenBrightnessControl.displays`; batería desde
  `BatteryControlModel`, perfiles reales desde `PowerProfilesControl`.
  No molestar usa la misma instancia de NotificationCenter. Configuración
  se lanza desde `Kicker.SimpleFavoritesModel` con `systemsettings.desktop`.

**Límites deliberados:** la configuración empresarial EAP/certificados y el
emparejamiento de dispositivos nuevos quedan en Configuración del sistema.
Sin adaptadores Bluetooth, salidas/fuentes de audio, pantallas regulables,
batería interna o perfiles disponibles, los respectivos controles se omiten.
No hay datos de demostración en estos componentes. La integración conserva
el alcance de pantalla predeterminada del shell. La lista de redes procede
del modelo real; no se declara que un intento de conexión haya tenido éxito.

Contratos contrastados con qmltypes/bibliotecas locales de Plasma 6.8.1,
Qt 6.12.0 y KF6PulseAudioQt 1.9.0. El applet de volumen no está instalado en
`/usr/share/plasma/plasmoids/org.kde.plasma.volume/`.
Referencias oficiales: [contrato OSD de KDE](https://github.com/KDE/plasma-workspace/blob/master/shell/osd.h),
[unidades y capacidades MPRIS](https://specifications.freedesktop.org/mpris/latest/Player_Interface.html).
La selección de salida usa los roles `PulseObject`/`Default` de PulseAudioQt;
brillo usa `displayName`, `label`, `brightness`, `maxBrightness` del modelo local.

**Verificado:** lint completo sin avisos (exit 0, comando inferior);
qmltestrunner offscreen/software **54 passed / 0 failed**, incluyendo pasos,
límites, silencio, separación del micrófono, capacidades multimedia, Seek,
reinicio/caducidad del OSD y carga/Esc del panel. Captura offscreen inspeccionada
en `/tmp/t212-preview.png` (servicios no accesibles: muestra su ausencia real).
El log vivo registra recargas hasta las 15:06 sin errores QML nuevos; permanece
el aviso previo del portal sobre `singlr-shell`.
El sandbox deniega el bus de sesión (`busctl --user status
org.kde.Solid.PowerManagement`: Operation not permitted), PulseAudio, UPower,
brillo y rfkill. Pendientes de prueba física: teclas globales con el nuevo
lanzador C++, dispositivos/redes reales, blur, clic fuera y devolución de foco
entre aplicaciones en KWin. El lint y los dobles de las pruebas no acreditan
esas operaciones.

```bash
/usr/lib/qt6/bin/qmllint -I shell/qml -i shell/qml/Singlr/Ui/qmldir \
  shell/qml/Shell.qml shell/qml/Singlr/Ui/*.qml \
  shell/qml/Singlr/Shell/*.qml shell/qml/tests/*.qml
XDG_CACHE_HOME=/tmp/singlr-t203-cache QT_QPA_PLATFORM=offscreen \
QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
  /usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests
```

---

# T210 — Notificaciones del sistema

Implementación del encargo explícito del creador, limitada a `shell/qml/**`, sin
commit. `NotificationsBackend` usa los roles y métodos del qmltypes instalado de
NotificationManager (Plasma Workspace 6.8.1, Qt 6.12.0). Crear `Notifications`
inicializa el servidor: [fuente oficial 6.8](https://github.com/KDE/plasma-workspace/blob/Plasma/6.8/libnotificationmanager/notificationsmodel.cpp).
`Server.init()` no está expuesto a QML en esta versión. La inhibición usa
`Server.inhibited`, como [Plasma 6.8](https://github.com/KDE/plasma-workspace/blob/Plasma/6.8/applets/notifications/global/Globals.qml).

Emergentes de 360 px en Overlay independiente, sin padre transitorio, teclado ni
zona exclusiva. `singlrBlur` aprovecha el soporte C++ existente. Máximo tres
visibles, resto en cola; tiempos positivos del emisor, 5 s para el predeterminado,
0 persistente y críticas sin caducidad. Se detiene el timeout interno de KDE y el
shell administra el tiempo visible y la pausa por hover. Caducar conserva el
historial; × descarta. Acciones y acción predeterminada resuelven nuevamente el
índice por id antes de invocar KDE. El historial se agrupa por aplicación e incluye
borrado total, inhibición y marca de lectura al abrir. La campana solo muestra el
punto si hay sin leer. `--windowed` crea un backend de demostración independiente;
no instancia el modelo ni el singleton servidor de KDE.

Verificado: qmllint completo sin avisos, qmltestrunner offscreen/software **47
passed, 0 failed** (9 checks de notificaciones, incluyendo init/cleanup). Se
revisaron las capturas `/tmp/t210-demo.png` y `/tmp/t210-history.png`. El log vivo
`/run/user/1000/singlr-live/shell.log` confirma `NOTIFICATIONS_SERVER valid=true`
tras recargar, sin errores QML; persiste el aviso previo del portal sobre el ID
de aplicación. `notify-send "Singlr" "Prueba de notificación" -a Singlr` no pudo
conectar al bus del escritorio (`Operation not permitted` del sandbox). También
se bloqueó crear un bus con `dbus-run-session`; no se intentó sortear el sandbox.
Pendiente: recepción visible real, acciones D-Bus y blur sobre ventanas reales.

Los comandos de lint y suite se conservan más abajo. El historial es de sesión,
sin persistencia en disco. Alcance de pantalla: la predeterminada, como el shell.

---

# T209 — Ciclo fiable del dock (P-009)

Sustituye el comportamiento T208: app inactiva → solo la ventana con mayor
`LastActivated` (sin fechas, primer hijo actual); app activa → siguiente id en
orden lexicográfico y cíclico. Una ventana activa no recibe ninguna acción.
Nunca minimiza. Menú contextual, clic central y rueda conservan su comportamiento.

Cada clic relee los hijos con `rowCount`/`makeModelIndex` y resuelve de nuevo el
índice por `WinIdList` inmediatamente antes de activar. Solo guarda ids, incluidos
UUID Wayland. Una petición pendiente por app sirve de referencia mientras
`IsActive` se retrasa; se descarta al confirmarse o desaparecer la ventana.
`Dock.cycleApp(appId)` busca el `AppId` (también admite la URL de lanzador) y usa
la misma función que el clic; devuelve false si no encuentra la app.

Verificado con Qt 6.12.0 / Plasma Workspace 6.8.1 y contratos de roles en el
qmltypes instalado y la fuente oficial enlazada en T208. `qmllint` con los imports
del comando inferior: exit 0, sin avisos. Suite offscreen/software completa:
**38 passed, 0 failed**. El doble reordena los hijos tras cada activación y prueba
ciclos completos, UUID, `IsActive` retrasado, foco externo tras confirmación,
ventana pendiente eliminada, minimizadas y grupo reducido a una ventana.
Registro vivo seguido con `tail -F`: recargas sin errores QML; persiste el aviso
previo del portal (`App info not found for 'singlr-shell'`). Pendiente: prueba real
de varias ventanas en KWin anidado por Claude mediante `cycleApp`.

---

# T208 — Dock según P-008

Decisión explícita del creador: clic trae las ventanas no minimizadas de la app,
de antigua a reciente; si todas están minimizadas, activa/restaura solo la última.
Nunca minimiza. Sin ciclo por clics ni rueda; clic central conserva nueva ventana.
Menú con títulos, marca activa, separadores, nueva ventana, fijación y «Salir»
(solicita cerrar todas las ventanas). Tooltip solo con nombre de app.

Solución técnica derivada: `LastActivated` comprobado en
`/usr/lib/qt6/qml/org/kde/taskmanager/taskmanager.qmltypes`, Plasma Workspace
6.8.1 / Qt 6.12.0. KDE documenta el rol como
[timestamp de la última activación](https://github.com/KDE/plasma-workspace/blob/master/libtaskmanager/abstracttasksmodel.h).
Si el backend no entrega fechas, se usa el historial observado por identidad de
ventana. Cada petición resuelve de nuevo el índice; la secuencia parte de una
instantánea para soportar reordenamientos del modelo. No se modifica Session.qml:
la ventana del dock conserva tamaño y visibilidad durante el clic.

Verificado T208: qmllint sobre todo el QML, exit 0 sin avisos; qmltestrunner
con los comandos offscreen/software documentados abajo: **33 passed, 0 failed**.
Incluye reordenamiento por activación, clic repetido, ventanas minimizadas,
historial alternativo, cierre de todas, menú/teclado, tooltip y rueda sin acciones.
Preview nativo del menú revisado en `/tmp/singlr-t208-menu.png`.
Registro vivo seguido con `tail -F`: recargas sin errores QML; persiste el aviso
de registro del portal (`App info not found for 'singlr-shell'`).
Pendiente: comprobar parpadeo visible al activar varias ventanas en KWin real;
si se reproduce, el encargo permite activar solo la más reciente.

---

# T205 — Pulido Linear (propuesta para revisión)

Solo `shell/qml/**`, sin commit. Barra de 28 px con nombre activo obtenido de los
roles de TasksModel; estado y búsqueda a la derecha. Dock de 48 px, iconos de
32 px separados 6 px, padding 8, sin etiquetas y a 10 px del borde. Fijaciones y
ventanas no fijadas se presentan en grupos conservando los índices originales
para clic y menú. Tooltip de 12 px, escalas 1.1/0.94 y puntos de actividad de 4 px.
Lanzador y catálogo comparten texto de 13 px, filas de 36 e iconos de 20.

Las ventanas de barra y dock declaran `singlrBlur: true`, radios 0/14 y geometría
sin márgenes transparentes. Todos los popups usan `Popup.Item`. En sesión, los menús se alojan en ventanas
layer-shell Top de tamaño justo, sin zona exclusiva y con teclado OnDemand.
El tooltip es una escena propia en una ventana sin entrada ni teclado. Estas
superficies solo se muestran mientras se usan; el dock conserva sus 48 px.
Los menús se cierran con Esc o al perder activación; el fondo también los cierra
al pulsar. En preview se conservan dentro de la escena del escritorio. Toda Window explícita
conserva `transientParent: null`. KRunner sigue recibiendo la consulta desde Timer.
El contrato de blur queda preparado para C++ de Claude; este cambio no implementa
el desenfoque de KWin. RectangularShadow aporta sombra de 24 px desplazada 8 px en
preview con RHI; software la omite. En sesión, el tamaño exacto de la Window recorta
la sombra exterior: para conservarla se necesita sombra del compositor en C++.
APIs contrastadas con Qt 6.12 local y documentación oficial de
[Popup](https://doc.qt.io/qt-6/qml-qtquick-controls-popup.html) y los qmltypes instalados
de QtQuick.Effects, TaskManager y LayerShellQt.

Verificación T205: `qmllint -W 0` con los imports del comando inferior, exit 0 sin
advertencias. `qmltestrunner` con el entorno offscreen/software inferior: **16
passed, 0 failed**, incluidos cambio de app activa, separación de grupos, tamaño
estable al abrir menú, navegación y despacho de acciones. Las tres capturas de
`captures/` se regeneraron con `--windowed --capture` y `--applications --capture=…`
y se revisaron visualmente a 2048×1280. Catálogo: 30 aplicaciones. Sin errores QML;
persisten avisos de servicios restringidos y algunos iconos de apps no resueltos
en offscreen. Blur, sombra exterior, popups y dispositivos reales pendientes de
verificación en KWin anidado. Las cifras visuales siguen siendo propuesta T205.

---

# Shell QML — T203 / H3 Día 1

Cambios limitados a `shell/qml/**`, sin commit. Soluciones técnicas derivadas del
encargo; la composición y los tokens de T201 se conservan como propuesta visual.

Desde la raíz, para desarrollo:

```bash
qml6 -I shell/qml shell/qml/Shell.qml -- --windowed
qml6 -I shell/qml shell/qml/Shell.qml -- --windowed --applications
```

**Sesión real:** usar `tools/run-singlr.sh`, que ejecuta el binario C++
`shell/session/qml-shell`. No iniciar el modo sesión con `qml6`. Todas las ventanas
conservan `transientParent: null`. No se asigna ninguna consulta de Milou desde
`Component.onCompleted`: la consulta inicial de captura llega desde un Timer.

## Qué es real

- **Todas las aplicaciones:** botón de cuadrícula en el dock y botón del pie del
  lanzador. `Kicker.RootModel` con `showAllApps`, sin recientes, favoritos ni acciones
  de sesión; se usa su hijo de aplicaciones, no sus categorías. `AppsModel` directo
  devuelve vacío sin appletInterface en esta versión. `KSortFilterProxyModel` filtra
  el nombre sin distinguir mayúsculas; el catálogo respeta las entradas XDG visibles
  de KDE, incluidas las de usuario/Flatpak que KDE descubra. Se verificaron 30 apps
  reales aquí. Arriba/abajo recorre la lista, Enter llama `trigger(row,"",null)`
  sobre la fila original y Esc cierra. El botón «Búsqueda general» vuelve a KRunner.
  La aceptación de un trabajo KIO no garantiza que la aplicación termine de abrir.
- **Búsqueda general:** Milou/KRunner busca aplicaciones, archivos y comandos.
  Consulta vacía muestra una orientación y acceso al catálogo, sin datos de muestra.
  «Buscando…» refleja `querying`; después se muestra «Sin resultados» si corresponde.
  Ctrl+K, botones y Enter despachan exclusivamente `actions`/`runAction(index,n)`
  reales del resultado; si no hay acciones, no se ofrece el panel. Esc cierra
  primero las acciones y luego el lanzador. Al abrir el overlay se solicita
  activación y se repone el foco en la siguiente vuelta del bucle de eventos.
- **Dock:** `TasksModel`, orden manual estable, ventanas sin agrupación y lanzadores
  en su posición. Las ventanas muestran indicador y estado activo. Clic lanza una
  fijación, activa una ventana o minimiza la activa si admite minimizarse.
  Clic derecho o tecla Menú abre «Abrir nueva ventana» y «Cerrar», habilitados según
  `IsNewInstanceable`/`IsLauncher` e `IsClosable`. Cancelar/Esc cierra el menú.
  Se invalida el menú al eliminar filas, reordenar o reiniciar el modelo.
  Las fijaciones siguen siendo Dolphin, Konsole, Firefox, Kate y System Settings
  solo cuando existen en `/usr/share/applications`; no se añaden apps ficticias.
- **TopBar:** fecha/hora con `Qt.locale("es_ES")`, menú Singlr → Salir que termina
  únicamente el proceso del shell. Indicadores informativos, sin controles falsos:
  batería desde `BatteryControlModel` si hay batería interna/cumulativa; volumen y
  silencio del sink de `PreferredDevice`; icono de red desde `ConnectionIcon` si
  `NetworkStatus` tiene conectividad conocida. Sin dispositivo/datos se ocultan.
  Los tres módulos cargan fuera de plasmashell; el sandbox bloquea sus servicios,
  por lo que aquí no se verifica su actualización con hardware real. No hay valores
  de reserva ni se interpreta ausencia del servicio como batería/volumen cero.
- **Material:** en sesión, superficie oscura translúcida de alta opacidad y sin
  captura de ventanas externas. En modo ventana, `Glass` conserva MultiEffect con
  backdrop del mismo árbol y alternativa opaca para software. No se declara blur
  del compositor. Meta+Espacio/Alt+Espacio requieren foco en el shell; no son atajos
  globales de KWin. Alcance: pantalla predeterminada.

## Evidencia y comprobaciones ejecutadas

Qt 6.12.0, Plasma Workspace/Desktop/PA/NM y LayerShellQt 6.8.1, KItemModels 6.31.0
(`pacman -Q`). Contratos comprobados en los qmltypes instalados de kicker, Milou,
taskmanager, battery, volume, networkmanagement y kitemmodels. Fuentes oficiales:
[catálogo y refresco de KDE](https://github.com/KDE/plasma-workspace/blob/master/applets/kicker/rootmodel.cpp),
[lanzamiento KIO](https://github.com/KDE/plasma-workspace/blob/master/applets/kicker/appentry.cpp),
[audio preferido](https://github.com/KDE/plasma-pa/blob/master/src/preferreddevice.cpp),
[fecha localizada de Qt](https://doc.qt.io/qt-6/qml-qtqml-date.html).

```bash
/usr/lib/qt6/bin/qmllint -W 0 -I shell/qml \
  -i shell/qml/Singlr/Ui/qmldir shell/qml/Shell.qml \
  shell/qml/Singlr/Ui/*.qml shell/qml/Singlr/Shell/*.qml shell/qml/tests/*.qml
# exit 0, sin advertencias.

# Cache escribible para sycoca dentro del sandbox; no cambia configuración KDE.
mkdir -p /tmp/singlr-t203-cache
XDG_CACHE_HOME=/tmp/singlr-t203-cache \
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
  /usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests
# 15 passed, 0 failed. Catálogo/filtro/refresco y lista del lanzador nativos.
# Dobles para acciones Milou y operaciones TasksModel; no lanzan/cierran apps.

XDG_CACHE_HOME=/tmp/singlr-t203-cache \
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
  qml6 -I shell/qml shell/qml/Shell.qml -- --windowed --capture
# exit 0, dos CAPTURE_OK: captures/desktop-dark.png y launcher-dark.png.

XDG_CACHE_HOME=/tmp/singlr-t203-cache \
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
  qml6 -I shell/qml shell/qml/Shell.qml -- --windowed --applications \
  --capture=shell/qml/captures/applications-dark.png
# exit 0, RESULTS=30, CAPTURE_OK.
```

Sin errores QML de carga, bindings o JavaScript. Persisten advertencias del entorno:
udev, UPower/D-Bus desconectado, conexión PulseAudio y Wayland denegada, y backend
de sesión ausente. No constituyen prueba de integración con esos servicios.
Las tres capturas se inspeccionaron visualmente a 2048×1280: frente a T201, fecha
española, entrada al catálogo y lista con iconos originales donde el tema los
resuelve. Se conserva tipografía Inter, densidad, selección y geometría; los
indicadores sin datos no aparecen. Algunos iconos no se resuelven offscreen.
No se ha probado RHI, lector de pantalla, varios monitores ni rendimiento.

`--capture=<ruta.png>` captura un estado y termina; `--capture` captura escritorio
y lanzador vacío. `--applications` abre el catálogo en modo ventana. `--search`
abre búsqueda general; `--query=` permite iniciar vacío. `--mode=light` conserva
la variante de desarrollo en modo ventana.

## Comandos para Claude en la sesión real

```bash
tools/run-singlr.sh --size 2048x1280
# Desde otra terminal, con una sola sesión anidada viva:
tools/capture-session.sh /tmp/singlr-h3-session.png
```

Recorrido pendiente: cuadrícula del dock → filtrar Dolphin → Enter; comprobar
que abre dentro del KWin anidado y aparece como ventana en el dock. Clic en la
activa minimiza, otro clic restaura/activa; clic derecho → nueva ventana y cerrar.
Abrir búsqueda desde el dock → Todas las aplicaciones → Búsqueda general; escribir
una consulta, Ctrl+K cuando ofrezca acciones y Esc dos veces. Confirmar foco
inmediato al abrir, que pulsar dentro del panel no lo cierra, que Esc funciona tras
Tab y que las apps recuperan teclado al cerrar. Probar actualización de red,
volumen y batería donde haya servicios/dispositivos. «Salir de Singlr» debe cerrar
la sesión a través del supervisor. No se ejecutaron estas pruebas en el sandbox.


### T206: popups en layer-shell (24 oct 2026)

Solución técnica derivada del encargo: `Popup.Item` explícito en los tres popups;
ventanas independientes y ajustadas para ambos menús y el tooltip del dock.
`activateOnShow` solicita foco para los menús OnDemand. Sin cambio de tokens visuales.
Verificado: qmllint sin advertencias; qmltestrunner 18 passed / 0 failed,
incluido host externo, Esc/clic fuera y señal de hover; captura offscreen del escritorio
y lanzador vacío en `/tmp/singlr-t206-{desktop,launcher}.png`.
Registro real seguido con `tail -f`: sin errores QML/layershellqt tras recargar;
persisten avisos previos de SVG y portal. Pendiente: recorrido físico de hover,
menú contextual y pérdida de foco entre aplicaciones en la sesión real.
Una captura adicional con búsqueda «konsole» abortó en KRunner/KIO en el sandbox
(`QWidget ... without QApplication`); el lanzador vacío sí se captura.

### T213 — Centro de control

Petición explícita del creador: filas de 36 px, texto de 13 px e iconos Phosphor
 de 16 px, controles neutros según P-010 y batería como última sección.
`ControlRow` comparte alineación, teclado, estado y acción entre Wi-Fi, Bluetooth
 y salidas de audio. `Toggle` y `SliderControl` usan Qt Quick Controls Basic con
 geometría propia y paleta neutra. El alfa de la pista es `#1fffffff`: QML utiliza
`#AARRGGBB`, por lo que `#ffffff1f` produciría amarillo opaco.

Contratos comprobados en los qmltypes y `ConnectionItemDelegate.qml` instalados
 de plasma-nm **6.8.1**, Qt **6.12.0**. `AppletProxyModel` aporta disponibilidad;
 una segunda ordenación por `Signal` y dos grupos de filas colocan primero la
 conectada y luego las demás por señal, sin priorizar historial. Se comprueban
`ItemType` y `SpecificPath` para omitir conexiones sin punto de acceso.
El patrón de conexión sigue el [applet oficial de KDE](https://github.com/KDE/plasma-nm/blob/master/applet/ConnectionItem.qml),
 contrastado con las firmas locales `activateConnection`,
`addAndActivateConnection` y `deactivateConnection`. La ruta histórica de
`/usr/share/plasma/plasmoids/org.kde.plasma.networkmanagement/` no existe en esta
 instalación. Los ajustes abren `systemsettings kcm_networkmanagement` mediante
`KCMUtils.KCMLauncher.openSystemSettings`.

Contraseña dentro de la fila, mostrar/ocultar, Enter para conectar y Esc para
 cancelar y limpiar. Progreso por estado nativo, errores por
`connectionActivationFailed`, transición fallida y timeout. El agente de secretos
 de KDE sigue siendo responsable de autenticación; falta comprobar con una red
 de prueba los errores de contraseña reales y si el agente presenta diálogos.
Las redes empresariales abren el KCM para configurar certificados/EAP.

Validación: qmllint completo sin avisos; qmltestrunner offscreen/software **61
 passed / 0 failed**. Los siete resultados del caso nuevo incluyen carga,
 disponibilidad, cuatro niveles de señal, llamadas de conexión/desconexión,
 contraseña por teclado, errores, éxito y controles neutros. Usa un Handler doble;
 no cambia la red activa. La [captura de componentes](captures/control-center-components-t213.png)
 es una composición QML con datos de prueba, revisada visualmente, no una captura
 de la sesión del creador. El log en vivo termina con carga correcta, sin errores
 QML nuevos; permanece el aviso previo de registro del portal para `singlr-shell`.

### T216 — Listas de conectividad estables

Corrección solicitada por el creador, sin decisiones visuales nuevas.
`StableDeviceModel` conserva un `ListModel`: actualiza `payload` con
`setProperty`, añade al final y elimina por clave, sin `clear` ni reasignación.
Wi-Fi usa UUID o SSID + seguridad; al abrir fija el orden por señal y coloca
la conexión activa primero. Solo vuelve a ordenar al abrir o cambiar la conexión.
El cursor, la contraseña, el menú y la confirmación retienen cambios estructurales;
al liberarlos se aplica la última instantánea. Las señales y estados siguen vivos.
La contraseña y el menú se conservan en objetos por clave fuera del delegado;
al cancelar, cerrar la página o desaparecer la red se limpia la contraseña.
Bluetooth comparte el modelo estable por dirección y congela bajo el cursor.
Ambas vistas usan `reuseItems: false`, sin transiciones estructurales ni navegación
automática por índice. El alto del panel se actualiza como máximo cada 400 ms.

Contratos: Qt 6.12.0 y plasma-nm 6.8.1 instalados; roles del `NetworkModel`
contrastados en los qmltypes locales. APIs de
[ListModel](https://doc.qt.io/qt-6/qml-qtqml-models-listmodel.html) y
[ListView](https://doc.qt.io/qt-6/qml-qtquick-listview.html) verificadas en Qt oficial.

Verificado: comando qmllint completo anterior, exit 0 sin avisos;
qmltestrunner offscreen/software **70 passed / 0 failed**. El nuevo doble de
NetworkModel cambia orden/señal cada 100 ms mientras se escribe: conserva objeto,
clave y contraseña, actualiza señal y aplaza altas/bajas/movimientos. También
comprueba menú/olvido, hover, reapertura y cambios de conexión.
El log en vivo tras la recarga de 19:32:10 no presenta errores QML nuevos;
permanece el aviso previo del portal. Los avisos D-Bus de la suite corresponden
al sandbox. Queda la confirmación física del creador con su red y Bluetooth;
las pruebas no conectan, desconectan ni olvidan dispositivos reales.
