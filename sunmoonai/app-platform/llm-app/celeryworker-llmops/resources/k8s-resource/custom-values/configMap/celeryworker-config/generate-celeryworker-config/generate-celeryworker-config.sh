#!/bin/bash
# Celery Worker ConfigMap YAML 生成脚本
# 根据配置生成 ConfigMap 的 YAML 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-celeryworker-config.conf"
# 计算 resources/k8s-resource 目录（模板文件所在位置）
# 从 generate-celeryworker-config/ -> celeryworker-config/ -> configMap/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# 计算应用根目录（用于查找主应用的 deploy-*.conf）
# 从 generate-celeryworker-config/ -> celeryworker-config/ -> configMap/ -> custom-values/ -> k8s-resource/ -> resources/ -> celeryworker-llmops/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

# 尝试读取主应用的 deploy-*.conf（作为基础配置的默认值源）
# 如果存在，则从中获取基础配置；否则使用 generate-*.conf 中的默认值
# 注意：只读取基础配置（NAMESPACE、ENVIRONMENT等），不读取部署控制参数
MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-celeryworker-llmops/app/deploy-app/deploy-celeryworker-llmops.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    # 临时读取主配置，获取基础配置变量（不覆盖已存在的环境变量）
    # 使用 subshell 避免污染当前环境
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${CELERY_WORKER_NAMESPACE:-}")
    _temp_environment=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${ENVIRONMENT:-}")
    
    # 如果从主配置读取到了值，且环境变量未设置，则设置默认值
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
    log_info "跳过资源生成: configmap (已禁用)"
    exit 0
fi

# ============================================================================
# 设置环境变量（用于模板替换）
# 注意：所有配置都从 generate-celeryworker-config.conf 读取，不在脚本中设置硬编码默认值
# ============================================================================
# 基础配置（从 generate-celeryworker-config.conf 中读取，所有默认值在 conf 文件中定义）
export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

# ConfigMap 数据内容（从 generate-celeryworker-config.conf 中读取，所有默认值在 conf 文件中定义）
export CELERY_BROKER_URL="${CELERY_BROKER_URL:-}"
export CELERY_QUEUE="${CELERY_QUEUE:-}"
export CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-}"
export CELERY_CONCURRENCY="${CELERY_CONCURRENCY:-}"
export POSTGRES_SERVER="${POSTGRES_SERVER:-}"
export POSTGRES_PORT="${POSTGRES_PORT:-}"
export POSTGRES_USER="${POSTGRES_USER:-}"
export POSTGRES_DB="${POSTGRES_DB:-}"
export POSTGRES_URL_TEMPLATE="${POSTGRES_URL_TEMPLATE:-}"
export DB_SSLMODE="${DB_SSLMODE:-}"
export DB_HOST="${DB_HOST:-}"
export DB_PORT="${DB_PORT:-}"
export DB_NAME="${DB_NAME:-}"
export DB_USER="${DB_USER:-}"
export NEO4J_SERVER="${NEO4J_SERVER:-}"
export NEO4J_PORT="${NEO4J_PORT:-}"
export NEO4J_USERNAME="${NEO4J_USERNAME:-}"
export NEO4J_AUTH="${NEO4J_AUTH:-}"
export NEO4J_BOLT="${NEO4J_BOLT:-}"
export NEO4J_BOLT_URL_TEMPLATE="${NEO4J_BOLT_URL_TEMPLATE:-}"
export NEO4J_FORCE_TIMEZONE="${NEO4J_FORCE_TIMEZONE:-}"
export NEO4J_AUTO_INSTALL_LABELS="${NEO4J_AUTO_INSTALL_LABELS:-}"
export NEO4J_MAX_CONNECTION_POOL_SIZE="${NEO4J_MAX_CONNECTION_POOL_SIZE:-}"
export SMTP_HOST="${SMTP_HOST:-}"
export SMTP_PORT="${SMTP_PORT:-}"
export SMTP_TLS="${SMTP_TLS:-}"
export SMTP_SSL="${SMTP_SSL:-}"
export SMTP_FROM="${SMTP_FROM:-}"
export EMAILS_FROM_EMAIL="${EMAILS_FROM_EMAIL:-}"
export EMAILS_FROM_NAME="${EMAILS_FROM_NAME:-}"
export SMTP_TIMEOUT="${SMTP_TIMEOUT:-}"
export SENTRY_ENVIRONMENT="${SENTRY_ENVIRONMENT:-}"
export SENTRY_RELEASE="${SENTRY_RELEASE:-}"
export SENTRY_TRACES_SAMPLE_RATE="${SENTRY_TRACES_SAMPLE_RATE:-}"
export SENTRY_PROFILES_SAMPLE_RATE="${SENTRY_PROFILES_SAMPLE_RATE:-}"
export REDIS_HOST="${REDIS_HOST:-}"
export REDIS_PORT="${REDIS_PORT:-}"
export REDIS_DB="${REDIS_DB:-}"
export REDIS_USE_SSL="${REDIS_USE_SSL:-}"
export PYTHONPATH="${PYTHONPATH:-}"

# ============================================================================
# 生成 YAML 文件
# ============================================================================
log_info "开始生成 Celery Worker ConfigMap YAML 文件..."
log_info "输出目录: $OUTPUT_DIR"

# 解析模板路径
local full_template_path
if [[ "$TEMPLATE_FILE" = /* ]]; then
    # 绝对路径
    full_template_path="$TEMPLATE_FILE"
else
    # 相对路径（相对于 K8S_RESOURCE_DIR）
    full_template_path="$K8S_RESOURCE_DIR/$TEMPLATE_FILE"
fi

if [ ! -f "$full_template_path" ]; then
    log_error "模板文件不存在: $full_template_path"
    exit 1
fi

log_info "生成 configmap: $OUTPUT_FILE"
log_info "模板文件: $full_template_path"

# 处理模板文件（替换变量）
local full_output_path="$OUTPUT_DIR/$OUTPUT_FILE"

# 使用 sed 处理 ${VAR:-default} 格式，然后使用 envsubst 替换变量
sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"

if [ $? -eq 0 ]; then
    log_success "✅ configmap 生成完成: $OUTPUT_FILE"
    
    # 验证生成的 YAML（如果 kubectl 可用）
    if command -v kubectl &> /dev/null; then
        if kubectl apply --dry-run=client -f "$full_output_path" &> /dev/null; then
            log_success "YAML 验证通过: $(basename "$full_output_path")"
        else
            log_warn "YAML 验证失败: $(basename "$full_output_path")"
            kubectl apply --dry-run=client -f "$full_output_path" 2>&1 | head -20
        fi
    fi
else
    log_error "YAML 生成失败"
    exit 1
fi
