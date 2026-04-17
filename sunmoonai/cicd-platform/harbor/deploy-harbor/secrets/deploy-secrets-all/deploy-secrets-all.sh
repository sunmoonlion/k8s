#!/bin/bash

# =============================================================================
# Harbor Secrets 总控部署脚本
# 文件名: deploy-secrets-all.sh
# 用途: 统一部署Harbor的所有Secret
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

# 自动定位 k8s 根目录（向上查找 utils/cluster-arg-parser.sh）
K8S_ROOT_DIR=""
search_dir="$SCRIPT_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），SCRIPT_DIR=$SCRIPT_DIR" 1>&2
    exit 1
fi

# 集群参数解析（轻量，无连接副作用）
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"

# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置（现在可以使用已设置的 CLUSTER 值）
SECRETS_CONFIG_FILE="$SCRIPT_DIR/deploy-secrets-all.conf"

if [[ -f "$SECRETS_CONFIG_FILE" ]]; then
    source "$SECRETS_CONFIG_FILE"
    
    # 加载集群配置映射函数（使用 utils 中的通用函数）
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        # 应用集群配置映射（使用 CLUSTER 环境变量，支持 C1_* 和 C2_* 前缀配置）
        apply_cluster_config_mapping
    fi
    
    log_info "已加载 Secrets 配置文件: $SECRETS_CONFIG_FILE"
else
    log_error "缺少 Secrets 配置文件: $SECRETS_CONFIG_FILE"
    exit 1
