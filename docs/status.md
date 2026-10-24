# Estado de Singlr

Fase: configuración del proyecto y de la coordinación. Todavía no hay producto implementado. La visión original permanece conservada en la raíz.

## Flujo vigente

El creador encarga el trabajo a Claude Code. Claude realiza arquitectura/integración, delega tareas acotadas a Codex 1 y Codex 2 mediante el plugin oficial y consolida los resultados. Modo habitual: carpeta principal y un solo escritor a la vez. Ver [workflow.md](workflow.md).

## Verificado

- Estructura, instrucciones, skills y enlaces compartidos preparados y comprobados.
- Identidad Git local configurada y commit inicial `f38dd34` registrado.
- `origin` conectado a `https://github.com/vanenyx/singlr.git`; sin push realizado.
- Plugin `codex@openai-codex` instalado y habilitado localmente en el checkout principal.
- Prueba breve del script del plugin: respuestas `SINGLR_OK_1` y `SINGLR_OK_2` desde los dos entornos de cuenta existentes.
- Worktrees anteriores conservados como opción para escritura paralela, no como flujo habitual. Sus instrucciones requieren sincronización antes de reutilizarlos.

## Pendientes de coordinación

- Selector explícito del entorno de cuenta por encargo, sin cambiar credenciales globales.
- Validación del uso cotidiano del plugin, con asignación de roles y recuperación/continuación de las sesiones correctas; `/codex:rescue` todavía no se ha probado.
- Confirmación de Node/CLI y carga de skills desde la sesión de Claude que se vaya a usar. El Markdown no configura estos mecanismos por sí solo.

No es necesario abrir tres sesiones Desktop para cerrar esta preparación. No repetir llamadas de prueba a modelos salvo que una tarea de configuración lo necesite.

## Trabajo de producto futuro

Cuando el creador lo encargue: Codex 1 explorará escenarios visuales integrados, Claude estudiará su viabilidad/arquitectura y Codex 2 preparará herramientas y verificación. No se inicia desarrollo con esta actualización documental.

La licencia y visibilidad de publicación siguen pendientes. La entrega inicial está en [handoffs/setup.md](handoffs/setup.md); la actualización del flujo, en [handoffs/coordination.md](handoffs/coordination.md). Los checks de preparación no prueban una experiencia Plasma ejecutable.
