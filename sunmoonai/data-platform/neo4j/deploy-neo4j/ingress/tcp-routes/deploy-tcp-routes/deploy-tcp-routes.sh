#!/bin/bash


# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEO4J_TCP_FILE="$(dirname "$SCRIPT_DIR")/neo4j-tcp.yaml"

# 检查 yq 命令
check_yq_command() {
    if ! command -v yq &> /dev/null; then
        log_error "❌ yq 命令未找到，请先安装 yq"
        log_info "安装方法:"
        echo "  # Ubuntu/Debian"
        echo "  sudo apt-get install yq"
        echo ""
        echo "  # CentOS/RHEL"
        echo "  sudo yum install yq"
        echo ""
        echo "  # 或使用 snap"
        echo "  sudo snap install yq"
        echo ""
        echo "  # 或下载二进制文件"
        echo "  wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq"
        echo "  chmod +x /usr/local/bin/yq"
        return 1
    fi
    log_success "✅ yq 命令可用"
    return 0
}

# 获取服务配置
get_service_config() {
    local namespace="$1"
    
    # 获取 Neo4j 服务信息
    local service_name
    local service_port
    
    service_name=$(kubectl get svc -n "$namespace" -l app.kubernetes.io/name=neo4j -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    service_port=$(kubectl get svc -n "$namespace" -l app.kubernetes.io/name=neo4j -o jsonpath='{.items[0].spec.ports[0].port}' 2>/dev/null || echo "7687")
    
    if [[ -z "$service_name" ]]; then
        log_error "❌ 未找到 Neo4j 服务"
        return 1
    fi
    
    echo "$service_name:$service_port"
}

# 验证服务存在
verify_service_exists() {
    local namespace="$1"
    local service_name="$2"
    
    if kubectl get svc "$service_name" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ Neo4j 服务存在: $service_name"
        return 0
    else
        log_error "❌ Neo4j 服务不存在: $service_name"
        return 1
    fi
}

# 部署 Neo4j TCP 路由
deploy_neo4j_tcp() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 Neo4j TCP 路由..."
    log_info "命名空间: $namespace"
    
    # 检查 yq 命令
    if ! check_yq_command; then
        return 1
    fi
    
    # 获取服务配置
    local service_config
    service_config=$(get_service_config "$namespace")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local service_name="${service_config%:*}"
    local service_port="${service_config#*:}"
    
    # 验证服务存在
    if ! verify_service_exists "$namespace" "$service_name"; then
        return 1
    fi
    
    # 检查配置文件是否存在
    if [[ ! -f "$NEO4J_TCP_FILE" ]]; then
        log_error "Neo4j TCP 路由配置文件不存在: $NEO4J_TCP_FILE"
        return 1
    fi
    
    # 动态替换服务名称
    local temp_file
    temp_file=$(mktemp)
    
    log_info "动态配置 Neo4j TCP 路由..."
    log_info "服务名称: $service_name"
    log_info "服务端口: $service_port"
    
    # 使用 yq 替换服务名称
    yq eval ".spec.routes[0].services[0].name = \"$service_name\"" "$NEO4J_TCP_FILE" > "$temp_file"
    yq eval ".spec.routes[0].services[0].port = $service_port" "$temp_file" > "${temp_file}.final"
    
    # 应用 TCP 路由配置
    log_info "应用 Neo4j TCP 路由配置..."
    if kubectl apply -f "${temp_file}.final" -n "$namespace"; then
        log_success "✅ Neo4j TCP 路由配置应用成功"
    else
        log_error "❌ Neo4j TCP 路由配置应用失败"
        rm -f "$temp_file" "${temp_file}.final"
        return 1
    fi
    
    # 清理临时文件
    rm -f "$temp_file" "${temp_file}.final"
    
    # 检查路由状态
    log_info "检查 Neo4j TCP 路由状态..."
    kubectl get ingressroutetcp -n "$namespace" neo4j-tcp
    
    log_success "✅ Neo4j TCP 路由部署完成！"
    return 0
}

# 删除 Neo4j TCP 路由
delete_neo4j_tcp() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 Neo4j TCP 路由..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$NEO4J_TCP_FILE" 2>/dev/null; then
        log_success "✅ Neo4j TCP 路由配置删除成功"
    else
        log_warn "⚠️ Neo4j TCP 路由配置不存在或删除失败"
    fi
    
    log_success "✅ Neo4j TCP 路由删除完成！"
    return 0
}

# 检查路由状态
check_tcp_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Neo4j TCP 路由状态..."
    
    # 检查路由是否存在
    if kubectl get ingressroutetcp -n "$namespace" neo4j-tcp >/dev/null 2>&1; then
        log_success "✅ Neo4j TCP 路由存在"
        kubectl get ingressroutetcp -n "$namespace" neo4j-tcp
    else
        log_error "❌ Neo4j TCP 路由不存在"
        return 1
    fi
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS

parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        # 启用大小写不敏感匹配
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                # 支持等号形式：--cluster=C1 或 --CLUSTER=C1（大小写不敏感）
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                # 支持空格形式：--cluster C1 或 -c C1（大小写不敏感）
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        # 恢复大小写敏感匹配
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 主函数
main() {
    parse_cluster_arg "$@"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local namespace="${2:-data-platform-dev}"
    
    # 建立远程 k8s 连接
    setup_connection
    
    case "$action" in
        "deploy")
            deploy_neo4j_tcp "$namespace"
            ;;
        "uninstall")
            delete_neo4j_tcp "$namespace"
            ;;
        "status")
            check_tcp_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Neo4j TCP 路由（默认）"
            echo "  uninstall        删除 Neo4j TCP 路由"
            echo "  status           检查路由状态"
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

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        # 启用大小写不敏感匹配
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                # 支持等号形式：--cluster=C1 或 --CLUSTER=C1（大小写不敏感）
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                # 支持空格形式：--cluster C1 或 -c C1（大小写不敏感）
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        # 恢复大小写敏感匹配
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi


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
    
    case "$action" in
        "deploy")
            deploy_neo4j_tcp "$namespace"
            ;;
        "uninstall")
            delete_neo4j_tcp "$namespace"
            ;;
        "status")
            check_tcp_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Neo4j TCP 路由（默认）"
            echo "  uninstall        删除 Neo4j TCP 路由"
            echo "  status           检查路由状态"
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
