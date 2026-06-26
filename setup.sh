#!/usr/bin/env bash
# sandboxai setup — preflight the host, then build the box + proxy images.
#
# Installs NOTHING destructively: if a prerequisite is missing it prints the exact
# command to fix it and stops. Safe to re-run — the docker layer cache makes
# repeated builds cheap, and every check is read-only.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ok()  { printf '  \033[32mok\033[0m    %s\n' "$1"; }
die() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; shift; for l in "$@"; do printf '          %s\n' "$l"; done; exit 1; }

echo "== sandboxai setup =="

# 1. Docker CLI + a reachable daemon ----------------------------------------
command -v docker >/dev/null 2>&1 || die "docker CLI not found" \
  "install Docker Engine: https://docs.docker.com/engine/install/"
docker info >/dev/null 2>&1 || die "docker daemon not reachable" \
  "start it:  sudo systemctl start docker" \
  "or add yourself to the docker group, then re-login"
ok "docker present and daemon reachable"

# 2. gVisor (runsc) — REQUIRED; the launcher now fails closed without it ------
command -v runsc >/dev/null 2>&1 || die "gVisor 'runsc' not installed" \
  "install:   https://gvisor.dev/docs/user_guide/install/" \
  "register:  sudo runsc install && sudo systemctl restart docker"
ok "runsc binary present"

# 3. runsc must be REGISTERED with the daemon (the binary alone is not enough)-
if docker info --format '{{range $k,$v := .Runtimes}}{{$k}} {{end}}' 2>/dev/null | grep -qw runsc; then
  ok "runsc registered as a docker runtime"
else
  die "runsc is installed but not registered with the docker daemon" \
    "register:  sudo runsc install && sudo systemctl restart docker"
fi

# 4. Build the images (idempotent) ------------------------------------------
echo "-- building images (cached re-runs are fast)"
docker build -q -t sandboxai/proxy "$here/proxy" >/dev/null && ok "image sandboxai/proxy"
docker build -q -t sandboxai/base  "$here/base"  >/dev/null && ok "image sandboxai/base"

cat <<EOF

setup complete. next:
  ./sandboxai claude .     # run claude in the locked box over the current dir
  ./sandboxai bash   .     # poke around inside the box
  ./sandboxai teardown     # remove proxy, networks, and the seeded claude volume
EOF
