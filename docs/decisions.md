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
| T-004 | Técnica derivada | Sustituida por T-005 | Dos entornos respondieron mediante el script del plugin, sin selector de cuenta por encargo. |
| P-004 | Explícita del creador | Vigente | Modelo permanente de colaboración (2026-10-23): Claude Code con Opus 5.5 como arquitecto principal y orquestador. Codex 1 con `gpt-6.1-sol` en Medium para interfaz, Qt Quick/QML e interacciones. Codex 2 con `gpt-6.1-sol` en Medium para integración, herramientas, pruebas, rendimiento, errores y revisión independiente. High solo si se justifica. Encargos autocontenidos y sin review gates permanentes. Ver [workflow.md](workflow.md). |
| T-005 | Técnica derivada | Aplicada | `scripts/codex-route.sh` asigna Codex 1 → cuenta 1 y Codex 2 → cuenta 2 mediante `CODEX_HOME`, con estado y broker del plugin aislados por rol. Motivo: el plugin 1.0.6 no tiene selector de cuenta y comparte el broker por carpeta. La correspondencia se ajusta en `.local/codex-accounts.env`. |
| P-005 | Explícita del creador | Vigente | Dirección visual (2026-10-24): se descartan A y B. Base: filosofía, estilo y diseño de Linear en UI y UX. Sobre ella, identidades de macOS (glassmorphism, no Liquid Glass) y de Raycast (superficies de comando, listas, acciones, teclado). Fondos sobrios al estilo de Linear. Ver [brief v2](phase1/brief.md). |
| P-007 | Explícita del creador | Vigente | Liquid Glass queda descartado también como opción futura (2026-10-24). Sustituye a la preferencia de la visión original de mantenerlo opcional y ajustable. El material translúcido de Singlr es el glassmorphism. |
| P-006 | Explícita del creador | Vigente | Fase 1 iniciada (2026-10-24): dirección visual y prototipo integrado, en entorno aislado que no altera la sesión KDE. |
| P-008 | Explícita del creador | Vigente | Dock con el modelo de macOS (2026-10-24): un icono por app. El clic trae la app al frente (todas sus ventanas, la última usada encima) y nunca minimiza. La ventana concreta se elige con el menú contextual o con Alt+` de KWin. Sin ciclo por clics ni rueda. |

Para nuevas entradas: ID, clase, estado, motivo, evidencia/autor y consecuencias. Una decisión técnica no aprueba decisiones perceptibles de producto.
