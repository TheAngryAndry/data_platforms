#!/usr/bin/env bash
set -euo pipefail

rule=(-p tcp ! -s 10.1.0.0/24 -m multiport --dports 8030,8031,8032,8033,10020,10033,18088,19889 -j DROP)
iptables -w -C INPUT "${rule[@]}" 2>/dev/null || iptables -w -I INPUT 1 "${rule[@]}"
