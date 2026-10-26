# T259 — evidencia de barra y anclaje nativo

[Comparación](comparison.png), recortes de sesiones KWin privadas nuevas. Anterior
recuperado de d1efe95; TopBar y ScreenSurfaces históricos con nombres distintos para no resolver
los componentes actuales por el import de Singlr.Shell. El resto de datos es sintético.
Salida lógica 2048×1280, captura física 2560×1600; logo ampliado nearest-neighbor
para conservar sus píxeles. Claro incluido debajo del estado corregido.

before.json conserva la geometría original; after.json contiene doce combinaciones
y cuatro menús. Sin PID, historiales o datos de ventanas personales. Limpieza final
remaining=[] y hashes host equal=True en ambos recorridos.

Reproducir desde checkout compilado:

```bash
python3 tests/shell/dock-popup-e2e.py --before --output /tmp/t259-before-new
python3 tests/shell/dock-popup-e2e.py --output /tmp/t259-after-new
python3 tests/shell/evidence/t259/compare.py /tmp/t259-before-new /tmp/t259-after-new
```

compare.py requiere Pillow; se usó el Python del runtime de Codex. Los PNG de
origen y logs permanecen en los temporales, no se incorpora contenido anfitrión.
Adaptador y QtTest solo en tests, no se instalan en el producto.

QML: 241 shell + 9 Ajustes por modo; 0 fallos, 5 capturas opcionales omitidas.
qmllint, doctor, check_setup y diff correctos. El clic del logo conserva el menú.
[Entrega y límites](../../../../docs/handoffs/T259-bar-dock-polish.md).
