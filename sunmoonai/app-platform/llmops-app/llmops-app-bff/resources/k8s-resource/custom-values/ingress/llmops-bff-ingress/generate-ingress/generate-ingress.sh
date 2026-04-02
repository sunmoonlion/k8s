#!/bin/bash
# LLMOps App BFF Ingress YAML 生成脚本
# 根据配置生成 Ingress 的 YAML 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-ingress.conf"
# 计算 resources/k8s-resource 目录（模板文件所在位置）
# 从 generate-ingress/ -> llmops-bff-ingress/ -> ingress/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# 计算应用根目录（用于查找主应用的 deploy-*.conf）
# 从 generate-ingress/ -> llmops-bff-ingress/ -> ingress/ -> custom-values/ -> k8s-resource/ -> resources/ -> llmops-app-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

# 尝试读取主应用的 deploy-*.conf（作为基础配置的默认值源）
# 如果存在，则从中获取基础配置；否则使用 generate-*.conf 中的默认值
# 注意：只读取基础配置（NAMESPACE、ENVIRONMENT等），不读取部署控制参数
MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-llmops-bff/app/deploy-app/deploy-llmops-bff.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${LLMOPS_BFF_NAMESPACE:-}")
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
    log_info "跳过资源生成: ingress (已禁用)"
    exit 0
fi

# ============================================================================
# 设置环境变量（用于模板替换）
# 注意：所有配置都从 generate-ingress.conf 读取，不在脚本中设置硬编码默认值
# ============================================================================
# 基础配置（从 generate-ingress.conf 中读取，所有默认值在 conf 文件中定义）
export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

# Ingress 相关配置（从配置文件中读取）
export SERVICE_NAME="${SERVICE_NAME:-}"
export SERVICE_PORT="${SERVICE_PORT:-}"
export UNIFIED_HOST="${UNIFIED_HOST:-}"
export NODE_IP="${NODE_IP:-}"
export USE_STRIP_PREFIX="${USE_STRIP_PREFIX:-}"
export USE_RATE_LIMIT="${USE_RATE_LIMIT:-}"

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
    log_info "开始生成 LLMOps App BFF Ingress YAML 文件..."
    log_info "输出目录: $OUTPUT_DIR"
    
    # 解析模板路径
    local full_template_path
    if [[ "$TEMPLATE_FILE" = /* ]]; then
        full_template_path="$TEMPLATE_FILE"
    else
        full_template_path="$K8S_RESOURCE_DIR/$TEMPLATE_FILE"
    fi
    
    local full_output_path="$OUTPUT_DIR/$OUTPUT_FILE"
    
    # 检查模板文件
    if [ ! -f "$full_template_path" ]; then
        log_error "模板文件不存在: $full_template_path"
        exit 1
    fi
    
    log_info "生成 ingress: $OUTPUT_FILE"
    log_info "模板文件: $full_template_path"
    
        # 根据 USE_STRIP_PREFIX 和 USE_RATE_LIMIT 配置，动态生成 Ingress YAML
    # 如果 USE_STRIP_PREFIX=true，使用 stripprefix 中间件（在 ingress.yaml 中定义）
    # 如果 USE_STRIP_PREFIX=false 且 USE_RATE_LIMIT=true，使用限流中间件（需要单独部署）
    
    local temp_template=$(mktemp)
    cp "$full_template_path" "$temp_template"
    
    # 处理条件逻辑：根据 USE_STRIP_PREFIX 和 USE_RATE_LIMIT 决定使用哪个中间件
    if [[ "${USE_STRIP_PREFIX:-false}" == "true" ]]; then
        # 使用 stripprefix 中间件（在 ingress.yaml 中定义）
        # 移除限流中间件的条件块（如果存在）
        sed -i '/#IF_USE_RATE_LIMIT_START/,/#IF_USE_RATE_LIMIT_END/d' "$temp_template"
        # 确保 stripprefix 中间件块存在（移除条件标记）
        sed -i 's/#IF_USE_STRIP_PREFIX_START//g' "$temp_template"
        sed -i 's/#IF_USE_STRIP_PREFIX_END//g' "$temp_template"
    elif [[ "${USE_RATE_LIMIT:-true}" == "true" ]]; then
        # 使用限流中间件（需要单独部署）
        # 移除 stripprefix 中间件的条件块（如果存在）
        sed -i '/#IF_USE_STRIP_PREFIX_START/,/#IF_USE_STRIP_PREFIX_END/d' "$temp_template"
        # 确保限流中间件块存在（移除条件标记）
        sed -i 's/#IF_USE_RATE_LIMIT_START//g' "$temp_template"
        sed -i 's/#IF_USE_RATE_LIMIT_END//g' "$temp_template"
    else
        # 不使用任何中间件
        sed -i '/#IF_USE_STRIP_PREFIX_START/,/#IF_USE_STRIP_PREFIX_END/d' "$temp_template"
        sed -i '/#IF_USE_RATE_LIMIT_START/,/#IF_USE_RATE_LIMIT_END/d' "$temp_template"
    fi
    
    # 处理 ${VAR:-default} 语法，然后使用 envsubst
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$temp_template" | envsubst > "$full_output_path"
    
    rm -f "$temp_template"
    
    # 验证生成的 YAML
    if ! validate_yaml "$full_output_path"; then
        exit 1
    fi
    
    log_success "✅ ingress 生成完成: $OUTPUT_FILE"
    return 0
}

main "$@"
