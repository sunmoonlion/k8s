#!/usr/bin/env bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" namespace "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-elasticsearch-secrets.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] 缺少配置文件: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

action="${1:-deploy}"
namespace="${2:-${ELASTICSEARCH_NAMESPACE:-data-platform-dev}}"

case "$action" in
    deploy)
        kubectl create secret generic "$ELASTICSEARCH_SECRET_NAME" \
            --namespace "$namespace" \
            --from-literal="$ELASTICSEARCH_AUTH_SECRET_PASSWORD_KEY=$ELASTICSEARCH_PASSWORD" \
            --from-literal="elasticsearch-username=$ELASTICSEARCH_USERNAME" \
            --from-literal="kibana-password=$KIBANA_SYSTEM_PASSWORD" \
            --dry-run=client -o yaml | kubectl apply -f -
        echo "[OK] Elasticsearch 管理员 Secret 已配置: $namespace/$ELASTICSEARCH_SECRET_NAME"
        ;;
    status)
        kubectl get secret "$ELASTICSEARCH_SECRET_NAME" -n "$namespace"
        ;;
    uninstall|delete)
        kubectl delete secret "$ELASTICSEARCH_SECRET_NAME" -n "$namespace" --ignore-not-found
        ;;
    *)
        echo "用法: $0 [deploy|status|uninstall] [namespace]" >&2
        exit 1
        ;;
esac
