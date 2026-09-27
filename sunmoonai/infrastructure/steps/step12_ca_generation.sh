#!/usr/bin/env bash
# Historical filename; consume signed ingress certificates, never generate CA.
# Cloud 未经实机验证. Default prints only; --verify never repairs Secrets.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$STEP_DIR/../utils/cluster-step.sh"
cluster_step_main certificates "$@"
