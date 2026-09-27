#!/usr/bin/env bash
# Compatibility entry: the deploy-kind script is the single implementation.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/../deploy-kind/check-storage-mounts.sh" "$@"
