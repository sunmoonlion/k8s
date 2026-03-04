#!/bin/bash

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 计算项目根目录（从当前脚本位置向上查找）
# deploy-kibana-stripprefix.sh -> deploy-kibana-stripprefix/ -> kibana-stripprefix/ -> middleware/ -> deploy-kibana/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# 导入统一部署模板（提供日志函数等基础设施）
# 在加载前保存 SCRIPT_DIR，因为 unified-deployment-template.sh 会覆盖它
SAVED_SCRIPT_DIR_FOR_TEMPLATE="$SCRIPT_DIR"
utils_path=""
if [[ -f "$PROJECT_ROOT/../../../../utils/unified-deployment-template.sh" ]]; then
    utils_path="$PROJECT_ROOT/../../../../utils/unified-deployment-template.sh"
fi

if [[ -n "$utils_path" && -f "$utils_path" ]]; then
    source "$utils_path"
    # 立即恢复 SCRIPT_DIR，防止被 unified-deployment-template.sh 覆盖
    SCRIPT_DIR="$SAVED_SCRIPT_DIR_FOR_TEMPLATE"
else
    echo "警告: 无法找到 unified-deployment-template.sh，日志函数可能不可用" >&2
    # 定义基本的日志函数作为后备
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warn() { echo "[WARN] $*"; }
fi

# 确保 SCRIPT_DIR 正确
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        # 在加载前保存 SCRIPT_DIR
        local saved_script_dir="$SCRIPT_DIR"
        if [[ -f "$PROJECT_ROOT/../../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../../utils/cluster-config-mapping.sh"
            # 恢复 SCRIPT_DIR
            SCRIPT_DIR="$saved_script_dir"
            apply_cluster_config_mapping "$cluster_value"
            # 再次确保 SCRIPT_DIR 正确
            SCRIPT_DIR="$saved_script_dir"
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

# 配置文件路径（如果未设置，使用默认路径）
if [[ -z "${KIBANA_STRIPPREFIX_CONFIG_FILE:-}" ]]; then
    KIBANA_STRIPPREFIX_CONFIG_FILE="$SCRIPT_DIR/deploy-kibana-stripprefix.conf"
fi
if [[ -z "${KIBANA_STRIPPREFIX_FILE:-}" ]]; then
    KIBANA_STRIPPREFIX_FILE="$(dirname "$SCRIPT_DIR")/kibana-stripprefix.yaml"
fi

# 加载配置
load_config() {
    if [[ ! -f "$KIBANA_STRIPPREFIX_CONFIG_FILE" ]]; then
        log_error "Kibana StripPrefix 中间件配置文件不存在: $KIBANA_STRIPPREFIX_CONFIG_FILE"
        exit 1
    fi
    
    # 在加载配置文件前保存 SCRIPT_DIR
    local saved_script_dir="$SCRIPT_DIR"
    source "$KIBANA_STRIPPREFIX_CONFIG_FILE"
    # 恢复 SCRIPT_DIR，防止被配置文件覆盖
    SCRIPT_DIR="$saved_script_dir"
    log_success "✅ Kibana StripPrefix 中间件配置加载成功"
}

# 部署 Kibana StripPrefix 中间件
deploy_kibana_stripprefix() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "部署 Kibana StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    # 检查配置文件是否存在
    if [[ ! -f "$KIBANA_STRIPPREFIX_FILE" ]]; then
        log_error "Kibana StripPrefix 中间件配置文件不存在: $KIBANA_STRIPPREFIX_FILE"
        return 1
    fi
    
    # 应用中间件配置
    log_info "应用 Kibana StripPrefix 中间件配置..."
    if kubectl apply -f "$KIBANA_STRIPPREFIX_FILE" -n "$namespace"; then
        log_success "✅ Kibana StripPrefix 中间件配置应用成功"
    else
        log_error "❌ Kibana StripPrefix 中间件配置应用失败"
        return 1
    fi
    
    # 检查中间件状态
    log_info "检查 Kibana StripPrefix 中间件状态..."
    kubectl get middleware -n "$namespace" kibana-stripprefix
    
    log_success "✅ Kibana StripPrefix 中间件部署完成！"
    return 0
}

# 删除 Kibana StripPrefix 中间件
delete_kibana_stripprefix() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "删除 Kibana StripPrefix 中间件..."
    log_info "命名空间: $namespace"
    
    if kubectl delete -f "$KIBANA_STRIPPREFIX_FILE" 2>/dev/null; then
        log_success "✅ Kibana StripPrefix 中间件配置删除成功"
    else
        log_warn "⚠️ Kibana StripPrefix 中间件配置不存在或删除失败"
    fi
    
    log_success "✅ Kibana StripPrefix 中间件删除完成！"
    return 0
}

# 检查中间件状态
check_stripprefix_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Kibana StripPrefix 中间件状态..."
    
    # 检查中间件是否存在
    if kubectl get middleware -n "$namespace" kibana-stripprefix >/dev/null 2>&1; then
        log_success "✅ Kibana StripPrefix 中间件存在"
        kubectl get middleware -n "$namespace" kibana-stripprefix
    else
        log_error "❌ Kibana StripPrefix 中间件不存在"
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
    # 建立远程 k8s 连接（如果函数存在）
    if type setup_kubectl_environment >/dev/null 2>&1; then
        setup_kubectl_environment
    elif type setup_connection >/dev/null 2>&1; then
        setup_connection
    else
        log_warn "⚠️  无法建立 Kubernetes 连接（函数不存在），继续执行..."
    fi
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_kibana_stripprefix "$namespace"
            ;;
        "uninstall")
            delete_kibana_stripprefix "$namespace"
            ;;
        "status")
            check_stripprefix_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Kibana StripPrefix 中间件（默认）"
            echo "  uninstall        删除 Kibana StripPrefix 中间件"
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

