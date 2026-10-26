# T257 — puntos e iconos del dock

Capturas offscreen/software, 1024×560. Tres filas: estado anterior de a9b9763,
variante sin punto con caja uniforme y variante de compensación visible integrada.
Iconos originales instalados: Dolphin, Konsole, Firefox, Warp, Codex y Chrome.
No hay capturas ni datos de ventanas personales.

| Altura | Oscuro | Claro |
| --- | --- | --- |
| 48 px | [Comparación](dark-48.png) | [Comparación](light-48.png) |
| 72 px | [Comparación](dark-72.png) | [Comparación](light-72.png) |

Regenerar desde el checkout compilado con esas aplicaciones instaladas:

```bash
cmake --build build --target singlr-systemplugin singlr-dock-icon-test
python3 tests/shell/evidence/t257/capture.py
```

El script recupera el DockItem anterior de Git, crea la variante de caja simple
en temporal y ejecuta con datos/XDG/buses aislados. No modifica la sesión real.
La compensación se compara por contorno visible, no por igualdad de masa perceptual.
[Resultados y límites](../../../../docs/handoffs/T257-dock-icons.md).
