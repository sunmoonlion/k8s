#!/usr/bin/env bash
# 修复 local-path-provisioner helper Pod 在部分 worker 节点 ErrImageNeverPull 的问题。
# 用法: CLUSTER=C1 ./fix-local-path-helper-image.sh
# 可选: HELPER_IMAGE=... HELPER_PULL_POLICY=IfNotPresent
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/unified-deployment-template.sh"

read_k8s_config
setup_kubectl_environment

HELPER_IMAGE="${HELPER_IMAGE:-harbor.sunmoonai.com:30443/k8s-images/os-shell:12-debian-12-r51}"
HELPER_PULL_POLICY="${HELPER_PULL_POLICY:-IfNotPresent}"
NS="${LOCAL_PATH_NAMESPACE:-local-path-storage}"
CM="${LOCAL_PATH_CONFIGMAP:-local-path-config}"

log_info "Patch ${NS}/${CM}: helper image=${HELPER_IMAGE}, pullPolicy=${HELPER_PULL_POLICY}"

kubectl get configmap "${CM}" -n "${NS}" >/dev/null

python3 - "${HELPER_IMAGE}" "${HELPER_PULL_POLICY}" <<'PY'
import json, re, subprocess, sys

image, pull_policy = sys.argv[1:3]
cm = json.loads(subprocess.check_output([
    "kubectl", "get", "configmap", "local-path-config",
    "-n", "local-path-storage", "-o", "json"
]))
helper = cm["data"]["helperPod.yaml"]
helper = re.sub(r"(?m)^(\s*image:\s).*", rf"\1{image}", helper, count=1)
if "imagePullPolicy:" in helper:
    helper = re.sub(r"(?m)^(\s*imagePullPolicy:\s).*", rf"\1{pull_policy}", helper, count=1)
else:
    helper = re.sub(
        rf"(?m)^(\s*image:\s{re.escape(image)}\s*)$",
        rf"\1\n          imagePullPolicy: {pull_policy}",
        helper,
        count=1,
    )
patch = json.dumps({"data": {"helperPod.yaml": helper}})
subprocess.check_call([
    "kubectl", "patch", "configmap", "local-path-config",
    "-n", "local-path-storage", "--type", "merge", "-p", patch
])
print("[ok] configmap patched")
PY

log_success "local-path-config 已更新（provisioner 会在下次创建 helper Pod 时使用新镜像策略，无需重启 deployment）"
