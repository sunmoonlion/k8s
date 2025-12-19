#!/bin/bash

# =============================================================================
# Celery Worker ConfigMap 部署脚本
# 文件名: deploy-celeryworker-config.sh
# 用途: 部署 Celery Worker ConfigMap 到 Kubernetes 集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"  # celeryworker-config 目录
# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

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

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 加载配置文件（现在可以使用已设置的 CLUSTER 值）
CONFIG_FILE="$SCRIPT_DIR/deploy-celeryworker-config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
else
    log_warn "配置文件不存在: $CONFIG_FILE，使用默认配置"
fi

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
    local namespace="${2:-${NAMESPACE:-${CONFIGMAP_NAMESPACE:-$DEFAULT_NAMESPACE}}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    log_info "部署 Celery Worker ConfigMap..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 检查命名空间是否存在
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_error "命名空间不存在: $namespace"
        log_error "请先创建命名空间: kubectl create namespace $namespace"
        exit 1
    fi
    
    # ConfigMap YAML 文件路径
    local configmap_yaml="$CONFIG_DIR/celeryworker-config.yaml"
    
    if [[ ! -f "$configmap_yaml" ]]; then
        log_error "ConfigMap YAML 文件不存在: $configmap_yaml"
        exit 1
    fi
    
    # 导出环境变量供 envsubst 使用
    export NAMESPACE="$namespace"
    export CELERY_BROKER_URL="${CELERY_BROKER_URL:-amqp://admin:admin123@rabbitmq-sunmoonai.messaging-platform-dev:5672//}"
    export CELERY_RESULT_BACKEND="${CELERY_RESULT_BACKEND:-redis://redis-service.data-platform:6379/0}"
    export CELERY_QUEUE="${CELERY_QUEUE:-llmops-queue}"
    export CELERY_CONCURRENCY="${CELERY_CONCURRENCY:-2}"
    export REDIS_URL="${REDIS_URL:-redis://redis-service.data-platform:6379}"
    
    # 创建临时文件并替换环境变量
    local temp_yaml=$(mktemp)
    trap "rm -f $temp_yaml" EXIT
    
    log_info "生成 ConfigMap YAML（替换环境变量）..."
    # 将 ${VAR:-default} 转换为 ${VAR}，然后使用 envsubst 替换
    # 因为 envsubst 不支持默认值语法
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$configmap_yaml" | envsubst > "$temp_yaml"
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "试运行模式，生成的 ConfigMap YAML:"
        echo ""
        cat "$temp_yaml"
        echo ""
        log_success "ConfigMap YAML 生成完成（试运行模式）"
    else
        log_info "部署 ConfigMap 到 Kubernetes 集群..."
        
        if kubectl apply -f "$temp_yaml"; then
            log_success "ConfigMap 已部署: $CONFIGMAP_NAME (命名空间: $namespace)"
        else
            log_error "ConfigMap 部署失败"
            exit 1
        fi
    fi
}

# 执行主函数
main "$@"

