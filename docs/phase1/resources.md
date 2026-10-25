# Recursos del shell — P-016 / T230

P-016 es una decisión explícita del creador: PSS propia < 120 MB y CPU en reposo
prácticamente cero. T230 concreta el check de CPU en < 0,5 %. Se usan **MB decimales**
(120 000 000 bytes), límites estrictos y CPU donde 100 % equivale a un núcleo lógico.
El método, los tiempos y el instrumental siguientes son soluciones técnicas derivadas;
no aprueban decisiones visuales ni demuestran cumplimiento en otros equipos.

## Ejecutar fuera del sandbox

Desde este checkout, en la sesión Wayland anfitriona, sin sudo y sin cerrar Plasma:

```bash
# Base y comparación secuencial; ~50 s de muestra/reposo por sesión + arranque/cierre.
tools/measure-resources.sh --compare-plasma --output /tmp/singlr-resources-idle

# Base, recorrido de tres paneles y medida posterior al cierre (~115 s + arranque).
tools/measure-resources.sh --scenario open-panels --output /tmp/singlr-resources-panels

# Diagnóstico separado: tiene coste y no debe sustituir la medida principal.
tools/measure-resources.sh --scenario open-panels --profile --output /tmp/singlr-resources-profile
```

Las carpetas de salida deben ser nuevas o vacías. `--size 2048x1280` es el valor
predeterminado; mantener tamaño, escala, hardware, alimentación y carga del host
iguales al comparar revisiones. Repetir tres veces con rutas nuevas y conservar cada
resultado; no interpretar una diferencia pequeña aislada como fuga.

Requiere las herramientas de `tools/run-singlr.sh`, compilador/dependencias del
lanzador, `qdbus6` y, para comparación, `plasmashell`. No instala paquetes.
Antes de medir compila el lanzador (`build.log`). Un error de arranque, permisos de
`/proc`, D-Bus, escenario o limpieza produce FAIL y salida 1, al igual que superar
el presupuesto. JSON y tabla se guardan en `results.json` y `results.md`; la tabla
se imprime también en terminal. Los errores quedan en JSON, no se convierten en ceros. Cada sesión conserva además
`samples.json` con las filas ya obtenidas, incluso si el recorrido posterior falla.

El runner invoca `run-singlr.sh` para cada sesión, una después de otra. La variante
`--client plasma` inicia **plasmashell en lugar de Singlr**, con bus, KWin, runtime y
configuración XDG temporales nuevos. No inicia un escritorio Plasma completo ni
replica los servicios de la sesión habitual. Solo mide `krunner` si se activa en ese
bus; no lo fuerza a arrancar. Se comprueba la limpieza y el hash de la configuración
KDE del host con el contrato existente del runner. No se instala ni modifica KDE.

## Método y alcance de los números

- Descubrimiento por nombre exacto de `/proc/<pid>/comm` **y** entrada NUL exacta
  `SINGLR_SESSION_ID` en `/proc/<pid>/environ`. Nunca se selecciona el Plasma del host.
  Se comprueba `starttime` para detectar reutilización de PID.
- Tras encontrar el cliente, espera 20 s de reposo. Lee `smaps_rollup`: PSS total,
  Pss_Anon, Pss_File, Pss_Shmem y RSS; kB del kernel se convierte multiplicando por
  1024. Un desglose que el kernel no exponga queda `null`/N/D. La memoria reportada
  corresponde al final de la muestra; no es un pico ni una media.
- CPU durante 30 s mediante delta de `utime+stime` de `/proc/<pid>/stat`, dividido
  por `CLK_TCK` y tiempo monotónico real. Incluye todos los hilos del proceso, excluye
  CPU de hijos. Hilos: `num_threads` al final de la muestra.
- `scheduler_timeslices` suma deltas del tercer campo de `task/<tid>/schedstat` de
  todos los hilos. Si no se puede leer o cambia el conjunto de TID, queda `null`.
  **No es un contador de despertares**: el kernel describe este campo como turnos de
  ejecución. `wakeups` queda `null`, porque `schedstat` no los expone. Ceros pueden
  indicar estadísticas del scheduler desactivadas; no prueban ausencia de despertares.
