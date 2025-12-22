#!/bin/bash
# LLMOps App SSR ConfigMap YAML 生成脚本
# 根据配置生成 ConfigMap 的 YAML 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-llmops-app-ssr-config.conf"
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-llmops-ssr/app/deploy-app/deploy-llmops-ssr.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${LLMOPS_SSR_NAMESPACE:-}")
    _temp_environment=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${ENVIRONMENT:-}")
    [ -n "$_temp_namespace" ] && [ -z "${NAMESPACE:-}" ] && export NAMESPACE="$_temp_namespace"
    [ -n "$_temp_environment" ] && [ -z "${ENVIRONMENT:-}" ] && export ENVIRONMENT="$_temp_environment"
    unset _temp_namespace _temp_environment
fi

log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

if [ "${ENABLED:-true}" != "true" ]; then
    log_info "跳过资源生成: configmap (已禁用)"
    exit 0
fi

export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"
export LLMOPS_SSR_CONFIGMAP_NAME="${LLMOPS_SSR_CONFIGMAP_NAME:-llmops-app-ssr-config}"
export PROJECT_NAME="${PROJECT_NAME:-}"
export SERVER_NAME="${SERVER_NAME:-}"
export SERVER_HOST="${SERVER_HOST:-}"
export SERVER_BOT="${SERVER_BOT:-}"
export BACKEND_CORS_ORIGINS="${BACKEND_CORS_ORIGINS:-}"
export POSTGRES_SERVER="${POSTGRES_SERVER:-}"
export POSTGRES_PORT="${POSTGRES_PORT:-}"
export POSTGRES_USER="${POSTGRES_USER:-}"
export POSTGRES_DB="${POSTGRES_DB:-}"
export NEO4J_SERVER="${NEO4J_SERVER:-}"
export NEO4J_PORT="${NEO4J_PORT:-}"
export NEO4J_USERNAME="${NEO4J_USERNAME:-}"
export NEO4J_AUTH="${NEO4J_AUTH:-}"
export NEO4J_BOLT="${NEO4J_BOLT:-}"
export USERS_OPEN_REGISTRATION="${USERS_OPEN_REGISTRATION:-}"
export NEO4J_FORCE_TIMEZONE="${NEO4J_FORCE_TIMEZONE:-}"
export NEO4J_AUTO_INSTALL_LABELS="${NEO4J_AUTO_INSTALL_LABELS:-}"
export NEO4J_MAX_CONNECTION_POOL_SIZE="${NEO4J_MAX_CONNECTION_POOL_SIZE:-}"
export MULTI_MAX="${MULTI_MAX:-}"
export EMAIL_RESET_TOKEN_EXPIRE_HOURS="${EMAIL_RESET_TOKEN_EXPIRE_HOURS:-}"
export EMAIL_TEMPLATES_DIR="${EMAIL_TEMPLATES_DIR:-}"
export EMAIL_TEST_USER="${EMAIL_TEST_USER:-}"

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

main() {
    log_info "开始生成 LLMOps App SSR ConfigMap YAML 文件..."
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
    
    log_info "生成 configmap: $OUTPUT_FILE"
    log_info "模板文件: $full_template_path"
    
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
    
    if ! validate_yaml "$full_output_path"; then
        exit 1
    fi
    
    log_success "✅ configmap 生成完成: $OUTPUT_FILE"
    return 0
}

main "$@"
