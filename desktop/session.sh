#!/bin/sh
# The desktop session: an X server nobody else can see, a window manager, the apps you asked for, and
# noVNC on 6080. Started as the box's command by `sandboxai desktop` — see run_box in ../sandboxai.
set -eu

export DISPLAY=:0
Xvfb :0 -screen 0 "${SANDBOXAI_GEOMETRY:-1600x900x24}" -nolisten tcp &
while [ ! -e /tmp/.X11-unix/X0 ]; do sleep 0.1; done

openbox &
# A taskbar, because both apps open maximised: with no panel and no reachable root menu, the second window
# is simply unreachable over VNC (the browser eats Alt-Tab before openbox sees it).
tint2 >/dev/null 2>&1 &

# VNC is password-gated because the box's LAN IP is reachable by every user on the host (docker publishes
# nothing here — an --internal network drops published ports, but the host routes to the container directly).
x11vnc -storepasswd "$SANDBOXAI_VNC_PASSWORD" "$HOME/.vncpass" >/dev/null 2>&1
x11vnc -display :0 -rfbauth "$HOME/.vncpass" -localhost -forever -shared -quiet -bg >/dev/null

# xdg-open has no desktop environment to ask, so it falls back to $BROWSER — that is how the OAuth redirect
# finds its way out of these apps.
export BROWSER=sandboxai-browser

# Without a keyring Electron's safeStorage reports isEncryptionAvailable=false and Claude Desktop DISCARDS
# the session on exit — you re-login every single run, however faithfully the cookies are harvested. So the
# box runs its own keyring, unlocked with a password the launcher generated once and keeps beside the
# harvested credentials. That password is no more secret than the credentials it protects; the point is
# giving Electron a working backend, not hiding anything from the host.
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
mkdir -p "$HOME/.local/share/keyrings"
eval "$(printf '%s' "$(cat "$HOME/.sandboxai-keyring-pass")" | gnome-keyring-daemon --unlock --components=secrets)"
export GNOME_KEYRING_CONTROL

# --proxy-server is load-bearing, not belt-and-braces: chromium IGNORES HTTP_PROXY, so without it both apps
# come up as a blank white window with no network and the login hangs on "Awaiting Authentication".
# --no-sandbox: chrome's own sandbox needs SUID/user namespaces, and the box runs with every capability
# dropped. Nothing is lost — gVisor plus this box IS the sandbox. --password-store=basic keeps Electron from
# blocking on a gnome-keyring that isn't here; --disable-gpu because there is no device to render on.
electron_flags="--no-sandbox --disable-gpu --password-store=gnome-libsecret --proxy-server=$HTTPS_PROXY"

for app in ${SANDBOXAI_DESKTOP_APPS:-claude antigravity}; do
  case "$app" in
    claude)      claude-desktop $electron_flags >/dev/null 2>&1 & ;;
    antigravity) antigravity $electron_flags /work >/dev/null 2>&1 & ;;
    *)           echo "sandboxai-desktop: unknown app '$app'" >&2; exit 2 ;;
  esac
done

exec websockify --web=/usr/share/novnc 6080 localhost:5900
