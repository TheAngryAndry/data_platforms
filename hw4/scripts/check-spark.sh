#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop HADOOP_CONF_DIR=/etc/hadoop/yarn-conf
export HIVE_CONF_DIR=/etc/hive/client HADOOP_HEAPSIZE=256
result=$(mktemp)
trap 'rm -f "$result"' EXIT

/opt/hive/bin/beeline -u jdbc:hive2://127.0.0.1:10000/default -n team \
  --silent=true --showHeader=false --outputformat=tsv2 \
  -e 'SHOW PARTITIONS hw4.daily_sales;
      SELECT sale_date, orders, quantity, revenue FROM hw4.daily_sales ORDER BY sale_date;' > "$result"
diff -u data/expected.tsv "$result"
cat "$result"
