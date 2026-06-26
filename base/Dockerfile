# sandboxai toolchain base: the absolute minimum for a WORKING agent box. Node (the agent CLIs run on
# it), the python3 interpreter + stdlib (the agent reaches for `python3 -c`/scripts constantly to edit
# files), git, and TLS roots. Deliberately NOT here: pip, compilers, ffmpeg, a pinned JDK — those are
# TOOLCHAIN CHOICES the repo owns. Declare them in .sandboxai/Dockerfile (FROM this image) and the
# launcher builds a cached per-repo image — see resolve_image in ../sandboxai.
FROM node:20-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates python3 \
 && rm -rf /var/lib/apt/lists/*

# The agent CLIs: claude (`claude`) and gemini (`gemini`). Run either with `sandboxai claude .` /
# `sandboxai gemini .`. No API keys are forwarded — each authenticates from its host login, seeded into
# the box by ensure_box_auth (../sandboxai): ~/.claude for claude, ~/.gemini for gemini. Add more agents
# here, or in a repo Dockerfile.
RUN npm install -g @anthropic-ai/claude-code @google/gemini-cli

# Non-root agent with an EMPTY home. Nothing sensitive is ever baked or mounted here.
# node:20-slim already ships a `node` user at UID 1000; drop it so `agent` can own that UID (matches the host user bind-mounting /work).
RUN userdel -r node && useradd -m -u 1000 agent \
 && install -d -o agent -g agent /home/agent/.claude /home/agent/.claude/projects   # BOTH must be agent-owned: install -d only chowns the last component, and a root-owned .claude blocks the wrapper from seeding creds into it; projects is where the memory volume mounts
USER agent
WORKDIR /work
