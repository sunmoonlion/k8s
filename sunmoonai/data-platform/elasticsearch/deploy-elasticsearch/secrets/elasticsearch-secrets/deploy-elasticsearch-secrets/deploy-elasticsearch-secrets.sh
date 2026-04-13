#!/bin/bash

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"




# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置
load_config() {
    if [[ ! -f "$ELASTICSEARCH_SECRETS_CONFIG_FILE" ]]; then
        log_error "Elasticsearch 密钥配置文件不存在: $ELASTICSEARCH_SECRETS_CONFIG_FILE"
        exit 1
    fi
    
    source "$ELASTICSEARCH_SECRETS_CONFIG_FILE"
    log_success "✅ Elasticsearch 密钥配置加载成功"
}

# 生成随机密码
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

# 部署 Elasticsearch 密钥
deploy_elasticsearch_secrets() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 Elasticsearch 密钥..."
    log_info "命名空间: $namespace"
    
    # 检查密钥是否已存在
    if kubectl get secret "$ELASTICSEARCH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Elasticsearch 密钥已存在: $ELASTICSEARCH_SECRET_NAME"
        return 0
    fi
    
    # 生成密码
    local elasticsearch_password
    local elasticsearch_username
    
    elasticsearch_password=$(generate_password 16)
    elasticsearch_username="elastic"
    
    log_info "生成 Elasticsearch 密钥..."
    
    # 创建密钥
    kubectl create secret generic "$ELASTICSEARCH_SECRET_NAME" \
        --namespace="$namespace" \
        --from-literal="$ELASTICSEARCH_AUTH_SECRET_PASSWORD_KEY"="$elasticsearch_password" \
        --from-literal="elasticsearch-username"="$elasticsearch_username"
    
    if [[ $? -eq 0 ]]; then
        log_success "✅ Elasticsearch 密钥创建成功: $ELASTICSEARCH_SECRET_NAME"
        log_info "Elasticsearch 用户名: $elasticsearch_username"
        log_info "Elasticsearch 密码: $elasticsearch_password"
    else
        log_error "❌ Elasticsearch 密钥创建失败"
        return 1
    fi
    
    return 0
}

# 删除 Elasticsearch 密钥
delete_elasticsearch_secrets() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 Elasticsearch 密钥..."
    log_info "命名空间: $namespace"
    
    if kubectl delete secret "$ELASTICSEARCH_SECRET_NAME" -n "$namespace" 2>/dev/null; then
        log_success "✅ Elasticsearch 密钥删除成功"
    else
        log_warn "⚠️ Elasticsearch 密钥不存在或删除失败"
    fi
    
    return 0
}

# 检查密钥状态
check_secrets_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Elasticsearch 密钥状态..."
    log_info "命名空间: $namespace"
    
    if kubectl get secret "$ELASTICSEARCH_SECRET_NAME" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Elasticsearch 密钥存在: $ELASTICSEARCH_SECRET_NAME"
        kubectl get secret "$ELASTICSEARCH_SECRET_NAME" -n "$namespace"
    else
        log_error "❌ Elasticsearch 密钥不存在: $ELASTICSEARCH_SECRET_NAME"
        return 1
    fi
    
    return 0
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local namespace="${2:-data-platform-dev}"
    
    # 建立远程 k8s 连接
    setup_connection
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_elasticsearch_secrets "$namespace"
            ;;
        "uninstall")
            delete_elasticsearch_secrets "$namespace"
            ;;
        "status")
            check_secrets_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Elasticsearch 密钥（默认）"
            echo "  uninstall        删除 Elasticsearch 密钥"
            echo "  status           检查密钥状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  namespace 命名空间（默认: data-platform-dev）"
            echo ""
            echo "示例:"
            echo "  $0 deploy"
            echo "  $0 deploy data-platform-dev"
            echo "  $0 uninstall"
            echo "  $0 status"
            exit 0
            ;;
        *)
            log_error "未知操作: $action"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
