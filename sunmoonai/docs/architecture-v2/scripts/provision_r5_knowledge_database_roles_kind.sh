#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export SOURCE_RUNTIME_SECRET="${SOURCE_RUNTIME_SECRET:-knowledge-admin-backend-postgresql-conn}"
export RUNTIME_SECRET="${RUNTIME_SECRET:-knowledge-backend-postgresql-conn}"
export MIGRATION_SECRET="${MIGRATION_SECRET:-knowledge-backend-migration-postgresql-conn}"
export RUNTIME_ROLE="${RUNTIME_ROLE:-knowledge_backend_user}"
export MIGRATION_ROLE="${MIGRATION_ROLE:-knowledge_backend_user_migration}"
export LEGACY_OWNER_ROLE="${LEGACY_OWNER_ROLE:-knowledge_admin_user_migration}"
export SERVICE_NAME="${SERVICE_NAME:-knowledge-backend}"
export TASK_ID="${TASK_ID:-R5-K2}"
export TASK_LABEL="${TASK_LABEL:-r5-knowledge}"
export APP_ID="${APP_ID:-knowledge}"
export TEMP_SECRET="${TEMP_SECRET:-r5-knowledge-role-provisioner}"

exec "$SCRIPT_DIR/provision_r5_info_database_roles_kind.sh" "$@"
