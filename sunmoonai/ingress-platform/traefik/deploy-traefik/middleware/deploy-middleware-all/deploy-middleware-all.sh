#!/bin/bash

# Traefik 中间件部署脚本
# 负责部署和管理 Traefik 中间件子组件

set -e

# 脚本目录（保存为变量，防止被统一部署模板覆盖）
MIDDLEWARE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（k8s目录）
# 当前位置：sunmoonai/ingress-platform/traefik/deploy-traefik/middleware/deploy-middleware-all/
# 向上 6 层到达 k8s 目录
K8S_ROOT="$(cd "$MIDDLEWARE_SCRIPT_DIR/../../../../../.." && pwd)"

# 导入统一部署模板（提供日志函数和 Kubernetes 连接函数）
source "$K8S_ROOT/utils/unified-deployment-template.sh"

# 恢复中间件脚本的目录路径
SCRIPT_DIR="$MIDDLEWARE_SCRIPT_DIR"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
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
        if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$K8S_ROOT/utils/cluster-config-mapping.sh"
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

# 加载中间件部署配置文件
MIDDLEWARE_CONFIG_FILE="$SCRIPT_DIR/deploy_middleware-all.conf"
if [[ -f "$MIDDLEWARE_CONFIG_FILE" ]]; then
    source "$MIDDLEWARE_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$K8S_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载中间件配置文件: $MIDDLEWARE_CONFIG_FILE"
else
    log_error "缺少中间件配置文件: $MIDDLEWARE_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="ingress-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查子组件脚本是否存在
    local components=(
        "buffering:${middleware_buffering_enabled:-false}:${middleware_buffering_priority:-900}:缓冲中间件:$PROJECT_ROOT/traefik-buffering-middleware/deploy-buffering-traefik-middleware/deploy-traefik-middleware.sh"
    )

    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            if [[ ! -f "$script_path" ]]; then
                log_error "子组件部署脚本不存在: $script_path"
                return 1
            fi
            if [[ ! -x "$script_path" ]]; then
                log_error "子组件部署脚本无执行权限: $script_path"
                return 1
            fi
        fi
    done
    log_info "前置条件检查通过"
}

