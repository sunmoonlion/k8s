#!/usr/bin/env bash

pg_validate() {
  require_non_empty "APP_DB_NAME" "${APP_DB_NAME:-}"
  require_non_empty "APP_DB_USER" "${APP_DB_USER:-}"
  require_non_empty "APP_DB_PASSWORD" "${APP_DB_PASSWORD:-}"
  require_non_empty "DB_HOST" "${DB_HOST:-}"
  require_non_empty "DB_PORT" "${DB_PORT:-}"
  require_non_empty "PG_ADMIN_USER" "${PG_ADMIN_USER:-}"
  require_non_empty "PG_ADMIN_PASSWORD" "${PG_ADMIN_PASSWORD:-}"
}

pg_use_k8s_client() {
  [[ "${TARGET:-}" == "k8s" ]] && ! bool_true "${DBCTL_K8S_USE_LOCAL_CLIENT:-false}"
}

pg_client_namespace() {
  if [[ -n "${PG_CLIENT_NAMESPACE:-}" ]]; then
    printf '%s\n' "${PG_CLIENT_NAMESPACE}"
  elif [[ "${DB_HOST}" =~ \.([a-z0-9-]+)\.svc(\.|$) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "${K8S_PRECHECK_NAMESPACE:-${NAMESPACE:-default}}"
  fi
}

pg_client_image() {
  printf '%s\n' "${PG_CLIENT_IMAGE:-${POSTGRESQL_CLIENT_IMAGE:-harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4}}"
}

pg_run_k8s_client() {
  local ignored_pod_name="$1" script_content
  script_content="$(cat)"
  builtin printf '%s\0' "$script_content" "${PG_ADMIN_PASSWORD:-}" | \
    python3 -B "$ROOT_DIR/lib/client_pod.py" --namespace "$(pg_client_namespace)" \
      --image "$(pg_client_image)" --pull-secret "${PG_CLIENT_IMAGE_PULL_SECRET:-harbor-registry-secret}"
}

pg_provision() {
  log "Provision PostgreSQL: db=${APP_DB_NAME}, user=${APP_DB_USER}"
  if bool_true "${DRY_RUN:-false}"; then
    log "DRY_RUN=true, skip executing psql"
    return 0
  fi

  wait_k8s_pods_ready

  local admin_db="${PG_ADMIN_DB:-postgres}"
  local sslmode="${PG_SSLMODE:-prefer}"
  local db_exists role_exists

  if pg_use_k8s_client; then
    local pod_name="dbctl-pg-provision-${SERVICE_NAME:-app}-$(date +%s)"
    pg_run_k8s_client "${pod_name}" <<EOF
pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" >/dev/null

db_exists=\$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -tAc "SELECT 1 FROM pg_database WHERE datname='${APP_DB_NAME}'")
if [[ "\${db_exists}" != "1" ]]; then
  createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" "${APP_DB_NAME}"
  echo "[pg-client] created database: ${APP_DB_NAME}"
else
  echo "[pg-client] database already exists: ${APP_DB_NAME}"
fi

role_exists=\$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${APP_DB_USER}'")
if [[ "\${role_exists}" != "1" ]]; then
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<< "CREATE ROLE \"${APP_DB_USER}\" LOGIN PASSWORD '${APP_DB_PASSWORD}';"
  echo "[pg-client] created role: ${APP_DB_USER}"
else
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<< "ALTER ROLE \"${APP_DB_USER}\" WITH PASSWORD '${APP_DB_PASSWORD}';"
  echo "[pg-client] updated role password: ${APP_DB_USER}"
fi

psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<SQL
GRANT CONNECT ON DATABASE "${APP_DB_NAME}" TO "${APP_DB_USER}";
\c "${APP_DB_NAME}";
GRANT USAGE, CREATE ON SCHEMA public TO "${APP_DB_USER}";
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO "${APP_DB_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO "${APP_DB_USER}";
SQL
EOF
    APP_DB_URI="$(dbctl_connection_uri postgresql "$APP_DB_USER" "$APP_DB_PASSWORD" "$APP_DB_NAME" "$sslmode")"
    require_non_empty "APP_DB_URI(pg)" "${APP_DB_URI}"
    return 0
  fi

  require_cmd "psql"
  require_cmd "createdb"
  pg_precheck

  export PGPASSWORD="${PG_ADMIN_PASSWORD}"

  db_exists="$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -tAc "SELECT 1 FROM pg_database WHERE datname='${APP_DB_NAME}'")"
  if [[ "${db_exists}" != "1" ]]; then
    createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" "${APP_DB_NAME}"
    log "[pg] created database: ${APP_DB_NAME}"
  else
    log "[pg] database already exists: ${APP_DB_NAME}"
  fi

  role_exists="$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${APP_DB_USER}'")"
  if [[ "${role_exists}" != "1" ]]; then
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<< "CREATE ROLE \"${APP_DB_USER}\" LOGIN PASSWORD '${APP_DB_PASSWORD}';"
    log "[pg] created role: ${APP_DB_USER}"
  else
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<< "ALTER ROLE \"${APP_DB_USER}\" WITH PASSWORD '${APP_DB_PASSWORD}';"
    log "[pg] updated role password: ${APP_DB_USER}"
  fi

  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<EOF
GRANT CONNECT ON DATABASE "${APP_DB_NAME}" TO "${APP_DB_USER}";
\c "${APP_DB_NAME}";
GRANT USAGE, CREATE ON SCHEMA public TO "${APP_DB_USER}";
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO "${APP_DB_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO "${APP_DB_USER}";
EOF

  APP_DB_URI="$(dbctl_connection_uri postgresql "$APP_DB_USER" "$APP_DB_PASSWORD" "$APP_DB_NAME" "$sslmode")"
  require_non_empty "APP_DB_URI(pg)" "${APP_DB_URI}"
}

