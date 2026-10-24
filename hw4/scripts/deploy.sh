#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
ssh_opts=(-F "${LOCAL_SSH_CONFIG:-/dev/null}" -i "${LOCAL_SSH_KEY:-$HOME/.ssh/id_ed25519_mts_course}"
  -o BatchMode=yes -o StrictHostKeyChecking=accept-new
  -o "UserKnownHostsFile=${SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}")
edge="$SSH_USER@$EDGE_PUBLIC_IP"
if (( $# != 0 )); then
  echo 'Usage: deploy.sh' >&2
  exit 1
fi

tar -czf - cluster.conf config scripts systemd README.md nginx data sql sales.py |
  ssh "${ssh_opts[@]}" "$edge" 'mkdir -p ~/data-platforms/hw4; tar -xzf - -C ~/data-platforms/hw4'
ssh "${ssh_opts[@]}" "$edge" 'bash ~/data-platforms/hw4/scripts/deploy-hdfs-edge.sh'
ssh "${ssh_opts[@]}" "$edge" 'bash ~/data-platforms/hw4/scripts/deploy-yarn-edge.sh'
ssh "${ssh_opts[@]}" "$edge" 'bash ~/data-platforms/hw4/scripts/deploy-hive-edge.sh'
ssh "${ssh_opts[@]}" "$edge" \
  'cd ~/data-platforms/hw4 && sudo bash scripts/install-spark.sh && bash scripts/run-spark.sh'
