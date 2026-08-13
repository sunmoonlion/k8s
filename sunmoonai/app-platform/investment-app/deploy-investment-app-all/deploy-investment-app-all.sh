#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(dirname "$THIS_DIR")"
PLATFORM_ROOT="$(dirname "$APP_ROOT")"

exec python3 "$PLATFORM_ROOT/scripts/formal_deploy_entry.py" \
  --app-root "$APP_ROOT" \
  --config "$THIS_DIR/deploy-investment-app-all.conf" \
  "$@"
