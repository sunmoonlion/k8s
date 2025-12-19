#!/bin/bash
# Document Converter App BFF YAML 生成脚本
# 根据配置生成所有相关的 YAML 文件

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/generate.conf"
OUTPUT_DIR="${SCRIPT_DIR}"

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

# 加载部署配置（获取环境变量）
if [ -n "${DEPLOY_CONFIG:-}" ] && [ -f "$SCRIPT_DIR/$DEPLOY_CONFIG" ]; then
    source "$SCRIPT_DIR/$DEPLOY_CONFIG"
else
    log_warn "部署配置文件不存在或未配置: ${DEPLOY_CONFIG:-未设置}"
fi

# 设置默认环境变量
export NAMESPACE="${NAMESPACE:-${DOCUMENT_CONVERTER_NAMESPACE:-app-platform-dev}}"
export ENVIRONMENT="${ENVIRONMENT:-development}"
export ENV="${ENV:-dev}"

# 准备 Document Converter 相关的环境变量
export DOCUMENT_CONVERTER_IMAGE_REGISTRY="${DOCUMENT_CONVERTER_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
export DOCUMENT_CONVERTER_IMAGE_PROJECT="${DOCUMENT_CONVERTER_IMAGE_PROJECT:-k8s-images}"
export DOCUMENT_CONVERTER_IMAGE_NAME="${DOCUMENT_CONVERTER_IMAGE_NAME:-document-converter}"
export DOCUMENT_CONVERTER_IMAGE_TAG="${DOCUMENT_CONVERTER_IMAGE_TAG:-1.0}"
export DOCUMENT_CONVERTER_FULL_IMAGE="${DOCUMENT_CONVERTER_IMAGE_REGISTRY}/${DOCUMENT_CONVERTER_IMAGE_PROJECT}/${DOCUMENT_CONVERTER_IMAGE_NAME}:${DOCUMENT_CONVERTER_IMAGE_TAG}"
export DOCUMENT_CONVERTER_REPLICAS="${DOCUMENT_CONVERTER_REPLICAS:-2}"
export DOCUMENT_CONVERTER_CPU_REQUEST="${DOCUMENT_CONVERTER_CPU_REQUEST:-500m}"
export DOCUMENT_CONVERTER_CPU_LIMIT="${DOCUMENT_CONVERTER_CPU_LIMIT:-1000m}"
export DOCUMENT_CONVERTER_MEMORY_REQUEST="${DOCUMENT_CONVERTER_MEMORY_REQUEST:-512Mi}"
export DOCUMENT_CONVERTER_MEMORY_LIMIT="${DOCUMENT_CONVERTER_MEMORY_LIMIT:-1Gi}"
export DOCUMENT_CONVERTER_SERVICE_PORT="${DOCUMENT_CONVERTER_SERVICE_PORT:-8000}"
export DOCUMENT_CONVERTER_UNIFIED_HOST="${DOCUMENT_CONVERTER_UNIFIED_HOST:-www.sunmoonai.com}"

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

# 生成单个资源
generate_resource() {
    local resource_type="$1"
    local template_path="$2"
    local output_file="$3"
    local enabled="$4"
    
    if [ "$enabled" != "true" ]; then
        log_info "跳过资源生成: $resource_type (已禁用)"
        return 0
    fi
    
    # 解析路径（支持相对路径）
    local full_template_path
    if [[ "$template_path" = /* ]]; then
        full_template_path="$template_path"
    else
        full_template_path="$SCRIPT_DIR/$template_path"
    fi
    
    local full_output_path="$OUTPUT_DIR/$output_file"
    
    # 检查模板文件
    if [ ! -f "$full_template_path" ]; then
        log_error "模板文件不存在: $full_template_path"
        return 1
    fi
    
    log_info "生成 $resource_type: $output_file"
    
    # 根据资源类型选择不同的处理方式
    case "$resource_type" in
        app)
            # 主应用 YAML：处理 {{VAR}} 模板语法
            sed -e "s|{{NAMESPACE}}|${NAMESPACE}|g" \
                -e "s|{{IMAGE}}|${DOCUMENT_CONVERTER_FULL_IMAGE}|g" \
                -e "s|{{REPLICAS}}|${DOCUMENT_CONVERTER_REPLICAS}|g" \
                -e "s|{{CPU_REQUEST}}|${DOCUMENT_CONVERTER_CPU_REQUEST}|g" \
                -e "s|{{CPU_LIMIT}}|${DOCUMENT_CONVERTER_CPU_LIMIT}|g" \
                -e "s|{{MEMORY_REQUEST}}|${DOCUMENT_CONVERTER_MEMORY_REQUEST}|g" \
                -e "s|{{MEMORY_LIMIT}}|${DOCUMENT_CONVERTER_MEMORY_LIMIT}|g" \
                -e "s|{{SERVICE_PORT}}|${DOCUMENT_CONVERTER_SERVICE_PORT}|g" \
                "$full_template_path" > "$full_output_path"
            ;;
        configmap|secret)
            # ConfigMap 和 Secret：直接使用 envsubst
            envsubst < "$full_template_path" > "$full_output_path"
            ;;
        ingress|middleware)
            # Ingress 和 Middleware：处理 {{VAR}} 模板语法
            sed -e "s|{{NAMESPACE}}|${NAMESPACE}|g" \
                -e "s|{{UNIFIED_HOST}}|${DOCUMENT_CONVERTER_UNIFIED_HOST}|g" \
                "$full_template_path" > "$full_output_path"
            ;;
        *)
            log_warn "未知的资源类型: $resource_type，使用默认处理方式"
            envsubst < "$full_template_path" > "$full_output_path"
            ;;
    esac
    
    # 验证生成的 YAML
    if ! validate_yaml "$full_output_path"; then
        return 1
    fi
    
    log_success "✅ $resource_type 生成完成: $output_file"
    return 0
}

# 主函数
main() {
    log_info "开始生成 Document Converter App BFF YAML 文件..."
    log_info "输出目录: $OUTPUT_DIR"
    
    mkdir -p "$OUTPUT_DIR"
    
    # 检查是否有配置的资源列表
    if [ -z "${GENERATE_RESOURCES:-}" ] || [ ${#GENERATE_RESOURCES[@]} -eq 0 ]; then
        log_error "未配置需要生成的资源 (GENERATE_RESOURCES)"
        exit 1
    fi
    
    # 生成所有启用的资源
    local failed=0
    for resource_config in "${GENERATE_RESOURCES[@]}"; do
        IFS=':' read -r resource_type template_path output_file enabled <<< "$resource_config"
        
        if ! generate_resource "$resource_type" "$template_path" "$output_file" "$enabled"; then
            failed=1
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log_success "🎉 所有 YAML 文件生成完成！"
        return 0
    else
        log_error "❌ 部分 YAML 文件生成失败"
        return 1
    fi
}

main "$@"
