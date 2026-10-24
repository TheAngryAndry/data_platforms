#!/usr/bin/env bash
set -euo pipefail

dfs() { sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfs "$@"; }
backup=$(mktemp -d /var/backups/data-platforms-hive-hdfs.XXXXXX)
dfs -ls -d /user/hive /user/hive/warehouse /user/hive/warehouse-external /tmp/hive \
  > "$backup/permissions.txt" 2>&1 || true
getent group hive >/dev/null || groupadd --system hive
id hive >/dev/null 2>&1 || useradd --system --gid hive \
  --home-dir /var/lib/hive --shell /usr/sbin/nologin hive
sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -refreshUserToGroupsMappings
dfs -mkdir -p /user/hive/warehouse /user/hive/warehouse-external /tmp/hive
dfs -chown hive:hive /user/hive /user/hive/warehouse /user/hive/warehouse-external /tmp/hive
dfs -chmod 750 /user/hive /user/hive/warehouse /user/hive/warehouse-external
dfs -chmod 1777 /tmp/hive
