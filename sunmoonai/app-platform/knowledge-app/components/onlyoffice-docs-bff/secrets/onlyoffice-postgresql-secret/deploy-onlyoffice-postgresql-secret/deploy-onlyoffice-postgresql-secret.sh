#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" action "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
# Component configuration remains adjacent; lifecycle is shared by the four Opaque Secrets.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
K8S_ROOT_DIR="$(cd "$SCRIPT_DIR/../../../../../../../.." && pwd)"
source "$APP_ROOT/secrets/secret-entry.sh"
onlyoffice_secret_entry "$K8S_ROOT_DIR" "$APP_ROOT" "$SCRIPT_DIR/deploy-onlyoffice-postgresql-secret.conf" \
    onlyoffice-postgresql-secret-generated.yaml POSTGRESQL_PASSWORD "$@"
