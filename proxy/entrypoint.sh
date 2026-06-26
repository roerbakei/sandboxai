#!/bin/sh
# Only web ports may leave, enforced at the network layer: tinyproxy's ConnectPort gates only
# CONNECT, so plain-HTTP forwarding can otherwise reach any port (GET http://host:22/ hits SSH).
set -e

iptables -P OUTPUT DROP
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp -m multiport --dports 80,443,563 -j ACCEPT

exec tinyproxy -d -c /etc/tinyproxy/tinyproxy.conf
