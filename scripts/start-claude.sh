#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
if command -v claude >/dev/null 2>&1; then
    claude_bin="$(command -v claude)"
elif [[ -x "$HOME/.local/bin/claude" ]]; then
    claude_bin="$HOME/.local/bin/claude"
else
    echo 'Claude Code no está disponible. Instálalo desde su fuente oficial.' >&2
    exit 1
fi
if [[ "${1:-}" == '--check' ]]; then
    "$claude_bin" --version
    exit
fi
exec "$claude_bin" --permission-mode auto \
    'Lee CLAUDE.md, AGENTS.md, docs/agents/claude.md y docs/status.md. Verifica únicamente la configuración del proyecto, instrucciones y skills. Informa de resultados y pendientes. No inicies diseño, implementación, instalaciones ni publicación.' "$@"
