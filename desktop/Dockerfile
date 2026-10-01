# sandboxai desktop: the GUI apps (Claude Desktop, Antigravity) on a throwaway X server the host reaches
# over noVNC. Layered on sandboxai/base rather than merged into it so a headless `sandboxai claude .` never
# drags ~1GB of desktop around. The RUNTIME boundary is identical to the headless box — non-root, no caps,
# proxy-only egress, ephemeral $HOME (see run_box in ../sandboxai).
FROM sandboxai/base AS statx-shim
USER root
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev \
 && rm -rf /var/lib/apt/lists/*
COPY statx_fill.c /statx_fill.c
RUN gcc -shared -fPIC -O2 -o /statx_fill.so /statx_fill.c -ldl

FROM sandboxai/base
USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      xvfb x11vnc novnc websockify openbox tint2 xterm dbus-x11 gnome-keyring libsecret-1-0 \
      fonts-dejavu-core libasound2t64 libatk-bridge2.0-0t64 libcups2t64 libgbm1 libgtk-3-0t64 \
      libnss3 libxkbcommon0 libxdamage1 libxcomposite1 libxrandr2 libxss1 \
 && rm -rf /var/lib/apt/lists/*

# Anthropic publishes no URL for this key, so it is versioned here instead; apt fails loudly if it rotates.
COPY claude-desktop-archive-keyring.asc /usr/share/keyrings/claude-desktop-archive-keyring.asc
RUN echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' \
      > /etc/apt/sources.list.d/claude-desktop.list \
 && apt-get update && apt-get install -y --no-install-recommends claude-desktop \
 && rm -rf /var/lib/apt/lists/*

# A real browser, because both apps sign you in by handing a URL to xdg-open — without one the login just
# sits on "Awaiting Authentication". Ubuntu's own firefox/chromium packages are snap stubs that cannot run in
# a container. Firefox from Mozilla's apt repo installs fine but dies instantly under gVisor
# ("wasm_rt_syscall_set_segue_base error: Invalid argument" — its RLBox sandbox needs a syscall runsc does not
# implement), so this is Chrome: the same Chromium the two Electron apps already run on in here.
RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb \
 && apt-get update && apt-get install -y --no-install-recommends /tmp/chrome.deb xdg-utils \
 && rm -f /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*

# xdg-open execs $BROWSER with no chance to add flags, and bare chrome cannot start here — same dropped
# capabilities and same missing proxy env as the Electron apps. This wrapper is what $BROWSER points at.
COPY browser.sh /usr/local/bin/sandboxai-browser
RUN chmod 0755 /usr/local/bin/sandboxai-browser

# Antigravity ships no repo, only a versioned tarball. Bump this ARG to upgrade; the URLs are listed on
# https://antigravity.google/download (the page is gzipped JS, so read it with `curl --compressed`).
ARG ANTIGRAVITY_URL=https://storage.googleapis.com/antigravity-public/antigravity-hub/2.13.0-6362815968182272/linux-x64/Antigravity.tar.gz
RUN mkdir -p /opt/antigravity \
 && curl -fsSL "$ANTIGRAVITY_URL" | tar -xz --strip-components=1 -C /opt/antigravity \
 && ln -sf /opt/antigravity/antigravity /usr/local/bin/antigravity

COPY --from=statx-shim /statx_fill.so /usr/local/lib/sandboxai/statx_fill.so
RUN echo /usr/local/lib/sandboxai/statx_fill.so > /etc/ld.so.preload

COPY session.sh /usr/local/bin/sandboxai-desktop
RUN chmod 0755 /usr/local/bin/sandboxai-desktop

USER agent
WORKDIR /work
