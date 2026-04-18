#!/usr/bin/env bash
# Toggle scratchpad de YouTube Music.
# Primera ejecución: lanza la app (la windowrule la envía a special:ytmusic).
# Siguientes: togglea visibilidad del workspace especial.

APP_BIN="youtube-music-desktop-app"
APP_CLASS="YouTube Music Desktop App"
WORKSPACE="ytmusic"

# Check by window class (más robusto que pgrep con binarios de nombre largo)
if hyprctl clients -j | grep -q "\"class\": \"$APP_CLASS\""; then
    hyprctl dispatch togglespecialworkspace "$WORKSPACE" >/dev/null
else
    setsid "$APP_BIN" >/dev/null 2>&1 < /dev/null &
    disown
fi
