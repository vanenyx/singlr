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

`.codex/config.toml` propone `workspace-write` y `on-request` sin fijar modelo o cuenta. Las opciones de sesión y políticas del host pueden prevalecer. Claude tiene `acceptEdits` como valor de proyecto; el lanzador solicita `auto` para esa sesión. Verifica permisos efectivos sin cambiar preferencias globales por deducción de estos documentos.

## Plugin y prueba realizada

El plugin oficial [Codex para Claude Code](https://github.com/openai/codex-plugin-cc), versión 1.0.6 en la prueba, está instalado y habilitado con alcance local para el checkout principal. Usa el CLI/servicio local de Codex; no controla automáticamente las dos ventanas Desktop.

Se usó la entrada `codex-companion.mjs task` desde un directorio temporal vacío con cada entorno. Resultados observados:

| Alias operativo | CODEX_HOME local | Respuesta |
| --- | --- | --- |
| Cuenta 1 | `/home/sunw/.codex` | `SINGLR_OK_1` |
| Cuenta 2 | `/home/sunw/.local/share/chatgpt-cuenta2/codex` | `SINGLR_OK_2` |

Son los entornos existentes de las dos aplicaciones. La prueba acredita respuestas desde ambos entornos, sin certificar identidades por correo. No se cambiaron credenciales. Hubo tres solicitudes en total: una adicional accidental al intentar consultar ayuda y las dos confirmaciones. No repetir esos pings como requisito rutinario de arranque.

La configuración local del plugin y la evidencia en `.local/integration-smoke/` no se versionan; un clon nuevo no hereda esa instalación. El Node disponible para la prueba provenía del runtime incluido con la app; no asumir que `node` esté en el PATH de una terminal nueva.

## Pendiente antes de delegar desarrollo

- Preparar una manera explícita de seleccionar cada entorno por proceso, sin cambiar globalmente la cuenta de las apps ni copiar credenciales al repo. No asumir que el plugin ofrece un selector de dos cuentas por tarea.
- Validar el punto de entrada de uso cotidiano, por ejemplo `/codex:rescue`, con rol, carpeta, modo de acceso y recuperación/continuación de la sesión correcta. El script funcionó; ese ciclo completo aún no se ha probado.
- Verificar que Claude dispone del CLI y Node en su entorno y que las skills pertinentes se cargan en cada encargo real.
- Asociar el rol al encargo y registrar entorno e identificador de trabajo/sesión. Codex 1 se especializa en diseño/implementación y Codex 2 en herramientas/calidad; una cuenta no asigna el rol por sí sola.

Esta actualización de Markdown documenta el flujo; no implementa un selector ni autoriza llamadas adicionales o desarrollo. Si se encarga configurar la conexión restante, usar pruebas mínimas, sin review gates ni reintentos de modelos innecesarios.

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
