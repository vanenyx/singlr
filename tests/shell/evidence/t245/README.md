# T245 — evidencia y límites

Rama `day3/codex2-a11y-perf`, base de main, 25 oct 2026. Sin commit, sin recarga de la
sesión anfitriona. No hay decisiones visuales nuevas; los cambios QML son de
accesibilidad, foco y movimiento.

## Ejecutado

- `shell/session/build.sh` y `cmake --build build -j2`: compilación correcta.
- Pruebas QML siempre mediante `tools/test-qml.sh`. Perfiles temporales con
  `SINGLR_TEST_ANIMATION_FACTOR=0` y `=2`: véase `verification.txt` para los totales
  finales y duraciones observadas. Se prueban Tab/flechas/Enter/Esc, retorno del
  foco desde menú contextual, nombres/roles, acciones asistivas y recorrido del
  dock. Los modelos de prueba no sustituyen AT-SPI.
- `PYTHONPATH=tests/shell python3 -m unittest test_resources test_shortcuts -v`:
  11 pruebas, 10 correctas y 1 omitida: restauración D-Bus bloqueada por el sandbox.
  Los parsers y umbrales se prueban con datos sintéticos, no son medidas.
- Sintaxis Python del medidor y lector AT-SPI, sintaxis bash del runner.
- Medición antes: `tools/measure-resources.sh --compare-plasma --scenario
  open-panels --output /tmp/t245-before`. Falló creando el bus, antes de arrancar
  Singlr; Plasma no llegó a iniciarse. `resources-before.json`, `nested-before.log`.
- Intento posterior de diagnóstico: misma orden con `--profile --output
  /tmp/t245-after`. Mismo bloqueo; no se compara como muestra principal sin perfil.
  `resources-after.json`, `nested-after.log`. No contiene cifras PSS/CPU.
- Consulta `qdbus6 org.a11y.Bus /org/a11y/bus org.a11y.Bus.GetAddress`: acceso al
  socket anfitrión denegado, guardado en `atspi-blocked.txt`. `import pyatspi`
  tampoco está disponible; python-dbus sí lo está. No se ha instalado nada.

## Accesibilidad pendiente de integración real

Fuera del sandbox, iniciar una sesión **privada**:

```bash
QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 tools/run-singlr.sh
```

En otro terminal, usar el `session.json` anunciado por `SINGLR_SESSION_FILE` (no el
bus anfitrión). Abrir el panel con sus atajos y capturar mientras está visible:

```bash
python3 tools/check-atspi.py \
  --session-file /tmp/singlr-session-REEMPLAZAR/session.json \
  --output /tmp/t245-atspi-launcher.json \
  --expect 'Buscar aplicaciones, archivos y comandos'
```

El lector filtra por PID del shell marcado y vuelca nombre, descripción, rol,
estados, interfaces y acciones de cada nodo AT-SPI; falla si faltan nombres
solicitados o si no hay shell en el registro. Repetir con centro de control,
notificaciones, portapapeles y menú de sesión. Mantener los JSON como evidencia.

Atajos: Meta/Alt+Espacio (lanzador), Meta+A (control), Meta+N (notificaciones),
Meta+V (portapapeles), Meta+Alt+D (foco dock), Meta+Alt+S (menú de sesión).
KGlobalAccel conserva conflictos existentes. El dock admite Tab, flechas
izquierda/derecha, Enter, espacio, tecla Menú y Esc; el menú contextual también
admite Tab/Backtab y flechas. Comprobar que una app de prueba vuelve a recibir el
teclado al cerrar cada superficie, y que cambiar voluntariamente a otra app no
reactiva la anterior. Ese retorno depende del compositor y no queda acreditado
por el backend offscreen.

El resto de medidas, separación de procesos y comandos están documentados en
[`docs/phase1/resources.md`](../../../../docs/phase1/resources.md#t245--accesibilidad-y-medición-ampliada-25-oct-2026).
PSS < 120 MB, CPU real y liberación GPU siguen sin acreditarse en esta entrega.
