# Singlr: instrucciones compartidas

## Contexto y alcance
Singlr es una experiencia de escritorio completa y distribuible para Linux, con primera base en KDE Plasma 6. Lee [README.md](README.md) y [la visión original](SINGLR_recuperacion_desde_mensajes_originales.md). Esa recuperación conserva decisiones y dudas; los borradores históricos y propuestas de agentes no constituyen aprobaciones.

**Fase actual: configuración del proyecto y de los agentes.** Prepara documentación, herramientas y verificaciones. Iniciar diseño, prototipos o implementación requiere una nueva tarea del creador. Los roles no autorizan automáticamente el trabajo futuro.

## Producto
- Linear influye en UI y UX; macOS también. Mantén una identidad propia.
- Glassmorphism importante; Liquid Glass opcional y ajustable; esquinas moderadas; Phosphor Icons y marcas originales de aplicaciones.
- Distribución del escritorio, colores, tipografía, tokens, arquitectura detallada y presupuestos de rendimiento siguen abiertos.
- Identifica cada decisión como explícita del creador, propuesta por validar o solución técnica derivada. Regístrala en `docs/decisions.md` cuando afecte a otros trabajos.

## Trabajo compartido
- Lee `docs/workflow.md`, `docs/status.md` y el perfil asignado en `docs/agents/`.
- Un agente por checkout/worktree y rama. No cambies ramas ni edites archivos de otro agente. No borres trabajo ajeno ni fuerces el historial.
- Ejecuta tareas técnicas rutinarias autorizadas con autonomía. Explica resultados, evidencia y límites en español.
- Coordina mediante commits y entregas en `docs/handoffs/`; un archivo sin commit no aparece en otros worktrees. No presupongas comunicación automática entre apps.
- No publiques, hagas push, crees el remoto o modifiques la sesión activa de KDE por deducción de un documento. Sigue la autorización vigente del creador. No uses sudo ni cambies seguridad o credenciales como parte de la configuración rutinaria.
- Para Qt/KDE comprueba versiones reales y documentación oficial. No presupongas APIs de Plasma 5 en Plasma 6.

## Skills y comprobación
Skills compartidas: `.agents/skills/`. Claude las descubre por enlaces relativos en `.claude/skills/`. Lee solo la skill pertinente.

Ejecuta `python3 scripts/check_setup.py` tras cambios de configuración. `python3 scripts/doctor.py` inventaría herramientas sin instalar paquetes ni tocar KDE. Estos checks no prueban el escritorio ni validan QML futuro.

Entrega: qué cambió, cómo se verificó, qué puede revisar el creador y qué queda pendiente. No declares una prueba ejecutada si solo has escrito su procedimiento.
