#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop HADOOP_CONF_DIR=/etc/hadoop/yarn-conf
export HIVE_CONF_DIR=/etc/hive/client HADOOP_HEAPSIZE=256
exec /opt/hive/bin/beeline -u jdbc:hive2://127.0.0.1:10000/default -n team "$@"
