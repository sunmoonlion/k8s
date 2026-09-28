#!/usr/bin/env bash
# Compatibility entry: independent registry client. Default is a plan.
# See ../registry-platform/docs/clients.md; mutations require explicit --apply.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -B "$SCRIPT_DIR/../registry-platform/client.py" trust "$@"
