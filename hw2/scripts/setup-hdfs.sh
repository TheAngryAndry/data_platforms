#!/usr/bin/env bash
set -euo pipefail

# HDFS resolves user groups on the NameNode.
backup=$(mktemp -d /var/backups/data-platforms-hdfs.XXXXXX)
getent passwd yarn mapred > "$backup/users.txt" || true
dfs() { sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfs "$@"; }
dfs -ls -d /tmp /logs /mr-history /mr-history/tmp /mr-history/done /user/team \
  > "$backup/directories.txt" 2>&1 || true
echo "HDFS permissions backup: $backup"

for user in yarn mapred; do
  id "$user" >/dev/null 2>&1 || useradd --system --gid hadoop \
    --home-dir "/var/lib/hadoop-$user" --create-home --shell /usr/sbin/nologin "$user"
done
sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -refreshUserToGroupsMappings
dfs -mkdir -p /tmp /logs /mr-history/tmp /mr-history/done /user/team
dfs -chmod 1777 /tmp /logs /mr-history/tmp
dfs -chown mapred:hadoop /mr-history /mr-history/tmp /mr-history/done
dfs -chmod 750 /mr-history/done
dfs -chown team:hadoop /user/team
