#!/usr/bin/env bash
# Regression probe for the GTK folder chooser: under gVisor, glib's g_file_query_info must succeed on /proc
# and /sys (see desktop/statx_fill.c). Needs docker + gVisor + the sandboxai/desktop image; no GUI.
set -euo pipefail

docker run --rm --runtime=runsc --user 1000 sandboxai/desktop python3 -c '
import ctypes, sys
gio = ctypes.CDLL("libgio-2.0.so.0")
gio.g_file_new_for_path.restype = ctypes.c_void_p
gio.g_file_query_exists.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
bad = [p for p in ("/proc", "/sys", "/dev") if not gio.g_file_query_exists(gio.g_file_new_for_path(p.encode()), None)]
sys.exit("FAIL  glib cannot stat: " + " ".join(bad) if bad else 0)'

echo "ok: glib can stat /proc and /sys under gVisor"
