#!/usr/bin/env bash
# battery.sh — lectura directa de /sys/class/power_supply/BAT0.
#   pct      → 0-100
#   state    → "charging" | "discharging" | "full" | "unknown"
#   json     → {"pct":N,"state":"..."} (una sola lectura atómica)

set -eu

bat_dir="/sys/class/power_supply/BAT0"
[[ -d "$bat_dir" ]] || bat_dir="/sys/class/power_supply/BAT1"

read_pct() {
    [[ -d "$bat_dir" ]] || { echo 0; return; }
    cat "$bat_dir/capacity" 2>/dev/null || echo 0
}

read_state() {
    [[ -d "$bat_dir" ]] || { echo "unknown"; return; }
    # estados posibles: Charging, Discharging, Full, Not charging, Unknown
    raw=$(cat "$bat_dir/status" 2>/dev/null || echo "Unknown")
    case "$raw" in
        Charging)        echo "charging" ;;
        Discharging)     echo "discharging" ;;
        Full|"Not charging") echo "full" ;;
        *)               echo "unknown" ;;
    esac
}

case "${1:-}" in
    pct)   read_pct ;;
    state) read_state ;;
    json)
        printf '{"pct":%s,"state":"%s"}\n' "$(read_pct)" "$(read_state)"
        ;;
    *)
        echo "uso: battery.sh {pct|state|json}" >&2
        exit 1
        ;;
esac
