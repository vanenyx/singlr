# T272 — Singlr reducido; Workspace de KDE

27 oct 2026 · Codex 1 · encargo de escritura exclusivo · sin commit, push ni instalación.
Decisión explícita del creador: P-032. Se implementa la retirada autorizada;
no se altera la sesión activa ni sus archivos kwinrc/kglobalshortcutsrc.

## Cambios

- `session/singlr_kwin.py`: journal nuevo limitado a las tres claves de material.
  Las claves de Workspace pasan a retiradas; se conserva el conjunto de formatos
  anteriores aceptados (con/sin TabBox, material, borde, activadores nativos y
  decoración). Restauración exacta de ausencias, vacíos y valores personalizados.
  `recover_pending` restaura antes de leer el nuevo snapshot. Recarga: descarga
  extensiones retiradas y reconfigura KWin; no carga multitarea propia ni descarga
  Overview/Window View de KDE. El vidrio conserva su carga/restauración previa.
- Eliminados `kwin/effects/singlr-overview/`, `kwin/scripts/singlr-gestures/` y
  `session/kwin/tabbox/singlr/`, sus reglas de instalación CMake y sus recorridos
  exclusivos (`tests/shell/overview-e2e.sh`, `workspace-e2e.py`, pruebas del cambiador).
  PKGBUILD ya delegaba toda la instalación en CMake: se documenta el alcance sin
  añadir reglas. El staging ya no contiene estos paquetes.
- `shell/session/src/{shortcuts.cpp,shortcuts.h,main.cpp}`: eliminada aplicación
  de atajos de KWin; al arrancar restaura un backup anterior si existe, antes de
  registrar acciones del shell. No crea otro. Conserva restauración al salir y
  `--restore-shortcuts` como reintento. La lista de acciones retiradas solo valida
  backups antiguos. Meta+Alt+S se retira por coincidir con el lector de pantalla.
- `shell/session/src/system.cpp/h`: retirados propiedad, sondeo y temporizador
  de disponibilidad de la multitarea propia. Se mantiene `invokeShortcut` asíncrono.
- `shell/qml/Singlr/Shell/{Dock,Session}.qml`: botón siempre visible que invoca
  `kwin` / `Overview`. Retirado estado propio y puente exclusivo de búsqueda/estado
  (`session/appearance/workspacebridge.h` y su entrada CMake). La búsqueda nativa
  queda en KDE. El dock ya no se retiene por multitarea abierta: funciona con su
  autoocultado habitual; lanzador/foco de teclado siguen reteniéndolo.
- Adaptadas pruebas Python, C++ y QML, verificador del paquete, `tools/test-qml.sh`,
  `tools/singlr-live.py` y `tools/singlr-doctor`. La herramienta live ya no enlaza
  extensiones retiradas ni depende de una decoración eliminada para aplicar material.
- Documentación: P-032 y sustituciones, notas [Registro] en sistemas 03/05 de
  `docs/singlr-1.0.md`, fila de estado, arquitectura, `session/WORKSPACE.md`,
  `packaging/README.md` y `shell/qml/README.md`.

## Atajos y gestos resultantes

Valores de fábrica KDE 6.8.1 como referencia; siempre prevalece la elección del
usuario en Ajustes de KDE. Singlr no vuelve a imponer esos valores.

