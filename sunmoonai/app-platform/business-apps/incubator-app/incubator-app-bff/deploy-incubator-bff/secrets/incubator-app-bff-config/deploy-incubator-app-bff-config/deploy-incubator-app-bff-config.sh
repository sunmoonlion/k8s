#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-incubator-app-bff-config.conf"
# 模板文件已移动到 resources/custom-values/templates/
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")"  # 从 deploy-xxx/ 到应用根目录
TEMPLATES_DIR="$PROJECT_ROOT/resources/custom-values/templates"
SECRETS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"  # secrets 目录（用于输出）
YAML_TEMPLATE="$TEMPLATES_DIR/configmap/incubator-app-bff-config.yaml"
YAML_OUTPUT="$SECRETS_DIR/incubator-app-bff-config/incubator-app-bff-config.yaml"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }

# 加载配置
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
  log_info "已加载配置: $CONFIG_FILE"
else
  log_warn "未找到配置文件: $CONFIG_FILE，使用默认配置"
fi

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 生成 YAML 文件
generate_yaml() {
  if [[ ! -f "$YAML_TEMPLATE" ]]; then
    log_error "缺少 YAML 模板: $YAML_TEMPLATE"
    exit 1
  fi

  log_info "根据配置生成 YAML 文件..."
  export PROJECT_ID NAMESPACE ENVIRONMENT \
         PROJECT_NAME SERVER_NAME SERVER_HOST SERVER_BOT \
         BACKEND_CORS_ORIGINS \
         POSTGRES_SERVER POSTGRES_PORT POSTGRES_USER POSTGRES_DB \
         NEO4J_SERVER NEO4J_PORT NEO4J_USERNAME NEO4J_AUTH NEO4J_BOLT \
         USERS_OPEN_REGISTRATION NEO4J_FORCE_TIMEZONE NEO4J_AUTO_INSTALL_LABELS \
         NEO4J_MAX_CONNECTION_POOL_SIZE MULTI_MAX \
         EMAIL_RESET_TOKEN_EXPIRE_HOURS EMAIL_TEMPLATES_DIR EMAIL_TEST_USER

  if ! command -v envsubst &>/dev/null; then
    log_error "envsubst 未安装，请安装 gettext-base"
    exit 1
  fi

  envsubst < "$YAML_TEMPLATE" > "$YAML_OUTPUT"
  log_success "YAML 文件已生成: $YAML_OUTPUT"
}

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"

  # 生成 YAML 文件
  generate_yaml

  # 部署或卸载
  case "$action" in
    deploy)
      kubectl apply -f "$YAML_OUTPUT" -n "$NAMESPACE"
      log_success "ConfigMap 部署完成"
      ;;
    uninstall)
      kubectl delete -f "$YAML_OUTPUT" -n "$NAMESPACE" --ignore-not-found
      log_success "ConfigMap 卸载完成"
      ;;
    generate)
      log_success "仅生成 YAML 文件，未部署"
      ;;
    *)
      log_error "无效操作: $action"
      echo "用法: $0 <deploy|uninstall|generate> [project_id] [namespace] [environment]"
      exit 1
      ;;
  esac
}

main "$@"
