#!/bin/bash
# Incubator App SSR YAML 生成脚本
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

# 加载 Secret 配置（用于生成 Secret YAML，如果存在）
SECRET_CONFIG="../../deploy-incubator-ssr/secrets/incubator-app-ssr-secret/deploy-incubator-app-ssr-secret/deploy-incubator-app-ssr-secret.conf"
if [ -f "$SCRIPT_DIR/$SECRET_CONFIG" ]; then
    source "$SCRIPT_DIR/$SECRET_CONFIG"
    log_info "已加载 Secret 配置文件: $SECRET_CONFIG"
    # SSR Secret 通常为空，但保留加载逻辑以保持一致性
fi

# 设置默认环境变量
export NAMESPACE="${NAMESPACE:-${INCUBATOR_SSR_NAMESPACE:-app-platform-dev}}"
export ENVIRONMENT="${ENVIRONMENT:-development}"
export ENV="${ENV:-dev}"

# 准备 Incubator App SSR 相关的环境变量
export INCUBATOR_SSR_IMAGE_REGISTRY="${INCUBATOR_SSR_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}"
export INCUBATOR_SSR_IMAGE_PROJECT="${INCUBATOR_SSR_IMAGE_PROJECT:-k8s-images}"
export INCUBATOR_SSR_IMAGE="${INCUBATOR_SSR_IMAGE:-incubator-app-ssr}"
export INCUBATOR_SSR_TAG="${INCUBATOR_SSR_TAG:-1.0.0}"
export INCUBATOR_SSR_FULL_IMAGE_NAME="${INCUBATOR_SSR_IMAGE_REGISTRY}/${INCUBATOR_SSR_IMAGE_PROJECT}/${INCUBATOR_SSR_IMAGE}:${INCUBATOR_SSR_TAG}"
export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-Always}"
export INCUBATOR_SSR_IMAGE_PULL_SECRET_NAME="${INCUBATOR_SSR_IMAGE_PULL_SECRET_NAME:-harbor-registry-secret}"
export INCUBATOR_SSR_UNIFIED_HOST="${INCUBATOR_SSR_UNIFIED_HOST:-incubator-ssr.sunmoonai.com}"
export INCUBATOR_SSR_NODE_IP="${INCUBATOR_SSR_NODE_IP:-101.126.151.0}"
export INCUBATOR_SSR_EXTERNAL_PORT="${INCUBATOR_SSR_EXTERNAL_PORT:-30443}"

# Harbor Docker 认证配置（用于 harbor-registry-secret）
HARBOR_DOCKER_SERVER="${HARBOR_DOCKER_SERVER:-${INCUBATOR_SSR_IMAGE_REGISTRY:-harbor.sunmoonai.com:30443}}"
HARBOR_DOCKER_USERNAME="${HARBOR_DOCKER_USERNAME:-admin}"
HARBOR_DOCKER_PASSWORD="${HARBOR_DOCKER_PASSWORD:-Harbor@12345}"
# 生成 base64 编码的 Docker config JSON
HARBOR_AUTH_STRING=$(echo -n "${HARBOR_DOCKER_USERNAME}:${HARBOR_DOCKER_PASSWORD}" | base64 -w 0)
HARBOR_DOCKER_CONFIG_JSON=$(echo -n "{\"auths\":{\"${HARBOR_DOCKER_SERVER}\":{\"username\":\"${HARBOR_DOCKER_USERNAME}\",\"password\":\"${HARBOR_DOCKER_PASSWORD}\",\"auth\":\"${HARBOR_AUTH_STRING}\"}}}" | base64 -w 0)
export HARBOR_DOCKER_CONFIG_JSON

# Ingress 相关变量（用于模板替换）
export SERVICE_NAME="${SERVICE_NAME:-incubator-app-ssr}"
export SERVICE_PORT="${SERVICE_PORT:-3000}"
export UNIFIED_HOST="${UNIFIED_HOST:-${INCUBATOR_SSR_UNIFIED_HOST}}"
export NODE_IP="${NODE_IP:-${INCUBATOR_SSR_NODE_IP}}"

# PVC 相关变量（用于模板替换，从部署配置文件中读取）
# 注意：这些变量的默认值在 deploy-incubator-ssr.conf 中配置
export PVC_NAME="${PVC_NAME:-incubator-app-ssr-pvc}"
export PVC_MOUNT_PATH="${PVC_MOUNT_PATH:-/app/data}"
export PVC_SUB_PATH="${PVC_SUB_PATH:-}"
export PVC_STORAGE_CLASS="${PVC_STORAGE_CLASS:-}"
export PVC_ACCESS_MODE="${PVC_ACCESS_MODE:-ReadWriteOnce}"
export PVC_STORAGE_SIZE="${PVC_STORAGE_SIZE:-10Gi}"

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
            # 主应用 YAML：需要处理 ${VAR:-default} 语法
            sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
            ;;
        configmap|secret|pvc)
            # ConfigMap、Secret 和 PVC：先处理 ${VAR:-default}，然后使用 envsubst
            sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
            ;;
        ingress|middleware)
            # Ingress 和 Middleware：处理可能的 {{VAR}} 和 ${VAR} 两种格式
            sed -e 's/{{\([^}]*\)}}/${\1}/g' -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
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
    log_info "开始生成 Incubator App SSR YAML 文件..."
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
