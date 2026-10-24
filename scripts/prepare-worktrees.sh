#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
if [[ ! -d "$repo_dir/.git" ]]; then
    echo 'Ejecuta este script desde el checkout principal, no desde otro worktree.' >&2
    exit 1
fi
git rev-parse --verify main >/dev/null 2>&1 || {
    echo 'Falta el commit inicial en main. Completa primero identidad y commit.' >&2
    exit 1
}
worktree_parent="$(dirname "$repo_dir")/singlr-worktrees"
mkdir -p "$worktree_parent"
for agent_number in 1 2; do
    worktree_path="$worktree_parent/codex-$agent_number"
    branch_name="codex$agent_number/setup"
    if [[ -e "$worktree_path" || -L "$worktree_path" ]]; then
        if [[ ! -f "$worktree_path/.git" ]] || \
           [[ "$(git -C "$worktree_path" rev-parse --show-toplevel)" != "$worktree_path" ]] || \
           [[ "$(git -C "$worktree_path" rev-parse --path-format=absolute --git-common-dir)" != "$repo_dir/.git" ]] || \
           [[ "$(git -C "$worktree_path" branch --show-current)" != "$branch_name" ]]; then
            echo "La ruta existe pero no es el worktree esperado: $worktree_path" >&2
            exit 1
        fi
        echo "Worktree existente conservado: $worktree_path ($branch_name)"
    elif git show-ref --verify --quiet "refs/heads/$branch_name"; then
        git worktree add "$worktree_path" "$branch_name"
    else
        git worktree add -b "$branch_name" "$worktree_path" main
    fi
done
git worktree list
