#!/bin/bash

# Neo4j 中间件总控部署脚本
# 统一部署所有 Neo4j 中间件组件（stripprefix + policy）

set -e

# 导入统一部署模板（使用 BASH_SOURCE 确保路径相对脚本文件）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../../../../utils/unified-deployment-template.sh"
NEO4J_MIDDLEWARE_CONFIG_FILE="$SCRIPT_DIR/deploy-middleware-all.conf"

# 加载配置
load_config() {
    if [[ ! -f "$NEO4J_MIDDLEWARE_CONFIG_FILE" ]]; then
        log_error "Neo4j 中间件总控配置文件不存在: $NEO4J_MIDDLEWARE_CONFIG_FILE"
        exit 1
    fi
    
    source "$NEO4J_MIDDLEWARE_CONFIG_FILE"
    log_success "✅ Neo4j 中间件总控配置加载成功"
}

# 部署所有中间件组件（按优先级）
deploy_all_middleware() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始基于优先级的 Neo4j 中间件组件部署..."
    log_info "命名空间: $namespace"
    
    local components=(
        "stripprefix:${neo4j_stripprefix_enabled:-true}:${neo4j_stripprefix_priority:-200}:Neo4j StripPrefix:$SCRIPT_DIR/../neo4j-stripprefix/deploy-neo4j-stripprefix/deploy-neo4j-stripprefix.sh"
        "policy:${neo4j_policy_enabled:-true}:${neo4j_policy_priority:-100}:Neo4j Policy:$SCRIPT_DIR/../neo4j-policy/deploy-neo4j-policy/deploy-neo4j-policy.sh"
    )
    
    # 过滤启用的组件并按优先级排序
    local enabled=()
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        [[ "$en" == "true" ]] && enabled+=("$c")
    done
    
    # 按优先级降序排序（数值越大越先部署）
    if [[ ${#enabled[@]} -gt 1 ]]; then
        IFS=$'\n' enabled=($(printf '%s\n' "${enabled[@]}" | sort -t: -k3 -nr))
    fi
    
    # 按优先级部署
    for c in "${enabled[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        log_info "🚀 部署 $desc (优先级: $pr) ..."
        if [[ -f "$path" ]]; then
            if "$path" deploy "$namespace"; then
                log_success "✅ $desc 部署成功"
            else
                log_error "❌ $desc 部署失败"
                return 1
            fi
        else
            log_error "❌ $desc 部署脚本不存在: $path"
            return 1
        fi
    done
    
    log_success "✅ Neo4j 所有中间件组件部署完成！"
    return 0
}

# 删除所有中间件组件（按优先级逆序）
delete_all_middleware() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始删除 Neo4j 所有中间件组件（按优先级逆序）..."
    log_info "命名空间: $namespace"
    
    local components=(
        "stripprefix:${neo4j_stripprefix_enabled:-true}:${neo4j_stripprefix_priority:-200}:Neo4j StripPrefix:$SCRIPT_DIR/../neo4j-stripprefix/deploy-neo4j-stripprefix/deploy-neo4j-stripprefix.sh"
        "policy:${neo4j_policy_enabled:-true}:${neo4j_policy_priority:-100}:Neo4j Policy:$SCRIPT_DIR/../neo4j-policy/deploy-neo4j-policy/deploy-neo4j-policy.sh"
    )
    
    # 过滤启用的组件并按优先级升序排序（卸载时逆序）
    local enabled=()
    for c in "${components[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        [[ "$en" == "true" ]] && enabled+=("$c")
    done
    
    # 按优先级升序排序（数值越小越先删除，逆序卸载）
    if [[ ${#enabled[@]} -gt 1 ]]; then
        IFS=$'\n' enabled=($(printf '%s\n' "${enabled[@]}" | sort -t: -k3 -n))
    fi
    
    # 按逆序删除
    for c in "${enabled[@]}"; do
        IFS=':' read -r name en pr desc path <<< "$c"
        log_info "卸载 $desc (优先级: $pr) ..."
        if [[ -f "$path" ]]; then
            "$path" uninstall "$namespace" || log_warn "⚠️ $desc 卸载失败或不存在"
        else
            log_warn "⚠️ $desc 部署脚本不存在，跳过删除"
        fi
    done
    
    log_success "✅ Neo4j 所有中间件组件删除完成！"
    return 0
}

# 检查所有中间件状态
check_all_middleware_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Neo4j 所有中间件组件状态..."
    log_info "命名空间: $namespace"
    
    # 检查 Neo4j StripPrefix 中间件
    if [[ -f "$SCRIPT_DIR/../neo4j-stripprefix/deploy-neo4j-stripprefix/deploy-neo4j-stripprefix.sh" ]]; then
        "$SCRIPT_DIR/../neo4j-stripprefix/deploy-neo4j-stripprefix/deploy-neo4j-stripprefix.sh" status "$namespace"
    else
        log_warn "⚠️ Neo4j StripPrefix 中间件部署脚本不存在"
    fi
    
    # 检查 Neo4j Policy 中间件
    if [[ -f "$SCRIPT_DIR/../neo4j-policy/deploy-neo4j-policy/deploy-neo4j-policy.sh" ]]; then
        "$SCRIPT_DIR/../neo4j-policy/deploy-neo4j-policy/deploy-neo4j-policy.sh" status "$namespace"
    else
        log_warn "⚠️ Neo4j Policy 中间件部署脚本不存在"
    fi
    
    log_success "✅ Neo4j 所有中间件组件状态检查完成！"
    return 0
}

# 主函数
main() {
    local action="${1:-deploy}"
    local project_id="${2:-sunmoonai}"      # 父级传递的项目ID（虽然不使用，但保持接口一致）
    local namespace="${3:-data-platform-dev}"  # 父级传递的命名空间
    local environment="${4:-development}"    # 父级传递的环境（虽然不使用，但保持接口一致）
    local dry_run="${5:-false}"             # 父级传递的 dry_run（虽然不使用，但保持接口一致）
    
    # 建立远程 k8s 连接
    setup_connection
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_all_middleware "$namespace"
            ;;
        "uninstall")
            delete_all_middleware "$namespace"
            ;;
        "status")
            check_all_middleware_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Neo4j 所有中间件组件（默认）"
            echo "  uninstall        删除 Neo4j 所有中间件组件"
            echo "  status           检查所有中间件状态"
            echo "  help             显示此帮助信息"
            echo ""
            echo "参数:"
            echo "  action        操作类型（deploy/uninstall/status）"
            echo "  project_id    项目ID（可选，保持接口一致性）"
            echo "  namespace     命名空间（默认: data-platform-dev）"
            echo "  environment   环境（可选，保持接口一致性）"
            echo "  dry_run       试运行模式（可选，保持接口一致性）"
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

