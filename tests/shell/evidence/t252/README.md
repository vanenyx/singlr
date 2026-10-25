# T252 — evidencia

**Vigente: [corrección sin placas](correction/index.html)**, con fondo cálido/blanco/negro,
ambos temas y tres geometrías. Las imágenes siguientes son la entrega inicial histórica.

[Comparador](index.html): 60 imágenes + 60 recortes de borde, generados mediante
`tools/material-review.py --shader-fixture tests/shell/evidence/t252/shader-fixture`.
Son fixtures EGL del shader real, **no capturas del compositor ni de la UI integrada**.

[Datos ópticos](shader-fixture/optics.json), [verificación](verification.txt),
[entrega y procedimiento KWin](../../../../docs/handoffs/T252-material-polish.md).
La sesión privada está bloqueada por bind de sockets; [log](nested-probe.log).
Las capturas KWin y los tiempos de frame no se ejecutaron aquí.
