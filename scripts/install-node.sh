#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run install-node.sh through sudo" >&2
  exit 1
fi
if [[ $# -lt 2 ]]; then
  echo "Usage: install-node.sh STAGE ROLE [ROLE ...]" >&2
  exit 1
fi

stage=$1
shift
roles=("$@")
# shellcheck source=../cluster.env
source "$stage/cluster.env"

archive="$stage/dist/hadoop-${HADOOP_VERSION}.tar.gz"
[[ -f $archive ]] || { echo "Hadoop archive not found: $archive" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq "$JAVA_PACKAGE" procps curl

getent group hadoop >/dev/null || groupadd --system hadoop
id hdfs >/dev/null 2>&1 || useradd --system --gid hadoop --home-dir /var/lib/hadoop-hdfs --create-home --shell /usr/sbin/nologin hdfs

if [[ ! -x /opt/hadoop-${HADOOP_VERSION}/bin/hdfs ]]; then
  tar -xzf "$archive" -C /opt
fi
ln -sfn "/opt/hadoop-${HADOOP_VERSION}" /opt/hadoop

install -d -o root -g hadoop -m 0755 /etc/hadoop/conf
cp -a /opt/hadoop/etc/hadoop/. /etc/hadoop/conf/
install -o root -g hadoop -m 0644 "$stage/config/core-site.xml" /etc/hadoop/conf/core-site.xml
install -o root -g hadoop -m 0644 "$stage/config/hdfs-site.xml" /etc/hadoop/conf/hdfs-site.xml
install -o root -g hadoop -m 0644 "$stage/config/hadoop-env.sh" /etc/hadoop/conf/hadoop-env.sh
install -o root -g hadoop -m 0644 "$stage/config/workers" /etc/hadoop/conf/workers

install -d -o hdfs -g hadoop -m 0750 /var/lib/hadoop-hdfs/tmp /var/log/hadoop-hdfs /run/hadoop-hdfs
for role in "${roles[@]}"; do
  case "$role" in
    namenode) install -d -o hdfs -g hadoop -m 0700 /data/hdfs/namenode ;;
    datanode) install -d -o hdfs -g hadoop -m 0700 /data/hdfs/datanode ;;
    secondarynamenode) install -d -o hdfs -g hadoop -m 0700 /data/hdfs/secondary ;;
    *) echo "Unknown role: $role" >&2; exit 1 ;;
  esac
done

install -o root -g root -m 0644 "$stage/systemd/"*.service /etc/systemd/system/
systemctl daemon-reload

if [[ " ${roles[*]} " == *" namenode " && ! -f /data/hdfs/namenode/current/VERSION ]]; then
  sudo -u hdfs env JAVA_HOME="$JAVA_HOME" HADOOP_HOME=/opt/hadoop HADOOP_CONF_DIR=/etc/hadoop/conf \
    /opt/hadoop/bin/hdfs namenode -format -nonInteractive
fi

echo "Installed roles on $(hostname): ${roles[*]}"
