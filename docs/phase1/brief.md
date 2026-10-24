# Fase 1 — Brief de dirección visual

Encargo del creador (2026-10-24): explorar dos direcciones visuales del escritorio Singlr con evidencia real y preparar un prototipo Qt Quick/QML. Nada de este brief es una decisión visual aprobada; las bases son la [visión recuperada](../../SINGLR_recuperacion_desde_mensajes_originales.md) y [AGENTS.md](../../AGENTS.md).

## Qué debe mostrar cada dirección

Cuatro estados del mismo escritorio a 2048×1280 lógicos (la pantalla del creador: 2560×1600 con escala 1,25), en modo oscuro, más el escritorio principal en modo claro:

1. **Escritorio principal**: fondo, navegación o lanzamiento, estado del sistema y una ventana en foco con otra detrás.
2. **Búsqueda**: lanzador o paleta abierta sobre el escritorio, con resultados de aplicaciones, archivos y acciones.
3. **Multitarea**: vista de ventanas y espacios de trabajo, con la ventana activa identificable.
4. **Controles del sistema**: red, audio, brillo, energía, notificaciones y acceso a Liquid Glass y su intensidad.

Las ventanas de aplicación son simuladas (archivos, terminal, editor, navegador) con datos verosímiles. Usan los logotipos originales instalados en `/usr/share/icons`.

## Condiciones de la visión

- La UI visible de Linear es una influencia central (composición, jerarquía, tipografía, superficies, color, densidad, precisión), junto al refinamiento, la profundidad y la continuidad de macOS. Debe resultar descendiente de ambos, no una copia.
- Base neutra y sobria, con superficies tonales bien diferenciadas. El creador cuestionó los fondos azulados.
- Superficies mates donde se lee y trabaja. Glassmorphism en elementos flotantes y temporales. Liquid Glass opcional y ajustable, distinto del cristal clásico.
- Esquinas moderadas, menos redondeadas que en Apple. El anillo del logotipo no impone geometría circular.
- Iconos de Phosphor (`third_party/phosphor`). Tipografía por explorar: Inter está disponible en `third_party/inter` y Noto Sans en el sistema.
- No se ha aprobado ninguna disposición de panel, dock o barra: es una de las variables a explorar.

## Cómo deben diferir

Cada dirección tiene un nombre, una tesis de dos líneas y diferencias deliberadas en al menos tres ejes: estructura de navegación y lanzamiento, equilibrio entre materiales mates y cristal, densidad y escala tipográfica, tratamiento de ventanas y multitarea. Cambiar solo la paleta no cuenta como dirección distinta.

## Criterios de evaluación

1. **Identidad:** ¿se reconoce como Singlr y no como un tema de Linear o una imitación de macOS?
2. **Jerarquía y foco:** ¿el trabajo domina? ¿Navegación y estado acompañan sin competir?
3. **Precisión:** alineación, ritmo de espaciado, escala tipográfica y coherencia de iconos.
4. **Materiales:** ¿el cristal se lee bien sobre fondos claros y oscuros? ¿Liquid Glass se diferencia y puede desactivarse?
5. **Recorridos:** ¿lanzar, buscar, cambiar de ventana y ajustar el sistema resultan directos?
6. **Viabilidad:** coste de efectos, implementación sobre Plasma 6 y KWin, y escalabilidad a un escritorio completo.

## Entorno

Los prototipos se ejecutan con `qml6` en ventana propia, en captura offscreen o en una sesión KWin anidada. Nunca reemplazan ni modifican la sesión KDE habitual del creador.
