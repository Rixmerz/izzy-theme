#!/usr/bin/env bash
# Selector Bluetooth con wofi + bluetoothctl.
# - Toggle: re-clickear el ícono en Waybar cierra el menú abierto
# - Lista dispositivos emparejados y los descubiertos en un escaneo corto
# - Conectar / desconectar / confiar / quitar
# - Toggle BT on/off
# - Atajo a blueman-manager para administración avanzada

set -u

source "$(dirname "$0")/_wofi-popup.sh"

notify() { command -v notify-send >/dev/null && notify-send -a "bluetooth-menu" "$@" || true; }

wofi_menu() { wofi_popup "$1"; }

# Toggle-close
LOCK=/run/user/$(id -u)/bluetooth-menu.lock
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
trap 'rm -f "$LOCK"; bluetoothctl --timeout 1 scan off >/dev/null 2>&1 || true' EXIT

bt_powered() { bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}' | head -1 | grep -qi yes; }
bt_rfkill_blocked() { rfkill list bluetooth 2>/dev/null | grep -qi 'blocked: yes'; }

bt_turn_on() {
    if bt_rfkill_blocked; then
        rfkill unblock bluetooth 2>/dev/null
        sleep 0.4
    fi
    systemctl is-active --quiet bluetooth.service || systemctl start bluetooth.service 2>/dev/null || true
    bluetoothctl power on 2>/dev/null
    # Espera hasta 2s a que el controlador reporte Powered: yes
    for _ in 1 2 3 4 5 6 7 8; do
        bt_powered && return 0
        sleep 0.25
    done
    return 1
}

if ! bt_powered; then
    choice=$(printf "󰂯  Encender Bluetooth\n󰂲  Cancelar" | wofi_menu "Bluetooth apagado") || exit 0
    case "$choice" in
        *Encender*)
            if bt_turn_on; then
                notify "Bluetooth encendido"
            else
                notify "No se pudo encender" "Revisá rfkill / bluetooth.service"
                exit 1
            fi
            ;;
        *) exit 0 ;;
    esac
fi

# Scan no-bloqueante por ~3s mientras construimos la lista.
bluetoothctl --timeout 3 scan on >/dev/null 2>&1 &
scan_pid=$!
sleep 0.8

# -------- Construcción de la lista --------
declare -A ICONS=(
    [audio-card]="󰋋" [audio-headphones]="󰋋" [audio-headset]="󰋋"
    [input-keyboard]="󰌌" [input-mouse]="󰍽" [input-gaming]="󰊴"
    [phone]="󰏲" [computer]="󰌢" [unknown]="󰂱"
)

declare -A MAC_BY_LINE  # línea visible -> MAC (para lookup tras seleccionar)
declare -A NAME_BY_MAC  # MAC -> nombre amigable (para prompt del submenú)

device_line() {
    local mac=$1 name=$2
    local info icon_key icon connected paired trusted battery
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    icon_key=$(awk -F': ' '/Icon:/ {print $2; exit}' <<<"$info")
    icon=${ICONS[$icon_key]:-${ICONS[unknown]}}
    connected=$(awk '/Connected:/ {print $2; exit}' <<<"$info")
    paired=$(awk '/Paired:/ {print $2; exit}' <<<"$info")
    trusted=$(awk '/Trusted:/ {print $2; exit}' <<<"$info")
    battery=$(awk -F'[()]' '/Battery Percentage/ {print $2; exit}' <<<"$info")

    local mark="  "
    [[ "$connected" == "yes" ]] && mark="󰄬 "
    [[ "$paired"    == "yes" && "$mark" == "  " ]] && mark="󰌷 "

    local extras=""
    [[ -n "$battery" ]] && extras="   $battery"

    # Línea visible: SIN MAC (el usuario sólo ve nombre + iconos + batería)
    printf "%s %s  %s%s" "$mark" "$icon" "$name" "$extras"
}

mapfile -t devices < <(
    bluetoothctl devices Paired   | awk '{mac=$2; $1=""; $2=""; sub(/^  */,""); print mac "\t" $0}'
    bluetoothctl devices          | awk '{mac=$2; $1=""; $2=""; sub(/^  */,""); print mac "\t" $0}'
)

