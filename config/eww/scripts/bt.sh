#!/usr/bin/env bash
# bt.sh — Bluetooth vía bluetoothctl para el dashboard eww.
#   power                 → on|off
#   list                  → JSON [{name, mac, paired, connected}, ...]
#   toggle                → power on/off + rfkill unblock
#   connect <MAC>
#   disconnect <MAC>

set -euo pipefail

json_escape() {
    local s="${1//\\/\\\\}"
    printf '%s' "${s//\"/\\\"}"
}

case "${1:-}" in
    power)
        if command -v bluetoothctl >/dev/null 2>&1; then
            st=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print tolower($2); exit}')
            [[ "$st" == "yes" ]] && echo "on" || echo "off"
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
        # `bluetoothctl devices` lista paired+discovered
        while IFS= read -r line; do
            # format: "Device <MAC> <NAME ...>"
            [[ "$line" =~ ^Device[[:space:]]+([0-9A-Fa-f:]+)[[:space:]]+(.*)$ ]] || continue
            mac="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            info=$(bluetoothctl info "$mac" 2>/dev/null || true)
            paired=$(awk '/Paired:/{print tolower($2); exit}' <<<"$info")
            connected=$(awk '/Connected:/{print tolower($2); exit}' <<<"$info")
            [[ "$paired"    == "yes" ]] || paired="no"
            [[ "$connected" == "yes" ]] || connected="no"
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
        if [[ "$st" == "yes" ]]; then
            bluetoothctl power off >/dev/null
        else
            rfkill unblock bluetooth 2>/dev/null || true
            bluetoothctl power on >/dev/null
        fi
        ;;

    connect)
        mac="${2:-}"
        [[ -z "$mac" ]] && { echo "uso: bt.sh connect <MAC>" >&2; exit 1; }
        bluetoothctl connect "$mac" >/dev/null 2>&1 \
            && notify-send -a dashboard "Bluetooth" "Conectado: $mac" \
            || notify-send -a dashboard "Bluetooth" "Falló conexión: $mac"
        ;;

    disconnect)
        mac="${2:-}"
        [[ -z "$mac" ]] && { echo "uso: bt.sh disconnect <MAC>" >&2; exit 1; }
        bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
        ;;

    *)
        echo "uso: bt.sh {power|list|toggle|connect <MAC>|disconnect <MAC>}" >&2
        exit 1
        ;;
esac
