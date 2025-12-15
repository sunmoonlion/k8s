#!/bin/bash

# Incubator App BFF 部署脚本
# 用法: ./deploy-incubator-bff.sh <deploy|undeploy|status> [project_id] [namespace] [environment]
# 镜像构建请在源码仓库执行 mybuild/build-image.sh（可选推送）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="$SCRIPT_DIR/deploy-incubator-bff.conf"

# 默认值
DEFAULT_PROJECT_ID="sunmoonai"
DEFAULT_NAMESPACE="app-platform-dev"
DEFAULT_ENVIRONMENT="development"

# 资源路径
RESOURCES_DIR="../resource"
INCUBATOR_BFF_YAML="${RESOURCES_DIR}/incubator-app-bff.yaml"
SECRETS_DIR="$SCRIPT_DIR/secrets"
INCUBATOR_BFF_CONFIGMAP="${SECRETS_DIR}/incubator-app-bff-config/incubator-app-bff-config.yaml"
INCUBATOR_BFF_SECRET="${SECRETS_DIR}/incubator-app-bff-secret/incubator-app-bff-secret.yaml"

log_info() { echo -e "\\033[0;34m[INFO]\\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_success() { echo -e "\\033[0;32m[SUCCESS]\\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_warn() { echo -e "\\033[1;33m[WARN]\\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error() { echo -e "\\033[0;31m[ERROR]\\033[0m $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# 加载配置
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
  log_info "已加载配置: $CONFIG_FILE"
else
  log_warn "未找到配置文件: $CONFIG_FILE，使用默认配置"
fi

# 计算镜像名称
INCUBATOR_BFF_FULL_IMAGE_NAME="${INCUBATOR_BFF_IMAGE_REGISTRY}/${INCUBATOR_BFF_IMAGE_PROJECT}/${INCUBATOR_BFF_IMAGE}:${INCUBATOR_BFF_TAG}"

check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    log_error "kubectl 未安装或不在 PATH 中"
    exit 1
  }
}

check_namespace() {
  local namespace="$1"
  if kubectl get namespace "$namespace" >/dev/null 2>&1; then
    log_success "命名空间存在: $namespace"
  else
    log_error "命名空间不存在: $namespace"
    exit 1
  }
}

check_env_config() {
  [[ -f "$INCUBATOR_BFF_YAML" ]] || { log_error "缺少资源文件: $INCUBATOR_BFF_YAML"; exit 1; }
  if [[ "${secrets_enabled:-true}" == "true" ]]; then
    [[ -f "$INCUBATOR_BFF_CONFIGMAP" ]] || { log_error "缺少 ConfigMap 模板: $INCUBATOR_BFF_CONFIGMAP"; exit 1; }
    [[ -f "$INCUBATOR_BFF_SECRET" ]] || { log_error "缺少 Secret 模板: $INCUBATOR_BFF_SECRET"; exit 1; }
  fi
  if ! command -v envsubst &>/dev/null; then
    log_error "envsubst 未安装，请安装 gettext-base"
    exit 1
  }
}

deploy_secrets_config() {
  [[ "${secrets_enabled:-true}" == "true" ]] || { log_info "跳过 Secrets/ConfigMap 部署"; return; }
  log_info "部署 ConfigMap 和 Secret..."
  export NAMESPACE ENV
  tmp_cm=$(mktemp)
  tmp_sec=$(mktemp)
  envsubst < "$INCUBATOR_BFF_CONFIGMAP" > "$tmp_cm"
  envsubst < "$INCUBATOR_BFF_SECRET" > "$tmp_sec"
  kubectl apply -f "$tmp_cm" -n "$NAMESPACE"
  kubectl apply -f "$tmp_sec" -n "$NAMESPACE"
  rm -f "$tmp_cm" "$tmp_sec"
}

deploy_app() {
  check_env_config
  log_info "部署 Incubator App BFF..."
  export NAMESPACE ENV INCUBATOR_BFF_FULL_IMAGE_NAME INCUBATOR_BFF_IMAGE_REGISTRY INCUBATOR_BFF_IMAGE_PROJECT INCUBATOR_BFF_IMAGE INCUBATOR_BFF_TAG IMAGE_PULL_POLICY
  tmp_yaml=$(mktemp)
  envsubst < "$INCUBATOR_BFF_YAML" > "$tmp_yaml"
  kubectl apply -f "$tmp_yaml" -n "$NAMESPACE"
  rm -f "$tmp_yaml"
  log_success "应用部署完成"
}

undeploy_app() {
  check_env_config
  log_info "卸载 Incubator App BFF..."
  export NAMESPACE ENV
  tmp_yaml=$(mktemp)
  envsubst < "$INCUBATOR_BFF_YAML" > "$tmp_yaml"
  kubectl delete -f "$tmp_yaml" -n "$NAMESPACE" --ignore-not-found
  rm -f "$tmp_yaml"
  if [[ "${secrets_enabled:-true}" == "true" ]]; then
    tmp_cm=$(mktemp)
    tmp_sec=$(mktemp)
    envsubst < "$INCUBATOR_BFF_CONFIGMAP" > "$tmp_cm"
    envsubst < "$INCUBATOR_BFF_SECRET" > "$tmp_sec"
    kubectl delete -f "$tmp_cm" -n "$NAMESPACE" --ignore-not-found
    kubectl delete -f "$tmp_sec" -n "$NAMESPACE" --ignore-not-found
    rm -f "$tmp_cm" "$tmp_sec"
  fi
  log_success "卸载完成"
}

show_status() {
  log_info "当前状态 (namespace=$NAMESPACE):"
  kubectl get pods -n "$NAMESPACE" -l app=incubator-app-bff || true
  kubectl get svc -n "$NAMESPACE" -l app=incubator-app-bff || true
  kubectl get configmap -n "$NAMESPACE" -l app=incubator-app-bff || true
  kubectl get secret -n "$NAMESPACE" -l app=incubator-app-bff || true
}

main() {
  local action="${1:-deploy}"
  local project_id="${2:-$INCUBATOR_BFF_PROJECT_ID:-$DEFAULT_PROJECT_ID}"
  local namespace="${3:-$INCUBATOR_BFF_NAMESPACE:-$DEFAULT_NAMESPACE}"
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

