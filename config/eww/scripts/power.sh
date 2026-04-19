#!/usr/bin/env bash
# power.sh — lock / logout / reboot / poweroff con wofi confirm.
# Lock es directo (no destructivo).  El resto pide confirmación via wofi
# para que un click accidental no tire la sesión o apague la máquina.

set -eu

confirm() {
    # $1 = prompt, $2 = acción label que se compara como "yes"
    local prompt="$1" action="$2"
    printf '%s\nCancelar' "$action" | wofi --dmenu --prompt "$prompt" 2>/dev/null || true
}

case "${1:-}" in
    lock)
        hyprlock &
        ;;
    logout)
        choice=$(confirm "¿Salir de Hyprland?" "Salir")
        [[ "$choice" == "Salir" ]] && hyprctl dispatch exit
        ;;
    reboot)
        choice=$(confirm "¿Reiniciar el sistema?" "Reiniciar")
        [[ "$choice" == "Reiniciar" ]] && systemctl reboot
        ;;
    poweroff)
        choice=$(confirm "¿Apagar el sistema?" "Apagar")
        [[ "$choice" == "Apagar" ]] && systemctl poweroff
        ;;
    suspend)
        systemctl suspend
        ;;
    *)
        echo "uso: power.sh {lock|logout|reboot|poweroff|suspend}" >&2
        exit 1
        ;;
esac
