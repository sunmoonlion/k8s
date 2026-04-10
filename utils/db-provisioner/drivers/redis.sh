#!/usr/bin/env bash

redis_admin_auth_args() {
  # Newer redis-cli supports ACL login via --user. Older Windows builds (e.g. 3.x) do not.
  if redis-cli --help 2>&1 | grep -q -- '--user'; then
    printf -- '--user %s -a %s' "${REDIS_ADMIN_USER}" "${REDIS_ADMIN_PASSWORD}"
    return 0
  fi

  # Compatibility fallback: old redis-cli can still authenticate default user with password only.
  if [[ "${REDIS_ADMIN_USER}" == "default" ]]; then
    warn "redis-cli has no --user support, fallback to password-only admin auth for default user"
    printf -- '-a %s' "${REDIS_ADMIN_PASSWORD}"
    return 0
  fi

  die "redis-cli does not support --user and REDIS_ADMIN_USER is not default. Please install redis-cli >= 6."
}

redis_validate() {
  require_non_empty "DB_HOST" "${DB_HOST:-}"
  require_non_empty "DB_PORT" "${DB_PORT:-}"
  require_non_empty "REDIS_DB_INDEX" "${REDIS_DB_INDEX:-}"

  if bool_true "${REDIS_AUTH_ONLY:-false}"; then
    # Password-only auth (no ACL user management). Useful for apps that don't support Redis username.
    require_non_empty "REDIS_PASSWORD" "${REDIS_PASSWORD:-}"
    return 0
  fi

  require_non_empty "REDIS_ADMIN_USER" "${REDIS_ADMIN_USER:-}"
  require_non_empty "REDIS_ADMIN_PASSWORD" "${REDIS_ADMIN_PASSWORD:-}"
  require_non_empty "APP_DB_USER" "${APP_DB_USER:-}"
  require_non_empty "APP_DB_PASSWORD" "${APP_DB_PASSWORD:-}"
}

redis_provision() {
  if bool_true "${REDIS_AUTH_ONLY:-false}"; then
    log "Provision Redis (auth-only): db=${REDIS_DB_INDEX}"
    if bool_true "${DRY_RUN:-false}"; then
      log "DRY_RUN=true, skip executing redis-cli"
      return 0
    fi
    require_cmd "redis-cli"
    wait_k8s_pods_ready
    redis_precheck
    APP_DB_URI="redis://:${REDIS_PASSWORD}@${DB_HOST}:${DB_PORT}/${REDIS_DB_INDEX}"
    require_non_empty "APP_DB_URI(redis)" "${APP_DB_URI}"
    return 0
  fi

  local key_prefix="${REDIS_KEY_PREFIX:-${SERVICE_NAME:-app}:*}"
  local category="${REDIS_ACL_CATEGORY:-+@read +@write +@hash +@string +@list +@set +@sortedset}"

  log "Provision Redis ACL user: user=${APP_DB_USER}, db=${REDIS_DB_INDEX}, keyPrefix=${key_prefix}"
  if bool_true "${DRY_RUN:-false}"; then
    log "DRY_RUN=true, skip executing redis-cli"
    return 0
  fi

  require_cmd "redis-cli"
  wait_k8s_pods_ready
  redis_precheck

  local auth_args
  auth_args="$(redis_admin_auth_args)"
  # shellcheck disable=SC2086
  redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${auth_args} ACL SETUSER "${APP_DB_USER}" on ">${APP_DB_PASSWORD}" "~${key_prefix}" "${category}" -@dangerous >/dev/null
  log "[redis] ACL user upserted: ${APP_DB_USER}"

  APP_DB_URI="redis://${APP_DB_USER}:${APP_DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${REDIS_DB_INDEX}"
  require_non_empty "APP_DB_URI(redis)" "${APP_DB_URI}"
}

redis_deprovision() {
  if bool_true "${REDIS_AUTH_ONLY:-false}"; then
    log "Deprovision Redis (auth-only): nothing to do server-side"
    APP_DB_URI=""
    return 0
  fi

  log "Deprovision Redis ACL user: user=${APP_DB_USER}"
  if bool_true "${DRY_RUN:-false}"; then
    log "DRY_RUN=true, skip executing redis-cli"
    APP_DB_URI=""
    return 0
  fi

  require_cmd "redis-cli"
  wait_k8s_pods_ready
  redis_precheck
  local auth_args
  auth_args="$(redis_admin_auth_args)"
  # shellcheck disable=SC2086
  redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${auth_args} ACL DELUSER "${APP_DB_USER}" >/dev/null || true
  log "[redis] dropped ACL user if exists: ${APP_DB_USER}"
  if bool_true "${DEPROVISION_DROP_DATABASE:-false}"; then
    if bool_true "${REDIS_ALLOW_FLUSH_DB:-false}"; then
      # shellcheck disable=SC2086
      redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${auth_args} -n "${REDIS_DB_INDEX}" FLUSHDB ASYNC >/dev/null
      log "[redis] flushed db index: ${REDIS_DB_INDEX}"
    else
      warn "DEPROVISION_DROP_DATABASE=true but REDIS_ALLOW_FLUSH_DB!=true, skip FLUSHDB for safety"
    fi
  fi
  APP_DB_URI=""
}

redis_precheck() {
  local timeout="${DB_PRECHECK_TIMEOUT_SECONDS:-60}"
  local interval="${DB_PRECHECK_INTERVAL_SECONDS:-3}"

  if ! precheck_enabled; then
    log "Redis precheck disabled"
    return 0
  fi

  log "Redis precheck: waiting for readiness (timeout=${timeout}s, interval=${interval}s)"
  if bool_true "${REDIS_AUTH_ONLY:-false}"; then
    if wait_until "${timeout}" "${interval}" redis-cli -h "${DB_HOST}" -p "${DB_PORT}" -a "${REDIS_PASSWORD}" PING >/dev/null 2>&1; then
      log "Redis precheck passed"
      return 0
    fi
  else
    local auth_args
    auth_args="$(redis_admin_auth_args)"
    # shellcheck disable=SC2086
    if wait_until "${timeout}" "${interval}" redis-cli -h "${DB_HOST}" -p "${DB_PORT}" ${auth_args} PING >/dev/null 2>&1; then
      log "Redis precheck passed"
      return 0
    fi
  fi

  die "Redis precheck failed: service not ready or unreachable"
}
