#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" deploy-project "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"

# Shared business Secret path; cloud execution: 未经实机验证.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
source "$PROJECT_ROOT/utils/secret-management/lib/opaque-deploy.sh"
opaque_secret_entry "$PROJECT_ROOT" "$SCRIPT_DIR/deploy-postgresql-auth-secret.conf" postgresql-auth-secret data-platform-dev "$@"
