#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  log_error "配置文件不存在: $CONFIG_FILE"
  exit 1
fi

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

check_namespace() {
  local ns="$1"
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    log_success "命名空间存在: $ns"
  else
    log_error "命名空间不存在: $ns"
    return 1
  fi
}

deploy_components() {
  local action="$1" project_id="$2" namespace="$3" environment="$4"

  local components=(
    "incubator_bff_secret:${incubator_bff_secret_enabled:-true}:${incubator_bff_secret_priority:-600}:BFF Secret:$SCRIPT_DIR/../incubator-app-bff-secret/deploy-incubator-app-bff-secret/deploy-incubator-app-bff-secret.sh"
    "incubator_bff_config:${incubator_bff_config_enabled:-true}:${incubator_bff_config_priority:-500}:BFF ConfigMap:$SCRIPT_DIR/../incubator-app-bff-config/deploy-incubator-app-bff-config/deploy-incubator-app-bff-config.sh"
  )

  local enabled=()
  for c in "${components[@]}"; do
    IFS=':' read -r name enabled_flag priority desc script <<< "$c"
    if [[ "$enabled_flag" == "true" ]]; then
      enabled+=("$c")
    else
      log_info "跳过组件(禁用): $desc"
    fi
  done

  IFS=$'\n' enabled=($(printf '%s\n' "${enabled[@]}" | sort -t: -k3 -nr))

  for c in "${enabled[@]}"; do
    IFS=':' read -r name enabled_flag priority desc script <<< "$c"
    log_info "部署组件: $desc (优先级 $priority)"
    if [[ -x "$script" ]]; then
      bash "$script" "$action" "$project_id" "$namespace" "$environment"
    else
      log_warn "脚本不可执行或不存在: $script"
    fi
  done
}

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  if [[ "$action" != "status" ]]; then
    check_namespace "$namespace" || exit 1
  fi

  deploy_components "$action" "$project_id" "$namespace" "$environment"
}

main "$@"

