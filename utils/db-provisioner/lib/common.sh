#!/usr/bin/env bash

set -euo pipefail

readonly DBP_VERSION="0.1.0"

log() {
  printf '[db-provisioner] %s\n' "$*"
}

warn() {
  printf '[db-provisioner][warn] %s\n' "$*" >&2
}

err() {
  printf '[db-provisioner][error] %s\n' "$*" >&2
}

die() {
  err "$*"
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing command: $cmd"
}

require_non_empty() {
  local key="$1"
  local val="${2:-}"
  [[ -n "$val" ]] || die "Required config is empty: $key"
}

load_env_file() {
  local env_file="$1"
  [[ -f "$env_file" ]] || die "Config file not found: $env_file"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

bool_true() {
  local v
  v="$(lower "${1:-false}")"
  [[ "$v" == "1" || "$v" == "true" || "$v" == "yes" || "$v" == "on" ]]
}

bool_false() {
  ! bool_true "${1:-false}"
}

now_rfc3339() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

redact() {
  local s="${1:-}"
  local n=${#s}
  if (( n <= 4 )); then
    printf '****'
  else
    printf '%s****%s' "${s:0:2}" "${s:n-2:2}"
  fi
}

precheck_enabled() {
  bool_false "${DB_PRECHECK_ENABLED:-true}" && return 1
  return 0
}

wait_until() {
  local timeout="${1:-60}"
  local interval="${2:-3}"
  shift 2
  local start now
  start="$(date +%s)"

  while true; do
    if "$@"; then
      return 0
    fi
    now="$(date +%s)"
    if (( now - start >= timeout )); then
      return 1
    fi
    sleep "${interval}"
  done
}

k8s_precheck_enabled() {
  bool_true "${K8S_PRECHECK_ENABLED:-false}"
}

wait_k8s_pods_ready() {
  local timeout="${K8S_PRECHECK_TIMEOUT_SECONDS:-120}"
  local interval="${K8S_PRECHECK_INTERVAL_SECONDS:-3}"
  local ns="${K8S_PRECHECK_NAMESPACE:-default}"
  local selector="${K8S_PRECHECK_LABEL_SELECTOR:-}"

  if ! k8s_precheck_enabled; then
    return 0
  fi

  require_cmd "${SUNMOON_KUBECTL:?Explicit target required}"
  require_non_empty "K8S_PRECHECK_LABEL_SELECTOR" "${selector}"

  log "K8s precheck: waiting pods ready (ns=${ns}, selector=${selector}, timeout=${timeout}s)"
  if wait_until "${timeout}" "${interval}" provisioner_kube -n "${ns}" wait --for=condition=Ready pod -l "${selector}" --timeout=5s >/dev/null 2>&1; then
    log "K8s precheck passed"
    return 0
  fi

  err "K8s precheck failed. Pods status:"
  provisioner_kube -n "${ns}" get pods -l "${selector}" -o wide || true
  die "K8s pod readiness precheck failed"
}

# K8s Pod 名称单段最长 63 字符；格式: dbctl-<role>-<service>-<timestamp>
dbctl_k8s_client_pod_name() {
  local role="$1"
  local service="${2:-app}"
  local ts suffix prefix max_len

  ts="$(date +%s)"
  suffix="-${ts}"
  prefix="dbctl-${role}-"
  max_len=$((63 - ${#prefix} - ${#suffix}))
  if ((${#service} > max_len)); then
    service="${service:0:max_len}"
  fi
  printf '%s%s%s' "$prefix" "$service" "$suffix"
}

# Existing drivers render shell/SQL text. Refuse unsupported interpolation input
# rather than silently rewrite a password or execute config data as code.
dbctl_validate_interpolation() {
  local key value
  for key in APP_DB_NAME APP_DB_USER PG_ADMIN_USER PG_ADMIN_DB REDIS_ADMIN_USER MONGO_ADMIN_USER MONGO_AUTH_DB SERVICE_NAME; do
    value="${!key:-}"
    [[ -z "$value" || "$value" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]{0,62}$ ]] || die "Unsupported identifier: $key"
  done
  for key in APP_DB_PASSWORD PG_ADMIN_PASSWORD REDIS_PASSWORD REDIS_ADMIN_PASSWORD MONGO_ADMIN_PASSWORD DB_HOST REDIS_KEY_PREFIX REDIS_KEY_PREFIX_SEP REDIS_CHANNEL_PREFIX REDIS_ACL_CATEGORY; do
    value="${!key:-}"
    case "$value" in
      *"'"*|*'"'*|*'`'*|*'$'*|*'\'*|*$'\n'*|*$'\r'*) die "Unsupported interpolation characters: $key" ;;
    esac
  done
  case "${DB_ENGINE:-}" in
    postgresql|postgres|pg) [[ "${APP_DB_USER:-}" != "${PG_ADMIN_USER:-}" ]] || die 'Application role must differ from PostgreSQL administrator' ;;
    mongodb) [[ "${APP_DB_USER:-}" != "${MONGO_ADMIN_USER:-}" ]] || die 'Application user must differ from MongoDB administrator' ;;
    redis) if ! bool_true "${REDIS_AUTH_ONLY:-false}"; then
      [[ "${APP_DB_USER:-}" != default && "${APP_DB_USER:-}" != "${REDIS_ADMIN_USER:-}" ]] || die 'Application ACL must differ from Redis administrator/default'
    fi ;;
  esac
  [[ "${DB_HOST:-}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || die 'DB_HOST must be a DNS name or IPv4 address'
  for key in DB_PRECHECK_TIMEOUT_SECONDS K8S_PRECHECK_TIMEOUT_SECONDS; do
    value="${!key:-60}"
    [[ "$value" =~ ^[1-9][0-9]{0,2}$ && "$value" -le 300 ]] || die "Invalid timeout: $key"
  done
  [[ "${DB_PORT:-}" =~ ^[1-9][0-9]{0,4}$ && "$DB_PORT" -le 65535 ]] || die 'Invalid DB_PORT'
  if [[ "${DB_ENGINE:-}" == redis ]]; then
    [[ "${REDIS_DB_INDEX:-}" =~ ^[0-9]{1,5}$ ]] || die 'Invalid REDIS_DB_INDEX'
  fi
}

dbctl_connection_uri() {
  builtin printf '%s\0' "$1" "$2" "$3" "$DB_HOST" "$DB_PORT" "$4" "${5:-}" | python3 -B -c '
import sys
from urllib.parse import quote
scheme,user,password,host,port,database,mode,tail=sys.stdin.buffer.read().decode().split("\0")
if tail:raise SystemExit("Invalid URI data")
q=lambda v:quote(v,safe="")
print(scheme+"://"+q(user)+":"+q(password)+"@"+host+":"+port+"/"+q(database)+("?sslmode="+q(mode) if mode else ""))'
}
