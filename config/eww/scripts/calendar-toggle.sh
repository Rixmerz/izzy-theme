#!/usr/bin/env bash
# Toggle del popup de calendario eww (click en reloj waybar).
# Reusa el daemon eww del dashboard; lo arranca si no responde.
set -u

timeout 1 eww ping >/dev/null 2>&1 || {
    systemctl --user reset-failed eww-daemon.service 2>/dev/null
    systemctl --user restart eww-daemon.service 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8; do
        sleep 0.15
        timeout 1 eww ping >/dev/null 2>&1 && break
    done
}

if eww active-windows 2>/dev/null | grep -q '^calendar'; then
    eww close calendar >/dev/null 2>&1
else
    eww open calendar >/dev/null 2>&1
fi
