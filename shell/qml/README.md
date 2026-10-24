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
