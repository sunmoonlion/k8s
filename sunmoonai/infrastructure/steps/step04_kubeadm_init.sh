#!/usr/bin/env bash
# Locked kubeadm cluster adapter; 云上未经实机验证. Default: print only.
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BASE_DIR/../utils/cluster-step.sh"
cluster_step_main init "$@"
