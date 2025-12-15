#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

[[ -f "$CONFIG_FILE" ]] || { log_error "配置文件不存在: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

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
    "incubator_ssr_secret:${incubator_ssr_secret_enabled:-true}:${incubator_ssr_secret_priority:-600}:SSR Secret:$SCRIPT_DIR/../incubator-app-ssr-secret/deploy-incubator-app-ssr-secret/deploy-incubator-app-ssr-secret.sh"
    "incubator_ssr_config:${incubator_ssr_config_enabled:-true}:${incubator_ssr_config_priority:-500}:SSR ConfigMap:$SCRIPT_DIR/../incubator-app-ssr-config/deploy-incubator-app-ssr-config/deploy-incubator-app-ssr-config.sh"
  )

  local enabled=()
  for c in "${components[@]}"; do
    IFS=':' read -r name flag priority desc script <<< "$c"
    if [[ "$flag" == "true" ]]; then
      enabled+=("$c")
    else
      log_info "跳过组件(禁用): $desc"
    fi
  done

  IFS=$'\n' enabled=($(printf '%s\n' "${enabled[@]}" | sort -t: -k3 -nr))

  for c in "${enabled[@]}"; do
    IFS=':' read -r name flag priority desc script <<< "$c"
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