| Entrada | Propietario y comportamiento |
| --- | --- |
| Meta; Alt+F1 | Singlr: lanzador mediante acción existente de plasmashell, con autoload de preferencias |
| Meta+1…9 | Singlr: entradas del dock, acciones existentes de plasmashell con autoload |
| Meta+V | Singlr: portapapeles; se conserva resolución de propietarios/Klipper |
| Meta+N | Singlr: notificaciones; reutiliza acción de plasmashell si ya la tiene |
| Meta+A | Singlr: centro de control, con comprobación de conflictos |
| Meta+Alt+D | Singlr: foco en el dock, con comprobación de conflictos |
| Meta+Space / Alt+Space | Se conservan los Shortcut locales del dock para el lanzador |
| Meta+L | KDE: bloqueo (Singlr no registraba esta combinación); menú del shell sigue usando SessionManagement |
| Alt+Tab / Meta+Tab; variantes Shift | KDE: cambiador de ventanas; retirado Meta+Tab propio |
| Meta+↑/↓; Meta+←/→ | KDE: mosaico arriba/abajo/izquierda/derecha; retirado maximizar/minimizar propio |
| Meta+PgUp / Meta+PgDown | KDE: maximizar/minimizar |
| Meta+W / Meta+G | KDE: vista general / cuadrícula |
| Ctrl+Meta+flechas | KDE: cambiar escritorio según disposición |
| Meta+D; Meta+T; Alt+F3 | KDE: mostrar escritorio, editor de mosaicos, menú de ventana |
| Meta+Alt+S | KDE: lector de pantalla; Singlr deja de registrar esta tecla para menú de sesión, accesible en barra |
| Botón de multitarea del dock | Invoca acción Overview de KWin por KGlobalAccel, independiente de la tecla asignada |
| Cuatro dedos arriba/abajo | KDE: transiciones de Overview/cuadrícula según estado; ningún gesto propio |
| Tres/cuatro dedos izquierda/derecha | KDE: escritorios según disposición |
| Tres dedos arriba/abajo | KDE: escritorios verticales cuando hay varias filas; retiradas acciones propias de multitarea/escritorio |
| Pinza de cuatro dedos y otros gestos | Sin asignación Singlr; decide KDE y la configuración del usuario |
| Esquinas y animaciones de ventana | KDE: ya no se anula la esquina superior izquierda ni se fuerza scale/squash/maximize/magiclamp |

La retirada de Meta+Alt+S evita la colisión detectada. Las coincidencias
Meta/Meta+1…9/Meta+N con funciones sustituidas de plasmashell conservan el mismo
propietario/acción o lo reutilizan; no se desplazan atajos de KWin ni de otras apps.
La política previa para conflictos personalizados se conserva.

## Contratos y versiones comprobados

`pacman -Q`: kwin 6.8.1-2, plasma-workspace 6.8.1-1, plasma-desktop 6.8.1-1,
kglobalaccel 6.31.0-1, qt6-base 6.12.0-3. `doctor.py`: qmllint/qmake 6.12.0.

