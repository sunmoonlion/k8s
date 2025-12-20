#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../deploy-incubator-app-ssr-config.conf"
# 模板文件已移动到 resources/custom-values/templates/
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")"  # 从 deploy-xxx/ 到应用根目录
TEMPLATES_DIR="$PROJECT_ROOT/resources/custom-values/templates"
YAML_FILE="$TEMPLATES_DIR/configmap/incubator-app-ssr-config.yaml"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENV="$environment"

  [[ -f "$YAML_FILE" ]] || { log_error "缺少 ConfigMap 模板: $YAML_FILE"; exit 1; }

  tmp=$(mktemp)
  envsubst < "$YAML_FILE" > "$tmp"

  case "$action" in
    deploy)
      kubectl apply -f "$tmp" -n "$NAMESPACE"
      log_success "ConfigMap 部署完成"
      ;;
    uninstall)
      kubectl delete -f "$tmp" -n "$NAMESPACE" --ignore-not-found
      log_success "ConfigMap 卸载完成"
      ;;
    *)
      log_error "无效操作: $action"
      exit 1
      ;;
  esac

  rm -f "$tmp"
}

main "$@"

