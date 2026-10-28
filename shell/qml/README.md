> T266: las menciones históricas a `SinglrSecrets` describen un agente retirado.
> La sesión instalada usa el agente de plasma-nm/kded. Se conserva la entrada
> inicial de contraseña para redes nuevas; los secretos de perfiles existentes
> los solicita KDE. Véase [sesión](../../session/README.md).

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
# Perfil KDE, XDG y bus temporales: el módulo Singlr.System migra y escribe la
# apariencia de KDE, y nunca debe tocar la configuración ni la sesión del usuario.
cmake --build build && tools/test-qml.sh
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

### T217 — Páginas de geometría estable (P-011)

Sustituye el comportamiento de expansión de T213/T216 por una sola `StackView`:
principal → Wi-Fi → detalle/contraseña y principal → Bluetooth → dispositivo.
El alto se calcula una vez con el contenido principal; todas las páginas usan
ese mismo espacio, con desplazamiento interno. Las filas miden 36 px. Contraseña,
errores (línea reservada), acciones y confirmación de olvido viven en páginas.
`SinglrSecrets` abre directamente la página de contraseña, también al reintentar.
Se conservan las claves y el orden de `StableDeviceModel`, eliminando congelación
por hover, estados de expansión por clave y temporizador de alto de 400 ms.
El historial de notificaciones tiene alto fijo de 620 px, filas de 36 px y detalle
por página. Los menús de dock/barra ya toman una instantánea al abrir o son
estáticos. Solo las páginas usan fundido cruzado de 120 ms; se eliminaron los
movimientos de tamaño/posición, pulso/escala del dock y animaciones de listas.
El indicador giratorio de conexión comunica progreso.