- Acción `Overview`, Meta+W, cuadrícula Meta+G y gestos de cuatro dedos:
  [KWin v6.8.1 overvieweffect.cpp](https://github.com/KDE/kwin/blob/v6.8.1/src/plugins/overview/overvieweffect.cpp).
- Mosaico, maximizar/minimizar y operaciones de ventana:
  [KWin v6.8.1 useractions.cpp](https://github.com/KDE/kwin/blob/v6.8.1/src/useractions.cpp).
- Meta+Tab/Alt+Tab:
  [KWin rama Plasma/6.8 tabbox.cpp](https://github.com/KDE/kwin/blob/Plasma/6.8/src/tabbox/tabbox.cpp).
- Escritorios y gestos de tres/cuatro dedos:
  [KWin v6.8.1 virtualdesktops.cpp](https://github.com/KDE/kwin/blob/v6.8.1/src/virtualdesktops.cpp).
- `invokeShortcut(actionName: s)` sin resultado: XML instalado
  `/usr/share/dbus-1/interfaces/kf6_org.kde.kglobalaccel.Component.xml`, contrastado
  con [fuente oficial](https://github.com/KDE/kglobalaccel/blob/master/src/org.kde.kglobalaccel.Component.xml).
- Colisión lector de pantalla: `/usr/share/kglobalaccel/org.kde.screenreader.desktop`,
  `X-KDE-Shortcuts=Meta+Alt+S`; `pacman -Qo` confirma plasma-desktop 6.8.1-1.

## Comprobaciones ejecutadas

Todo build/staging adicional en `/tmp`, sin instalar ni reiniciar componentes.
Los tests usan perfiles XDG temporales y buses deshabilitados/privados.

| Comando | Resultado |
| --- | --- |
| `pytest tests/shell/test_kwin.py tests/shell/test_session*.py` | No disponible: `pytest: command not found`; `python3 -m pytest` tampoco está instalado. No se instalaron dependencias. Se ejecutaron las mismas clases unittest con los comandos siguientes. |
| `python3 -m unittest discover -s tests/shell -p 'test_kwin.py' -v` | 17 correctas. Incluye formatos antiguos, restauración exacta, recuperación previa al snapshot, material nuevo, fallos/atomicidad y KConfig CLI real en XDG temporal. |
| `python3 -m unittest discover -s tests/shell -p 'test_session*.py' -v` | 18 ejecutadas: 17 correctas, 1 omitida por socket D-Bus privado prohibido. |
| `python3 -m unittest discover -s tests/shell -p 'test_shortcuts.py' -v` | Compilación y prueba de codec/conflictos correctas; 1 prueba D-Bus omitida por sandbox. Caso nuevo prepara un backup legado, restaura y verifica que arranque sin backup no crea uno. |
| `SINGLR_BUILD_DIR=/tmp/t272-shell-build python3 -m unittest discover -s tests/shell -p 'test_tray.py' -v` | 3 correctas, 1 D-Bus omitida; backend nativo compilado, prueba windowed sin backend correcta. |
| `python3 -m unittest discover -s tests/shell -p 'test_packaging.py' -v` | 5 correctas. |
| `SINGLR_BUILD_DIR=/tmp/t272-shell-build shell/session/build.sh` | Correcto. Aviso previo de LayerShellQt::Shell::useLayerShell obsoleto. |
| `cmake -S . -B /tmp/t272-cmake -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib -DSINGLR_BUILD_LIQUIDGLASS=OFF` y `cmake --build /tmp/t272-cmake --parallel 2` | Correctos; nuevo módulo sin WorkspaceBridge y shell compilados. Plugin de vidrio fuera de este check. |
| `DESTDIR=/tmp/t272-stage cmake --install /tmp/t272-cmake` y `python3 tests/shell/verify_package.py /tmp/t272-stage` | Correctos; payload, fuentes, ejecutables y rutas de sesión verificados. Paquetes de Workspace retirados ausentes del staging. |
| `SINGLR_TEST_BUILD_DIR=/tmp/t272-cmake tools/test-qml.sh` y variante `--light` | Por modo: 244 shell + 11 Ajustes correctas, 0 fallos, 5 capturas opcionales omitidas. Offscreen/software. |
| `python3 scripts/doctor.py` | Inventario correcto; no prueba integración. |
| `python3 scripts/check_setup.py`; `git diff --check` | Correctos en entrega final. |

La primera pasada QML detectó una expectativa de anchura anterior al botón siempre
visible (131 frente a 169 px); se ajustó esa prueba y la pasada final quedó verde.
La búsqueda `rg -n "singlr-overview|singlr-gestures|Singlr Overview|tabbox/singlr"`
solo conserva documentación histórica/handoff y lógica de migración (claves,
identificadores de descarga y lista de acciones restaurables).

Logs de esta ejecución: `/tmp/t272-{kwin-final,session,shortcuts,tray,packaging}.log`,
`/tmp/t272-{build,cmake,stage,qml-final,qml-light}.log`.

## Pendientes para Claude

- Ejecutar pytest cuando esté disponible. Repetir pruebas de D-Bus privado fuera
  del sandbox: falla `bind` con `Operation not permitted`, no la compilación.
- Verificar en sesión aislada con KWin real: botón Overview, restauración de backup
  de atajos/journal de una instalación previa, gestos físicos, esquinas, autohide
  y conservación de preferencias personalizadas. QML software no prueba GPU ni
  integración con KWin. No se intentó tocar el compositor activo.
- Actualizar el paquete en el flujo autorizado; comprobar retirada por pacman de
  archivos antiguos. No se borraron copias manuales ni symlinks del usuario.
- Revisión y commit por Claude. No se hizo commit ni push.
