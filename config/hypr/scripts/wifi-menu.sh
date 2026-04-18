#!/usr/bin/env bash
# Selector WiFi con wofi + nmcli.
# - Toggle: re-clickear el ícono en Waybar cierra el menú abierto
# - Listado con ícono de señal, cifrado y marca de red activa
# - Conectar (pide contraseña vía wofi si hace falta)
# - Toggle WiFi on/off
# - Desconectar / abrir nm-connection-editor

set -u

source "$(dirname "$0")/_wofi-popup.sh"

# Toggle-close: si ya hay una instancia corriendo, matamos su wofi hijo y salimos.
LOCK=/run/user/$(id -u)/wifi-menu.lock
if [[ -f "$LOCK" ]]; then
    pid=$(cat "$LOCK" 2>/dev/null || true)
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
        pkill -P "$pid" wofi 2>/dev/null
        kill "$pid" 2>/dev/null
        rm -f "$LOCK"
        exit 0
    fi
    rm -f "$LOCK"
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

notify() { command -v notify-send >/dev/null && notify-send -a "wifi-menu" "$@" || true; }

wofi_menu()     { wofi_popup "$1"; }
wofi_password() { wofi_popup "$1" --password; }

signal_icon() {
    local s=$1
    if   (( s >= 80 )); then echo "󰤨"
    elif (( s >= 60 )); then echo "󰤥"
    elif (( s >= 40 )); then echo "󰤢"
    elif (( s >= 20 )); then echo "󰤟"
    else                     echo "󰤯"
    fi
}

wifi_enabled() { [[ "$(nmcli -t radio wifi)" == "enabled" ]]; }

if ! wifi_enabled; then
    choice=$(printf "󰖩  Activar WiFi\n󰖪  Cancelar" | wofi_menu "WiFi desactivado") || exit 0
    case "$choice" in
        *Activar*) nmcli radio wifi on && notify "WiFi activado"; sleep 2 ;;
        *) exit 0 ;;
    esac
fi

# Refrescar escaneo en segundo plano y esperar brevemente
nmcli device wifi rescan >/dev/null 2>&1 &
sleep 0.4

active_ssid=$(nmcli -t -f ACTIVE,SSID device wifi | awk -F: '$1=="yes"{print $2; exit}')

# Construir lista (deduplicada por SSID, mejor señal primero)
mapfile -t networks < <(
    nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list \
    | awk -F: 'length($4){print}' \
    | sort -t: -k2,2 -nr \
    | awk -F: '!seen[$4]++' \
    | while IFS=: read -r inuse signal security ssid; do
        icon=$(signal_icon "$signal")
        lock=" "; [[ -n "$security" && "$security" != "--" ]] && lock="󰍁"
        mark=" "; [[ "$inuse" == "*" ]] && mark="󰄬"
        printf "%s %s %s  %-3s%%  %s\n" "$mark" "$icon" "$lock" "$signal" "$ssid"
    done
)

header=()
[[ -n "$active_ssid" ]] && header+=("󰖪  Desconectar de ${active_ssid}")
header+=("󰖩  Apagar WiFi")
header+=("󰑐  Reescanear")
header+=("󰒓  Editor avanzado (nm-connection-editor)")
header+=("─────────────────────────")

selection=$(printf "%s\n" "${header[@]}" "${networks[@]}" | wofi_menu "Red WiFi") || exit 0

case "$selection" in
    *Desconectar*)
        nmcli connection down id "$active_ssid" && notify "Desconectado de $active_ssid"
        exit 0 ;;
    *Apagar*)
        nmcli radio wifi off && notify "WiFi apagado"
        exit 0 ;;
    *Reescanear*)
        notify "Reescaneando…"
        exec "$0" ;;
    *Editor*)
        nm-connection-editor &
        exit 0 ;;
    *─*) exit 0 ;;
    "") exit 0 ;;
esac

# Extraer SSID (todo lo que sigue a "XX%  ")
ssid=$(sed -E 's/^.*[0-9]+%\s+//' <<<"$selection")
[[ -z "$ssid" ]] && exit 0

# Si ya existe un perfil guardado → subirlo directo
if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
    if nmcli connection up id "$ssid" >/dev/null 2>&1; then
        notify "Conectado a $ssid"
        exit 0
    fi
fi

# Detectar si requiere contraseña
security=$(nmcli -t -f SSID,SECURITY device wifi list | awk -F: -v s="$ssid" '$1==s{print $2; exit}')

if [[ -n "$security" && "$security" != "--" ]]; then
    pass=$(wofi_password "Contraseña para $ssid") || exit 0
    [[ -z "$pass" ]] && exit 0
    if nmcli device wifi connect "$ssid" password "$pass" 2>&1 | grep -qi error; then
        notify "Error conectando a $ssid" "Contraseña incorrecta o fuera de rango"
        exit 1
    fi
else
    nmcli device wifi connect "$ssid" >/dev/null 2>&1 || { notify "Error conectando a $ssid"; exit 1; }
fi

notify "Conectado a $ssid"
