#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
sudo bash scripts/install-hive.sh
ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes "$SSH_USER@$NAMENODE_HOST" \
  'sudo bash -s' < scripts/setup-hive-hdfs.sh
sudo systemctl enable hive-metastore hive-server2
sudo systemctl restart hive-metastore hive-server2

# A running systemd service does not yet mean Hive accepts JDBC queries.
ready_log=$(mktemp)
trap 'rm -f "$ready_log"' EXIT
for attempt in $(seq 1 30); do
  if timeout 20 scripts/beeline.sh --silent=true -e 'SELECT 1;' >"$ready_log" 2>&1; then
    bash scripts/load-data.sh
    exit 0
  fi
  sleep 5
done
cat "$ready_log" >&2
echo 'HiveServer2 did not become ready.' >&2
exit 1
