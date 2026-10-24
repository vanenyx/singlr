# SINGLR
## Recuperación de la visión original del producto

**Procedencia:** intervenciones del creador en la conversación de definición de Singlr, incluido su texto «SINGULAR — Identidad Visual y Filosofía de Diseño v0.1».  
**Naturaleza:** reconstrucción fiel de requisitos y preferencias; no aprobación de una especificación final de implementación.  
**Criterio:** las decisiones confirmadas se distinguen de las preferencias todavía exploratorias y de los detalles que requieren diseño. Las propuestas del asistente no se convierten automáticamente en requisitos.

---

## I. Qué queremos construir

**Singlr es una experiencia de escritorio original para Linux, concebida como un producto completo, coherente, instalable, actualizable y optimizado para diferentes usuarios y equipos.** Su primera implementación se desarrollará aprovechando Arch Linux y KDE Plasma, con capacidad de evolución arquitectónica a futuro.

La intención es diseñar cómo **se ve, se siente y se utiliza** el escritorio: composición visual, superficies, iconografía, ventanas, navegación, movimiento, controles del sistema, organización del trabajo y personalización. La calidad debe estar presente tanto en la interfaz visible (*UI*) como en la experiencia de uso (*UX*).

Singlr parte del deseo de crear algo propio y reconocible. No consiste en aplicar un tema estético a una instalación personal: se busca una identidad de producto y una experiencia que otras personas puedan instalar y mantener.

## II. La dirección estética: Linear × macOS × identidad Singlr

**Esta es una de las decisiones más importantes de toda la conversación.** La **UI visible de Linear** constituye una referencia visual principal, además de su UX: composición, superficies, jerarquía, tratamiento del contenido, densidad, navegación, detalles y sensación de precisión. La apariencia de Linear importa por sí misma; no es meramente una fuente de atajos o productividad.

**macOS es igualmente una referencia visual y de interacción:** acabado profesional, refinamiento, fluidez, profundidad, continuidad, atención a la geometría y las microinteracciones. Sus virtudes se reinterpretan en el contexto de Linux.

**Glassmorphism** aporta un material de profundidad suave y translucidez que encaja con la estética inspirada en Linear. El resultado aspirado es una interfaz que parezca **descendiente de Linear y macOS, pero con personalidad propia**, no una suma literal de dos interfaces.

La formulación del creador fue «como un hijo de Linear y macOS», añadiendo que «el Glassmorphism ahí sí cobra sentido al aplicarlo a Linear». Posteriormente aclaró de forma explícita que «la parte que se ve de Linear» es una influencia central. Esto tiene prioridad sobre cualquier esquema que asigne «Linear = solo UX» y «macOS = solo UI».

## III. Identidad de marca

**Nombre del producto:** Singlr.  
**Dominio:** `singlr.dev`, reservado por su creador.

**Logotipo:** un anillo circular de grosor uniforme, principalmente monocromático, adaptable a fondos claros y oscuros. Simboliza unidad, continuidad, simplicidad e identidad propia. Puede adoptar tratamiento lumínico o animaciones en contextos de marca adecuados.

El logotipo es una pieza de **identidad corporativa**. Su forma no prescribe el uso de círculos como patrón o geometría general del escritorio.

## IV. Lenguaje visual expresamente preferido

### 1. Geometría

- Geometría limpia, controlada y consistente.
- Bordes moderadamente redondeados, con una suavidad **menos pronunciada que la utilizada en varias interfaces de Apple**.
- Radios y proporciones adecuados a cada componente y a su función.

Las cifras exactas en píxeles todavía requieren exploración y prototipado; los valores que aparecieron antes como sugerencia del asistente no son parámetros aprobados.

### 2. Color

- Estética cromática inspirada de forma significativa en el lenguaje visual de Linear.
- Superficies y jerarquías tonales bien diferenciadas; preferencia por una base sobria y neutra.
- Colores de acento funcionales y configurables, cuya elección concreta sigue abierta.
- Tratamiento coherente en variantes claras y oscuras si se decide incluir ambas.

