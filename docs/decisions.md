# Registro de decisiones

La fuente de producto es [la recuperación original](../SINGLR_recuperacion_desde_mensajes_originales.md). No repetir aquí todo su contenido.

| ID | Clase | Estado | Decisión y procedencia |
| --- | --- | --- | --- |
| P-001 | Explícita del creador | Vigente | En esta etapa solo configurar proyecto, repo, skills, documentación y agentes. Solicitud de 2026-10-23. |
| T-001 | Técnica derivada | Aplicada | Instrucciones comunes en AGENTS.md; CLAUDE.md las importa. Evita definiciones contradictorias. |
| T-002 | Técnica derivada | Aplicada | Skills locales versionadas en .agents/skills y enlaces relativos desde .claude/skills. |
| T-003 | Técnica derivada | Sustituida como flujo habitual por P-003 | Checkouts aislados preparados inicialmente. Se conservan como opción para escritura paralela, con integración de ramas cuando se utilicen. |
| P-002 | Propuesta por validar | Pendiente | Licencia, visibilidad del remoto y decisiones futuras de diseño y arquitectura. |
| P-003 | Explícita del creador | Vigente | Actualizar las instrucciones al flujo presentado y aceptado en esta conversación: el creador encarga a Claude, Claude realiza sus tareas y coordina los dos roles Codex mediante el plugin; carpeta principal con escritura por turnos y worktrees opcionales. |
| T-004 | Técnica derivada | Pendiente de configuración completa | Dos entornos respondieron mediante el script del plugin. Falta seleccionar cuenta explícitamente por encargo y verificar el ciclo cotidiano de delegación/continuación. La actualización documental no implementa esa automatización. |

Para nuevas entradas: ID, clase, estado, motivo, evidencia/autor y consecuencias. Una decisión técnica no aprueba decisiones perceptibles de producto.
