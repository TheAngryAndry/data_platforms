#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."
source ./cluster.env
ssh_opts=(-i "$HOME/.ssh/team_internal" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

curl -fL "$HADOOP_URL" -o "hadoop-${HADOOP_VERSION}.tar.gz"

for host in $DATANODE_HOSTS; do
  scp "${ssh_opts[@]}" -r "$PWD" "$SSH_USER@$host:"
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'sudo bash ~/homework-1/scripts/install.sh'
done

ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" '
  sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf namenode -format -nonInteractive &&
  sudo systemctl enable --now hdfs-namenode.service hdfs-secondarynamenode.service
'

for host in $DATANODE_HOSTS; do
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'sudo systemctl enable --now hdfs-datanode.service'
done
