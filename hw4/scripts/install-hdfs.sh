#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."
source ./cluster.conf

backup=$(mktemp -d /var/backups/data-platforms-hdfs-install.XXXXXX)
for path in /etc/hosts /etc/hadoop/conf /etc/systemd/system/hdfs-*.service; do
  if [[ -e $path ]]; then cp -a --parents "$path" "$backup"; fi
done
systemctl list-units --type=service --all --no-pager > "$backup/services.txt"
echo "Backup: $(hostname):$backup"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq "$JAVA_PACKAGE" procps python3

groupadd --system hadoop
useradd --system --gid hadoop --home-dir /var/lib/hadoop-hdfs --create-home --shell /usr/sbin/nologin hdfs

python3 scripts/configure-hosts.py

tar -xzf "hadoop-${HADOOP_VERSION}.tar.gz" -C /opt
ln -sfn "/opt/hadoop-${HADOOP_VERSION}" /opt/hadoop

install -d -o root -g hadoop -m 0755 /etc/hadoop/conf
cp -a /opt/hadoop/etc/hadoop/. /etc/hadoop/conf/
install -o root -g hadoop -m 0644 config/core-site.xml config/hdfs-site.xml config/hadoop-env.sh config/workers /etc/hadoop/conf/

install -d -o hdfs -g hadoop -m 0750 /var/lib/hadoop-hdfs/tmp /var/log/hadoop-hdfs
install -d -o hdfs -g hadoop -m 0700 /data/hdfs/{namenode,datanode,secondary}

install -o root -g root -m 0644 systemd/hdfs-*.service /etc/systemd/system/
systemctl daemon-reload
