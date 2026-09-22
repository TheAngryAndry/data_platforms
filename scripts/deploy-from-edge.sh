#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: deploy-from-edge.sh STAGE" >&2
  exit 1
fi
stage=$1
# shellcheck source=../cluster.env
source "$stage/cluster.env"
internal_key=/home/team/.ssh/team_internal
ssh_opts=(-i "$internal_key" -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

mkdir -p "$stage/dist"
archive="$stage/dist/hadoop-${HADOOP_VERSION}.tar.gz"
if [[ ! -f $archive ]]; then
  curl -fL --retry 3 --connect-timeout 20 "$HADOOP_URL" -o "$archive"
fi
printf '%s  %s\n' "$HADOOP_SHA512" "$archive" | sha512sum -c -

deploy_internal() {
  local host=$1
  shift
  local remote_stage
  remote_stage=$(ssh "${ssh_opts[@]}" "$SSH_USER@$host" 'mktemp -d /tmp/hdfs-deploy.XXXXXX')
  if ! scp "${ssh_opts[@]}" -r "$stage/cluster.env" "$stage/config" "$stage/systemd" "$stage/scripts" "$stage/dist" "$SSH_USER@$host:$remote_stage/"; then
    ssh "${ssh_opts[@]}" "$SSH_USER@$host" "rm -rf -- '$remote_stage'"
    return 1
  fi
  if ! ssh "${ssh_opts[@]}" "$SSH_USER@$host" "sudo bash '$remote_stage/scripts/install-node.sh' '$remote_stage' $*"; then
    ssh "${ssh_opts[@]}" "$SSH_USER@$host" "rm -rf -- '$remote_stage'"
    return 1
  fi
  ssh "${ssh_opts[@]}" "$SSH_USER@$host" "rm -rf -- '$remote_stage'"
}

deploy_internal team-01-nn namenode datanode secondarynamenode
deploy_internal team-01-00 datanode
deploy_internal team-01-01 datanode

ssh "${ssh_opts[@]}" "$SSH_USER@team-01-nn" 'sudo systemctl enable hdfs-namenode.service && sudo systemctl restart hdfs-namenode.service'
for attempt in $(seq 1 30); do
  if timeout 1 bash -c '</dev/tcp/10.1.0.11/8020' 2>/dev/null; then
    break
  fi
  if [[ $attempt -eq 30 ]]; then
    echo "NameNode did not open port 8020" >&2
    exit 1
  fi
  sleep 2
done

ssh "${ssh_opts[@]}" "$SSH_USER@team-01-nn" 'sudo systemctl enable hdfs-datanode.service hdfs-secondarynamenode.service && sudo systemctl restart hdfs-datanode.service hdfs-secondarynamenode.service'
ssh "${ssh_opts[@]}" "$SSH_USER@team-01-00" 'sudo systemctl enable hdfs-datanode.service && sudo systemctl restart hdfs-datanode.service'
ssh "${ssh_opts[@]}" "$SSH_USER@team-01-01" 'sudo systemctl enable hdfs-datanode.service && sudo systemctl restart hdfs-datanode.service'

echo "HDFS services started"
