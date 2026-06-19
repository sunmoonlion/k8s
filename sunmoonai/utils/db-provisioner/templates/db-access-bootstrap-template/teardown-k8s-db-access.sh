#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"

source_common_env_preserving_callers() {
  local env_file="$1"
  local -A caller_values=()
  local var

  for var in ENABLE_POSTGRESQL ENABLE_REDIS ENABLE_NODEBULL_REDIS ENABLE_MONGODB; do
    if [[ ${!var+x} ]]; then
      caller_values["$var"]="${!var}"
    fi
  done

  # shellcheck disable=SC1090
  source "$env_file"

  for var in "${!caller_values[@]}"; do
    export "$var=${caller_values[$var]}"
  done
}

source_common_env_preserving_callers "${CONFIG_DIR}/common.env"

PG_CONFIG="${PG_K8S_CONFIG:-${CONFIG_DIR}/postgresql.k8s.env}"
REDIS_CONFIG="${REDIS_K8S_CONFIG:-${CONFIG_DIR}/redis.k8s.env}"
NODEBULL_REDIS_CONFIG="${NODEBULL_REDIS_K8S_CONFIG:-${CONFIG_DIR}/nodebull-redis.k8s.env}"
MONGO_CONFIG="${MONGO_K8S_CONFIG:-${CONFIG_DIR}/mongodb.k8s.env}"

log() { printf '[db-access-bootstrap][k8s] %s\n' "$*"; }
die() { printf '[db-access-bootstrap][k8s][error] %s\n' "$*" >&2; exit 1; }

bool_true() {
  case "${1:-false}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac
}

require_file() { [[ -f "$1" ]] || die "Missing file: $1"; }

main() {
  [[ -x "${DBCTL_BIN}" ]] || die "DBCTL_BIN not executable: ${DBCTL_BIN}"
  command -v kubectl >/dev/null 2>&1 || die "Missing kubectl"

  bool_true "${ENABLE_POSTGRESQL:-false}" && [[ -f "${PG_CONFIG}" ]] && "${DBCTL_BIN}" --config "${PG_CONFIG}" --target k8s --action deprovision
  bool_true "${ENABLE_MONGODB:-false}" && [[ -f "${MONGO_CONFIG}" ]] && "${DBCTL_BIN}" --config "${MONGO_CONFIG}" --target k8s --action deprovision
  bool_true "${ENABLE_REDIS:-false}" && [[ -f "${REDIS_CONFIG}" ]] && "${DBCTL_BIN}" --config "${REDIS_CONFIG}" --target k8s --action deprovision
  bool_true "${ENABLE_NODEBULL_REDIS:-false}" && [[ -f "${NODEBULL_REDIS_CONFIG}" ]] && "${DBCTL_BIN}" --config "${NODEBULL_REDIS_CONFIG}" --target k8s --action deprovision

  log "Done. k8s secrets removed (and users deprovisioned where supported)."
}

main "$@"
