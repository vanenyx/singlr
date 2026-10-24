---
name: singlr-product-craft
description: "Usar al definir, desarrollar o revisar experiencias y funcionalidades de Singlr: criterio de producto, responsabilidad de extremo a extremo, alcance adecuado y evaluación de calidad. Adecuada para exploración de producto, revisión de prototipos, planificación de incrementos y PR con impacto en UX."
---

# Singlr Product Craft

## Propósito
Ayudar a entregar una experiencia de producto excelente, no solo tareas de código terminadas. Inspirada en los principios de calidad expuestos por Karri Saarinen en la entrevista publicada por Figma (véase `references/sources.md`).

Esta skill es **un método de trabajo**, no la definición de producto de Singlr. Antes de ejecutarla, consulta la documentación de producto aprobada y la tarea actual del repositorio. No atribuyas al usuario decisiones que no estén aprobadas. Si no existe una definición suficiente, identifica la decisión concreta pendiente sin inventarla.

## Proceso

1. **Entender el resultado deseado.** Describe quién utilizará la experiencia, en qué situación, qué problema resuelve y cómo se reconocerá que está bien resuelto. Considera experiencia completa y contexto del escritorio, no solo el componente solicitado.
2. **Examinar el producto actual.** Inspecciona las pantallas, rutas e interacciones afectadas. Consulta capturas o ejecuta el prototipo cuando sea posible. Evita evaluar una pantalla aislada sin su contexto.
3. **Proponer una intervención acotada de extremo a extremo.** Selecciona el incremento más pequeño que permita verificar una experiencia real integrada. Las especificaciones son el umbral mínimo: plantea posibles mejoras como alternativas explícitas; no cambies compromisos de producto sin aprobación.
4. **Construir con responsabilidad compartida.** Incluye o solicita evaluación cruzada de UI, interacción, funcionamiento, accesibilidad y rendimiento. Un agente puede especializarse, pero nadie debe considerar la experiencia de conjunto «responsabilidad de otro».
5. **Contrastar el resultado con uso real.** Prueba los estados habituales, bordes, errores y recorrido completo. Combina mediciones técnicas con evaluación visual y juicio fundamentado; no confundas una métrica verde con calidad de producto.
6. **Refinar antes de cerrar.** Corrige defectos perceptibles y explica qué permanece provisional. Publica evidencias comprobables (capturas, comandos de prueba, cambios observados) y riesgos concretos.

## Preguntas de revisión
- ¿La experiencia tiene identidad, claridad visual y comportamiento coherentes con el resto del escritorio?
- ¿Se entiende el resultado sin explicar la arquitectura interna?
- ¿Qué detalle pequeño perjudica desproporcionadamente la sensación de calidad?
- ¿Estamos reduciendo alcance para hacer una experiencia completa o reduciendo el producto a un componente inconexo?
- ¿El trabajo está integrado, probado y es reversible donde corresponde?

## Salida esperada
Presenta un resumen breve con: **experiencia evaluada**, **decisión recomendada y por qué**, **evidencia**, **riesgos**, **qué puede probar el director de producto** y **decisiones pendientes de su aprobación**. Distingue observaciones comprobadas de opiniones de diseño.

## Referencia
Lee `references/sources.md` para la procedencia y los límites de interpretación. No copies el artículo literalmente.
