#!/usr/bin/env bash
# Locked offline adapter; 云上未经实机验证. Default: print only.
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BASE_DIR/../utils/node-step.sh"
node_step_main runtime STEP02 "$@"
