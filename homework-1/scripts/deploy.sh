#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."
source ./cluster.env
ssh_opts=(-i "${LOCAL_SSH_KEY:-$HOME/.ssh/id_ed25519_mts_course}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
edge="$SSH_USER@$EDGE_PUBLIC_IP"

scp "${ssh_opts[@]}" -r "$PWD" "$edge:"
ssh "${ssh_opts[@]}" "$edge" 'bash ~/homework-1/scripts/deploy-edge.sh'
