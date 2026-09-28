#!/usr/bin/env bash
k8s_write_output() {
  local ns="${OUTPUT_NAMESPACE:-default}"
  local secret_name="${OUTPUT_SECRET_NAME:-${SERVICE_NAME:-service}-${DB_ENGINE}-conn}"
  if [[ "${ACTION:-provision}" == deprovision ]]; then
    python3 -B "$PROVISIONER_K8S_ROOT/utils/secret-management/lib/opaque_secret.py" \
      --action uninstall --namespace "$ns" --name "$secret_name" --apply
    return
  fi
  local env_prefix="${OUTPUT_ENV_PREFIX:-}"
  local -a pairs=(SERVICE_NAME "${SERVICE_NAME:-}" ENVIRONMENT "${ENVIRONMENT:-}"
    DB_ENGINE "$DB_ENGINE" DB_HOST "${DB_HOST:-}" DB_PORT "${DB_PORT:-}"
    APP_DB_NAME "${APP_DB_NAME:-}" APP_DB_USER "${APP_DB_USER:-}"
    APP_DB_PASSWORD "${APP_DB_PASSWORD:-${REDIS_PASSWORD:-}}" APP_DB_URI "${APP_DB_URI:-}")
  if [[ -n "$env_prefix" ]]; then
    pairs+=("${env_prefix}_HOST" "${DB_HOST:-}" "${env_prefix}_PORT" "${DB_PORT:-}"
      "${env_prefix}_DB" "${REDIS_DB_INDEX:-${APP_DB_NAME:-}}"
      "${env_prefix}_USERNAME" "${APP_DB_USER:-}" "${env_prefix}_PASSWORD" "${APP_DB_PASSWORD:-${REDIS_PASSWORD:-}}"
      "${env_prefix}_URI" "${APP_DB_URI:-}")
    [[ -z "${QUEUE_REDIS_PREFIX:-}" ]] || pairs+=("${env_prefix}_PREFIX" "$QUEUE_REDIS_PREFIX")
  fi
  builtin printf '%s\0' "${pairs[@]}" | provisioner_secret --namespace "$ns" --name "$secret_name" --allow-empty-values
}