**No está aprobada una paleta hexadecimal definitiva.** El creador cuestionó explícitamente los fondos azulados y la dirección cromática que le fue propuesta. La decisión positiva es explorar con rigor la estética de Linear, no fijar la paleta anterior.

### 3. Materiales, translucidez y profundidad

- **Superficies sólidas o mates** allí donde ayuden a leer y trabajar sin distracciones.
- **Glassmorphism/frosted glass** como material visual importante, especialmente apropiado en elementos flotantes, paneles temporales y componentes donde la profundidad resulte útil.
- **Liquid Glass** como posibilidad **opcional** y **configurable**, independiente del glassmorphism clásico. El creador quiere poder activarlo, desactivarlo y controlar su intensidad por preferencia.
- Una implementación sensible a rendimiento, contraste y legibilidad, sin que los efectos decorativos dominen la experiencia.

No se ha decidido exactamente qué componentes tendrán cristal, qué nivel de opacidad usarán ni cómo se implementará ópticamente: son objetos de prototipado.

### 4. Tipografía, espaciado y composición

- Tipografía precisa, legible y visualmente refinada, acorde con la influencia de Linear y macOS.
- Espaciado, densidad y alineaciones tratados como elementos fundamentales de la identidad.
- Jerarquía visual fuerte, detalle coherente y composición equilibrada.

La familia tipográfica, escala tipográfica y medidas definitivas **todavía no se han seleccionado**.

### 5. Iconografía

**Familia base elegida: Phosphor Icons** (el creador la identificó fonéticamente como «photoshop icons» en mensajes posteriores).

A partir del texto de identidad aportado por el creador:
- Estilo minimalista, geométrico y reconocible.
- Variantes de contorno (*Outline*) y rellena (*Solid/Fill*) según contexto y significado.
- Tamaños de presentación habituales de 16, 20 y 24 px; consistencia de peso óptico, alineación y proporciones.
- Los **iconos de las aplicaciones instaladas conservan las marcas originales**. La uniformidad se consigue mediante tamaños ópticos, márgenes y presentación, sin redibujar arbitrariamente los logotipos.
- Singlr podrá tener iconos propios cuando sean necesarios para funciones originales de la experiencia.

La frase «la menor complejidad visual posible, sin perder significado ni identidad» apareció **en el contexto de iconografía**. Es una buena orientación para diseñar símbolos, pero no fue aprobada como regla universal del proyecto.

### 6. Movimiento

- Microinteracciones fluidas, discretas, profesionales y con propósito.
- Transiciones que mejoren la orientación, percepción del estado y continuidad.
- Control de efectos y comportamiento para equilibrar estética y rendimiento.

Duraciones, curvas y secuencias concretas quedan por diseñar y ensayar.

## V. Experiencia completa de escritorio

Singlr debe sentirse como **un sistema visual y de interacción integrado**. La experiencia abarca, como mínimo, estos ámbitos de producto:

1. **Superficie del escritorio:** organización general de pantalla, jerarquía, fondos, paneles y relación con las ventanas.
2. **Navegación y aplicaciones:** accesos, aplicaciones abiertas, cambio de contexto, organización y continuidad.
3. **Búsqueda/lanzamiento:** acceso eficiente a aplicaciones, archivos y acciones según capacidades reales del sistema.
4. **Ventanas y espacios de trabajo:** multitarea, comportamiento, foco, estados, movimientos y organización.
5. **Controles y estado del sistema:** conectividad, audio, batería/energía cuando corresponda, notificaciones y preferencias.
6. **Personalización:** estilos, modos, niveles de translucidez, Liquid Glass opcional y controles adecuados a cada material.
7. **Experiencia cotidiana:** legibilidad, rapidez, comodidad, previsibilidad y coherencia en distintos escenarios de uso.

**Importante:** esta lista describe los sistemas que forman parte del producto; **no aprueba una distribución concreta** del Dock, barras, paneles ni navegación. Tampoco significa que haya que programar todos los subsistemas de cero. El objetivo es la experiencia global y se puede aprovechar lo que KDE ya hace bien.

