#!/bin/bash

# =============================================================================
# Redis Auth Secret 部署脚本
# 文件名: deploy-redis-auth-secret.sh
# 用途: 生成并部署Redis认证Secret到Kubernetes集群
# 说明: Bitnami Redis Chart要求Secret键名使用破折号（redis-password）
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"


source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="data-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置文件（现在可以使用已设置的 CLUSTER 值）
source "$SCRIPT_DIR/deploy-redis-auth-secret.conf"

# 加载集群配置映射函数（使用 utils 中的通用函数）
if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
    # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
    apply_cluster_config_mapping
fi

main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 Redis Auth Secret..."
    log_info "部署参数：项目ID=$project_id, 命名空间=$namespace, 环境=$environment, 试运行=$dry_run"
    echo ""
    
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    if [[ -n "${redis_password:-}" ]]; then
        echo -n "${redis_password}" > "$temp_data_dir/redis-password"
        log_info "添加数据键: redis-password"
    fi
    
    local secret_yaml="$SECRET_DIR/redis-auth-secret.yaml"
    
    log_info "生成Opaque Secret YAML..."
    generate_opaque_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Opaque Secret YAML生成完成: $secret_yaml"
    
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署Secret到Kubernetes集群..."
        
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "命名空间不存在: $namespace"
            exit 1
        fi
        
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret已部署: $SECRET_NAME (命名空间: $namespace)"
        else
            log_error "Secret部署失败"
            exit 1
        fi
        
        if [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" ]]; then
            log_info "重启使用该Secret的组件..."
            IFS=',' read -ra COMPONENTS <<< "${RESTART_COMPONENTS_LIST}"
            for component in "${COMPONENTS[@]}"; do
                component=$(echo "$component" | xargs)
                if [[ -n "$component" ]]; then
                    log_info "重启组件: $component"
                    kubectl rollout restart deployment/"$component" -n "$namespace" 2>/dev/null || \
                    kubectl rollout restart statefulset/"$component" -n "$namespace" 2>/dev/null || \
                    log_warn "组件 $component 不存在或重启失败"
                fi
            done
        fi
    else
        log_info "[试运行] 将部署Secret: $SECRET_NAME"
    fi
    
    echo ""
    log_success "Redis Auth Secret 部署完成！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Redis Auth Secret 部署脚本"
        echo "用法: $0 [项目ID] [命名空间] [环境] [试运行]"
        exit 0
    fi
    main "$@"
fi

