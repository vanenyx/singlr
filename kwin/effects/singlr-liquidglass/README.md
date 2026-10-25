# T252 — pulido de materiales

Estado vigente: [corrección T252](../../../docs/handoffs/T252-material-correction.md).
El plugin procesa Vidrio y Liquid y lee `singlr/singlr.conf` y `kdeglobals` por eventos.
`Enabled` en kwinrc sigue gobernando la óptica Liquid. La difusión variable se añade
al blur nativo. El material ajusta su luminancia local para AA, sin placas ni contornos.
Prueba explícita sin instalar, usando el GLSL de producción sobre EGL surfaceless:

```sh
cmake --build build --target singlr-material-optics-test
python3 tools/material-review.py --shader-fixture /tmp/singlr-optics
```

No equivale a captura ni medición de KWin. Las notas T248/T249 siguientes son históricas;
T252 sustituye sus cifras de opacidad, filtro y refracción.

# Singlr Liquid Glass — T248

T249 corrige la opacidad del tinte, amplía la refracción/brillo y añade diagnóstico
por ventana y marcador magenta en el shader. Ver [causa, pruebas y revisión pendiente](../../../docs/handoffs/T249-liquidglass-fix.md).
La apariencia nueva aún requiere captura en KWin; `pluginLoaded` no acredita dibujo.

Prototipo fuera del árbol para **KWin 6.8.1**, compilado y con factory comprobada;
pendiente de renderizado y revisión visual en compositor real.
No instalar en el perfil habitual para probarlo. No se ha modificado la sesión activa.

## Construcción y contrato

```sh
cmake -S . -B build -DSINGLR_BUILD_LIQUIDGLASS=ON -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build --parallel 2
cmake --build build --target singlr-liquidglass-test singlr-appearance-test singlr-material-settings-test
build/kwin/effects/singlr-liquidglass/singlr-liquidglass-test
build/session/appearance/singlr-material-settings-test
```

`find_package(KWin 6.8.1 EXACT)` importa `KWin::kwin`, que exige C++23 y cabeceras Vulkan
incluso para este pase OpenGL. PKGBUILD: `kwin=6.8.1`, `vulkan-headers` como dependencia de
construcción. Recompilar y volver a probar con cada actualización de KWin; el IID incluye
`KWIN_PLUGIN_VERSION_STRING`. No hay garantía de ABI entre versiones.

API local: `EffectPluginFactory` (factory propia que devuelve null si falla el shader),
`Effect::drawWindow/prePaintScreen/reconfigure/isActive/blocksDirectScanout`,
`EffectsHandler`, `SurfaceInterface::blurRegion/blurChanged`, `Window::resourceClass`,
`BackgroundEffectItem`, `RenderViewport`, `GLFramebuffer::blitFromRenderTarget`,
`GLTexture`, `GLVertexBuffer` y `ShaderManager`. La comprobación layer-shell usa el
metaobjeto de `LayerShellV1Window`: esa clase no se exporta en libkwin, por lo que
`qobject_cast<LayerShellV1Window *>` introduciría un símbolo no exportado.

