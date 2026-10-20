#!/usr/bin/env bash
set -euo pipefail

if getent hosts team-01-nn.hse.c.mws | grep -q '^127\.'; then
  backup=$(mktemp -d /var/backups/data-platforms-hdfs-address.XXXXXX)
  cp -a /etc/hosts "$backup/"
  echo "Backup: $(hostname):$backup"
  # Hadoop берёт адрес локального DataNode из имени узла.
  sed -i \
    -e '/^127\.0\.1\.1[[:space:]]\+team-01-nn\.hse\.c\.mws[[:space:]]\+team-01-nn[[:space:]]*$/d' \
    -e 's/^10\.1\.0\.11[[:space:]].*/10.1.0.11\tteam-01-nn team-01-nn.hse.c.mws/' /etc/hosts
  getent hosts team-01-nn.hse.c.mws | grep -q '^10\.1\.0\.11[[:space:]]'
  systemctl restart hdfs-datanode
fi
