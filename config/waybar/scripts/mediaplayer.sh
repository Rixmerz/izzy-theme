#!/usr/bin/env bash
# Waybar media module — launcher de YouTube Music + now-playing (MPRIS).
# Sigue a playerctl en tiempo real y emite JSON por cada cambio.

FMT='{"alt":"{{status}}","text":"{{markup_escape(title)}}","tooltip":"<span size=\"xx-large\" weight=\"bold\" line_height=\"1.3\">{{markup_escape(title)}}</span>\n<span size=\"medium\" alpha=\"85%\">{{markup_escape(artist)}}</span>\n\n<span alpha=\"48%\" size=\"small\" letter_spacing=\"800\">{{duration(position)}}  ·  {{duration(mpris:length)}}</span>","class":"{{lc(status)}}"}'

IDLE='{"text":"YouTube Music","tooltip":"<span size=\"x-large\" weight=\"bold\">YouTube Music</span>\n<span alpha=\"55%\" size=\"small\">Nada sonando</span>","class":"idle","alt":"Stopped"}'

printf '%s\n' "$IDLE"

playerctl --follow metadata --format "$FMT" 2>/dev/null | while IFS= read -r line; do
    if [[ -z "$line" ]] || [[ "$line" == *'"text":""'* ]]; then
        printf '%s\n' "$IDLE"
    else
        printf '%s\n' "$line"
    fi
done
