#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop HADOOP_CONF_DIR=/etc/hadoop/yarn-conf
export HADOOP_HEAPSIZE=256 PYSPARK_PYTHON=/usr/bin/python3

for service in yarn-resourcemanager hive-metastore hive-server2; do
  systemctl is-active --quiet "$service"
done
for host in team-01-00 team-01-01; do
  ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes "team@$host" \
    'test -x /usr/bin/python3 || { sudo apt-get update -qq && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3; }'
done
/opt/hadoop/bin/hdfs dfs -mkdir -p /user/team/hw4/input
/opt/hadoop/bin/hdfs dfs -put -f data/sales.csv /user/team/hw4/input/sales.csv

/opt/spark/bin/spark-submit \
  --master yarn --deploy-mode cluster \
  --driver-memory 512m --executor-memory 512m \
  --num-executors 2 --executor-cores 1 \
  --conf spark.driver.memoryOverhead=384 \
  --conf spark.executor.memoryOverhead=384 \
  --conf spark.sql.shuffle.partitions=2 \
  --conf spark.ui.enabled=false \
  sales.py

export HIVE_CONF_DIR=/etc/hive/client
/opt/hive/bin/beeline -u jdbc:hive2://127.0.0.1:10000/default -n team -f sql/daily-sales.sql
bash scripts/check-spark.sh
