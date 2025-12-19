#!/bin/bash
set -euo pipefail
# LLMOps App SSR 部署脚本
# 用法: ./deploy-llmops-ssr.sh <deploy|undeploy|status> [project_id] [namespace] [environment]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-llmops-ssr.conf"

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || echo "[WARN] 未找到配置文件，使用默认值"

LLMOPS_SSR_FULL_IMAGE_NAME="${LLMOPS_SSR_IMAGE_REGISTRY}/${LLMOPS_SSR_IMAGE_PROJECT}/${LLMOPS_SSR_IMAGE}:${LLMOPS_SSR_TAG}"

log_info(){ echo -e "\033[0;34m[INFO]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_success(){ echo -e "\033[0;32m[SUCCESS]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn(){ echo -e "\033[1;33m[WARN]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error(){ echo -e "\033[0;31m[ERROR]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*" 1>&2; }

check_kubectl(){ command -v kubectl >/dev/null 2>&1 || { log_error "kubectl 未安装"; exit 1; }; }
check_namespace(){ kubectl get namespace "$1" >/dev/null 2>&1 || { log_error "命名空间不存在: $1"; exit 1; }; }

# 资源文件路径（对齐项目结构）
RESOURCES_DIR="../resources"
# 使用生成的 YAML 文件（由 resources/custom-values/generate.sh 生成）
CUSTOM_VALUES_DIR="${RESOURCES_DIR}/custom-values"
LLMOPS_SSR_YAML="${CUSTOM_VALUES_DIR}/llmops-app-ssr-generated.yaml"
# 模板文件路径（已移动到 resources/custom-values/templates/）
TEMPLATES_DIR="${CUSTOM_VALUES_DIR}/templates"
LLMOPS_SSR_CONFIGMAP="${TEMPLATES_DIR}/configmap/llmops-app-ssr-config.yaml"
LLMOPS_SSR_SECRET="${TEMPLATES_DIR}/secret/llmops-app-ssr-secret.yaml"

# 自动生成 YAML 文件的辅助函数
auto_generate_yaml() {
  local yaml_file="$1"
  local custom_values_dir="$2"
  
  if [ ! -f "$yaml_file" ]; then
    log_warn "生成的 YAML 文件不存在，自动运行生成脚本..."
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

check_env_config(){
  # 自动生成 YAML 文件（如果不存在）
  if ! auto_generate_yaml "$LLMOPS_SSR_YAML" "$CUSTOM_VALUES_DIR"; then
    exit 1
  fi
  if [[ "${secrets_enabled:-true}" == "true" ]]; then
    [[ -f "$LLMOPS_SSR_CONFIGMAP" ]] || { log_error "缺少 ConfigMap 模板: $LLMOPS_SSR_CONFIGMAP"; exit 1; }
    [[ -f "$LLMOPS_SSR_SECRET" ]] || { log_error "缺少 Secret 模板: $LLMOPS_SSR_SECRET"; exit 1; }
  fi
  command -v envsubst >/dev/null 2>&1 || { log_error "envsubst 未安装"; exit 1; }
}

deploy_secrets_config(){
  [[ "${secrets_enabled:-true}" == "true" ]] || { log_info "跳过 Secrets/ConfigMap"; return; }
  log_info "部署 ConfigMap / Secret..."
  export NAMESPACE ENV
  tmp_cm=$(mktemp); tmp_sec=$(mktemp)
  envsubst < "$LLMOPS_SSR_CONFIGMAP" > "$tmp_cm"
  envsubst < "$LLMOPS_SSR_SECRET" > "$tmp_sec"
  kubectl apply -f "$tmp_cm" -n "$NAMESPACE"
  kubectl apply -f "$tmp_sec" -n "$NAMESPACE"
  rm -f "$tmp_cm" "$tmp_sec"
}

deploy_app(){
  check_env_config
  log_info "部署 LLMOps App SSR..."
  
  # 自动生成 YAML 文件（如果不存在）
  if ! auto_generate_yaml "$LLMOPS_SSR_YAML" "$CUSTOM_VALUES_DIR"; then
    exit 1
  fi
  
  # 部署 Deployment 和 Service（直接使用生成的 YAML）
  kubectl apply -f "$LLMOPS_SSR_YAML" -n "$NAMESPACE"
  log_success "应用部署完成"
}

undeploy_app(){
  check_env_config
  log_info "卸载 LLMOps App SSR..."
  
  # 检查生成的 YAML 文件是否存在
  if [ ! -f "$LLMOPS_SSR_YAML" ]; then
    log_warn "生成的 YAML 文件不存在: $LLMOPS_SSR_YAML，尝试直接删除资源"
    kubectl delete deployment llmops-app-ssr -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete service llmops-app-ssr-service -n "$NAMESPACE" --ignore-not-found=true
  else
    kubectl delete -f "$LLMOPS_SSR_YAML" -n "$NAMESPACE" --ignore-not-found=true
  fi
  if [[ "${secrets_enabled:-true}" == "true" ]]; then
    tmp_cm=$(mktemp); tmp_sec=$(mktemp)
    envsubst < "$LLMOPS_SSR_CONFIGMAP" > "$tmp_cm"
    envsubst < "$LLMOPS_SSR_SECRET" > "$tmp_sec"
    kubectl delete -f "$tmp_cm" -n "$NAMESPACE" --ignore-not-found
    kubectl delete -f "$tmp_sec" -n "$NAMESPACE" --ignore-not-found
    rm -f "$tmp_cm" "$tmp_sec"
  fi
  log_success "卸载完成"
}

show_status(){
  log_info "当前状态 (namespace=$NAMESPACE):"
  kubectl get pods -n "$NAMESPACE" -l app=llmops-app-ssr || true
  kubectl get svc -n "$NAMESPACE" -l app=llmops-app-ssr || true
  kubectl get configmap -n "$NAMESPACE" -l app=llmops-app-ssr || true
  kubectl get secret -n "$NAMESPACE" -l app=llmops-app-ssr || true
}

main(){
  local action="${1:-deploy}"
  local project_id="${2:-$LLMOPS_SSR_PROJECT_ID:-$DEFAULT_PROJECT_ID}"
  local namespace="${3:-$LLMOPS_SSR_NAMESPACE:-$DEFAULT_NAMESPACE}"
  local environment="${4:-$ENVIRONMENT:-$DEFAULT_ENVIRONMENT}"

  PROJECT_ID="$project_id"; NAMESPACE="$namespace"; ENVIRONMENT="$environment"
  case "$environment" in
    dev|development) ENV="dev" ;;
    prod|production) ENV="prod" ;;
    *) ENV="dev" ;;
  esac

  check_kubectl
  check_namespace "$NAMESPACE"

  case "$action" in
    deploy)
      deploy_secrets_config
      deploy_app
      show_status
      ;;
    undeploy)
      undeploy_app
      ;;
    status)
      show_status
      ;;
    *)
      log_error "无效操作: $action"
      echo "用法: $0 <deploy|undeploy|status> [project_id] [namespace] [environment]"
      exit 1
      ;;
  esac
}

main "$@"
