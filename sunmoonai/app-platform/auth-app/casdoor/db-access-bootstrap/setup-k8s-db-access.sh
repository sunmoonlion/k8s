#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
# sunmoonai/.../db-access-bootstrap -> ../../../../.. = k8s repo root
K8S_ROOT="$(cd "${SCRIPT_DIR}/../../../../.." && pwd)"

# shellcheck disable=SC1091
source "${CONFIG_DIR}/common.env"

# dbctl 依赖 kubectl；从 WSL 直接执行时未必已有 KUBECONFIG/隧道
ensure_kubectl_for_dbctl() {
  if [[ -n "${KUBECONFIG:-}" ]] && kubectl cluster-info >/dev/null 2>&1; then
    return 0
  fi
  local tmpl="${K8S_ROOT}/utils/unified-deployment-template.sh"
  [[ -f "$tmpl" ]] || die "缺少统一部署模板，无法建立集群连接: $tmpl"
  # shellcheck disable=SC1091
  source "$tmpl"
  export DISABLE_AUTO_CLEANUP="${DISABLE_AUTO_CLEANUP:-true}"
  if ! setup_kubectl_environment; then
    die "无法建立 Kubernetes 连接（请设置 CLUSTER 并确认 k8s-admin.conf）"
  fi
  log "kubectl 已就绪: KUBECONFIG=${KUBECONFIG:-<unset>}"
}

PG_CONFIG="${PG_K8S_CONFIG:-${CONFIG_DIR}/postgresql.k8s.env}"
REDIS_CONFIG="${REDIS_K8S_CONFIG:-${CONFIG_DIR}/redis.k8s.env}"
MONGO_CONFIG="${MONGO_K8S_CONFIG:-${CONFIG_DIR}/mongodb.k8s.env}"

log() { printf '[db-access-bootstrap][k8s] %s\n' "$*"; }
die() { printf '[db-access-bootstrap][k8s][error] %s\n' "$*" >&2; exit 1; }

bool_true() {
  case "${1:-false}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac
}

require_file() { [[ -f "$1" ]] || die "Missing file: $1"; }

main() {
  [[ -x "${DBCTL_BIN}" ]] || die "DBCTL_BIN not executable: ${DBCTL_BIN}"
  command -v kubectl >/dev/null 2>&1 || die "Missing kubectl"
  ensure_kubectl_for_dbctl

  bool_true "${ENABLE_POSTGRESQL:-false}" && require_file "${PG_CONFIG}" && "${DBCTL_BIN}" --config "${PG_CONFIG}" --target k8s --action provision
  bool_true "${ENABLE_MONGODB:-false}" && require_file "${MONGO_CONFIG}" && "${DBCTL_BIN}" --config "${MONGO_CONFIG}" --target k8s --action provision

  # Redis: 这里默认也走 dbctl（会尝试创建 ACL 用户）。如果你的应用不支持 username，可以把 ENABLE_REDIS=false
  # 或者把 redis.k8s.env 里 APP_DB_USER 留空改为“只输出连接信息”（后续可再扩展 driver）。
  bool_true "${ENABLE_REDIS:-false}" && require_file "${REDIS_CONFIG}" && "${DBCTL_BIN}" --config "${REDIS_CONFIG}" --target k8s --action provision

  log "Done. k8s secrets applied in namespace: ${NAMESPACE}"
}

main "$@"
