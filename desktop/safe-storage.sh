#!/bin/sh
# Puts the host's "Claude Safe Storage" key into the box keyring, so the cookies copied from the host decrypt.
# The seed is data (secret, label, then one "name value" attribute per line), never a script — see ensure_desktop_auth.
set -eu

seed="${1:-$HOME/.sandboxai-claude-safe-storage}"
[ -s "$seed" ] || exit 0

{
  IFS= read -r secret
  IFS= read -r label
  set --
  while read -r name value; do set -- "$@" "$name" "$value"; done
  printf %s "$secret" | secret-tool store --label="$label" "$@"
} < "$seed"
