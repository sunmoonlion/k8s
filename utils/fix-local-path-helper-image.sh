#!/usr/bin/env bash
# 修复 local-path-provisioner helper Pod 在部分 worker 节点 ErrImageNeverPull 的问题。
#
# 用法:
#   CLUSTER=C1 DISABLE_AUTO_CLEANUP=true ./fix-local-path-helper-image.sh
#
# 策略:
#   - C1/C2/C3 离线集群默认 bitnami/os-shell + imagePullPolicy=Never（与 step09 一致）
#   - 显式 HELPER_USE_HARBOR=true 时改用 Harbor，并同步 harbor-registry-secret 到 local-path-storage
set -euo pipefail

export DISABLE_AUTO_CLEANUP=true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/unified-deployment-template.sh"

read_k8s_config
setup_kubectl_environment

NS="${LOCAL_PATH_NAMESPACE:-local-path-storage}"
CM="${LOCAL_PATH_CONFIGMAP:-local-path-config}"
SECRET_NAME="${LOCAL_PATH_HARBOR_SECRET:-harbor-registry-secret}"
SECRET_SOURCE_NS="${LOCAL_PATH_HARBOR_SECRET_SOURCE_NS:-app-platform-dev}"

_resolve_offline_helper_defaults() {
    local cluster="${CLUSTER:-}"
    cluster="$(echo "$cluster" | tr '[:lower:]' '[:upper:]')"
    case "$cluster" in
        C1|C2|C3)
            HELPER_IMAGE="${HELPER_IMAGE:-${C1_STEP09_HELPER_IMAGE:-bitnami/os-shell:12-debian-12-r51}}"
            HELPER_PULL_POLICY="${HELPER_PULL_POLICY:-${C1_STEP09_HELPER_IMAGE_PULL_POLICY:-Never}}"
            ;;
        *)
            HELPER_IMAGE="${HELPER_IMAGE:-bitnami/os-shell:12-debian-12-r51}"
            HELPER_PULL_POLICY="${HELPER_PULL_POLICY:-Never}"
            ;;
    esac
}

if [[ "${HELPER_USE_HARBOR:-false}" == "true" ]]; then
    if declare -F get_cluster_harbor_registry >/dev/null 2>&1; then
        HELPER_IMAGE="${HELPER_IMAGE:-$(get_cluster_harbor_registry)/k8s-images/os-shell:12-debian-12-r51}"
    else
        HELPER_IMAGE="${HELPER_IMAGE:-harbor.sunmoonai.com:30443/k8s-images/os-shell:12-debian-12-r51}"
    fi
    HELPER_PULL_POLICY="${HELPER_PULL_POLICY:-IfNotPresent}"
else
    _resolve_offline_helper_defaults
fi

log_info "Patch ${NS}/${CM}: helper image=${HELPER_IMAGE}, pullPolicy=${HELPER_PULL_POLICY}"

kubectl get configmap "${CM}" -n "${NS}" >/dev/null

if [[ "${HELPER_USE_HARBOR:-false}" == "true" ]]; then
    if kubectl get secret "$SECRET_NAME" -n "$SECRET_SOURCE_NS" >/dev/null 2>&1; then
        kubectl get secret "$SECRET_NAME" -n "$SECRET_SOURCE_NS" -o yaml \
            | sed "s/namespace: ${SECRET_SOURCE_NS}/namespace: ${NS}/" \
            | grep -v '^\s*resourceVersion:\|^\s*uid:\|^\s*creationTimestamp:' \
            | kubectl apply -f -
        log_success "已同步 ${SECRET_SOURCE_NS}/${SECRET_NAME} -> ${NS}/${SECRET_NAME}"
    else
        log_warn "未找到 ${SECRET_SOURCE_NS}/${SECRET_NAME}，Harbor helper 可能仍无法拉取"
    fi
fi

USE_HARBOR_SECRET="${HELPER_USE_HARBOR:-false}" \
HELPER_IMAGE="$HELPER_IMAGE" \
HELPER_PULL_POLICY="$HELPER_PULL_POLICY" \
SECRET_NAME="$SECRET_NAME" \
python3 <<'PY'
import json, os, re, subprocess, textwrap

image = os.environ["HELPER_IMAGE"]
pull_policy = os.environ["HELPER_PULL_POLICY"]
use_secret = os.environ.get("USE_HARBOR_SECRET", "false") == "true"
secret_name = os.environ.get("SECRET_NAME", "harbor-registry-secret")

pull_secret_block = ""
if use_secret:
    pull_secret_block = textwrap.dedent(f"""\
      imagePullSecrets:
        - name: {secret_name}
""")

helper = textwrap.dedent(f"""\
apiVersion: v1
kind: Pod
metadata:
  name: helper-pod
spec:
  priorityClassName: system-node-critical
{pull_secret_block}  tolerations:
    - key: node.kubernetes.io/disk-pressure
      operator: Exists
      effect: NoSchedule
  containers:
    - name: helper-pod
      image: {image}
      imagePullPolicy: {pull_policy}
      securityContext:
        runAsUser: 0
""")

patch = json.dumps({"data": {"helperPod.yaml": helper}})
subprocess.check_call([
    "kubectl", "patch", "configmap", "local-path-config",
    "-n", "local-path-storage", "--type", "merge", "-p", patch,
])
print("[ok] configmap patched")
PY

kubectl rollout restart deployment/local-path-provisioner -n "${NS}" >/dev/null 2>&1 || true
log_success "local-path-config 已更新；已重启 local-path-provisioner 使 helper 模板生效"
