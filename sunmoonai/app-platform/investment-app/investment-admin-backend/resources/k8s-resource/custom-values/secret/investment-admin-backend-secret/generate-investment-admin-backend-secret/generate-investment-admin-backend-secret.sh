#!/bin/bash
# Investment Admin Backend Secret YAML 生成脚本
# 根据配置生成 Secret 的 YAML 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-investment-admin-backend-secret.conf"
# 计算 resources/k8s-resource 目录（模板文件所在位置）
# 从 generate-investment-admin-backend-secret/ -> investment-admin-backend-secret/ -> secret/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# 计算应用根目录（用于查找主应用的 deploy-*.conf）
# 从 generate-investment-admin-backend-secret/ -> investment-admin-backend-secret/ -> secret/ -> custom-values/ -> k8s-resource/ -> resources/ -> investment-admin-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

# 尝试读取主应用的 deploy-*.conf
MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-investment-admin-backend/app/deploy-app/deploy-investment-admin-backend.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${INVESTMENT_ADMIN_BACKEND_NAMESPACE:-}")
    _temp_environment=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${ENVIRONMENT:-}")
    [ -n "$_temp_namespace" ] && [ -z "${NAMESPACE:-}" ] && export NAMESPACE="$_temp_namespace"
    [ -n "$_temp_environment" ] && [ -z "${ENVIRONMENT:-}" ] && export ENVIRONMENT="$_temp_environment"
    unset _temp_namespace _temp_environment
fi

# 日志函数
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }

# 加载配置
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# 检查是否启用
if [ "${ENABLED:-true}" != "true" ]; then
    log_info "跳过资源生成: secret (已禁用)"
    exit 0
fi

# ============================================================================
# 设置环境变量（用于模板替换）
# ============================================================================
export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

export SECRET_KEY="${SECRET_KEY:-}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
export FIRST_SUPERUSER="${FIRST_SUPERUSER:-}"
export FIRST_SUPERUSER_PASSWORD="${FIRST_SUPERUSER_PASSWORD:-}"
export SMTP_USER="${SMTP_USER:-}"
export SMTP_PASSWORD="${SMTP_PASSWORD:-}"
export SENTRY_DSN="${SENTRY_DSN:-}"
export JWT_SECRET="${JWT_SECRET:-}"
export REDIS_PASSWORD="${REDIS_PASSWORD:-}"

# 尝试从 ConfigMap 配置读取非敏感信息（用于组装完整连接字符串）
CONFIGMAP_CONFIG_FILE="$K8S_RESOURCE_DIR/custom-values/configMap/investment-admin-backend-config/generate-investment-admin-backend-config/generate-investment-admin-backend-config.conf"
if [ -f "$CONFIGMAP_CONFIG_FILE" ]; then
    _temp_postgres_server=$(source "$CONFIGMAP_CONFIG_FILE" 2>/dev/null && echo "${POSTGRES_SERVER:-}")
    _temp_postgres_port=$(source "$CONFIGMAP_CONFIG_FILE" 2>/dev/null && echo "${POSTGRES_PORT:-}")
    _temp_postgres_user=$(source "$CONFIGMAP_CONFIG_FILE" 2>/dev/null && echo "${POSTGRES_USER:-}")
    _temp_postgres_db=$(source "$CONFIGMAP_CONFIG_FILE" 2>/dev/null && echo "${POSTGRES_DB:-}")

    [ -n "$_temp_postgres_server" ] && [ -z "${POSTGRES_SERVER:-}" ] && export POSTGRES_SERVER="$_temp_postgres_server"
    [ -n "$_temp_postgres_port" ] && [ -z "${POSTGRES_PORT:-}" ] && export POSTGRES_PORT="$_temp_postgres_port"
    [ -n "$_temp_postgres_user" ] && [ -z "${POSTGRES_USER:-}" ] && export POSTGRES_USER="$_temp_postgres_user"
    [ -n "$_temp_postgres_db" ] && [ -z "${POSTGRES_DB:-}" ] && export POSTGRES_DB="$_temp_postgres_db"

    unset _temp_postgres_server _temp_postgres_port _temp_postgres_user _temp_postgres_db
fi

# 组装完整连接字符串（如果未在配置中提供）
if [ -z "${DB_URL:-}" ] && [ -n "${POSTGRES_USER:-}" ] && [ -n "${POSTGRES_PASSWORD:-}" ] && [ -n "${POSTGRES_SERVER:-}" ] && [ -n "${POSTGRES_PORT:-}" ] && [ -n "${POSTGRES_DB:-}" ]; then
    export DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_SERVER}:${POSTGRES_PORT}/${POSTGRES_DB}"
fi

export DB_PASSWORD="${DB_PASSWORD:-${POSTGRES_PASSWORD:-}}"
export DB_URL="${DB_URL:-}"

# 验证 YAML 文件
validate_yaml() {
    local yaml_file="$1"

    if command -v kubectl &> /dev/null; then
        if kubectl apply --dry-run=client -f "$yaml_file" &> /dev/null; then
            log_success "YAML 验证通过: $(basename "$yaml_file")"
            return 0
        else
            log_error "YAML 验证失败: $(basename "$yaml_file")"
            kubectl apply --dry-run=client -f "$yaml_file" 2>&1 | head -20
            return 1
        fi
    else
        log_warn "kubectl 未安装，跳过 YAML 验证"
        return 0
    fi
}

# 生成 YAML
main() {
    log_info "开始生成 Investment Admin Backend Secret YAML 文件..."
    log_info "输出目录: $OUTPUT_DIR"

    local full_template_path
    if [[ "$TEMPLATE_FILE" = /* ]]; then
        full_template_path="$TEMPLATE_FILE"
    else
        full_template_path="$K8S_RESOURCE_DIR/$TEMPLATE_FILE"
    fi

    local full_output_path="$OUTPUT_DIR/$OUTPUT_FILE"

    if [ ! -f "$full_template_path" ]; then
        log_error "模板文件不存在: $full_template_path"
        exit 1
    fi

    log_info "生成 secret: $OUTPUT_FILE"
    log_info "模板文件: $full_template_path"

    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"

    if ! validate_yaml "$full_output_path"; then
        exit 1
    fi

    log_success "✅ secret 生成完成: $OUTPUT_FILE"
    return 0
}

main "$@"
