# T207 — Dock en vivo

Implementación de la propuesta del encargo; su validación visual por el creador sigue pendiente. Soluciones técnicas derivadas: identidad de ventana por `WinIdList` ordenado, resolución del índice en cada acción y memoria por aplicación; `LastActivated` para recuperar la más reciente. No se retienen índices de hijos entre activaciones.

- Clic: lanzar con pulso hasta ventana/10 s, recuperar la más reciente, restaurar todas si están minimizadas, ciclar grupos y minimizar una ventana activa.
- Rueda bidireccional, clic central para nueva instancia, halo de atención y foco visible solo por Tab.
- Menú en la superficie layer-shell existente: ventanas con título recortado y marca activa, nueva ventana, fijar/quitar y cerrar; filas de 30 px, texto de 13 px, ↑/↓/Enter/Esc y cierre exterior.
- Tooltip compartido: 400 ms iniciales, inmediato al pasar entre iconos; tolerancia de 150 ms entre ellos. Oculto al interactuar/abrir menú.
- Fijados propios mediante QtCore.Settings en `$XDG_CONFIG_HOME/singlr/dock.json` (normalmente `~/.config/singlr/dock.json`). **Formato INI de QSettings**, con la lista serializada como JSON dentro de `pins`; la extensión no cambia el formato. No toca preferencias de KDE. Fijados separados de las abiertas, orden manual de TasksModel y lanzador al final.
- Zona exclusiva inferior de 58 px; superficie del dock de 48 px y margen de 10 px.
- Pendiente: arrastre para reordenar fijados.

## Evidencia

Qt 6.12.0, Plasma y layer-shell-qt 6.8.1. Contratos comprobados con los qmltypes locales y documentación de [Settings](https://doc.qt.io/qt-6/qml-qtcore-settings.html), [TasksModel](https://github.com/KDE/plasma-workspace/blob/master/libtaskmanager/tasksmodel.h) y [roles de ventanas](https://api.kde.org/legacy/plasma/plasma-workspace/html/classTaskManager_1_1AbstractTasksModel.html). Los identificadores Wayland se usan únicamente dentro del proceso.

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_CACHE_HOME=/tmp/singlr-t207-cache \
  /usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests
# 32 passed, 0 failed. El doble mueve al primer puesto cada ventana activada.
# Incluye ciclo, rueda, MRU, minimizadas, retirada de ventana, menú/teclado,
# pulso/timeout, tooltips, clic central y persistencia en archivos /tmp.

/usr/lib/qt6/bin/qmllint -I shell/qml -i shell/qml/Singlr/Ui/qmldir \
  shell/qml/Singlr/Shell/Dock.qml shell/qml/Singlr/Shell/DockItem.qml \
  shell/qml/Singlr/Shell/Session.qml shell/qml/tests/tst_Dock.qml
# exit 0, sin advertencias.
```

`git diff --check`: correcto. Seguimiento con `tail -f` del registro de la sesión viva durante las recargas: sin errores QML nuevos; persiste el aviso previo del portal por el ID `singlr-shell`. Las pruebas offscreen tienen avisos por falta de acceso a Wayland/D-Bus/UPower/audio; no equivalen a interacción real con Chrome.

## Recorrido para el creador

1. Chrome con cuatro ventanas: activar Chrome y pulsar ocho veces; debe visitar las cuatro dos veces. Repetir con rueda arriba/abajo. Cambiar de ventana con Alt+Tab y volver al dock.
2. Minimizar todas: un clic restaura las cuatro y deja delante la más reciente. Con una sola ventana activa, un clic la minimiza. Clic central abre otra ventana.
3. Botón derecho: elegir una ventana, navegar con ↑/↓ y Enter, salir con Esc o clic exterior; comprobar fijar/quitar, cerrar una y cerrar el grupo.
4. Fijar una app, esperar una recarga y comprobar permanencia y orden. Quitarla y repetir. Mover el cursor entre iconos y revisar demora inicial, respuesta inmediata y ocultación al pulsar.
5. Abrir una app cerrada: observar pulso discreto hasta que abre. Maximizar una ventana: debe terminar encima del espacio reservado. Comprobar halo cuando una app solicite atención y ausencia de puntos/marcos al pulsar.

Sin commit. Cambios limitados a `shell/qml/**`.
