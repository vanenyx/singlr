# T269 — Singularidad ligera y fluida: pruebas y banco de medición

Encargo del creador, 26 oct 2026: reducir el coste del fondo y suavizar la estela.
Claude implementó el renderizado y el ritmo de animación; Codex 1 actualiza pruebas,
añade el banco reproducible y registra la evidencia. Claude verificó con GPU,
aplicó el cambio al canal de desarrollo y midió la sesión real.

## Resultado

Cambios de Claude en `singularity.{h,cpp}` y los shaders:

- Un punto por partícula sustituye los seis vértices/dos triángulos. El fragment
  shader orienta la estela con `gl_PointCoord`; se conserva GLSL 120 de compatibilidad
  sin `flat`. Se mantiene el número de partículas por calidad (26 000/52 000/90 000).
- Temporizador de un disparo encadenado a `frameSwapped`: objetivos de 30 fps en
  reposo y 60 fps con movimiento/estelas, en periodos enteros del refresco. Cuando
  no llega presentación, la cadena deja de solicitar fotogramas.
- Envolvente de entrada exponencial de 70 ms y caducidad exacta a 1,6 s; 32 ranuras
  que no sustituyen estelas vivas. Espaciado por distancia o 50 ms; entrar sin
  mover el cursor no crea impulso. Uniformes compactados de las estelas activas.

Son soluciones técnicas derivadas del encargo; la equivalencia visual de los
puntos y la fluidez percibida siguen pendientes de revisión del creador.

Pruebas actualizadas en `tests/shell/singularity.cpp`:

- Perturbación gráfica con edad de 0,15 s, conservando cobertura 6×4, invariancia
  exterior píxel a píxel, restauración exacta y anulación al desactivar reacción.
- Fuerza nula en ambos extremos; recorrido a intervalos de 1 ms, sin diferencias
  superiores a 0,012 entre muestras (incluye entrada, sobrepaso, atenuación y salida).
- Entrada/reentrada sin movimiento, movimiento efectivo, cursor quieto que no
  renueva estelas, reacción desactivada, saturación real de las 32 ranuras y
  reutilización solo después de caducar. Se comparan posición, velocidad y nacimiento.
- Sin `elapsedChanged` ni avance de `elapsed` al parar; avance/señales durante la
  animación. Se conservan bloqueo, suspensión simulada, visibilidad y descarga.

## Por qué reducir primitivas

Experimentos previos de Claude, aportados en el encargo (no repetidos por Codex):

| Variante | Resultado informado |
| --- | --- |
| Cuadros de 0,01×, sin cobertura | 1,2 ms GPU/fotograma |
| Mitad de partículas | −50 % de coste |
| Cuarta parte del área | −10 % |
| Sin blending o shader trivial | Mejora inferior al 15 % |
| Puntos en lugar de triángulos | −45 % |

La proporcionalidad con partículas y la menor sensibilidad al área/sombreado
apoyan que el coste dominante sea procesar/rasterizar primitivas pequeñas en
este equipo. No demuestra el mismo cuello de botella en todas las GPU.

## Banco reproducible

`tests/shell/singularity_bench.cpp`, target optativo `singlr-singularity-bench`
`EXCLUDE_FROM_ALL`, y `tools/bench-singularity.sh`, basados en los prototipos de Claude.
Solo se usan propiedades públicas de Singularidad; nunca `m_time`. El cursor
sintético recorre una trayectoria sinusoidal cada 16 ms mediante `setPointer`.

Cada ejecución crea bus de sesión, perfil XDG y KWin virtual privados a 2560×1600.
Prueba calidades 0/1/2 en reposo y con cursor: calentamiento de 2 s, muestra nominal
de 6 s por escenario. Usa el tiempo real transcurrido para fps y ocupación; cuenta
presentaciones y muestras de timestamps. Registra GPU, versión Qt, tamaño, DPR,
refresco y soporte de timestamps. Falla ante superficie/backend inválidos o falta
de muestras. Los procesos tienen límite de 20 s y el compositor privado se cierra
al terminar. Los logs van a archivos regulares, también stdout/stderr de
`dbus-run-session`; los servicios activados no pueden retener una tubería de salida.

