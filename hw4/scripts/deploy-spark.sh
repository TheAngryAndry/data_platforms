#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
ssh_opts=(-F /dev/null -i "$HOME/.ssh/id_ed25519_mts_course" -o BatchMode=yes)
edge=team@171.22.72.148

tar -czf - README.md scripts sql data sales.py |
  ssh "${ssh_opts[@]}" "$edge" 'mkdir -p ~/data-platforms/hw4; tar -xzf - -C ~/data-platforms/hw4'
ssh "${ssh_opts[@]}" "$edge" \
  'cd ~/data-platforms/hw4 && sudo bash scripts/install-spark.sh && bash scripts/run-spark.sh'
