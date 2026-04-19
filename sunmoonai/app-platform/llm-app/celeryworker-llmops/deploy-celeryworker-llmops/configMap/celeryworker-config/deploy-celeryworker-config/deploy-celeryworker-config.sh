#!/bin/bash

# =============================================================================
# Celery Worker ConfigMap 部署脚本
# 文件名: deploy-celeryworker-config.sh
# 用途: 部署 Celery Worker ConfigMap 到 Kubernetes 集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-celeryworker-config.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-celeryworker-config/ 向上 3 级到达应用根目录
# deploy-celeryworker-config/ -> celeryworker-config/ -> secrets/ -> deploy-celeryworker-llmops/ -> celeryworker-llmops/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
source "$PROJECT_ROOT/utils/cluster-arg-parser.sh"


# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
CONFIGMAP_YAML="$K8S_RESOURCE_DIR/custom-values/configMap/celeryworker-config/generate-celeryworker-config/celeryworker-config-generated.yaml"

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
    log_warn "配置文件不存在: $CONFIG_FILE，使用默认配置"
fi

# 自动生成 YAML 文件的辅助函数
auto_generate_yaml() {
    local yaml_file="$1"
    local k8s_resource_dir="$2"
    
    if [ ! -f "$yaml_file" ]; then
        log_warn "生成的 YAML 文件不存在: $yaml_file，自动运行生成脚本..."
        # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
        export NAMESPACE="${NAMESPACE:-app-platform-dev}"
        export ENVIRONMENT="${ENVIRONMENT:-development}"
        export ENV="${ENV:-dev}"
        
        local generate_script="$k8s_resource_dir/custom-values/configMap/celeryworker-config/generate-celeryworker-config/generate-celeryworker-config.sh"
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
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    # 参数格式：<action> <project_id> <namespace> <environment>
    # 与 deploy-secrets-all.sh 和其他 secret 脚本保持一致
    local action="${1:-deploy}"
    local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    
    log_info "部署 Celery Worker ConfigMap..."
    log_info "部署参数："
    log_info "  - 操作: $action"
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    echo ""
    
    export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"
    
  # 1. 自动生成 YAML 文件（如果不存在）
  if ! auto_generate_yaml "$CONFIGMAP_YAML" "$K8S_RESOURCE_DIR"; then
    log_error "无法生成或找到 ConfigMap YAML 文件"
    exit 1
  fi
    
    # 2. 部署或卸载
    case "$action" in
        deploy)
            # 检查命名空间是否存在
            local _ns_err3
            _ns_err3=$(kubectl get namespace "$namespace" 2>&1)
            if [[ $? -ne 0 ]]; then
                if echo "$_ns_err3" | grep -qiE "not.?found|NotFound"; then
                    log_error "命名空间不存在: $namespace"
                    log_error "请先创建命名空间: kubectl create namespace $namespace"
                    exit 1
                else
                    log_warn "kubectl 连接失败，尝试自动重连后重试（${_ns_err3%%$'\n'*}）"
                    if command -v setup_kubectl_environment >/dev/null 2>&1 && setup_kubectl_environment >/dev/null 2>&1; then
                        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
                            log_success "✅ 重连后命名空间 $namespace 已存在"
                        else
                            log_error "kubectl 连接失败，无法验证命名空间 $namespace"
                            exit 1
                        fi
                    else
                        log_error "kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err3%%$'\n'*}）"
                        exit 1
                    fi
                fi
            fi
            
            log_info "部署 ConfigMap 到 Kubernetes 集群..."
            if kubectl apply -f "$CONFIGMAP_YAML" -n "$namespace"; then
                log_success "ConfigMap 已部署: ${CONFIGMAP_NAME:-celeryworker-config} (命名空间: $namespace)"
            else
                log_error "ConfigMap 部署失败"
                exit 1
            fi
            ;;
        uninstall)
            log_info "卸载 ConfigMap..."
            kubectl delete -f "$CONFIGMAP_YAML" -n "$namespace" --ignore-not-found
            log_success "ConfigMap 卸载完成"
            ;;
        status)
            log_info "检查 ConfigMap 状态..."
            local configmap_name="${CONFIGMAP_NAME:-celeryworker-config}"
            kubectl get configmap "$configmap_name" -n "$namespace" 2>/dev/null || log_warn "ConfigMap 不存在: $configmap_name"
            ;;
        generate)
            log_success "YAML 文件已生成: $CONFIGMAP_YAML"
            ;;
        *)
            log_error "无效操作: $action"
            echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