Se estudió el [blur de KWin v6.8.1](https://github.com/KDE/kwin/blob/v6.8.1/src/plugins/blur/blur.cpp)
y la [construcción externa de Glass](https://github.com/4v3ngR/kwin-effects-glass/blob/main/src/CMakeLists.txt).
El pase de Singlr es original, SPDX GPL-2.0-or-later. La licencia/publicación del producto
sigue pendiente según P-002. El contrato de factory está descrito en
[la documentación oficial](https://api.kde.org/kwin-effectpluginfactory.html).

## Renderizado

La posición 80 ejecuta el pase después del blur nativo. Solo procesa una superficie Wayland
layer-shell cuyo `resourceClass` sea exactamente `singlr-shell` y tenga región de blur.
La copia del fondo se limita a sus límites, mantiene un buffer por ventana/vista, respeta
daño y región, y conserva el formato del render target. SDF de rectángulo redondeado,
refracción normal al borde, brillo superior/interior y separación cromática subpíxel.
Un filtro de nueve muestras adicional depende de intensidad. Sin ruido, reloj ni animación.
`BackgroundEffectItem` expande el daño; no se solicitan repintados salvo al reconfigurar.
No bloquea direct scanout. Libera texturas al desactivar, eliminar ventana o retirar vista.

`kwinrc [Effect-singlrliquidglass]`: `Enabled=false`, `Intensity=65` (0–100).
`DiagnosticOverlay=false` por defecto; el helper privado puede activarlo para identificar
el borde magenta generado por el fragment shader. `/Effects debug singlr-liquidglass windows`
devuelve JSON de configuración, región, identidad y pases dibujados sin log por frame.
`KConfigWatcher` y `reconfigure` actualizan en vivo; basta `KConfig::Notify` o una llamada
D-Bus a reconfigure. El efecto rechaza software rendering. Transformaciones, fullscreen
effects y pantalla bloqueada conservan el comportamiento nativo. La factory no se activa
por defecto fuera de la transacción de sesión Singlr.

## Materiales y límites actuales

- `Appearance.material`: solid / glass / liquid; `intensity`: 0–100; preferencia en
  `singlr/singlr.conf [Appearance]`. `Accessibility/reduceTransparency=true`, intensidad 0
  o renderer Qt software fuerzan superficies opacas, sin solicitudes de blur.
- Backend T241 (`Singlr.System.KDEAppearance`) con KConfig/Notify. Conserva wallpaper,
  claves ajenas y preferencias KDE; solo escribe kwinrc con `XDG_SESSION_DESKTOP=Singlr`
  y un journal de sesión existente. La transacción captura/restaura los tres nuevos valores;
  también admite recuperación de journals anteriores a T248.
- Vidrio es el respaldo visual si el plugin no está disponible. La selección Liquid se
  conserva para la próxima sesión compatible. No se desactiva ni modifica el blur global.
- **Límite de API:** KWindowEffects no permite escoger el radio de blur nativo por ventana.
  Intensidad controla el tinte, el blur del preview QML y el filtro/refracción adicional de
  Liquid; el blur base de Vidrio sigue usando el radio del compositor. No presentar esto
  como control completo de blur por ventana ni cambiar `Effect-blur/BlurStrength` global.
- El radio SDF se estima de la primera scanline de la región redondeada. Una región con
  varias piezas (p. ej. varias notificaciones) tiene una SDF sobre su bounding box: se
  recorta a la región, pero no tiene una SDF independiente por tarjeta.
- Pendientes de prueba: daño parcial real, escala fraccionaria, vistas múltiples/rotadas,
  HDR, shader en drivers AMD/NVIDIA y apariencia del brillo tras el tinte. GLES cae a
  Vidrio si el compilador rechaza el shader GLSL 140. El estado «plugin cargado» no es una
  medición de rendimiento ni prueba de corrección de la imagen.

## Evidencia y bloqueo

La configuración inicial se detuvo por falta de cabeceras Vulkan. Para verificar sin
instalar paquetes se obtuvieron cabeceras **oficiales** Khronos, tag
`vulkan-sdk-1.4.335.0`, en `/tmp/t248-vulkan/include`; no se vendorizan ni son stubs.
CMake usó `-DVulkan_INCLUDE_DIR=/tmp/t248-vulkan/include`. La compilación completa,
el enlace `--no-undefined`, la carga de factory (5 pruebas) y staging con plugin pasan.
El PKGBUILD usa el paquete normal `vulkan-headers` para construir en un entorno limpio.

El intento de sesión anidada se detuvo al crear el bus privado: `Failed to bind socket:
Operation not permitted`. Limpieza sin procesos restantes y hashes de configuración host
iguales. No se ha renderizado Liquid Glass ni medido GPU/frame time.

Pruebas de lectura/clamp/alcance se ejecutan también sin el SDK Vulkan mediante el target
`singlr-material-settings-test`. GLSL comprobado con `glslangValidator`; factory cargada
sin instanciar el efecto (necesita el singleton/contexto EGL de KWin).
Ver [handoff](../../../docs/handoffs/T248-liquidglass.md) y
[procedimiento de medición](../../../docs/testing/materials.md).
