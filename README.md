# Singlr

Experiencia de escritorio original para Linux, con primera base en KDE Plasma 6. Influencias visuales y de interacción: Linear y macOS, reinterpretadas con identidad propia.

**Estado: preparación del proyecto.** Todavía no hay shell, componentes QML, instalador ni experiencia ejecutable. No se han fijado composición, paleta, tipografía o arquitectura final.

- [Visión original y decisiones del creador](SINGLR_recuperacion_desde_mensajes_originales.md)
- [Configurar Claude y sus colaboradores Codex](docs/agents/setup.md)
- [Reglas de colaboración](docs/workflow.md)
- [Estado y siguientes tareas](docs/status.md)
- [Registro de decisiones](docs/decisions.md)
- [Situación técnica](docs/architecture.md)

## Comprobar la preparación

Requisitos de esta fase: Git y Python 3.11 o posterior.

```bash
python3 scripts/check_setup.py
python3 scripts/doctor.py
```

Las skills están versionadas en `.agents/skills/` y compartidas con Claude mediante enlaces en `.claude/skills/`. No necesitan instalarse globalmente ni contratar servicios adicionales.

También están incorporadas las skills aportadas por el creador: [Product Craft](.agents/skills/singlr-product-craft/SKILL.md) e [Interface Refinement](.agents/skills/singlr-interface-refinement/SKILL.md), con sus referencias originales. El catálogo y uso están en la [guía de agentes](docs/agents/setup.md).

## Flujo de trabajo

El creador da instrucciones a Claude Code. Claude realiza arquitectura/integración, delega trabajos acotados a Codex 1 o Codex 2 mediante el plugin oficial y consolida resultados. Se trabaja habitualmente en la carpeta principal, con un único escritor por turno. Los worktrees quedan para escritura paralela justificada.

La prueba breve obtuvo respuesta de ambos entornos de Codex; todavía falta configurar la elección de cuenta por tarea y validar el flujo completo. Las ventanas Codex Desktop son opcionales para revisar o continuar trabajos, no agentes automáticamente controlados por Claude.

`origin` está conectado al remoto proporcionado por el creador; no se ha hecho push. No se ha elegido una licencia de distribución; decidirla antes de publicar el proyecto.
