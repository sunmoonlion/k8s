#!/bin/bash

set -e

# 导入统一部署模板
# 路径：deploy-ingress/ → ingress/ → deploy-casdoor/ → casdoor/ → auth-app/ → app-platform/ → sunmoonai/ → k8s/ → utils/
source "$(dirname "$0")/../../../../../../../utils/unified-deployment-template.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
CASDOOR_MAIN_CONFIG="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-casdoor.conf"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

load_config() {
    [[ -f "$CASDOOR_MAIN_CONFIG" ]] || { log_error "主配置不存在: $CASDOOR_MAIN_CONFIG"; exit 1; }
    source "$CASDOOR_MAIN_CONFIG"

    NAMESPACE="${CASDOOR_NAMESPACE:-app-platform-dev}"
    SERVICE_NAME="casdoor-${CASDOOR_PROJECT_ID:-sunmoonai}"
    SERVICE_PORT="${CASDOOR_SERVICE_PORT:-8000}"
    UNIFIED_HOST="${CASDOOR_UNIFIED_HOST:-casdoor.sunmoonai.com}"

    # NODE_IP 从集群节点动态获取
    if [[ -z "${NODE_IP:-}" ]]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "101.126.151.0")
    fi

    log_success "✅ 配置加载成功 | 服务: $SERVICE_NAME:$SERVICE_PORT | 域名: $UNIFIED_HOST"
}

deploy_ingress() {
    local namespace="${1:-$NAMESPACE}"
    [[ -f "$INGRESS_FILE" ]] || { log_error "Ingress 文件不存在: $INGRESS_FILE"; return 1; }

    kubectl get namespace "$namespace" >/dev/null 2>&1 || { log_error "命名空间不存在: $namespace"; return 1; }
    kubectl get service -n "$namespace" "$SERVICE_NAME" >/dev/null 2>&1 || {
        log_error "Service 不存在: $SERVICE_NAME（Casdoor 是否已部署？）"; return 1; }

    local tmp; tmp=$(mktemp)
    cp "$INGRESS_FILE" "$tmp"
    sed -i "s|{{NAMESPACE}}|$NAMESPACE|g"     "$tmp"
    sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$tmp"
    sed -i "s|{{SERVICE_PORT}}|$SERVICE_PORT|g" "$tmp"
    sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$tmp"
    sed -i "s|{{NODE_IP}}|$NODE_IP|g"           "$tmp"

    kubectl apply -f "$tmp" && log_success "✅ Casdoor IngressRoute 应用成功"
    rm -f "$tmp"
}

delete_ingress() {
    kubectl delete -f "$INGRESS_FILE" --ignore-not-found || true
    log_success "✅ Casdoor IngressRoute 删除完成"
}

declare -a PARSED_ARGS

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"

    local action="${1:-deploy}"
    setup_kubectl_environment
    load_config

    case "$action" in
        deploy)  deploy_ingress "$NAMESPACE" ;;
        uninstall|delete) delete_ingress ;;
        status)
            kubectl get ingressroute -n "$NAMESPACE" -l component=casdoor 2>/dev/null || echo "无 IngressRoute"
            kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "无 Service"
            ;;
        *) echo "用法: $0 [deploy|uninstall|status]" ;;
    esac
}

main "$@"
