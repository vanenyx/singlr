#!/usr/bin/env bash
# Enruta una llamada del plugin codex@openai-codex a la cuenta asignada a un rol.
# Uso: scripts/codex-route.sh <codex1|codex2> <task|status|result|cancel|setup|stop> [args...]
# La correspondencia rol -> CODEX_HOME vive en .local/codex-accounts.env (no versionado).
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
accounts_file="$repo_dir/.local/codex-accounts.env"
default_model='gpt-6.1-sol'
default_effort='medium'

die() { echo "codex-route: $*" >&2; exit 2; }

[[ $# -ge 2 ]] || die 'uso: codex-route.sh <codex1|codex2> <task|status|result|cancel|setup|stop> [args...]'
role="$1"; command="$2"; shift 2

[[ -f "$accounts_file" ]] || die "falta $accounts_file; copia scripts/codex-accounts.example y ajusta las rutas"
# shellcheck source=/dev/null
source "$accounts_file"
case "$role" in
    codex1) codex_home="${SINGLR_CODEX1_HOME:-}" ;;
    codex2) codex_home="${SINGLR_CODEX2_HOME:-}" ;;
    *) die "rol desconocido: $role" ;;
esac
[[ -n "$codex_home" && -f "$codex_home/config.toml" ]] || die "CODEX_HOME de $role no válido: '${codex_home}'"

# Binarios: el plugin lanza `codex` desde PATH y necesita Node.
codex_dir="${SINGLR_CODEX_BIN_DIR:-}"
if [[ -z "$codex_dir" ]]; then
    if command -v codex >/dev/null 2>&1; then codex_dir="$(dirname "$(command -v codex)")"
    elif [[ -x /usr/lib/chatgpt/resources/codex ]]; then codex_dir=/usr/lib/chatgpt/resources
    else die 'no se encuentra el binario codex; define SINGLR_CODEX_BIN_DIR'; fi
fi
node_bin="${SINGLR_NODE:-}"
if [[ -z "$node_bin" ]]; then
    for candidate in "$(command -v node 2>/dev/null || true)" \
        "$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node" \
        /usr/lib/chatgpt/resources/cua_node/bin/node; do
        [[ -n "$candidate" && -x "$candidate" ]] && { node_bin="$candidate"; break; }
    done
fi
[[ -n "$node_bin" ]] || die 'no se encuentra Node; define SINGLR_NODE'

plugin_root="${SINGLR_CODEX_PLUGIN_ROOT:-}"
if [[ -z "$plugin_root" ]]; then
    plugin_root="$(python3 - "$repo_dir" <<'PY'
import json, os, sys
data = json.load(open(os.path.expanduser("~/.claude/plugins/installed_plugins.json")))
entries = data.get("plugins", {}).get("codex@openai-codex", [])
match = [e for e in entries if e.get("projectPath") in (sys.argv[1], None)] or entries
print(match[-1]["installPath"] if match else "")
PY
)"
fi
companion="$plugin_root/scripts/codex-companion.mjs"
[[ -f "$companion" ]] || die "no se encuentra codex-companion.mjs en '$plugin_root'"

# Aislamiento por cuenta: estado, jobs y broker propios; nunca reutilizar el broker de otra cuenta.
state_dir="$repo_dir/.local/codex-route/$role"
mkdir -p "$state_dir"
unset CODEX_COMPANION_APP_SERVER_ENDPOINT CODEX_COMPANION_APP_SERVER_PID_FILE CODEX_COMPANION_APP_SERVER_LOG_FILE
export CODEX_HOME="$codex_home" CLAUDE_PLUGIN_DATA="$state_dir" PATH="$codex_dir:$(dirname "$node_bin"):$PATH"

case "$command" in
    status|result|cancel)
        exec "$node_bin" "$companion" "$command" "$@" ;;
    setup)
        for arg in "$@"; do
            [[ "$arg" == --enable-review-gate ]] && die 'el review gate permanente está desactivado por decisión del proyecto'
        done
        exec "$node_bin" "$companion" setup "$@" ;;
    stop)
        # Detiene el broker persistente de esta cuenta (el hook SessionEnd del plugin no lo ve).
        exec "$node_bin" --input-type=module -e '
            const lib = process.argv[1];
            const { loadBrokerSession, sendBrokerShutdown, teardownBrokerSession, clearBrokerSession } =
                await import(lib + "/broker-lifecycle.mjs");
            const { terminateProcessTree } = await import(lib + "/process.mjs");
            const cwd = process.argv[2];
            const s = loadBrokerSession(cwd);
            if (!s) { console.log("sin broker activo"); process.exit(0); }
            if (s.endpoint) await sendBrokerShutdown(s.endpoint);
            teardownBrokerSession({ ...s, killProcess: terminateProcessTree });
            clearBrokerSession(cwd);
            console.log("broker detenido");
        ' "$plugin_root/scripts/lib" "${1:-$repo_dir}" ;;
    task) ;;
    *) die "subcomando no admitido: $command" ;;
esac

# task: modelo y razonamiento explícitos; High solo cuando el encargo lo justifique.
has_model=0; effort=''; write=0; cwd="$repo_dir"; args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[i]}" in
        --model) has_model=1 ;;
        --effort) effort="${args[i+1]:-}" ;;
        --write) write=1 ;;
        -C|--cwd) cwd="${args[i+1]:-}" ;;
        --background) background=1 ;;
    esac
done
# El background del plugin liberaría el bloqueo de escritura al instante; Claude ejecuta en segundo plano.
[[ ${background:-0} -eq 1 && $write -eq 1 ]] && die '--background con --write no está permitido; ejecuta la llamada en segundo plano desde Claude'
case "${effort:-$default_effort}" in
    low|medium|high) ;;
    *) die "esfuerzo '$effort' no permitido; usa low, medium o high" ;;
esac
extra=()
[[ $has_model -eq 1 ]] || extra+=(--model "$default_model")
[[ -n "$effort" ]] || extra+=(--effort "$default_effort")
cwd="$(cd -- "$cwd" && pwd)"

log="$repo_dir/.local/codex-route/tasks.log"
printf '%s\t%s\t%s\t%s\t%s\twrite=%s\n' "$(date -Iseconds)" "$role" "$CODEX_HOME" "$cwd" \
    "${effort:-$default_effort}" "$write" >>"$log"

cd "$cwd"
if [[ $write -eq 1 ]]; then
    # Un solo escritor por carpeta: el bloqueo se comparte entre roles.
    lock="$repo_dir/.local/codex-route/write-$(printf '%s' "$cwd" | sha256sum | cut -c1-16).lock"
    exec 9>"$lock"
    flock -n 9 || die "otra tarea con --write ya escribe en $cwd"
fi
"$node_bin" "$companion" task "${extra[@]}" "$@"