El usuario rechazó expresamente que el proyecto terminara definido como «construir un widget» o como «hacer macOS con atajos de Linear». Cualquier primer incremento técnico debe evaluarse por cómo contribuye a la experiencia Singlr completa.

## VI. Alcance tecnológico y evolución

- Equipo actual: **Arch Linux con KDE Plasma** ya instalado.
- Primer despliegue previsto: **Singlr sobre Plasma 6**, integrando componentes propios y capacidades existentes de KDE/KWin.
- Tecnologías propuestas para explorar y validar: **Qt Quick/QML, estilos de Plasma, scripting de KWin**, servicios de Linux; **Quickshell** como opción futura si se justifica.
- Posible evolución hacia una shell más independiente, sin asumirla como condición previa para el producto inicial.

La elección de una arquitectura modular permite evolucionar. No implica que los plasmoids y las APIs específicas de Plasma puedan trasladarse sin adaptación a otros entornos.

## VII. Calidad del producto

El creador pidió explícitamente que Singlr sea:

- **Reproducible:** instalable por otras personas y reproducible a partir de código versionado.
- **Actualizable:** cambios y migraciones sostenibles a lo largo del tiempo.
- **Optimizado:** buen rendimiento y uso controlado de recursos, incluidos los efectos de composición.
- **Profesional y consistente:** UX/UI integral, no una acumulación de temas aislados.
- **Mantenible:** estructura técnica comprensible, pruebas y compatibilidad verificables.
- **Distribuible:** no limitado a la laptop del creador.

Las métricas numéricas, hardware soportado y mecanismos concretos de empaquetado deberán estudiarse y decidirse con evidencia; no hay presupuestos de rendimiento aprobados.

## VIII. Cómo se desarrollará con agentes

**Equipo confirmado por el creador:**
- **Claude Code** en terminal (**CLI**).
- **Codex 1** en una **aplicación de escritorio Codex**.
- **Codex 2** en una **segunda instancia/aplicación de escritorio Codex**.
- **El creador** dirige el producto, conoce el progreso, evalúa resultados y participa en decisiones importantes.

**Modo de trabajo deseado:** agentes con autonomía significativa para tareas técnicas rutinarias: preparar el entorno, organizar Git, escribir código, ejecutar pruebas, investigar documentación y corregir fallos sin convertir al usuario en operador de comandos. Se evaluará un modelo de permisos seguro que reduzca interrupciones sin compartir contraseñas personales ni modificar indiscriminadamente la seguridad del sistema.

**Coordinación propuesta y aceptada como dirección de trabajo:** repositorio Git compartido, trabajos aislados, revisiones e integración controlada. La distribución específica de tareas «Claude arquitectura / Codex 1 implementación / Codex 2 QA» nació como una propuesta del asistente; es una asignación operativa razonable, **no una propiedad intrínseca del producto**.

**Expectativa informativa del creador:** los agentes deben explicar qué están construyendo y mostrar resultados verificables; autonomía no equivale a ocultar el proceso o sustituir decisiones de producto.

El creador indicó que **él creará el repositorio remoto de GitHub**. No debe asumirse que ya existe.

## IX. Situación conocida al final de la conversación

- **Definición de producto:** explorada extensamente, con varias decisiones confirmadas y otras todavía abiertas.
- **Paquetes de partida:** se entregaron archivos comprimidos de Singlr durante la conversación. El creador confirmó que **descargó el comprimido**.
- **Ruta:** `/home/sunw/Projects/singlr/` existía pero **estaba vacía cuando se discutió el comando de inicio**.
- **Agentes:** el creador confirmó expresamente que **no había enviado prompts ni ejecutado desarrollo con Claude o Codex** en ese momento.
- **Proyecto de escritorio ejecutable:** no hay evidencia de una experiencia integrada de Singlr ya construida o probada en su laptop.
- **Repositorio remoto:** no hay confirmación de que haya sido creado.

Los comprimidos anteriores son **material técnico preliminar**. Antes de emplearlos como fuente normativa habría que contrastarlos con esta reconstrucción basada en mensajes originales: algunos contenían interpretaciones del asistente que el creador cuestionó.

