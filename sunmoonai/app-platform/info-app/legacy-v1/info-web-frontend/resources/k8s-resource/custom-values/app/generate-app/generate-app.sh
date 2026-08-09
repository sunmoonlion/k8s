#!/bin/bash
# info-web-frontend Deployment YAML 生成脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-app.conf"
# 从 generate-app/ -> app/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# 从 generate-app/ -> app/ -> custom-values/ -> k8s-resource/ -> resources/ -> info-web-frontend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-info-web-frontend/app/deploy-app/deploy-info-web-frontend.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${INFO_WEB_FRONTEND_NAMESPACE:-}")
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
    log_info "跳过资源生成: app (已禁用)"; exit 0
fi

export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

export INFO_WEB_FRONTEND_IMAGE_REGISTRY="${INFO_WEB_FRONTEND_IMAGE_REGISTRY:-}"
export INFO_WEB_FRONTEND_IMAGE_PROJECT="${INFO_WEB_FRONTEND_IMAGE_PROJECT:-}"
export INFO_WEB_FRONTEND_IMAGE="${INFO_WEB_FRONTEND_IMAGE:-}"
export INFO_WEB_FRONTEND_TAG="${INFO_WEB_FRONTEND_TAG:-}"
export INFO_WEB_FRONTEND_FULL_IMAGE_NAME="${INFO_WEB_FRONTEND_IMAGE_REGISTRY}/${INFO_WEB_FRONTEND_IMAGE_PROJECT}/${INFO_WEB_FRONTEND_IMAGE}:${INFO_WEB_FRONTEND_TAG}"
export IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-}"
export INFO_WEB_FRONTEND_IMAGE_PULL_SECRET_NAME="${INFO_WEB_FRONTEND_IMAGE_PULL_SECRET_NAME:-}"
export INFO_WEB_FRONTEND_SECRET_NAME="${INFO_WEB_FRONTEND_SECRET_NAME:-}"
export INFO_WEB_FRONTEND_CONFIGMAP_NAME="${INFO_WEB_FRONTEND_CONFIGMAP_NAME:-}"
export INFO_WEB_FRONTEND_POSTGRESQL_SECRET_NAME="${INFO_WEB_FRONTEND_POSTGRESQL_SECRET_NAME:-}"
export INFO_WEB_FRONTEND_REDIS_SECRET_NAME="${INFO_WEB_FRONTEND_REDIS_SECRET_NAME:-}"
export INFO_WEB_FRONTEND_MONGODB_SECRET_NAME="${INFO_WEB_FRONTEND_MONGODB_SECRET_NAME:-}"
export INFO_WEB_FRONTEND_DATABASE_ENV_FROM=""
append_database_secret_ref() {
    local secret_name="$1"
    [[ -n "$secret_name" ]] || return 0
    if [[ -n "$INFO_WEB_FRONTEND_DATABASE_ENV_FROM" ]]; then
        INFO_WEB_FRONTEND_DATABASE_ENV_FROM+=$'\n'
    fi
    INFO_WEB_FRONTEND_DATABASE_ENV_FROM+="        - secretRef:"$'\n'"            name: ${secret_name}"
}
append_database_secret_ref "$INFO_WEB_FRONTEND_POSTGRESQL_SECRET_NAME"
append_database_secret_ref "$INFO_WEB_FRONTEND_REDIS_SECRET_NAME"
append_database_secret_ref "$INFO_WEB_FRONTEND_MONGODB_SECRET_NAME"
if [[ -n "$INFO_WEB_FRONTEND_DATABASE_ENV_FROM" ]]; then
    export INFO_WEB_FRONTEND_DATABASE_ENV_FROM
fi
export INFO_WEB_FRONTEND_OBJECT_STORAGE_CONFIGMAP_NAME="${INFO_WEB_FRONTEND_OBJECT_STORAGE_CONFIGMAP_NAME:-}"
export INFO_WEB_FRONTEND_OBJECT_STORAGE_SECRET_NAME="${INFO_WEB_FRONTEND_OBJECT_STORAGE_SECRET_NAME:-}"
export INFO_WEB_FRONTEND_OBJECT_STORAGE_ENV_FROM=""
if [[ -n "$INFO_WEB_FRONTEND_OBJECT_STORAGE_CONFIGMAP_NAME" ||
      -n "$INFO_WEB_FRONTEND_OBJECT_STORAGE_SECRET_NAME" ]]; then
    if [[ -z "$INFO_WEB_FRONTEND_OBJECT_STORAGE_CONFIGMAP_NAME" ||
          -z "$INFO_WEB_FRONTEND_OBJECT_STORAGE_SECRET_NAME" ]]; then
        log_error "对象存储 ConfigMap 和 Secret 名称必须同时设置"
        exit 1
    fi
    printf -v INFO_WEB_FRONTEND_OBJECT_STORAGE_ENV_FROM \
      '        - configMapRef:\n            name: %s\n        - secretRef:\n            name: %s' \
      "$INFO_WEB_FRONTEND_OBJECT_STORAGE_CONFIGMAP_NAME" \
      "$INFO_WEB_FRONTEND_OBJECT_STORAGE_SECRET_NAME"
    export INFO_WEB_FRONTEND_OBJECT_STORAGE_ENV_FROM
