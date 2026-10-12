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
expected='archive: -czf - cluster.conf config scripts systemd README.md nginx
bash ~/data-platforms/hw2/scripts/deploy-yarn-edge.sh
scripts/open-web.sh --check'
[[ $(cat "$trace") == "$expected" ]]
: > "$trace"
if command bash scripts/deploy.sh all; then exit 1; fi
[[ ! -s $trace ]]
if FAIL_DEPLOY=1 command bash scripts/deploy.sh; then exit 1; fi
if grep -q open-web "$trace"; then exit 1; fi

# No HDFS: stop before downloading, installing or changing anything.
ssh() { return 1; }
scp() { echo 'UNEXPECTED scp' >> "$trace"; return 1; }
sudo() { echo 'UNEXPECTED sudo' >> "$trace"; return 1; }
mkdir() { echo 'UNEXPECTED mkdir' >> "$trace"; return 1; }
export -f ssh scp sudo mkdir
: > "$trace"
if command bash scripts/deploy-yarn-edge.sh > "$trace" 2>&1; then exit 1; fi
grep -q 'Complete hw1 first' "$trace"
if grep -q UNEXPECTED "$trace"; then exit 1; fi
echo 'PASS: hw2 deployment isolation, argument validation and stop on failure'
