# sandboxai

Run an AI agent (or a shell) in an **empty room it can't escape into anything worth reaching**.
The box gets your project and a route to the web via a filtering proxy — nothing else.

## Install

```
git clone <repo> sandboxai && cd sandboxai
make build      # preflight host (docker + gVisor) and build images
make install    # symlink `sandboxai` into ~/.local/bin — no sudo
```

No root needed: `install` symlinks into `~/.local/bin` (on your PATH by default on most distros — if not,
`make install` prints the line to add). Want it system-wide instead? `sudo make install PREFIX=/usr/local`.
Keep the clone in place — `sandboxai` resolves its own symlink to find `base/` and `proxy/`. Prefer no
install at all? Run `./setup.sh` once and call `./sandboxai` from the clone. Remove with `make uninstall`.

## Usage

```
sandboxai claude [PATH]     # run claude in the locked box over PATH (default: current dir)
sandboxai gemini [PATH]     # run gemini instead
sandboxai bash   [PATH]     # poke around inside
sandboxai reseed            # refresh the box logins from your host (keeps history & settings)
sandboxai teardown          # remove proxy, networks, seeded login volume
sandboxai --help            # full option list
sandboxai --version

# options for the run commands (--flag value and --flag=value both work):
sandboxai claude . --exclude=.env --exclude=secrets/   # hide files/dirs from the box
sandboxai claude . --mount=~/Pictures/Screenshots      # add an extra host dir (at /mnt/Screenshots)
sandboxai claude . --allow-network=github.com --allow-network=pypi.org   # egress allowlist (deny the rest)
sandboxai claude . --dockerfile=ci/box.Dockerfile      # extra tools, FROM sandboxai/base
sandboxai claude . -- --model opus                     # everything after -- goes to the command
```

**Agents & auth.** `claude` and `gemini` are baked in; run any other agent by adding it in a
`--dockerfile`. **No API keys or host env are forwarded** — each agent authenticates from its host
login, copied into the box once: `~/.claude` (sanitized) for claude, `~/.gemini` for gemini. Log in on
the host first; after re-logging in, run `sandboxai reseed`.

## The guarantees

1. **Shares only the path you point at** — nothing else on your disk is visible.
2. **Empty `$HOME`, only the agent logins you use** — no `~/.ssh`, no `~/.aws`, no ssh-agent, and
   **no host env or API keys forwarded**. The only seeded credentials are your **agent logins**
   (`~/.claude`, sanitized to drop third-party MCP tokens and kept refreshable so claude doesn't log
   out mid-task; `~/.gemini` if present) — copied in, never live-mounted. A breach gets your source
   plus an agent session scoped to your account, nothing else. Prefer a fully ephemeral Claude token?
   Launch with `SANDBOXAI_EPHEMERAL_AUTH=1` and the refresh token is stripped too (you re-auth
   periodically). Your **user skills (`~/.claude/skills`) and enabled plugins (`~/.claude/plugins`)**
   are mirrored into the box on **every launch** — install a new one on the host and it's there next
   launch, no reseed needed.
3. **Egress = web via proxy only** — raw TCP (SSH/db/...) has no route; CONNECT is limited to web ports.
   By default every web host is reachable; pass **`--allow-network=HOST`** (repeatable) to lock egress
   to only those hosts and their subdomains and deny everything else.
4. **Boundary is host-enforced** — `--cap-drop ALL`, `--security-opt no-new-privileges`, an
   `--internal` network, and the **gVisor (`runsc`) runtime**, which also virtualizes `/proc`+`/sys`
   so the box can't even fingerprint the host kernel/hardware. The agent inside can't turn any of it off.

## Prerequisites

- **Docker Engine** with a reachable daemon.
- **gVisor (`runsc`)**, installed *and registered* with Docker. The launcher fails closed without it:
  ```
  # https://gvisor.dev/docs/user_guide/install/
  sudo runsc install && sudo systemctl restart docker
  ```
`./setup.sh` checks all of this and tells you exactly what's missing before building anything.

## Toolchain inside the box

The base image is **deliberately minimal** — just enough for a working agent: **Node** (the agent
CLIs run on it), **claude** and **gemini**, the **`python3` interpreter + stdlib** (the agent's go-to
for ad-hoc file scripting), **git**, and TLS roots. **Library dependencies** still just work — the box
installs them through the locked egress; HTTPS to package mirrors goes through the proxy, raw protocols
don't leave.

**Anything beyond the base is the repo's job.** A specific runtime version, a compiler, `pip`, system
packages (`ffmpeg`, `libpq-dev`, a JDK, ...) — declare them in **`.sandboxai/Dockerfile`**, built
`FROM sandboxai/base` so you keep claude and the locked setup:

```dockerfile
# .sandboxai/Dockerfile
FROM sandboxai/base
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3-pip ffmpeg build-essential \
 && rm -rf /var/lib/apt/lists/*
USER agent
```

On launch, sandboxai builds that into a per-repo image and **caches it by content hash** (rebuilt only
when the Dockerfile or the base image changes). The build step may go root and use the host network;
the image you actually *run* is still forced non-root with the same locked egress — build-time root ≠
runtime root, so the boundary is untouched. First launch pays the build once; every launch after is
instant. Purge the built images with `./sandboxai teardown` (or `docker rmi $(docker images -q
'sandboxai/custom')`).

## Isolation between projects

Each **PATH gets its own memory volume** — `sandboxai_proj_<sha of the absolute path>`, mounted over
`~/.claude/projects` so memory, history, and sessions never bleed between repos (every box runs at
`/work`, so without this they'd all collide on the same `-work` slug). Your **login, config, and
skills are shared** across all boxes in one `sandboxai_claude` volume — authenticate once, use it
everywhere. Memory volumes survive `teardown` on purpose; list them with
`docker volume ls -q | grep '^sandboxai_proj_'`.

## Layout

```
sandboxai          # the launcher — builds infra, applies the lock, runs the box
Makefile           # make install / uninstall (symlink onto PATH)
setup.sh           # one-time host preflight + image build
base/Dockerfile    # the box image: node + claude + gemini + python3 + git, empty-home non-root user
proxy/             # tinyproxy: the entire egress policy, ~20 auditable lines
```

## FAQ

**The login URL inside the box isn't clickable / I can't copy it.** Don't log in from inside the box.
The box can't reach your host clipboard (it has no display server, and mounting one in would expose your
desktop), and the long URL wraps so it won't select cleanly. Instead, log in on the **host** —
`claude` then `/login`, finish in your normal browser — then `sandboxai reseed` and relaunch. The box
comes up already authenticated and never shows the prompt.

**Why does a login prompt show up at all if I'm logged in on the host?** Your host login is seeded into
the box once. If it still prompts, either you haven't logged in on the host yet (do that, then
`sandboxai reseed`), or `SANDBOXAI_EPHEMERAL_AUTH=1` is set — that strips the refresh token on purpose,
so the box re-authenticates periodically.

**Can I give the box access to more than my project?** Yes — `--mount=PATH` (repeatable). Each lands at
`/mnt/<basename>`; override with `--mount=PATH:/abs/dest`. It's read-write and lives outside `/work`.
