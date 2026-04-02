#!/bin/bash
# LLMOps App SSR Ingress YAML 生成脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-ingress.conf"
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
    log_info "跳过资源生成: ingress (已禁用)"
    exit 0
fi

export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"
export SERVICE_NAME="${SERVICE_NAME:-}"
export SERVICE_PORT="${SERVICE_PORT:-}"
export UNIFIED_HOST="${UNIFIED_HOST:-}"
export NODE_IP="${NODE_IP:-}"
export USE_STRIP_PREFIX="${USE_STRIP_PREFIX:-}"
export USE_RATE_LIMIT="${USE_RATE_LIMIT:-}"

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
    log_info "开始生成 LLMOps App SSR Ingress YAML 文件..."
    
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
    
    local temp_template=$(mktemp)
    cp "$full_template_path" "$temp_template"
    
    if [[ "${USE_STRIP_PREFIX:-false}" == "true" ]]; then
        sed -i '/#IF_USE_RATE_LIMIT_START/,/#IF_USE_RATE_LIMIT_END/d' "$temp_template"
        sed -i 's/#IF_USE_STRIP_PREFIX_START//g' "$temp_template"
        sed -i 's/#IF_USE_STRIP_PREFIX_END//g' "$temp_template"
    elif [[ "${USE_RATE_LIMIT:-true}" == "true" ]]; then
        sed -i '/#IF_USE_STRIP_PREFIX_START/,/#IF_USE_STRIP_PREFIX_END/d' "$temp_template"
        sed -i 's/#IF_USE_RATE_LIMIT_START//g' "$temp_template"
        sed -i 's/#IF_USE_RATE_LIMIT_END//g' "$temp_template"
    else
        sed -i '/#IF_USE_STRIP_PREFIX_START/,/#IF_USE_STRIP_PREFIX_END/d' "$temp_template"
        sed -i '/#IF_USE_RATE_LIMIT_START/,/#IF_USE_RATE_LIMIT_END/d' "$temp_template"
    fi
    
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$temp_template" | envsubst > "$full_output_path"
    rm -f "$temp_template"
    
    if ! validate_yaml "$full_output_path"; then
        exit 1
    fi
    
    log_success "✅ ingress 生成完成: $OUTPUT_FILE"
    return 0
}

main "$@"
