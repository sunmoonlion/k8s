#!/usr/bin/env bash

# Deploy and validate the Investment Architecture v2 R4 candidates in a fully
# isolated namespace. The accepted Research topology in app-platform-dev is a
# read-only rollback baseline and must remain byte-for-byte unchanged.

set -euo pipefail
umask 077

ROOT="/home/zymun"
SCRIPT_ROOT="${ROOT}/k8s/sunmoonai/docs/architecture-v2/scripts"

export R3_APP="investment"
export R3_NAMESPACE="${R4_INVESTMENT_NAMESPACE:-investment-architecture-v2-r4}"
export R3_RELEASE_ID="r4-investment-001"
export R3_ADMIN_ORIGIN="https://investment-admin-r4.sunmoonai.com:30443"
export R3_WEB_ORIGIN="https://investment-web-r4.sunmoonai.com:30443"
export R3_CASDOOR_ORIGIN="https://casdoor.sunmoonai.com:30443"
export R3_PROVIDER_NAMESPACE="app-platform-dev"
export R3_INGRESS_NAMESPACE="ingress-platform-dev"
export R3_IDENTITY_SECRET="sunmoonai-architecture-v2-r4-investment-identity"
export R3_ADMIN_APPLICATION="sunmoonai-investment-architecture-v2-r4-admin"
export R3_WEB_APPLICATION="sunmoonai-investment-architecture-v2-r4-web"
export R3_ADMIN_DISPLAY_NAME="Investment Architecture v2 R4 Admin"
export R3_WEB_DISPLAY_NAME="Investment Architecture v2 R4 Web"
export R3_TASK_LABEL="architecture-v2-r4-investment"
export R3_IDENTITY_JOB_PREFIX="architecture-v2-r4-investment-identity"
export R3_RESULT_TASK="architecture-v2-r4-investment"
export R3_TARGET_TLS_SECRET="investment-r4-tls"
export R3_POLICY_CLUSTER_NAME="investment-r4-policy"
export R3_EVIDENCE_DIR="${ROOT}/k8s/sunmoonai/docs/architecture-v2/evidence/R4-investment-gate"

export BACKEND_IMAGE="harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:abab9895b9323430fa357a01c4ad796ea3130b76853c7206306be54d3307834d"
export ADMIN_IMAGE="harbor.sunmoonai.com:30443/app-images/investment-admin-frontend@sha256:15d8253d2125045f38ea8bd159df77642250214b3bd72e8733cedbd50464f41d"
export WEB_IMAGE="harbor.sunmoonai.com:30443/app-images/investment-web-frontend@sha256:d3ac86bdea887ed3be4ab2b61a8928bdf23086e20137c02e0ec2ca520ae51a0a"

# The accepted pre-rename Research Web image is used only to prove native
# Deployment rollback inside the isolated R4 namespace. It is never promoted
# as an Investment candidate and the live Research deployment is not touched.
export WEB_R2_IMAGE="harbor.sunmoonai.com:30443/app-images/research-web-frontend@sha256:46f7c4b59857b734b6d74257c5f9e02d3d3bba64a640b4d030b9290f73ed4b91"
export R3_R2_BACKEND_ENV_NAME="WEB_BACKEND_INTERNAL_URL"

research_topology_hash() {
  kubectl --kubeconfig "${KUBECONFIG:-$HOME/.kube/kind-config}" get \
    deployments.apps,statefulsets.apps,daemonsets.apps,services,configmaps,secrets,persistentvolumeclaims,serviceaccounts,networkpolicies.networking.k8s.io,ingressroutes.traefik.io,jobs.batch,cronjobs.batch,roles.rbac.authorization.k8s.io,rolebindings.rbac.authorization.k8s.io,poddisruptionbudgets.policy,horizontalpodautoscalers.autoscaling \
    -n "$R3_PROVIDER_NAMESPACE" -o json \
    | python3 -c '
import hashlib, json, sys

payload = json.load(sys.stdin)
items = []
for item in payload.get("items", []):
    metadata = item.get("metadata", {})
    if "research" not in metadata.get("name", ""):
        continue
    item.pop("status", None)
    metadata.pop("managedFields", None)
    if item.get("kind") == "Secret":
        item["data"] = {
            key: hashlib.sha256(value.encode()).hexdigest()
            for key, value in sorted(item.get("data", {}).items())
        }
        item.pop("stringData", None)
    items.append(item)
items.sort(key=lambda value: (
    value.get("apiVersion", ""), value.get("kind", ""),
    value.get("metadata", {}).get("namespace", ""),
    value.get("metadata", {}).get("name", ""),
))
encoded = json.dumps(items, sort_keys=True, separators=(",", ":")).encode()
print(hashlib.sha256(encoded).hexdigest())
'
}

research_before="$(research_topology_hash)"
"${SCRIPT_ROOT}/run_r3_template_gate.sh"
research_after="$(research_topology_hash)"

if [[ "$research_before" != "$research_after" ]]; then
  printf 'Research rollback topology changed during Investment R4 gate\n' >&2
  exit 1
fi

python3 - "$R3_EVIDENCE_DIR/research-topology.json" "$research_before" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps({
    "task": "architecture-v2-r4-investment-research-topology",
    "result": "passed",
    "namespace": "app-platform-dev",
    "before_sha256": sys.argv[2],
    "after_sha256": sys.argv[2],
    "secret_values_printed": False,
}, indent=2) + "\n")
PY
