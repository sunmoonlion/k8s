#!/bin/bash

# =============================================================================
# LLMOps Service ConfigMap 部署脚本
# 文件名: deploy-llmops-service-config.sh
# 用途: 部署 LLMOps Service ConfigMap 到 Kubernetes 集群
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 模板文件已移动到 resources/custom-values/templates/
# 计算应用根目录（从 deploy-xxx/ 到应用根目录）
APP_ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")"  # 从 deploy-xxx/ 到应用根目录
TEMPLATES_DIR="$APP_ROOT/resources/custom-values/templates"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"  # llmops-service-config 目录（用于其他用途）
# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"

# 日志函数
log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 默认配置
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 加载配置文件
CONFIG_FILE="$SCRIPT_DIR/deploy-llmops-service-config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 检查命名空间
check_namespace() {
    local namespace="$1"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ 命名空间 $namespace 已存在"
        return 0
    else
        log_error "❌ 命名空间 $namespace 不存在！"
        echo ""
        log_info "请先创建命名空间："
        echo "  kubectl create namespace $namespace"
        echo ""
        return 1
    fi
}

main() {
    local action="${1:-deploy}"
    local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${3:-${CONFIGMAP_NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    
    log_info "部署 LLMOps Service ConfigMap..."
    log_info "部署参数："
    log_info "  - 操作: $action"
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    echo ""
    
    # 检查命名空间
    if ! check_namespace "$namespace"; then
        exit 1
    fi
    
    # ConfigMap YAML 文件路径
    local configmap_yaml="$TEMPLATES_DIR/configmap/${CONFIGMAP_NAME}.yaml"
    
    if [[ ! -f "$configmap_yaml" ]]; then
        log_error "ConfigMap YAML 文件不存在: $configmap_yaml"
        exit 1
    fi
    
    case "$action" in
        "deploy")
            log_info "部署 ConfigMap: $CONFIGMAP_NAME 到命名空间: $namespace"
            
            # 使用 envsubst 替换环境变量
            # 注意：需要先处理 ${VAR:-default} 语法，因为 envsubst 不支持默认值
            TEMP_YAML=$(mktemp)
            export NAMESPACE="$namespace" ENV="$environment"
            # 将 ${VAR:-default} 转换为 ${VAR}，然后使用 envsubst 替换
            sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$configmap_yaml" | envsubst > "$TEMP_YAML"
            
            kubectl apply -f "$TEMP_YAML" -n "$namespace"
            rm -f "$TEMP_YAML"
            
            log_success "ConfigMap 部署完成: $CONFIGMAP_NAME"
            ;;
        "uninstall")
            log_info "卸载 ConfigMap: $CONFIGMAP_NAME 从命名空间: $namespace"
            
            TEMP_YAML=$(mktemp)
            export NAMESPACE="$namespace" ENV="$environment"
            # 将 ${VAR:-default} 转换为 ${VAR}，然后使用 envsubst 替换
            sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$configmap_yaml" | envsubst > "$TEMP_YAML"
            
            kubectl delete -f "$TEMP_YAML" -n "$namespace" --ignore-not-found=true
            rm -f "$TEMP_YAML"
            
            log_success "ConfigMap 卸载完成: $CONFIGMAP_NAME"
            ;;
        "status")
            log_info "检查 ConfigMap 状态: $CONFIGMAP_NAME 在命名空间: $namespace"
            kubectl get configmap "$CONFIGMAP_NAME" -n "$namespace" 2>/dev/null || log_warn "ConfigMap 不存在"
            ;;
        *)
            log_error "无效的操作: $action"
            echo "用法: $0 [deploy|uninstall|status] [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac
}

main "$@"

