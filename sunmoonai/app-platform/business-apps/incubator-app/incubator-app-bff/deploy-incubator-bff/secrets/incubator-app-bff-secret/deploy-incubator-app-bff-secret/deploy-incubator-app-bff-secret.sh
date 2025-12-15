#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../deploy-incubator-app-bff-secret.conf"
YAML_FILE="$SCRIPT_DIR/../../incubator-app-bff-secret.yaml"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENV="$environment"

  if [[ ! -f "$YAML_FILE" ]]; then
    log_error "缺少 Secret 模板: $YAML_FILE"
    exit 1
  fi

  tmp=$(mktemp)
  envsubst < "$YAML_FILE" > "$tmp"

  case "$action" in
    deploy)
      kubectl apply -f "$tmp" -n "$NAMESPACE"
      log_success "Secret 部署完成"
      ;;
    undeploy)
      kubectl delete -f "$tmp" -n "$NAMESPACE" --ignore-not-found
      log_success "Secret 卸载完成"
      ;;
    *)
      log_error "无效操作: $action"
      exit 1
      ;;
  esac

  rm -f "$tmp"
}

main "$@"

