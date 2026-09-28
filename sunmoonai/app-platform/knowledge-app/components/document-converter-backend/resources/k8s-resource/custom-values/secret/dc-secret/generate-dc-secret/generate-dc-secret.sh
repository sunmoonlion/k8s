#!/usr/bin/env bash
# Local selected Secret renderer. No cluster or network access.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"
source "$APP_ROOT/resources/config-resource.sh"
dc_render_resource "$APP_ROOT" Secret "$SCRIPT_DIR" document-converter-secret "$@"
