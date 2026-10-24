---
name: singlr-quality
description: Verificar cambios de Singlr con evidencia de funcionamiento, compatibilidad, accesibilidad, rendimiento o instalación reversible. Ajustar los checks al cambio real y distinguir resultados de pruebas pendientes.
---

# Calidad de Singlr

Lee la tarea, el diff y docs/status.md. Determina qué cambió y qué resultado observable debe comprobarse. En configuración, usa `python3 scripts/check_setup.py` y `python3 scripts/doctor.py`; no atribuyas a estos scripts pruebas de un escritorio ejecutable.

Para componentes reales, selecciona las comprobaciones pertinentes: carga con versiones/imports correctos; recorridos y estados de error; teclado y foco; lectura/contraste; escalado y monitores; efectos desactivados; instalación, actualización y reversión. No conviertas esta lista en pruebas obligatorias ajenas al cambio.

Al medir rendimiento registra entorno, versiones, escenario, método y comparación. No inventes umbrales aprobados ni generalices una medición local a todos los equipos.

Revisa la experiencia en contexto y los límites de servicios simulados. Un lint correcto no demuestra interacción ni integración; un mockup no demuestra renderizado nativo.

Entrega hallazgos accionables con evidencia, gravedad y modo de reproducir. Separa comprobaciones ejecutadas y su resultado de las bloqueadas o no realizadas. Corrige fallos dentro del alcance y evita crear pruebas que solo comparan frases de los documentos.
