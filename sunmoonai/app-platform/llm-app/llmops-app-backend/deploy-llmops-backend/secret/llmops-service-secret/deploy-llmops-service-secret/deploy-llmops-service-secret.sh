#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-llmops-service-secret.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-llmops-service-secret/ 向上 3 级到达应用根目录
# deploy-llmops-service-secret/ -> llmops-service-secret/ -> secrets/ -> deploy-llmops-backend/ -> llmops-app-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
SECRET_YAML="$K8S_RESOURCE_DIR/custom-values/secret/llmops-service-secret/generate-llmops-service-secret/llmops-service-secret-generated.yaml"

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

# 检查敏感配置（从生成配置文件中读取）
check_sensitive_config() {
  local warnings=0
  local generate_config_file="$K8S_RESOURCE_DIR/custom-values/secret/llmops-service-secret/generate-llmops-service-secret/generate-llmops-service-secret.conf"
  
  # 如果生成配置文件存在，从中读取配置进行检查
  if [[ -f "$generate_config_file" ]]; then
    # 临时加载生成配置文件（不覆盖已存在的环境变量）
    local _temp_secret_key _temp_totp_secret_key _temp_postgres_password _temp_neo4j_password _temp_first_superuser_password
    
    _temp_secret_key=$(source "$generate_config_file" 2>/dev/null && echo "${SECRET_KEY:-changeme}")
    _temp_totp_secret_key=$(source "$generate_config_file" 2>/dev/null && echo "${TOTP_SECRET_KEY:-changeme}")
    _temp_postgres_password=$(source "$generate_config_file" 2>/dev/null && echo "${POSTGRES_PASSWORD:-changeme}")
    _temp_neo4j_password=$(source "$generate_config_file" 2>/dev/null && echo "${NEO4J_PASSWORD:-changeme}")
    _temp_first_superuser_password=$(source "$generate_config_file" 2>/dev/null && echo "${FIRST_SUPERUSER_PASSWORD:-changeme}")
    
    if [[ "$_temp_secret_key" == "changeme" ]]; then
      log_warn "⚠️  SECRET_KEY 仍使用默认值 'changeme'，请修改为安全的随机字符串（在生成配置文件中）"
      warnings=$((warnings + 1))
    fi
    
    if [[ "$_temp_totp_secret_key" == "changeme" ]]; then
      log_warn "⚠️  TOTP_SECRET_KEY 仍使用默认值 'changeme'，请修改为安全的随机字符串（在生成配置文件中）"
      warnings=$((warnings + 1))
    fi
    
    if [[ "$_temp_postgres_password" == "changeme" ]]; then
      log_warn "⚠️  POSTGRES_PASSWORD 仍使用默认值 'changeme'，请修改为实际密码（在生成配置文件中）"
      warnings=$((warnings + 1))
    fi
    
    if [[ "$_temp_neo4j_password" == "changeme" ]]; then
      log_warn "⚠️  NEO4J_PASSWORD 仍使用默认值 'changeme'，请修改为实际密码（在生成配置文件中）"
      warnings=$((warnings + 1))
    fi
    
    if [[ "$_temp_first_superuser_password" == "changeme" ]]; then
      log_warn "⚠️  FIRST_SUPERUSER_PASSWORD 仍使用默认值 'changeme'，请修改为实际密码（在生成配置文件中）"
      warnings=$((warnings + 1))
    fi
    
    unset _temp_secret_key _temp_totp_secret_key _temp_postgres_password _temp_neo4j_password _temp_first_superuser_password
  else
    log_warn "⚠️  生成配置文件不存在: $generate_config_file，跳过敏感配置检查"
  fi
  
  if [[ $warnings -gt 0 ]]; then
    log_warn "发现 $warnings 个敏感配置仍使用默认值，建议在生产环境部署前修改生成配置文件"
  fi
}

# 自动生成 YAML 文件的辅助函数
auto_generate_yaml() {
    local yaml_file="$1"
    local k8s_resource_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
        export NAMESPACE="${NAMESPACE:-app-platform-dev}"
        export ENVIRONMENT="${ENVIRONMENT:-development}"
        export ENV="${ENV:-dev}"
        export PROJECT_ID="${PROJECT_ID:-sunmoonai}"
        
        local generate_script="$k8s_resource_dir/custom-values/secret/llmops-service-secret/generate-llmops-service-secret/generate-llmops-service-secret.sh"
        if [ -f "$generate_script" ]; then
            if bash "$generate_script"; then
                log_success "YAML 文件生成成功"
            else
                log_error "YAML 文件生成失败"
                return 1
            fi
        else
            log_error "生成脚本不存在: $generate_script"
            return 1
        fi
    fi
    return 0
}

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"

  # 检查敏感配置
  check_sensitive_config

  # 1. 自动生成 YAML 文件（如果不存在）
  if ! auto_generate_yaml "$SECRET_YAML" "$K8S_RESOURCE_DIR"; then
    log_error "无法生成或找到 Secret YAML 文件"
    exit 1
  fi

  # 2. 部署或卸载
  case "$action" in
    deploy)
      kubectl apply -f "$SECRET_YAML" -n "$NAMESPACE"
      log_success "Secret 部署完成"
      ;;
    uninstall)
      kubectl delete -f "$SECRET_YAML" -n "$NAMESPACE" --ignore-not-found
      log_success "Secret 卸载完成"
      ;;
    status)
      log_info "检查 Secret 状态..."
      local secret_name="${LLMOPS_SERVICE_SECRET_NAME:-llmops-service-secret}"
      kubectl get secret "$secret_name" -n "$NAMESPACE" 2>/dev/null || log_warn "Secret 不存在: $secret_name"
      ;;
    generate)
      log_success "仅生成 YAML 文件，未部署"
      ;;
    *)
      log_error "无效操作: $action"
      echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
      exit 1
      ;;
  esac
}

main "$@"
