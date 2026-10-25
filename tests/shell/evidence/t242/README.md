# T242 — entrega a Claude

Sin commit. `Appearance.qml` intacto. Rama `day2/codex1-dock-launcher`.

## Resultado

- Dock: orden manual común para fijados y aplicaciones abiertas; `move` + `syncLaunchers`, `launcherList` persistida y orden adicional por identidad para restaurar aplicaciones que siguen abiertas. Meta+1…9 sigue ese orden. Soltar fuera o sobre el botón de apps no quita ni reordena aplicaciones. El movimiento se confirma al soltar sobre otro icono, sin animación.
- Fijar/quitar desde ambos menús. El lanzador obtiene `favoriteId` de Kicker o normaliza el URL desktop de KRunner mediante KService para evitar duplicados.
- Archivos: `requestOpenUrls` abre con el servicio del icono; se acepta y resalta solo si todos los archivos son compatibles, incluida la herencia MIME. URLs remotas solo para servicios que declaran su esquema; no se consulta contenido remoto durante el arrastre.
- Lanzador: favoritos de ResultsModel `calculator`, `unitconverter` para prioridad; Enter copia el texto del resultado. Categorías nativas, encabezados discretos y desplazamiento interno en la altura existente de 542 px. `ContextMenu` compartido por clic derecho, tecla Menú y Ctrl+K; conserva el índice original de cada acción KRunner. Mostrar en carpeta usa `org.freedesktop.FileManager1.ShowItems`.
- Bloqueo: teclado virtual Phosphor sin etiqueta visible y con nombre accesible. El nombre de la distribución de teclado se conserva porque indica el estado actual, sin su icono redundante.

La ampliación C++ fue autorizada expresamente. Se añadieron KService/QMimeDatabase al puente existente, normalización de URL de aplicación y ShowItems. También se ajustaron CMake, build.py y los dos tests que compilan system.cpp directamente. Son soluciones técnicas derivadas de T242; no se cambian tokens ni decisiones visuales. Claude puede registrar la integración en docs/handoffs y docs/decisions.

## Evidencia

Qt 6.12.0, Plasma/Milou 6.8.1, KRunner 6.31.0. APIs verificadas en qmltypes/cabeceras locales y fuentes KDE:

- https://raw.githubusercontent.com/KDE/plasma-workspace/master/libtaskmanager/tasksmodel.cpp
- https://raw.githubusercontent.com/KDE/plasma-workspace/master/runners/calculator/calculatorrunner.cpp
- https://raw.githubusercontent.com/KDE/plasma-workspace/master/runners/services/servicerunner.cpp

[Preview del lanzador](launcher.png): datos de prueba, renderer software, superficie de sesión. Conserva tipografía, color, radios, iconos y material de Singlr.Ui; agrupa resultados sin añadir texto repetido ni alterar la geometría. No acredita composición con KWin ni aprobación visual del creador.

Ejecutado:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME= \
DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/t242-disabled \
XDG_CONFIG_HOME=/tmp/t242-env/config XDG_CACHE_HOME=/tmp/t242-env/cache \
/usr/lib/qt6/bin/qmltestrunner -import shell/qml -input shell/qml/tests
python3 -m unittest discover -s tests/shell -p 'test_*.py'
tools/check-shell.sh --output /tmp/t242-shell.png
python3 scripts/check_setup.py
git diff --check
```

Resultados: QML **150 correctas**; Python **72 pruebas, OK, 3 omitidas** (bus privado no disponible). Check shell **PASS**: lint, carga offscreen y PNG. Setup y whitespace correctos. Pruebas nuevas: cálculo/conversión al portapapeles, acciones por ratón/teclado, fijar/quitar en ambos modos del lanzador, archivos y geometría; dock con doble TasksModel para despacho/MIME y TasksModel real para persistencia y arrastre; MIME C++ con archivos temporales, texto heredado, carpetas, tipos mezclados, faltantes y remotos. ShowItems se prueba con un receptor simulado en bus privado, pero aquí se omite por sandbox.

Medición intentada:

```sh
tools/measure-resources.sh --scenario open-panels --output /tmp/t242-resources
```

Bloqueada antes de iniciar KWin: `dbus-daemon: Failed to bind socket: Operation not permitted`. Sin cifras de rendimiento. Registro `/tmp/t242-resources/singlr/session.log`: limpieza sin procesos restantes y `SINGLR_HOST_CONFIG ... equal=True`. Claude debe medir fuera de este sandbox antes de integrar (P-016).

## Validación anidada pendiente para Claude

Desde este worktree, en un entorno que permita crear el bus privado:

```sh
tools/run-singlr.sh --duration 180
```

El comando imprime `SINGLR_SESSION_FILE`; importar **solo en una terminal auxiliar** el entorno privado de ese JSON (como los probes existentes). No importar en el bus anfitrión ni reiniciar su shell. Dentro del entorno privado:

```sh
printf 'T242 — archivo de prueba\n' > /tmp/singlr-t242.txt
kate /tmp/singlr-t242.txt
# Alternativa si Kate está solo en Flatpak: flatpak run org.kde.kate /tmp/singlr-t242.txt
dolphin /tmp
```

1. Abrir Todas las aplicaciones, menú de una app → Mantener en el dock; comprobar el menú inverso y persistencia tras relanzar el shell privado.
2. Arrastrar fijados y apps abiertas entre sí; comprobar Meta+1…9, botón de apps inmóvil y que soltar fuera conserva el icono.
3. Arrastrar `singlr-t242.txt` desde Dolphin a Kate: destino resaltado y archivo abierto. Arrastrar `/tmp` a Dolphin: aceptar carpeta. Probar un tipo incompatible y una selección mixta: sin resaltar ni abrir.
4. Meta → `2+2`: primera fila `4`, Enter copia. Meta → `10 km a mi`: resultado de unitconverter según la sintaxis/localización de KRunner; Enter copia. Si el runner local exige `to`, comprobar también `10 km to mi` y registrar la limitación de idioma de KDE.
5. Buscar un archivo indexado por Baloo o su ruta absoluta (`/tmp/singlr-t242.txt`, runner locations). Enter abre; Ctrl+K → Mostrar en carpeta selecciona el archivo. Probar acciones KRunner con clic derecho, Ctrl+K, flechas, Enter y Escape.
6. Revisar bloqueo en la sesión de prueba: icono de teclado virtual, foco Tab y nombre accesible.

No se ejecutaron estos recorridos en KWin ni se bloqueó la sesión diaria.
