#!/bin/sh
# What $BROWSER points at, so an OAuth URL handed to xdg-open actually opens. The flags are the same ones
# the Electron apps need — see session.sh for why each is load-bearing.
# --no-first-run alone does not stop the Linux Terms dialog, and that dialog lands ON TOP of the login page
# every single run because the box home is wiped each time. The sentinel file is what actually silences it.
chrome_dir="$HOME/.config/google-chrome"
mkdir -p "$chrome_dir" && : > "$chrome_dir/First Run"

exec google-chrome-stable \
  --no-sandbox --disable-gpu --password-store=basic \
  --no-first-run --no-default-browser-check \
  ${HTTPS_PROXY:+--proxy-server="$HTTPS_PROXY"} "$@"
