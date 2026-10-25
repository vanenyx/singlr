# T254 — capturas offscreen

`SINGLR_CAPTURE_T254=1 tools/test-qml.sh` y `SINGLR_CAPTURE_T254=1 tools/test-qml.sh --light` generan esta matriz. Fixture con aplicaciones representativas, 1280×800, render software; no simula blur del compositor.

| Modo | 40 px | 72 px |
| --- | --- | --- |
| Flotante oscuro | [40](dark-floating-40.png) | [72](dark-floating-72.png) |
| Fijo oscuro | [40](dark-fixed-40.png) | [72](dark-fixed-72.png) |
| Flotante claro | [40](light-floating-40.png) | [72](light-floating-72.png) |
| Fijo claro | [40](light-fixed-40.png) | [72](light-fixed-72.png) |

[Entrega, verificaciones y límites](../../../../docs/handoffs/T254-dock-settings.md).
