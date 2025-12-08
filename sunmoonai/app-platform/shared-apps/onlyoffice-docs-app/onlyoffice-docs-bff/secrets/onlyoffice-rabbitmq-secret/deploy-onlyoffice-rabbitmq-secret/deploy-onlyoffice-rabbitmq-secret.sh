#!/bin/bash

# =============================================================================
# ONLYOFFICE RabbitMQ Secret 部署脚本
# 文件名: deploy-onlyoffice-rabbitmq-secret.sh
# 用途: 从 RabbitMQ Secret 获取密码并创建 ONLYOFFICE Docs 的 RabbitMQ 连接 Secret
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"
# 计算项目根目录（k8s目录）
# 从 deploy-onlyoffice-rabbitmq-secret/ 向上6级到达 k8s/
# deploy-onlyoffice-rabbitmq-secret/ -> onlyoffice-rabbitmq-secret/ -> secrets/ -> onlyoffice-docs/ -> app-platform/ -> sunmoonai/ -> k8s/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../" && pwd)"

source "$PROJECT_ROOT/utils/secret-management/lib/secret-core.sh"

# 解析命令行参数
declare -a PARSED_ARGS

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
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
            apply_cluster_config_mapping "$cluster_value"
        fi
    fi
}

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 尝试加载主配置文件
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-onlyoffice-docs/deploy-onlyoffice-docs.conf"
if [[ -f "$MAIN_CONFIG_FILE" ]]; then
    set +e
    source "$MAIN_CONFIG_FILE" 2>/dev/null
    set -e
    log_info "已加载主配置文件: $MAIN_CONFIG_FILE"
fi

# 加载配置文件
CONFIG_FILE="$SCRIPT_DIR/deploy-onlyoffice-rabbitmq-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
else
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "部署 ONLYOFFICE RabbitMQ Secret..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 1. 从配置文件获取密码
    log_info "从配置文件获取 RabbitMQ 密码..."
    
    if [[ -z "${RABBITMQ_PASSWORD:-}" ]]; then
        log_error "RabbitMQ 密码未配置！"
        log_error "请在配置文件中设置 RABBITMQ_PASSWORD"
        log_error "配置文件: $CONFIG_FILE"
        log_error ""
        log_error "示例："
        log_error "  RABBITMQ_PASSWORD=\"your_rabbitmq_password\""
        exit 1
    fi
    
    local password="$RABBITMQ_PASSWORD"
    log_success "已从配置文件获取 RabbitMQ 密码"
    log_warn "⚠️  请确保此密码与 RabbitMQ 部署时使用的密码保持一致！"
    
    # 2. 生成 Secret YAML
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    echo -n "$password" > "$temp_data_dir/${TARGET_SECRET_KEY}"
    
    local secret_yaml="$SECRET_DIR/onlyoffice-rabbitmq-secret.yaml"
    
    log_info "生成 Secret YAML..."
    
    generate_opaque_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Secret YAML生成完成: $secret_yaml"
    
    # 3. 部署 Secret 到 Kubernetes（集群2）
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署 Secret 到 Kubernetes 集群..."
        
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
    else
        log_info "[试运行] 将部署Secret: $SECRET_NAME"
        log_info "[试运行] YAML文件: $secret_yaml"
    fi
    
    echo ""
    log_success "ONLYOFFICE RabbitMQ Secret 部署完成！"
    log_info "部署信息："
    log_info "  - Secret名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

