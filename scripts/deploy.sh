#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
ssh_opts=(-F "${LOCAL_SSH_CONFIG:-/dev/null}" -i "${LOCAL_SSH_KEY:-$HOME/.ssh/id_ed25519_mts_course}"
  -o BatchMode=yes -o StrictHostKeyChecking=accept-new
  -o "UserKnownHostsFile=${SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}")
edge="$SSH_USER@$EDGE_PUBLIC_IP"
stage=${1:-all}
case $stage in all|hdfs|yarn) ;; *) echo 'Usage: deploy.sh [all|hdfs|yarn]' >&2; exit 1 ;; esac

# Transfer only source files, not downloaded Hadoop or local logs.
tar -czf - cluster.conf config scripts systemd nginx README.md |
  ssh "${ssh_opts[@]}" "$edge" 'mkdir -p ~/data-platforms; tar -xzf - -C ~/data-platforms'
ssh "${ssh_opts[@]}" "$edge" "bash ~/data-platforms/scripts/deploy-edge.sh $stage"
if [[ $stage != hdfs ]]; then bash scripts/open-web.sh --check; fi
