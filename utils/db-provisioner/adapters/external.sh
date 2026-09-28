#!/usr/bin/env bash
external_write_output() {
  [[ "${OUTPUT_ENV_FILE:-}" == /* ]] || die 'Explicit absolute OUTPUT_ENV_FILE required'
  builtin printf '%s\0' SERVICE_NAME "${SERVICE_NAME:-}" ENVIRONMENT "${ENVIRONMENT:-}" \
    DB_ENGINE "$DB_ENGINE" DB_HOST "${DB_HOST:-}" DB_PORT "${DB_PORT:-}" \
    APP_DB_NAME "${APP_DB_NAME:-}" APP_DB_USER "${APP_DB_USER:-}" \
    APP_DB_PASSWORD "${APP_DB_PASSWORD:-${REDIS_PASSWORD:-}}" APP_DB_URI "${APP_DB_URI:-}" | \
    python3 -B "$ROOT_DIR/lib/private_output.py" "$ACTION" "$OUTPUT_ENV_FILE"
}
