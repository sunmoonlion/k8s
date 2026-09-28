#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" deploy-project "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
# Component entry keeps its positional API and adjacent configuration.
# Authentication and Kubernetes operations are shared with local/cloud consumers.
# Cloud execution: 未经实机验证.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT_DIR="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
source "$K8S_ROOT_DIR/sunmoonai/registry-platform/lib/pull-secret.sh"
registry_secret_entry "$K8S_ROOT_DIR" "$SCRIPT_DIR/deploy-harbor-registry-secret.conf" \
    deploy-project data-platform-dev "$@"
