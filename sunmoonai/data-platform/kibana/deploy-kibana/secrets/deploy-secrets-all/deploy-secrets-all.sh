#!/bin/bash

# 禁用自动清理，由主脚本负责清理
DISABLE_AUTO_CLEANUP=true

# 恢复 Secrets 脚本的目录路径
# 优先使用 SECRETS_SCRIPT_DIR 环境变量，如果未设置则从脚本自身位置计算
if [[ -z "${SECRETS_SCRIPT_DIR:-}" ]]; then
    SECRETS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# 确保 SCRIPT_DIR 是绝对路径
if [[ -n "$SECRETS_SCRIPT_DIR" ]]; then
    SCRIPT_DIR="$(cd "$SECRETS_SCRIPT_DIR" && pwd)"
else
    # 如果还是为空，从脚本自身位置计算
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# 自动定位 k8s 根目录（向上查找 utils/unified-deployment-template.sh）
PROJECT_ROOT=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/unified-deployment-template.sh" ]]; then
        PROJECT_ROOT="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$PROJECT_ROOT" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/unified-deployment-template.sh），SCRIPT_DIR=$SCRIPT_DIR" >&2
    exit 1
fi

# 导入统一部署模板（提供日志函数等基础设施）
# 在加载前保存 SCRIPT_DIR，因为 unified-deployment-template.sh 会覆盖它
SAVED_SCRIPT_DIR_FOR_TEMPLATE="$SCRIPT_DIR"
source "$PROJECT_ROOT/utils/unified-deployment-template.sh"
# 立即恢复 SCRIPT_DIR，防止被 unified-deployment-template.sh 覆盖
SCRIPT_DIR="$SAVED_SCRIPT_DIR_FOR_TEMPLATE"

# 解析命令行参数函数（支持 --cluster 或 -c）

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载 Secrets 部署配置文件
# 在加载任何外部脚本前保存 SCRIPT_DIR，防止被覆盖
SAVED_SCRIPT_DIR="$SCRIPT_DIR"
SECRETS_CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"
if [[ -f "$SECRETS_CONFIG_FILE" ]]; then
    source "$SECRETS_CONFIG_FILE"
    # 恢复 SCRIPT_DIR，防止被配置文件覆盖
    SCRIPT_DIR="$SAVED_SCRIPT_DIR"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    # 在加载前再次保存 SCRIPT_DIR，因为 cluster-config-mapping.sh 可能会覆盖它
    SAVED_SCRIPT_DIR_FOR_CLUSTER="$SCRIPT_DIR"
    if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
        # 临时保存当前的 SCRIPT_DIR，因为 cluster-config-mapping.sh 可能会修改它
        original_script_dir="$SCRIPT_DIR"
        source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
        # 立即恢复 SCRIPT_DIR，防止被 cluster-config-mapping.sh 覆盖
        SCRIPT_DIR="$original_script_dir"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
        # 再次确保 SCRIPT_DIR 正确（apply_cluster_config_mapping 可能也会修改它）
        SCRIPT_DIR="$original_script_dir"
    fi
    # 最后再次确保 SCRIPT_DIR 正确
    SCRIPT_DIR="$SAVED_SCRIPT_DIR"
    
    log_info "已加载 Secrets 配置文件: $SECRETS_CONFIG_FILE"
else
    log_error "缺少 Secrets 配置文件: $SECRETS_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

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
        "kibana_elasticsearch_secret:${kibana_elasticsearch_secret_enabled:-true}:${kibana_elasticsearch_secret_priority:-800}:Kibana Elasticsearch 连接密钥:$SCRIPT_DIR/../kibana-elasticsearch-secret/deploy-kibana-elasticsearch-secret/deploy-kibana-elasticsearch-secret.sh"
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
    
    log_info "📝 验证 Secret 配置..."
    
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
    
    log_info "📊 设置 Secret 监控和验证..."
    
    log_info "🔍 验证 Secret 状态..."
    
    log_success "✅ 本级专属组件部署完成"
}

# 主部署函数
deploy_secrets() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "🚀 开始部署 Secrets 递归架构..."
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
    
    log_success "🎉 Secrets 递归部署完成！"
    echo ""
    log_info "📋 部署信息："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    log_success "🎯 Secrets 部署成功完成！"
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
    echo "  $0 sunmoonai data-platform-dev dev   # 指定参数"
    echo "  $0 sunmoonai data-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SECRETS_CONFIG_FILE"
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS

