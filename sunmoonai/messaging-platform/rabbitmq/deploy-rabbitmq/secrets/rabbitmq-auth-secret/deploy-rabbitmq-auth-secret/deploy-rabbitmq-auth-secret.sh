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

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="messaging-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 加载配置文件（现在可以使用已设置的 CLUSTER 值）
CONFIG_FILE="$SCRIPT_DIR/deploy-rabbitmq-auth-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载配置文件: $CONFIG_FILE"
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
    
    log_info "部署 RabbitMQ Auth Secret..."
    
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    [[ -n "${rabbitmq_username:-}" ]] && echo -n "${rabbitmq_username}" > "$temp_data_dir/rabbitmq-username"
    [[ -n "${rabbitmq_password:-}" ]] && echo -n "${rabbitmq_password}" > "$temp_data_dir/rabbitmq-password"
    [[ -n "${rabbitmq_erlang_cookie:-}" ]] && echo -n "${rabbitmq_erlang_cookie}" > "$temp_data_dir/rabbitmq-erlang-cookie"
    
    local secret_yaml="$SECRET_DIR/rabbitmq-auth-secret.yaml"
    
    generate_opaque_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Secret YAML生成完成: $secret_yaml"
    
    if [[ "$dry_run" != "true" ]]; then
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "命名空间不存在: $namespace"
            exit 1
        fi
        
        # 仅在 Secret 原本存在且内容变化时重启组件，避免每次重新部署都触发 Pod Terminating。
        # 注意：首次创建 Secret 时，kubectl get secret 会返回非 0，但这里放在 if 流程中不会触发 set -e 退出。
        local secret_hash_before=""
        local secret_data_before=""
        if secret_data_before=$(kubectl get secret "$SECRET_NAME" -n "$namespace" -o jsonpath='{.data}' 2>/dev/null); then
            secret_hash_before=$(printf '%s\n' "$secret_data_before" | sort | md5sum 2>/dev/null | awk '{print $1}')
        fi
        
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret已部署: $SECRET_NAME (命名空间: $namespace)"
        else
            log_error "Secret部署失败"
            exit 1
        fi
        
        local secret_hash_after=""
        secret_hash_after=$(kubectl get secret "$SECRET_NAME" -n "$namespace" -o jsonpath='{.data}' 2>/dev/null | sort | md5sum 2>/dev/null | awk '{print $1}')
        # 仅当 Secret 原本已存在且内容发生变化时才重启（首次创建不重启，避免第一次部署就出现 Terminating）。
        local need_restart="false"
        if [[ -n "$secret_hash_before" && "$secret_hash_before" != "$secret_hash_after" ]]; then
            need_restart="true"
        fi
        
        if [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" && "$need_restart" == "true" ]]; then
            log_info "Secret 内容已变化，重启使用该 Secret 的组件..."
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
        elif [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" && "$need_restart" == "false" ]]; then
            log_info "Secret 内容未变化，跳过重启组件（避免不必要的 Pod Terminating）"
        fi
    fi
    
    log_success "RabbitMQ Auth Secret 部署完成！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

