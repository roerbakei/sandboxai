#!/usr/bin/env bash
# Regression probe for the web-port egress firewall (commit 9fe9b21).
#
# THE GUARANTEE UNDER TEST: only web ports (80/443/563) may leave the proxy.
# tinyproxy's ConnectPort gates only CONNECT, so plain-HTTP forwarding
# (`GET http://host:22/`) used to reach SSH. The fix adds an OUTPUT firewall
# on the proxy container. This probe proves it end-to-end, through a REAL box
# and its REAL policy-scoped proxy — the same path an agent would take.
#
# Run on the HOST (needs the docker socket; the box itself has none).
#   ./test-egress.sh
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "== 1/3  build (bake the fix into sandboxai/proxy) =="
make build >/dev/null
echo "   ok"

echo "== 2/3  behavioural probe through the box's proxy =="
# Run a python probe INSIDE a real box. urllib honours the box's HTTP(S)_PROXY,
# so http://h:PORT/ becomes a plain-HTTP forward and https:// becomes a CONNECT
# — exactly the two ways out. We time each: a DROP makes the proxy's outbound
# SYN vanish, so the request stalls to timeout; a reachable port answers fast.
probe='
import json, time, urllib.request as u, socket
def hit(url, t=8):
    start=time.time()
    try:
        u.urlopen(url, timeout=t); return ("ok", time.time()-start, "")
    except Exception as e:
        return (type(e).__name__, time.time()-start, str(e)[:60])
r={
 "web_443":  hit("https://github.com/"),   # CONNECT :443  -> must work, fast
 "web_80":   hit("http://github.com/"),     # plain HTTP :80 -> must work, fast
 "ssh_22":   hit("http://github.com:22/"),  # plain HTTP :22 -> SSH; MUST be blocked (stall)
 "pg_5432":  hit("http://github.com:5432/"),# plain HTTP :5432 -> MUST be blocked (stall)
}
print("PROBE_JSON "+json.dumps(r))
'
out="$(printf '%s' "$probe" | ./sandboxai bash . -- -c 'python3 -' 2>/dev/null | grep '^PROBE_JSON ' | sed 's/^PROBE_JSON //')"
[[ -n "$out" ]] || { echo "   FAIL: no probe output (box never produced a result)"; exit 1; }
echo "   raw: $out"

echo "== 3/3  proxy firewall rules (deterministic backstop) =="
proxy="$(docker ps --filter name=sandboxai_proxy_ --format '{{.Names}}' | head -1)"
rules=""
if [[ -n "$proxy" ]]; then
  rules="$(docker exec "$proxy" iptables -S OUTPUT 2>/dev/null || true)"
  echo "$rules" | sed 's/^/   /'
else
  echo "   (no proxy container found — was the box launched?)"
fi

echo "== verdict =="
# Discriminator is TIMING: blocked ports stall to ~timeout (DROP swallows the SYN);
# pre-fix, :22 answered in ~0.37s (SSH is open on github). < 3s on a non-web port = LEAK.
python3 - "$out" "$rules" <<'PY'
import json, sys
r=json.loads(sys.argv[1]); rules=sys.argv[2]
def ok(k):   s,t,_=r[k]; return s=="ok" and t<6          # answered fast
def blk(k):  s,t,_=r[k]; return (s!="ok") and t>=5        # stalled, then failed = DROP
def leak(k): s,t,_=r[k]; return t<3 and not (s!="ok" and t>=5)  # fast = reached the port

verdict=[]
verdict.append(("web :443 reachable", ok("web_443")))
verdict.append(("web :80  reachable", ok("web_80")))
verdict.append(("SSH :22  blocked",   blk("ssh_22")  and not leak("ssh_22")))
verdict.append((":5432    blocked",   blk("pg_5432") and not leak("pg_5432")))
verdict.append(("firewall rule present", "OUTPUT DROP" in rules and "80,443,563" in rules))

for name,passed in verdict:
    print(f"   [{'PASS' if passed else 'FAIL'}] {name}")
for k in ("ssh_22","pg_5432"):
    s,t,m=r[k]
    if t<3 and not (s!='ok' and t>=5):
        print(f"   !! {k}: answered in {t:.2f}s ({s}) — proxy REACHED a non-web port. FIX NOT WORKING.")

allpass=all(p for _,p in verdict)
print("\n   "+("ALL PASS — egress firewall holds. Safe to push v0.1.1." if allpass
              else "FAILURES above — DO NOT push. Investigate before tagging."))
sys.exit(0 if allpass else 1)
PY
