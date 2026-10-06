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
    desktop/session.sh : Xvfb :0 | openbox | x11vnc -rfbauth | websockify 6080; apps open /work (claude via claude://code/new?folder=)

    sandboxai
      DESKTOP_VOL=sandboxai_desktop            seed source only, :ro at /seed — NEVER mounted in $HOME
      DESKTOP_CREDS=(...)                      host-fixed allowlist the harvest copies out: Claude/Antigravity Cookies +
                                               Local Storage, installation_id, box keyring. No *config.json, no settings.json
      CLAUDE_LOGIN                             follows the host EVERY launch, replaced wholesale, only with its key
      SEEDED_ONCE_CREDS                        Antigravity etc.: seeded once, then the box's own logins win
      BOX_KEYRING                              harvested, NEVER seeded from the host
      stage_claude_safe_storage()              host keyring item application=Claude (chromium schema; its label is just "Chromium Safe Storage") -> .sandboxai-claude-safe-storage
      desktop/safe-storage.sh                  box side: secret-tool store the item so host cookies decrypt
      harvest_desktop_creds(<container>)       docker cp allowlist out of the EXITED box into DESKTOP_VOL
      desktop [PATH]                           no exec/--rm: docker run --name, wait, harvest, rm; prints URL + VNC password
      teardown()                               also removes DESKTOP_VOL

Guarantee held: box $HOME stays ephemeral. Only non-executable credential blobs persist,
chosen host-side, so a compromised box plants nothing that runs next launch.