pg_deprovision_script() {
  local admin_db="${PG_ADMIN_DB:-postgres}"
  cat <<EOF
role_exists=\$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${APP_DB_USER}'")
db_exists=\$(psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -tAc "SELECT 1 FROM pg_database WHERE datname='${APP_DB_NAME}'")
if [[ "\${role_exists}" == 1 ]]; then
  if [[ "\${db_exists}" == 1 ]]; then
    # Database-local ownership/grants must be handled in the application DB.
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${APP_DB_NAME}" -v ON_ERROR_STOP=1 <<SQL
REASSIGN OWNED BY "${APP_DB_USER}" TO "${PG_ADMIN_USER}";
DROP OWNED BY "${APP_DB_USER}";
SQL
  fi
  # Fail rather than cascade if this role has dependencies in other databases.
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<SQL
DROP ROLE "${APP_DB_USER}";
SQL
fi
if [[ "${DEPROVISION_DROP_DATABASE:-false}" == true || "${DEPROVISION_DROP_DATABASE:-false}" == 1 ]]; then
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" -d "${admin_db}" -v ON_ERROR_STOP=1 <<SQL
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE datname='${APP_DB_NAME}' AND pid <> pg_backend_pid();
SQL
  dropdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" --if-exists "${APP_DB_NAME}"
fi
EOF
}

pg_deprovision() {
  wait_k8s_pods_ready
  if pg_use_k8s_client; then
    pg_deprovision_script | pg_run_k8s_client unused
  else
    require_cmd psql
    pg_precheck
    export PGPASSWORD="${PG_ADMIN_PASSWORD}"
    pg_deprovision_script | timeout 300s bash -se
  fi
  APP_DB_URI=""
}

pg_precheck() {
  local timeout="${DB_PRECHECK_TIMEOUT_SECONDS:-60}"
  local interval="${DB_PRECHECK_INTERVAL_SECONDS:-3}"

  if ! precheck_enabled; then
    log "PostgreSQL precheck disabled"
    return 0
  fi

  if pg_use_k8s_client; then
    return 0
  fi

  require_cmd "pg_isready"
  log "PostgreSQL precheck: waiting for readiness (timeout=${timeout}s, interval=${interval}s)"
  if wait_until "${timeout}" "${interval}" pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${PG_ADMIN_USER}" >/dev/null 2>&1; then
    log "PostgreSQL precheck passed"
    return 0
  fi

  die "PostgreSQL precheck failed: service not ready or unreachable"
}
