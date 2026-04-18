#!/usr/bin/env bash
# uninstall.sh — izzy-theme
# Remueve los symlinks creados por install.sh. No toca ~/.config/theme/ ni wallpapers.

set -euo pipefail

unlink_if_ours() {
    local path="$1"
    if [[ -L "$path" ]]; then
        local target
        target=$(readlink -f "$path")
        case "$target" in
            */izzy-theme/*) rm "$path"; echo "  rm:   $path" ;;
            *)              echo "  skip: $path (no apunta al repo)" ;;
        esac
    fi
}

echo "==> Removiendo symlinks de izzy-theme"
unlink_if_ours "$HOME/.config/hypr/hyprland.conf"
unlink_if_ours "$HOME/.config/hypr/hyprlock.conf"
unlink_if_ours "$HOME/.config/hypr/hypridle.conf"
unlink_if_ours "$HOME/.config/hypr/hyprpaper.conf"
unlink_if_ours "$HOME/.config/waybar/config.jsonc"
unlink_if_ours "$HOME/.config/waybar/style.css"
unlink_if_ours "$HOME/.config/matugen/config.toml"
unlink_if_ours "$HOME/.config/matugen/templates"
unlink_if_ours "$HOME/.local/bin/theme"

echo
echo "✓ Desinstalado. ~/.config/theme y ~/Pictures/Wallpapers se conservan."
echo "  Si tenés respaldos izzy-theme-backup-*, pueden restaurarse manualmente."
