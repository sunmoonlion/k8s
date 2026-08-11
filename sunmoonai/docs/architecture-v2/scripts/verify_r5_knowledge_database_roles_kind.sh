#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export RUNTIME_SECRET="${RUNTIME_SECRET:-knowledge-backend-postgresql-conn}"
export MIGRATION_SECRET="${MIGRATION_SECRET:-knowledge-backend-migration-postgresql-conn}"
export RUNTIME_ROLE="${RUNTIME_ROLE:-knowledge_backend_user}"
export MIGRATION_ROLE="${MIGRATION_ROLE:-knowledge_backend_user_migration}"
export LEGACY_OWNER_ROLE="${LEGACY_OWNER_ROLE:-knowledge_admin_user_migration}"
export DATABASE_NAME="${DATABASE_NAME:-knowledge_admin}"
export PROBE_TABLE="${PROBE_TABLE:-r5_knowledge_role_probe}"
export TASK_ID="${TASK_ID:-R5-K2}"
export MIN_TABLE_COUNT="${MIN_TABLE_COUNT:-5}"

exec "$SCRIPT_DIR/verify_r5_info_database_roles_kind.sh" "$@"
