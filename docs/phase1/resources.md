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

# Base, recorrido de cuatro paneles, muestras abiertas y posterior al cierre (~240 s + arranque).
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
- `open-panels` solo se aplica a Singlr: invoca `toggleLauncher`, `toggleControlCenter`,
  `toggleNotifications` y `toggleClipboard` por D-Bus, uno cada vez; espera 2 s tras cada toggle y
  verifica aumento de superficies visibles al abrir y vuelta al número inicial al
  cerrar. Guarda snapshots y una muestra de 30 s con cada panel abierto. Espera otros 20 s y repite muestra de 30 s.
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

## Resultados (25 oct 2026, Radeon 610M, 2560×1600 a 1,25)

| Medida | plasmashell | singlr-shell |
| --- | ---: | ---: |
| Sesión aislada en reposo, PSS | 207 MB | 84 MB |
| Sesión aislada tras abrir y cerrar paneles | — | 91 MB |
| Sesión real del creador (sus widgets, fondo y bandeja), 60 s en reposo, PSS | 254 MB | 151 MB |
| Sesión real, CPU en reposo (10 s) | 0 ticks | 1 tick (0,1 %) |

Antes de la optimización (P-016), la sesión real de Singlr estaba en ~208 MB.

## T245 — accesibilidad y medición ampliada (25 oct 2026)

**No hay cifras nuevas de PSS/CPU en esta entrega.** Los intentos antes y después
fallaron antes de iniciar el shell: `dbus-daemon` no puede enlazar el socket privado
(`Operation not permitted`, salida 127). El sandbox tampoco permite conectar al bus
anfitrión ni muestra PID de `singlr-shell`, `plasmashell` o `ksmserver`. No se ha
recargado ni alterado la sesión del creador.

| Medida T245 | Antes (base de main al iniciar) | Después (rama T245) |
| --- | --- | --- |
| PSS shell / ksmserver | N/D | N/D |
| CPU reposo / panel abierto / tras cerrar | N/D | N/D |
| GPU / modelos tras cerrar | Sin perfil real | Sin perfil real |
| Inicio de sesión anidada | Bloqueado por socket D-Bus | Bloqueado por socket D-Bus |

Los 84/91 MB aislados, 151 MB de Singlr real y 207/254 MB de Plasma del apartado
anterior son **medidas históricas**, no resultados de T245. Los 151 MB históricos
superan el límite propio de 120 MB: no se da por resuelto ese incumplimiento ni se
atribuye una mejora a estos cambios. No se ha eliminado funcionalidad para reducir
consumo. Evidencia de los intentos y pruebas:
[`tests/shell/evidence/t245/`](../../tests/shell/evidence/t245/README.md).

### Cambios del medidor

- `open-panels` recorre ahora lanzador, centro de control, notificaciones y
  portapapeles. Además del reposo y del estado final, registra 30 s de CPU/PSS con
  **cada panel abierto**. El recorrido tarda aproximadamente cuatro minutos más el
  arranque/cierre. Conserva `samples.json` después de cada muestra.
- Si `ksmserver` existe con el marcador privado, se registra como proceso separado.
  `session-components.json` registra también si existe el locker. El runner de shell
  aislado no inicia una sesión completa con ksmserver: su ausencia no equivale a un
  coste de 0 MB en la sesión instalada.
- Klipper vive dentro del shell y `Singlr.System` es un módulo del mismo proceso:
  ambos están incluidos en su PSS; no se les asigna una PSS independiente ficticia.
  El locker se comprueba fuera del bloqueo, sin iniciarlo para medir reposo.
- El límite de memoria se aplica al shell/KRunner; los auxiliares tienen filas
  separadas. CPU < 0,5 % se exige en reposo y tras cerrar, no durante el uso de un
  panel. La columna de presupuesto no acredita VRAM ni ausencia de modelos.
- `--existing-pid` permite una muestra de solo lectura de 30 s de PID explícitos
  del usuario (`singlr-shell`, `plasmashell`, `krunner`, `ksmserver` o
  `kscreenlocker_g`). No necesita controlar KWin ni reiniciar sesiones. Comprueba
  identidad/starttime; si un proceso desaparece, falla. Sin acceso a KWin, ventanas
  quedan `null`/N/D, no 0.

Para comparar las sesiones reales, ejecutar en cada una tras 20 s de reposo, con
los PID actuales del shell y de ksmserver (sustituir los números):

