#!/bin/bash

# =============================================================================
# Neo4j LLMOps DB Secret 部署脚本
# 文件名: deploy-neo4j-llmops-db-secret.sh
# 用途: 部署 Neo4j 图数据库连接信息 Secret 到 Kubernetes 集群
# 注意: 使用 resources/custom-values/generate.sh 生成的 YAML 文件
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # neo4j-llmops-db-secret 目录
# 计算项目根目录（应用根目录）
# 从 deploy-neo4j-llmops-db-secret/ 向上 3 级到达应用根目录
# deploy-neo4j-llmops-db-secret/ -> neo4j-llmops-db-secret/ -> secrets/ -> deploy-celeryworker-llmops/ -> celeryworker-llmops/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"


# 使用生成的 YAML 文件（由 resources/custom-values/generate.sh 生成）
CUSTOM_VALUES_DIR="$PROJECT_ROOT/resources/custom-values"
SECRET_YAML="$CUSTOM_VALUES_DIR/neo4j-llmops-db-secret-generated.yaml"

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

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 加载配置文件（现在可以使用已设置的 CLUSTER 值）
CONFIG_FILE="$SCRIPT_DIR/deploy-neo4j-llmops-db-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log_info "已加载配置: $CONFIG_FILE"
    
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

# 自动生成 YAML 文件的辅助函数（与主部署脚本保持一致）
auto_generate_yaml() {
    local yaml_file="$1"
    local custom_values_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        if [ -f "$custom_values_dir/generate.sh" ]; then
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
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 参数格式：<action> <project_id> <namespace> <environment>
    # 与 deploy-secrets-all.sh 和其他 secret 脚本保持一致
    local action="${1:-deploy}"
    local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    
    log_info "部署 Neo4j LLMOps DB Secret..."
    log_info "部署参数："
    log_info "  - 操作: $action"
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    echo ""
    
    export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"
    
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
                log_error "请先创建命名空间: kubectl create namespace $namespace"
                exit 1
            fi
            
            log_info "部署 Secret 到 Kubernetes 集群..."
            if kubectl apply -f "$SECRET_YAML" -n "$namespace"; then
                log_success "Secret 已部署: ${SECRET_NAME:-neo4j-llmops-db-secret} (命名空间: $namespace)"
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
            local secret_name="${SECRET_NAME:-neo4j-llmops-db-secret}"
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
    log_success "Neo4j LLMOps DB Secret 操作完成！"
    log_info "操作信息："
    log_info "  - 操作: $action"
    log_info "  - Secret 名称: ${SECRET_NAME:-neo4j-llmops-db-secret}"
    log_info "  - 命名空间: $namespace"
    log_info "  - YAML 文件: $SECRET_YAML"
    log_info "  - 完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "Neo4j LLMOps DB Secret 部署脚本"
    echo ""
    echo "用法:"
    echo "  $0 <deploy|uninstall|status|generate> [项目ID] [命名空间] [环境]"
    echo ""
    echo "操作:"
    echo "  deploy     部署 Secret 到 Kubernetes"
    echo "  uninstall  卸载 Secret"
    echo "  status     查看 Secret 状态"
    echo "  generate   仅生成 YAML 文件，不部署"
    echo ""
    echo "参数:"
    echo "  项目ID     项目标识符 (默认: $DEFAULT_PROJECT_ID)"
    echo "  命名空间   Kubernetes 命名空间 (默认: $DEFAULT_NAMESPACE)"
    echo "  环境       部署环境 (默认: $DEFAULT_ENVIRONMENT)"
    echo ""
    echo "示例:"
    echo "  $0 deploy                                          # 使用默认参数部署"
    echo "  $0 deploy sunmoonai app-platform-dev dev          # 指定参数部署"
    echo "  $0 status app-platform-dev                        # 查看状态"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-neo4j-llmops-db-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi
