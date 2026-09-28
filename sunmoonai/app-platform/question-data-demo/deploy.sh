#!/usr/bin/env bash

# Shared request boundary: before configuration, credentials, connections and EXIT traps.
# shellcheck source=/dev/null
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" named "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"
# Shared consumer; cloud execution 未经实机验证. No build or KIND loading.
set -euo pipefail
set +x
export DISABLE_AUTO_CLEANUP=true
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT_DIR="$(cd "$ROOT/../../.." && pwd)"
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
unified_parse_cluster_arg "$@"
set -- "${PARSED_ARGS[@]}"
[[ $# -le 1 ]] || { echo 'Use [deploy|status|uninstall] --cluster KIND|C1' >&2; exit 2; }
ACTION="${1:-deploy}"
case "$ACTION" in
    help|-h|--help) echo 'Use [deploy|status|uninstall] --cluster KIND|C1; --dry-run returns before configuration'; exit 0 ;;
    deploy|status|uninstall) ;;
    *) echo 'Unsupported Demo action' >&2; exit 2 ;;
esac
REQUESTED_CLUSTER="${CLUSTER:-}"
[[ -f "$ROOT/deploy.conf" && ! -L "$ROOT/deploy.conf" ]] || { echo 'Demo configuration missing' >&2; exit 1; }
source "$ROOT/deploy.conf" >/dev/null 2>&1 || { echo 'Demo configuration failed' >&2; exit 1; }
[[ "$REQUESTED_CLUSTER" =~ ^(KIND|C[1-9][0-9]*)$ && "${CLUSTER:-}" == "$REQUESTED_CLUSTER" ]] || {
    echo 'Explicit cluster required; configuration must not replace it' >&2; exit 1;
}
export QUESTION_DATA_IMAGE QUESTION_DATA_NAMESPACE QUESTION_DATA_HOST QUESTION_DATA_PULL_SECRET QUESTION_DATA_WAIT_SECONDS DEEPSEEK_ENV_FILE
source "$K8S_ROOT_DIR/utils/deploy-target.sh"
sunmoon_deploy_target_init "$K8S_ROOT_DIR" || exit 1
if [[ "$ACTION" == deploy ]]; then
    source "$K8S_ROOT_DIR/sunmoonai/registry-platform/lib/config.sh"
    registry_load_config || exit 1
fi
python3 -B "$ROOT/deploy.py" "$ACTION" --apply
