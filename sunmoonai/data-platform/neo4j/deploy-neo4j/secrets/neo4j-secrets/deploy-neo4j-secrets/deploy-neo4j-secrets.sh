#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"


DEFAULT_PROJECT_ID="${DEFAULT_PROJECT_ID:-sunmoonai}"
DEFAULT_NAMESPACE="${DEFAULT_NAMESPACE:-data-platform-dev}"
DEFAULT_ENVIRONMENT="${DEFAULT_ENVIRONMENT:-development}"

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
    
    [[ -f "$SCRIPT_DIR/deploy-neo4j-secrets.conf" ]] && source "$SCRIPT_DIR/deploy-neo4j-secrets.conf"
    
    log_info "部署 Neo4j Secrets..."
    
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    [[ -n "${neo4j_password:-}" ]] && echo -n "${neo4j_password}" > "$temp_data_dir/neo4j-password"
    
    local secret_yaml="$SECRET_DIR/neo4j-secrets.yaml"
    
    generate_opaque_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Secret YAML生成完成: $secret_yaml"
    
    if [[ "$dry_run" != "true" ]]; then
        local _ns_err2
        _ns_err2=$(kubectl get namespace "$namespace" 2>&1)
        if [[ $? -ne 0 ]]; then
            if echo "$_ns_err2" | grep -qiE "not.?found|NotFound"; then
                log_error "命名空间不存在: $namespace"
                exit 1
            else
                log_warn "kubectl 连接失败，尝试自动重连后重试（${_ns_err2%%$'\n'*}）"
                if command -v setup_kubectl_environment >/dev/null 2>&1 && setup_kubectl_environment >/dev/null 2>&1; then
                    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
                        log_success "✅ 重连后命名空间 $namespace 已存在"
                    else
                        log_error "kubectl 连接失败，无法验证命名空间 $namespace"
                        exit 1
                    fi
                else
                    log_error "kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err2%%$'\n'*}）"
                    exit 1
                fi
            fi
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
    fi
    
    log_success "Neo4j Secrets 部署完成！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