wait "$scan_pid" 2>/dev/null || true

declare -A SEEN
lines=()
for row in "${devices[@]}"; do
    mac=${row%%$'\t'*}
    name=${row#*$'\t'}
    [[ -z "$mac" || -n "${SEEN[$mac]:-}" ]] && continue
    SEEN[$mac]=1
    # Si no hay nombre, o el "nombre" es el MAC (devices sin friendly name),
    # usamos los últimos 5 chars del MAC como identificador compacto.
    if [[ -z "$name" || "$name" == "$mac" || "$name" == "${mac//:/-}" ]]; then
        name="Dispositivo ${mac: -5}"
    fi
    line=$(device_line "$mac" "$name")
    # Dedupe por si dos entries generan la misma línea visible.
    suffix=""; i=2
    while [[ -n "${MAC_BY_LINE[${line}${suffix}]:-}" ]]; do
        suffix=" ($i)"; ((i++))
    done
    line="${line}${suffix}"
    MAC_BY_LINE["$line"]=$mac
    NAME_BY_MAC["$mac"]=$name
    lines+=("$line")
done

# Ordenar: conectados primero, luego emparejados, luego resto.
IFS=$'\n' lines=($(printf "%s\n" "${lines[@]}" | awk '
    /^󰄬/ {print 0 "\t" $0; next}
    /^󰌷/ {print 1 "\t" $0; next}
           {print 2 "\t" $0}
' | sort -k1,1n | cut -f2-))
unset IFS

header=(
    "󰂲  Apagar Bluetooth"
    "󰑐  Reescanear"
    "󰒓  Blueman (avanzado)"
    "─────────────────────────"
)

selection=$(printf "%s\n" "${header[@]}" "${lines[@]}" | wofi_menu "Bluetooth") || exit 0

case "$selection" in
    *Apagar*)     bluetoothctl power off >/dev/null && notify "Bluetooth apagado"; exit 0 ;;
    *Reescanear*) exec "$0" ;;
    *Blueman*)    blueman-manager & exit 0 ;;
    *─*|"")       exit 0 ;;
esac

mac=${MAC_BY_LINE[$selection]:-}
[[ -z "$mac" ]] && exit 0
name=${NAME_BY_MAC[$mac]:-$mac}

info=$(bluetoothctl info "$mac" 2>/dev/null)
connected=$(awk '/Connected:/ {print $2; exit}' <<<"$info")
paired=$(awk '/Paired:/ {print $2; exit}' <<<"$info")

# -------- Submenú de acciones por dispositivo --------
actions=()
if [[ "$connected" == "yes" ]]; then
    actions+=("󰿟  Desconectar")
else
    actions+=("󰂱  Conectar")
fi
[[ "$paired" == "yes" ]] && actions+=("󰗞  Quitar emparejamiento") || actions+=("󰌷  Emparejar")
actions+=("󰒓  Confiar / dejar de confiar")
actions+=("󰜺  Cancelar")

action=$(printf "%s\n" "${actions[@]}" | wofi_menu "$name") || exit 0

case "$action" in
    *Desconectar*)
        bluetoothctl disconnect "$mac" >/dev/null && notify "Desconectado" || notify "Error al desconectar" ;;
    *Conectar*)
        if bluetoothctl connect "$mac" 2>&1 | grep -qi "successful"; then
            notify "Conectado"
        else
            notify "No se pudo conectar" "Revisá emparejamiento o rango"
        fi ;;
    *Emparejar*)
        bluetoothctl pair "$mac" >/dev/null 2>&1 && bluetoothctl trust "$mac" >/dev/null 2>&1 && notify "Emparejado" || notify "Error al emparejar" ;;
    *Quitar*)
        bluetoothctl remove "$mac" >/dev/null && notify "Emparejamiento eliminado" ;;
    *Confiar*)
        trusted=$(awk '/Trusted:/ {print $2; exit}' <<<"$info")
        if [[ "$trusted" == "yes" ]]; then
            bluetoothctl untrust "$mac" >/dev/null && notify "Ya no se confía en el dispositivo"
        else
            bluetoothctl trust   "$mac" >/dev/null && notify "Dispositivo marcado como confiable"
        fi ;;
esac
