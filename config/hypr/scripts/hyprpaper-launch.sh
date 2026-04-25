#!/usr/bin/env bash
# Espera a que Hyprland tenga al menos un monitor antes de levantar hyprpaper.
# Workaround race: con exec-once temprano, hyprpaper parsea el conf antes de
# que aquamarine termine modesetting de eDP-1 → wallpaper se aplica a lista
# vacía de outputs → no se bindea nunca aunque el monitor aparezca después.
# Síntoma: pantalla negra/clear-color tras reboot, hyprpaper corriendo OK.
for _ in $(seq 1 100); do
    if hyprctl monitors 2>/dev/null | grep -q '^Monitor '; then
        break
    fi
    sleep 0.05
done
exec hyprpaper
