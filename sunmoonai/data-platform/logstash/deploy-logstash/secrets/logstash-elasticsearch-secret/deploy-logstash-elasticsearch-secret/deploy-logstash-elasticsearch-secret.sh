#!/bin/bash

# =============================================================================
# Logstash Elasticsearch Secret 部署脚本
# 文件名: deploy-logstash-elasticsearch-secret.sh
# 用途: 生成并部署Logstash连接Elasticsearch的认证Secret到Kubernetes集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"
# 计算项目根目录（k8s目录）
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
    
    log_info "部署 Logstash Elasticsearch Secret..."
    
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    [[ -n "${ES_HOST:-}" ]] && echo -n "${ES_HOST}" > "$temp_data_dir/ES_HOST"
    [[ -n "${ES_PORT:-}" ]] && echo -n "${ES_PORT}" > "$temp_data_dir/ES_PORT"
    [[ -n "${ES_USERNAME:-}" ]] && echo -n "${ES_USERNAME}" > "$temp_data_dir/ES_USERNAME"
    [[ -n "${ES_PASSWORD:-}" ]] && echo -n "${ES_PASSWORD}" > "$temp_data_dir/ES_PASSWORD"
    [[ -n "${ES_TLS:-}" ]] && echo -n "${ES_TLS}" > "$temp_data_dir/ES_TLS"
    
    local secret_yaml="$SECRET_DIR/logstash-elasticsearch-secret.yaml"
    
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
    fi
    
    log_success "Logstash Elasticsearch Secret 部署完成！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

