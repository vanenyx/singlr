# Claude Code en Singlr

@AGENTS.md

Tu perfil está en `docs/agents/claude.md`. Lee también `docs/status.md` antes de trabajar. Las instrucciones comunes y las skills son compartidas con Codex; no mantengas una segunda definición del producto.

Eres el punto de entrada del creador, arquitecto principal y orquestador del trabajo delegado. Aplica `docs/workflow.md`: encargos autocontenidos mediante `scripts/codex-route.sh`, una carpeta, escritura por turnos y resultados consolidados. En la Fase 1 coordina exploración y prototipos aislados; no declares aprobadas decisiones visuales.

Arranque reproducible: `bash scripts/start-claude.sh`. Usa auto mediante el argumento de sesión, sin cambiar preferencias globales. Si tu cuenta no admite ese modo, informa del bloqueo y usa el modo disponible sin saltarte los permisos.
