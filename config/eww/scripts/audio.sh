#!/usr/bin/env bash
# audio.sh — volumen + sink vía wpctl (pipewire + wireplumber).
#   vol   → 0-100 (entero)
#   mute  → "true" | "false"
#   sink  → descripción del sink default

set -euo pipefail

case "${1:-}" in
    vol)
        if command -v wpctl >/dev/null 2>&1; then
            wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
                | awk '{ printf("%d", $2 * 100) }' \
                || echo 0
        else
            echo 0
        fi
        ;;
    mute)
        if command -v wpctl >/dev/null 2>&1; then
            out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
            if [[ "$out" == *MUTED* ]]; then echo "true"; else echo "false"; fi
        else
            echo "false"
        fi
        ;;
    sink)
        if command -v wpctl >/dev/null 2>&1; then
            wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null \
                | awk -F'"' '/node\.description/{ print $2; exit }' \
                || echo "—"
        else
            echo "—"
        fi
        ;;
    *)
        echo "uso: audio.sh {vol|mute|sink}" >&2
        exit 1
        ;;
esac
