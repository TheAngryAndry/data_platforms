#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
ssh_opts=(-i "$HOME/.ssh/team_internal" -o BatchMode=yes)

ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
  'systemctl is-active --quiet hdfs-namenode && systemctl is-active --quiet hdfs-secondarynamenode'
for host in $DATANODE_HOSTS; do
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'systemctl is-active --quiet hdfs-datanode'
done
echo 'PASS: NameNode, SecondaryNameNode and 3 DataNode services active'

report=$(ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
  'sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -report')
echo "$report"
grep -q 'Live datanodes (3)' <<< "$report"
if grep -Eq '(Dead|Decommissioning) datanodes \([1-9]' <<< "$report"; then exit 1; fi
[[ $(grep -c 'Decommission Status : Normal' <<< "$report") == 3 ]]
grep -q 'Under replicated blocks: 0' <<< "$report"
grep -q 'Blocks with corrupt replicas: 0' <<< "$report"
grep -q 'Missing blocks: 0' <<< "$report"
echo 'PASS: 3 live DataNodes, no degraded nodes or blocks'

fsck=$(ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
  'sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf fsck /' 2>&1)
echo "$fsck"
grep -q 'Status: HEALTHY' <<< "$fsck"
echo 'PASS: HDFS fsck HEALTHY'