# 部署中间件子组件（按优先级）
deploy_middleware_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始基于优先级的中间件子组件部署..."

    # 定义中间件组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "buffering:${middleware_buffering_enabled:-false}:${middleware_buffering_priority:-900}:缓冲中间件:$PROJECT_ROOT/traefik-buffering-middleware/deploy-buffering-traefik-middleware/deploy-traefik-middleware.sh"
    )

    # 先过滤出启用的组件，然后按优先级排序
    local enabled_components=()
    local disabled_components=()

    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            enabled_components+=("$component_info")
        else
            disabled_components+=("$component_info")
        fi
    done

    # 根据启用组件数量决定是否进行优先级排序
    if [[ ${#enabled_components[@]} -gt 1 ]]; then
        # 多个组件启用时，按优先级排序（数值越大优先级越高）
        IFS=$'\n' sorted_enabled_components=($(printf '%s\n' "${enabled_components[@]}" | sort -t: -k3 -nr))
        log_info "📋 中间件子组件部署顺序（按优先级排序）："

        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        # 只有一个组件启用时，直接使用，无需排序
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 中间件子组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        # 没有启用的组件
        sorted_enabled_components=()
        log_info "📋 中间件子组件部署顺序：无启用的组件"
    fi

    # 显示禁用的组件
    if [[ ${#disabled_components[@]} -gt 0 ]]; then
        log_info "  ⏭️  禁用的组件："
        for component_info in "${disabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "    $description (${name}_enabled=false)"
        done
    fi

    # 部署启用的组件
    for component_info in "${sorted_enabled_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"

        if [[ ${#enabled_components[@]} -gt 1 ]]; then
            log_info "🚀 部署 $description (优先级: $priority)..."
        else
            log_info "🚀 部署 $description..."
        fi

        if [[ -f "$script_path" ]]; then
            local original_dir="$(pwd)"
            cd "$(dirname "$script_path")"

            # 传递 deploy action 和所有参数
            if ./"$(basename "$script_path")" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ $description 部署成功"
            else
                log_error "❌ $description 部署失败"
                cd "$original_dir"
                return 1
            fi

            cd "$original_dir"
        else
            log_warn "⚠️  $description 部署脚本不存在: $script_path"
        fi
    done

    log_success "✅ 中间件子组件部署完成！"
}

# 卸载中间件子组件（按优先级反向）
uninstall_middleware_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "开始基于优先级的中间件子组件卸载..."

    local components=(
        "buffering:${middleware_buffering_enabled:-false}:${middleware_buffering_priority:-900}:缓冲中间件:$PROJECT_ROOT/traefik-buffering-middleware/deploy-buffering-traefik-middleware/deploy-traefik-middleware.sh"
    )

    # 卸载时按优先级从低到高（反向）
    IFS=$'\n' sorted_components=($(printf '%s\n' "${components[@]}" | sort -t: -k3 -n))

    for component_info in "${sorted_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "🚀 卸载 $description (优先级: $priority)..."
            if [[ -f "$script_path" ]]; then
                local original_dir="$(pwd)"
                cd "$(dirname "$script_path")"
                if ./"$(basename "$script_path")" uninstall "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ $description 卸载成功"
                else
                    log_error "❌ $description 卸载失败"
                    cd "$original_dir"
                    # 不返回1，尝试卸载其他组件
                fi
                cd "$original_dir"
            else
                log_warn "⚠️  $description 卸载脚本不存在: $script_path"
            fi
        fi
    done

    log_success "✅ 中间件子组件卸载完成！"
}

# 检查中间件子组件状态
check_middleware_components_status() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"

    log_info "检查中间件子组件状态..."

    local components=(
        "buffering:${middleware_buffering_enabled:-false}:${middleware_buffering_priority:-900}:缓冲中间件:$PROJECT_ROOT/traefik-buffering-middleware/deploy-buffering-traefik-middleware/deploy-traefik-middleware.sh"
    )

    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "🚀 检查 $description 状态..."
            if [[ -f "$script_path" ]]; then
                local original_dir="$(pwd)"
                cd "$(dirname "$script_path")"
                if ./"$(basename "$script_path")" status "$project_id" "$namespace" "$environment" "$dry_run"; then
                    log_success "✅ $description 状态检查完成"
                else
                    log_warn "⚠️  $description 状态检查异常"
                fi
                cd "$original_dir"
            else
                log_warn "⚠️  $description 状态脚本不存在: $script_path"
            fi
        fi
    done

    log_success "✅ 中间件子组件状态检查完成！"
}

# 获取中间件子组件日志
get_middleware_components_logs() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    local tail_lines="${5:-50}"

    log_info "获取中间件子组件日志..."

    local components=(
        "buffering:${middleware_buffering_enabled:-false}:${middleware_buffering_priority:-900}:缓冲中间件:$PROJECT_ROOT/traefik-buffering-middleware/deploy-buffering-traefik-middleware/deploy-traefik-middleware.sh"
    )

    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "🚀 获取 $description 日志..."
            if [[ -f "$script_path" ]]; then
                local original_dir="$(pwd)"
                cd "$(dirname "$script_path")"
                if ./"$(basename "$script_path")" logs "$project_id" "$namespace" "$environment" "$dry_run" "$tail_lines"; then
                    log_success "✅ $description 日志获取完成"
                else
                    log_warn "⚠️  $description 日志获取异常"
                fi
                cd "$original_dir"
            else
                log_warn "⚠️  $description 日志脚本不存在: $script_path"
            fi
        fi
    done

    log_success "✅ 中间件子组件日志获取完成！"
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-}"
    local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
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

    # 检查命名空间是否存在
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_error "命名空间 $namespace 不存在，请先创建"
        return 1
    fi

    # 检查前置条件
    if ! check_prerequisites; then
        log_error "前置条件检查失败，部署终止"
        return 1
    fi

    case "$action" in
        "deploy")
            if deploy_middleware_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"; then
                return 0
            else
                log_error "❌ 中间件子组件部署失败！"
                return 1
            fi
            ;;
        "uninstall")
            if uninstall_middleware_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"; then
                return 0
            else
                log_error "❌ 中间件子组件卸载失败！"
                return 1
            fi
            ;;
        "status")
            if check_middleware_components_status "$project_id" "$namespace" "$environment" "$dry_run"; then
                return 0
            else
                log_error "❌ 中间件子组件状态检查失败！"
                return 1
            fi
            ;;
        "logs")
            if get_middleware_components_logs "$project_id" "$namespace" "$environment" "$dry_run"; then
                return 0
            else
                log_error "❌ 中间件子组件日志获取失败！"
                return 1
            fi
            ;;
        *)
            echo "Traefik 中间件部署脚本"
            echo ""
            echo "用法: $0 [--cluster C1|C2] <action> <project_id> [additional_params...]"
            echo ""
            echo "参数:"
            echo "  --cluster, -c   集群选择 (格式：C{数字}，如 C1, C2, C3 等)，也可以通过环境变量 CLUSTER 设置"
            echo ""
            echo "操作:"
            echo "  deploy     部署中间件子组件"
            echo "  uninstall  卸载中间件子组件"
            echo "  status     检查中间件子组件状态"
            echo "  logs       获取中间件子组件日志"
            echo ""
            echo "详细用法:"
            echo "  deploy:    $0 deploy <project_id> [namespace] [environment] [dry_run]"
            echo "  uninstall: $0 uninstall <project_id> [namespace] [environment] [dry_run]"
            echo "  status:    $0 status <project_id> [namespace] [environment] [dry_run]"
            echo "  logs:      $0 logs <project_id> [namespace] [environment] [dry_run] [tail_lines]"
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
            echo "  $0 uninstall $DEFAULT_PROJECT_ID $DEFAULT_NAMESPACE $DEFAULT_ENVIRONMENT"
            echo "  $0 status $DEFAULT_PROJECT_ID $DEFAULT_NAMESPACE $DEFAULT_ENVIRONMENT"
            echo "  $0 logs $DEFAULT_PROJECT_ID $DEFAULT_NAMESPACE $DEFAULT_ENVIRONMENT 100"
            echo ""
            echo "中间件子组件:"
            echo "  - 缓冲中间件 (buffering)    - 控制请求/响应缓冲，支持大文件上传"
            echo ""
            echo "注意:"
            echo "  - 超时配置已移至Traefik全局配置，无需中间件"
            echo "  - 可通过配置文件控制中间件子组件的启用/禁用"
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
