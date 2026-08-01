#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-knowledge-admin-backend-secret.conf"
SECRET_NAME="knowledge-admin-backend-secret"

log_info()    { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error()   { echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_warn()    { echo -e "\033[33m[WARN]\033[0m $*"; }

[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || log_warn "未找到配置文件: $CONFIG_FILE"

read_existing_secret_value() {
    local namespace="$1" key="$2" encoded
    encoded="$(kubectl get secret "$SECRET_NAME" -n "$namespace" \
        -o "jsonpath={.data.${key}}" 2>/dev/null || true)"
    [[ -n "$encoded" ]] || return 1
    printf '%s' "$encoded" | base64 --decode
}

resolve_secret_value() {
    local namespace="$1" key="$2" required="$3" value
    value="${!key:-}"
    if [[ -z "$value" ]]; then
        value="$(read_existing_secret_value "$namespace" "$key" || true)"
    fi
    if [[ "$required" == "true" && -z "$value" ]]; then
        log_error "$key 未显式提供且集群中不存在非空值，拒绝更新 $SECRET_NAME"
        return 1
    fi
    printf -v "$key" '%s' "$value"
    export "$key"
}

deploy_secret_without_disk() {
    local namespace="$1"
    resolve_secret_value "$namespace" CASDOOR_CLIENT_ID false
    resolve_secret_value "$namespace" CASDOOR_CLIENT_SECRET false
    resolve_secret_value "$namespace" RAGFLOW_API_KEY true

    kubectl create secret generic "$SECRET_NAME" \
        -n "$namespace" \
        --from-literal="CASDOOR_CLIENT_ID=$CASDOOR_CLIENT_ID" \
        --from-literal="CASDOOR_CLIENT_SECRET=$CASDOOR_CLIENT_SECRET" \
        --from-literal="RAGFLOW_API_KEY=$RAGFLOW_API_KEY" \
        --dry-run=client \
        -o yaml \
        | kubectl apply -f - >/dev/null
    kubectl label secret "$SECRET_NAME" -n "$namespace" \
        app=knowledge-admin-backend --overwrite >/dev/null

    unset CASDOOR_CLIENT_ID CASDOOR_CLIENT_SECRET RAGFLOW_API_KEY
    log_success "$SECRET_NAME 已无落盘协调，已有非空敏感值不会被空变量覆盖"
}

main() {
    local action="${1:-deploy}"
    local project_id="${2:-${PROJECT_ID:-}}"
    local namespace="${3:-${NAMESPACE:-}}"
    local environment="${4:-${ENVIRONMENT:-}}"

    export PROJECT_ID="$project_id" NAMESPACE="$namespace" ENVIRONMENT="$environment" ENV="${ENV:-dev}"

    case "$action" in
        deploy)
            deploy_secret_without_disk "$NAMESPACE"
            log_success "knowledge-admin-backend Secret 部署完成"
            ;;
        uninstall)
            kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE" --ignore-not-found
            log_success "knowledge-admin-backend Secret 卸载完成"
            ;;
        status)
            kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" 2>/dev/null \
                || log_warn "Secret 不存在: $SECRET_NAME"
            ;;
        generate)
            log_error "已禁用敏感 Secret 明文 YAML 生成；请使用 deploy 进行无落盘协调"
            exit 1
            ;;
        *)
            log_error "无效操作: $action"
            echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac
}

main "$@"
