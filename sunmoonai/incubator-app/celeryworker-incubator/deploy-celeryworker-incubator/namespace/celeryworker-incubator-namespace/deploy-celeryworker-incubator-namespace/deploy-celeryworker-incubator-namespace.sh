#!/bin/bash
# Celery Worker (Incubator) Namespace 部署脚本
# 根据配置部署 Namespace 到 Kubernetes 集群

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-celeryworker-incubator-namespace.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-celeryworker-incubator-namespace/ -> celeryworker-incubator-namespace/ -> namespace/ -> deploy-celeryworker-incubator/ -> celeryworker-incubator/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
NAMESPACE_YAML="$K8S_RESOURCE_DIR/custom-values/namespace/celeryworker-incubator-namespace/generate-celeryworker-incubator-namespace/celeryworker-incubator-namespace-generated.yaml"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "[SUCCESS] $*"; }
log_error() { echo -e "[ERROR] $*" >&2; }
log_warn() { echo -e "[WARN] $*"; }

# 加载配置文件
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    log_warn "未找到配置文件: $CONFIG_FILE，使用默认配置"
fi

# 默认配置从配置文件读取（deploy-celeryworker-incubator-namespace.conf）
# 如果配置文件未设置，则使用空值（由函数参数默认值处理）
DEFAULT_PROJECT_ID="${PROJECT_ID:-}"
DEFAULT_NAMESPACE="${NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

main() {
  local action="${1:-deploy}"
  local project_id="${2:-${PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
  local namespace="${3:-${NAMESPACE:-$DEFAULT_NAMESPACE}}"
  local environment="${4:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"

  export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment"

  # 1. 自动生成 YAML 文件（如果不存在）
  # 导出基础配置变量，供生成脚本使用（通过环境变量继承）
  export NAMESPACE="$namespace"
  export ENVIRONMENT="$environment"
  export ENV="${ENV:-dev}"
  export PROJECT_ID="$project_id"
  
  local generate_script="$PROJECT_ROOT/resources/k8s-resource/custom-values/namespace/celeryworker-incubator-namespace/generate-celeryworker-incubator-namespace/generate-celeryworker-incubator-namespace.sh"
  if [ -f "$generate_script" ]; then
    if bash "$generate_script"; then
      log_success "Namespace YAML 文件生成成功"
    else
      log_error "Namespace YAML 文件生成失败"
      exit 1
    fi
  else
    log_error "生成脚本不存在: $generate_script"
    exit 1
  fi

  # 2. 根据操作类型执行相应动作
  case "$action" in
    deploy)
      log_info "部署 Celery Worker (Incubator) Namespace..."
      log_info "命名空间: $namespace"
      
      if [ ! -f "$NAMESPACE_YAML" ]; then
        log_error "YAML 文件不存在: $NAMESPACE_YAML"
        exit 1
      fi
      
      # 检查命名空间是否已存在
      if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_warn "命名空间 $namespace 已存在，跳过创建"
        log_info "如需更新，请先删除现有命名空间：kubectl delete namespace $namespace"
      else
        if kubectl apply -f "$NAMESPACE_YAML"; then
          log_success "✅ Namespace 部署成功"
        else
          log_error "❌ Namespace 部署失败"
          exit 1
        fi
      fi
      ;;
    
    uninstall)
      log_info "卸载 Celery Worker (Incubator) Namespace..."
      log_info "命名空间: $namespace"
      
      # 警告：删除命名空间会删除其中的所有资源
      log_warn "⚠️  删除命名空间 $namespace 将删除其中的所有资源！"
      read -p "确认删除命名空间 $namespace? (yes/no): " confirm
      if [ "$confirm" != "yes" ]; then
        log_info "取消删除操作"
        exit 0
      fi
      
      if kubectl delete namespace "$namespace" 2>/dev/null; then
        log_success "✅ Namespace 卸载成功"
      else
        log_warn "⚠️ Namespace 可能不存在或已卸载"
      fi
      ;;
    
    status)
      log_info "检查 Celery Worker (Incubator) Namespace 状态..."
      log_info "命名空间: $namespace"
      
      if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "✅ Namespace 存在"
        kubectl get namespace "$namespace" -o wide
      else
        log_warn "⚠️ Namespace 不存在"
      fi
      ;;
    
    *)
      log_error "未知操作: $action"
      echo "用法: $0 {deploy|uninstall|status} [project_id] [namespace] [environment]"
      exit 1
      ;;
  esac
}

main "$@"
