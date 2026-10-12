#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
trace=$(mktemp)
trap 'rm -f "$trace"' EXIT
export trace

# Exercise the real entrypoint without changing the cluster.
ssh() {
  local remote=${*: -1}
  if [[ $remote == 'mkdir -p '* ]]; then cat >/dev/null; return; fi
  printf '%s\n' "$remote" >> "$trace"
  [[ ${FAIL_DEPLOY:-0} != 1 ]]
}
tar() { printf 'archive: %s\n' "$*" >> "$trace"; }
bash() { printf '%s\n' "$*" >> "$trace"; }
export -f ssh tar bash

command bash scripts/deploy.sh
expected='archive: -czf - cluster.conf config scripts systemd README.md
bash ~/data-platforms/hw1/scripts/deploy-hdfs-edge.sh'
[[ $(cat "$trace") == "$expected" ]]
: > "$trace"
if command bash scripts/deploy.sh all; then exit 1; fi
[[ ! -s $trace ]]
if FAIL_DEPLOY=1 command bash scripts/deploy.sh; then exit 1; fi
if grep -q open-web "$trace"; then exit 1; fi
echo 'PASS: hw1 deployment isolation, argument validation and stop on failure'
