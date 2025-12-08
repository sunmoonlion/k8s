#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP08
TARGET="${STEP08_TARGET:-master}"
WAIT="${STEP08_WAIT_TIMEOUT:-300}"
EXPECTED="${STEP08_EXPECTED_NODE_COUNT:-}"

# 远端 kubeconfig 路径（用于在目标节点上执行 kubectl 调用）
REMOTE_KUBECONFIG="${STEP08_REMOTE_KUBECONFIG:-/etc/kubernetes/admin.conf}"

precheck(){ log_info "[Step08] 预检集群验证"; }
ensure_resources(){ :; }

# 在指定索引节点上准备可读的 kubeconfig（使用统一函数）
_prepare_remote_kubeconfig_for_idx(){
  local idx="$1"
  prepare_remote_kubeconfig "$idx" "REMOTE_KUBECONFIG" || {
    log_error "[Step08] 无法在远端节点 $idx 准备可读的 kubeconfig"
    return 1
  }
}

execute(){
  log_info "[Step08] 验证 kube-system 就绪"
  _prepare_remote_kubeconfig_for_idx "$i" || return 1
  ssh_exec "$i" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get nodes -owide || true'"
  ssh_exec "$i" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl -n kube-system get pods -owide || true'"
  if [[ -n "$EXPECTED" ]]; then
    # 通过 base64 传输等待脚本，避免复杂转义
    local _script
    _script="timeout $WAIT bash -lc 'until [ \$(KUBECONFIG=\"\$REMOTE_KUBECONFIG\" kubectl get nodes --no-headers 2>/dev/null | wc -l) -eq $EXPECTED ]; do sleep 3; done'"
    local _b64; _b64="$(printf '%s' "$_script" | base64 -w0)"
    # 通过环境变量传递 REMOTE_KUBECONFIG
    ssh_exec "$i" "bash -lc 'echo $_b64 | base64 -d > /tmp/step08_wait.sh && REMOTE_KUBECONFIG=\"$REMOTE_KUBECONFIG\" bash /tmp/step08_wait.sh; rc=\$?; rm -f /tmp/step08_wait.sh; exit \$rc'" || true
  fi
}

verify(){ log_info "[Step08] 验证完成（如上输出）"; }

main(){ precheck; ensure_resources; for_each_node "$TARGET" execute; verify; }
main "$@"


