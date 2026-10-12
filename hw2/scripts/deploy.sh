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

# Transfer only this homework's sources, not runtime files or logs.
tar -czf - cluster.conf config scripts systemd README.md nginx |
  ssh "${ssh_opts[@]}" "$edge" 'mkdir -p ~/data-platforms/hw2; tar -xzf - -C ~/data-platforms/hw2'
ssh "${ssh_opts[@]}" "$edge" 'bash ~/data-platforms/hw2/scripts/deploy-yarn-edge.sh'
bash scripts/open-web.sh --check
