# sandboxai toolchain base: the absolute minimum for a WORKING agent box. Node (gemini-cli runs on it),
# the python3 interpreter + stdlib (the agent reaches for `python3 -c`/scripts constantly to edit files),
# git, and TLS roots. Deliberately NOT here: pip, compilers, ffmpeg, a pinned JDK — those are TOOLCHAIN
# CHOICES the repo owns. Declare them in .sandboxai/Dockerfile (FROM this image) and the launcher builds a
# cached per-repo image — see resolve_image in ../sandboxai. The GUI stack is NOT here either: it lives in
# ../desktop (FROM this image), so a headless `sandboxai claude .` never drags a desktop around.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 curl xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Ubuntu's apt node is 18, too old for gemini-cli; the upstream tarball is one layer and no extra apt repo.
ARG NODE_VERSION=20.19.0
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
  | tar -xJ --strip-components=1 -C /usr/local

# The agent CLIs: claude, antigravity, gemini. Run any with `sandboxai <name> .`. No API keys are
# forwarded — each authenticates from its host login, seeded into the box by ensure_box_auth (../sandboxai).
# claude and antigravity ship native binaries, so they come from their own installers rather than npm. Both
# hardcode $HOME/.local/bin as the target and the box's $HOME is WIPED every run, so they are installed
# under a fixed root and symlinked onto PATH — a home-relative install would vanish at launch.
ENV TOOLCHAIN_HOME=/opt/toolchain
RUN mkdir -p "$TOOLCHAIN_HOME" \
 && HOME="$TOOLCHAIN_HOME" sh -c 'curl -fsSL https://claude.ai/install.sh | bash' \
 && HOME="$TOOLCHAIN_HOME" sh -c 'curl -fsSL https://antigravity.google/cli/install.sh | bash' \
 && ln -sf "$TOOLCHAIN_HOME"/.local/bin/* /usr/local/bin/ \
 && npm install -g @google/gemini-cli \
 && npm cache clean --force

# Non-root agent with an EMPTY home. Nothing sensitive is ever baked or mounted here.
# ubuntu:24.04 already ships an `ubuntu` user at UID 1000; drop it so `agent` can own that UID (matches the host user bind-mounting /work).
RUN userdel -r ubuntu \
 && useradd -m -u 1000 agent \
 && install -d -o agent -g agent /home/agent/.claude /home/agent/.claude/projects   # BOTH must be agent-owned: install -d only chowns the last component, and a root-owned .claude blocks the wrapper from seeding creds into it; projects is where the memory volume mounts
USER agent
WORKDIR /work
