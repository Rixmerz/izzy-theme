#!/usr/bin/env bash
# net.sh — WiFi via nmcli para el dashboard eww.
#   status                 → JSON {enabled, ssid, signal}
#   list                   → JSON [{ssid, signal, secure, active}, ...]
#   toggle                 → prende/apaga radio WiFi
#   rescan                 → fuerza scan
#   connect  <SSID>        → conecta (perfil existente o pide pass con wofi)
#   disconnect             → baja la conexión WiFi activa
#   forget   <SSID>        → borra el perfil guardado
#   details  <SSID>        → notify-send con info
#   menu     <SSID>        → popup wofi con acciones según estado

set -eu

json_escape() {
    local s="${1//\\/\\\\}"
    printf '%s' "${s//\"/\\\"}"
}

# Helper: detecta si hay perfil guardado para un SSID
has_profile() {
    nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$1"
}

# Helper: detecta si un SSID es el activo
is_active() {
    nmcli -t -f IN-USE,SSID dev wifi list 2>/dev/null \
        | awk -F: -v s="$1" '$1=="*" && $2==s { found=1 } END { exit !found }'
}

case "${1:-}" in
    status)
        enabled=$(nmcli radio wifi 2>/dev/null || echo "unknown")
        line=$(nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list 2>/dev/null | awk -F: '$1=="*"{print; exit}')
        ssid=""; sig=0
        if [[ -n "$line" ]]; then
            IFS=: read -r _ ssid sig <<<"$line"
        fi
        printf '{"enabled":"%s","ssid":"%s","signal":%d}\n' \
               "$enabled" "$(json_escape "$ssid")" "${sig:-0}"
        ;;

    list)
        nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
            | awk -F: '
                {
                    active = ($1 == "*") ? "yes" : "no"
                    ssid   = $2
                    sig    = $3 + 0
                    sec    = ($4 == "" || $4 == "--") ? "no" : "yes"
                    if (ssid == "" || ssid == "--") next
                    if (!(ssid in best) || sig > bestSig[ssid]) {
                        best[ssid]    = ssid
                        bestSig[ssid] = sig
                        bestSec[ssid] = sec
                    }
                    if (active == "yes") activeSsid = ssid
                }
                END {
                    n = 0
                    for (k in best) { n++; keys[n] = k }
                    for (i = 1; i <= n; i++) {
                        for (j = i+1; j <= n; j++) {
                            if (bestSig[keys[j]] > bestSig[keys[i]]) {
                                tmp = keys[i]; keys[i] = keys[j]; keys[j] = tmp
                            }
                        }
                    }
                    printf "["
                    for (i = 1; i <= n; i++) {
                        k = keys[i]
                        esc = k
                        gsub(/\\/, "\\\\", esc)
                        gsub(/"/,  "\\\"", esc)
                        isAct = (k == activeSsid) ? "yes" : "no"
                        if (i > 1) printf ","
                        printf "{\"ssid\":\"%s\",\"signal\":%d,\"secure\":\"%s\",\"active\":\"%s\"}",
                               esc, bestSig[k], bestSec[k], isAct
                    }
                    print "]"
                }'
        ;;

    toggle)
        st=$(nmcli radio wifi 2>/dev/null || echo "disabled")
        if [[ "$st" == "enabled" ]]; then
            nmcli radio wifi off
        else
            nmcli radio wifi on
        fi
        ;;

    rescan)
        nmcli device wifi rescan 2>/dev/null || true
        notify-send -a dashboard "WiFi" "Buscando redes…"
        ;;

    disconnect)
        # baja cualquier conexión wifi activa
        dev=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2=="wifi" && $3=="connected"{print $1; exit}')
        if [[ -n "${dev:-}" ]]; then
            nmcli device disconnect "$dev" >/dev/null 2>&1 \
                && notify-send -a dashboard "WiFi" "Desconectado" \
                || notify-send -a dashboard "WiFi" "Falló desconectar"
        fi
        ;;

    connect)
        ssid="${2:-}"
        [[ -z "$ssid" ]] && { echo "uso: net.sh connect <SSID>" >&2; exit 1; }
        if has_profile "$ssid"; then
            nmcli connection up id "$ssid" >/dev/null 2>&1 \
                && notify-send -a dashboard "WiFi" "Conectado a $ssid" \
                || notify-send -a dashboard "WiFi" "Falló conexión a $ssid"
            exit 0
        fi
        # intento sin pass (abierta)
        if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            notify-send -a dashboard "WiFi" "Conectado a $ssid"
            exit 0
        fi
        # pedir pass con wofi
        pass=$(printf '' | wofi --dmenu --password --prompt "Password $ssid" 2>/dev/null || true)
        [[ -z "$pass" ]] && exit 0
        nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1 \
            && notify-send -a dashboard "WiFi" "Conectado a $ssid" \
            || notify-send -a dashboard "WiFi" "Password incorrecta o falló"
        ;;

    forget)
        ssid="${2:-}"
        [[ -z "$ssid" ]] && { echo "uso: net.sh forget <SSID>" >&2; exit 1; }
        nmcli connection delete id "$ssid" >/dev/null 2>&1 \
            && notify-send -a dashboard "WiFi" "Olvidada: $ssid" \
            || notify-send -a dashboard "WiFi" "Sin perfil guardado: $ssid"
        ;;

    details)
        ssid="${2:-}"
        [[ -z "$ssid" ]] && { echo "uso: net.sh details <SSID>" >&2; exit 1; }
        info=$(nmcli -t -f SSID,BSSID,SIGNAL,RATE,SECURITY,CHAN dev wifi list 2>/dev/null \
               | awk -F: -v s="$ssid" '$1==s {print; exit}')
        if [[ -z "$info" ]]; then
            notify-send -a dashboard "WiFi" "Sin info para $ssid"
        else
            # IFS=: read con campos escapados por nmcli — los \: quedan. Mostrar crudo.
            notify-send -a dashboard "WiFi: $ssid" "$info"
        fi
        ;;

    menu)
        ssid="${2:-}"
        [[ -z "$ssid" ]] && { echo "uso: net.sh menu <SSID>" >&2; exit 1; }

        # Construir opciones según estado
        opts=""
        if is_active "$ssid"; then
            opts="󰖪  Desconectar"$'\n'
        else
            opts="󰖩  Conectar"$'\n'
        fi
        if has_profile "$ssid"; then
            opts+="󰚌  Olvidar"$'\n'
        fi
        opts+="󰋽  Detalles"

        choice=$(printf '%s' "$opts" | wofi --dmenu --prompt "$ssid" 2>/dev/null || true)
        case "$choice" in
            *Conectar*)     "$0" connect    "$ssid" ;;
            *Desconectar*)  "$0" disconnect ;;
            *Olvidar*)      "$0" forget     "$ssid" ;;
            *Detalles*)     "$0" details    "$ssid" ;;
        esac
        ;;

    *)
        echo "uso: net.sh {status|list|toggle|rescan|connect|disconnect|forget|details|menu} [SSID]" >&2
        exit 1
        ;;
esac
