# T248 — Appearance / Liquid Glass (Codex 2)

Rama `day3/codex2-liquidglass`, sin commit. **Shell y plugin compilados; factory
cargada. Renderizado y medición en compositor pendientes.** No se alteró KDE ni se instalaron paquetes.

## Entregado

- `kwin/effects/singlr-liquidglass/`: efecto C++ externo, metadata, shader SDF,
  configuración Enabled/Intensity, pruebas config/scope y prueba de factory ejecutada.
  `EffectPluginFactory` de KWin 6.8.1, `BackgroundEffectItem`, captura recortada con
  GLFramebuffer/GLTexture y geometría de daño con GLVertexBuffer. Sin animación ni timers
  de render; no fuerza repintados en reposo. [Contrato y límites](../../kwin/effects/singlr-liquidglass/README.md).
- `session/appearance/` + `shell/qml/Singlr/Ui/{Appearance,Theme,Glass,ContextMenu}.qml`:
  material/intensidad/reducir transparencia mediante el backend T241 y KConfig::Notify;
  opaco con software rendering y accesibilidad, respaldo a Vidrio sin plugin.
- `apps/settings/`: selector Sólido/Vidrio/Liquid Glass, intensidad con SliderControl e
  interruptor accesible; mantiene 880×600. Persiste una vez al soltar el deslizador.
- `shell/session/src/main.cpp` + `Session.qml` / `ScreenSurfaces.qml`: propagación del
  cambio de blur en vivo y seguimiento por evento Show de ventanas diferidas. Lanzador
  declara su rectángulo de contenido, sin pedir blur para toda su ventana fullscreen.
- `session/singlr_kwin.py`: cambio aislado, tres valores transaccionales nuevos;
  lee preferencias al entrar y restaura también ausencia/valores previos. Recupera
  journals anteriores a T248. No se tocaron overview ni paquetes Workspace de Codex 1.
- CMake, PKGBUILD y check-cmake: KWin EXACT 6.8.1, `kwin=6.8.1` y makedepend `vulkan-headers`.
  `SINGLR_BUILD_LIQUIDGLASS=OFF` permite verificar explícitamente solo el shell.
- `tools/material-review.py`: cambios/captura exclusivamente en perfil temporal del
  runner; rechazo de rutas de configuración ajenas, prueba de ese límite incluida.
  [Procedimiento completo](../testing/materials.md) para seis capturas, respaldo, frames,
  GPU AMD/NVIDIA, reposo/PSS y limpieza. Fixture animado separado del producto.

## Comprobaciones ejecutadas

Entorno: KWin 6.8.1-2, Qt 6.12.0, Arch, cabeceras `/usr/include/kwin`.

- `tools/test-qml.sh`: 179 + 8 passed, 0 failed, 1 skipped.
- `tools/test-qml.sh --light`: mismo resultado.
- Pruebas Python de transacción KWin, adaptador T241, empaquetado y helper privado:
  21 passed. Incluyen roundtrip, fallo/recuperación, preferencias y journal pre-T248.
- `singlr-material-settings-test`: 4 passed (incluye init/cleanup): defaults, recarga,
  clamp y exclusión de aplicaciones/superficies sin región.
- `singlr-appearance-test` se ejecutó mediante `test_gtk_integration.py`: persistencia,
  clamp, activación solo con journal Singlr, conservación de kwinrc fuera del journal y esquema/paleta T241.
- `glslangValidator -S frag`: shader GLSL 140 válido. No demuestra compilación por driver.
- `singlr-liquidglass-test`: 5 passed, incluida carga de factory/metadata con QPluginLoader.
  No instancia el efecto fuera del singleton/contexto EGL de KWin.
- `tools/check-cmake.sh`: compilación/enlace `--no-undefined` y staging **con plugin ON**
  correctos, comprobando presencia de la biblioteca instalada. `scripts/check_setup.py` y `git diff --check`: correctos.
- Capturas offscreen de Ajustes claro/oscuro en
  [`tests/shell/evidence/t248`](../../tests/shell/evidence/t248/README.md), inspección visual.
  No son evidencia del efecto del compositor.

## Bloqueo y siguiente paso de Claude

La primera configuración falló por `Vulkan_INCLUDE_DIR` ausente. Se resolvió sin instalar
paquetes: cabeceras oficiales de Khronos, tag `vulkan-sdk-1.4.335.0`, en
`/tmp/t248-vulkan/include`, pasando `-DVulkan_INCLUDE_DIR=/tmp/t248-vulkan/include`.
Se obtuvieron con el conector GitHub (archivo core SHA
`70f9e8619381f4f6526252ce46391d61f9532552`); no se añaden al repositorio. En construcción
normal usar la makedepend `vulkan-headers`. Compilación y factory ya comprobadas.

El intento `tools/run-singlr.sh --duration 2` quedó bloqueado al abrir el bus privado:
`dbus-daemon: Failed to bind socket ... Operation not permitted`. Resultado:
`SINGLR_CLEANUP remaining=[]`, `SINGLR_HOST_CONFIG files_before=30 files_after=30 equal=True`.
Claude debe ejecutar el [procedimiento](../testing/materials.md) fuera de esta restricción.

No están ejecutadas las seis capturas de compositor ni las mediciones de laptop P-016.
Tampoco se acredita instanciación en KWin, daño parcial, múltiples vistas, HDR ni rendimiento AMD/NVIDIA.
No integrar como efecto validado ni habilitarlo en el canal de desarrollo antes de ello.

**Límite funcional conocido:** el protocolo estándar no permite radio de blur por ventana.
La intensidad controla el tinte y el filtro/refracción adicional Liquid; Vidrio conserva
el blur base de KWin. El radio del preview QML sí varía. Esto no cumple todavía el control
completo de radio solicitado para el blur de Vidrio, y se deja explícito para completar
la arquitectura sin afectar materiales de aplicaciones. La SDF de varias piezas usa el
bounding box común, aunque el pintado sí se recorta a cada región.

Valores de tinte/radio/intensidad y apariencia especular son propuestas visuales por
validar (T-012), no nuevas aprobaciones del creador. Respeta P-016/P-017/P-019 y el
sistema 05 sin declarar el producto ni este efecto completos.
