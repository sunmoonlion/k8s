#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(dirname "$THIS_DIR")"
exec "$APP_ROOT/deploy-investment-app-all/deploy-investment-app-all.sh" "$@" --component backend-api
