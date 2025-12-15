#!/bin/bash
# Incubator App SSR 部署脚本
# 用法: ./deploy-incubator-ssr.sh <deploy|undeploy|status> [project_id] [namespace] [environment]
# 注意：资源 YAML 位置由 RESOURCES_DIR/INCUBATOR_SSR_YAML 指定，resource 目录不改动

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/deploy-incubator-ssr.conf"

DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 载入配置
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "[WARN] 未找到配置文件: $CONFIG_FILE，使用默认配置"
fi

# 计算镜像全名
INCUBATOR_SSR_FULL_IMAGE_NAME="${INCUBATOR_SSR_IMAGE_REGISTRY}/${INCUBATOR_SSR_IMAGE_PROJECT}/${INCUBATOR_SSR_IMAGE}:${INCUBATOR_SSR_TAG}"

log_info() { echo -e "\033[0;34m[INFO]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*" 1>&2; }

check_kubectl() {
  command -v kubectl >/dev/null 2>&1 || { log_error "kubectl 未安装"; exit 1; }
}

check_namespace() {
  if kubectl get namespace "$1" >/dev/null 2>&1; then
    log_success "命名空间存在: $1"
  else
    log_error "命名空间不存在: $1"
    exit 1
  }
}

check_env_config() {
  if [[ ! -f "$INCUBATOR_SSR_YAML" ]]; then
    log_error "缺少资源文件: $INCUBATOR_SSR_YAML"
    log_warn "请在 resource 目录提供 YAML，当前不修改 resource 目录"
    exit 1
  fi
  if [[ "${secrets_enabled:-true}" == "true" ]]; then
    [[ -f "$INCUBATOR_SSR_CONFIGMAP" ]] || { log_error "缺少 ConfigMap 模板: $INCUBATOR_SSR_CONFIGMAP"; exit 1; }
    [[ -f "$INCUBATOR_SSR_SECRET" ]] || { log_error "缺少 Secret 模板: $INCUBATOR_SSR_SECRET"; exit 1; }
  fi
  command -v envsubst >/dev/null 2>&1 || { log_error "envsubst 未安装"; exit 1; }
}

deploy_secrets_config() {
  [[ "${secrets_enabled:-true}" == "true" ]] || { log_info "跳过 Secrets/ConfigMap 部署"; return; }
  log_info "部署 ConfigMap 和 Secret..."
  export NAMESPACE ENV
  tmp_cm=$(mktemp)
  tmp_sec=$(mktemp)
  envsubst < "$INCUBATOR_SSR_CONFIGMAP" > "$tmp_cm"
  envsubst < "$INCUBATOR_SSR_SECRET" > "$tmp_sec"
  kubectl apply -f "$tmp_cm" -n "$NAMESPACE"
  kubectl apply -f "$tmp_sec" -n "$NAMESPACE"
  rm -f "$tmp_cm" "$tmp_sec"
}

deploy_app() {
  check_env_config
  log_info "部署 Incubator App SSR..."
  export NAMESPACE ENV INCUBATOR_SSR_FULL_IMAGE_NAME INCUBATOR_SSR_IMAGE_REGISTRY INCUBATOR_SSR_IMAGE_PROJECT INCUBATOR_SSR_IMAGE INCUBATOR_SSR_TAG IMAGE_PULL_POLICY
  tmp_yaml=$(mktemp)
  envsubst < "$INCUBATOR_SSR_YAML" > "$tmp_yaml"
  kubectl apply -f "$tmp_yaml" -n "$NAMESPACE"
  rm -f "$tmp_yaml"
  log_success "应用部署完成"
}

undeploy_app() {
  check_env_config
  log_info "卸载 Incubator App SSR..."
  export NAMESPACE ENV
  tmp_yaml=$(mktemp)
  envsubst < "$INCUBATOR_SSR_YAML" > "$tmp_yaml"
  kubectl delete -f "$tmp_yaml" -n "$NAMESPACE" --ignore-not-found
  rm -f "$tmp_yaml"
  if [[ "${secrets_enabled:-true}" == "true" ]]; then
    tmp_cm=$(mktemp)
    tmp_sec=$(mktemp)
    envsubst < "$INCUBATOR_SSR_CONFIGMAP" > "$tmp_cm"
    envsubst < "$INCUBATOR_SSR_SECRET" > "$tmp_sec"
    kubectl delete -f "$tmp_cm" -n "$NAMESPACE" --ignore-not-found
    kubectl delete -f "$tmp_sec" -n "$NAMESPACE" --ignore-not-found
    rm -f "$tmp_cm" "$tmp_sec"
  fi
  log_success "卸载完成"
}

show_status() {
  log_info "当前状态 (namespace=$NAMESPACE):"
  kubectl get pods -n "$NAMESPACE" -l app=incubator-app-ssr || true
  kubectl get svc -n "$NAMESPACE" -l app=incubator-app-ssr || true
  kubectl get configmap -n "$NAMESPACE" -l app=incubator-app-ssr || true
  kubectl get secret -n "$NAMESPACE" -l app=incubator-app-ssr || true
}

main() {
  local action="${1:-deploy}"
  local project_id="${2:-$INCUBATOR_SSR_PROJECT_ID:-$DEFAULT_PROJECT_ID}"
  local namespace="${3:-$INCUBATOR_SSR_NAMESPACE:-$DEFAULT_NAMESPACE}"
  local environment="${4:-$ENVIRONMENT:-$DEFAULT_ENVIRONMENT}"

  PROJECT_ID="$project_id"
  NAMESPACE="$namespace"
  ENVIRONMENT="$environment"

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

