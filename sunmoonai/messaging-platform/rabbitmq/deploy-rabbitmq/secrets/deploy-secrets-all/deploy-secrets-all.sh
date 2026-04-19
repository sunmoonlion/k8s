#!/bin/bash

set -euo pipefail

# 计算脚本目录和项目根目录
RABBITMQ_SECRETS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 保存原始的脚本目录（unified-deployment-template.sh 会重新定义 SCRIPT_DIR）
ORIGINAL_SCRIPT_DIR="$RABBITMQ_SECRETS_SCRIPT_DIR"
SCRIPT_DIR="$RABBITMQ_SECRETS_SCRIPT_DIR"

# 自动检测项目根目录：
# 从当前目录向上查找，直到找到 utils/unified-deployment-template.sh
PROJECT_ROOT=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/unified-deployment-template.sh" ]]; then
        PROJECT_ROOT="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$PROJECT_ROOT" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/unified-deployment-template.sh），SCRIPT_DIR=$SCRIPT_DIR" >&2
    exit 1
fi

# 禁用自动清理，由主脚本负责清理（必须在 source 之前设置）
DISABLE_AUTO_CLEANUP=true

# 加载统一部署模板（提供日志函数和 Kubernetes 连接函数）
if [[ -f "$PROJECT_ROOT/utils/unified-deployment-template.sh" ]]; then
    set +e
    source "$PROJECT_ROOT/utils/unified-deployment-template.sh"
    source_exit_code=$?
    set -e
    
    if [[ $source_exit_code -ne 0 ]]; then
        echo "错误: 无法加载统一部署模板: $PROJECT_ROOT/utils/unified-deployment-template.sh (退出码: $source_exit_code)" >&2
        exit 1
    fi
    
    # 恢复原始的脚本目录
    SCRIPT_DIR="$ORIGINAL_SCRIPT_DIR"
    
    # 验证关键函数是否已加载
    if ! type setup_kubectl_environment >/dev/null 2>&1; then
        echo "错误: setup_kubectl_environment 函数未加载" >&2
        exit 1
    fi
    
    export -f setup_kubectl_environment 2>/dev/null || true
else
    # 如果模板不存在，定义基本的日志函数
    log_info() { echo -e "[INFO] $*"; }
    log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
    log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
    log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="messaging-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）

# 先解析命令行参数（如果提供）
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载 Secrets 部署配置文件
SECRETS_CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"
if [[ -f "$SECRETS_CONFIG_FILE" ]]; then
    source "$SECRETS_CONFIG_FILE"
    
    # 加载集群配置映射函数
    if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
        source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
        if ! type setup_kubectl_environment >/dev/null 2>&1; then
            log_warn "⚠️  setup_kubectl_environment 函数在加载 cluster-config-mapping.sh 后丢失，尝试重新加载"
            if [[ -f "$PROJECT_ROOT/utils/unified-deployment-template.sh" ]]; then
                set +e
                source "$PROJECT_ROOT/utils/unified-deployment-template.sh" >/dev/null 2>&1
                set -e
            fi
        fi
        export -f setup_kubectl_environment 2>/dev/null || true
        if ! type setup_kubectl_environment >/dev/null 2>&1; then
            log_error "❌ setup_kubectl_environment 函数不存在，请检查 unified-deployment-template.sh 是否已正确加载"
            exit 1
        fi
    fi
    
    log_info "已加载 Secrets 配置文件: $SECRETS_CONFIG_FILE"
else
    log_error "缺少 Secrets 配置文件: $SECRETS_CONFIG_FILE"
    exit 1
fi

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_warn "⚠️  Kubernetes 连接不可用，跳过命名空间检查"
        return 0
    fi
    
    local _ns_err
    _ns_err=$(kubectl get namespace "$namespace" 2>&1)
    if [[ $? -eq 0 ]]; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    elif echo "$_ns_err" | grep -qiE "not.?found|NotFound"; then
        log_error "❌ 命名空间 $namespace 不存在！"
        return 1
    else
        log_warn "kubectl 连接失败，尝试自动重连后重试（${_ns_err%%$'\n'*}）"
        if command -v setup_kubectl_environment >/dev/null 2>&1 && setup_kubectl_environment >/dev/null 2>&1; then
            if kubectl get namespace "$namespace" >/dev/null 2>&1; then
                log_success "✅ 重连后命名空间 $namespace 已存在"
                return 0
            fi
        fi
        log_error "❌ kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err%%$'\n'*}）"
        log_error "请检查 KUBECONFIG 和集群连接状态"
        return 1
    fi
}

# 部署子级组件（按优先级）
deploy_sub_components_by_priority() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "🔧 开始部署子级组件..."
    
    # 定义组件部署信息（组件名:启用标志:优先级:描述:脚本路径）
    local components=(
        "rabbitmq_auth_secret:${rabbitmq_auth_secret_enabled:-true}:${rabbitmq_auth_secret_priority:-1000}:RabbitMQ 认证密钥:$SCRIPT_DIR/../rabbitmq-auth-secret/deploy-rabbitmq-auth-secret/deploy-rabbitmq-auth-secret.sh"
        "harbor_registry_secret:${harbor_registry_secret_enabled:-true}:${harbor_registry_secret_priority:-800}:Harbor 镜像拉取密钥:$SCRIPT_DIR/../harbor-registry-secret/deploy-harbor-registry-secret/deploy-harbor-registry-secret.sh"
    )
    
    # 先过滤出启用的组件，然后按优先级排序
    local enabled_components=()
    local disabled_components=()
    
    for component_info in "${components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            enabled_components+=("$component_info")
        else
            disabled_components+=("$component_info")
        fi
    done
    
    # 根据启用组件数量决定是否进行优先级排序
    if [[ ${#enabled_components[@]} -gt 1 ]]; then
        IFS=$'\n' sorted_enabled_components=($(printf '%s\n' "${enabled_components[@]}" | sort -t: -k3 -nr))
        log_info "📋 子级组件部署顺序（按优先级排序）："
        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 子级组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        sorted_enabled_components=()
        log_info "📋 子级组件部署顺序：无启用的组件"
    fi
    
    # 显示禁用的组件
    if [[ ${#disabled_components[@]} -gt 0 ]]; then
        log_info "  ⏭️  禁用的组件："
        for component_info in "${disabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "    $description (${name}_enabled=false)"
        done
    fi
    
    # 部署启用的组件
    for component_info in "${sorted_enabled_components[@]}"; do
        IFS=':' read -r name enabled priority description script_path <<< "$component_info"
        
        if [[ ${#enabled_components[@]} -gt 1 ]]; then
            log_info "🚀 部署 $description (优先级: $priority)..."
        else
            log_info "🚀 部署 $description..."
        fi
        
        if [[ -f "$script_path" ]]; then
            local original_dir="$(pwd)"
            cd "$(dirname "$script_path")"
            
            if env KUBECONFIG="${KUBECONFIG:-}" ./"$(basename "$script_path")" "$project_id" "$namespace" "$environment" "$dry_run"; then
                log_success "✅ $description 部署成功"
            else
                log_error "❌ $description 部署失败"
                cd "$original_dir"
                return 1
            fi
            
            cd "$original_dir"
        else
            log_warn "⚠️  $description 部署脚本不存在: $script_path"
        fi
    done
    
    log_success "✅ 子级组件部署完成！"
}

# 主部署函数
deploy_secrets() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "🚀 开始部署 RabbitMQ Secrets..."
    log_info "📋 部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    log_info ""
    
    # 确保 Kubernetes 连接已建立
    if ! type setup_kubectl_environment >/dev/null 2>&1; then
        log_warn "⚠️  setup_kubectl_environment 函数不存在，尝试重新加载 unified-deployment-template.sh"
        if [[ -f "$PROJECT_ROOT/utils/unified-deployment-template.sh" ]]; then
            set +e
            source "$PROJECT_ROOT/utils/unified-deployment-template.sh" >/dev/null 2>&1
            source_exit_code=$?
            set -e
            
            if [[ $source_exit_code -ne 0 ]]; then
                log_error "❌ 无法加载统一部署模板"
                return 1
            fi
            export -f setup_kubectl_environment 2>/dev/null || true
        else
            log_error "❌ 统一部署模板文件不存在"
            return 1
        fi
        
        if ! type setup_kubectl_environment >/dev/null 2>&1; then
            log_error "❌ setup_kubectl_environment 函数不存在"
            return 1
        fi
    fi
    
    if ! setup_kubectl_environment; then
        log_error "❌ 无法建立 Kubernetes 连接"
        return 1
    fi
    
    if ! check_namespace "$namespace"; then
        return 1
    fi
    
    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "🎉 RabbitMQ Secrets 部署完成！"
}

show_help() {
    echo "RabbitMQ Secrets All 部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 [项目ID] [命名空间] [环境] [试运行]"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: $DEFAULT_PROJECT_ID)"
    echo "  命名空间   Kubernetes 命名空间 (默认: $DEFAULT_NAMESPACE)"
    echo "  环境       部署环境 (默认: $DEFAULT_ENVIRONMENT)"
    echo "  试运行     是否试运行 (默认: false)"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认参数"
    echo "  $0 sunmoonai messaging-platform-dev dev   # 指定参数"
    echo ""
    echo "配置文件: $SECRETS_CONFIG_FILE"
}

main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" ]]; then
        shift
    fi
    
    deploy_secrets "$@"
}

main "$@"

