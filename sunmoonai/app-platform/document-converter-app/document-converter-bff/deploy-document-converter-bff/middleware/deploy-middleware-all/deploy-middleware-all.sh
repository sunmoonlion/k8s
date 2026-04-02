#!/bin/bash

# Document Converter Middleware 部署脚本

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 计算应用根目录（document-converter-app 目录）
# 从 deploy-middleware-all/ -> middleware/ -> deploy-document-converter-bff/ -> document-converter-bff/ -> document-converter-app/
APP_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# 保存脚本目录
CONVERTER_MIDDLEWARE_SCRIPT_DIR="$SCRIPT_DIR"

# 导入统一部署模板
find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}
K8S_ROOT_DIR="$(find_k8s_root_dir "$APP_ROOT")"
if [[ -z "${K8S_ROOT_DIR:-}" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），APP_ROOT=$APP_ROOT" 1>&2
    exit 1
fi
source "$K8S_ROOT_DIR/utils/unified-deployment-template.sh"

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

