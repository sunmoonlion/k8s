#!/usr/bin/env bash
# Historical filename: Traefik only; Harbor runs outside clusters.
# Cloud 未经实机验证. Default prints only; --verify does not repair resources.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$STEP_DIR/../utils/cluster-step.sh"
cluster_step_main ingress "$@"
