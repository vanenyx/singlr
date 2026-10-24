---
name: singlr-interface-refinement
description: "Usar para diseñar, comparar o refinar la UI visible de Singlr: composición, jerarquía, tipografía, navegación, densidad, superficies, color, separadores, iconos y estados. Aplica al escritorio integrado y a componentes de Plasma/QML, mediante variantes visuales y verificación en contexto."
---

# Singlr Interface Refinement

## Propósito
Convertir los aprendizajes del rediseño visual de Linear (marzo de 2026) en un **procedimiento de diseño y revisión de interfaz** para Singlr. Importan la UI visible **y** las interacciones. Linear es una referencia influyente, no una plantilla que debamos clonar.

Consulta primero los documentos de diseño vigentes y la tarea del repositorio. Conserva las decisiones ya aprobadas; cuando el diseño esté abierto, explora alternativas con evidencia visual. El resultado debe seguir siendo reconocible como Singlr.

## Proceso de diseño

1. **Definir el contexto visual completo.** Selecciona un recorrido o escenario de escritorio: libre, ventana en foco, búsqueda abierta, multitarea, control del sistema u otro pertinente. Obtén una captura o demo inicial si existe.
2. **Mapear jerarquía y atención.** Identifica superficie de trabajo, navegación, orientación, acciones e información de estado. Ajusta contraste y presencia visual a la prioridad contextual, sin borrar pistas necesarias.
3. **Refinar composición y densidad.** Examina proporciones, tamaño y ubicación de paneles, pestañas, espaciado, alineación, tipografía e iconos. Revisa si la densidad facilita tareas reales y si existe ruido innecesario.
4. **Evaluar separaciones y superficies.** Compara bordes, divisores, contraste tonal, capas y elevación. La estructura puede comunicarse por alineación, tono y espaciado; verifica su claridad en modo claro y oscuro.
5. **Explorar materiales y color.** Trabaja con tokens centralizados para modo claro/oscuro, superficies y acentos. Si se usan glassmorphism o desenfoques, prueba legibilidad, contraste, fondos variables y coste gráfico. Ajusta los parámetros de materiales según las decisiones vigentes de Singlr.
6. **Comparar alternativas.** Produce dos o tres variantes coherentes del mismo escenario cuando una decisión esté abierta. Muestra comparaciones de antes/después en estados equivalentes y explica los compromisos de cada una.
7. **Validar en la implementación.** Si la infraestructura lo permite, usa variables de diseño y toggles o feature flags para comparar versiones, manteniendo un camino de reversión. Prueba interacción, foco, escalado, accesibilidad y rendimiento. Los controles internos de comparación son una herramienta, no una obligación arquitectónica.

## Criterios de revisión
- ¿La UI visible expresa precisión, calma y profundidad de forma coherente?
- ¿El área de trabajo recibe la atención adecuada respecto de la navegación?
- ¿La iconografía ayuda a reconocer acciones sin multiplicar símbolos decorativos?
- ¿Las pestañas y controles ocupan una proporción justificada del espacio?
- ¿Los separadores hacen legible la estructura sin sobrecargarla?
- ¿El comportamiento al navegar confirma la jerarquía sugerida por el diseño?
- ¿Los materiales mejoran la experiencia en fondos y configuraciones reales?

## Entregable obligatorio
Incluye: (a) escenario y captura/preview del estado inicial, cuando esté disponible; (b) variantes visuales o cambios comparados; (c) rationale de composición, tipografía, color, iconos y materiales; (d) observaciones sobre interacción y accesibilidad; (e) resultados comprobados y asuntos pendientes. No declares «aprobado» lo que no haya evaluado el director de producto.

## Referencia
Lee `references/sources.md` para procedencia y contexto. Usa el artículo como base de preguntas y experimentos, sin reutilizar textualmente sus componentes o marca.
