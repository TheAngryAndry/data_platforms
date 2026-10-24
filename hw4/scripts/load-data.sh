#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
sudo install -d -o hive -g hive -m 0750 /var/lib/hive/import
sudo install -o hive -g hive -m 0640 data/sales-*.csv /var/lib/hive/import/
scripts/beeline.sh -f sql/sales.sql