fi
export INFO_WEB_FRONTEND_ELASTICSEARCH_CONFIGMAP_NAME="${INFO_WEB_FRONTEND_ELASTICSEARCH_CONFIGMAP_NAME:-}"
export INFO_WEB_FRONTEND_ELASTICSEARCH_SECRET_NAME="${INFO_WEB_FRONTEND_ELASTICSEARCH_SECRET_NAME:-}"
export INFO_WEB_FRONTEND_ELASTICSEARCH_ENV_FROM=""
export INFO_WEB_FRONTEND_ELASTICSEARCH_VOLUME_MOUNT=""
export INFO_WEB_FRONTEND_ELASTICSEARCH_VOLUME=""
if [[ -n "$INFO_WEB_FRONTEND_ELASTICSEARCH_CONFIGMAP_NAME" ||
      -n "$INFO_WEB_FRONTEND_ELASTICSEARCH_SECRET_NAME" ]]; then
    if [[ -z "$INFO_WEB_FRONTEND_ELASTICSEARCH_CONFIGMAP_NAME" ||
          -z "$INFO_WEB_FRONTEND_ELASTICSEARCH_SECRET_NAME" ]]; then
        log_error "Elasticsearch ConfigMap 和 Secret 名称必须同时设置"
        exit 1
    fi
    printf -v INFO_WEB_FRONTEND_ELASTICSEARCH_ENV_FROM \
      '        - configMapRef:\n            name: %s\n        - secretRef:\n            name: %s' \
      "$INFO_WEB_FRONTEND_ELASTICSEARCH_CONFIGMAP_NAME" \
      "$INFO_WEB_FRONTEND_ELASTICSEARCH_SECRET_NAME"
    printf -v INFO_WEB_FRONTEND_ELASTICSEARCH_VOLUME_MOUNT \
      '        - name: elasticsearch-ca\n          mountPath: /var/run/secrets/sunmoonai/elasticsearch\n          readOnly: true'
    printf -v INFO_WEB_FRONTEND_ELASTICSEARCH_VOLUME \
      '      - name: elasticsearch-ca\n        secret:\n          secretName: %s\n          items:\n          - key: ca.crt\n            path: ca.crt' \
      "$INFO_WEB_FRONTEND_ELASTICSEARCH_SECRET_NAME"
    export INFO_WEB_FRONTEND_ELASTICSEARCH_ENV_FROM
    export INFO_WEB_FRONTEND_ELASTICSEARCH_VOLUME_MOUNT
    export INFO_WEB_FRONTEND_ELASTICSEARCH_VOLUME
fi
export PVC_NAME="${PVC_NAME:-}"
export PVC_MOUNT_PATH="${PVC_MOUNT_PATH:-}"
export PVC_SUB_PATH="${PVC_SUB_PATH:-}"

validate_yaml() {
    local yaml_file="$1"
    if command -v ruby &> /dev/null; then
        if ruby -e 'require "yaml"; YAML.load_stream(File.read(ARGV.fetch(0)))' "$yaml_file" &> /dev/null; then
            log_success "YAML 验证通过: $(basename "$yaml_file")"
        else
            log_error "YAML 验证失败: $(basename "$yaml_file")"
            ruby -e 'require "yaml"; YAML.load_stream(File.read(ARGV.fetch(0)))' "$yaml_file" 2>&1 | head -20
            return 1
        fi
    elif command -v kubectl &> /dev/null && kubectl config current-context &> /dev/null; then
        kubectl apply --dry-run=client -f "$yaml_file" &> /dev/null || {
            log_error "YAML/Kubernetes 资源验证失败: $(basename "$yaml_file")"
            return 1
        }
    else
        log_warn "缺少 Ruby YAML 解析器且没有可用 Kubernetes context，跳过 YAML 验证"
    fi
}

main() {
    log_info "开始生成 info-web-frontend YAML 文件..."
    log_info "输出目录: $OUTPUT_DIR"

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

    log_info "生成 app: $OUTPUT_FILE"
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
    validate_yaml "$full_output_path"
    log_success "✅ app 生成完成: $OUTPUT_FILE"
}

main "$@"
