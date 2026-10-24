# Preparar el flujo coordinado desde Claude

## Punto de entrada

El creador trabaja habitualmente desde Claude Code en `/home/sunw/Projects/singlr`. Claude coordina sus tareas y las de Codex 1/Codex 2 según [el flujo compartido](../workflow.md). Una carpeta con escritura por turnos es el modo habitual; las dos aplicaciones Desktop quedan disponibles para revisar o continuar trabajos de forma explícita.

Desde la carpeta principal:

```bash
bash scripts/start-claude.sh
```

El lanzador existente solo pide verificar la preparación. Para orientar esa sesión hacia la coordinación, usa el mensaje de [su perfil](claude.md). Ese mensaje tampoco inicia desarrollo. No es necesario abrir las dos apps Codex ni crear nuevos worktrees para este flujo.

## Instrucciones y skills

AGENTS.md contiene reglas comunes; CLAUDE.md las importa. Los perfiles de esta carpeta definen responsabilidades y contexto breve para encargos. Las skills se versionan en `.agents/skills/` y se exponen a Claude mediante enlaces relativos en `.claude/skills/`. No mantener copias globales contradictorias.

| Skill | Cuándo usarla |
| --- | --- |
| `singlr-ui-design` | Diseño integrado y fidelidad a la visión de Singlr |
| `singlr-interface-refinement` | Comparar y refinar composición, jerarquía, superficies e interacción |
| `singlr-product-craft` | Planificar o evaluar calidad de la experiencia completa y alcance de producto |
| `singlr-qt-plasma` | Investigar o implementar integración nativa Qt/KDE |
| `singlr-quality` | Verificar funcionamiento y calidad con evidencia reproducible |

Las dos skills del paquete `singlr-skills-v0.1.zip` se añadieron conservando sus instrucciones y referencias originales. Complementan las skills existentes; no fijan decisiones de producto ni requieren cargar las cinco en cada tarea. En Claude se invocan como `/singlr-product-craft` y `/singlr-interface-refinement`; en Codex, como `$singlr-product-craft` y `$singlr-interface-refinement`.

`.codex/config.toml` propone `workspace-write` y `on-request` sin fijar modelo o cuenta; modelo y esfuerzo los fija `scripts/codex-route.sh` en cada encargo. Las opciones de sesión y políticas del host pueden prevalecer. Claude tiene `acceptEdits` como valor de proyecto; el lanzador solicita `auto` para esa sesión. Verifica permisos efectivos sin cambiar preferencias globales por deducción de estos documentos.

## Plugin y prueba realizada

El plugin oficial [Codex para Claude Code](https://github.com/openai/codex-plugin-cc), versión 1.0.6 en la prueba, está instalado y habilitado con alcance local para el checkout principal. Usa el CLI/servicio local de Codex; no controla automáticamente las dos ventanas Desktop.

Se usó la entrada `codex-companion.mjs task` desde un directorio temporal vacío con cada entorno. Resultados observados:

| Alias operativo | CODEX_HOME local | Respuesta |
| --- | --- | --- |
| Cuenta 1 | `/home/sunw/.codex` | `SINGLR_OK_1` |
| Cuenta 2 | `/home/sunw/.local/share/chatgpt-cuenta2/codex` | `SINGLR_OK_2` |

Son los entornos existentes de las dos aplicaciones. La prueba acredita respuestas desde ambos entornos, sin certificar identidades por correo. No se cambiaron credenciales. Hubo tres solicitudes en total: una adicional accidental al intentar consultar ayuda y las dos confirmaciones. No repetir esos pings como requisito rutinario de arranque.

La configuración local del plugin y la evidencia en `.local/integration-smoke/` no se versionan; un clon nuevo no hereda esa instalación. El Node disponible para la prueba provenía del runtime incluido con la app; no asumir que `node` esté en el PATH de una terminal nueva.

Esa prueba usó el estado por defecto del plugin con ambas cuentas y no acreditaba aislamiento entre ellas. Además dejó tres brokers activos con cwd en el directorio temporal. La sustituye la validación del enrutamiento siguiente.

## Enrutamiento por cuenta

En un clon nuevo, copiar `scripts/codex-accounts.example` a `.local/codex-accounts.env` y ajustar las rutas. El funcionamiento está en [workflow.md](../workflow.md#enrutamiento-por-cuenta).

Comprobaciones realizadas el 2026-10-23 con `scripts/codex-route.sh`, plugin 1.0.6 y `codex-cli 0.163.0-alpha.11.1`:

- `setup --json` con cada rol: listo, sesión ChatGPT activa y dos cuentas distintas, review gate desactivado. No consume modelo.
- Una tarea de solo lectura por rol: `SINGLR_ROUTE_OK_1` y `SINGLR_ROUTE_OK_2`. Cada hilo quedó registrado únicamente en `sessions/` de su propio `CODEX_HOME`, con `gpt-6.1-sol` y esfuerzo `medium`.
- `status` muestra los jobs separados por rol; `stop` detuvo el broker de cada cuenta.
- Rechazos comprobados: rol desconocido, esfuerzo `xhigh`, `--background` con `--write` y `--enable-review-gate`.

Pendiente de validar en el primer encargo real: una tarea con `--write`, la continuación con `--resume-last` y la carga de skills de Codex desde el encargo.

## Git y worktrees opcionales

Identidad Git local y `origin` ya están configurados. Claude registra commits en puntos coherentes y gestiona Git; no hace falta commit/PR/push para pasar cada tarea al colaborador en la misma carpeta.

Se conservan `../singlr-worktrees/codex-1` y `../singlr-worktrees/codex-2` para escritura paralela futura, junto con `scripts/prepare-worktrees.sh`. No son el arranque habitual. Si se reutilizan, comprobar tareas activas, estado limpio y sincronizar sus instrucciones desde `main` antes de dar un nuevo encargo. No crear otro worktree encima de uno existente.

No se ha hecho push. La licencia y la visibilidad de publicación quedan por resolver antes de publicar el proyecto.

## Referencias

- [Plugin oficial de Codex para Claude Code](https://github.com/openai/codex-plugin-cc)
- [Estado y configuración de Codex mediante CODEX_HOME](https://learn.chatgpt.com/docs/config-file/config-advanced#config-and-state-locations)
- [Autenticación de Codex](https://learn.chatgpt.com/docs/auth)
- [Skills locales de Codex](https://learn.chatgpt.com/docs/build-skills)
- [Skills de Claude](https://code.claude.com/docs/en/skills)
- [Permisos de Claude](https://code.claude.com/docs/en/permissions)
