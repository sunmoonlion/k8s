#!/bin/bash
# Document Converter BFF Namespace 部署脚本
# 根据配置部署 Namespace 到 Kubernetes 集群

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-document-converter-bff-namespace.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-document-converter-bff-namespace/ -> document-converter-bff-namespace/ -> namespace/ -> deploy-document-converter-bff/ -> document-converter-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
NAMESPACE_YAML="$K8S_RESOURCE_DIR/custom-values/namespace/document-converter-bff-namespace/generate-document-converter-bff-namespace/document-converter-bff-namespace-generated.yaml"

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

# 默认配置从配置文件读取（deploy-document-converter-bff-namespace.conf）
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
  
  local generate_script="$PROJECT_ROOT/resources/k8s-resource/custom-values/namespace/document-converter-bff-namespace/generate-document-converter-bff-namespace/generate-document-converter-bff-namespace.sh"
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

  case "$action" in
    deploy)
      kubectl apply -f "$NAMESPACE_YAML"
      log_success "Namespace 部署完成"
      ;;
    uninstall)
      kubectl delete -f "$NAMESPACE_YAML" -n "$namespace" --ignore-not-found
      log_success "Namespace 卸载完成"
      ;;
    status)
      log_info "检查 Namespace 状态..."
      kubectl get namespace "$namespace" 2>/dev/null || log_warn "Namespace 不存在: $namespace"
      ;;
    generate)
      log_success "仅生成 YAML 文件，未部署"
      ;;
    *)
      log_error "无效操作: $action"
      echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
      exit 1
      ;;
  esac
}

main "$@"

