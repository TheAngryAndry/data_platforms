#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
test -x /opt/hadoop/bin/hadoop
test -f /etc/hadoop/yarn-conf/yarn-site.xml

backup=$(mktemp -d /var/backups/data-platforms-hive.XXXXXX)
chmod 700 "$backup"
for path in /etc/hive /etc/postgresql /etc/systemd/system/hive-metastore.service \
  /etc/systemd/system/hive-server2.service; do
  if [[ -e $path ]]; then cp -a --parents "$path" "$backup"; fi
done
systemctl list-units --type=service --all --no-pager > "$backup/services.txt"
ss -lnt > "$backup/ports.txt"
echo "Backup: $(hostname):$backup"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq postgresql libpostgresql-jdbc-java curl python3
getent group hive >/dev/null || groupadd --system hive
id hive >/dev/null 2>&1 || useradd --system --gid hive \
  --home-dir /var/lib/hive --create-home --shell /usr/sbin/nologin hive
install -d -o hive -g hive -m 0750 /var/lib/hive /var/log/hive
install -d -m 0755 /var/cache/hive /etc/hive /etc/hive/client
install -d -o root -g hive -m 0750 /etc/hive/metastore

if [[ ! -x /opt/apache-hive-$HIVE_VERSION-bin/bin/hive ]]; then
  archive="apache-hive-$HIVE_VERSION-bin.tar.gz"
  url="https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/$archive"
  curl -fL "$url" -o "/var/cache/hive/$archive"
  curl -fL "$url.sha256" -o "/var/cache/hive/$archive.sha256"
  (cd /var/cache/hive && sha256sum -c "$archive.sha256")
  tar -xzf "/var/cache/hive/$archive" -C /opt
fi
ln -sfn "/opt/apache-hive-$HIVE_VERSION-bin" /opt/hive
ln -sfn /usr/share/java/postgresql.jar /opt/hive/lib/postgresql.jar
systemctl enable --now postgresql
python3 scripts/configure-hive.py

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop HADOOP_CONF_DIR=/etc/hadoop/yarn-conf
export HIVE_CONF_DIR=/etc/hive/metastore HADOOP_HEAPSIZE=512
schema() {
  sudo -u hive --preserve-env=JAVA_HOME,HADOOP_HOME,HADOOP_CONF_DIR,HIVE_CONF_DIR,HADOOP_HEAPSIZE \
    /opt/hive/bin/schematool -dbType postgres "$@"
}
tables=$(sudo -u postgres psql -d hive_metastore -Atqc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")
if [[ $tables == 0 ]]; then schema -initSchema; fi
schema -info
install -m 0644 systemd/hive-metastore.service systemd/hive-server2.service /etc/systemd/system/
systemctl daemon-reload
