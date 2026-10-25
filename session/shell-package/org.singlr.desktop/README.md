# Pantalla de bloqueo Singlr — T240

Propuesta visual para revisar; no constituye aprobación de nuevos tokens. Paquete
`Plasma/Shell`, API 2, instalado en `share/plasma/shells/org.singlr.desktop`.
`X-Plasma-FallbackPackage` delega a `org.kde.plasma.desktop` los archivos ausentes;
la prueba con KPackage real comprueba el bloqueo propio y el logout de KDE.
La sesión exporta `PLASMA_DEFAULT_SHELL` antes de iniciar KWin y restaura su valor
anterior al salir. No se escribe `plasmashellrc`; su selección explícita de paquete,
si existe, tiene prioridad sobre la variable. Plasma conserva su paquete.

## Procedencia y contrato

Base: los archivos de `/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen`
de plasma-workspace 6.8.1, contrastados con kscreenlocker 6.8.1 y Qt 6.12.0.
Se mantienen sus avisos SPDX. Los componentes Breeze de avatar, acciones y batería,
y los modelos KDE de accesibilidad, autenticación, teclados, sesión y MPRIS se
reutilizan. No se implementa ni sustituye PAM.

Se mantienen contraseña sincronizada entre pantallas, mensajes PAM, métodos de
huella/tarjeta y otros métodos configurados, confirmación de desbloqueo sin prompt,
cambio de usuario/suspensión/hibernación según capacidades, teclado virtual de KWin,
distribuciones, Bloq Mayús/teclas lentas, batería, controles multimedia y OSD.
El éxito siempre lo valida el greeter nativo; Qt.quit no elude su comprobación.

**Corrección técnica derivada:** el QML de Plasma instalado todavía referencia
`pamTimeout`, pero el greeter 6.8.1 publica `inPasswordDelay`. La flecha y Enter
quedan bloqueados durante esa espera; no se guarda una contraseña pendiente en
otra propiedad QML. El usuario puede volver a enviar al terminar la espera.
El contrato está en los qmltypes instalados y en `greeter/pamauthenticators.h`.

**Aislamiento técnico derivado:** se copian `Theme.qml`, `Theme.js`, `Appearance.qml`,
`Wallpaper.qml`, `Icon.qml` e `Icons.js` desde `shell/qml/Singlr/Ui`; Theme solo cambia
las rutas de fuentes. El greeter no hereda la ruta QML del ejecutable Singlr ni sus
singletons C++. Los tokens mantienen el mismo cálculo perceptual y preferencias
`singlr/singlr.conf`. Al cambiar esos archivos en la shell hay que sincronizar las
copias. CMake instala Inter, Phosphor y sus licencias dentro del paquete.

## Composición

Hora grande (80 px, Inter Medium, actualización por minuto), fecha secundaria,
avatar/nombre KDE y una única entrada de 44 px con candado y flecha Phosphor,
revelado de contraseña accesible y manejo de Enter. Superficie neutra translúcida,
radio 8 px, bordes de foco y colores del tema existente. Sin entrada animada,
fundidos de fondo ni sacudidas de error. La zona de mensajes reserva 64 px con
scroll interno: los errores no desplazan el campo. Multimedia reserva su altura.
La composición completa puede desplazarse en pantallas bajas.