- Ventanas: snapshot por scripting de KWin privado antes del intervalo de CPU,
  filtrado por PID, guardado en cada fila JSON. Incluye `hidden`, tamaño y geometría.
  KWin solo conoce superficies que recibió: ventanas Qt nunca mapeadas se consultan
  con el perfil del lanzador. Se reutiliza el helper de `tests/shell/e2e.py`.
- `open-panels` solo se aplica a Singlr: invoca `toggleLauncher`, `toggleControlCenter`
  y `toggleNotifications` por D-Bus, uno cada vez; espera 2 s tras cada toggle y
  verifica aumento de superficies visibles al abrir y vuelta al número inicial al
  cerrar. Guarda snapshots de apertura. Espera otros 20 s y repite muestra de 30 s.
  `pss_delta_bytes` compara after-close con idle; puede reflejar cachés o modelos
  retenidos, y no acredita por sí solo una fuga ni liberación completa.
- En comparación, Plasma y KRunner tienen filas y checks individuales; no se suman
  para fingir PSS propia de Singlr. KWin y otros servicios están excluidos. GPU/VRAM
  no mapeada en el proceso y coste total del escritorio tampoco están incluidos.
  `--compare-plasma --scenario open-panels` compara reposo con Plasma y recorre
  paneles únicamente en Singlr.

## Perfil del lanzador

```bash
SINGLR_PROFILE=1 tools/run-singlr.sh
# En el bus PRIVADO anunciado por SINGLR_SESSION_FILE (no en el bus del host):
# qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.singlrProfile
```

Solo con `SINGLR_PROFILE=1` se activa `QSG_INFO=1` antes de construir la aplicación.
Se vuelca `SINGLR_PROFILE {json}` al inicio, a los 20 s y por petición D-Bus
(`--profile` pide además el volcado final). Registra todas las `QQuickWindow`,
visibles u ocultas, clase/nombre, tamaño lógico, DPR y estado del scene graph.
Registra el número de descendientes QObject vivos por raíz del engine: no equivale
al número de objetos QML creados por cada componente ni incluye toda propiedad JS.
No añade un temporizador de muestreo continuo.

Qt 6.12 no ofrece un registro público global de texturas ni de temporizadores QML.
`textureBytes` y `qmlActiveTimers` son `null`; `QSG_INFO` aporta diagnóstico del backend,
no una cifra portátil de VRAM. `graphicsStateInfo()` describe frames en vuelo, sin
exponer memoria de texturas. No se usan APIs privadas ni se provoca renderizado de
ventanas ocultas para estimarlo. El cumplimiento de «panel cerrado sin GPU/modelos»
requiere revisar estos logs junto con el código y, si hace falta, un perfil GPU externo.

APIs contrastadas en este equipo: Qt Quick 6.12.0 (`pkg-config`), KWin 6.8.1
(`kwin_wayland --version`). Referencias oficiales:
[GraphicsStateInfo](https://doc.qt.io/qt-6/qquickwindow-graphicsstateinfo.html),
[scene graph / QSG_INFO](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html),
[KWin scripting API](https://develop.kde.org/docs/plasma/kwin/api/),
[proc](https://docs.kernel.org/filesystems/proc.html),
[schedstat](https://docs.kernel.org/scheduler/sched-stats.html).

## Verificación técnica

```bash
python3 -m unittest discover -s tests/shell -p test_resources.py -v
python3 -m unittest discover -s tests/shell -p test_session.py -v
shell/session/build.sh
PYTHONPATH=tests/shell python3 -m unittest test_packaging.PackagingTests.test_reload_bridge -v
```

Las pruebas sintéticas validan parsers, selección de sesión y aislamiento del cliente
Plasma con ejecutables simulados; no miden rendimiento ni acreditan interacción real.
Las medidas reales y la revisión de logs quedan para Claude fuera del sandbox.

## Resultados pendientes

| Revisión / equipo / fecha | Proceso | Escenario / fase | PSS MB | anon MB | file MB | RSS MB | Hilos | CPU % | Ventanas KWin | Turnos scheduler | Delta PSS MB | PASS/FAIL | Evidencia |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| | | | | | | | | | | | | | |
