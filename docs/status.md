# Estado de Singlr

Fase: configuración del proyecto y de la coordinación. Todavía no hay producto implementado. La visión original permanece conservada en la raíz.

## Flujo vigente

El creador encarga el trabajo a Claude Code (Opus 5.5), arquitecto principal y orquestador. Claude delega en Codex 1 (interfaz y QML) y Codex 2 (integración, herramientas y calidad), ambos con `gpt-6.1-sol` en Medium, mediante `scripts/codex-route.sh`. Modo habitual: carpeta principal y un solo escritor a la vez. Ver [workflow.md](workflow.md).

## Verificado

- Estructura, instrucciones y cinco skills con enlaces compartidos preparados y comprobados; incluye `singlr-product-craft` y `singlr-interface-refinement` del ZIP aportado por el creador.
- Identidad Git local configurada y commit inicial `f38dd34` registrado.
- `origin` conectado a `https://github.com/vanenyx/singlr.git`; sin push realizado.
- Plugin `codex@openai-codex` 1.0.6 instalado y habilitado localmente en el checkout principal.
- Enrutamiento por cuenta: cada rol usa su `CODEX_HOME`, con estado y broker aislados. Hay una tarea de solo lectura por rol con el modelo y el esfuerzo previstos. Detalle en [agents/setup.md](agents/setup.md#enrutamiento-por-cuenta).
- Worktrees anteriores conservados como opción para escritura paralela, no como flujo habitual. Sus instrucciones requieren sincronización antes de reutilizarlos.

## Pendientes de coordinación

- Validar en el primer encargo real una tarea con `--write`, la continuación con `--resume-last` y la carga de skills de Codex.
- Tres brokers del plugin de la prueba anterior siguen activos con cwd en un directorio temporal; pueden detenerse.

No repetir llamadas de prueba a modelos salvo que una tarea de configuración lo necesite; `setup --json` comprueba cada cuenta sin consumir modelo.

## Trabajo de producto futuro

Cuando el creador lo encargue: Claude definirá requisitos y contratos, Codex 1 implementará la interfaz y Codex 2 preparará integración, herramientas y verificación. No se inicia desarrollo con esta configuración.

La licencia y visibilidad de publicación siguen pendientes. La entrega inicial está en [handoffs/setup.md](handoffs/setup.md); la coordinación, en [handoffs/coordination.md](handoffs/coordination.md); el modelo de colaboración, en [handoffs/collaboration-model.md](handoffs/collaboration-model.md). Los checks de preparación no prueban una experiencia Plasma ejecutable.
