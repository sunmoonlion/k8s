#!/usr/bin/env bash
# Local selected resource renderer. No cluster/network calls; cloud 未经实机验证.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../../../../../.." && pwd)"
source "$APP_ROOT/resources/config-resource.sh"
dc_render_resource "$APP_ROOT" PersistentVolumeClaim "$SCRIPT_DIR" document-converter-pvc "$@"
