#!/bin/bash

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 自动定位 k8s 根目录（向上查找 utils/cluster-arg-parser.sh）
K8S_ROOT_DIR=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），SCRIPT_DIR=$SCRIPT_DIR" 1>&2
    exit 1
fi

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

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
    local config_file="$SCRIPT_DIR/deploy-secrets-all.conf"
    if [[ ! -f "$config_file" ]]; then
        log_error "Neo4j Secrets 总控配置文件不存在: $config_file"
        exit 1
    fi
    
    source "$config_file"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_success "✅ Neo4j Secrets 总控配置加载成功"
}

# 部署所有 Secrets 组件
deploy_all_secrets() {
    local namespace="${1:-data-platform-dev}"
    local project_id="${2:-${PROJECT_ID:-sunmoonai}}"
    local environment="${3:-${ENVIRONMENT:-development}}"
    
    log_info "开始部署 Neo4j 所有 Secrets 组件..."
    log_info "命名空间: $namespace"
    
    # 部署 Harbor Registry Secret（如果启用，优先级最高）
    if [[ "${harbor_registry_secret_enabled:-true}" == "true" ]]; then
        log_info "部署 Harbor 镜像拉取密钥..."
        if [[ -f "$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh" ]]; then
            "$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh" \
                "$project_id" \
                "$namespace" \
                "$environment" \
                "false"
        else
            log_error "❌ Harbor Registry Secret 部署脚本不存在"
            return 1
        fi
    else
        log_info "跳过 Harbor Registry Secret 部署（已禁用）"
    fi
    
    # 部署 Neo4j 密钥
    if [[ "${neo4j_secrets_enabled:-true}" == "true" ]]; then
        log_info "部署 Neo4j 密钥..."
        if [[ -f "$SCRIPT_DIR/../neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" ]]; then
            "$SCRIPT_DIR/../neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" deploy "$namespace"
        else
            log_error "❌ Neo4j 密钥部署脚本不存在"
            return 1
        fi
    else
        log_info "跳过 Neo4j 密钥部署（已禁用）"
    fi
    
    log_success "✅ Neo4j 所有 Secrets 组件部署完成！"
    return 0
}

# 删除所有 Secrets 组件
delete_all_secrets() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "开始删除 Neo4j 所有 Secrets 组件..."
    log_info "命名空间: $namespace"
    
    # 删除 Neo4j 密钥
    if [[ -f "$SCRIPT_DIR/../neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" ]]; then
        "$SCRIPT_DIR/../neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" uninstall "$namespace"
    else
        log_warn "⚠️ Neo4j 密钥部署脚本不存在，跳过删除"
    fi
    
    log_success "✅ Neo4j 所有 Secrets 组件删除完成！"
    return 0
}

# 检查所有 Secrets 状态
check_all_secrets_status() {
    local namespace="${1:-data-platform-dev}"
    
    log_info "检查 Neo4j 所有 Secrets 组件状态..."
    log_info "命名空间: $namespace"
    
    # 检查 Neo4j 密钥
    if [[ -f "$SCRIPT_DIR/../neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" ]]; then
        "$SCRIPT_DIR/../neo4j-secrets/deploy-neo4j-secrets/deploy-neo4j-secrets.sh" status "$namespace"
    else
        log_warn "⚠️ Neo4j 密钥部署脚本不存在"
    fi
    
    log_success "✅ Neo4j 所有 Secrets 组件状态检查完成！"
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
    local project_id="${2:-${PROJECT_ID:-sunmoonai}}"
    local namespace="${3:-data-platform-dev}"
    local environment="${4:-${ENVIRONMENT:-development}}"
    
    # 加载配置
    load_config
    
    case "$action" in
        "deploy")
            deploy_all_secrets "$namespace" "$project_id" "$environment"
            ;;
        "uninstall")
            delete_all_secrets "$namespace"
            ;;
        "status")
            check_all_secrets_status "$namespace"
            ;;
        "help"|"-h"|"--help")
            echo "用法: $0 <action> [namespace]"
            echo ""
            echo "操作:"
            echo "  deploy           部署 Neo4j 所有 Secrets 组件（默认）"
            echo "  uninstall        删除 Neo4j 所有 Secrets 组件"
            echo "  status           检查所有 Secrets 状态"
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
