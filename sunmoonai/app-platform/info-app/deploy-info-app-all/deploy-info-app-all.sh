#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$THIS_DIR")"
ACTION=""
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
TIMEOUT=300
COMPONENT=all
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    deploy|validate|validate-resources|plan|server-dry-run|apply|status|logs|drift|uninstall|cleanup)
      [[ -z "$ACTION" ]] || { echo "重复操作参数: $1" >&2; exit 2; }
      ACTION="$1"
      shift
      ;;
    --cluster)
      [[ "${2:-}" == "KIND" ]] || {
        echo "Info formal release 当前只验收 KIND；收到: ${2:-}" >&2
        exit 2
      }
      shift 2
      ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --component) COMPONENT="$2"; shift 2 ;;
    --*) echo "未知参数: $1" >&2; exit 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

ACTION="${ACTION:-plan}"
case "$ACTION" in
  deploy) ACTION=apply ;;
  validate|validate-resources) ACTION=server-dry-run ;;
  logs) ACTION=status ;;
  plan|server-dry-run|apply|status|drift) ;;
  uninstall|cleanup)
    echo "拒绝从默认入口删除正式 Info；回滚/清理由 R7 专用流程执行。" >&2
    exit 2
    ;;
esac

# Compatibility with deploy-app-platform-all: project namespace environment dry-run.
if [[ ${#POSITIONAL[@]} -gt 4 ]]; then
  echo "位置参数过多: ${POSITIONAL[*]}" >&2
  exit 2
fi
if [[ ${#POSITIONAL[@]} -ge 2 && "${POSITIONAL[1]}" != "app-platform-dev" ]]; then
  echo "Info formal release namespace 已锁定为 app-platform-dev；收到: ${POSITIONAL[1]}" >&2
  exit 2
fi

exec python3 "$ROOT/deployment/deploy.py" "$ACTION" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --timeout "$TIMEOUT" \
  --component "$COMPONENT"
