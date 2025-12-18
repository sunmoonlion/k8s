#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

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
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
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

# 加载配置（现在可以使用已设置的 CLUSTER 值）
SECRETS_CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

if [[ -f "$SECRETS_CONFIG_FILE" ]]; then
    source "$SECRETS_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Secrets 配置文件: $SECRETS_CONFIG_FILE"
else
    log_error "缺少 Secrets 配置文件: $SECRETS_CONFIG_FILE"
    exit 1
fi

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    else
        log_error "❌ 命名空间 $namespace 不存在！"
        echo ""
        log_info "请先使用 namespace-platform 部署所需的命名空间："
        echo "  cd ../../namespace-platform"
        echo "  ./scripts/deploy.sh --env dev"
        echo ""
        log_info "或者手动创建命名空间："
        echo "  kubectl create namespace $namespace"
        echo ""
        return 1
    fi
}

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "🔧 开始部署子级组件..."
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "harbor_registry_secret:${harbor_registry_secret_enabled:-true}:${harbor_registry_secret_priority:-1000}:Harbor 镜像拉取密钥:$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
        "postgresql_llmops_db_secret:${postgresql_llmops_db_secret_enabled:-true}:${postgresql_llmops_db_secret_priority:-900}:PostgreSQL LLMOps 数据库 Secret:$SCRIPT_DIR/../postgresql-llmops-db-secret/deploy-postgresql-llmops-db-secret/deploy-postgresql-llmops-db-secret.sh"
        "neo4j_llmops_db_secret:${neo4j_llmops_db_secret_enabled:-true}:${neo4j_llmops_db_secret_priority:-850}:Neo4j LLMOps 图数据库 Secret:$SCRIPT_DIR/../neo4j-llmops-db-secret/deploy-neo4j-llmops-db-secret/deploy-neo4j-llmops-db-secret.sh"
        "celeryworker_config:${celeryworker_config_enabled:-true}:${celeryworker_config_priority:-800}:Celery Worker ConfigMap:$SCRIPT_DIR/../celeryworker-config/deploy-celeryworker-config/deploy-celeryworker-config.sh"
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
            
            if ./"$(basename "$script_path")" "$project_id" "$namespace" "$environment" "$dry_run"; then
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

# 部署 Secrets 核心服务
deploy_secrets_core() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "🚀 阶段2：部署 Secrets 核心服务"
    
    # 这里可以添加 Secrets 核心服务的部署逻辑
    # 例如：创建通用的 Secret 模板、验证 Secret 格式等
    
    log_info "📝 验证 Secret 和 ConfigMap 配置..."
    
    # 验证必要的环境变量
    if [[ -z "$PROJECT_ID" ]]; then
        log_error "❌ PROJECT_ID 未设置"
        return 1
    fi
    
    if [[ -z "$NAMESPACE" ]]; then
        log_error "❌ NAMESPACE 未设置"
        return 1
    fi
    
    log_success "✅ Secrets 核心服务配置验证完成"
}

# 部署本级专属组件
deploy_current_level_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "🚀 阶段3：部署本级专属组件"
    
    # 这里可以添加 Secrets 级别的专属部署逻辑
    # 例如：创建 Secret 监控、日志记录、验证等
    
    log_info "📊 设置 Secret 和 ConfigMap 监控和验证..."
    
    # 验证所有 Secret 和 ConfigMap 是否正确创建
    log_info "🔍 验证 Secret 和 ConfigMap 状态..."
    
    # 检查 harbor-registry-secret
    if [[ "${harbor_registry_secret_enabled:-true}" == "true" ]]; then
        if kubectl get secret harbor-registry-secret -n "$namespace" >/dev/null 2>&1; then
            log_success "✅ harbor-registry-secret 已存在"
        else
            log_warn "⚠️  harbor-registry-secret 不存在"
        fi
    fi
    
    # 检查 postgresql-llmops-db-secret
    if [[ "${postgresql_llmops_db_secret_enabled:-true}" == "true" ]]; then
        if kubectl get secret postgresql-llmops-db-secret -n "$namespace" >/dev/null 2>&1; then
            log_success "✅ postgresql-llmops-db-secret 已存在"
        else
            log_warn "⚠️  postgresql-llmops-db-secret 不存在"
        fi
    fi
    
    # 检查 neo4j-llmops-db-secret
    if [[ "${neo4j_llmops_db_secret_enabled:-true}" == "true" ]]; then
        if kubectl get secret neo4j-llmops-db-secret -n "$namespace" >/dev/null 2>&1; then
            log_success "✅ neo4j-llmops-db-secret 已存在"
        else
            log_warn "⚠️  neo4j-llmops-db-secret 不存在"
        fi
    fi
    
    # 检查 celeryworker-config
    if [[ "${celeryworker_config_enabled:-true}" == "true" ]]; then
        if kubectl get configmap celeryworker-config -n "$namespace" >/dev/null 2>&1; then
            log_success "✅ celeryworker-config 已存在"
        else
            log_warn "⚠️  celeryworker-config 不存在"
        fi
    fi
    
    log_success "✅ 本级专属组件部署完成"
}

# 主部署函数
deploy_secrets() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "🚀 开始部署 Celery Worker Secrets 和 ConfigMaps..."
    log_info "📋 部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 检查命名空间
    if ! check_namespace "$namespace"; then
        return 1
    fi
    
    # 阶段1：部署子级组件（按优先级）
    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    # 阶段2：部署 Secrets 核心服务
    deploy_secrets_core "$project_id" "$namespace" "$environment" "$dry_run"
    
    # 阶段3：部署本级专属组件
    deploy_current_level_components "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "🎉 Secrets 和 ConfigMaps 递归部署完成！"
    echo ""
    log_info "📋 部署信息："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    log_success "🎯 Secrets 和 ConfigMaps 部署成功完成！"
}

# 显示帮助信息
show_help() {
    echo "Secrets All 递归部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 [项目ID] [命名空间] [环境] [试运行]"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: $DEFAULT_PROJECT_ID)"
    echo "  命名空间   Kubernetes 命名空间 (默认: $DEFAULT_NAMESPACE)"
    echo "  环境       部署环境 (默认: $DEFAULT_ENVIRONMENT)"
    echo "  试运行     是否试运行 (默认: false)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认参数"
    echo "  $0 sunmoonai app-platform-dev dev    # 指定参数"
    echo "  $0 sunmoonai app-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SECRETS_CONFIG_FILE"
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 处理参数：如果第一个参数是 action（如 deploy），则跳过
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]]; then
        # 第一个参数是 action，跳过它
        shift
    fi
    
    local project_id="${1:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    log_info "🚀 开始部署 Celery Worker Secrets 和 ConfigMaps..."
    log_info "  项目ID: $project_id"
    log_info "  命名空间: $namespace"
    log_info "  环境: $environment"
    log_info "  试运行: $dry_run"
    echo ""
    
    # 部署 Secrets
    if deploy_secrets "$project_id" "$namespace" "$environment" "$dry_run"; then
        log_success "✅ Celery Worker Secrets 和 ConfigMaps 部署完成！"
        return 0
    else
        log_error "❌ Celery Worker Secrets 和 ConfigMaps 部署失败"
        return 1
    fi
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi

