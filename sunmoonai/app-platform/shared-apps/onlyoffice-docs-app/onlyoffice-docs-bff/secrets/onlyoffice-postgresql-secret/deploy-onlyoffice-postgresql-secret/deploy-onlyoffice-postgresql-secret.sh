#!/bin/bash

# =============================================================================
# ONLYOFFICE PostgreSQL Secret 部署脚本
# 文件名: deploy-onlyoffice-postgresql-secret.sh
# 用途: 部署 ONLYOFFICE Docs 连接 PostgreSQL 的认证 Secret
# 注意: 使用 resources/custom-values/generate.sh 生成的 YAML 文件
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"
# 计算项目根目录（应用根目录）
# 从 deploy-onlyoffice-postgresql-secret/ 向上 3 级到达应用根目录
# deploy-onlyoffice-postgresql-secret/ -> onlyoffice-postgresql-secret/ -> secrets/ -> onlyoffice-docs-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由 resources/custom-values/generate.sh 生成）
CUSTOM_VALUES_DIR="$PROJECT_ROOT/resources/custom-values"
SECRET_YAML="$CUSTOM_VALUES_DIR/onlyoffice-postgresql-secret-generated.yaml"

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
CONFIG_FILE="$SCRIPT_DIR/deploy-onlyoffice-postgresql-secret.conf"
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

# 自动生成 YAML 文件的辅助函数（与主部署脚本保持一致）
auto_generate_yaml() {
    local yaml_file="$1"
    local custom_values_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        if [ -f "$custom_values_dir/generate.sh" ]; then
            # 检查必需的密码是否已设置
            if [[ -z "${POSTGRESQL_PASSWORD:-}" ]]; then
                log_error "PostgreSQL 密码未配置！"
                log_error "请在配置文件中设置 POSTGRESQL_PASSWORD"
                log_error "配置文件: $CONFIG_FILE"
                return 1
            fi
            if bash "$custom_values_dir/generate.sh"; then
                log_success "YAML 文件生成成功"
            else
                log_error "YAML 文件生成失败"
                return 1
            fi
        else
            log_error "生成脚本不存在: $custom_values_dir/generate.sh"
            return 1
        fi
    fi
    return 0
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 参数格式：<action> <project_id> <namespace> <environment>
    # 与 deploy-secrets-all.sh 和其他 secret 脚本保持一致
    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    
    log_info "部署 ONLYOFFICE PostgreSQL Secret..."
    log_info "部署参数："
    log_info "  - 操作: $action"
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    echo ""
    
    export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"
    
    # 检查必需的密码是否已设置
    if [[ -z "${POSTGRESQL_PASSWORD:-}" ]]; then
        log_error "PostgreSQL 密码未配置！"
        log_error "请在配置文件中设置 POSTGRESQL_PASSWORD"
        log_error "配置文件: $CONFIG_FILE"
        exit 1
    fi
    
    # 1. 自动生成 YAML 文件（如果不存在）
    if ! auto_generate_yaml "$SECRET_YAML" "$CUSTOM_VALUES_DIR"; then
        log_error "无法生成或找到 Secret YAML 文件"
        exit 1
    fi
    
    # 2. 根据操作类型执行相应动作
    case "$action" in
        deploy)
            # 检查命名空间是否存在
            if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
                log_error "命名空间不存在: $namespace"
                exit 1
            fi
            
            log_info "部署 Secret 到 Kubernetes 集群..."
            if kubectl apply -f "$SECRET_YAML" -n "$namespace"; then
                log_success "Secret 已部署: ${SECRET_NAME:-onlyoffice-postgresql-secret} (命名空间: $namespace)"
            else
                log_error "Secret 部署失败"
                exit 1
            fi
            ;;
        uninstall)
            log_info "卸载 Secret..."
            kubectl delete -f "$SECRET_YAML" -n "$namespace" --ignore-not-found
            log_success "Secret 卸载完成"
            ;;
        status)
            log_info "检查 Secret 状态..."
            local secret_name="${SECRET_NAME:-onlyoffice-postgresql-secret}"
            kubectl get secret "$secret_name" -n "$namespace" 2>/dev/null || log_warn "Secret 不存在: $secret_name"
            ;;
        generate)
            log_success "YAML 文件已生成: $SECRET_YAML"
            ;;
        *)
            log_error "无效操作: $action"
            echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "ONLYOFFICE PostgreSQL Secret 操作完成！"
    log_info "操作信息："
    log_info "  - 操作: $action"
    log_info "  - Secret 名称: ${SECRET_NAME:-onlyoffice-postgresql-secret}"
    log_info "  - 命名空间: $namespace"
    log_info "  - YAML 文件: $SECRET_YAML"
    log_info "  - 完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
