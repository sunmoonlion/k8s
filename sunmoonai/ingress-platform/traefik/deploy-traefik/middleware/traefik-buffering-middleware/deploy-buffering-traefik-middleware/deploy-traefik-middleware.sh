#!/bin/bash

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
BUFFERING_MIDDLEWARE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
K8S_ROOT="$(cd "$BUFFERING_MIDDLEWARE_SCRIPT_DIR/../../../../../../.." && pwd)"

# 导入统一部署模板（提供日志函数和 Kubernetes 连接函数）
source "$K8S_ROOT/utils/unified-deployment-template.sh"

# 恢复缓冲中间件脚本的目录路径
SCRIPT_DIR="$BUFFERING_MIDDLEWARE_SCRIPT_DIR"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载缓冲中间件配置文件
BUFFERING_MIDDLEWARE_CONFIG_FILE="$SCRIPT_DIR/deploybuffering-traefik-middleware.conf"
if [[ -f "$BUFFERING_MIDDLEWARE_CONFIG_FILE" ]]; then
    source "$BUFFERING_MIDDLEWARE_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载缓冲中间件配置文件: $BUFFERING_MIDDLEWARE_CONFIG_FILE"
else
    log_warn "缓冲中间件配置文件不存在: $BUFFERING_MIDDLEWARE_CONFIG_FILE，使用默认配置"
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ingress-platform-dev"
DEFAULT_ENVIRONMENT="development"
# 2GB = 2147483648 字节，用于支持大镜像文件上传
DEFAULT_MAX_REQUEST="2147483648"
DEFAULT_MAX_RESPONSE="2147483648"
# 20MB = 20971520 字节，超过此大小会写入磁盘
DEFAULT_MEM_REQUEST="20971520"
DEFAULT_MEM_RESPONSE="20971520"
DEFAULT_RETRY_EXPRESSION="IsNetworkError() && Attempts() <= 2"

# 检查命名空间是否存在（若不存在则自动创建）
check_namespace() {
    local namespace="$1"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    fi
    
    log_warn "⚠️  命名空间 $namespace 不存在，尝试自动创建..."
    if kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -; then
        log_success "✅ 已自动创建命名空间: $namespace"
        return 0
    fi
    
    log_error "❌ 命名空间 $namespace 不存在，且自动创建失败！"
    return 1
}

# 部署缓冲中间件
deploy_buffering_middleware() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署 Traefik 缓冲中间件..."
    log_info "项目: $project_id"
    log_info "命名空间: $namespace"
    log_info "环境: $environment"
    log_info "干运行: $dry_run"
    
    # 检查命名空间是否存在
    check_namespace "$namespace"
    
    # 静态 YAML 文件路径
    local yaml_file="$SCRIPT_DIR/../traefik-buffering-middleware.yaml"
    
    if [[ ! -f "$yaml_file" ]]; then
        log_error "❌ 静态 YAML 文件不存在: $yaml_file"
        return 1
    fi
    
    log_info "使用静态 YAML 文件: $yaml_file"
    
    # 读取配置参数
    local max_request="${MIDDLEWARE_BUFFERING_MAX_REQUEST:-$DEFAULT_MAX_REQUEST}"
    local max_response="${MIDDLEWARE_BUFFERING_MAX_RESPONSE:-$DEFAULT_MAX_RESPONSE}"
    local mem_request="${MIDDLEWARE_BUFFERING_MEM_REQUEST:-$DEFAULT_MEM_REQUEST}"
    local mem_response="${MIDDLEWARE_BUFFERING_MEM_RESPONSE:-$DEFAULT_MEM_RESPONSE}"
    local retry_expression="${MIDDLEWARE_BUFFERING_RETRY_EXPRESSION:-$DEFAULT_RETRY_EXPRESSION}"
    
    # 创建临时文件，替换变量
    local temp_file=$(mktemp)
    
    # 使用 sed 替换变量（envsubst 不支持 ${VAR:-default} 语法）
    # 注意：需要转义特殊字符，特别是 retryExpression 中的 && 和括号
    # 先替换带默认值的变量，再替换不带默认值的变量
    # 转义 retry_expression 中的特殊字符用于 sed（转义 &、|、() 等）
    local retry_expression_escaped=$(printf '%s\n' "$retry_expression" | sed 's/[&|()]/\\&/g')
    
    sed -e "s|\${MAX_REQUEST_BODY_BYTES:-2147483648}|$max_request|g" \
        -e "s|\${MEM_REQUEST_BODY_BYTES:-20971520}|$mem_request|g" \
        -e "s|\${MAX_RESPONSE_BODY_BYTES:-2147483648}|$max_response|g" \
        -e "s|\${MEM_RESPONSE_BODY_BYTES:-20971520}|$mem_response|g" \
        -e "s|\${RETRY_EXPRESSION:-IsNetworkError() && Attempts() <= 2}|$retry_expression_escaped|g" \
        -e "s/\${PROJECT_ID}/$project_id/g" \
        -e "s/\${NAMESPACE}/$namespace/g" \
        "$yaml_file" > "$temp_file"
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "执行干运行部署..."
        kubectl apply -f "$temp_file" --dry-run=client
        log_success "✅ 缓冲中间件干运行部署成功！"
    else
        log_info "执行实际部署..."
        if kubectl apply -f "$temp_file"; then
            log_success "✅ 缓冲中间件部署成功！"
        else
            log_error "❌ 缓冲中间件部署失败！"
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
    
    return 0
}

