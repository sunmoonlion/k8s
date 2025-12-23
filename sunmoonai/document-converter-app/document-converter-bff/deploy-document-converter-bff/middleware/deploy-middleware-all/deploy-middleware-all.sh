#!/bin/bash

# Document Converter Middleware 部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 计算应用根目录（document-converter-app 目录）
# 从 deploy-middleware-all/ -> middleware/ -> deploy-document-converter-bff/ -> document-converter-bff/ -> document-converter-app/
APP_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# 项目根目录（sunmoonai 目录，用于访问 utils）
# 从 document-converter-app/ -> sunmoonai/
PROJECT_ROOT="$(cd "$APP_ROOT/.." && pwd)"

# 保存脚本目录
CONVERTER_MIDDLEWARE_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复脚本目录
SCRIPT_DIR="$CONVERTER_MIDDLEWARE_SCRIPT_DIR"

# 加载主配置文件
load_config() {
    local config_file="$APP_ROOT/deploy-document-converter-bff/app/deploy-app/deploy-document-converter-bff.conf"
    
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log_info "已加载主配置文件: $config_file"
    else
        log_warn "主配置文件不存在: $config_file，使用默认配置"
    fi
}

load_config

# 默认配置
NAMESPACE="${DOCUMENT_CONVERTER_NAMESPACE:-app-platform-dev}"

# 部署 Middleware
deploy_middleware() {
    log_info "部署 Document Converter StripPrefix Middleware..."
    
    local middleware_file="$APP_ROOT/deploy-document-converter-bff/middleware/document-converter-stripprefix.yaml"
    
    if [[ ! -f "$middleware_file" ]]; then
        log_error "Middleware 配置文件不存在: $middleware_file"
        exit 1
    fi
    
    # 替换命名空间
    local temp_file=$(mktemp)
    sed "s|namespace: app-platform-dev|namespace: $NAMESPACE|g" "$middleware_file" > "$temp_file"
    
    kubectl apply -f "$temp_file"
    rm -f "$temp_file"
    
    log_success "✅ Document Converter Middleware 部署完成"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "Document Converter Middleware 部署"
    log_info "=========================================="
    
    setup_kubectl_environment
    deploy_middleware
    
    log_success "✅ 所有 Middleware 部署完成！"
}

main

