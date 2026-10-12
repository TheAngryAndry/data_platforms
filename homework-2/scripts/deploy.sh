#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
ssh_opts=(-F "${LOCAL_SSH_CONFIG:-/dev/null}" -i "${LOCAL_SSH_KEY:-$HOME/.ssh/id_ed25519_mts_course}"
  -o BatchMode=yes -o StrictHostKeyChecking=accept-new
  -o "UserKnownHostsFile=${SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}")
edge="$SSH_USER@$EDGE_PUBLIC_IP"

# Transfer only source files, not downloaded Hadoop or local logs.
tar --exclude='./runtime' --exclude='*.log' -czf - . |
  ssh "${ssh_opts[@]}" "$edge" 'mkdir -p ~/homework-2; tar -xzf - -C ~/homework-2'
ssh "${ssh_opts[@]}" "$edge" 'bash ~/homework-2/scripts/deploy-edge.sh'
bash scripts/open-web.sh --check
