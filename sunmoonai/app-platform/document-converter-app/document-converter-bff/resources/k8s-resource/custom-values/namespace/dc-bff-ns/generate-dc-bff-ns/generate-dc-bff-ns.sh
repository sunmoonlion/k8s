#!/bin/bash
# Document Converter BFF Namespace YAML 生成脚本
# 根据配置生成 Namespace 的 YAML 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-dc-bff-ns.conf"
# 计算 resources/k8s-resource 目录（模板文件所在位置）
# 从 generate-document-converter-bff-namespace/ -> document-converter-bff-namespace/ -> namespace/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# 计算应用根目录（用于查找主应用的 deploy-*.conf）
# 从 generate-document-converter-bff-namespace/ -> document-converter-bff-namespace/ -> namespace/ -> custom-values/ -> k8s-resource/ -> resources/ -> document-converter-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

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

# 尝试读取主应用的 deploy-*.conf（作为基础配置的默认值源）
# 如果存在，则从中获取基础配置；否则使用 generate-*.conf 中的默认值
# 注意：只读取基础配置（NAMESPACE、ENVIRONMENT等），不读取部署控制参数
MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-document-converter-bff/app/deploy-app/deploy-document-converter-bff.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${DOCUMENT_CONVERTER_BFF_NAMESPACE:-}")
    _temp_environment=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${ENVIRONMENT:-}")
    [ -n "$_temp_namespace" ] && [ -z "${NAMESPACE:-}" ] && export NAMESPACE="$_temp_namespace"
    [ -n "$_temp_environment" ] && [ -z "${ENVIRONMENT:-}" ] && export ENVIRONMENT="$_temp_environment"
    unset _temp_namespace _temp_environment
fi

# 检查是否启用
if [ "${ENABLED:-true}" != "true" ]; then
    log_info "跳过资源生成: namespace (已禁用)"
    exit 0
fi

# ============================================================================
# 设置环境变量（用于模板替换）
# 注意：所有配置都从 generate-document-converter-bff-namespace.conf 读取，不在脚本中设置硬编码默认值
# ============================================================================
# 基础配置（从 generate-document-converter-bff-namespace.conf 中读取，所有默认值在 conf 文件中定义）
export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

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
    log_info "开始生成 Document Converter BFF Namespace YAML 文件..."
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
    
    log_info "生成 namespace: $OUTPUT_FILE"
    log_info "模板文件: $full_template_path"
    
    # 处理 ${VAR:-default} 语法，然后使用 envsubst
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
    
    # 验证生成的 YAML
    if ! validate_yaml "$full_output_path"; then
        exit 1
    fi
    
    log_success "✅ namespace 生成完成: $OUTPUT_FILE"
    return 0
}

main "$@"

