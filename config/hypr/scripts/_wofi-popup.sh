# shellcheck shell=bash
# Helper source-able: wofi_popup <prompt> [opciones_extra_wofi...]
# Envuelve wofi --dmenu con un watcher que lo cierra cuando Hyprland emite
# eventos claros de "el usuario miró a otro lado": cambio de workspace,
# cambio de monitor, o activación de una ventana concreta (no eventos vacíos
# provocados por que wofi agarre el teclado).

wofi_popup() {
    local prompt=$1; shift
    local out
    out=$(mktemp --tmpdir wofi-popup.XXXX)

    wofi --dmenu \
         --prompt  "$prompt" \
         --width   460 \
         --height  520 \
         --cache-file /dev/null \
         "$@" > "$out" &
    local wofi_pid=$!

    # Watcher en Python; se conecta al socket2 de Hyprland y mata wofi
    # ante eventos genuinos. Un periodo de gracia de 450ms absorbe los
    # eventos iniciales que dispara el compositor cuando la capa aparece.
    setsid python3 - "$wofi_pid" >/dev/null 2>&1 <<'PY' &
import os, sys, socket, signal, time, select

pid = int(sys.argv[1])
try:
    sock_path = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket2.sock"
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(None)
    s.connect(sock_path)
except Exception:
    sys.exit(0)

GRACE = 0.45
start = time.monotonic()
# Eventos que consideramos "intención clara" del usuario de irse a otro lado.
# Ignoramos eventos con payload vacío (ej: activewindow>>, al perder foco
# cuando wofi agarra el teclado).
TRIGGERS = {b'workspace', b'workspacev2',
            b'focusedmon',
            b'activewindow', b'activewindowv2',
            b'openwindow',
            b'movewindow', b'movewindowv2'}

buf = b''
try:
    while True:
        # kill watcher si wofi ya murió por cualquier otra razón.
        try: os.kill(pid, 0)
        except ProcessLookupError: sys.exit(0)

        r,_,_ = select.select([s], [], [], 0.25)
        if not r: continue
        chunk = s.recv(4096)
        if not chunk: break
        buf += chunk
        while b'\n' in buf:
            line, buf = buf.split(b'\n', 1)
            if b'>>' not in line: continue
            name, _, arg = line.partition(b'>>')
            if name not in TRIGGERS: continue
            # Durante el grace period: descartar todo.
            if time.monotonic() - start < GRACE: continue
            # Evento activewindow con payload vacío = wofi agarró teclado.
            if name.startswith(b'activewindow') and arg.strip() == b'': continue
            try: os.kill(pid, signal.SIGTERM)
            except ProcessLookupError: pass
            sys.exit(0)
except Exception:
    pass
PY
    local watcher_pid=$!

    wait "$wofi_pid" 2>/dev/null
    local rc=$?

    kill -TERM -- -"$watcher_pid" 2>/dev/null  # mata todo el process group (setsid)
    kill -TERM "$watcher_pid" 2>/dev/null

    cat "$out"
    rm -f "$out"
    return "$rc"
}
