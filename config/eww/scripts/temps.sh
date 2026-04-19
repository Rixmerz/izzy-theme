#!/usr/bin/env bash
# temps.sh — temperaturas CPU / GPU en °C (entero).
# Adaptado a Ryzen (k10temp) + NVIDIA dGPU con AMD iGPU como fallback.

set -eu

case "${1:-}" in
    cpu)
        # k10temp → Tctl en Ryzen.  Si sensors no está, devolver 0.
        if command -v sensors >/dev/null 2>&1; then
            sensors k10temp-pci-00c3 2>/dev/null \
                | awk '/Tctl:/{gsub(/[+°C]/,"",$2); printf("%d",$2); exit}' \
                || echo 0
        else
            echo 0
        fi
        ;;
    gpu)
        # Preferir NVIDIA (dGPU activa).  Fallback a amdgpu (iGPU).
        if command -v nvidia-smi >/dev/null 2>&1; then
            out=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || true)
            out="${out//[$' \t\n']/}"
            if [[ -n "$out" && "$out" =~ ^[0-9]+$ ]]; then
                echo "$out"
                exit 0
            fi
        fi
        if command -v sensors >/dev/null 2>&1; then
            sensors amdgpu-pci-0600 2>/dev/null \
                | awk '/edge:/{gsub(/[+°C]/,"",$2); printf("%d",$2); exit}' \
                || echo 0
        else
            echo 0
        fi
        ;;
    *)
        echo "uso: temps.sh {cpu|gpu}" >&2
        exit 1
        ;;
esac
