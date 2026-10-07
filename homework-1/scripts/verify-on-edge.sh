#!/usr/bin/env bash
set -Eeuo pipefail

internal_key=/home/team/.ssh/team_internal
ssh_opts=(-i "$internal_key" -o BatchMode=yes)
fail=0

check_service() {
  local host=$1 service=$2
  ssh "${ssh_opts[@]}" "team@$host" "systemctl is-active --quiet '$service'"
  echo "OK: $host $service is active"
}

check_service team-01-nn hdfs-namenode.service
check_service team-01-nn hdfs-datanode.service
check_service team-01-nn hdfs-secondarynamenode.service
check_service team-01-00 hdfs-datanode.service
check_service team-01-01 hdfs-datanode.service

report=$(ssh "${ssh_opts[@]}" team@team-01-nn 'sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -report')
printf '%s\n' "$report"
live=$(sed -n 's/^Live datanodes (\([0-9][0-9]*\)):.*/\1/p' <<<"$report")
dead=$(sed -n 's/^Dead datanodes (\([0-9][0-9]*\)):.*/\1/p' <<<"$report")
dead=${dead:-0}
[[ $live == 3 ]] || { echo "FAIL: expected 3 live DataNodes, got ${live:-unknown}" >&2; fail=1; }
[[ $dead == 0 ]] || { echo "FAIL: expected 0 dead DataNodes, got ${dead:-unknown}" >&2; fail=1; }

fsck=$(ssh "${ssh_opts[@]}" team@team-01-nn 'sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf fsck /' 2>&1)
printf '%s\n' "$fsck"
grep -q 'Status: HEALTHY' <<<"$fsck" || { echo "FAIL: HDFS fsck is not HEALTHY" >&2; fail=1; }

for spec in \
  'team-01-nn:hdfs-namenode.service hdfs-datanode.service hdfs-secondarynamenode.service' \
  'team-01-00:hdfs-datanode.service' \
  'team-01-01:hdfs-datanode.service'; do
  host=${spec%%:*}
  services=${spec#*:}
  errors=$(ssh "${ssh_opts[@]}" "team@$host" "sudo journalctl --since '-10 minutes' -p err --no-pager $(printf -- '-u %s ' $services)")
  if grep -qv '^-- No entries --$' <<<"$errors" && [[ -n $errors ]]; then
    echo "FAIL: critical journal entries on $host" >&2
    printf '%s\n' "$errors" >&2
    fail=1
  else
    echo "OK: no critical journal entries on $host"
  fi
done

if [[ $fail -ne 0 ]]; then
  exit 1
fi
echo "PASS: HDFS is healthy; 3 live DataNodes, 0 dead DataNodes"
