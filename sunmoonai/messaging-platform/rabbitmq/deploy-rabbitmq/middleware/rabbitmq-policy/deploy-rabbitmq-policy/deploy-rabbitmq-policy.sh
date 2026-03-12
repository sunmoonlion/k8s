#!/bin/bash

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
RABBITMQ_POLICY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-rabbitmq-policy/ -> rabbitmq-policy/ -> middleware/ -> deploy-rabbitmq/ -> rabbitmq/ -> messaging-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$RABBITMQ_POLICY_SCRIPT_DIR/../../../../../../.." && pwd)"

# 导入统一部署模板（提供日志函数和 Kubernetes 连接函数）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复 RabbitMQ 策略脚本的目录路径
SCRIPT_DIR="$RABBITMQ_POLICY_SCRIPT_DIR"

# 配置文件路径
RABBITMQ_POLICY_CONFIG_FILE="$RABBITMQ_POLICY_SCRIPT_DIR/deploy-rabbitmq-policy.conf"

# 解析命令行参数中的集群选择（下沉到统一模板）
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]] && echo "$@" | grep -qE '(--cluster|-c|-C)'; then
    if type unified_parse_cluster_arg >/dev/null 2>&1; then
        unified_parse_cluster_arg "$@"
        ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
    fi
fi

# 加载配置
load_config() {
    # 使用保存的脚本目录确保路径正确
    local config_file="${RABBITMQ_POLICY_CONFIG_FILE:-$RABBITMQ_POLICY_SCRIPT_DIR/deploy-rabbitmq-policy.conf}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "RabbitMQ 策略配置文件不存在: $config_file"
        exit 1
    fi
    
    source "$config_file"
    
    # 计算策略 YAML 文件完整路径（如果配置文件中只提供了相对路径）
    if [[ -n "${RABBITMQ_POLICY_FILE_RELATIVE:-}" ]]; then
        # 相对路径转换为绝对路径（相对于脚本目录）
        RABBITMQ_POLICY_FILE="$(cd "$RABBITMQ_POLICY_SCRIPT_DIR" && cd "$(dirname "$RABBITMQ_POLICY_FILE_RELATIVE")" && pwd)/$(basename "$RABBITMQ_POLICY_FILE_RELATIVE")"
    elif [[ -z "${RABBITMQ_POLICY_FILE:-}" ]]; then
        # 如果没有配置，使用默认路径
        RABBITMQ_POLICY_FILE="$(cd "$RABBITMQ_POLICY_SCRIPT_DIR/.." && pwd)/rabbitmq-policy.yaml"
    fi
    # 展开 ~ 符号
    RABBITMQ_POLICY_FILE="${RABBITMQ_POLICY_FILE/#\~/$HOME}"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_success "✅ RabbitMQ 策略配置加载成功"
}

# 部署 RabbitMQ 策略中间件
deploy_rabbitmq_policy() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "部署 RabbitMQ 策略中间件..."
    log_info "命名空间: $namespace"
    
    # 使用从配置文件中加载的路径（已在 load_config 中计算）
    local policy_file="${RABBITMQ_POLICY_FILE:-$RABBITMQ_POLICY_SCRIPT_DIR/../rabbitmq-policy.yaml}"
    
    # 检查策略 YAML 文件是否存在
    if [[ ! -f "$policy_file" ]]; then
        log_error "RabbitMQ 策略 YAML 文件不存在: $policy_file"
        return 1
    fi
    
    # 应用策略配置
    log_info "应用 RabbitMQ 策略配置..."
    if kubectl apply -f "$policy_file" -n "$namespace"; then
        log_success "✅ RabbitMQ 策略配置应用成功"
    else
        log_error "❌ RabbitMQ 策略配置应用失败"
        return 1
    fi
    
    # 检查中间件状态
    log_info "检查 RabbitMQ 策略中间件状态..."
    kubectl get middleware -n "$namespace" rabbitmq-policy
    
    log_success "✅ RabbitMQ 策略中间件部署完成！"
    return 0
}

# 删除 RabbitMQ 策略中间件
delete_rabbitmq_policy() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "删除 RabbitMQ 策略中间件..."
    log_info "命名空间: $namespace"
    
    # 确定策略 YAML 文件路径
    local policy_file="${RABBITMQ_POLICY_FILE:-$RABBITMQ_POLICY_SCRIPT_DIR/../rabbitmq-policy.yaml}"
    
    if kubectl delete -f "$policy_file" 2>/dev/null; then
        log_success "✅ RabbitMQ 策略配置删除成功"
    else
        log_warn "⚠️ RabbitMQ 策略配置不存在或删除失败"
    fi
    
    log_success "✅ RabbitMQ 策略中间件删除完成！"
    return 0
}

# 检查中间件状态
check_policy_status() {
    local namespace="${1:-messaging-platform-dev}"
    
    log_info "检查 RabbitMQ 策略中间件状态..."
    
    # 检查中间件是否存在
    if kubectl get middleware -n "$namespace" rabbitmq-policy >/dev/null 2>&1; then
        log_success "✅ RabbitMQ 策略中间件存在"
        kubectl get middleware -n "$namespace" rabbitmq-policy
    else
        log_error "❌ RabbitMQ 策略中间件不存在"
        return 1
    fi
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local namespace="${2:-messaging-platform-dev}"
    
    # 建立远程 k8s 连接（使用统一部署模板的函数）
    if ! setup_kubectl_environment; then
        log_error "无法建立 Kubernetes 连接"
        return 1
    fi
    
    # 确保配置文件路径正确（使用保存的脚本目录，防止被覆盖）
    RABBITMQ_POLICY_CONFIG_FILE="$RABBITMQ_POLICY_SCRIPT_DIR/deploy-rabbitmq-policy.conf"
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_rabbitmq_policy "$namespace"
            ;;
        "uninstall")
            delete_rabbitmq_policy "$namespace"
            ;;
        "status")
            check_policy_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [project_id] [namespace] [environment] [dry_run]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 RabbitMQ 策略中间件（默认）"
            echo "  uninstall        删除 RabbitMQ 策略中间件"
            echo "  status           检查中间件状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  action        操作类型（deploy/uninstall/status）"
            echo "  project_id    项目ID（可选，保持接口一致性）"
            echo "  namespace     命名空间（默认: messaging-platform-dev）"
            echo "  environment   环境（可选，保持接口一致性）"
            echo "  dry_run       试运行模式（可选，保持接口一致性）"
            echo ""
            echo "示例:"
            echo "  $0 deploy"
            echo "  $0 deploy messaging-platform-dev"
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

