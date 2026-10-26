# T254 — Dock configurable

**Actualización 26 oct, P-025/T257:** el indicador de aplicación abierta descrito
en esta entrega histórica fue retirado por decisión del creador.

Codex 1, `day3/codex1-dock-settings`, sin commit. Implementa P-022 sobre Desktop, Appearance y Platform; no acredita la sesión completa de Singlr 1.0.

## Cambios

Ajustes → Dock: Flotante/Fijo, alturas 40/48/56/64/72 px e interruptor de ocultación. Persisten en `singlr/singlr.conf`, grupo `Dock`, con KConfigWatcher por **nombre relativo** y Notify; bindings del shell en vivo. Los fijados y su orden conservan su almacenamiento anterior.

Flotante mantiene superficie/radio, margen inferior 4 px. Fijo ocupa el ancho de la pantalla principal, sin márgenes/radios ni sombra, con hilo superior tenue. Contenido centrado; iconos, espaciado, indicador de app abierta y separador escalan con la altura, con dimensiones enteras. Se añadió el indicador de abierta, ausente en la implementación anterior.

Autohide: dock nativo oculto, exclusión 0; superficie layer-shell transparente de 2 px en el borde inferior, capa Overlay, sin teclado, solo cuando la opción está activa. Hover o archivos en el borde revelan; puntero, archivos sobre cualquier app, arrastre de orden, menú, foco del dock, lanzador y vista general mantienen visible. Espera de salida de 450 ms para cruzar el espacio del flotante. Sin animación ni temporizador continuo, incluido factor de movimiento 0. El puente Workspace transmite visibilidad del overview para Meta+Tab y gestos, además del botón.

Justificación: superficie mínima con semántica estándar del [protocolo layer-shell](https://github.com/swaywm/wlr-protocols/blob/master/unstable/wlr-layer-shell-unstable-v1.xml), sin forzar ventanas ni modificar bordes globales. Exclusión positiva solo sin autohide; anclaje inferior (y laterales en fijo). Qt 6.12.0, KWin/LayerShellQt 6.8.1, KF6 Config 6.31.0 locales. No se ha tocado la sesión habitual.

## Evidencia

- `cmake --build build -j 4`: pasa.
- `SINGLR_CAPTURE_T254=1 tools/test-qml.sh`: 222 shell + 9 ajustes, 0 fallos (3 omitidas opcionales).
- `SINGLR_CAPTURE_T254=1 tools/test-qml.sh --light`: 222 shell + 9 ajustes, 0 fallos (3 omitidas opcionales).
- `SINGLR_TEST_ANIMATION_FACTOR=0 tools/test-qml.sh`: 221 shell + 9 ajustes, 0 fallos (4 omitidas opcionales).
- Target `singlr-appearance-test`: 12 pasan, 1 omitida por falta de bus D-Bus aislado; persistencia, normalización y valores inválidos comprobados. Se añadió prueba de aviso de otro proceso, ejecutable con `QT_QPA_PLATFORM=offscreen dbus-run-session -- build/session/appearance/singlr-appearance-test`.
- qmllint con imports absolutos del checkout/build: pasa para Main, Dock, DockItem y Session. `kwin/effects/singlr-overview/tools/check-qml.sh`: lint 0, componente Ready.
- `git diff --check`: pasa. `python3 scripts/doctor.py`: inventario correcto. `python3 scripts/check_setup.py`: falla por enlace **preexistente** a `tests/shell/evidence/t252/correction/nested-probe.log` en T252; no se ha alterado ese trabajo.
- `tools/measure-resources.sh --output /tmp/t254-resources`: no llega a medir. El sandbox bloquea bind del socket del bus privado (`Operation not permitted`, salida 127); no se acredita P-016.

[Capturas y resultados](../../tests/shell/evidence/t254/README.md): ocho PNG de escritorio de prueba offscreen/software a 1280×800, flotante/fijo × 40/72 × claro/oscuro. Se inspeccionaron flotante oscuro 72 y fijo claro 40. Son evidencia de geometría/material de fallback, no del desenfoque en KWin.

## Revisión de Claude en KWin anidado

1. Abrir Ajustes y cambiar los tres controles con el shell ya abierto; verificar aviso entre procesos y persistencia tras relanzar. Probar teclado en slider y foco Meta+atajo del dock.
2. Maximizar ventana con fijo a 40 y 72: borde inferior del área útil en la parte superior del dock; activar autohide y comprobar recuperación de toda la altura. Repetir cambio flotante/fijo en vivo.
3. Oculto: recorrer borde inferior, cruzar margen, pasar entre apps, abrir/cerrar menú, soltar puntero y esperar salida. Arrastrar archivos desde Dolphin al borde, mantener sobre apps compatibles/incompatibles y abrir; abandonar drag fuera sin dejar dock retenido. Estas rutas DND nativas no están acreditadas por las pruebas de estado QML.
4. Abrir/cerrar lanzador y overview (botón, Meta+Tab, gesto), recuperar foco del dock, Escape; repetir con factor 0. Conectar/desconectar salida principal y comprobar dock/activador en la misma salida; política de pantalla intacta.
5. Medir recursos del shell completo, con autohide activo en reposo; revisar vidrio/fijo en claro/oscuro. Integración, rendimiento y aprobación visual quedan pendientes de esta revisión.