```bash
tools/measure-resources.sh --existing-pid 1234 --existing-pid 1235 \
  --phase idle --output /tmp/t245-singlr-real-idle
# Abrir el panel manualmente y mantenerlo abierto durante la muestra:
tools/measure-resources.sh --existing-pid 1234 --existing-pid 1235 \
  --phase open-panels --output /tmp/t245-singlr-real-panel
# Cerrar, esperar 20 s, repetir con --phase after-close y otra salida.
# Repetir con plasmashell/ksmserver en la sesión Plasma, mismo equipo y carga.
```

Para la comparación aislada y perfil de liberación:

```bash
tools/measure-resources.sh --compare-plasma --scenario open-panels \
  --output /tmp/t245-comparison
# Perfil separado, con su coste diagnóstico:
tools/measure-resources.sh --scenario open-panels --profile \
  --output /tmp/t245-profile
```

La revisión de código y las pruebas de ciclo de vida confirman que las superficies
nativas se destruyen al cerrar y los `DeferredLoader` liberan contenido tras su
caché de 2500 ms (más 500 ms para GC/trim). **No equivale a liberar modelos de forma
instantánea**, ni demuestra que el driver devuelva toda su memoria GPU. Falta el
perfil real para acreditar P-016 de extremo a extremo.

### Movimiento y contratos de accesibilidad

Qt Quick 6.12.0, KWin/Plasma 6.8.1, Kirigami y qqc2-desktop-style 6.31.0,
qqc2-breeze-style 6.8.1. `Motion` consume `org.kde.kirigami.platform.Units`, la
misma duración de plataforma usada por los componentes Plasma instalados
(`/usr/lib/qt6/qml/org/kde/plasma/extras/animations/AppearAnimation.qml`).
La integración KDE observa `kdeglobals [KDE] AnimationDurationFactor`; evita un
lector propio o un temporizador de sondeo. Units limita `longDuration` a 1 ms;
Singlr convierte ese caso a transiciones de 0 ms y detiene el spinner infinito.
Se verifican perfiles XDG temporales con factor 0 y 2, sin escribir kdeglobals del
usuario. El cambio en ControlCenter se limita a foco, semántica y duraciones;
TopBar y Theme no cambian.

