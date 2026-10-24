# T201 — shell QML, Día 1

Entrada: `qml6 -I shell/qml shell/qml/Shell.qml -- --windowed` desde la raíz.
Sin argumentos crea superficies layer-shell; ejecutarlo exclusivamente en la sesión
anidada preparada por Codex 2. No requiere archivos de `shell/session/` para el modo ventana.

## Implementación y procedencia

- `Singlr/Ui/`: módulo reutilizable, tokens LCH oscuro/claro, Inter variable y
  Phosphor migrados de `prototypes/desktop/`; las fuentes se referencian en
  `third_party/` sin copiarlas. AppIcon usa Kirigami.Icon y los iconos originales del tema.
- `Singlr/Shell/`: fondo sólido, reloj/fecha del sistema, menú para terminar el
  proceso Singlr, dock TasksModel, lanzador ResultsModel de Milou.
- Las fijaciones se descubren en `/usr/share/applications`: Dolphin, Konsole,
  Firefox, Kate y System Settings, solo si existe su archivo desktop. No se
  descubren hoy fijaciones en directorios de aplicaciones del usuario/Flatpak.
- El dock representa los roles `AppName`, `decoration`, `IsWindow`, `IsGroupParent`,
  `IsActive`, `IsLauncher`. Activa mediante `requestActivate(index)` o lanza con
  `requestNewInstance(index)`. Los grupos los resuelve TasksModel.
- Milou busca aplicaciones, archivos y comandos reales. No hay resultados de
  demostración en el producto. Enter llama `run(model.index(row, 0))` y las
  acciones son exclusivamente las del rol `actions`, mediante `runAction(index,n)`.
  Ctrl+K solo abre el panel cuando el resultado tiene acciones; Esc cierra primero
  ese panel. Arriba/abajo recorre resultados o acciones. Meta+Espacio y Alt+Espacio
  funcionan con foco en las ventanas del shell: no son atajos globales del compositor.
- `Session.qml`: fondo en LayerBackground, barra en LayerTop (exclusionZone 38),
  dock en LayerBottom y lanzador LayerOverlay con teclado exclusivo mientras abre.
  Barra y dock usan teclado OnDemand. Alcance actual: pantalla predeterminada.
- `Glass.qml`: MultiEffect con autoPaddingEnabled=false y detección por
  `glass.GraphicsInfo.api`; desenfoque verdadero cuando hay RHI y un backdrop del
  mismo árbol visual. Software o ausencia de backdrop usa material opaco.
  **En modo sesión no se desenfocan ventanas de otras aplicaciones**: no existe
  captura cross-window ni una API de blur del compositor conectada en esta entrega.
  La API QML local de org.kde.kwindowsystem no expone KWindowEffects.

Contratos contrastados con Qt 6.12.0, milou 6.8.1, plasma-workspace 6.8.1 y
layer-shell-qt 6.8.1 (`pacman -Q`, 24 oct 2026), y los archivos locales:

- `/usr/lib/qt6/qml/org/kde/milou/milou.qmltypes` y `ResultDelegate.qml`
- `/usr/lib/qt6/qml/org/kde/taskmanager/taskmanager.qmltypes`
- `/usr/lib/qt6/qml/org/kde/layershell/LayerShellQtQml.qmltypes`
- [Qt MultiEffect](https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html)

## Evidencia visual

Referencia inicial: `prototypes/desktop/captures/search-dark.png` y
`desktop-dark.png`. Se conservan 760×542 para el lanzador, barra de 38, dock de
48, radios moderados, tipografía Inter/Phosphor, neutros LCH y selección índigo.
Se eliminan las ventanas y estados simulados: el escritorio queda libre para apps
reales. No se introduce una variante de dirección visual pendiente de aprobación.

