#!/usr/bin/env bash
# brightness.sh — porcentaje de backlight via brightnessctl.
#   pct       → 0-100 actual
#   set <n>   → setea a n% (0-100)

set -eu

case "${1:-}" in
    pct)
        if command -v brightnessctl >/dev/null 2>&1; then
            cur=$(brightnessctl get 2>/dev/null || echo 0)
            max=$(brightnessctl max 2>/dev/null || echo 1)
            if (( max > 0 )); then
                echo $(( 100 * cur / max ))
            else
                echo 0
            fi
        else
            echo 0
        fi
        ;;
    set)
        n="${2:-}"
        [[ -z "$n" ]] && { echo "uso: brightness.sh set <0-100>" >&2; exit 1; }
        # clamp 5-100 para evitar apagar la pantalla por accidente
        (( n < 5   )) && n=5
        (( n > 100 )) && n=100
        brightnessctl set "${n}%" >/dev/null 2>&1 || true
        ;;
    *)
        echo "uso: brightness.sh {pct|set <0-100>}" >&2
        exit 1
        ;;
esac
