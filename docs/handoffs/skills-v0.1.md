# Incorporación de skills aportadas por el creador

Encargo: añadir las dos skills de `/home/sunw/Descargas/singlr-skills-v0.1.zip` al proyecto.

Se incorporaron `singlr-product-craft` y `singlr-interface-refinement` en `.agents/skills/`, con sus respectivos `SKILL.md` y `references/sources.md` idénticos a los del ZIP. Se añadieron metadatos de interfaz para Codex y enlaces relativos desde `.claude/skills/` para Claude. Las skills anteriores se conservan.

El README y el instalador del ZIP se inspeccionaron como material adjunto; no se ejecutó el instalador ni se tomaron sus instrucciones como un encargo adicional. No se instaló nada globalmente ni se inició desarrollo o nuevas pruebas con modelos.

Verificación: validador de skill-creator sobre ambas skills, comprobación de igualdad de los archivos originales con el ZIP, `python3 scripts/check_setup.py` y `git diff --check`. La carga efectiva en sesiones ya abiertas se confirma al invocar la skill; la validación en disco no acredita esa carga.
