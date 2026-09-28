#!/bin/bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" action "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
# ONLYOFFICE domain route and its Middleware. Cloud execution 未经实机验证.
set -euo pipefail
set +x
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_ROOT_DIR="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
unified_parse_cluster_arg "$@"
set -- "${PARSED_ARGS[@]}"
[[ $# -le 5 ]] || { echo 'Too many Ingress arguments' >&2; exit 2; }
action="${1:-deploy}"
case "$action" in
    help|-h|--help) echo 'action [project namespace environment dry_run]; deploy/status/uninstall'; exit 0 ;;
    deploy|status|uninstall) ;;
    *) echo 'Unsupported Ingress action' >&2; exit 2 ;;
esac
[[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]] || { echo 'Explicit CLUSTER required' >&2; exit 1; }
requested_project="${2:-}"
requested_namespace="${3:-}"
requested_environment="${4:-}"
source "$APP_ROOT/deploy-onlyoffice-docs/deploy-onlyoffice-docs.conf" >/dev/null 2>&1
source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
apply_cluster_config_mapping
project="${requested_project:-${ONLYOFFICE_PROJECT_ID:-sunmoonai}}"
export NAMESPACE="${requested_namespace:-${ONLYOFFICE_NAMESPACE:-app-platform-dev}}"
export ENVIRONMENT="${requested_environment:-${ENVIRONMENT:-development}}"
export SERVICE_NAME="${SERVICE_NAME:-onlyoffice-docs-$project}"
export SERVICE_PORT="${ONLYOFFICE_SERVICE_PORT:-8888}"
export UNIFIED_HOST="${ONLYOFFICE_UNIFIED_HOST:-www.sunmoonai.com}"
source "$K8S_ROOT_DIR/utils/deploy-target.sh"
sunmoon_deploy_target_init "$K8S_ROOT_DIR" || exit 1
kube=(timeout 25s "$SUNMOON_KUBECTL" --kubeconfig "$KUBECONFIG" --request-timeout=10s)
case "$action" in
    status)
        "${kube[@]}" get ingressroute.traefik.io onlyoffice-docs-web-route -n "$NAMESPACE"
        "${kube[@]}" get middleware.traefik.io onlyoffice-docs-stripprefix -n "$NAMESPACE" ;;
    uninstall)
        "${kube[@]}" delete ingressroute.traefik.io onlyoffice-docs-web-route -n "$NAMESPACE" --ignore-not-found --wait=false
        sunmoon_deploy_target_check "$K8S_ROOT_DIR" || exit 1
        "${kube[@]}" delete middleware.traefik.io onlyoffice-docs-stripprefix -n "$NAMESPACE" --ignore-not-found --wait=false ;;
    deploy)
        "${kube[@]}" get namespace "$NAMESPACE" >/dev/null
        "${kube[@]}" get service "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null
        # Generate only the route and its middleware; never credentials or PVCs.
        bash "$APP_ROOT/resources/custom-values/generate.sh" \
            --resource onlyoffice-docs-stripprefix-generated.yaml \
            --resource onlyoffice-docs-ingress-generated.yaml
        sunmoon_deploy_target_check "$K8S_ROOT_DIR" || exit 1
        "${kube[@]}" apply -f "$APP_ROOT/resources/custom-values/onlyoffice-docs-stripprefix-generated.yaml"
        sunmoon_deploy_target_check "$K8S_ROOT_DIR" || exit 1
        "${kube[@]}" apply -f "$APP_ROOT/resources/custom-values/onlyoffice-docs-ingress-generated.yaml" ;;
esac
