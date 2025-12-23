#!/bin/bash
# Auth App BFF Rate Limit Middleware 部署脚本
# 根据配置部署 Rate Limit Middleware 到 Kubernetes 集群

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-auth-app-bff-rate-limit.conf"
# 计算项目根目录（应用根目录）
# 从 deploy-auth-app-bff-rate-limit/ -> auth-app-bff-rate-limit/ -> middleware/ -> deploy-auth-app-bff/ -> auth-app-bff/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
MIDDLEWARE_YAML="$K8S_RESOURCE_DIR/custom-values/middleware/auth-app-bff-rate-limit/generate-auth-app-bff-rate-limit/auth-app-bff-rate-limit-generated.yaml"

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

# 默认配置从配置文件读取（deploy-auth-app-bff-rate-limit.conf）
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
        export NAMESPACE="${NAMESPACE:-}"
        export ENVIRONMENT="${ENVIRONMENT:-}"
        export ENV="${ENV:-dev}"
        
        local generate_script="$k8s_resource_dir/custom-values/middleware/auth-app-bff-rate-limit/generate-auth-app-bff-rate-limit/generate-auth-app-bff-rate-limit.sh"
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
  
  local generate_script="$PROJECT_ROOT/resources/k8s-resource/custom-values/middleware/auth-app-bff-rate-limit/generate-auth-app-bff-rate-limit/generate-auth-app-bff-rate-limit.sh"
  if [ -f "$generate_script" ]; then
    if bash "$generate_script"; then
      log_success "Rate Limit Middleware YAML 文件生成成功"
    else
      log_error "Rate Limit Middleware YAML 文件生成失败"
      exit 1
    fi
  else
    log_error "生成脚本不存在: $generate_script"
    exit 1
  fi

  # 2. 根据操作类型执行相应动作
  case "$action" in
    deploy)
      log_info "部署 Auth App BFF Rate Limit Middleware..."
      log_info "命名空间: $namespace"
      
      if [ ! -f "$MIDDLEWARE_YAML" ]; then
        log_error "YAML 文件不存在: $MIDDLEWARE_YAML"
        exit 1
      fi
      
      if kubectl apply -f "$MIDDLEWARE_YAML" -n "$namespace"; then
        log_success "✅ Rate Limit Middleware 部署成功"
      else
        log_error "❌ Rate Limit Middleware 部署失败"
        exit 1
      fi
      ;;
    
    uninstall)
      log_info "卸载 Auth App BFF Rate Limit Middleware..."
      log_info "命名空间: $namespace"
      
      if kubectl delete -f "$MIDDLEWARE_YAML" -n "$namespace" 2>/dev/null; then
        log_success "✅ Rate Limit Middleware 卸载成功"
      else
        log_warn "⚠️ Rate Limit Middleware 可能不存在或已卸载"
      fi
      ;;
    
    status)
      log_info "检查 Auth App BFF Rate Limit Middleware 状态..."
      log_info "命名空间: $namespace"
      
      if kubectl get middleware auth-app-bff-rate-limit -n "$namespace" 2>/dev/null; then
        log_success "✅ Rate Limit Middleware 存在"
      else
        log_warn "⚠️ Rate Limit Middleware 不存在"
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
