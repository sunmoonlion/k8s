#!/bin/bash
# Harbor Registry Secret YAML 生成脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-harbor-registry-secret.conf"
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-nodebullworker-llm-web-backend/app/deploy-app/deploy-nodebullworker-llm-web-backend.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${NODEBULLWORKER_LLM_WEB_BACKEND_NAMESPACE:-}")
    _temp_environment=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${ENVIRONMENT:-}")
    [ -n "$_temp_namespace" ] && [ -z "${NAMESPACE:-}" ] && export NAMESPACE="$_temp_namespace"
    [ -n "$_temp_environment" ] && [ -z "${ENVIRONMENT:-}" ] && export ENVIRONMENT="$_temp_environment"
    unset _temp_namespace _temp_environment
fi

log_info()    { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在: $CONFIG_FILE"; exit 1
fi
source "$CONFIG_FILE"

if [ "${ENABLED:-true}" != "true" ]; then
    log_info "跳过资源生成: harbor-registry-secret (已禁用)"; exit 0
fi

export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

# 解析 Docker registry 密码。仓库内只保留占位符，真实值通过环境变量或集群 Secret 注入。
resolve_docker_password() {
    local password="${DOCKER_PASSWORD:-}"
    if [[ -n "$password" && "$password" != "TODO_FILL_IN_HARBOR_PASSWORD" ]]; then
        printf '%s' "$password"
        return 0
    fi

    if [[ -n "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
        printf '%s' "$HARBOR_ADMIN_PASSWORD"
        return 0
    fi

    if command -v kubectl >/dev/null 2>&1; then
        local secret_namespace="${HARBOR_SECRET_NAMESPACE:-cicd-platform-dev}"
        local secret_name="${HARBOR_AUTH_SECRET_NAME:-harbor-secret}"
        local secret_key="${HARBOR_AUTH_SECRET_PASSWORD_KEY:-HARBOR_ADMIN_PASSWORD}"
        local secret_value
        secret_value=$(kubectl get secret "$secret_name" -n "$secret_namespace" \
            -o "jsonpath={.data.${secret_key}}" 2>/dev/null | base64 -d 2>/dev/null || true)
        if [[ -n "$secret_value" ]]; then
            printf '%s' "$secret_value"
            return 0
        fi
    fi

    log_error "未提供 Harbor registry 密码。请设置 DOCKER_PASSWORD 或 HARBOR_ADMIN_PASSWORD，或确保可读取 cicd-platform-dev/harbor-secret。"
    return 1
}

# 生成 base64 编码的 Docker config JSON
HARBOR_AUTH_STRING=$(echo -n "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" | base64 -w 0)
HARBOR_DOCKER_CONFIG_JSON=$(echo -n "{\"auths\":{\"${DOCKER_SERVER}\":{\"username\":\"${DOCKER_USERNAME}\",\"password\":\"${DOCKER_PASSWORD}\",\"auth\":\"${HARBOR_AUTH_STRING}\"}}}" | base64 -w 0)
export HARBOR_DOCKER_CONFIG_JSON

validate_yaml() {
    local yaml_file="$1"
    if command -v kubectl &> /dev/null; then
        if kubectl apply --dry-run=client -f "$yaml_file" &> /dev/null; then
            log_success "YAML 验证通过: $(basename "$yaml_file")"
            return 0
        else
            log_error "YAML 验证失败: $(basename "$yaml_file")"
            kubectl apply --dry-run=client -f "$yaml_file" 2>&1 | head -20
            return 1
        fi
    else
        log_warn "kubectl 未安装，跳过 YAML 验证"
        return 0
    fi
}

main() {
    log_info "开始生成 Harbor Registry Secret YAML 文件..."

    local full_template_path
    if [[ "$TEMPLATE_FILE" = /* ]]; then
        full_template_path="$TEMPLATE_FILE"
    else
        full_template_path="$K8S_RESOURCE_DIR/$TEMPLATE_FILE"
    fi
    local full_output_path="$OUTPUT_DIR/$OUTPUT_FILE"

    if [ ! -f "$full_template_path" ]; then
        log_error "模板文件不存在: $full_template_path"; exit 1
    fi

    log_info "生成 harbor-registry-secret: $OUTPUT_FILE"
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
    if ! validate_yaml "$full_output_path"; then exit 1; fi
    log_success "✅ harbor-registry-secret 生成完成: $OUTPUT_FILE"
}

main "$@"
