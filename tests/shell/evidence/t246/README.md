# T246 — evidencia y límites

`switcher-dark.png` y `switcher-light.png` son capturas **QML offscreen**, de la
presentación real `SwitcherView` y de la barra Singlr, con modelos y miniaturas
simulados por `tst_Workspace.qml`. Sirven para revisar composición, tokens,
legibilidad, foco y densidad; no acreditan miniaturas vivas ni integración KWin.
Se revisaron ambas imágenes tras generarlas. La propuesta usa superficies
neutrales de Singlr.Ui, Inter de 12 px, iconos originales de apps, bordes de foco
contrastados, esquinas moderadas y dimensiones constantes durante el cambio.

Estado inicial: Overview ya tenía miniaturas/escritorios de KWin, pero colores
oscuros fijos, sin búsqueda; no había cambiador ni indicador propios. No se pudo
capturar ese estado en KWin por la restricción de sockets del sandbox.

Resultados exactos en `verification.txt`. Las suites de presentación pasan en
claro/oscuro. Los avisos de D-Bus/Solid/KIO sin bus son esperables en este perfil;
la prueba de consulta utiliza un modelo de resultados aislado. El único skip
preexistente es AT-SPI no disponible en offscreen. Los metadatos extraídos de
KWin son incompletos: lint exit 0 no significa ausencia de avisos.

`nested-blocked.txt` conserva el fallo del socket y la igualdad de hashes del
host; `resources-blocked.json` conserva la medición bloqueada, **sin presupuesto
validado**. No se ha instalado ni recargado la sesión del creador. La carga del
paquete TabBox completo fuera de KWin tampoco terminó; no se presenta como Ready.

[Procedimiento para Claude](../../../../session/WORKSPACE.md). Pendientes:
Alt/Shift+Tab real, soltar modificador/Enter/Esc, miniaturas vivas, gestos, arrastre
entre escritorios, apertura de Command al escribir, dos salidas y escalas,
consumo de shell+KWin y aprobación visual del creador. El script anidado guarda
capturas reales en `nested/` cuando se ejecute fuera del sandbox.
