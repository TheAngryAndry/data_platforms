#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
ssh_opts=(-i "$HOME/.ssh/team_internal" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

if ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" 'sudo test -f /data/hdfs/namenode/current/VERSION'; then
  ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
    'systemctl is-active --quiet hdfs-namenode && systemctl is-active --quiet hdfs-secondarynamenode'
  for host in $DATANODE_HOSTS; do
    ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'systemctl is-active --quiet hdfs-datanode'
  done
  echo 'PASS: existing HDFS reused without formatting or restart'
  exit 0
fi

# Refuse to overwrite a partial installation or an existing namespace.
for host in $DATANODE_HOSTS; do
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" \
    'test ! -e /opt/hadoop && test ! -e /etc/hadoop/conf && sudo test ! -e /data/hdfs'
done
mkdir -p runtime
curl -fL "$HADOOP_URL" -o "runtime/hadoop-${HADOOP_VERSION}.tar.gz"
for host in $DATANODE_HOSTS; do
  tar -czf - cluster.conf config scripts systemd nginx "runtime/hadoop-${HADOOP_VERSION}.tar.gz" |
    ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'mkdir -p ~/data-platforms; tar -xzf - -C ~/data-platforms'
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'sudo bash ~/data-platforms/scripts/install-hdfs.sh'
done

ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" '
  sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf namenode -format -nonInteractive &&
  sudo systemctl enable --now hdfs-namenode.service hdfs-secondarynamenode.service
'
for host in $DATANODE_HOSTS; do
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'sudo systemctl enable --now hdfs-datanode.service'
done
for attempt in $(seq 1 30); do
  report=$(ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
    'sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -report')
  if grep -q 'Live datanodes (3)' <<< "$report"; then
    echo 'PASS: HDFS started; 3 live DataNodes'
    exit 0
  fi
  sleep 2
done
echo 'HDFS did not register all three DataNodes' >&2
exit 1
