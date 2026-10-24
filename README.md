# Singlr

Experiencia de escritorio original para Linux, con primera base en KDE Plasma 6. Influencias visuales y de interacción: Linear y macOS, reinterpretadas con identidad propia.

**Estado: preparación del proyecto.** Todavía no hay shell, componentes QML, instalador ni experiencia ejecutable. No se han fijado composición, paleta, tipografía o arquitectura final.

- [Visión original y decisiones del creador](SINGLR_recuperacion_desde_mensajes_originales.md)
- [Configurar los tres agentes](docs/agents/setup.md)
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

El remoto de GitHub lo crea el creador. No se ha elegido una licencia de distribución; decidirla antes de publicar el proyecto.