## X. Qué está definido y qué no

### Decisiones explícitas del creador o ratificadas en la conversación

- Nombre **Singlr** y dominio `singlr.dev`.
- Entorno de escritorio Linux original, con primera base en KDE Plasma.
- **UI de Linear como influencia visual sustancial**, además de su UX.
- Influencia visual y experiencial de macOS, reformulada mediante identidad propia.
- Glassmorphism como parte significativa del lenguaje de materiales.
- Liquid Glass **opcional y ajustable**.
- Redondeado de esquinas **moderado**.
- Preferencia por un sistema cromático cercano al lenguaje de Linear, sin aceptar aún una paleta final.
- Logotipo como **anillo geométrico monocromático**.
- **Phosphor Icons** como familia elegida; respeto de logotipos originales de aplicaciones.
- Reproducibilidad, actualizaciones, distribución, rendimiento y consistencia.
- Equipo: Claude Code CLI + dos instancias Codex Desktop, con trabajo técnico delegado y visibilidad del progreso para el creador.

### Aspectos realmente abiertos al diseño y a las pruebas

- Vistas finales del escritorio y su composición espacial.
- Posición y forma de panel, dock/barra de aplicaciones, navegación y menú.
- Diseño específico de ventanas, decoraciones y multitarea.
- Sistema tipográfico, escala, interlineado y densidad.
- Paletas de colores y acentos finales para modos visuales.
- Tokens concretos de geometría, espaciado, sombras y movimiento.
- Presets, intensidad, disponibilidad y coste del glassmorphism y de Liquid Glass.
- Experiencia exacta del buscador, centro de control y notificaciones.
- Integraciones reales con KDE, aplicaciones Qt/GTK, dispositivos y diferentes configuraciones.
- Objetivos numéricos de rendimiento y compatibilidad.
- Estrategia detallada de release, instalación, migración y pruebas reales.

Estos vacíos **no son fallos de la idea del creador**; son trabajo legítimo de diseño e ingeniería que se debe desarrollar mediante investigación, prototipos y evaluación. Deben resolverse con criterio profesional y con participación del creador en las decisiones perceptibles de producto.

---

## XI. Trazabilidad: formulaciones del creador que sostienen esta recuperación

Estas referencias son fragmentos de los mensajes aportados en esta conversación. No provienen de los documentos posteriores generados por el asistente.

| Tema | Manifestación en los mensajes originales |
|---|---|
| Plataforma inicial | «Ya instalé Arch Linux con KDE Plasma» |
| Objetivo de apariencia | «súper limpia, súper productiva, eficiente y óptima» y «basada en las interfaces de macOS» |
| Identidad propia | «quiero que sea mi propio [...] su propia identidad» |
| Geometría | «sí me gustan los bordes redondos, pero no tanto como los de Apple» |
| Materiales | «Liquid Glass [...] poder desactivarlo [...] activarlo y también controlarlo» |
| Referencia compuesta | «como un hijo de Linear y macOS» |
| Interfaz de Linear | «la parte que se ve de Linear [...] la parte de user interface de Linear también era importante» |
| Producto instalable | «proyecto reproducible y actualizable [...] no solo que funcione en mí [...] bien optimizado» |
| Nombre | «me quedo con Singlr y el dominio [...] singlr.dev» |
| Iconos | «revisando todas las fuentes de iconos, [...] Phosphor Icons [...] mejor encaja» (normalización contextual del nombre transcrito fonéticamente) |
| Agentes | «Claude en CLI» y «2 Codex en apps de escritorio» |
| Seguimiento | «yo si bien no voy a programar necesito saber qué se está haciendo» |
| Alcance | «terminará siendo [...] crear un widget [...] la definición es pobre» (advertencia explícita sobre reducción del producto) |

### Regla de fidelidad para el futuro

Al desarrollar requisitos nuevos se debe indicar si son **(a) decisión explícita**, **(b) propuesta por validar** o **(c) solución técnica derivada y justificada**. Las sugerencias y borradores del asistente nunca adquieren automáticamente el estatus de decisión del creador.

**Fin de la recuperación.**
