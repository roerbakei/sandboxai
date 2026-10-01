#!/usr/bin/env bash
# Regression probe for --exclude: (1) a masked path must not show up as a git deletion in the repo that
# owns it — including a NESTED repo, since the project root is often just a folder of repos — and (2) an
# --exclude that names nothing must be refused, not silently mounted (docker would create root-owned junk
# in the project). Needs docker + the sandboxai/base image; no gVisor.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$here/sandboxai" --version >/dev/null

proj="$(mktemp -d)"
trap 'rm -rf "$proj"' EXIT
git -C "$proj" init -q sub
mkdir -p "$proj/sub/secret" && echo x > "$proj/sub/secret/k" && echo x > "$proj/sub/.env"
git -C "$proj/sub" add -A && git -C "$proj/sub" -c user.name=t -c user.email=t@t commit -qm init

dirty="$(docker run --rm --user "$(id -u)" -e HOME=/tmp -e SANDBOXAI_EXCLUDES=$'sub/secret/\nsub/.env\n' \
  -v "$proj":/work -w /work --tmpfs /work/sub/secret -v /dev/null:/work/sub/.env:ro \
  sandboxai/base sh -c "$BOX_WRAPPER" _ git -C /work/sub status --porcelain)"
[[ -z "$dirty" ]] || { echo "FAIL  masked excludes show as git changes in the nested repo:" >&2; echo "$dirty" >&2; exit 1; }

"$here/sandboxai" bash "$proj" --exclude=nope/ 2>/dev/null && { echo "FAIL  a missing --exclude was accepted" >&2; exit 1; }
[[ ! -e "$proj/nope" ]] || { echo "FAIL  a missing --exclude left junk in the project" >&2; exit 1; }

echo "ok: excludes are skip-worktree'd in the owning repo; a missing exclude is refused"
