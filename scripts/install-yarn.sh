#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
role=${1:?Usage: install-yarn.sh edge|worker}
[[ $role == edge || $role == worker ]]

backup=$(mktemp -d /var/backups/data-platforms.XXXXXX)
for path in /etc/hosts /etc/hadoop/yarn-conf /etc/nginx /etc/profile.d/hadoop-yarn.sh \
  /etc/systemd/system/yarn-resourcemanager.service \
  /etc/systemd/system/yarn-nodemanager.service \
  /etc/systemd/system/mapred-historyserver.service \
  /etc/systemd/system/hadoop-web-firewall.service /usr/local/sbin/hadoop-web-firewall; do
  if [[ -e $path ]]; then cp -a --parents "$path" "$backup"; fi
done
systemctl list-units --type=service --all --no-pager > "$backup/services.txt"
ss -lnt > "$backup/ports.txt"
echo "Backup: $(hostname):$backup"

if [[ $role == edge ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq openjdk-11-jre-headless nginx python3 curl iptables
  if [[ ! -x /opt/hadoop/bin/yarn ]]; then
    tar -xzf runtime/hadoop.tar.gz -C /opt
    ln -sfn "/opt/hadoop-$HADOOP_VERSION" /opt/hadoop
  fi
fi
test -x /opt/hadoop/bin/yarn
test -x /usr/lib/jvm/java-11-openjdk-amd64/bin/java
python3 scripts/configure-hosts.py
getent group hadoop >/dev/null || groupadd --system hadoop
for user in yarn mapred; do
  id "$user" >/dev/null 2>&1 || useradd --system --gid hadoop \
    --home-dir "/var/lib/hadoop-$user" --create-home --shell /usr/sbin/nologin "$user"
done

install -d -o root -g hadoop -m 0755 /etc/hadoop/yarn-conf
cp -a /opt/hadoop/etc/hadoop/. /etc/hadoop/yarn-conf/
if [[ $role == edge ]]; then
  iptables-save > "$backup/iptables.txt"
  install -m 0755 scripts/firewall.sh /usr/local/sbin/hadoop-web-firewall
  install -m 0644 systemd/hadoop-web-firewall.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable --now hadoop-web-firewall
  cp runtime/hdfs-conf/{core-site.xml,hdfs-site.xml} /etc/hadoop/yarn-conf/
else
  cp /etc/hadoop/conf/{core-site.xml,hdfs-site.xml} /etc/hadoop/yarn-conf/
fi
install -o root -g hadoop -m 0644 config/yarn-site.xml config/mapred-site.xml config/capacity-scheduler.xml /etc/hadoop/yarn-conf/
install -o root -g hadoop -m 0644 config/yarn-env.sh /etc/hadoop/yarn-conf/hadoop-env.sh
if [[ $role == worker ]]; then
  case $(hostname -s) in
    team-01-00) node_ip=10.1.0.12 ;;
    team-01-01) node_ip=10.1.0.13 ;;
    *) echo 'Unknown NodeManager host' >&2; exit 1 ;;
  esac
  python3 - "$node_ip" <<'PY'
import sys, xml.etree.ElementTree as ET
path = '/etc/hadoop/yarn-conf/yarn-site.xml'
tree = ET.parse(path)
prop = ET.SubElement(tree.getroot(), 'property')
ET.SubElement(prop, 'name').text = 'yarn.nodemanager.hostname'
ET.SubElement(prop, 'value').text = sys.argv[1]
tree.write(path, encoding='UTF-8', xml_declaration=True)
PY
fi
# HDFS uses a private local tmp directory; YARN clients need their own.
python3 - <<'PY'
import xml.etree.ElementTree as ET
path = '/etc/hadoop/yarn-conf/core-site.xml'
tree = ET.parse(path)
for prop in tree.getroot().findall('property'):
    if prop.findtext('name') == 'hadoop.tmp.dir':
        prop.find('value').text = '/var/lib/hadoop-yarn/tmp'
tree.write(path, encoding='UTF-8', xml_declaration=True)
PY
install -d -o yarn -g hadoop -m 0755 /var/lib/hadoop-yarn
install -d -o yarn -g hadoop -m 0750 /var/lib/hadoop-yarn/local /var/log/hadoop-yarn
install -d -o yarn -g hadoop -m 1777 /var/lib/hadoop-yarn/tmp
install -d -o yarn -g hadoop -m 0750 /var/log/hadoop-yarn/containers
install -d -o mapred -g hadoop -m 0750 /var/log/hadoop-mapred
cat > /etc/profile.d/hadoop-yarn.sh <<'PROFILE'
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HADOOP_MAPRED_HOME=/opt/hadoop
export HADOOP_CONF_DIR=/etc/hadoop/yarn-conf
export PATH="$PATH:/opt/hadoop/bin"
PROFILE

if [[ $role == edge ]]; then
  install -m 0644 systemd/yarn-resourcemanager.service systemd/mapred-historyserver.service /etc/systemd/system/
  install -m 0644 nginx/hadoop-links.conf /etc/nginx/snippets/
  install -m 0644 nginx/hadoop.conf /etc/nginx/conf.d/
  nginx -t
else
  install -m 0644 systemd/yarn-nodemanager.service /etc/systemd/system/
fi
systemctl daemon-reload