El fondo es el configurado en Singlr, desenfocado con FastBlur cacheado en GPU;
el plugin independiente de fondo KDE queda oculto. Software usa el mismo fondo
oscurecido, con base opaca y contraste suficiente, sin exigir shaders. No se captura
el escritorio. Ver [FastBlur de Qt](https://doc.qt.io/qt-6/qml-qt5compat-graphicaleffects-fastblur.html).
No se añaden temporizadores decorativos; se conserva el heartbeat de autenticación
original de KDE cuando la entrada está visible.

## Verificación reproducible

Desde la raíz del repositorio:

```bash
python3 -m unittest discover -s tests/shell -p test_lockscreen.py -v
python3 -m unittest discover -s tests/shell -p test_session_entry.py -v
python3 scripts/check_setup.py
tools/check-cmake.sh
lock=session/shell-package/org.singlr.desktop/contents/lockscreen
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml -i "$lock/qmldir" "$lock"/*.qml
```

`test_lockscreen.py` comprueba KPackage real y nueve resultados QtTest (incluidos
init/cleanup): estabilidad del campo ante errores largos/media, salida pequeña,
respuesta vacía, espera/reintento, ocultación, limpieza y Enter. La prueba de campo
usa dobles explícitos de frontera, no acredita una conversación PAM real.
El lint completo conserva avisos `unqualified` por contexto dinámico del greeter y
`missing-type` de `ActiveScreenMonitor.lockscreenState`, también presente en KDE.
Los cinco componentes visuales propios pasan `--max-warnings 0` con los imports
anteriores. La carga nativa offscreen acredita resolución, sin fallback ni error QML;
no acredita los servicios de la sesión.

Capturas: `tests/shell/evidence/t240/software.png` y `error-synthetic.png`.
Son del greeter real en offscreen/software a 1280×900, obtenido con una sonda temporal
que hace visible la entrada y captura QQuickWindow. La segunda inyecta únicamente
un mensaje de error sintético; no es evidencia de fallo PAM real. Se envió solo una
entrada vacía. El worker PAM no pudo iniciar dentro del sandbox (bus/Wayland
restringidos), según `greeter-offscreen.log`. GPU, huella, batería, MPRIS y cambio
de usuario requieren comprobarse en la sesión de prueba real.

## Para Claude: prueba gráfica fuera del sandbox, sin instalar en el host

```bash
stage=$(mktemp -d /tmp/singlr-lockscreen.XXXXXX)
DESTDIR="$stage" cmake --install build
# En terminal gráfica; --testing abre una ventana y NO bloquea la sesión.
env XDG_DATA_DIRS="$stage/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    QML2_IMPORT_PATH=/usr/lib/qt6/qml QT_FORCE_STDERR_LOGGING=1 \
    /usr/lib/kscreenlocker_greet --testing --shell org.singlr.desktop \
    2>"$stage/greeter.log"
# Tras guardar la evidencia, eliminar solo el staging creado arriba.
rm -rf -- "$stage"
```

Capturar reposo, entrada enfocada y error tras **Enter vacío**, sin teclear la
contraseña real. Comprobar Tab/Shift+Tab, Escape, revelado, Bloq Mayús, distribución,
teclado virtual, escalado/salida pequeña y dos monitores; métodos de huella/tarjeta,
media y batería si están disponibles. No ejecutar cambio de usuario ni suspensión
sobre la sesión cotidiana para esta comprobación. Registrar capacidades ausentes.

Antes de integrar, ejecutar también `tools/measure-resources.sh --output /tmp/t240-resources-host`
fuera del sandbox para la regresión del shell (P-016). Esa herramienta mide los
clientes del shell anidado, no el proceso greeter: la PSS/CPU del greeter necesita
una muestra separada con y sin interfaz visible, y contraste con el paquete KDE.

## Resultado de esta entrega

- `tools/check-cmake.sh`: compilación e instalación DESTDIR correctas; el verificador
  exige el nuevo paquete y resuelve sus dos fuentes.
- `test_session_entry.py`: 14 pruebas correctas. Importación antes de KWin,
  eliminación/restauración del paquete previo también al fallar el arranque.
- `test_lockscreen.py`: KPackage correcto y 9 resultados QtTest correctos.
- `scripts/check_setup.py`: correcto. `git diff --check`: correcto.
- `qmllint`: ejecutado con qmldir/imports reales; 86 avisos de contexto dinámico y
  uno de tipo incompleto de KDE; cero avisos en los cinco componentes visuales
  comprobados con `--max-warnings 0`.
- `kscreenlocker_greet --testing --shell org.singlr.desktop`: carga nativa propia
  offscreen/software sin fallback ni errores QML. PAM no operativo en el sandbox;
  el envío vacío no llegó a un prompt. Capturas e inyección sintética documentadas.
- `tools/measure-resources.sh --output /tmp/t240-resources`: intentado, sin muestra;
  `dbus-daemon: Failed to bind socket ... Operation not permitted`. Limpieza y
  configuración del host verificadas por el propio script (`equal=True`).

Pendientes de Claude: captura GPU, conversación PAM con respuesta vacía, hardware,
monitores/escalado y medición P-016. Trasladar las dos soluciones técnicas derivadas
al registro de decisiones al integrar; este encargo limita escritura al paquete,
CMake, una línea de la sesión y pruebas. Sin commit ni cambios a la sesión activa.
