#!/usr/bin/env bash
# TACH visualizer para waybar (estilo bar-graph 300ZX).
# cava → salida raw ascii → mapeo a bloques ▁▂▃▄▅▆▇█ → stdout streaming.
# waybar lee cada línea como texto del módulo custom/cava.

BARS=12
CFG="$(mktemp --suffix=-waybar-cava)"
trap 'rm -f "$CFG"' EXIT

cat > "$CFG" <<EOF
[general]
bars = $BARS
framerate = 30
autosens = 1

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
bar_delimiter = 59
EOF

# 0..7 → bloques (0 = línea base ▁, idle se ve como ▁▁▁▁)
blocks=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

cava -p "$CFG" 2>/dev/null | while IFS=';' read -ra bars; do
    out=""
    for v in "${bars[@]}"; do
        [[ -z $v ]] && continue
        out+="${blocks[$v]}"
    done
    printf '%s\n' "$out"
done
