#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../cluster.env
source "$repo_dir/cluster.env"
local_key=${LOCAL_SSH_KEY:-$HOME/.ssh/id_ed25519_mts_course}
ssh_opts=(-i "$local_key" -o BatchMode=yes)
edge="$SSH_USER@$EDGE_PUBLIC_IP"
remote_script=$(ssh "${ssh_opts[@]}" "$edge" 'mktemp /tmp/verify-hdfs.XXXXXX')
trap 'ssh "${ssh_opts[@]}" "$edge" "rm -f -- $remote_script" >/dev/null 2>&1 || true' EXIT
scp "${ssh_opts[@]}" "$repo_dir/scripts/verify-on-edge.sh" "$edge:$remote_script"
ssh "${ssh_opts[@]}" "$edge" "bash '$remote_script'"
