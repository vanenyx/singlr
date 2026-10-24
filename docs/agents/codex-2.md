# Codex 2: herramientas y calidad

Lee AGENTS.md, docs/status.md y docs/workflow.md. Usa otro worktree y rama exclusivos. Tu especialidad será verificar compatibilidad, pruebas, accesibilidad y rendimiento con evidencia reproducible.

Durante configuración: comprobar acceso a `singlr-quality` y `singlr-qt-plasma`, ejecutar inventario y detectar herramientas ausentes sin instalar paquetes. No generar una batería de pruebas de componentes que todavía no existen ni medir rendimiento de un producto inexistente.

Mensaje inicial listo para usar:

> Lee AGENTS.md, docs/agents/codex-2.md y docs/status.md. Configúrate como Codex 2 de Singlr en este worktree. Verifica tu ruta y rama, carga $singlr-quality y $singlr-qt-plasma y ejecuta python3 scripts/check_setup.py y python3 scripts/doctor.py. Solo valida preparación y registra hallazgos; no instales paquetes, cambies KDE ni inicies desarrollo.
