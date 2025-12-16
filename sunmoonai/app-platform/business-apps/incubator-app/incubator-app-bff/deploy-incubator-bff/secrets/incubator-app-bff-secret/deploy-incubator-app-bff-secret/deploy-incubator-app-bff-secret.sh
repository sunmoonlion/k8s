#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-incubator-app-bff-secret.conf"
SECRETS_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"  # secrets 目录
YAML_TEMPLATE="$SECRETS_DIR/incubator-app-bff-secret/incubator-app-bff-secret.yaml.template"
YAML_OUTPUT="$SECRETS_DIR/incubator-app-bff-secret/incubator-app-bff-secret.yaml"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

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

# 检查敏感配置
check_sensitive_config() {
  local warnings=0
  
  if [[ "${SECRET_KEY:-changeme}" == "changeme" ]]; then
    log_warn "⚠️  SECRET_KEY 仍使用默认值 'changeme'，请修改为安全的随机字符串"
    warnings=$((warnings + 1))
  fi
  
  if [[ "${TOTP_SECRET_KEY:-changeme}" == "changeme" ]]; then
    log_warn "⚠️  TOTP_SECRET_KEY 仍使用默认值 'changeme'，请修改为安全的随机字符串"
    warnings=$((warnings + 1))
  fi
  
  if [[ "${POSTGRES_PASSWORD:-changeme}" == "changeme" ]]; then
    log_warn "⚠️  POSTGRES_PASSWORD 仍使用默认值 'changeme'，请修改为实际密码"
    warnings=$((warnings + 1))
  fi
  
  if [[ "${NEO4J_PASSWORD:-changeme}" == "changeme" ]]; then
    log_warn "⚠️  NEO4J_PASSWORD 仍使用默认值 'changeme'，请修改为实际密码"
    warnings=$((warnings + 1))
  fi
  
  if [[ "${FIRST_SUPERUSER_PASSWORD:-changeme}" == "changeme" ]]; then
    log_warn "⚠️  FIRST_SUPERUSER_PASSWORD 仍使用默认值 'changeme'，请修改为实际密码"
    warnings=$((warnings + 1))
  fi
  
  if [[ $warnings -gt 0 ]]; then
    log_warn "发现 $warnings 个敏感配置仍使用默认值，建议在生产环境部署前修改"
  fi
}

# 生成 YAML 文件
generate_yaml() {
  if [[ ! -f "$YAML_TEMPLATE" ]]; then
    log_error "缺少 YAML 模板: $YAML_TEMPLATE"
    exit 1
  fi

  log_info "根据配置生成 YAML 文件..."
  export PROJECT_ID NAMESPACE ENVIRONMENT \
         SECRET_KEY TOTP_SECRET_KEY \
         POSTGRES_PASSWORD NEO4J_PASSWORD \
         FIRST_SUPERUSER FIRST_SUPERUSER_PASSWORD \
         SMTP_USER SMTP_PASSWORD SENTRY_DSN

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

  # 检查敏感配置
  check_sensitive_config

  # 生成 YAML 文件
  generate_yaml

  # 部署或卸载
  case "$action" in
    deploy)
      kubectl apply -f "$YAML_OUTPUT" -n "$NAMESPACE"
      log_success "Secret 部署完成"
      ;;
    undeploy)
      kubectl delete -f "$YAML_OUTPUT" -n "$NAMESPACE" --ignore-not-found
      log_success "Secret 卸载完成"
      ;;
    generate)
      log_success "仅生成 YAML 文件，未部署"
      ;;
    *)
      log_error "无效操作: $action"
      echo "用法: $0 <deploy|undeploy|generate> [project_id] [namespace] [environment]"
      exit 1
      ;;
  esac
}

main "$@"
