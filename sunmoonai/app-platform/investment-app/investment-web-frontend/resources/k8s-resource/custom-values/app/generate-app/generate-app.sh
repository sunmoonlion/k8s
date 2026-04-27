#!/bin/bash
# Investment Web Frontend YAML 生成脚本
# 根据配置生成应用的 YAML 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-app.conf"
# 计算 resources/k8s-resource 目录（模板文件所在位置）
# 从 generate-app/ -> app/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# 计算应用根目录（用于查找主应用的 deploy-*.conf）
# 从 generate-app/ -> app/ -> custom-values/ -> k8s-resource/ -> resources/ -> investment-web-frontend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

# 尝试读取主应用的 deploy-*.conf（作为基础配置的默认值源）
MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-investment-web-frontend/app/deploy-app/deploy-investment-web-frontend.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${INVESTMENT_WEB_FRONTEND_NAMESPACE:-}")
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
    log_info "跳过资源生成: app (已禁用)"
    exit 0
fi

# ============================================================================
# 设置环境变量（用于模板替换）
# ============================================================================
export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

export INVESTMENT_WEB_FRONTEND_IMAGE_REGISTRY="${INVESTMENT_WEB_FRONTEND_IMAGE_REGISTRY:-}"
export INVESTMENT_WEB_FRONTEND_IMAGE_PROJECT="${INVESTMENT_WEB_FRONTEND_IMAGE_PROJECT:-}"
export INVESTMENT_WEB_FRONTEND_IMAGE="${INVESTMENT_WEB_FRONTEND_IMAGE:-}"
export INVESTMENT_WEB_FRONTEND_TAG="${INVESTMENT_WEB_FRONTEND_TAG:-}"
export INVESTMENT_WEB_FRONTEND_FULL_IMAGE_NAME="${INVESTMENT_WEB_FRONTEND_IMAGE_REGISTRY}/${INVESTMENT_WEB_FRONTEND_IMAGE_PROJECT}/${INVESTMENT_WEB_FRONTEND_IMAGE}:${INVESTMENT_WEB_FRONTEND_TAG}"
export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-}"
export INVESTMENT_WEB_FRONTEND_IMAGE_PULL_SECRET_NAME="${INVESTMENT_WEB_FRONTEND_IMAGE_PULL_SECRET_NAME:-}"
export INVESTMENT_WEB_FRONTEND_SECRET_NAME="${INVESTMENT_WEB_FRONTEND_SECRET_NAME:-}"
export INVESTMENT_WEB_FRONTEND_CONFIGMAP_NAME="${INVESTMENT_WEB_FRONTEND_CONFIGMAP_NAME:-}"

export PVC_NAME="${PVC_NAME:-}"
export PVC_MOUNT_PATH="${PVC_MOUNT_PATH:-}"
export PVC_SUB_PATH="${PVC_SUB_PATH:-}"

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
    log_info "开始生成 Investment Web Frontend YAML 文件..."
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

    log_info "生成 app: $OUTPUT_FILE"
    log_info "模板文件: $full_template_path"

    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"

    if ! validate_yaml "$full_output_path"; then
        exit 1
    fi

    log_success "✅ app 生成完成: $OUTPUT_FILE"
    return 0
}

main "$@"
