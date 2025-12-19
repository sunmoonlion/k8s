#!/bin/bash

# Document Converter Ingress 部署脚本

set -e

# 脚本目录（保存原始值，因为 unified-deployment-template.sh 会覆盖 SCRIPT_DIR）
ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# 计算应用根目录和资源路径（在 source 之前计算，避免 SCRIPT_DIR 被覆盖）
# 从 deploy-ingress/ -> ingress/ -> deploy-document-converter-bff/ -> document-converter-bff/
APP_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RESOURCES_DIR="${APP_ROOT}/resources"
CUSTOM_VALUES_DIR="${RESOURCES_DIR}/custom-values"

# 导入统一部署模板
source "$PROJECT_ROOT/../utils/unified-deployment-template.sh"

# 恢复原始的 SCRIPT_DIR
SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"

# Ingress 配置文件（使用生成的 YAML 文件）
INGRESS_FILE="${CUSTOM_VALUES_DIR}/document-converter-ingress-generated.yaml"

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
    
    # 自动生成 YAML 文件（如果不存在）
    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_warn "生成的 Ingress YAML 文件不存在，自动运行生成脚本..."
        if [[ -f "$CUSTOM_VALUES_DIR/generate.sh" ]]; then
            if bash "$CUSTOM_VALUES_DIR/generate.sh"; then
                log_success "YAML 文件生成成功"
            else
                log_error "YAML 文件生成失败"
                exit 1
            fi
        else
            log_error "生成脚本不存在: $CUSTOM_VALUES_DIR/generate.sh"
            exit 1
        fi
    fi
    
    if [[ ! -f "$INGRESS_FILE" ]]; then
        log_error "IngressRoute 配置文件不存在: $INGRESS_FILE"
        exit 1
    fi
    
    log_info "使用生成的 Ingress YAML: $INGRESS_FILE"
    
    # 直接使用生成的 YAML 文件（已经包含所有变量替换）
    kubectl apply -f "$INGRESS_FILE" -n "$NAMESPACE"
    
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

