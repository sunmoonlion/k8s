#!/usr/bin/env bash

# 脚本目录配置
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"

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
        if [[ -f "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

# 先解析命令行参数
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

DATA_PLATFORM_CONFIG_FILE="$THIS_DIR/deploy-data-platform-all.conf"
if [[ -f "$DATA_PLATFORM_CONFIG_FILE" ]]; then
  source "$DATA_PLATFORM_CONFIG_FILE"
  
  # 加载集群配置映射函数（使用 utils 中的通用函数）
  if [[ -f "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
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

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "开始部署子级组件..."
    
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
        
        log_info "🚀 部署 $component..."
        
        if [[ -f "$script_path" ]]; then
            if call_subscript "$script_path" deploy "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ $component 部署成功"
            else
                log_error "❌ $component 部署失败"
                return 1
            fi
        else
            log_warn "⚠️  $component 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 所有子级组件部署完成！"
}

# 主部署函数
deploy_data_platform() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "开始部署 Data Platform..."
    log_info "项目: $project_id, 命名空间: $namespace, 环境: $environment"
    
    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "✅ Data Platform 部署完成！"
}

# 主函数
main() {
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]]; then
        shift
    fi
    
    local project_id="${1:-${DATA_PLATFORM_PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${DATA_PLATFORM_NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    deploy_data_platform "$project_id" "$namespace" "$environment" "$dry_run"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