`captures/desktop-dark.png` y `captures/launcher-dark.png` muestran la composición
implementada a 2048×1280; se inspeccionaron visualmente. Son capturas software:
material opaco, lanzador vacío sin consulta, sin apps inventadas. En offscreen los
iconos del tema no se resolvieron y Dolphin mostró su identificador desktop; su
presentación en KDE normal queda pendiente. No prueban desenfoque ni búsqueda.

Se verificaron nombres accesibles, foco de entrada, Return/Espacio en botones,
Escape, wrap de navegación, acciones y despacho fallido. Pendientes: lector de
pantalla, escalado, varios monitores, coste gráfico y presentación en sesión real.

## Comprobaciones ejecutadas

```bash
python3 scripts/doctor.py
# Qt 6.12.0, qml/qmllint/qmltestrunner disponibles; sin instalar paquetes.

/usr/lib/qt6/bin/qmllint -W 0 -I shell/qml \
  -i shell/qml/Singlr/Ui/qmldir shell/qml/Shell.qml \
  shell/qml/Singlr/Ui/*.qml shell/qml/Singlr/Shell/*.qml shell/qml/tests/*.qml
# exit 0, sin errores ni advertencias. -i declara el singleton del módulo.

QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
  /usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests
# 8 passed, 0 failed. El modelo de resultados de estas pruebas es un doble;
# validan interacciones y contratos, no disponibilidad de servicios KDE.

QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
  qml6 -I shell/qml shell/qml/Shell.qml -- --windowed --capture
# exit 0. BACKEND=1, dos CAPTURE_OK, PNG 2048×1280 en captures/.
# Advertencias de integración: conexión Wayland/DBus y bloqueo de sycoca denegados.
```

`--capture=<ruta.png>` captura un solo estado y termina. `--search` abre el lanzador
con la consulta `konsole`; `--query=` permite capturarlo vacío. `--mode=light`
selecciona los tokens claros (las dos capturas entregadas son oscuras).

RHI/OpenGL offscreen se intentó y abortó al crear el contexto QRhi. D-Bus aislado
se intentó y falló al crear sockets (`Operation not permitted`). La consulta real
alcanzó plugins KDE pero KIO no pudo crear sockets; un diálogo de error abortó
con `QWidget: Cannot create a QWidget without QApplication`. `-a widget` evitó
ese aborto pero quedó bloqueado en el diálogo y se interrumpió. No se declara
verificada búsqueda, lanzamiento, activación de ventanas ni layer-shell.
Konsole y Kate no están instalados aquí (no hay desktop files); Dolphin, Firefox
y System Settings sí. No se instalaron paquetes ni se tocó la sesión KDE.

## Verificación pendiente para Claude (fuera del sandbox, en sesión anidada)

Con las variables WAYLAND_DISPLAY, XDG y DBUS_SESSION_BUS_ADDRESS de esa sesión:

```bash
qml6 -I shell/qml shell/qml/Shell.qml -- --windowed --search --query=konsole
```

Comprobar resultados y Enter solo si Konsole está instalado en el entorno de
prueba; usar `firefox` para una app existente aquí. Verificar que la aplicación
aparece dentro del KWin anidado y que su tarea se añade/activa desde el dock.
Si un runner necesita diálogos QWidget, usar `qml6 -a widget` con los mismos argumentos.

```bash
qml6 -I shell/qml shell/qml/Shell.qml -- --windowed --search --query=firefox \
  --capture=shell/qml/captures/launcher-results.png
# Para las capas, desde el entorno de KWin anidado preparado por Codex 2:
QT_WAYLAND_SHELL_INTEGRATION=layer-shell qml6 -I shell/qml shell/qml/Shell.qml
```

Revisar las cuatro capas, zona reservada, foco exclusivo del lanzador y su
liberación al cerrar, clic en fijaciones/ventanas, Ctrl+K sobre un resultado que
exponga acciones y «Salir de Singlr». Este documento registra soluciones técnicas
derivadas del encargo, sin aprobar nuevas decisiones visuales.
