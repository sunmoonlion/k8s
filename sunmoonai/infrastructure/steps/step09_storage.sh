#!/usr/bin/env bash
# Shared storage adapter; cloud 未经实机验证. Default prints only.
# No delete/recreate, online fallback, automatic PVC/Pod probes or host mounts.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$STEP_DIR/../utils/cluster-step.sh"
cluster_step_main storage "$@"
