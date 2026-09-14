# desktop-box

    base/Dockerfile    -> sandboxai/base       FROM ubuntu:24.04
      node             : nodejs.org tarball -> /usr/local   (gemini-cli needs >=20; ubuntu apt ships 18)
      claude           : claude.ai/install.sh,          HOME=/opt/toolchain, symlink /usr/local/bin
      antigravity      : antigravity.google/cli/install.sh, same
      gemini           : npm i -g @google/gemini-cli   (npm-only, no binary release)
      user             : agent uid 1000, HOME=/home/agent

    desktop/Dockerfile -> sandboxai/desktop    FROM sandboxai/base
      apt              : xvfb x11vnc novnc websockify openbox + electron libs
      claude-desktop   : apt downloads.claude.ai/claude-desktop/apt/stable
      antigravity gui  : ARG ANTIGRAVITY_URL -> /opt/antigravity
    desktop/session.sh : Xvfb :0 | openbox | x11vnc -rfbauth | websockify 6080

    sandboxai
      DESKTOP_VOL=sandboxai_desktop            seed source only, :ro at /seed — NEVER mounted in $HOME
      DESKTOP_CREDS=(...)                      host-fixed allowlist: Cookies, Local Storage,
                                               state.vscdb, installation_id. No *config.json, no settings.json
      ensure_desktop_auth()                    seed once from host ~/.config/{Claude,Antigravity}, ~/.gemini/antigravity
      harvest_desktop_creds(<container>)       docker cp allowlist out of the EXITED box into DESKTOP_VOL
      desktop [PATH]                           no exec/--rm: docker run --name, wait, harvest, rm; prints URL + VNC password
      teardown()                               also removes DESKTOP_VOL

Guarantee held: box $HOME stays ephemeral. Only non-executable credential blobs persist,
chosen host-side, so a compromised box plants nothing that runs next launch.
