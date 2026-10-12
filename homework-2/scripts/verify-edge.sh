#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source ./cluster.conf
source /etc/profile.d/hadoop-yarn.sh
ssh_opts=(-i "$HOME/.ssh/team_internal" -o BatchMode=yes)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for service in yarn-resourcemanager mapred-historyserver nginx hadoop-web-firewall; do
  systemctl is-active --quiet "$service"
done
for host in $NODEMANAGER_HOSTS; do
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'systemctl is-active --quiet yarn-nodemanager'
done
python3 - <<'PY'
import json, time, urllib.request
for attempt in range(60):
    try:
        with urllib.request.urlopen('http://10.1.0.10:18088/ws/v1/cluster/nodes?states=RUNNING', timeout=5) as r:
            nodes = json.load(r)['nodes']['node']
        assert len(nodes) == 2 and all(n['state'] == 'RUNNING' for n in nodes), nodes
        print('PASS: 2 RUNNING NodeManagers')
        break
    except Exception:
        if attempt == 59:
            raise
        time.sleep(2)
PY
yarn node -list
ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
  'sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf dfsadmin -report' > "$work/hdfs-report"
cat "$work/hdfs-report"
grep -q 'Live datanodes (3)' "$work/hdfs-report"
if grep -Eq 'Dead datanodes \([1-9]' "$work/hdfs-report"; then exit 1; fi

run="/user/team/homework-2-$(date -u +%Y%m%dT%H%M%S)-$$"
printf 'hadoop yarn hadoop\nyarn hdfs\n' > "$work/input.txt"
hdfs dfs -mkdir -p "$run/input"
hdfs dfs -put "$work/input.txt" "$run/input/"
timeout 300 hadoop jar "/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-$HADOOP_VERSION.jar" \
  wordcount "$run/input" "$run/output" 2>&1 | tee "$work/job.log"
hdfs dfs -cat "$run/output/part-r-00000" > "$work/actual"
printf 'hadoop\t2\nhdfs\t1\nyarn\t2\n' > "$work/expected"
diff -u "$work/expected" "$work/actual"
app=$(grep -oE 'application_[0-9]+_[0-9]+' "$work/job.log" | tail -1)
test -n "$app"
yarn application -status "$app" 2>&1 | tee "$work/status"
grep -q 'Final-State : SUCCEEDED' "$work/status"
job=${app/application_/job_}
for attempt in $(seq 1 60); do
  if curl -fsS "http://10.1.0.10:19889/ws/v1/history/mapreduce/jobs/$job" > "$work/history.json"; then break; fi
  sleep 2
done
python3 - "$work/history.json" <<'PY'
import json, sys
job = json.load(open(sys.argv[1]))['job']
assert job['state'] == 'SUCCEEDED', job
print('PASS: JobHistoryServer', job['id'], job['state'])
PY
for attempt in $(seq 1 60); do
  if yarn logs -applicationId "$app" > "$work/logs" 2>&1 && grep -q 'LogType:' "$work/logs"; then break; fi
  sleep 2
done
grep -q 'LogType:' "$work/logs"
echo "PASS: aggregated logs for $app"
ssh "${ssh_opts[@]}" "$SSH_USER@$NAMENODE_HOST" \
  'sudo -u hdfs /opt/hadoop/bin/hdfs --config /etc/hadoop/conf fsck /' > "$work/fsck" 2>&1
cat "$work/fsck"
grep -q 'Status: HEALTHY' "$work/fsck"
VERIFY_HOST=10.1.0.10 bash scripts/verify-web.sh
echo "PASS: WordCount on YARN; $app; HDFS output: $run/output"