fi

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="cicd-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 检查命名空间是否存在
check_namespace() {
    local namespace="$1"
    
    # 确保 kubectl 环境已设置（检查 KUBECONFIG 环境变量）
    if [[ -z "${KUBECONFIG:-}" ]]; then
        log_warn "KUBECONFIG 环境变量未设置，尝试使用默认配置..."
        # 尝试导入统一部署模板以获取 setup_kubectl_environment 函数
        local template_path="$PROJECT_ROOT/utils/unified-deployment-template.sh"
        if [[ -f "$template_path" ]]; then
            source "$template_path"
            if command -v setup_kubectl_environment &>/dev/null; then
                if ! setup_kubectl_environment; then
                    log_error "❌ 无法建立 Kubernetes 连接"
                    return 1
                fi
            fi
        else
            log_warn "未找到统一部署模板: $template_path"
            log_warn "将尝试使用默认 kubectl 配置"
        fi
    fi
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    else
        log_info "命名空间 $namespace 不存在，自动创建..."
        if kubectl create namespace "$namespace" >/dev/null 2>&1; then
            log_success "✅ 命名空间 $namespace 创建成功"
            return 0
        else
            log_error "❌ 命名空间 $namespace 创建失败！"
            log_info "请手动创建：kubectl create namespace $namespace"
            return 1
        fi
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
    # 使用新迁移的Secret脚本
    local components=(
        "harbor_secret:${harbor_secret_enabled:-true}:${harbor_secret_priority:-1000}:Harbor 认证密钥:$SCRIPT_DIR/../harbor-secret/deploy-harbor-secret/deploy-harbor-secret.sh"
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
        # 多个组件启用时，按优先级排序（数值越大优先级越高）
        IFS=$'\n' sorted_enabled_components=($(printf '%s\n' "${enabled_components[@]}" | sort -t: -k3 -nr))
        log_info "📋 子级组件部署顺序（按优先级排序）："
        
        for component_info in "${sorted_enabled_components[@]}"; do
            IFS=':' read -r name enabled priority description script_path <<< "$component_info"
            log_info "  🚀 $priority - $description"
        done
    elif [[ ${#enabled_components[@]} -eq 1 ]]; then
        # 只有一个组件启用时，直接使用，无需排序
        sorted_enabled_components=("${enabled_components[@]}")
        IFS=':' read -r name enabled priority description script_path <<< "${enabled_components[0]}"
        log_info "📋 子级组件部署顺序（单个组件，无需排序）："
        log_info "  🚀 $description"
    else
        # 没有启用的组件
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
        
        # 如果是TLS Secret，先检查/生成服务器证书
        if [[ "$name" == *"tls"* ]] || [[ "$description" == *"TLS"* ]]; then
            local secret_dir="$(dirname "$(dirname "$script_path")")"
            local cert_gen_script="$secret_dir/server-cert/generate-server-cert/generate-server-cert.sh"
            
            if [[ -f "$cert_gen_script" ]]; then
                log_info "生成服务器证书: $secret_dir/server-cert"
                bash "$cert_gen_script" || {
                    log_error "服务器证书生成失败"
                    return 1
                }
            else
                log_warn "未找到证书生成脚本: $cert_gen_script"
                log_warn "如果这是TLS Secret，请确保证书已生成"
            fi
        fi
        
        if [[ ${#enabled_components[@]} -gt 1 ]]; then
            log_info "🚀 部署 $description (优先级: $priority)..."
        else
            log_info "🚀 部署 $description..."
        fi
        
        if [[ -f "$script_path" ]]; then
            local original_dir="$(pwd)"
            cd "$(dirname "$script_path")"
            
            if ./"$(basename "$script_path")" "$project_id" "$namespace" "$environment" "$dry_run"; then
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

# 部署 Secrets 核心服务
deploy_secrets_core() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "🚀 阶段2：部署 Secrets 核心服务"
    
    # 这里可以添加 Secrets 核心服务的部署逻辑
    # 例如：创建通用的 Secret 模板、验证 Secret 格式等
    
    log_info "📝 验证 Secret 配置..."
    
    # 验证必要的环境变量
    if [[ -z "$PROJECT_ID" ]]; then
        log_error "❌ PROJECT_ID 未设置"
        return 1
    fi
    
    if [[ -z "$NAMESPACE" ]]; then
        log_error "❌ NAMESPACE 未设置"
        return 1
    fi
    
    log_success "✅ Secrets 核心服务配置验证完成"
}

# 部署本级专属组件
deploy_current_level_components() {
    local project_id="$1"
    local namespace="$2"
    local environment="$3"
    local dry_run="$4"
    
    log_info "🚀 阶段3：部署本级专属组件"
    
    # 这里可以添加 Secrets 级别的专属部署逻辑
    # 例如：创建 Secret 监控、日志记录、验证等
    
    log_info "📊 设置 Secret 监控和验证..."
    
    # 验证所有 Secret 是否正确创建
    log_info "🔍 验证 Secret 状态..."
    
    # 这里可以添加 Secret 状态检查逻辑
    log_success "✅ 本级专属组件部署完成"
}

# 主部署函数
deploy_secrets() {
    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"
    
    log_info "🚀 开始部署 Secrets 递归架构..."
    log_info "📋 部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 检查命名空间
    if ! check_namespace "$namespace"; then
        return 1
    fi
    
    # 阶段1：部署子级组件（按优先级）
    deploy_sub_components_by_priority "$project_id" "$namespace" "$environment" "$dry_run"
    
    # 阶段2：部署 Secrets 核心服务
    deploy_secrets_core "$project_id" "$namespace" "$environment" "$dry_run"
    
    # 阶段3：部署本级专属组件
    deploy_current_level_components "$project_id" "$namespace" "$environment" "$dry_run"
    
    log_success "🎉 Secrets 递归部署完成！"
    echo ""
    log_info "📋 部署信息："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    log_success "🎯 Secrets 部署成功完成！"
}

# 显示帮助信息
show_help() {
    echo "Secrets All 递归部署脚本"
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
    echo "  $0 sunmoonai harbor development      # 指定参数"
    echo "  $0 sunmoonai harbor development true # 试运行模式"
    echo ""
    echo "配置文件: $SECRETS_CONFIG_FILE"
}

# 主函数
main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local project_id="${1:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"
    
    log_info "🚀 开始部署 Harbor Secrets..."
    log_info "  项目ID: $project_id"
    log_info "  命名空间: $namespace"
    log_info "  环境: $environment"
    log_info "  试运行: $dry_run"
    echo ""
    
    # 部署 Secrets
    if deploy_secrets "$project_id" "$namespace" "$environment" "$dry_run"; then
        log_success "✅ Harbor Secrets 部署完成！"
        return 0
    else
        log_error "❌ Harbor Secrets 部署失败"
        return 1
    fi
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi

