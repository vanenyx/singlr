# T250 — evidencia

- Splash: [oscuro](dark-splash.png), [claro](light-splash.png). Renderizado real
  offscreen del componente `Singlr.Ui.SessionSplash`, etapa 4/6, 1280×800.
- Command: [oscuro](dark-command.png), [claro](light-command.png). Presentación real
  del lanzador con **modelo de resultados simulado**; no acredita el KCM abierto.
- `ksplash-dark.log` y `ksplash-light.log`: ambos paquetes cargados con el binario
  KSplash instalado, `--test --window --nofork`, backend offscreen/software,
  AnimationDurationFactor=0, perfiles temporales, salida normal 0. Las capturas
  anteriores proceden del test QML del mismo componente, no del framebuffer del
  proceso externo ni de una sesión de login.
- `verification.txt`: suites oscuras/claras 207 passed, 0 failed, 1 skipped cada
  una; movimiento reducido 205 passed, 0 failed, 3 skipped (dos capturas opcionales
  y AT-SPI). Pruebas de mezcla, sinónimos, índices que cambian, apertura y Ctrl+K.
- `native-blocked.log` y `resources-blocked.log`: límite D-Bus/KIO del sandbox.
  El runner nativo no queda validado aquí; tampoco PSS/CPU/GPU ni arranque real.

Se inspeccionaron visualmente las cuatro capturas. El splash mantiene el anillo
uniforme monocromo y una barra de 2 px sin giro ni movimiento continuo. La propuesta
visual requiere aceptación del creador. Material abre la sección existente en
Apariencia; falta conectar la nueva página de Codex 2 cuando se integre.

[Procedimiento anidado y de login](../../../../docs/testing/command-splash.md).
