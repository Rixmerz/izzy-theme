#!/usr/bin/env bash
# install.sh — izzy-theme
# Linkea los configs del repo a ~/.config y siembra los outputs iniciales.
# Es idempotente: se puede re-correr sin duplicar nada. No requiere root.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.config/izzy-theme-backup-$(date +%Y%m%d-%H%M%S)"

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mkdir -p "$BACKUP"
        mv "$dst" "$BACKUP/"
        echo "  backup:  $dst -> $BACKUP/"
    fi
    ln -sfn "$src" "$dst"
    echo "  link:    $dst -> $src"
}

echo "==> Linkeando configs"
link "$REPO/config/hypr/hyprland.conf"  "$HOME/.config/hypr/hyprland.conf"
link "$REPO/config/hypr/hyprlock.conf"  "$HOME/.config/hypr/hyprlock.conf"
link "$REPO/config/hypr/hypridle.conf"  "$HOME/.config/hypr/hypridle.conf"
link "$REPO/config/hypr/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"
link "$REPO/config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link "$REPO/config/waybar/style.css"    "$HOME/.config/waybar/style.css"
link "$REPO/config/matugen/config.toml" "$HOME/.config/matugen/config.toml"
link "$REPO/config/matugen/templates"   "$HOME/.config/matugen/templates"

echo "==> Instalando bin/theme en ~/.local/bin"
link "$REPO/bin/theme" "$HOME/.local/bin/theme"

echo "==> Creando ~/.config/theme y ~/Pictures/Wallpapers"
mkdir -p "$HOME/.config/theme/outputs" "$HOME/Pictures/Wallpapers"

echo "==> Sembrando stubs en ~/.config/theme/outputs (solo si están vacíos)"
for f in waybar-colors.css hyprland-colors.conf hyprlock-colors.conf; do
    dst="$HOME/.config/theme/outputs/$f"
    [[ -e "$dst" ]] || cp "$REPO/defaults/outputs/$f" "$dst"
    echo "  seed:    $dst"
done

echo "==> Creando symlink waybar-colors.css dentro de ~/.config/waybar"
ln -sfn "$HOME/.config/theme/outputs/waybar-colors.css" "$HOME/.config/waybar/waybar-colors.css"

echo "==> Symlink inicial del wallpaper default"
if [[ ! -e "$HOME/.config/theme/current-wallpaper" ]]; then
    if [[ -f /usr/share/hypr/wall0.png ]]; then
        ln -sfn /usr/share/hypr/wall0.png "$HOME/.config/theme/current-wallpaper"
    fi
fi

if [[ -d "$BACKUP" ]]; then
    echo
    echo "⚠  Respaldé archivos previos en: $BACKUP"
fi

cat <<'EOF'

✓ izzy-theme instalado.

Siguientes pasos:

  1) Instalá los paquetes requeridos (una sola vez):
       sudo pacman -S --needed matugen hyprland hyprpaper hyprlock hypridle \
           waybar mako brightnessctl playerctl grim slurp wl-clipboard \
           cliphist wofi kitty thunar ttf-jetbrains-mono-nerd noto-fonts \
           noto-fonts-emoji noto-fonts-cjk papirus-icon-theme

  2) Agregá a tu ~/.config/kitty/kitty.conf (para acrílico):
       background_opacity 0.85

  3) Iniciá/Reiniciá Hyprland (Super+Shift+M) y aplicá un tema:
       theme ~/Pictures/Wallpapers/<imagen>

EOF
