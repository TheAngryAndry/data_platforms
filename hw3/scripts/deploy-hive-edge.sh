#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
sudo bash scripts/install-hive.sh
ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes "$SSH_USER@$NAMENODE_HOST" \
  'sudo bash -s' < scripts/setup-hive-hdfs.sh
sudo systemctl enable hive-metastore hive-server2
sudo systemctl restart hive-metastore hive-server2
