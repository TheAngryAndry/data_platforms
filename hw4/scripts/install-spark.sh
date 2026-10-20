#!/usr/bin/env bash
set -euo pipefail

if [[ ! -x /usr/bin/python3 ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq python3
fi
test -x /usr/lib/jvm/java-11-openjdk-amd64/bin/java
test -x /opt/hadoop/bin/yarn
test -x /opt/hive/bin/beeline
test -f /etc/hadoop/yarn-conf/yarn-site.xml

backup=$(mktemp -d /var/backups/data-platforms-spark.XXXXXX)
if [[ -e /opt/spark || -L /opt/spark ]]; then cp -a /opt/spark "$backup/"; fi
systemctl list-units --type=service --all --no-pager > "$backup/services.txt"
echo "Backup: $(hostname):$backup"

version=3.5.7
archive="spark-$version-bin-hadoop3.tgz"
if [[ ! -x /opt/spark-$version-bin-hadoop3/bin/spark-submit ]]; then
  install -d /var/cache/spark
  cd /var/cache/spark
  curl -fL "https://archive.apache.org/dist/spark/spark-$version/$archive" -o "$archive"
  curl -fL "https://archive.apache.org/dist/spark/spark-$version/$archive.sha512" -o "$archive.sha512"
  sha512sum -c "$archive.sha512"
  tar --no-same-owner -xzf "$archive" -C /opt
fi
ln -sfn "/opt/spark-$version-bin-hadoop3" /opt/spark
