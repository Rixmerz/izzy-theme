#!/usr/bin/env bash
# bt.sh — Bluetooth via bluetoothctl para el dashboard eww.
#   power                    → "on" | "off"
#   list                     → JSON [{name, mac, paired, connected}, ...]
#   toggle                   → power on/off + rfkill unblock
#   scan                     → scan on por 8s (background), refresca la lista
#   connect    <MAC>
#   disconnect <MAC>
#   pair       <MAC>         → pair + trust + connect
#   trust      <MAC>
#   untrust    <MAC>
#   remove     <MAC>         → unpair
#   menu       <MAC>         → popup wofi con acciones según estado

set -eu
# sin `pipefail`: `bluetoothctl | awk` puede fallar transient.

json_escape() {
    local s="${1//\\/\\\\}"
    printf '%s' "${s//\"/\\\"}"
}

# Helper: query Paired/Connected de un MAC
bt_info() {
    bluetoothctl info "$1" 2>/dev/null
}

bt_get_field() {
    # $1 = field name (Paired, Connected, Trusted); $2 = info blob
    awk -v k="$1:" '$1==k{print tolower($2); exit}' <<<"$2"
}

case "${1:-}" in
    power)
        if command -v bluetoothctl >/dev/null 2>&1; then
            st=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print tolower($2); exit}')
            [[ "${st:-}" == "yes" ]] && echo "on" || echo "off"
        else
            echo "off"
        fi
        ;;

    list)
        if ! command -v bluetoothctl >/dev/null 2>&1; then
            echo "[]"
            exit 0
        fi
        echo -n "["
        first=1
        while IFS= read -r line; do
            [[ "$line" =~ ^Device[[:space:]]+([0-9A-Fa-f:]+)[[:space:]]+(.*)$ ]] || continue
            mac="${BASH_REMATCH[1]}"
            raw_name="${BASH_REMATCH[2]}"
            info=$(bt_info "$mac")
            paired=$(bt_get_field Paired "$info")
            connected=$(bt_get_field Connected "$info")
            [[ "${paired:-}"    == "yes" ]] || paired="no"
            [[ "${connected:-}" == "yes" ]] || connected="no"
            # Preferir Alias > Name > raw_name de `devices`.  Si todo falla y
            # el "nombre" es solo una MAC, marcar como (sin nombre).
            alias_name=$(awk -F': ' '/^\tAlias: /{print $2; exit}' <<<"$info")
            name_field=$(awk -F': ' '/^\tName: / {print $2; exit}' <<<"$info")
            name="${alias_name:-${name_field:-$raw_name}}"
            # Si el "nombre" es una MAC o formato AA-BB-CC-DD-EE-FF, truncar
            if [[ "$name" =~ ^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$ ]]; then
                name="(sin nombre · ${mac: -5})"
            fi
            name_e=$(json_escape "$name")
            [[ $first -eq 0 ]] && echo -n ","
            printf '{"name":"%s","mac":"%s","paired":"%s","connected":"%s"}' \
                   "$name_e" "$mac" "$paired" "$connected"
            first=0
        done < <(bluetoothctl devices 2>/dev/null)
        echo "]"
        ;;

    toggle)
        st=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}' || echo "no")
        if [[ "${st:-}" == "yes" ]]; then
            bluetoothctl power off >/dev/null
        else
            rfkill unblock bluetooth 2>/dev/null || true
            bluetoothctl power on >/dev/null
        fi
        ;;

    scan)
        # scan transient en background; 8s es suficiente para BLE típico.
        ( bluetoothctl --timeout 8 scan on >/dev/null 2>&1 ) &
        notify-send -a dashboard "Bluetooth" "Buscando dispositivos (8s)…"
        ;;

    connect)
        mac="${2:-}"
        [[ -z "$mac" ]] && { echo "uso: bt.sh connect <MAC>" >&2; exit 1; }
        bluetoothctl connect "$mac" >/dev/null 2>&1 \
            && notify-send -a dashboard "Bluetooth" "Conectado" \
            || notify-send -a dashboard "Bluetooth" "Falló conexión"
        ;;

    disconnect)
        mac="${2:-}"
        [[ -z "$mac" ]] && { echo "uso: bt.sh disconnect <MAC>" >&2; exit 1; }
        bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
        notify-send -a dashboard "Bluetooth" "Desconectado"
        ;;

    pair)
        mac="${2:-}"
        [[ -z "$mac" ]] && { echo "uso: bt.sh pair <MAC>" >&2; exit 1; }
        bluetoothctl pair    "$mac" >/dev/null 2>&1 || true
        bluetoothctl trust   "$mac" >/dev/null 2>&1 || true
        bluetoothctl connect "$mac" >/dev/null 2>&1 \
            && notify-send -a dashboard "Bluetooth" "Emparejado y conectado" \
            || notify-send -a dashboard "Bluetooth" "Falló emparejar"
        ;;

    trust)
        mac="${2:-}"
        bluetoothctl trust "$mac" >/dev/null 2>&1 \
            && notify-send -a dashboard "Bluetooth" "Confiado" \
            || notify-send -a dashboard "Bluetooth" "Falló"
        ;;

    untrust)
        mac="${2:-}"
        bluetoothctl untrust "$mac" >/dev/null 2>&1 \
            && notify-send -a dashboard "Bluetooth" "Ya no es de confianza"
        ;;

    remove)
        mac="${2:-}"
        bluetoothctl remove "$mac" >/dev/null 2>&1 \
            && notify-send -a dashboard "Bluetooth" "Dispositivo removido" \
            || notify-send -a dashboard "Bluetooth" "Falló remover"
        ;;

    menu)
        mac="${2:-}"
        [[ -z "$mac" ]] && { echo "uso: bt.sh menu <MAC>" >&2; exit 1; }
        info=$(bt_info "$mac")
        paired=$(bt_get_field Paired "$info")
        connected=$(bt_get_field Connected "$info")
        trusted=$(bt_get_field Trusted "$info")

        opts=""
        if [[ "$connected" == "yes" ]]; then
            opts="󰂲  Desconectar"$'\n'
        elif [[ "$paired" == "yes" ]]; then
            opts="󰂯  Conectar"$'\n'
        else
            opts="󰂰  Emparejar"$'\n'
        fi
        if [[ "$trusted" == "yes" ]]; then
            opts+="󰗖  Dejar de confiar"$'\n'
        else
            opts+="󰂢  Confiar"$'\n'
        fi
        opts+="󰂲  Remover"

        choice=$(printf '%s' "$opts" | wofi --dmenu --prompt "${mac}" 2>/dev/null || true)
        case "$choice" in
            *Emparejar*)       "$0" pair       "$mac" ;;
            *Conectar*)        "$0" connect    "$mac" ;;
            *Desconectar*)     "$0" disconnect "$mac" ;;
            *confiar*|*Dejar*) "$0" untrust    "$mac" ;;
            *Confiar*)         "$0" trust      "$mac" ;;
            *Remover*)         "$0" remove     "$mac" ;;
        esac
        ;;

    *)
        echo "uso: bt.sh {power|list|toggle|scan|connect|disconnect|pair|trust|untrust|remove|menu} [MAC]" >&2
        exit 1
        ;;
esac
