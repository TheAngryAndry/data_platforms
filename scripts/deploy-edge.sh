#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
case ${1:-all} in
  all) bash scripts/deploy-hdfs-edge.sh; bash scripts/deploy-yarn-edge.sh ;;
  hdfs) bash scripts/deploy-hdfs-edge.sh ;;
  yarn) bash scripts/deploy-yarn-edge.sh ;;
  *) echo 'Usage: deploy-edge.sh [all|hdfs|yarn]' >&2; exit 1 ;;
esac
