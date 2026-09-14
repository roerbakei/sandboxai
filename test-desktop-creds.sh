#!/usr/bin/env bash
# Regression probe for the one invariant that keeps `sandboxai desktop` as locked as the headless box:
# a desktop run persists ONLY the credential blobs in DESKTOP_CREDS. If a future edit widens the harvest
# to whole config dirs, the box gains a way to plant executable config (mcpServers, hooks, skills) that
# runs in the NEXT box. That is the breach this asserts against. Takes seconds; needs no GUI.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$here/sandboxai" --version >/dev/null

DESKTOP_VOL=sandboxai_desktop_probe
BOX=sandboxai_desktop_probe_box
DECOYS=(".config/Claude/claude_desktop_config.json" ".config/Claude/Preferences" ".claude/settings.json" ".bashrc")

cleanup() { docker rm -f "$BOX" >/dev/null 2>&1 || true; docker volume rm -f "$DESKTOP_VOL" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$BOX" alpine:3.20 sleep 300 >/dev/null
docker exec "$BOX" sh -c '
  for p in "$@"; do mkdir -p "'"$BOX_HOME"'/$(dirname "$p")"; echo planted > "'"$BOX_HOME"'/$p"; done' \
  _ "${DESKTOP_CREDS[@]}" "${DECOYS[@]}"

harvest_desktop_creds "$BOX"
harvested="$(docker run --rm -v "$DESKTOP_VOL":/d alpine:3.20 find /d -type f | sed 's|^/d/||' | sort)"

fail=0
for p in "${DESKTOP_CREDS[@]}"; do
  grep -qxF "$p" <<<"$harvested" || { echo "MISSING  $p — the login will not survive a desktop run" >&2; fail=1; }
done
for p in "${DECOYS[@]}"; do
  grep -qxF "$p" <<<"$harvested" && { echo "LEAKED   $p — a compromised box can now plant this for the next run" >&2; fail=1; }
done

[[ $fail -eq 0 ]] && echo "ok: desktop harvest persists exactly DESKTOP_CREDS (${#DESKTOP_CREDS[@]} paths), nothing else"
exit $fail
