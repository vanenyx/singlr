# Runtime QML de Fase 1

```bash
tools/run-prototype.sh prototypes/runtime-check/Main.qml --window
tools/run-prototype.sh prototypes/runtime-check/Main.qml --nested
tools/run-prototype.sh prototypes/runtime-check/Main.qml --capture /tmp/runtime.png --size 2048x1280
tools/check-qml.sh prototypes/runtime-check
python3 tools/inventory-qml.py
```

Se admiten raíces Item y Window (incluido ApplicationWindow). `--window` es el modo
predeterminado. La captura fuerza el tamaño lógico y guarda ese tamaño en píxeles.
`check-qml` considera entradas los .qml inmediatos de la carpeta; los componentes
reutilizables deben estar en subcarpetas. Usa qmllint con imports Qt 6 y exige una
carga y captura completadas. Retorna error ante fallos de lint, QML o proceso.
No acredita interacción, servicios ni renderizado de shaders.

Cada ejecución usa configuración, datos, estado y caché temporales. Nested usa
runtime/socket propios, conexión absoluta al compositor padre y bus D-Bus privado
compartido por KWin y el cliente. No ejecuta --replace, plasmashell, configuradores
ni servicios de usuario. El supervisor limpia sus grupos al terminar, fallar,
recibir Ctrl+C o SIGTERM. SIGKILL del supervisor impide limpiar: evitarlo.
Estas herramientas no son una sandbox para QML no confiable.

```bash
SINGLR_DURATION_MS=11000 tools/run-prototype.sh prototypes/runtime-check/Main.qml --window
SINGLR_DURATION_MS=11000 tools/run-prototype.sh prototypes/runtime-check/Main.qml --nested
```

`SINGLR_FRAMES` contiene cantidad, media, p95 y máximo de intervalos frameSwapped,
con reloj QML de milisegundos y 1 segundo de calentamiento. Es cadencia, no tiempo
GPU; incluye planificación y vsync. QSG_INFO y qt.rhi imprimen backend/adaptador
cuando el renderizador inicializa. Espacio alterna el blur en la escena técnica.

Offscreen puede elegir software, que omite ShaderEffect/MultiEffect. Se identifica
con SINGLR_NOTICE: una captura correcta no acredita desenfoque. Para comprobar RHI
en un host con contexto GL disponible (aquí falló sin acceso a contexto/dispositivos):

```bash
QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl tools/run-prototype.sh prototypes/runtime-check/Main.qml --capture /tmp/runtime-rhi.png --size 2048x1280
/usr/lib/qt6/bin/qsb --qt6 -o /tmp/singlr-probe.frag.qsb prototypes/runtime-check/probe.frag
```

Resultados ejecutados en tools/evidence/. Ventana, blur real y cierre anidado
completo requieren verificación externa al sandbox. No hay dependencias nuevas.

La sesión Singlr con aplicaciones reales usa `tools/run-singlr.sh`,
`tools/capture-session.sh` y `tools/check-shell.sh`. Contrato, evidencia y
comandos externos: [shell/session/README.md](../shell/session/README.md).
