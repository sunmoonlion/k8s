#!/usr/bin/env bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" named "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
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

PG_CONFIG="${PG_CONFIG:-${CONFIG_DIR}/postgresql.external.env}"
MONGO_CONFIG="${MONGO_CONFIG:-${CONFIG_DIR}/mongodb.external.env}"

log() {
  printf '[db-provision-template] %s\n' "$*"
}

die() {
  printf '[db-provision-template][error] %s\n' "$*" >&2
  exit 1
}

bool_true() {
  case "${1:-false}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  [[ -x "${DBCTL_BIN}" ]] || die "DBCTL_BIN not executable: ${DBCTL_BIN}"

  if bool_true "${ENABLE_POSTGRESQL:-false}" && [[ -f "${PG_CONFIG}" ]]; then
    "${DBCTL_BIN}" --config "${PG_CONFIG}" --target external --action deprovision
  fi

  if bool_true "${ENABLE_MONGODB:-false}" && [[ -f "${MONGO_CONFIG}" ]]; then
    "${DBCTL_BIN}" --config "${MONGO_CONFIG}" --target external --action deprovision
  fi

  if [[ -n "${OUT_ENV:-}" && -f "${OUT_ENV}" ]]; then
    rm -f "${OUT_ENV}"
    log "Removed env: ${OUT_ENV}"
  fi

  log "Deprovision complete"
}

main "$@"
