# Singlr

Experiencia de escritorio original para Linux, construida sobre KDE Plasma 6 y KWin/Wayland.
Linear, macOS y Raycast son referencias, reinterpretadas con identidad propia.

**Estado: prototipo integrado e instalable de Fase 1; no es una versión 1.0 estable.**
Incluye shell QML, Command, dock configurable, vista general, controles del sistema,
ajustes, pantalla de bloqueo, sesión dedicada y paquete Arch. El creador utiliza la sesión;
la aceptación completa en instalación limpia, otra configuración, bloqueo, suspensión,
multimonitor, rendimiento y reversión sigue pendiente.

## Referencias vigentes

- [Singlr 1.0: objetivos, siete sistemas y criterio de completo](docs/singlr-1.0.md)
- [Estado actual y pendientes](docs/status.md)
- [Arquitectura implementada](docs/architecture.md)
- [Decisiones del creador y soluciones técnicas](docs/decisions.md)
- [Compatibilidad y límites de la evidencia](docs/compatibility.md)
- [Visión original (registro histórico)](SINGLR_recuperacion_desde_mensajes_originales.md)

## Compilar y comprobar

Base local contrastada: Arch Linux, Plasma/KWin 6.8.1 y Qt 6.12.0.
El efecto de vidrio usa la ABI de **KWin 6.8.1 exacto**; no se promete compatibilidad
con otras versiones por los mínimos de CMake.

```bash
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_LIBDIR=lib
cmake --build build
python3 scripts/check_setup.py
python3 scripts/doctor.py
tools/test-qml.sh
tools/test-qml.sh --light
```

Dependencias y paquete: [packaging/README.md](packaging/README.md).
Sesión aislada: [shell/session/README.md](shell/session/README.md).
Aceptación real y regreso a Plasma: [tests/session/README.md](tests/session/README.md).
Los checks de preparación solo validan estructura/inventario. Las pruebas offscreen
no acreditan autenticación, dispositivos ni renderizado del compositor.

## Desarrollo

Por encargo del creador del 25/26 oct 2026, Codex continúa directamente el desarrollo
y la documentación con un solo escritor; Claude queda disponible para otros trabajos.
El flujo previo y el enrutamiento por cuentas se conservan en
[docs/workflow.md](docs/workflow.md). Las skills compartidas están en `.agents/skills/`.

Código sincronizado con [GitHub](https://github.com/vanenyx/singlr) por autorización
explícita del creador. No hay release estable. La licencia de distribución sigue
pendiente (P-002); este repositorio aún no concede una licencia general del proyecto.
Las dependencias mantienen sus propias licencias en `third_party/` y sus fuentes.
