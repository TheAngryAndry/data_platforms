#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
ssh_opts=(-F "${LOCAL_SSH_CONFIG:-/dev/null}" -i "${LOCAL_SSH_KEY:-$HOME/.ssh/id_ed25519_mts_course}"
  -o BatchMode=yes -o StrictHostKeyChecking=accept-new
  -o "UserKnownHostsFile=${SSH_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"
  -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3)
edge="$SSH_USER@$EDGE_PUBLIC_IP"
for port in 9870 9868 9864 9865 9869 8088 8042 8043 19888; do
  ssh_opts+=(-L "127.0.0.1:$port:127.0.0.1:$port")
done

case ${1:-} in
  --check)
    work=$(mktemp -d)
    cleanup() {
      ssh "${ssh_opts[@]}" -S "$work/control" -O exit "$edge" 2>/dev/null || true
      rm -rf "$work"
    }
    trap cleanup EXIT
    ssh "${ssh_opts[@]}" -M -S "$work/control" -f -N "$edge"
    VERIFY_HOST=127.0.0.1 bash scripts/verify-web.sh
    ;;
  '')
    echo 'ResourceManager: http://127.0.0.1:8088/cluster'
    echo 'NameNode: http://127.0.0.1:9870/dfshealth.html'
    echo 'JobHistoryServer: http://127.0.0.1:19888/jobhistory'
    echo 'Keep this terminal open. Ctrl+C closes all tunnels.'
    exec ssh "${ssh_opts[@]}" -N "$edge"
    ;;
  *) echo 'Usage: open-web.sh [--check]' >&2; exit 1 ;;
esac
