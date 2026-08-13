#!/usr/bin/env bash
set -euo pipefail

# auth-app 当前只有一个活动组件：Casdoor。此入口保留 App 级命令体验，但不再扫描目录，
# 从而避免历史 auth backend/frontend 或未来临时目录被误部署。

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTH_APP_ROOT="$(dirname "$THIS_DIR")"
K8S_ROOT_DIR=""
search_dir="$THIS_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录" >&2
    exit 1
fi

source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
source "$THIS_DIR/deploy-auth-app-all.conf"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

CASDOOR_SCRIPT="$AUTH_APP_ROOT/casdoor/deploy-casdoor/deploy-casdoor.sh"
if [[ ! -x "$CASDOOR_SCRIPT" ]]; then
    echo "[ERROR] Casdoor 部署脚本不存在或不可执行: $CASDOOR_SCRIPT" >&2
    exit 1
fi

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    local action="${1:-deploy}"
    [[ $# -gt 0 ]] && shift

    case "$action" in
        deploy|upgrade|uninstall|status|logs)
            ;;
        help|--help|-h)
            echo "用法: $0 [--cluster C1|C2|C3|KIND] [deploy|upgrade|uninstall|status|logs] [project_id] [namespace] [environment] [dry_run]"
            exit 0
            ;;
        *)
            echo "[ERROR] 未知操作: $action" >&2
            exit 2
            ;;
    esac

    local project_id="${1:-$AUTH_APP_PROJECT_ID}"
    local namespace="${2:-$AUTH_APP_NAMESPACE}"
    local environment="${3:-$ENVIRONMENT}"
    local dry_run="${4:-false}"
    local cluster_args=()
    [[ -n "${CLUSTER:-}" ]] && cluster_args=(--cluster "$CLUSTER")

    echo "[INFO] auth-app 仅部署 Casdoor: action=$action cluster=${CLUSTER:-default} namespace=$namespace"
    DISABLE_AUTO_CLEANUP=true "$CASDOOR_SCRIPT" "${cluster_args[@]}" \
        "$action" "$project_id" "$namespace" "$environment" "$dry_run"
}

main "$@"
