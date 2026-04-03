#!/bin/bash
# toutiao-app-backend ConfigMap YAML 生成脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-toutiao-app-backend-config.conf"
# 从 generate-toutiao-app-backend-config/ -> toutiao-app-backend-config/ -> configMap/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-toutiao-app-backend/app/deploy-app/deploy-toutiao-app-backend.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${TOUTIAO_BACKEND_NAMESPACE:-}")
    _temp_environment=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${ENVIRONMENT:-}")
    [ -n "$_temp_namespace" ] && [ -z "${NAMESPACE:-}" ] && export NAMESPACE="$_temp_namespace"
    [ -n "$_temp_environment" ] && [ -z "${ENVIRONMENT:-}" ] && export ENVIRONMENT="$_temp_environment"
    unset _temp_namespace _temp_environment
fi

log_info()    { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }

[ ! -f "$CONFIG_FILE" ] && log_error "配置文件不存在: $CONFIG_FILE" && exit 1
source "$CONFIG_FILE"
[ "${ENABLED:-true}" != "true" ] && log_info "跳过资源生成: configmap (已禁用)" && exit 0

export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"
export FLASK_ENV="${FLASK_ENV:-}"
export LOGGING_LEVEL="${LOGGING_LEVEL:-}"
export LOGGING_FILE_DIR="${LOGGING_FILE_DIR:-}"
export MYSQL_HOST="${MYSQL_HOST:-}"
export MYSQL_PORT="${MYSQL_PORT:-}"
export MYSQL_SLAVE_HOST="${MYSQL_SLAVE_HOST:-}"
export MYSQL_SLAVE_PORT="${MYSQL_SLAVE_PORT:-}"
export MYSQL_DB="${MYSQL_DB:-}"
export REDIS_SENTINEL_NODES="${REDIS_SENTINEL_NODES:-}"
export REDIS_SENTINEL_SERVICE_NAME="${REDIS_SENTINEL_SERVICE_NAME:-}"
export REDIS_CLUSTER_NODES="${REDIS_CLUSTER_NODES:-}"
export ES_HOSTS="${ES_HOSTS:-}"
export AUTH_JWKS_URL="${AUTH_JWKS_URL:-}"
export AUTH_JWT_ISSUER="${AUTH_JWT_ISSUER:-}"
export AUTH_JWT_AUDIENCE="${AUTH_JWT_AUDIENCE:-}"
export QINIU_BUCKET_NAME="${QINIU_BUCKET_NAME:-}"
export QINIU_DOMAIN="${QINIU_DOMAIN:-}"
export CORS_ORIGINS="${CORS_ORIGINS:-}"
export DATACENTER_ID="${DATACENTER_ID:-}"
export WORKER_ID="${WORKER_ID:-}"

validate_yaml() {
    local yaml_file="$1"
    if command -v kubectl &> /dev/null; then
        if kubectl apply --dry-run=client -f "$yaml_file" &> /dev/null; then
            log_success "YAML 验证通过: $(basename "$yaml_file")"
        else
            log_error "YAML 验证失败: $(basename "$yaml_file")"
            kubectl apply --dry-run=client -f "$yaml_file" 2>&1 | head -20
            return 1
        fi
    else
        log_warn "kubectl 未安装，跳过 YAML 验证"
    fi
}

main() {
    log_info "开始生成 toutiao-app-backend ConfigMap YAML..."
    local full_template_path="$K8S_RESOURCE_DIR/$TEMPLATE_FILE"
    local full_output_path="$OUTPUT_DIR/$OUTPUT_FILE"
    [ ! -f "$full_template_path" ] && log_error "模板文件不存在: $full_template_path" && exit 1
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
    validate_yaml "$full_output_path"
    log_success "✅ configmap 生成完成: $OUTPUT_FILE"
}

main "$@"
