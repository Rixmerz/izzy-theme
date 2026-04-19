#!/usr/bin/env bash
# net.sh — lista/controla WiFi vía nmcli.  Sub-comandos:
#   status          → JSON {enabled, ssid, signal}
#   list            → JSON [{ssid, signal, secure, active}, ...]
#   toggle          → prende/apaga la radio WiFi
#   connect <SSID>  → conecta (si ya hay perfil) o pide pass con wofi

set -euo pipefail

json_escape() {
    # escapa comillas y backslashes para embeds JSON
    local s="${1//\\/\\\\}"
    printf '%s' "${s//\"/\\\"}"
}

case "${1:-}" in
    status)
        enabled=$(nmcli radio wifi 2>/dev/null || echo "unknown")
        # IN-USE(*), SSID, SIGNAL del AP activo
        line=$(nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list 2>/dev/null | awk -F: '$1=="*"{print; exit}')
        ssid=""
        sig=0
        if [[ -n "$line" ]]; then
            IFS=: read -r _ ssid sig <<<"$line"
        fi
        printf '{"enabled":"%s","ssid":"%s","signal":%d}\n' \
               "$enabled" "$(json_escape "$ssid")" "${sig:-0}"
        ;;

    list)
        # Dedupe por SSID manteniendo la señal más alta y el flag activo si existe.
        # nmcli -t separador `:` requiere escapar `\:` dentro de SSIDs con ":".
        nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null \
            | awk -F: '
                BEGIN { }
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
                    # orden por señal desc
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

    connect)
        ssid="${2:-}"
        if [[ -z "$ssid" ]]; then
            echo "uso: net.sh connect <SSID>" >&2
            exit 1
        fi
        # perfil existente → up directo
        if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$ssid"; then
            nmcli connection up id "$ssid" >/dev/null 2>&1 && exit 0
        fi
        # intento sin pass (abierta)
        if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            exit 0
        fi
        # pedir pass con wofi (falla silencioso si el user cancela)
        pass=$(printf '' | wofi --dmenu --password --prompt "Password $ssid" 2>/dev/null || true)
        [[ -z "$pass" ]] && exit 0
        nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1 \
            && notify-send -a dashboard "WiFi" "Conectado a $ssid" \
            || notify-send -a dashboard "WiFi" "Falló conexión a $ssid"
        ;;

    *)
        echo "uso: net.sh {status|list|toggle|connect <SSID>}" >&2
        exit 1
        ;;
esac
