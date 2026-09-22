#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../cluster.env
source "$repo_dir/cluster.env"
local_key=${LOCAL_SSH_KEY:-$HOME/.ssh/id_ed25519_mts_course}
ssh_opts=(-i "$local_key" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
edge="$SSH_USER@$EDGE_PUBLIC_IP"

[[ -f $local_key ]] || { echo "SSH key not found: $local_key" >&2; exit 1; }
remote_stage=$(ssh "${ssh_opts[@]}" "$edge" 'mktemp -d /tmp/hdfs-deploy.XXXXXX')
cleanup() {
  ssh "${ssh_opts[@]}" "$edge" "rm -rf -- '$remote_stage'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

scp "${ssh_opts[@]}" -r "$repo_dir/cluster.env" "$repo_dir/config" "$repo_dir/systemd" "$repo_dir/scripts" "$edge:$remote_stage/"
ssh "${ssh_opts[@]}" "$edge" "bash '$remote_stage/scripts/deploy-from-edge.sh' '$remote_stage'"

"$repo_dir/scripts/verify-hdfs.sh"