# 检查缓冲中间件状态
check_buffering_middleware_status() {
    local project_id="$1"
    local namespace="$2"
    
    log_info "检查缓冲中间件状态..."
    
    # 检查中间件是否存在
    if kubectl get middleware "traefik-buffering-${project_id}" -n "$namespace" >/dev/null 2>&1; then
        log_success "✅ 缓冲中间件存在"
        
        # 显示中间件详情
        log_info "中间件详情："
        kubectl get middleware "traefik-buffering-${project_id}" -n "$namespace" -o yaml | grep -A 15 "spec:"
        
        return 0
    else
        log_error "❌ 缓冲中间件不存在"
        return 1
    fi
}

# 获取缓冲中间件日志
get_buffering_middleware_logs() {
    local project_id="$1"
    local namespace="$2"
    local tail_lines="${3:-50}"
    
    log_info "获取缓冲中间件日志（最近 $tail_lines 行）..."
    
    # 中间件本身不产生日志，但我们可以检查相关的事件
    log_info "检查缓冲中间件相关事件："
    kubectl get events -n "$namespace" --field-selector involvedObject.name="traefik-buffering-${project_id}" --sort-by='.lastTimestamp' | tail -n "$tail_lines"
    
    return 0
}

# 卸载缓冲中间件
uninstall_buffering_middleware() {
    local project_id="$1"
    local namespace="$2"
    
    log_info "卸载缓冲中间件..."
    
    # 检查是否已安装
    if ! kubectl get middleware "traefik-buffering-${project_id}" -n "$namespace" >/dev/null 2>&1; then
        log_warn "缓冲中间件未安装或已卸载"
        return 0
    fi
    
    # 执行卸载
    if kubectl delete middleware "traefik-buffering-${project_id}" -n "$namespace"; then
        log_success "✅ 缓冲中间件卸载成功！"
        return 0
    else
        log_error "❌ 缓冲中间件卸载失败！"
        return 1
    fi
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
    
    local action="${1:-}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"
    
    # 如果没有提供参数，默认执行完整流程
    if [[ -z "$action" ]]; then
        log_info "未指定命令，执行完整部署流程"
        action="deploy"
    fi
    
    # 读取 Kubernetes 配置文件
    if ! read_k8s_config; then
        log_error "无法读取 Kubernetes 配置文件"
        return 1
    fi
    
    # 设置 Kubernetes 环境（建立远程连接）
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    case "$action" in
        "deploy")
            if deploy_buffering_middleware "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_info "缓冲中间件部署信息:"
                log_info "项目: $project_id"
                log_info "命名空间: $namespace"
                log_info "中间件名称: traefik-buffering-${project_id}"
                log_info ""
                log_info "检查部署状态:"
                log_info "kubectl get middleware traefik-buffering-${project_id} -n $namespace"
                log_info "kubectl describe middleware traefik-buffering-${project_id} -n $namespace"
                return 0
            else
                log_error "❌ 缓冲中间件部署失败！"
                return 1
            fi
            ;;
        "uninstall")
            if uninstall_buffering_middleware "$project_id" "$namespace"; then
                return 0
            else
                return 1
            fi
            ;;
        "status")
            if check_buffering_middleware_status "$project_id" "$namespace"; then
                return 0
            else
                return 1
            fi
            ;;
        "logs")
            get_buffering_middleware_logs "$project_id" "$namespace" "$dry_run"
            ;;
        *)
            echo "Traefik 缓冲中间件部署脚本"
            echo ""
            echo "用法: $0 <action> <project_id> [additional_params...]"
            echo ""
            echo "操作:"
            echo "  deploy     部署缓冲中间件"
            echo "  uninstall  卸载缓冲中间件"
            echo "  status     检查缓冲中间件状态"
            echo "  logs       获取缓冲中间件日志"
            echo ""
            echo "详细用法:"
            echo "  deploy:    $0 deploy <project_id> [namespace] [environment] [dry_run]"
            echo "  uninstall: $0 uninstall <project_id> [namespace]"
            echo "  status:    $0 status <project_id> [namespace]"
            echo "  logs:      $0 logs <project_id> [namespace] [tail_lines]"
            echo ""
            echo "参数说明:"
            echo "  project_id   项目标识符（必需）"
            echo "  namespace    命名空间（可选，默认: $DEFAULT_NAMESPACE）"
            echo "  environment  环境（可选，默认: $DEFAULT_ENVIRONMENT）"
            echo "  dry_run      干运行模式（可选，默认: false）"
            echo "  tail_lines   日志行数（可选，默认: 50）"
            echo ""
            echo "示例:"
            echo "  $0 deploy $DEFAULT_PROJECT_ID $DEFAULT_NAMESPACE $DEFAULT_ENVIRONMENT"
            echo "  $0 uninstall $DEFAULT_PROJECT_ID $DEFAULT_NAMESPACE"
            echo "  $0 status $DEFAULT_PROJECT_ID $DEFAULT_NAMESPACE"
            echo "  $0 logs $DEFAULT_PROJECT_ID $DEFAULT_NAMESPACE 100"
            echo ""
            echo "配置参数:"
            echo "  MIDDLEWARE_BUFFERING_MAX_REQUEST    最大请求体大小（默认: $DEFAULT_MAX_REQUEST）"
            echo "  MIDDLEWARE_BUFFERING_MAX_RESPONSE   最大响应体大小（默认: $DEFAULT_MAX_RESPONSE）"
            echo "  MIDDLEWARE_BUFFERING_MEM_REQUEST    内存请求体大小（默认: $DEFAULT_MEM_REQUEST）"
            echo "  MIDDLEWARE_BUFFERING_MEM_RESPONSE   内存响应体大小（默认: $DEFAULT_MEM_RESPONSE）"
            echo "  MIDDLEWARE_BUFFERING_RETRY_EXPRESSION 重试表达式（默认: $DEFAULT_RETRY_EXPRESSION）"
            echo ""
            echo "注意:"
            echo "  - 缓冲中间件用于控制请求和响应的缓冲行为"
            echo "  - 可通过配置文件自定义缓冲参数"
            echo "  - 中间件部署为 Kubernetes 自定义资源"
            echo "  - 设置为 0 表示禁用缓冲"
            exit 1
            ;;
    esac
    # 清理 Kubernetes 连接资源
    cleanup_kubectl_environment
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
