#!/bin/sh
# The desktop session: an X server nobody else can see, a window manager, the two GUI apps, and noVNC on
# 6080. Started as the box's command by `sandboxai desktop` — see run_box in ../sandboxai.
set -eu

export DISPLAY=:0
Xvfb :0 -screen 0 "${SANDBOXAI_GEOMETRY:-1600x900x24}" -nolisten tcp &
while [ ! -e /tmp/.X11-unix/X0 ]; do sleep 0.1; done

openbox &

# VNC is password-gated because the box's LAN IP is reachable by every user on the host (docker publishes
# nothing here — an --internal network drops published ports, but the host routes to the container directly).
x11vnc -storepasswd "$SANDBOXAI_VNC_PASSWORD" "$HOME/.vncpass" >/dev/null 2>&1
x11vnc -display :0 -rfbauth "$HOME/.vncpass" -localhost -forever -shared -quiet -bg >/dev/null

# --no-sandbox: chrome's own sandbox needs SUID/user namespaces, and the box runs with every capability
# dropped. Nothing is lost — gVisor plus this box IS the sandbox. --password-store=basic keeps Electron from
# blocking on a gnome-keyring that isn't here; --disable-gpu because there is no device to render on.
electron_flags="--no-sandbox --disable-gpu --password-store=basic"
# shellcheck disable=SC2086
claude-desktop $electron_flags >/dev/null 2>&1 &
# shellcheck disable=SC2086
antigravity $electron_flags /work >/dev/null 2>&1 &

exec websockify --web=/usr/share/novnc 6080 localhost:5900
