#!/usr/bin/env bash

# 脚本目录配置
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"
# k8s 根目录：.../k8s（用于引用 utils 下的通用脚本）
# THIS_DIR=.../k8s/sunmoonai/data-platform/deploy-data-platform-all
K8S_ROOT_DIR="$(cd "$THIS_DIR/../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# 颜色输出函数
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

# 日志函数
log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }

# 解析命令行参数

# 先解析命令行参数
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

DATA_PLATFORM_CONFIG_FILE="$THIS_DIR/deploy-data-platform-all.conf"
if [[ -f "$DATA_PLATFORM_CONFIG_FILE" ]]; then
  source "$DATA_PLATFORM_CONFIG_FILE"
  
  # 加载集群配置映射函数（使用 utils 中的通用函数）
  if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_/C2_/C3_/KIND_ 前缀配置）
    apply_cluster_config_mapping
  fi
  
  log_info "已加载 Data Platform 配置: $DATA_PLATFORM_CONFIG_FILE"
else
  log_error "缺少 Data Platform 配置文件: $DATA_PLATFORM_CONFIG_FILE"; exit 1
fi

# 默认参数
DEFAULT_PROJECT_ID="${DATA_PLATFORM_PROJECT_ID:-sunmoonai}"
DEFAULT_NAMESPACE="${DATA_PLATFORM_NAMESPACE:-data-platform-dev}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-development}"

# 调用子级脚本并传递集群参数
call_subscript() {
    local script_path="$1"
    shift
    local args=("$@")
    
    if [[ -n "${CLUSTER:-}" ]]; then
        "$script_path" --cluster "$CLUSTER" "${args[@]}"
    else
        "$script_path" "${args[@]}"
    fi
}

# 执行子级组件（按优先级）
run_sub_components_by_priority() {
    local action="$1"
    local project_id="$2"
    local namespace="$3"
    local environment="$4"
    local dry_run="$5"
    
    log_info "开始执行子级组件: ${action}"
    
    local components=()
    
    # 检查 PostgreSQL
    if [[ "${postgresql_enabled:-false}" == "true" ]]; then
        local priority="${postgresql_priority:-900}"
        components+=("$priority:postgresql:$PROJECT_ROOT/postgresql/deploy-postgresql/deploy-postgresql.sh")
    fi
    
    # 检查 MongoDB
    if [[ "${mongodb_enabled:-false}" == "true" ]]; then
        local priority="${mongodb_priority:-800}"
        components+=("$priority:mongodb:$PROJECT_ROOT/mongodb/deploy-mongodb/deploy-mongodb.sh")
    fi
    
    # 检查 Redis
    if [[ "${redis_enabled:-false}" == "true" ]]; then
        local priority="${redis_priority:-700}"
        components+=("$priority:redis:$PROJECT_ROOT/redis/deploy-redis/deploy-redis.sh")
    fi
    
    # 检查 Elasticsearch
    if [[ "${elasticsearch_enabled:-false}" == "true" ]]; then
        local priority="${elasticsearch_priority:-600}"
        components+=("$priority:elasticsearch:$PROJECT_ROOT/elasticsearch/deploy-elasticsearch/deploy-elasticsearch.sh")
    fi
    
    # 检查 Kibana
    if [[ "${kibana_enabled:-false}" == "true" ]]; then
        local priority="${kibana_priority:-500}"
        components+=("$priority:kibana:$PROJECT_ROOT/kibana/deploy-kibana/deploy-kibana.sh")
    fi
    
    # 检查 Logstash
    if [[ "${logstash_enabled:-false}" == "true" ]]; then
        local priority="${logstash_priority:-400}"
        components+=("$priority:logstash:$PROJECT_ROOT/logstash/deploy-logstash/deploy-logstash.sh")
    fi
    
    # 检查 Neo4j
    if [[ "${neo4j_enabled:-false}" == "true" ]]; then
        local priority="${neo4j_priority:-300}"
        components+=("$priority:neo4j:$PROJECT_ROOT/neo4j/deploy-neo4j/deploy-neo4j.sh")
    fi
    
    IFS=$'\n' sorted_components=($(sort -nr <<<"${components[*]}"))
    unset IFS
    
    if [[ ${#sorted_components[@]} -eq 0 ]]; then
        log_warn "⚠️  没有启用的子级组件"
        return 0
    fi
    
    log_info "📋 子级组件部署顺序："
    for component_info in "${sorted_components[@]}"; do
        local priority="${component_info%%:*}"
        local component=$(echo "$component_info" | cut -d: -f2)
        log_info "  🚀 $component (优先级: $priority)"
    done
    
    for component_info in "${sorted_components[@]}"; do
        local priority="${component_info%%:*}"
        local component=$(echo "$component_info" | cut -d: -f2)
        local script_path=$(echo "$component_info" | cut -d: -f3)
        
        log_info "🚀 ${action} $component..."
        
        if [[ -f "$script_path" ]]; then
            if call_subscript "$script_path" "$action" "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ $component ${action} 成功"
            else
                log_error "❌ $component ${action} 失败"
                return 1
            fi
        else
            log_warn "⚠️  $component 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 所有子级组件 ${action} 完成！"
}

# 主函数（按 action 执行）
run_data_platform() {
    local action="$1"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"
    
    log_info "开始执行 Data Platform: ${action}"
    log_info "项目: $project_id, 命名空间: $namespace, 环境: $environment"
    
    run_sub_components_by_priority "$action" "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "✅ Data Platform ${action} 完成！"
}

# 主函数
main() {
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" || "$action" == "logs" ]]; then
        shift
    fi
    
    local project_id="${1:-${DATA_PLATFORM_PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${DATA_PLATFORM_NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    run_data_platform "$action" "$project_id" "$namespace" "$environment" "$dry_run"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