Contratos contrastados con Qt 6.12.0 local y documentación oficial:
[`setTimestamps`](https://doc.qt.io/qt-6/qquickgraphicsconfiguration.html),
[`swapChain`](https://doc.qt.io/qt-6/qquickwindow.html#swapChain) y
[`lastCompletedGpuTime`](https://doc.qt.io/qt-6/qrhicommandbuffer.html#lastCompletedGpuTime).
Son métodos documentados desde Qt 6.6; QRhi requiere `Qt6::GuiPrivate` y tiene
compatibilidad limitada, que CMake advierte explícitamente. No se incluyen cabeceras
`qquickwindow_p.h` ni se accede al estado privado de Singularidad.

«Ocupación GPU» es suma de tiempos de comandos de esta ventana / tiempo de muestra;
no es uso global de la GPU ni incluye el coste de KWin. Los timestamps son
asíncronos y pueden referirse a fotogramas anteriores; no se trata de un perfilador
exacto por presentación. La escala se fija a 1 y se conserva el selector Radeon
del prototipo (se puede sobrescribir `VK_LOADER_DRIVERS_SELECT`).

```bash
cmake --build .local/build-singularity
cmake --build .local/build-singularity --target singlr-singularity-test singlr-singularity-bench
SINGLR_TEST_BUILD_DIR=$PWD/.local/build-singularity tools/bench-singularity.sh .local/bench-singularity/T269-run1
SINGLR_TEST_BUILD_DIR=$PWD/.local/build-singularity tools/bench-singularity.sh .local/bench-singularity/T269-run2
```

## Antes y después

Antes: medición de Claude con el código de T268 (Vulkan, 2560×1600, Radeon 610M).
Después: `tools/bench-singularity.sh`, dos ejecuciones consecutivas de Claude fuera del sandbox.

| Calidad | Escenario | Antes: ms GPU / ocupación / fps | Después, ejecución 1 | Después, ejecución 2 |
| --- | --- | --- | --- | --- |
| 0 | Reposo | 2,7 / 6,6 % / ~26 irregulares | 1,82 / 5,5 % / 30,0 | 1,73 / 5,2 % / 30,0 |
| 0 | Cursor | — | 2,21 / 13,3 % / 59,8 | 1,82 / 10,9 % / 60,0 |
| 1 | Reposo | 5,3 / 14 % / ~26 | 3,41 / 10,2 % / 30,0 | 3,47 / 10,4 % / 30,0 |
| 1 | Cursor | — | 3,52 / 21,1 % / 59,8 | 3,64 / 21,8 % / 59,8 |
| 2 | Reposo | 7,8–10,8 / 21–28 % / ~26 | 5,75 / 17,3 % / 30,0 | 5,81 / 17,4 % / 30,0 |
| 2 | Cursor | ~9,8 / ~26 % / ~26 | 4,74 / 28,3 % / 59,8 | 5,01 / 30,0 % / 59,8 |

El coste por fotograma baja entre un 35 % y un 50 %. La cadencia es exacta:
30 fps en reposo y 60 fps con cursor, frente a ~26 fps irregulares antes. Con
cursor la ocupación es parecida a la del reposo anterior porque se dibuja el doble
de fotogramas, y solo durante ~1,6 s tras cada movimiento.

**Sesión real del creador** (calidad alta, panel 2560×1600 a 240 Hz, escala 1,25,
backend OpenGL), con contador `drm-engine-gfx` del proceso del shell y muestras
de 10 s en reposo:

- Antes: GPU 21 % en esta muestra; 29 % en una muestra anterior del mismo día.
- Después de `tools/dev-channel.sh reload`: GPU 15 % en tres muestras consecutivas.
- CPU del shell: 2–3 % de un núcleo en ambos casos.

## Comprobaciones

Codex 1 escribió las pruebas, el banco y este registro dentro de su sandbox, sin
acceso a `/dev/dri` ni a sockets D-Bus. Claude ejecutó después la parte gráfica:

| Comando | Resultado |
| --- | --- |
| `tools/test-singularity.sh` (build aislado) | Nativo 7/7; QML 3/3 normal y 3/3 con reducir movimiento |
| `tools/test-qml.sh` | Shell 246 correctos, 5 omitidos; Ajustes 11 correctos |
| `tools/bench-singularity.sh` ×2 | Tablas de arriba |
| `git diff --check` | Correcto |

Correcciones de Claude al banco durante la verificación:

- **Ventana sin marco.** KWin añadía barra de título y la ventana medía 1572 px de alto.
- **Atómicos en lugar del mutex.** Con el mutex, el escenario con cursor se colgaba
  de forma intermitente. Las pilas capturadas con gdb mostraban el hilo de render
  bloqueado en el mutex del banco. El fondo no estaba implicado: con OpenGL no
  se colgó en ninguna repetición.

## Límites y pendientes

- La medición prevista es KWin virtual a 60 Hz; el panel real es de 240 Hz.
  No acredita el ritmo, la latencia ni el comportamiento de oclusión del panel real.
- GPU compartida con el escritorio: ruido aproximado ±25 %, además de cambios de
  frecuencia/carga. Conservar ambas ejecuciones y evitar conclusiones por diferencias pequeñas.
- Timestamps de Vulkan aunque el shell use OpenGL: no equivalen a medir su backend
  real. No se mide el escritorio completo, CPU/PSS ni cumplimiento de P-016.
- Prueba visual del creador: aspecto, continuidad y suavidad de la estela. También
  siguen pendientes bloqueo/suspensión físicos y aceptación multimonitor.
