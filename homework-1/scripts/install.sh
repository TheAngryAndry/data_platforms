#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/.."
source ./cluster.env

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq "$JAVA_PACKAGE" procps

groupadd --system hadoop
useradd --system --gid hadoop --home-dir /var/lib/hadoop-hdfs --create-home --shell /usr/sbin/nologin hdfs

tar -xzf "hadoop-${HADOOP_VERSION}.tar.gz" -C /opt
ln -sfn "/opt/hadoop-${HADOOP_VERSION}" /opt/hadoop

install -d -o root -g hadoop -m 0755 /etc/hadoop/conf
cp -a /opt/hadoop/etc/hadoop/. /etc/hadoop/conf/
install -o root -g hadoop -m 0644 config/* /etc/hadoop/conf/

install -d -o hdfs -g hadoop -m 0750 /var/lib/hadoop-hdfs/tmp /var/log/hadoop-hdfs
install -d -o hdfs -g hadoop -m 0700 /data/hdfs/{namenode,datanode,secondary}

install -o root -g root -m 0644 systemd/*.service /etc/systemd/system/
systemctl daemon-reload
