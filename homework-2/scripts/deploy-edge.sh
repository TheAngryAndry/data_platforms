#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
ssh_opts=(-i "$HOME/.ssh/team_internal" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

# Check the existing cluster before changing configuration.
for host in $DATANODE_HOSTS; do
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'systemctl is-active --quiet hdfs-datanode'
done
ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
  'systemctl is-active --quiet hdfs-namenode && systemctl is-active --quiet hdfs-secondarynamenode && sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -report'

mkdir -p runtime
mkdir -p runtime/hdfs-conf
for file in core-site.xml hdfs-site.xml; do
  scp "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST:/etc/hadoop/conf/$file" runtime/hdfs-conf/
done
if [[ ! -x /opt/hadoop/bin/yarn ]]; then
  # Use exactly the same Hadoop distribution as the running HDFS cluster.
  ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
    "tar -C /opt -czf - hadoop-$HADOOP_VERSION" > runtime/hadoop.tar.gz
fi

sudo bash scripts/install.sh edge
for host in $NODEMANAGER_HOSTS; do
  tar --exclude='./runtime' --exclude='*.log' -czf - . |
    ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'mkdir -p ~/homework-2; tar -xzf - -C ~/homework-2'
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'sudo bash ~/homework-2/scripts/install.sh worker'
done

ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" 'sudo bash -s' < scripts/setup-hdfs.sh

sudo systemctl enable yarn-resourcemanager mapred-historyserver
sudo systemctl restart yarn-resourcemanager mapred-historyserver
for host in $NODEMANAGER_HOSTS; do
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" \
    'sudo systemctl enable yarn-nodemanager; sudo systemctl restart yarn-nodemanager'
done
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
bash scripts/verify-edge.sh
