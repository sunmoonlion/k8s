#!/bin/bash

# =============================================================================
# Harbor Registry Secret 部署脚本（Incubator BFF）
# 文件名: deploy-harbor-registry-secret.sh
# 用途: 部署 Harbor 镜像拉取 Secret 到 Kubernetes 集群
# 注意: 使用各组件自己的 generate-*.sh 生成的 YAML 文件
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # harbor-registry-secret 目录
# 计算项目根目录（应用根目录）
# 从 deploy-harbor-registry-secret/ 向上 3 级到达应用根目录
# deploy-harbor-registry-secret/ -> harbor-registry-secret/ -> secret/ -> deploy-incubator-backend/ -> incubator-app-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"


# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
HARBOR_SECRET_YAML="$K8S_RESOURCE_DIR/custom-values/secret/harbor-registry-secret/generate-harbor-registry-secret/harbor-registry-secret-generated.yaml"

# 调试：输出路径信息（如果需要）
# log_info "PROJECT_ROOT: $PROJECT_ROOT"
# log_info "CUSTOM_VALUES_DIR: $CUSTOM_VALUES_DIR"
# log_info "HARBOR_SECRET_YAML: $HARBOR_SECRET_YAML"

# 日志函数（如果未定义）
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" >&2; }
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

# 尝试加载主配置文件（如果存在），以获取 INCUBATOR_APP_BFF_IMAGE_REGISTRY 等环境变量
# 主配置文件路径：../../deploy-incubator-backend.conf（相对于当前脚本目录）
MAIN_CONFIG_FILE="$(cd "$SCRIPT_DIR/../../.." && pwd)/deploy-incubator-backend.conf"
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

# 默认配置从配置文件读取（deploy-harbor-registry-secret.conf）
# 如果配置文件未设置，则使用空值（由函数参数默认值处理）
DEFAULT_PROJECT_ID="${PROJECT_ID:-}"
DEFAULT_NAMESPACE="${NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

# 自动生成 YAML 文件的辅助函数
auto_generate_yaml() {
    local yaml_file="$1"
    local k8s_resource_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
        # 注意：这些变量应该从部署脚本的参数或配置中获取
        export NAMESPACE="${SECRET_NAMESPACE:-app-platform-dev}"
        export ENVIRONMENT="${ENVIRONMENT:-development}"
        export ENV="${ENV:-dev}"
        
        local generate_script="$k8s_resource_dir/custom-values/secret/harbor-registry-secret/generate-harbor-registry-secret/generate-harbor-registry-secret.sh"
        if [ -f "$generate_script" ]; then
            if bash "$generate_script"; then
                log_success "YAML 文件生成成功"
            else
                log_error "YAML 文件生成失败"
                return 1
            fi
        else
            log_error "生成脚本不存在: $generate_script"
            return 1
        fi
    fi
    return 0
}

main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 参数格式：<action> <project_id> <namespace> <environment>
    # 与 deploy-secrets-all.sh 和其他 secret 脚本保持一致
    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="false"
    
    # 对于非 deploy 操作，设置为试运行模式
    if [[ "$action" != "deploy" ]]; then
        dry_run="true"
    fi
    
    log_info "部署 Harbor Registry Secret (Incubator BFF)..."
    log_info "部署参数："
    log_info "  - 操作: $action"
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    echo ""
    
    # 1. 自动生成 YAML 文件（如果不存在）
    if ! auto_generate_yaml "$HARBOR_SECRET_YAML" "$K8S_RESOURCE_DIR"; then
        log_error "无法生成或找到 Harbor Registry Secret YAML 文件"
        exit 1
    fi
    
    # 2. 根据操作类型执行相应动作
    case "$action" in
        deploy)
            # 部署 Secret 到 Kubernetes
            log_info "部署 Secret 到 Kubernetes 集群..."
            
            # 检查命名空间是否存在
            if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
                log_error "命名空间不存在: $namespace"
                log_error "请先创建命名空间: kubectl create namespace $namespace"
                exit 1
            fi
            
            # 部署 Secret（使用生成的 YAML 文件）
            if kubectl apply -f "$HARBOR_SECRET_YAML" -n "$namespace"; then
                log_success "Secret 已部署: $SECRET_NAME (命名空间: $namespace)"
            else
                log_error "Secret 部署失败"
                exit 1
            fi
            ;;
        uninstall)
            log_info "卸载 Secret..."
            kubectl delete -f "$HARBOR_SECRET_YAML" -n "$namespace" --ignore-not-found
            log_success "Secret 卸载完成"
            ;;
        status)
            log_info "检查 Secret 状态..."
            kubectl get secret "$SECRET_NAME" -n "$namespace" 2>/dev/null || log_warn "Secret 不存在: $SECRET_NAME"
            ;;
        generate)
            log_success "YAML 文件已生成: $HARBOR_SECRET_YAML"
            ;;
        *)
            log_error "无效操作: $action"
            echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac
    
    # 3. 可选：重启相关组件（仅在 deploy 操作时）
    if [[ "$action" == "deploy" ]]; then
        if [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" ]]; then
            log_info "重启使用该 Secret 的组件..."
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
    
    echo ""
    log_success "Harbor Registry Secret (Incubator BFF) 操作完成！"
    log_info "操作信息："
    log_info "  - 操作: $action"
    log_info "  - Secret 名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - YAML 文件: $HARBOR_SECRET_YAML"
    log_info "  - 完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "Harbor Registry Secret 部署脚本 (Incubator BFF)"
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
    echo "  项目ID     项目标识符 (从配置文件 deploy-harbor-registry-secret.conf 读取)"
    echo "  命名空间   Kubernetes 命名空间 (从配置文件 deploy-harbor-registry-secret.conf 读取)"
    echo "  环境       部署环境 (从配置文件 deploy-harbor-registry-secret.conf 读取)"
    echo ""
    echo "示例:"
    echo "  $0 deploy                                          # 使用默认参数部署"
    echo "  $0 deploy sunmoonai app-platform-dev dev          # 指定参数部署"
    echo "  $0 status app-platform-dev                        # 查看状态"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-harbor-registry-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi


