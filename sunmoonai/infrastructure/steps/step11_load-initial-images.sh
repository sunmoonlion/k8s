#!/usr/bin/env bash
# Cluster consumer of independent Harbor; 云上未经实机验证. Default prints only.
# Harbor installation, keys, data and lifecycle belong to registry-platform.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$STEP_DIR/../utils/cluster-step.sh"
cluster_step_main registry "$@"
