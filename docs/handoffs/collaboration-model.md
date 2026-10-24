# Modelo permanente de colaboración

Encargo del creador (2026-10-23): dejar operativo y documentado el modelo Claude (Opus 5.5) como arquitecto y orquestador, con Codex 1 y Codex 2 en `gpt-6.1-sol` Medium, enrutados por cuenta, sin iniciar desarrollo. Agente: Claude, carpeta principal, rama `main`.

## Resultado

- `scripts/codex-route.sh`: selector de cuenta por rol sobre el plugin 1.0.6, con estado y broker aislados, modelo y esfuerzo por defecto, bloqueo de un escritor por carpeta y review gate bloqueado. Plantilla de rutas en `scripts/codex-accounts.example`; la copia local está en `.local/codex-accounts.env`, no versionada.
- `docs/workflow.md`: roles, enrutamiento, ciclo de tarea, reglas de uso eficiente y procedimientos alternativos.
- Plantilla de encargo en `docs/handoffs/README.md`.
- Perfiles de Claude, Codex 1 y Codex 2; AGENTS.md, CLAUDE.md, `docs/agents/setup.md`, `docs/decisions.md` (P-004, T-005) y `docs/status.md`.
- Skills sin cambios.

## Hallazgos sobre el plugin

Se revisó el código instalado (`codex-companion.mjs` y `lib/`). No hay selector de cuenta: usa `CODEX_HOME` del proceso y lanza `codex` desde `PATH`. Estado, jobs, `--resume-last` y un broker persistente separado se guardan por carpeta. Sin aislamiento, una tarea de la cuenta 2 podría reutilizar el broker de la cuenta 1 en la misma carpeta. El hook de cierre solo detiene el broker del estado por defecto. `/codex:rescue` pasa por un subagente reenviador y no puede elegir cuenta. El review gate viene desactivado por defecto.

## Verificación

- `setup --json` con cada rol: listo y con sesión activa en dos cuentas distintas.
- Tarea de solo lectura con cada rol: `SINGLR_ROUTE_OK_1` y `SINGLR_ROUTE_OK_2`. Los hilos `01a16c16-e2b9-…` y `01a16c16-f7a2-…` aparecen solo en `sessions/` de su `CODEX_HOME`, con `gpt-6.1-sol` y `medium`. Job de Codex 2: `task-mvlvna8x-cq7d6l`.
- `stop` detuvo los dos brokers; se comprobaron los rechazos de entradas no permitidas.
- `bash -n scripts/codex-route.sh`, `python3 scripts/check_setup.py` y `git diff --check`. Shellcheck no está instalado.

## Pendiente

- Primer encargo real: validar `--write`, `--resume-last` y la carga de skills de Codex.
- Tres brokers de la prueba anterior siguen activos; detenerlos con autorización del creador.
