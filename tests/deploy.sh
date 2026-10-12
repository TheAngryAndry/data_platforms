#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

trace=$(mktemp)
trap 'rm -f "$trace"' EXIT
export trace

# Record deployment commands without connecting to or changing the cluster.
ssh() {
  local remote=${*: -1}
  if [[ $remote == 'mkdir -p '* ]]; then cat >/dev/null; return; fi
  printf '%s\n' "$remote" >> "$trace"
  [[ $remote != *"deploy-${FAIL_STAGE:-none}-edge.sh" ]]
}
tar() { :; }
bash() { printf '%s\n' "$*" >> "$trace"; }
export -f ssh tar bash

hdfs='bash ~/data-platforms/scripts/deploy-hdfs-edge.sh'
yarn='bash ~/data-platforms/scripts/deploy-yarn-edge.sh'
web='scripts/open-web.sh --check'
for stage in '' all hdfs yarn; do
  : > "$trace"
  if [[ -z $stage ]]; then command bash scripts/deploy.sh; else command bash scripts/deploy.sh "$stage"; fi
  case $stage in
    hdfs) expected=$hdfs ;;
    yarn) expected="$yarn"$'\n'"$web" ;;
    *) expected="$hdfs"$'\n'"$yarn"$'\n'"$web" ;;
  esac
  [[ $(cat "$trace") == "$expected" ]]
done

: > "$trace"
if command bash scripts/deploy.sh 'hdfs; exit 0'; then exit 1; fi
[[ ! -s $trace ]]
for stage in hdfs yarn; do
  : > "$trace"
  if FAIL_STAGE=$stage command bash scripts/deploy.sh; then exit 1; fi
  if grep -q open-web "$trace"; then exit 1; fi
  if [[ $stage == hdfs ]] && grep -q deploy-yarn "$trace"; then exit 1; fi
done
echo 'PASS: deploy stages, input validation and stop on failure'
