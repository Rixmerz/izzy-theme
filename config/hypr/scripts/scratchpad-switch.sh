#!/usr/bin/env bash
# Toggle un special workspace serializando animaciones.
# Si otro special está visible, lo oculta primero y espera a que termine
# su fadeOut antes de mostrar el target. Evita el lag del crossfade.

TARGET="${1:?usage: $0 <special-name>}"

current=$(hyprctl monitors -j | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    if m.get("focused"):
        print(m.get("specialWorkspace", {}).get("name", ""))
        break
')

if [[ "$current" == "special:$TARGET" ]]; then
    hyprctl dispatch togglespecialworkspace "$TARGET" >/dev/null
elif [[ -n "$current" && "$current" != "special:" ]]; then
    other="${current#special:}"
    hyprctl dispatch togglespecialworkspace "$other" >/dev/null
    sleep 0.1
    hyprctl dispatch togglespecialworkspace "$TARGET" >/dev/null
else
    hyprctl dispatch togglespecialworkspace "$TARGET" >/dev/null
fi
