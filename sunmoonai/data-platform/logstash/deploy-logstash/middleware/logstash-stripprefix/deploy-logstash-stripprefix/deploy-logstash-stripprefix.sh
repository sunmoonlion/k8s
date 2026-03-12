#!/bin/bash

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
LOGSTASH_STRIPPREFIX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 从 deploy-logstash-stripprefix/ -> logstash-stripprefix/ -> middleware/ -> deploy-logstash/ -> logstash/ -> data-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$LOGSTASH_STRIPPREFIX_SCRIPT_DIR/../../../../../../.." && pwd)"

# 导入统一部署模板（提供日志函数和 Kubernetes 连接函数）
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"

# 恢复 Logstash StripPrefix 脚本的目录路径
SCRIPT_DIR="$LOGSTASH_STRIPPREFIX_SCRIPT_DIR"

# 配置文件路径
LOGSTASH_STRIPPREFIX_CONFIG_FILE="$LOGSTASH_STRIPPREFIX_SCRIPT_DIR/deploy-logstash-stripprefix.conf"
# YAML 文件在上一级目录（logstash-stripprefix/ 目录下）
LOGSTASH_STRIPPREFIX_FILE="$(dirname "$LOGSTASH_STRIPPREFIX_SCRIPT_DIR")/logstash-stripprefix.yaml"

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
    # 使用保存的脚本目录确保路径正确
    local config_file="${LOGSTASH_STRIPPREFIX_CONFIG_FILE:-$LOGSTASH_STRIPPREFIX_SCRIPT_DIR/deploy-logstash-stripprefix.conf}"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Logstash StripPrefix 中间件配置文件不存在: $config_file"
        log_error "LOGSTASH_STRIPPREFIX_SCRIPT_DIR: $LOGSTASH_STRIPPREFIX_SCRIPT_DIR"
        log_error "LOGSTASH_STRIPPREFIX_CONFIG_FILE: ${LOGSTASH_STRIPPREFIX_CONFIG_FILE:-未设置}"
        exit 1
    fi
    
    source "$config_file"
    
    # 如果配置文件中没有定义文件路径，使用默认路径
    if [[ -z "${LOGSTASH_STRIPPREFIX_FILE:-}" ]]; then
        LOGSTASH_STRIPPREFIX_FILE="$(dirname "$LOGSTASH_STRIPPREFIX_SCRIPT_DIR")/logstash-stripprefix.yaml"
    fi
    
    log_success "✅ Logstash StripPrefix 中间件配置加载成功"
}

# 部署 Logstash StripPrefix 中间件
deploy_logstash_stripprefix() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 Logstash StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    # 检查配置文件是否存在
    if [[ ! -f "$LOGSTASH_STRIPPREFIX_FILE" ]]; then
        log_error "Logstash StripPrefix 中间件配置文件不存在: $LOGSTASH_STRIPPREFIX_FILE"
        return 1
    fi
    
    # 应用中间件配置
    log_info "应用 Logstash StripPrefix 中间件配置..."
    if kubectl apply -f "$LOGSTASH_STRIPPREFIX_FILE" -n "$namespace"; then
        log_success "✅ Logstash StripPrefix 中间件配置应用成功"
    else
        log_error "❌ Logstash StripPrefix 中间件配置应用失败"
        return 1
    fi
    
    # 检查中间件状态
    log_info "检查 Logstash StripPrefix 中间件状态..."
    kubectl get middleware -n "$namespace" logstash-stripprefix
    
    log_success "✅ Logstash StripPrefix 中间件部署完成！"
    return 0
}

# 删除 Logstash StripPrefix 中间件
delete_logstash_stripprefix() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 Logstash StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$LOGSTASH_STRIPPREFIX_FILE" 2>/dev/null; then
        log_success "✅ Logstash StripPrefix 中间件配置删除成功"
    else
        log_warn "⚠️ Logstash StripPrefix 中间件配置不存在或删除失败"
    fi
    
    log_success "✅ Logstash StripPrefix 中间件删除完成！"
    return 0
}

# 检查中间件状态
check_stripprefix_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Logstash StripPrefix 中间件状态..."
    
    # 检查中间件是否存在
    if kubectl get middleware -n "$namespace" logstash-stripprefix >/dev/null 2>&1; then
        log_success "✅ Logstash StripPrefix 中间件存在"
        kubectl get middleware -n "$namespace" logstash-stripprefix
    else
        log_error "❌ Logstash StripPrefix 中间件不存在"
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
    
    local action="${1:-deploy}"
    local namespace="${2:-data-platform-dev}"
    
    # 建立远程 k8s 连接
    setup_kubectl_environment
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_logstash_stripprefix "$namespace"
            ;;
        "uninstall")
            delete_logstash_stripprefix "$namespace"
            ;;
        "status")
            check_stripprefix_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Logstash StripPrefix 中间件（默认）"
            echo "  uninstall        删除 Logstash StripPrefix 中间件"
            echo "  status           检查中间件状态"
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

