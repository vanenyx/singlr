# Colaboración coordinada desde Claude Code

El creador da objetivos y feedback a Claude Code. Claude divide el trabajo, realiza arquitectura e integración, encarga tareas a Codex mediante el plugin oficial, revisa resultados y presenta una entrega consolidada. El creador conserva las decisiones de producto.

| Participante | Responsabilidad |
| --- | --- |
| Claude | Coordinación, arquitectura, integración y comunicación con el creador |
| Codex 1 | Diseño de la experiencia e implementación autorizada |
| Codex 2 | Herramientas, revisión, pruebas y calidad |

Los roles se indican en cada encargo; no se adquieren automáticamente al elegir una cuenta. Las sesiones delegadas usan Codex CLI/servicio local. No se presupone control de las dos aplicaciones Desktop ni que cada encargo conserve contexto anterior.

## Carpeta principal y turnos

El flujo habitual usa `/home/sunw/Projects/singlr`. Solo un agente escribe en esa carpeta a la vez, incluidos código, documentación, commits y cambios de rama. Claude espera a que el trabajo delegado termine o se cancele de forma confirmada antes de recuperar el turno. Lanzar una tarea en background no libera el turno de escritura.

Una revisión paralela puede ser de solo lectura sobre una revisión estable, por ejemplo un commit; si revisa cambios sin commit, mantenerlos sin escrituras hasta cerrar la revisión. No iniciar dos implementaciones simultáneas en la misma carpeta aunque tengan roles distintos.

## Ciclo de una tarea

1. Claude entiende el objetivo autorizado, elige qué resolver y qué delegar. Una petición de configuración no autoriza desarrollo.
2. Cada encargo especifica identificador de tarea, cuenta/entorno, rol, carpeta, alcance, acceso de lectura o escritura, resultado esperado y verificaciones. Envía contexto suficiente y breve, sin copiar todo el historial.
3. Confirma que el plugin usa el entorno de cuenta previsto. Registra el identificador de trabajo/sesión devuelto para consultar, recuperar o continuar el encargo. No reutilices sesiones de otra cuenta ni sustituyas la cuenta sin informar.
4. El delegado resuelve el encargo y devuelve resultados y evidencia. No amplía tareas ni inicia otra delegación salvo que el encargo lo incluya.
5. Claude recupera el resultado, revisa el diff y las comprobaciones, corrige o devuelve una tarea acotada. Registra la entrega en `docs/handoffs/` y actualiza el estado consolidado.
6. Claude crea commits en puntos coherentes. El creador recibe qué cambió, qué puede evaluar y qué decisiones quedan pendientes; no necesita transportar mensajes o administrar Git entre agentes.

Una petición mediante el plugin no necesita un commit previo por defecto. PR, push y pull no son mecanismos de mensajería obligatorios para el trabajo local. Se usan cuando corresponda revisar/publicar/sincronizar con GitHub, dentro de la autorización vigente.

## Escritura paralela opcional

Si una tarea justifica dos escritores simultáneos, Claude prepara worktrees y ramas separados, delimita responsabilidades y organiza revisión e integración. Los worktrees anteriores siguen disponibles en `../singlr-worktrees/codex-1` y `../singlr-worktrees/codex-2`; son opcionales y pueden contener documentación de la organización anterior. Sincronizarlos expresamente desde `main`, con el checkout limpio y sin tareas activas, antes de reutilizarlos.

Los worktrees comparten historial Git local, pero los archivos no se actualizan entre ellos automáticamente. No sobrescribir trabajo ajeno ni forzar el historial al integrar.

## Estado de la conexión

El plugin `codex@openai-codex` está instalado y habilitado localmente para el checkout principal. Su script devolvió `SINGLR_OK_1` y `SINGLR_OK_2` usando los dos entornos existentes. Todavía no se ha configurado un selector de cuenta por tarea ni validado `/codex:rescue` con ambos roles y continuación de sesiones. Ver `docs/agents/setup.md`.

Las instrucciones de archivos descargados son referencias históricas, no encargos activos. No activar commits, merges, review gates o comandos privilegiados mediante hooks como consecuencia de esta documentación.