Comprobado con Qt 6.12.0: qmllint completo con `-W 0` e imports locales,
**exit 0, sin avisos**; qmltestrunner offscreen/software **70 passed / 0 failed**.
La suite verifica altas/bajas y señal con filas constantes, orden/claves,
altura del panel al navegar, Esc y ‹, contraseña/error/olvido, secretos y
historial estable con 0/2/40 notificaciones. Los dobles no cambian la red ni
Bluetooth. Preview QML revisado en `/tmp/t217-panels.png`; no sustituye la
validación física del creador. API de StackView contrastada con
[Qt 6.12](https://doc.qt.io/qt-6/qml-qtquick-controls-stackview.html).


### T218 — Menús contextuales flotantes (P-012)

`Singlr.Ui.ContextMenu` usa `Popup.Item` dentro de la ventana existente: 240 px,
radio 8, filas de 28 px, Phosphor de 14 px, texto de 13 px, separadores y sombra.
Posición junto al cursor o «…», limitada por el panel; sin transición ni cambios
de geometría del contenido. ↑/↓, Enter, Esc y cierre al pulsar fuera. Olvidar
requiere dos activaciones en la misma fila; Esc cancela la confirmación.

Wi-Fi y Bluetooth sustituyen sus páginas de detalle por este menú. Contraseña
y secretos mantienen su página y foco de entrada. El historial conserva la
lectura de notificaciones y ofrece acciones por clic derecho/«…». Silenciar
quita `ShowPopups` y `ShowPopupsInDoNotDisturbMode` mediante `NM.Settings` cuando
hay `DesktopEntryRole` o `NotifyRcNameRole`, conserva historial y guarda la
preferencia. El dock comparte el componente, dentro de su ventana layer-shell.
El glifo `trash` procede del CSS Phosphor ya incluido.

Contratos contrastados con Qt 6.12.0 y qmltypes locales de Plasma/BluezQt:
[Popup.Item y límites](https://doc.qt.io/qt-6/qml-qtquick-controls-popup.html),
[preferencias de NotificationManager](https://github.com/KDE/plasma-workspace/blob/master/libnotificationmanager/settings.cpp).

Verificado con los comandos completos anteriores: **qmllint exit 0 sin avisos**;
**qmltestrunner offscreen/software 77 passed, 0 failed**. Incluye límites,
altura constante, doble confirmación y cancelación, teclado, clic fuera,
acciones Wi-Fi/Bluetooth, contraseña con foco, acciones del historial y dock.
Los dobles no modifican conexiones ni preferencias reales. Capturas de prueba
claro/oscuro revisadas en `/tmp/t218-menu-{dark,light}.png`; no acreditan
interacción física. Log vivo revisado tras recargas: sin errores QML nuevos;
permanece el aviso previo de registro del portal para `singlr-shell`.
Pendiente la comprobación física de conectividad, preferencias y devolución
de foco entre ventanas layer-shell en KWin.

### T219 — contraseña flotante (P-012 actualizado)

Sustituye la página de contraseña de T216/T218 por `WifiPasswordBar`: Popup
superpuesto sobre la propia fila, de su mismo ancho y 36 px, sin transición ni
navegación adicional. Mantiene tipografía, superficies y botones existentes;
candado de 14 px, campo flexible, ojo, retorno y cierre, con nombres accesibles.
No se añaden tooltips (Tool no los ofrece). Enter envía; Esc, cierre o clic fuera
cancelan. Al conectar conserva el texto en solo lectura y muestra puntos; el
error selecciona todo y cambia ayuda, borde e icono. Cerrar borra la contraseña.
`SinglrSecrets`, incluido retry, usa esta misma barra; si todavía no hay fila del
SSID, espera su llegada desde el modelo en la página Wi-Fi.

La lista Wi-Fi conserva orden y delegados al activarse una red y al recibir el
UUID de una conexión recién guardada. La promoción de la red activa se conserva
al abrir de nuevo la página; Bluetooth mantiene su comportamiento anterior.

Contratos: Qt local 6.12.0; [Popup: parent, foco y closePolicy](https://doc.qt.io/qt-6/qml-qtquick-controls-popup.html),
[TextInput: readOnly, accepted y selectAll](https://doc.qt.io/qt-6/qml-qtquick-textinput.html).
Verificación: qmllint completo sin avisos; qmltestrunner offscreen/software
**77 passed, 0 failed**. Incluye geometría del panel y de las filas al abrir,
conectar, fallar, cerrar y recibir éxito con UUID nuevo; teclado, mostrar/ocultar,
selección, envío, cancelación y retry de secretos con dobles. Preview renderizado
de barra normal y error inspeccionado a 308 × 36 px. El registro en vivo recarga
sin errores QML nuevos; conserva el aviso previo del portal por app ID
`singlr-shell`. No se ha probado autenticación contra una red real.

### T220 — Conectar en la fila y mínimo entendible (P-013, P-014)

Aplicación de las decisiones explícitas P-013/P-014; los cambios siguientes son
soluciones técnicas derivadas del encargo, pendientes de la revisión visual del
creador. No se modificaron archivos fuera de `shell/qml/` ni se creó commit.

- `WifiPasswordBar` eliminado. `WifiRow` conserva 36 px y sustituye su contenido
  por icono Wi-Fi + campo de contraseña + ojo. Enter envía; Esc o clic fuera
  cancelan y limpian. Progreso: icono atenuado y campo de solo lectura. Error:
  Phosphor de aviso rojo suave, selección completa y ayuda «Contraseña incorrecta».
  Éxito: fila normal con «Conectada». Los secretos y sus reintentos usan esa fila.
- El menú Wi-Fi llama al mismo `WifiRow.connectNetwork()` que el clic izquierdo:
  conserva progreso, protección contra solicitudes duplicadas y errores también
  para redes conocidas y abiertas. Se eliminó el porcentaje de señal visible.
- Bluetooth muestra también dispositivos no emparejados y descubre mientras está
  abierta su página; solo detiene el descubrimiento iniciado por ella. Clic y
  menú comparten conexión/desconexión/emparejamiento. Estado y errores aparecen
  en la fila sin desplazarla; se puede reintentar un error. El menú mantiene
  Conectar/Desconectar, Olvidar con doble confirmación y Ajustes.
- `BatteryRow`: una fila de 36 px; icono de carga, porcentaje 13 px/peso 590,
  tiempo corto y tres círculos de 12 px/borde 1,5 px. Colores prescritos por P-014;
  relleno ligado a `activeProfile`, clic/teclado llaman a `setProfile` y perfiles
  no disponibles se deshabilitan. Sin barra ni frases que repitan el porcentaje.
- Vista principal: Wi-Fi/Bluetooth pasan de título + estado a icono + estado.
  Salida, micrófono y brillo usan icono + deslizador en la misma fila. Las salidas
  de audio conservan nombres para poder elegir el dispositivo.
- Notificaciones: cabecera única con No molestar como icono con estado, borrar y
  cerrar; se reduce el hueco superior de la lista manteniendo el panel de 620 px.
  OSD: icono + barra para magnitudes, sin porcentaje redundante; conserva texto
  cuando comunica un estado. La barra superior y los menús ya eran compactos:
  se conservan sus nombres de acciones para distinguirlas; batería refleja carga.
- Se añaden tooltips compartidos a `Tool`, nombres accesibles a acciones «…» y
  estado accesible a perfiles y No molestar. Se conserva geometría, tipografía,
  materiales y navegación existentes fuera de estas reducciones.

**Límite pendiente del contrato nativo:** ni `org.kde.bluezqt` ni el módulo privado
Bluetooth instalado exportan `BluezQt::Agent` a QML. El launcher solo expone
`SinglrSecrets` (NetworkManager), sin agente Bluetooth. Por ello **no están
implementadas la recepción, entrada y confirmación de PIN dentro de la fila**.
`device.pair()` inicia el emparejamiento nativo, pero su diálogo depende del agente
externo disponible. Completar P-013 para PIN requiere un puente de `BluezQt::Agent`
en `shell/session/`, fuera del alcance autorizado. No se ha simulado ese contrato
como si funcionara ni se ha sustituido el agente de la sesión KDE.

Contratos: Qt 6.12.0, módulos Plasma 6.8.1 y firmas de BluezQt contrastadas con los
`qmltypes` locales. Referencias oficiales:
[TextInput y selección](https://doc.qt.io/qt-6/qml-qtquick-textinput.html),
[TapHandler y observación sin bloquear controles](https://doc.qt.io/qt-6/qml-qtquick-taphandler.html),
[agente BluezQt y peticiones PIN](https://api.kde.org/bluezqt-agent.html).

Verificado:

```bash
/usr/lib/qt6/bin/qmllint -I shell/qml -i shell/qml/Singlr/Ui/qmldir \
  shell/qml/Shell.qml shell/qml/Singlr/Ui/*.qml \
  shell/qml/Singlr/Shell/*.qml shell/qml/tests/*.qml
# exit 0, sin avisos

XDG_CACHE_HOME=/tmp/singlr-t220-cache QT_QPA_PLATFORM=offscreen \
QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
  /usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests
# 84 passed, 0 failed

git diff --check
# exit 0
```

Pruebas con dobles: geometría de filas/panel, Enter/Esc/clic fuera, contraseña
visible/oculta, fallo/selección/éxito con UUID nuevo, secretos/retry/cancelación,
el mismo flujo desde menú y clic en redes conocidas/abiertas/protegidas,
Bluetooth conectar/desconectar/emparejar/reintentar y perfiles por teclado,
colores y perfiles deshabilitados. No conectan hardware ni cambian PowerDevil.
[Preview de componentes T220](captures/minimum-controls-t220.png) renderizada e
inspeccionada; datos de prueba, no captura de autenticación real. No se tomó una
captura previa de la sesión: la comparación anterior se basa en el QML sustituido
(barra flotante, batería multilínea, etiquetas sobre los deslizadores).

Log en vivo revisado hasta la recarga de las 20:21:30: sin errores QML nuevos;
permanece el aviso previo del portal para `singlr-shell`. La suite offscreen
conserva avisos esperados de D-Bus, UPower y audio por el sandbox. Quedan pendientes
la autenticación Wi-Fi real, PIN Bluetooth con el puente indicado, cambios reales
de PowerDevil y comprobación física de foco entre ventanas layer-shell.

### T224 — bandeja en vivo y contrato de multitarea

`SystemTray.qml`, antes de la campana, consume `SinglrTray` si existe: seis
iconos de 16 px y 12 px entre ellos, pixmap preferido y nombre de tema como
alternativa; desbordamiento, tooltip, acciones primaria/secundaria, rueda y menú.
El desbordamiento conserva las acciones de cada app, incluido clic derecho.
Los menús usan `ContextMenu` en una superficie layer-shell independiente de
240 × 344 px bajo la barra. La altura permanece fija durante carga e
invalidaciones; desplazamiento interno, navegación Atrás para submenús,
separadores, radios/casillas, iconos y deshabilitados. Escape, pérdida de foco y
retirada de filas cierran el menú. Son soluciones técnicas derivadas de T224 y
P-011/P-012; no una nueva aprobación visual.

Pendientes para Claude **fuera de `shell/qml/**`**:

- El contrato actual `menu()` es síncrono. Se abre primero la superficie con
  «Cargando…» y se consulta mediante `Qt.callLater` después de ceder un ciclo.
  Esto permite presentar la superficie, pero **no evita bloquear el hilo GUI
  durante la llamada C++**, hasta ~3 s con un exportador colgado. Para garantizar
  hover fluido se necesita una consulta asíncrona en C++, con resultado/señal y
  control de respuestas antiguas. Referencia: [Qt.callLater](https://doc.qt.io/qt-6/qml-qtqml-qt.html#callLater-method).
- Añadir rol booleano `hasAttentionIcon`: el backend ya elige el icono de
  atención, pero no permite distinguirlo del normal. Hasta entonces un ítem
  NeedsAttention lleva también punto de 4 px; al exponer el rol se suprime el
  punto cuando hay icono específico, sin otro cambio QML.
- P-032: `SinglrSystem.invokeShortcut("kwin", "Overview")` invoca la vista general
  nativa por `org.kde.kglobalaccel.Component`. El botón de multitarea permanece
  visible. No se consulta periódicamente su estado ni se mantiene abierto el dock
  durante la vista general: aplica su autoocultado habitual; el lanzador sí lo retiene.

Verificación T224 (Qt 6.12.0): `qmllint` completo sin avisos; suite
`qmltestrunner` offscreen/software con pruebas de bandeja (acciones, overflow,
menú diferido/cancelado, submenú, invalidación, retirada y geometría fija).
El supervisor recarga los cambios en vivo; se vigiló
`/run/user/1000/singlr-live/shell.log`, sin errores QML nuevos. El acceso directo
al bus real está denegado por el sandbox, por lo que no se acredita interacción
manual con las siete apps ni revisión visual/captura de la sesión real.

## T231 — recursos del shell (P-016)

Solución técnica derivada, sin cambiar tipos layer-shell ni anclajes: ventanas
independientes creadas por `Loader` solo mientras se usan. Compartir una ventana
entre utility, notification y on-screen-display alteraría las reglas de foco,
entrada y posicionamiento. Al cerrar se destruye la ventana inmediatamente;
`DeferredLoader` conserva únicamente el contenido QML durante 2500 ms, fuera de
la ventana, y después lo libera. En reposo con `--no-background` quedan la barra
y el dock: desaparecen nueve ventanas temporales y la del fondo desactivado.
El centro de control espera a que su página inicial calcule la altura existente
antes de mostrar su ventana, para no introducir un cambio de tamaño al abrir.

- Lanzador y centro de control se cargan por URL para diferir también sus imports.
  Los modelos de red, Bluetooth, salidas de audio, brillo y batería detallada
  viven con el centro de control. Sus callbacks de operaciones se desconectan al
  liberarlo. Catálogo, menús, tooltips y vistas del OSD se liberan al cerrar.
- El servidor/estado de notificaciones permanece activo; historial y tarjetas son
  perezosos. No hay ticks de expiración con historial abierto ni cuando las tres
  tarjetas visibles son persistentes. Permanecen los modelos mínimos necesarios
  para indicadores, tareas, bandeja y atajos globales de volumen y reproducción.
- Cristal: ningún ShaderEffectSource existe oculto. La sesión usa `singlrBlur`
  de KWin; el árbol de desenfoque QML solo se crea en la vista previa visible.
  Muestreo a 1/4 por dimensión y recorte a 1/2: 75 % menos píxeles por textura
  respecto a sus tamaños anteriores. La capa de atención del dock solo se activa
  mientras su indicador es visible.
- Reloj alineado al minuto: aproximadamente 60 veces menos despertares. Apariencia
  automática programada a las 07:00/19:00: dos comprobaciones diarias. Animador de
  actividad condicionado a visibilidad. Temporizadores de captura, acciones,
  escaneo y expiración funcionan solo durante su operación/superficie; el margen
  de liberación es un temporizador de un solo disparo.
- Todas las `Image` tienen `sourceSize` según tamaño visible y DPR, incluido el
  fondo. `Kirigami.Icon` administra su rasterización al tamaño del componente.
  Inter y Phosphor ya se cargaban una única vez en el singleton `Theme`.

Evidencia local (Qt 6.12.0, 25 oct 2026):

- `qmltestrunner -import shell/qml -input shell/qml/tests` con
  `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software`: 107 pasadas, 0 fallos; incluidos
  apertura/cierre, caché breve, liberación y recreación de loaders y desconexión
  de operaciones al destruir el panel. Sin errores QML de propiedades o bindings.
- `python3 tools/check-shell.py --output /tmp/t231-desktop.png`: qmllint, carga y
  captura offscreen correctos. Captura adicional con `--windowed --applications`
  correcta en `/tmp/t231-apps.png`.
- Comparación orientativa durante T231 contra `HEAD`, procesos nuevos de `qml`,
  `Shell.qml --no-background`, XDG temporales, buses desactivados y software
  offscreen. Tras 4 s, `/proc/PID/smaps_rollup`: PSS 35511 → 30189 KiB
  (−5322 KiB, ≈15 %); anónimos 25416 → 20564 KiB. CPU: 0 ticks/3 s en ambos
  procesos, reloj del sistema de 100 Hz. Es ahorro conjunto; no se ha medido PSS
  por componente ni memoria GPU y no se extrapola a los 208 MB de la sesión real.
- Últimas recargas de `/run/user/1000/singlr-live/shell.log` sin errores QML.
  Siguen avisos preexistentes del portal, traducciones, buffer SVG y el terminal
  `konsole` ausente al lanzar Htop. El objetivo real <120 MB y el comportamiento
  con KWin quedan para la medición/revisión de Claude y Codex 2.

Contratos contrastados con documentación oficial de Qt:
[Loader](https://doc.qt.io/qt-6/qml-qtquick-loader.html) y
[Image.sourceSize](https://doc.qt.io/qt-6/qml-qtquick-image.html#sourceSize-prop).

### T233 — sesión y pantallas (25 oct 2026)

Solución técnica derivada del encargo: `SessionMenu.qml` reutiliza `ContextMenu`
(P-012), con avatar/inicial de 24 px, usuario, atajo Meta+L y confirmación en la
misma fila para reiniciar, apagar y cerrar sesión. `typeof` protege tanto las
capacidades como las llamadas a `SinglrSystem`; las acciones en modo ventana
solo escriben `SESSION_ACTION windowed` en el log, incluidos los ajustes.
Las capacidades se actualizan al abrir el menú y quedan congeladas hasta el
siguiente acceso para que los datos en segundo plano no cambien su tamaño.
Se conservan tipografía, material, colores y filas de 28 px del menú existente;
la confirmación usa `Theme.error`. Navegación por flechas/Enter y cierre con
Escape o clic fuera siguen a cargo de `ContextMenu`.

`Session.screens` usa `Qt.application.screens`. Un `Instantiator` administra
`ScreenSurfaces` (barra, fondo y superficies perezosas para sus menús) por salida,
con `Window.screen` explícito. `dockScreen` permite cambiar la política; por
defecto usa la primera pantalla y vuelve a ella si desaparece la seleccionada.
Dock, sus menús y OSD siguen esa pantalla. Las notificaciones emergentes también;
el historial (que oculta los popups mientras está abierto), el lanzador y el
centro de control siguen la pantalla del botón solicitante. Solo existe una
instancia de cada panel compartido. Los atajos globales conservan sus funciones
sin argumentos para las invocaciones C++ y usan la pantalla del dock.
Al cambiar el inventario se cierran paneles/menús; Instantiator retira los objetos
y ventanas de las salidas eliminadas. Los paneles siguen usando DeferredLoader.

Contratos contrastados con Qt local **6.12.0** y documentación oficial:
[Instantiator y propiedad de sus objetos](https://doc.qt.io/qt-6/qml-qtqml-models-instantiator.html),
[Window.screen](https://doc.qt.io/qt-6/qml-qtquick-window.html#screen-prop).

Verificación ejecutada:

- qmllint completo con los imports del comando anterior: exit 0, sin avisos.
- qmltestrunner offscreen/software: **115 passed, 0 failed**. Incluye protección
  sin bridge, capacidades opcionales, confirmación, cancelación, tamaño estable,
  modo ventana y alta/baja del inventario de pantallas. Offscreen solo ofrece un
  QScreen real: la prueba repite ese QScreen para comprobar el ciclo de objetos;
  no demuestra colocación en dos salidas físicas.
- Preview del menú renderizado e inspeccionado: `/tmp/t233-menu.png`.
- Log en vivo vigilado: las últimas recargas no muestran errores QML ni avisos
  de funciones de sesión ausentes; persiste el aviso previo del portal sobre el
  identificador `singlr-shell`.
- `tools/measure-resources.sh --output /tmp/t233-resources` intentado: **bloqueado**
  al crear el D-Bus privado (`Failed to bind socket … Operation not permitted`).
  No se acredita PSS/CPU ni el presupuesto P-016 con esta ejecución.

Validación pendiente para Claude, fuera del sandbox, sin tocar la sesión KDE:

1. En el controlador aislado de `tools/session-runtime.py`, ejecutar KWin con los
   mismos argumentos privados y añadir `--output-count 2` (opción confirmada con
   `kwin_wayland --help`). La línea del compositor queda:
   `kwin_wayland --wayland-display <display-padre> --socket singlr-wayland --width 1280 --height 800 --scale 1 --output-count 2 --no-lockscreen --no-global-shortcuts --no-kactivities`.
   Mantener el D-Bus, XDG y arranque del cliente privados del controlador;
   no ejecutar el cliente contra el bus de la sesión habitual.
2. Comprobar fondo/barra en ambas ventanas de salida, un solo dock en la primera,
   avisos/OSD en ella y menús/lanzador/centro/historial en la salida solicitante.
   Abrir el panel en una salida y después desde la otra; revisar Escape, clic
   fuera, foco y confirmación en sitio sin ejecutar acciones destructivas reales.
3. Deshabilitar y rehabilitar la segunda salida con `kscreen-doctor` **dentro del
   entorno privado**, con sus identificadores obtenidos mediante `kscreen-doctor
   -o`. Repetir con un menú y un panel abiertos. Verificar que no quedan ventanas
   huérfanas y que el dock vuelve a la primera salida disponible si se retira su
   pantalla. Revisar el log QML tras cada cambio.
4. Repetir la medición P-016 con el controlador normal y con dos salidas, en
   reposo, con panel abierto y después de cerrarlo. Guardar informe; este encargo
   no declara cumplido el presupuesto ni validada la integración multisalida.

### T238 — portapapeles y «Ahora suena»

Soluciones técnicas derivadas de T238/P-005/P-011…P-017; la composición sigue
pendiente de revisión visual del creador. No hay commit ni cambios de sesión.

- `ClipboardBackend` vive desde la construcción de `Session`. Retiene
  `Clipboard.KlipperInterface` **y** `Clipboard.HistoryModel`: el primero conserva
  `Klipper::self()` y su registro `org.kde.klipper`, objeto `/klipper`, interfaz
  `org.kde.klipper.klipper`; el segundo expone el historial estándar. No se crea
  otro almacén, proceso de portapapeles ni servicio D-Bus. El módulo mantiene sus
  preferencias de persistencia, selección e imágenes (no se fuerzan imágenes si
  Klipper las tiene desactivadas). Se usa `moveToTop(uuid)` para copiar el MIME
  original, `remove(uuid)`, escritura del rol `starred` y `removeRows(0, rowCount())` para vaciar todo tras confirmar.
- `ClipboardPanel`: 760 × 542, centrado por layer-shell (`AnchorNone`), lista de
  filas de 44 px y búsqueda literal insensible a mayúsculas. Enter copia y cierra;
  flechas navegan; Escape cierra. Clic derecho/«…» abren `ContextMenu`; fijación,
  eliminación y vaciado con segundo clic en el menú. Un cambio estructural del
  historial invalida el menú para no operar sobre otro UUID. El vaciado
  incluye los fijados («¿Vaciar todo?»): usa la operación nativa `removeRows`,
  porque `clearHistory()` del binario instalado abre además un KMessageDialog
  Qt Widgets (contrastado mediante objdump), incompatible con P-012 y el host
  QGuiApplication. No se cambian preferencias «no volver a preguntar». Miniaturas desde
  `decoration` de Klipper, URL con Phosphor link, texto plano y truncado. Reutiliza
  Glass, ListItem, ContextMenu, ShortcutHint, UiText y Theme; Glass admite ahora
  el material `Theme.surface` cuando KWin proporciona el blur. ListItem admite
  espacio final reservado sin alterar sus valores por defecto.
- El panel se carga mediante `DeferredLoader` (caché de 2500 ms); su ventana se
  destruye al cerrar, y después se libera búsqueda, proxy, delegados y menú.
  Solo el backend indispensable para registrar el historial permanece activo.
- `shortcuts.cpp`: `toggleClipboard()`, Meta+V, acción estándar
  `show-on-mouse-pos`. El `kglobalshortcutsrc` consultado la conserva en
  `[plasmashell]`; el binario `libklipper.so.6` instalado registra
  `org.kde.klipper`. Se atiende el propietario estándar encontrado en KGlobalAccel
  (ambos nombres admitidos), usando Autoloading; en perfil nuevo se usa
  `org.kde.klipper`. No se sustituye un propietario personalizado. La inscripción
  ocurre después de cargar el backend y reemplaza el destino local del atajo,
  manteniendo los atajos guardados. Falta contrastarlo en el bus privado real.
- `NowPlaying` reserva **36 px** en la página principal del centro de control,
  también sin reproductor; el contenido solo aparece cuando existe uno. Es una
  propuesta de composición derivada: evita variar alto/posición por reproducción.
  Comparado con la página anterior añade un hueco fijo de 44 px con su espaciado.
  Carátula de 28 px, título/artista en una línea, anterior/pausa/siguiente y «…»;
  capacidades MPRIS deshabilitan acciones, con nombres accesibles y foco de Tool.
  Comparte `SystemControls.mediaPlayers` (Mpris2Model ya residente para teclas);
  Automático usa el multiplexor activo de KDE, y el menú permite elegir otro.
  No hay progreso ni nuevos temporizadores de sondeo. Los delegados del selector
  se destruyen junto con el centro de control.

Contratos comprobados en **Qt 6.12.0 / plasma-workspace 6.8.1-1**: qmltypes de
`org.kde.plasma.private.clipboard` y `.mpris`, `KlipperPopup.qml`,
`ClipboardMenu.qml`, `DelegateToolButtons.qml`, `ImageItemDelegate.qml` instalados.
Código oficial de referencia (rama master, contrastado con contratos/binarios
locales, no sustituye una prueba de la versión instalada):
[KlipperInterface](https://github.com/KDE/plasma-workspace/blob/master/klipper/declarative/klipperinterface.cpp),
[registro D-Bus y acciones](https://github.com/KDE/plasma-workspace/blob/master/klipper/klipper.cpp),
[Mpris2Model](https://github.com/KDE/plasma-workspace/blob/master/libkmpris/mpris2model.cpp),
[registro y resolución de QAction en KGlobalAccel](https://github.com/KDE/kglobalaccel/blob/master/src/kglobalaccel.cpp).
`ldd /usr/bin/ksmserver` y sus cadenas no muestran enlace/referencia a Klipper;
no se detectó otro requisito de ksmserver para este servicio. Las apps copian por
el protocolo del compositor y los clientes D-Bus conservan el contrato de KDE.
Esto no acredita aún cierre/restauración ni comunicación con todas las apps.

**Límite offscreen detectado:** crear incluso HistoryModel sin KlipperInterface
produce SIGSEGV en el módulo instalado. Una traza local con manejador de señales
(no ptrace) lo sitúa en `SystemClipboard → xcb_get_input_focus →
xcb_send_request_with_fds64`, con conexión nula. El backend solo instancia esos
tipos en Wayland/XCB; en offscreen expone un modelo vacío.
Las pruebas de interacción usan un proxy doble y no invocan el backend nativo.
No se ha ocultado el fallo como una prueba de integración aprobada.

Comprobaciones (logs en `/tmp/t238-*.log`):

```bash
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests
# suite completa: 133 passed, 0 failed. Dobles, teclado, búsqueda literal,
# representación visual por tipo (no transferencia nativa de MIME),
# fijar/desfijar, eliminar UUID filtrado, confirmación, invalidación,
# capacidades MPRIS, selector y ciclo de vida/exclusividad del panel.
tools/check-shell.sh --output /tmp/t238-desktop.png
# compilación C++, qmllint, carga offscreen y PNG: PASS.
python3 -m unittest discover -s tests/shell -p 'test_shortcuts.py' -v
# unidad nativa PASS; D-Bus privado SKIP (socket denegado).
git diff --check
```

Preview con dobles renderizado e inspeccionado: `/tmp/t238-preview.png`, panel
sobre fondo/barra y fila multimedia aparte para revisar densidad. No representa
una reproducción real ni blur de KWin. Antes no existían estas superficies.

**P-016 pendiente:** `tools/measure-resources.sh --output /tmp/t238-resources`
intentado; falla antes de arrancar KWin: D-Bus `Failed to bind socket … Operation
not permitted`. No hay PSS/CPU del backend ni declaración de presupuesto cumplido.
La salida acredita limpieza sin procesos restantes y configuración host idéntica.
Para aislar el coste incremental, medir main y esta rama con los mismos XDG
privados, historial vacío y luego 20 textos/una imagen, al inicio, tras abrir y
5 s después de cerrar. Conservar `smaps_rollup`, ticks CPU en reposo y diferencia
PSS; no atribuir al backend el coste conjunto de otros cambios concurrentes.

Verificación para Claude **fuera del sandbox**, siempre en bus/pantalla privados:

```bash
tools/run-singlr.sh --duration 240
# Mantener abierto; copiar la ruta SINGLR_SESSION_FILE que imprime.
tools/measure-resources.sh --output /tmp/t238-resources-real
```

En otra terminal, ejecutar comandos en el entorno del descriptor, nunca en el
bus host (sustituir la ruta; el ejemplo no busca ni elige sesiones por deducción):

```bash
python3 - /tmp/singlr-session-XXXX/session.json <<'PY'
import json, os, subprocess, sys
from pathlib import Path
session = json.loads(Path(sys.argv[1]).read_text())
assert session['kind'] == 'singlr-nested-v1'
env = os.environ | session['env']
def run(*args):
    return subprocess.run(args, env=env, check=True, text=True, capture_output=True).stdout.strip()
print(run('qdbus6', 'org.kde.klipper', '/klipper'))  # comprobar interfaz completa
for text in ('T238 primero', 'T238 segundo', 'https://kde.org'):
    run('qdbus6', 'org.kde.klipper', '/klipper',
        'org.kde.klipper.klipper.setClipboardContents', text)
print(run('qdbus6', 'org.kde.klipper', '/klipper',
          'org.kde.klipper.klipper.getClipboardHistoryMenu'))
# El controlador desactiva global shortcuts en KWin anidado: invocar la misma
# acción en el daemon privado evita que Meta+V lo capture la sesión anfitriona.
for component in ('org.kde.klipper', 'plasmashell'):
    try:
        path = run('qdbus6', 'org.kde.kglobalaccel', '/kglobalaccel',
                   'org.kde.KGlobalAccel.getComponent', component)
        run('qdbus6', 'org.kde.kglobalaccel', path,
            'org.kde.kglobalaccel.Component.invokeShortcut', 'show-on-mouse-pos')
        break
    except subprocess.CalledProcessError:
        continue
else:
    raise RuntimeError('No se encontró la acción estándar privada')
# Si mpv y su complemento MPRIS están disponibles:
# subprocess.Popen(['mpv', '/ruta/a/un/audio.ogg'], env=env)
# print(run('playerctl', '-l'))
# print(run('playerctl', 'metadata'))
PY
```

Comprobar que los textos anteriores se registraron **sin abrir antes** el panel;
Enter y posterior Ctrl+V en una app privada, fijar/desfijar, borrar y cancelar/
confirmar vaciado; imagen copiada desde una app privada y miniatura. Repetir al
liberar/recrear la UI. Revisar que solo aparece Singlr al invocar el atajo y no el
popup de Plasma. Para teclado físico Meta+V hace falta un entorno aislado donde
el host no capture la combinación (el controlador seguro actual usa
`--no-global-shortcuts`); la invocación D-Bus no acredita la pulsación física.
Con un reproductor MPRIS real (mpv requiere plugin MPRIS si la instalación no lo
incluye), comprobar playerctl, anterior/pausa/siguiente y retirada del player;
con dos, Automático y selección explícita, carátula y título largos, sin cambiar
el alto del panel. Revisar foco/Escape/clic fuera y log QML. Conservar pendientes
hasta ejecutar estos recorridos; no tocar la sesión KDE habitual.

## T258 — contrato actual del portapapeles (P-026)

Actualiza el comportamiento de copia descrito en T238: clic o Enter selecciona y
pega en el destino original con capacidad Wayland. Ctrl+Enter o menú «Copiar» solo
copia. Sin destino válido se mantiene copia. [Entrega](../../docs/handoffs/T258-clipboard-paste.md).


## T273 — orden al usar el historial

La vista de Singlr conserva el orden de copia: seleccionar/pegar no sube entradas.
Copias nuevas o repetidas desde una aplicación sí van arriba. Klipper conserva
la restauración MIME; ClipboardHistoryModel guarda únicamente orden por UUID.
[Contrato y verificación](../../docs/handoffs/T273-clipboard-copy-order.md).
