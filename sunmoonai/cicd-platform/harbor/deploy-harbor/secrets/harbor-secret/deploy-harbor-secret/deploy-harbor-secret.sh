#!/bin/bash

# =============================================================================
# Harbor Secret 部署脚本
# 文件名: deploy-harbor-secret.sh
# 用途: 生成并部署Harbor Opaque Secret到Kubernetes集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # harbor-secret 目录
# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"


# 加载Secret生成核心函数
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

# 日志函数（如果未定义）
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="cicd-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 加载配置（现在可以使用已设置的 CLUSTER 值）
source "$SCRIPT_DIR/deploy-harbor-secret.conf"

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
    
    log_info "部署 Harbor Secret..."
    log_info "部署参数："
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    log_info "  - 试运行: $dry_run"
    echo ""
    
    # 1. 准备Opaque Secret数据
    # Opaque Secret使用动态键名，从配置中读取所有数据键
    log_info "准备Opaque Secret数据..."
    
    # 创建临时数据目录
    local temp_data_dir=$(mktemp -d)
    trap "rm -rf $temp_data_dir" EXIT
    
    # 从配置中提取数据键（直接使用配置文件中定义的键）
    # 系统配置项
    local system_keys=("SECRET_NAME" "SECRET_NAMESPACE" "SECRET_TYPE" "RESTART_COMPONENTS" "RESTART_PRIORITY" "RESTART_COMPONENTS_LIST")
    
    # 添加Harbor配置数据
    if [[ -n "${HARBOR_ADMIN_USERNAME:-}" ]]; then
        echo -n "${HARBOR_ADMIN_USERNAME}" > "$temp_data_dir/HARBOR_ADMIN_USERNAME"
        log_info "添加数据键: HARBOR_ADMIN_USERNAME"
    fi
    
    if [[ -n "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
        echo -n "${HARBOR_ADMIN_PASSWORD}" > "$temp_data_dir/HARBOR_ADMIN_PASSWORD"
        log_info "添加数据键: HARBOR_ADMIN_PASSWORD"
    fi
    
    # 2. 生成Opaque Secret YAML
    local secret_yaml="$SECRET_DIR/harbor-secret.yaml"
    
    log_info "生成Opaque Secret YAML..."
    generate_opaque_secret_yaml \
        --name "$SECRET_NAME" \
        --namespace "$namespace" \
        --data-dir "$temp_data_dir" \
        --output "$secret_yaml"
    
    log_success "Opaque Secret YAML生成完成: $secret_yaml"
    
    # 3. 部署Secret到Kubernetes（由底层脚本负责）
    if [[ "$dry_run" != "true" ]]; then
        log_info "部署Secret到Kubernetes集群..."
        
        # 检查命名空间是否存在
        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_error "命名空间不存在: $namespace"
            log_error "请先创建命名空间: kubectl create namespace $namespace"
            exit 1
        fi
        
        # 部署Secret
        if kubectl apply -f "$secret_yaml"; then
            log_success "Secret已部署: $SECRET_NAME (命名空间: $namespace)"
        else
            log_error "Secret部署失败"
            exit 1
        fi
        
        # 4. 可选：重启相关组件（如果配置了）
        if [[ "${RESTART_COMPONENTS:-false}" == "true" ]]; then
            log_info "重启使用该Secret的组件..."
            if [[ -n "${RESTART_COMPONENTS_LIST:-}" ]]; then
                IFS=',' read -ra COMPONENTS <<< "${RESTART_COMPONENTS_LIST}"
                for component in "${COMPONENTS[@]}"; do
                    component=$(echo "$component" | xargs)  # 去除空格
                    if [[ -n "$component" ]]; then
                        log_info "重启组件: $component"
                        if kubectl rollout restart deployment/"$component" -n "$namespace" 2>/dev/null; then
                            log_success "组件 $component 重启命令已执行"
                        elif kubectl rollout restart statefulset/"$component" -n "$namespace" 2>/dev/null; then
                            log_success "组件 $component 重启命令已执行"
                        else
                            log_warn "组件 $component 不存在或重启失败"
                        fi
                    fi
                done
            else
                log_warn "RESTART_COMPONENTS=true 但未配置 RESTART_COMPONENTS_LIST，跳过重启"
            fi
        fi
    else
        log_info "[试运行] 将部署Secret: $SECRET_NAME"
        log_info "[试运行] YAML文件: $secret_yaml"
    fi
    
    echo ""
    log_success "Harbor Secret 部署完成！"
    log_info "部署信息："
    log_info "  - Secret名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "Harbor Secret 部署脚本"
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
    echo "  $0 sunmoonai cicd-platform-dev dev   # 指定参数"
    echo "  $0 sunmoonai cicd-platform-dev dev true # 试运行模式"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-harbor-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 检查参数
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    # 执行部署
    main "$@"
fi
