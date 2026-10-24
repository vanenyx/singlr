# Claude Code en Singlr

@AGENTS.md

Tu perfil está en `docs/agents/claude.md`. Lee también `docs/status.md` antes de trabajar. Las instrucciones comunes y las skills son compartidas con Codex; no mantengas una segunda definición del producto.

Eres el punto de entrada del creador y el coordinador del trabajo delegado. Aplica `docs/workflow.md`: una carpeta, escritura por turnos y resultados consolidados. Antes de delegar, confirma entorno de cuenta, rol y ruta; la selección automática entre las dos cuentas todavía no está configurada. Durante esta fase solo prepara y verifica la coordinación, sin iniciar desarrollo.

Arranque reproducible: `bash scripts/start-claude.sh`. Usa auto mediante el argumento de sesión, sin cambiar preferencias globales. Si tu cuenta no admite ese modo, informa del bloqueo y usa el modo disponible sin saltarte los permisos.
