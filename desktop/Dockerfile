# sandboxai desktop: the GUI apps (Claude Desktop, Antigravity) on a throwaway X server the host reaches
# over noVNC. Layered on sandboxai/base rather than merged into it so a headless `sandboxai claude .` never
# drags ~1GB of desktop around. The RUNTIME boundary is identical to the headless box — non-root, no caps,
# proxy-only egress, ephemeral $HOME (see run_box in ../sandboxai).
FROM sandboxai/base
USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      xvfb x11vnc novnc websockify openbox xterm dbus-x11 \
      fonts-dejavu-core libasound2t64 libatk-bridge2.0-0t64 libcups2t64 libgbm1 libgtk-3-0t64 \
      libnss3 libxkbcommon0 libxdamage1 libxcomposite1 libxrandr2 libxss1 \
 && rm -rf /var/lib/apt/lists/*

# Anthropic publishes no URL for this key, so it is versioned here instead; apt fails loudly if it rotates.
COPY claude-desktop-archive-keyring.asc /usr/share/keyrings/claude-desktop-archive-keyring.asc
RUN echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main' \
      > /etc/apt/sources.list.d/claude-desktop.list \
 && apt-get update && apt-get install -y --no-install-recommends claude-desktop \
 && rm -rf /var/lib/apt/lists/*

# Antigravity ships no repo, only a versioned tarball. Bump this ARG to upgrade; the URLs are listed on
# https://antigravity.google/download (the page is gzipped JS, so read it with `curl --compressed`).
ARG ANTIGRAVITY_URL=https://storage.googleapis.com/antigravity-public/antigravity-hub/2.13.0-6362815968182272/linux-x64/Antigravity.tar.gz
RUN mkdir -p /opt/antigravity \
 && curl -fsSL "$ANTIGRAVITY_URL" | tar -xz --strip-components=1 -C /opt/antigravity \
 && ln -sf /opt/antigravity/antigravity /usr/local/bin/antigravity

COPY session.sh /usr/local/bin/sandboxai-desktop
RUN chmod 0755 /usr/local/bin/sandboxai-desktop

USER agent
WORKDIR /work
