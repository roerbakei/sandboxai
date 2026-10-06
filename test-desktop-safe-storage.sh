#!/usr/bin/env bash
# Regression probe for the Claude Desktop login takeover: the host's Claude Desktop keyring key (application=Claude) must make it
# into the box keyring intact (secret + attributes), because the cookies copied from the host are noise without
# it. Feeds canned `secret-tool search` output through the real host parser, then restores it in the real
# desktop image. Uses a decoy secret — never touches your keyring. Needs docker and sandboxai/desktop.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$here/sandboxai" --version >/dev/null

DECOY=decoy-not-a-real-key
secret-tool() {
  cat <<EOF
[/org/freedesktop/secrets/collection/login/32]
label = Chromium Safe Storage
secret = $DECOY
created = 2026-07-15 16:33:12
modified = 2026-07-15 16:33:12
${FAKE_SCHEMA_LINE:+schema = chrome_libsecret_os_crypt_password_v2}
EOF
  echo "attribute.application = $CLAUDE_KEYRING_APP" >&2
}

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

stage_claude_safe_storage "$staging" || { echo "FAIL  host parser found nothing in canned secret-tool output" >&2; exit 1; }
FAKE_SCHEMA_LINE=1 stage_claude_safe_storage "$staging" || { echo "FAIL  host parser rejects output that carries a schema line" >&2; exit 1; }
[[ "$(stat -c %a "$staging/$CLAUDE_KEY_FILE")" == 600 ]] || { echo "FAIL  seed file is not 0600" >&2; exit 1; }
grep -qx "xdg:schema chrome_libsecret_os_crypt_password_v2" "$staging/$CLAUDE_KEY_FILE" || { echo "FAIL  seed lacks the chromium schema attribute" >&2; exit 1; }

restored="$(docker run --rm --user agent --entrypoint sh \
  -v "$staging/$CLAUDE_KEY_FILE":/seed:ro -v "$here/desktop/safe-storage.sh":/restore:ro sandboxai/desktop -c '
    eval "$(dbus-launch --sh-syntax)"
    eval "$(printf pw | gnome-keyring-daemon --unlock --components=secrets)"
    sh /restore /seed
    secret-tool lookup application Claude')"

[[ "$restored" == "$DECOY" ]] || { echo "FAIL  box keyring returned '$restored' instead of the seeded key" >&2; exit 1; }

DESKTOP_VOL=sandboxai_safe_storage_probe
trap 'rm -rf "$staging" "$fake_home"; docker volume rm -f "$DESKTOP_VOL" >/dev/null 2>&1 || true' EXIT
docker volume rm -f "$DESKTOP_VOL" >/dev/null 2>&1 || true
fake_home="$(mktemp -d)"
HOME="$fake_home"
mkdir -p "$HOME/.config/Claude/Local Storage" "$HOME/.local/share/keyrings"
echo host-cookies > "$HOME/$CLAUDE_COOKIES"
echo host-leveldb > "$HOME/.config/Claude/Local Storage/CURRENT"
echo host-keyring > "$HOME/$BOX_KEYRING/login.keyring"

in_volume() { docker run --rm -v "$DESKTOP_VOL":/d alpine:3.20 sh -c "$1"; }

in_volume 'mkdir -p "/d/.config/Claude/Local Storage" && echo stale > "/d/.config/Claude/Local Storage/stale.ldb"'
ensure_desktop_auth
[[ "$(in_volume 'cat /d/.config/Claude/Cookies')" == host-cookies ]] || { echo "FAIL  host Claude cookies were not taken over" >&2; exit 1; }
[[ -z "$(in_volume 'ls /d/.config/Claude/"Local Storage"/stale.ldb 2>/dev/null')" ]] || { echo "FAIL  stale leveldb file survived the takeover" >&2; exit 1; }
in_volume 'test -s /d/'"$CLAUDE_KEY_FILE" || { echo "FAIL  key not seeded beside the cookies" >&2; exit 1; }
[[ -z "$(in_volume 'ls /d/.local 2>/dev/null')" ]] || { echo "FAIL  host keyring was copied into the box seed" >&2; exit 1; }

secret-tool() { :; }
echo newer-host-cookies > "$HOME/$CLAUDE_COOKIES"
ensure_desktop_auth 2>/dev/null
[[ "$(in_volume 'cat /d/.config/Claude/Cookies')" == host-cookies ]] || { echo "FAIL  cookies replaced although the host key could not be read" >&2; exit 1; }

echo "ok: host key is staged by application+schema only, the box keyring answers the same lookup, the Claude login follows the host only with its key, and no host keyring crosses"
