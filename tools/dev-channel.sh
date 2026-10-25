#!/usr/bin/env bash
# Canal de desarrollo de Singlr en la sesión instalada del creador.
# enable : la sesión Singlr ejecuta el shell (barra, dock, paneles) desde este checkout.
# reload : recompila y reinicia solo el shell; las apps y la sesión siguen abiertas.
# disable: vuelve al shell empaquetado en /usr/lib/singlr.
# Sin sudo: un drop-in de usuario en ~/.config/systemd/user. La sesión, la pantalla de
# bloqueo y las unidades siguen siendo las del paquete instalado.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dropin="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/singlr-shell.service.d/dev-channel.conf"
build() {
    "$root/shell/session/build.sh" >/dev/null
    cmake --build "$root/build" >/dev/null
}
case "${1:-}" in
    enable)
        build
        mkdir -p "$(dirname "$dropin")"
        cat > "$dropin" <<CONF
# Creado por tools/dev-channel.sh; borrar con «tools/dev-channel.sh disable».
[Service]
Environment=SINGLR_DEV_ROOT=$root
Environment=QML_IMPORT_PATH=$root/build/qml
CONF
        echo "Canal de desarrollo activado: se aplica al próximo arranque del shell ($dropin)" ;;
    reload)
        build
        systemctl --user daemon-reload
        systemctl --user restart singlr-shell.service
        echo "Shell recargado desde $root" ;;
    disable)
        rm -f -- "$dropin"
        rmdir --ignore-fail-on-non-empty "$(dirname "$dropin")" 2>/dev/null || true
        echo "Canal de desarrollo desactivado: se aplica al próximo arranque del shell" ;;
    status)
        if [ -f "$dropin" ]; then echo "activo: $dropin"; else echo "inactivo"; fi ;;
    *) echo "uso: $0 enable|reload|disable|status" >&2; exit 2 ;;
esac
