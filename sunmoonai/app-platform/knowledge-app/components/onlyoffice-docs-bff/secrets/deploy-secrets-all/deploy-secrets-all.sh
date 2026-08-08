#!/bin/bash

set -euo pipefail

# 禁用自动清理，由主脚本负责清理
DISABLE_AUTO_CLEANUP=true

# 恢复 Secrets 脚本的目录路径
SCRIPT_DIR="${ONLYOFFICE_SECRETS_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# 计算项目根目录（k8s目录）
# 从 deploy-secrets-all/ 向上5级到达 k8s/
# deploy-secrets-all/ -> secrets/ -> onlyoffice-docs/ -> app-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 解析命令行参数
declare -a PARSED_ARGS

parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载主配置文件
ONLYOFFICE_MAIN_CONFIG_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-onlyoffice-docs/deploy-onlyoffice-docs.conf"
if [[ -f "$ONLYOFFICE_MAIN_CONFIG_FILE" ]]; then
    source "$ONLYOFFICE_MAIN_CONFIG_FILE"
    log_info "已加载 ONLYOFFICE Docs 主配置文件: $ONLYOFFICE_MAIN_CONFIG_FILE"
else
    log_error "缺少 ONLYOFFICE Docs 主配置文件: $ONLYOFFICE_MAIN_CONFIG_FILE"
    exit 1
fi

# 加载 Secrets 总控配置文件
SECRETS_CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"
if [[ -f "$SECRETS_CONFIG_FILE" ]]; then
    source "$SECRETS_CONFIG_FILE"
    log_info "已加载 Secrets 总控配置文件: $SECRETS_CONFIG_FILE"
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local action="$1"
    local project_id="$2"
    local namespace="$3"
    local environment="$4"
    
    log_info "🔧 开始部署子级组件..."
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "harbor_registry_secret:${harbor_registry_secret_enabled:-true}:${harbor_registry_secret_priority:-1000}:Harbor 镜像拉取密钥:$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
        "onlyoffice_postgresql_secret:${onlyoffice_postgresql_secret_enabled:-true}:${onlyoffice_postgresql_secret_priority:-900}:ONLYOFFICE PostgreSQL 连接密钥:$SCRIPT_DIR/../onlyoffice-postgresql-secret/deploy-onlyoffice-postgresql-secret/deploy-onlyoffice-postgresql-secret.sh"
        "onlyoffice_redis_secret:${onlyoffice_redis_secret_enabled:-true}:${onlyoffice_redis_secret_priority:-800}:ONLYOFFICE Redis 连接密钥:$SCRIPT_DIR/../onlyoffice-redis-secret/deploy-onlyoffice-redis-secret/deploy-onlyoffice-redis-secret.sh"
        "onlyoffice_rabbitmq_secret:${onlyoffice_rabbitmq_secret_enabled:-true}:${onlyoffice_rabbitmq_secret_priority:-700}:ONLYOFFICE RabbitMQ 连接密钥:$SCRIPT_DIR/../onlyoffice-rabbitmq-secret/deploy-onlyoffice-rabbitmq-secret/deploy-onlyoffice-rabbitmq-secret.sh"
        "onlyoffice_jwt_secret:${onlyoffice_jwt_secret_enabled:-true}:${onlyoffice_jwt_secret_priority:-600}:ONLYOFFICE JWT 认证密钥:$SCRIPT_DIR/../onlyoffice-jwt-secret/deploy-onlyoffice-jwt-secret/deploy-onlyoffice-jwt-secret.sh"
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
        log_info "📋 子级组件部署顺序（按优先级排序）："
        
        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        # 只有一个组件启用时，直接使用，无需排序
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 子级组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        # 没有启用的组件
        sorted_enabled_components=()
        log_info "📋 子级组件部署顺序：无启用的组件"
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
            
            if ./"$(basename "$script_path")" "$action" "$project_id" "$namespace" "$environment"; then
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
    
    log_success "✅ 子级组件部署完成！"
}

# 主函数
main() {
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    # 参数格式：<action> <project_id> <namespace> <environment>
    # 与其他组件的 deploy-secrets-all.sh 保持一致
    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    
    log_info "🚀 开始部署 ONLYOFFICE Docs Secrets..."
    log_info "📋 部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 操作: $action"
    echo ""
    
    # 确保命名空间存在（仅在 deploy 操作时）
    if [[ "$action" != "status" && "$action" != "generate" ]]; then
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "❌ 命名空间不存在: $namespace"
            exit 1
        fi
    fi
    
    # 阶段1：部署子级组件（Harbor Registry Secret 等）
    if ! deploy_sub_components_by_priority "$action" "$project_id" "$namespace" "$environment"; then
        log_error "❌ 子级组件部署失败"
        exit 1
    fi
    
    echo ""
    log_success "🎉 ONLYOFFICE Docs Secrets 部署完成！"
    log_info "📋 部署信息："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

main "$@"

