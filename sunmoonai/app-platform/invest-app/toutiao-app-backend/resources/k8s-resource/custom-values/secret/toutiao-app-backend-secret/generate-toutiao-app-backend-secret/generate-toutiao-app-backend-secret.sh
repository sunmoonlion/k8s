#!/bin/bash
# toutiao-app-backend Secret YAML 生成脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-toutiao-app-backend-secret.conf"
# 从 generate-toutiao-app-backend-secret/ -> toutiao-app-backend-secret/ -> secret/ -> custom-values/ -> k8s-resource/
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
[ "${ENABLED:-true}" != "true" ] && log_info "跳过资源生成: secret (已禁用)" && exit 0

export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"
export MYSQL_USER="${MYSQL_USER:-}"
export MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
export JWT_SECRET="${JWT_SECRET:-}"
export QINIU_ACCESS_KEY="${QINIU_ACCESS_KEY:-}"
export QINIU_SECRET_KEY="${QINIU_SECRET_KEY:-}"
export RABBITMQ_URL="${RABBITMQ_URL:-}"
export RATELIMIT_STORAGE_URL="${RATELIMIT_STORAGE_URL:-}"
export GEETEST_ID="${GEETEST_ID:-}"
export GEETEST_KEY="${GEETEST_KEY:-}"

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
    log_info "开始生成 toutiao-app-backend Secret YAML..."
    local full_template_path="$K8S_RESOURCE_DIR/$TEMPLATE_FILE"
    local full_output_path="$OUTPUT_DIR/$OUTPUT_FILE"
    [ ! -f "$full_template_path" ] && log_error "模板文件不存在: $full_template_path" && exit 1
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
    validate_yaml "$full_output_path"
    log_success "✅ secret 生成完成: $OUTPUT_FILE"
}

main "$@"
