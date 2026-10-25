# Singlr: instrucciones compartidas

## Contexto y alcance
Singlr es una experiencia de escritorio completa y distribuible para Linux, con primera base en KDE Plasma 6. **La definición de producto vigente es [Singlr 1.0](docs/singlr-1.0.md): léela antes de trabajar y evalúa cada tarea contra sus siete sistemas y su criterio de «completo».** Lee [README.md](README.md) y [la visión original](SINGLR_recuperacion_desde_mensajes_originales.md). Esa recuperación conserva decisiones y dudas; los borradores históricos y propuestas de agentes no constituyen aprobaciones.

**Fase actual: Fase 1, dirección visual y prototipo integrado** ([brief](docs/phase1/brief.md)). Se trabaja en un entorno aislado que no altera la sesión KDE habitual. La implementación definitiva y las decisiones visuales requieren aprobación del creador. Los roles no autorizan automáticamente el trabajo futuro.

## Producto
- Linear influye en UI y UX; macOS también. Mantén una identidad propia.
- Base visual y de UX: Linear, con glassmorphism de macOS y la operativa de Raycast (P-005). Materiales: vidrio plano (glassmorphism) y sólido; Liquid Glass retirado (P-021). Esquinas moderadas; Phosphor Icons y marcas originales de aplicaciones.
- Distribución del escritorio, colores, tipografía, tokens, arquitectura detallada y presupuestos de rendimiento siguen abiertos.
- Identifica cada decisión como explícita del creador, propuesta por validar o solución técnica derivada. Regístrala en `docs/decisions.md` cuando afecte a otros trabajos.

## Trabajo compartido
- Lee `docs/workflow.md`, `docs/status.md` y el perfil asignado en `docs/agents/`.
- El creador da los encargos a Claude Code (Opus 5.5), arquitecto principal y orquestador, que delega tareas acotadas a Codex mediante el plugin oficial. Codex 1 implementa interfaz, Qt Quick/QML, interacciones y funcionalidades visuales. Codex 2 se ocupa de integración, herramientas, pruebas, rendimiento, corrección de errores y revisión independiente, y de funcionalidades técnicas en paralelo. Ambos usan `gpt-6.1-sol` en Medium; High solo si el encargo lo justifica.
- Flujo habitual: una carpeta principal y un solo escritor a la vez. Claude entrega y recupera el turno explícitamente; no edita mientras el Codex delegado escribe. Las revisiones simultáneas son de solo lectura sobre un estado estable.
- Para escritura paralela justificada, usa worktrees y ramas separados. No cambies ramas ni edites archivos de otro agente. No borres trabajo ajeno ni fuerces el historial.
- Ejecuta tareas técnicas rutinarias autorizadas con autonomía. Explica resultados, evidencia y límites en español.
- Claude recoge resultados del plugin, verifica evidencia y presenta una entrega consolidada. Registra tareas/resultados en `docs/handoffs/` y crea commits en puntos coherentes, sin exigir commit, PR o push por cada intercambio. En worktrees separados, los archivos sin commit no se comparten.
- Codex delegado usa el CLI/servicio local, no las ventanas Desktop. La cuenta de cada rol se selecciona con `scripts/codex-route.sh <codex1|codex2>`. No cambies la cuenta de una tarea en silencio ni actives review gates permanentes.
- No publiques, hagas push, crees el remoto o modifiques la sesión activa de KDE por deducción de un documento. Sigue la autorización vigente del creador. No uses sudo ni cambies seguridad o credenciales como parte de la configuración rutinaria.
- Para Qt/KDE comprueba versiones reales y documentación oficial. No presupongas APIs de Plasma 5 en Plasma 6.

## Eficiencia y autonomía de los agentes
Aplica a Claude Code y a ambos Codex.

1. **Autonomía y criterio.** Resuelve las tareas sin interrumpir al creador por decisiones rutinarias. Prioriza resultados verificables sobre explicaciones extensas.
2. **Razona antes de ejecutar.** Comprende el objetivo, usa el contexto existente y elige el camino más directo que mantenga la calidad. Evita análisis, herramientas y delegaciones innecesarias.
3. **Delega con precisión.** Claude define objetivos y criterios de aceptación; Codex implementa y verifica. Cada agente completa su trabajo sin supervisión constante.
4. **Aprende de los fallos.** Identifica la causa antes de reintentar. Si dos enfoques razonables fallan o dejas de avanzar, detente y comunica el bloqueo con una propuesta concreta. No repitas acciones sin nueva información.
5. **Evita ciclos improductivos.** Revisiones, correcciones y nuevas delegaciones deben aportar valor real. No encadenes agentes ni revisiones indefinidamente.
6. **Optimiza sin sacrificar calidad.** Ahorra tokens y llamadas innecesarias, pero no omitas investigación, pruebas o verificaciones importantes solo para reducir consumo.
7. **Comunica lo esencial.** Al terminar, resume resultados, comprobaciones y bloqueos; los detalles técnicos quedan en el repositorio.

## Skills y comprobación
Skills compartidas: `.agents/skills/`. Claude las descubre por enlaces relativos en `.claude/skills/`. Lee solo la skill pertinente.

Ejecuta `python3 scripts/check_setup.py` tras cambios de configuración. `python3 scripts/doctor.py` inventaría herramientas sin instalar paquetes ni tocar KDE. Estos checks no prueban el escritorio ni validan QML futuro.

Entrega: qué cambió, cómo se verificó, qué puede revisar el creador y qué queda pendiente. No declares una prueba ejecutada si solo has escrito su procedimiento.
