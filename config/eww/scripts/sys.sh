#!/usr/bin/env bash
# sys.sh — CPU%, RAM%, disco% para el dashboard eww
# Entradas cortas pensadas para `defpoll` (string plano, no JSON).

set -euo pipefail

case "${1:-}" in
    cpu)
        # %cpu (total) calculado con diff /proc/stat en 200ms.
        read -r _ u1 n1 s1 i1 w1 irq1 sirq1 _ < /proc/stat
        t1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1))
        idle1=$((i1 + w1))
        sleep 0.2
        read -r _ u2 n2 s2 i2 w2 irq2 sirq2 _ < /proc/stat
        t2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2))
        idle2=$((i2 + w2))
        dt=$((t2 - t1))
        di=$((idle2 - idle1))
        if (( dt > 0 )); then
            awk -v d="$dt" -v i="$di" 'BEGIN{ printf("%d", 100*(d-i)/d) }'
        else
            echo 0
        fi
        ;;
    mem)
        awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2} END{ if(t>0) printf("%d", 100*(t-a)/t); else print 0 }' /proc/meminfo
        ;;
    memstr)
        awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2} END{ printf("%.1f / %.1f GiB", (t-a)/1048576, t/1048576) }' /proc/meminfo
        ;;
    disk)
        df / --output=pcent | tail -1 | tr -dc '0-9'
        ;;
    *)
        echo "uso: sys.sh {cpu|mem|memstr|disk}" >&2
        exit 1
        ;;
esac
