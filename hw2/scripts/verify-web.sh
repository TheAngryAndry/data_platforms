#!/usr/bin/env bash
set -euo pipefail

host=${VERIFY_HOST:-127.0.0.1}
for endpoint in 9870/dfshealth.html 9868/ 9864/datanode.html 9865/datanode.html \
  9869/datanode.html 8088/cluster 8042/node 8043/node 19888/jobhistory; do
  code=$(curl --noproxy '*' -sS -L -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 20 "http://$host:$endpoint")
  [[ $code == 200 ]] || { echo "FAIL: $endpoint HTTP $code"; exit 1; }
  echo "PASS: http://$host:$endpoint HTTP $code"
done
# Mutating requests must be rejected by nginx before reaching Hadoop.
code=$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' --max-time 10 \
  -X POST "http://$host:8088/ws/v1/cluster/apps/new-application")
[[ $code == 403 ]] || { echo "FAIL: expected HTTP 403 for POST, got $code"; exit 1; }
echo 'PASS: public proxy rejects POST'
nodes=$(curl --noproxy '*' -fsS --max-time 20 "http://$host:8088/cluster/nodes")
for port in 8042 8043; do
  grep -Fq "$host:$port" <<< "$nodes"
done
datanodes=$(curl --noproxy '*' -fsS --max-time 20 \
  "http://$host:9870/jmx?qry=Hadoop:service=NameNode,name=NameNodeInfo")
for port in 9864 9865 9869; do
  grep -Fq "$host:$port" <<< "$datanodes"
done
echo 'PASS: links to NodeManager and DataNode use the browser host'
