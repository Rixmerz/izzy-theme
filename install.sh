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
link "$REPO/config/waybar/scripts"      "$HOME/.config/waybar/scripts"
link "$REPO/config/hypr/scripts"        "$HOME/.config/hypr/scripts"
link "$REPO/config/wofi/config"         "$HOME/.config/wofi/config"
link "$REPO/config/wofi/style.css"      "$HOME/.config/wofi/style.css"
link "$REPO/config/matugen/config.toml" "$HOME/.config/matugen/config.toml"
link "$REPO/config/matugen/templates"   "$HOME/.config/matugen/templates"
link "$REPO/config/theme/atomic.omp.template.json" "$HOME/.config/theme/atomic.omp.template.json"
link "$REPO/config/gtk-3.0/gtk.css"      "$HOME/.config/gtk-3.0/gtk.css"
link "$REPO/config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
link "$REPO/config/gtk-4.0/gtk.css"      "$HOME/.config/gtk-4.0/gtk.css"
link "$REPO/config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

echo "==> Instalando bin/theme en ~/.local/bin"
link "$REPO/bin/theme"         "$HOME/.local/bin/theme"
link "$REPO/bin/izzy-folders"  "$HOME/.local/bin/izzy-folders"
link "$REPO/bin/izzy-fetch"    "$HOME/.local/bin/izzy-fetch"
link "$REPO/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

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

echo "==> Eww dashboard (SUPER+I)"
link "$REPO/config/eww/eww.yuck" "$HOME/.config/eww/eww.yuck"
link "$REPO/config/eww/eww.scss" "$HOME/.config/eww/eww.scss"
link "$REPO/config/eww/scripts"  "$HOME/.config/eww/scripts"
# eww.scss @importa `_colors` → reusa la paleta matugen de waybar sin duplicar templates.
ln -sfn "$HOME/.config/theme/outputs/waybar-colors.css" \
        "$HOME/.config/eww/_colors.css"

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
           noto-fonts-emoji noto-fonts-cjk papirus-icon-theme lm_sensors \
           bluez-utils networkmanager pipewire wireplumber
       yay -S --needed eww                    # dashboard (layer-shell GTK)
       sudo sensors-detect --auto             # habilita k10temp / amdgpu

  2) Agregá a tu ~/.config/kitty/kitty.conf (para acrílico):
       background_opacity 0.85

  3) Prompt oh-my-posh (opcional, colores derivados del wallpaper):
       yay -S --needed oh-my-posh-bin
       # Agregá a tu ~/.bashrc:
       #   _omp_config="$HOME/.config/theme/outputs/oh-my-posh.json"
       #   if command -v oh-my-posh >/dev/null && [[ -f "$_omp_config" ]]; then
       #       eval "$(oh-my-posh init bash --config "$_omp_config")"
       #       theme() {
       #           command theme "$@" || return $?
       #           [[ -f "$_omp_config" ]] || return 0
       #           PROMPT_COMMAND="${PROMPT_COMMAND//_omp_hook;/}"
       #           PROMPT_COMMAND="${PROMPT_COMMAND//_omp_hook/}"
       #           unset -f _omp_hook 2>/dev/null
       #           oh-my-posh cache clear >/dev/null 2>&1
       #           eval "$(oh-my-posh init bash --config "$_omp_config")"
       #       }
       #   fi
       # (la función `theme` wrapper refresca el prompt de la shell actual
       #  al cambiar tema; sin ella, solo terminales nuevas ven los cambios.)

  4) Iniciá/Reiniciá Hyprland (Super+Shift+M) y aplicá un tema:
       theme ~/Pictures/Wallpapers/<imagen>

EOF
