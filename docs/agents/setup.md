# Preparar y abrir los tres agentes

## Qué está configurado por repositorio

AGENTS.md contiene las instrucciones comunes. CLAUDE.md las importa. Los perfiles de esta carpeta definen responsabilidades y mensajes de arranque. Las tres skills se versionan en `.agents/skills/` y se exponen a Claude mediante enlaces relativos en `.claude/skills/`, conservados por Git en Linux.

`.codex/config.toml` propone `workspace-write` y `on-request` sin fijar modelo ni cuenta. Las opciones de la sesión/app o políticas del host pueden prevalecer; comprueba los permisos efectivos en cada instancia. Esta preparación no cambia preferencias globales de las dos cuentas.

Claude usa `acceptEdits` como valor de proyecto. El lanzador añade `--permission-mode auto` para esa sesión: `auto` no se activa mediante settings de proyecto en la versión actual. Su disponibilidad depende de la cuenta; si no está disponible, inicia con `--permission-mode acceptEdits` y conserva el resto de la configuración.

## Git y aislamiento

En esta máquina ya están configurados `origin` con `https://github.com/vanenyx/singlr.git` y la identidad local facilitada por el creador. El commit inicial y los dos worktrees están creados. Los pasos siguientes permiten reproducir la preparación en otra instalación; no hace falta repetir la identidad en los worktrees, pues comparten la configuración Git del repo.

La identidad debe ser la que el creador elija, configurada solo en este repo:

```bash
git config --local user.name 'TU NOMBRE'
git config --local user.email 'TU CORREO'
```

Después del commit inicial, `bash scripts/prepare-worktrees.sh` crea, si no existen:

| Agente | Ruta respecto del directorio Projects | Rama |
| --- | --- | --- |
| Claude | `singlr/` | `main` para integración; rama de tarea al cambiar código |
| Codex 1 | `singlr-worktrees/codex-1/` | `codex1/setup` |
| Codex 2 | `singlr-worktrees/codex-2/` | `codex2/setup` |

El script nunca reinicia un checkout existente. Repetirlo verifica rutas y ramas. Para nuevas tareas se crean nuevas ramas sin reutilizar una rama ya integrada.

## Abrir Claude

Desde `singlr/`, ejecutar `bash scripts/start-claude.sh`. Localiza Claude también en `~/.local/bin`, de modo que no depende del PATH de esta terminal. Abre una sesión interactiva, con el mensaje de verificación de su perfil. No lanza desarrollo por sí mismo desde este chat.

Confirmar en la sesión `/status`, `/permissions` y que aparecen `/singlr-ui-design`, `/singlr-qt-plasma` y `/singlr-quality`. `claude doctor` puede comprobar la instalación; esta comprobación no acredita por sí sola la carga de todas las skills.

## Abrir cada Codex Desktop

En la primera instancia, añadir/abrir como proyecto la ruta de `codex-1`; en la segunda, la de `codex-2`. Son worktrees Git ya creados: trabajar en modo local sobre esas rutas. Crear un chat en cada instancia y usar el mensaje de su perfil.

Alternativamente, abrir `singlr/` en ambas apps y crear un Worktree administrado por cada app desde `main`. En ese caso, no utilizar a la vez los worktrees manuales para esas mismas tareas.

Comprobar en cada instancia que lee AGENTS.md, encuentra las tres skills y muestra una rama propia. Si las skills no aparecen, iniciar un chat nuevo o reiniciar esa instancia. No es necesario copiarlas al directorio global de cada cuenta. Se conserva el modelo seleccionado por cada usuario.

La elección de proyecto, la sesión autenticada y los permisos de la UI deben verificarse en cada aplicación. Los perfiles en Markdown no cambian esos controles ni crean automáticamente sesiones en otra instancia.

## Conectar GitHub después

El remoto ya está conectado en esta máquina. Comprobarlo con `git remote -v`; hacer push cuando esté autorizado. En otra instalación, usar la URL facilitada por el creador. Resolver visibilidad/licencia antes de publicar; no inventar identidad ni credenciales. Las ramas y entregas funcionan localmente mientras tanto.

## Fuentes verificadas

Consultadas el 2026-10-23:

- [Skills locales de Codex y enlaces simbólicos](https://learn.chatgpt.com/docs/build-skills)
- [Configuración por proyecto de Codex](https://learn.chatgpt.com/docs/config-file/config-basic)
- [Skills de Claude y enlaces simbólicos](https://code.claude.com/docs/en/skills)
- [Precedencia y límites de settings de Claude](https://code.claude.com/docs/en/settings)
- [Permisos de Claude](https://code.claude.com/docs/en/permissions)
