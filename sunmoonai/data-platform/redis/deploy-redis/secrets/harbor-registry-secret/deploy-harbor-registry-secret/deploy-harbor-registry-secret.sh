#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"


source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 尝试加载主配置文件（如果存在），以获取 REDIS_IMAGE_REGISTRY 等环境变量
# 主配置文件路径：../../deploy-redis.conf（相对于当前脚本目录）
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-redis.conf"
if [[ -f "$MAIN_CONFIG_FILE" ]]; then
    # 临时禁用错误退出，因为主配置文件可能包含一些在当前上下文中不适用的配置
    set +e
    source "$MAIN_CONFIG_FILE" 2>/dev/null
    set -e
    log_info "已加载主配置文件: $MAIN_CONFIG_FILE"
fi

# 加载配置文件（现在可以使用已设置的 CLUSTER 值和主配置文件中的环境变量）
CONFIG_FILE="$SCRIPT_DIR/deploy-harbor-registry-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
else
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 Harbor Registry Secret (Redis)..."
    
    # 1. 准备Docker认证Secret数据
    log_info "准备Docker认证Secret数据..."
    
    local prepare_args=(
        --server "${DOCKER_SERVER:-harbor.sunmoonai.local}"
        --username "$DOCKER_USERNAME"
        --password "$DOCKER_PASSWORD"
    )
    
    [[ -n "${DOCKER_EMAIL:-}" ]] && prepare_args+=(--email "$DOCKER_EMAIL")
    
    local temp_data_dir=$(prepare_docker_auth_secret_data "${prepare_args[@]}")
    if [[ $? -ne 0 ]] || [[ -z "$temp_data_dir" ]]; then
        log_error "Docker认证Secret数据准备失败"
        exit 1
    fi
    
    trap "rm -rf $temp_data_dir" EXIT
    
    # 2. 生成Docker Secret YAML
    local secret_yaml="$SECRET_DIR/harbor-registry-secret.yaml"
    
    log_info "生成Docker Secret YAML..."
    
    generate_docker_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --docker-config "$temp_data_dir/.dockerconfigjson" \
        --output "$secret_yaml"
    log_success "Secret YAML生成完成: $secret_yaml"
    
    if [[ "$dry_run" != "true" ]]; then
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
    fi
    
    log_success "Harbor Registry Secret (Redis) 部署完成！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