Referencias de API: [Units de Kirigami](https://api.kde.org/qml-org-kde-kirigami-platform-units.html),
[accesibilidad Qt Quick](https://doc.qt.io/qt-6/qml-qtquick-accessible.html).
La verificación QML de nombres/roles/acciones y foco no sustituye la prueba AT-SPI
con Orca en Wayland. `tools/check-atspi.py` permite obtener ese árbol real por
D-Bus sin python3-atspi; la evidencia de este entorno es de **bloqueo**, no un árbol
validado. El retorno a una aplicación real al retirar las superficies queda
pendiente de esa sesión anidada; no se fuerza la activación de otra app desde QML.


## 25 oct (Claude): fondo real y asignador de glibc

Medición aislada (`tools/measure-resources.sh`, 2560×1600): fondo por defecto 90,7 MB; con el
fondo PNG 2560×1600 del creador **151 MB**. Con `MALLOC_MMAP_THRESHOLD_=131072` el mismo caso
da 91,6 MB: no era la textura, sino los temporales de decodificación retenidos por el umbral
dinámico de mmap de glibc. Corrección: `mallopt(M_MMAP_THRESHOLD, 128 KiB)` al arrancar y
`trimMemory()` al quedar listo el fondo. Resultado con el fondo real: **91,6 MB** en reposo,
98–105 MB con paneles abiertos, CPU en reposo ≈ 0. Plasma aislado: 93,8 MB.

## T255 — diagnóstico aislado (26 oct 2026)

Se mantuvo la sesión del creador intacta. Base: Qt 6.12.0, KWin 6.8.1, salida
anidada solicitada 2048×1280 / escala 1,25, fondo sólido, configuración privada
nueva; no replica el fondo, aplicaciones, historial ni bandeja del creador.
GPU/backend exactos no quedaron registrados en las muestras: no atribuir resultados
a una GPU concreta. Cada fase registra 30 s de CPU y PSS al final de la muestra.

| Escenario | PSS MB | CPU % | Resultado |
| --- | ---: | ---: | --- |
| Reposo, atlas automático Qt | 83,47 | 0,033 | Dentro de P-016 en esta fixture |
| Reposo, atlas 1024×1024 (experimento externo) | 85,79 | 0,000 | Sin mejora; no se incorpora |
| Recorrido de paneles: reposo inicial | 85,34 | 0,000 | Dentro de P-016 |
| Lanzador abierto | 91,91 | 0,267 | Dentro del límite de memoria |
| Centro de control abierto | 95,30 | 0,033 | Dentro del límite de memoria |
| Notificaciones abiertas | 93,83 | 0,067 | Dentro del límite de memoria |
| Portapapeles abierto | 94,04 | 0,233 | Dentro del límite de memoria |
| Tras cerrar los cuatro paneles | 90,75 | 0,000 | Tres superficies base; +5,41 MB frente al inicio |

La diferencia entre las dos medidas de atlas no permite una conclusión de ahorro;
no se cambia la configuración gráfica del producto. El recorrido confirmó apertura
y cierre de superficies en KWin privado, con limpieza `remaining=[]` y hashes del
host iguales. Un panel abierto se considera uso, no CPU de reposo. No acredita
liberación total de GPU/modelos ni ausencia de fugas por una sola ejecución.

Evidencia filtrada: [T255](../../tests/shell/evidence/t255/README.md).
La muestra histórica de sesión real de 167,75 MB sigue fuera de presupuesto;
**estas cifras aisladas no resuelven P-016 de la sesión instalada**.

Se ensayó además `QQmlEngine::trimComponentCache()` antes de `malloc_trim`,
con API pública y binario de prueba separado. Resultado: 85,84 MB al inicio y
91,00 MB tras cerrar los cuatro paneles (+5,16 MB). La base dio 85,34 / 90,75 MB
(+5,41 MB). Son ejecuciones individuales, con variación de cachés/bibliotecas y
un refinamiento del reajuste del viewport entre ambas: no es una serie controlada
ni acredita ahorro. **El experimento se retiró**; el runtime conserva su
comportamiento anterior. Fuente de la API:
[QQmlEngine](https://doc.qt.io/qt-6/qqmlengine.html#trimComponentCache).

Tras dos enfoques sin mejora útil (atlas y metadatos), el siguiente paso es un
perfil de asignaciones en sesión desechable con fondo, escala y bandeja equivalentes
a la sesión real, seguido de una comparación antes/después. No hay heaptrack
instalado en el inventario de esta entrega; no se instalaron paquetes ni se adjuntó
un depurador al shell del creador. No se sacrificaron funciones para bajar la cifra.

## T257 — iconos del dock (26 oct 2026)

Medida puntual en sesión KWin privada nueva, fondo sólido y datos nuevos:
93,45 MB PSS (67,18 MB anónimos), CPU 0,033 % / 30 s, tres superficies.
Salida solicitada 2048×1280; no se registró backend/GPU efectivo en esta muestra.
Limpieza `remaining=[]` y hashes host iguales. Está dentro del límite en esta
fixture, **sin comparación A/B equivalente** y sin acreditar P-016 en sesión real.

El helper guarda solo hasta 128 rectángulos de alfa, no pixmaps; mide a 128 px
cuando cambia el icono, sin trabajo por frame. Kirigami conserva la rasterización;
una fuente fija de 128 px evita ampliar bitmaps elegidos por tamaños intermedios.
El coste de esas texturas sí existe y no se presenta como una optimización de
memoria. [Evidencia filtrada](../../tests/shell/evidence/t257/README.md).

## T258 — pegado del historial (26 oct 2026)

Mismo procedimiento privado de measure-resources.sh: 93,94 MB PSS (67,53 MB
anónimos), CPU 0 % / 30 s, tres superficies, 37 hilos. Limpieza sin procesos y
hashes host iguales. Sin A/B ni certificación del presupuesto en sesión real.
El puente conserva metadatos de ventanas y referencias; no duplica historial o
contenido. Reintento 15 ms y límite 1500 ms solo mientras hay una solicitud;
ambos se detienen al completar o cancelar.


## T273 — orden de copia del historial (28 oct 2026)

Muestra privada de measure-resources.sh: 79,37 MB PSS, 61,03 MB anónimos,
0,100 % CPU, 35 hilos y tres superficies. Sin A/B ni certificación de sesión real.
El proxy retiene solo una lista de UUID y escribe cuando cambia el orden o se
eliminan entradas; la selección no escribe metadatos nuevos. Sin polling de reposo.
