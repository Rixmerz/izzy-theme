# izzy-theme

Servicio de tema dinámico para **Hyprland** en Arch Linux: tirás una imagen, corre
un solo comando, y toda la interfaz (barra, notificaciones, bordes, lockscreen,
wallpaper) adopta una paleta extraída automáticamente de esa imagen.

Pensado originalmente para una HP OMEN 15 con NVIDIA, pero portable a cualquier
Arch con Hyprland.

---

## ¿Qué hace?

- Extrae paleta **Material You** de cualquier imagen con [matugen](https://github.com/InioX/matugen) (scheme `content` — usa múltiples tonos de la imagen para acentos, sombras y highlights).
- Regenera en caliente:
  - **Waybar** (CSS vars con `@define-color`)
  - **Mako** (notificaciones)
  - **Hyprland** (bordes de ventana, blur/vibrancy)
  - **Hyprlock** (lockscreen)
  - **oh-my-posh** — prompt de shell tema `atomic` con segmentos shell/path/git/exec/time derivados de la paleta (brand colors de lenguajes se preservan)
- Copia la imagen a `~/Pictures/Wallpapers/` y la aplica vía `hyprctl hyprpaper wallpaper`.
- Mantiene estado centralizado en `~/.config/theme/current.toml` + symlink `current-wallpaper`.

Todo idempotente: podés re-correrlo sobre la misma imagen sin duplicar nada.

---

## Requisitos

Paquetes (Arch, repos oficiales):

```sh
sudo pacman -S --needed \
    hyprland hyprpaper hyprlock hypridle \
    waybar mako matugen \
    brightnessctl playerctl grim slurp wl-clipboard cliphist \
    wofi kitty thunar \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk \
    papirus-icon-theme
```

---

## Instalación

```sh
git clone https://github.com/Rixmerz/izzy-theme.git
cd izzy-theme
./install.sh
```

El instalador:
- hace backup de tus configs previos (si existen) a `~/.config/izzy-theme-backup-<fecha>/`
- symlinkea los archivos del repo a `~/.config/{hypr,waybar,matugen}` y `~/.local/bin/theme`
- siembra los outputs iniciales con la paleta stub de Catppuccin Mocha

Agregá a mano a tu `~/.config/kitty/kitty.conf`:

```
background_opacity 0.85
```

Reiniciá Hyprland (`Super+Shift+M`) y aplicá tu primer tema:

```sh
theme ~/Pictures/Wallpapers/algo.jpg
```

---

## Uso

```sh
theme <ruta-imagen>
```

La imagen se copia a `~/Pictures/Wallpapers/`, matugen regenera las paletas, se
recargan Waybar + Mako + Hyprland, y se aplica la imagen como wallpaper.

Variables de entorno para override:

| Variable | Default | Posibles valores |
|---|---|---|
| `THEME_SCHEME` | `scheme-content` | `scheme-content`, `scheme-vibrant`, `scheme-expressive`, `scheme-fidelity`, `scheme-tonal-spot`, `scheme-neutral`, `scheme-monochrome`, `scheme-fruit-salad`, `scheme-rainbow` |
| `THEME_PREFER` | `saturation` | `saturation`, `darkness`, `lightness`, `less-saturation`, `value`, `closest-to-fallback` |

Ejemplo:

```sh
THEME_SCHEME=scheme-vibrant theme ~/Downloads/foo.jpg
```

Re-aplicar el tema actual (útil si editaste los templates):

```sh
theme "$(readlink ~/.config/theme/current-wallpaper)"
```

---

## Arquitectura

```
~/Downloads/foo.png
        │
        ▼                     ~/Pictures/Wallpapers/foo.png   ────►  hyprpaper
   bin/theme ──► matugen ──┬► ~/.config/theme/outputs/waybar-colors.css   ──►  waybar
                           ├► ~/.config/theme/outputs/hyprland-colors.conf ──► hyprland
                           ├► ~/.config/theme/outputs/hyprlock-colors.conf ──► hyprlock
                           └► ~/.config/mako/config                         ──► mako

                           ~/.config/theme/current.toml   ◄── estado activo
                           ~/.config/theme/current-wallpaper (symlink)
```

Los archivos en `~/.config/theme/outputs/` son la **única fuente de verdad** de
colores. Cada app los lee via `source =` (hyprland/hyprlock), `@import`
(waybar) o overwrite directo (mako).

---

## Keybinds principales

| Combo | Acción |
|---|---|
| `Super+Return` | kitty |
| `Super+E` | Thunar |
| `Super+B` | Firefox |
| `Super+R` | wofi launcher |
| `Super+Shift+Q` | cerrar ventana |
| `Super+F` / `Super+Shift+F` | fullscreen / real |
| `Super+V` | flotar / tile |
| `Super+Shift+L` | hyprlock |
| `Super+Shift+M` | salir de Hyprland |
| `Super + h j k l` / flechas | foco |
| `Super+Shift + h j k l` / flechas | mover ventana |
| `Super+Ctrl + flechas` | redimensionar |
| `Super + 1..9` | ir al workspace N |
| `Super+Shift + 1..9` | mover ventana al workspace N |
| `Print` / `Shift+Print` / `Super+Print` / `Super+Shift+Print` | captura |
| `Super+;` | cliphist (historial portapapeles) |

---

## Desinstalar

```sh
./uninstall.sh
```

Remueve solo los symlinks creados. Los backups en `~/.config/izzy-theme-backup-*`
y los contenidos de `~/.config/theme/` se conservan.

---

## Licencia

MIT. Ver [LICENSE](LICENSE).
