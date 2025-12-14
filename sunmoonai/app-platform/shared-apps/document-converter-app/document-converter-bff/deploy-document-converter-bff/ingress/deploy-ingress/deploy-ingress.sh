#!/bin/bash

# Document Converter Ingress 部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# 保存脚本目录
CONVERTER_INGRESS_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复脚本目录
SCRIPT_DIR="$CONVERTER_INGRESS_SCRIPT_DIR"

# 加载主配置文件
load_config() {
    local config_file="$PROJECT_ROOT/sunmoonai/app-platform/shared-apps/document-converter-app/document-converter-bff/deploy-document-converter-bff/deploy-document-converter.conf"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log_info "已加载主配置文件: $config_file"
    else
        log_error "主配置文件不存在: $config_file"
        exit 1
    fi
}

load_config

# 默认配置
NAMESPACE="${DOCUMENT_CONVERTER_NAMESPACE:-app-platform-dev}"
SERVICE_NAME="document-converter"
SERVICE_PORT="${DOCUMENT_CONVERTER_SERVICE_PORT:-8000}"
UNIFIED_HOST="${DOCUMENT_CONVERTER_UNIFIED_HOST:-www.sunmoonai.com}"

# 部署 Ingress
deploy_ingress() {
    log_info "部署 Document Converter IngressRoute..."
    
    local ingress_file="$PROJECT_ROOT/sunmoonai/app-platform/shared-apps/document-converter-app/document-converter-bff/deploy-document-converter-bff/ingress/ingress.yaml"
    
    if [[ ! -f "$ingress_file" ]]; then
        log_error "IngressRoute 配置文件不存在: $ingress_file"
        exit 1
    fi
    
    # 替换模板变量
    local temp_file=$(mktemp)
    sed -e "s|{{NAMESPACE}}|$NAMESPACE|g" \
        -e "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" \
        -e "s|{{SERVICE_PORT}}|$SERVICE_PORT|g" \
        -e "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" \
        "$ingress_file" > "$temp_file"
    
    kubectl apply -f "$temp_file"
    rm -f "$temp_file"
    
    log_success "✅ Document Converter IngressRoute 部署完成"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "Document Converter Ingress 部署"
    log_info "=========================================="
    
    setup_kubectl_environment
    deploy_ingress
    
    log_success "✅ IngressRoute 部署完成！"
}

main

