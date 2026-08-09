#!/usr/bin/env bash

# Packet-level NetworkPolicy gate for Architecture v2 R3.
# The long-lived development KIND cluster uses kindnetd, which does not enforce
# NetworkPolicy. This gate creates a disposable, policy-capable Calico cluster
# and validates both allowed and denied flows against the rendered policy file.

set -euo pipefail
umask 077

KIND_BIN="${KIND_BIN:-kind}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
CLUSTER_NAME="${R3_POLICY_CLUSTER_NAME:-tpl-r3-policy}"
NODE_IMAGE="${R3_POLICY_NODE_IMAGE:-kindest/node:v1.27.3-sunmoonai}"
CALICO_VERSION="v3.28.2"
CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
CALICO_SHA256="be59408bf990e96276f631d2f9285c2a0f9802194c0ad1cecdb6d9c52623a1c8"
CALICO_ARCHIVE_DIR="${R3_CALICO_ARCHIVE_DIR:-/home/zymun/packages-to-be-installed/images}"
CALICO_MANIFEST_CACHE="${R3_CALICO_MANIFEST_CACHE:-${CALICO_ARCHIVE_DIR}/calico-v3.28.2.yaml}"
SERVER_IMAGE="${R3_POLICY_SERVER_IMAGE:-python:3.12-slim}"
CLIENT_IMAGE="${R3_POLICY_CLIENT_IMAGE:-busybox:latest}"
NAMESPACE=""
APP=""
BUNDLE=""
KEEP_CLUSTER=false
WORK_DIR="$(mktemp -d /tmp/architecture-v2-r3-calico.XXXXXX)"
KUBECONFIG_PATH="${WORK_DIR}/kubeconfig"

usage() {
  printf 'usage: %s --bundle DIR [--keep-cluster]\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle)
      BUNDLE="${2:-}"
      shift 2
      ;;
    --keep-cluster)
      KEEP_CLUSTER=true
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ -n "$BUNDLE" && -f "${BUNDLE}/30-network-policies.yaml" && -f "${BUNDLE}/release.json" ]] || {
  usage
  exit 2
}

read -r APP NAMESPACE < <(
  python3 - "${BUNDLE}/release.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    release = json.load(handle)
resource_app = release.get("app") or release.get("resource_app")
if not resource_app:
    raise SystemExit("release app/resource_app is absent")
print(resource_app, release["namespace"])
PY
)
[[ -n "$APP" && -n "$NAMESPACE" ]] || {
  printf 'bundle app or namespace is absent: %s\n' "${BUNDLE}/release.json" >&2
  exit 2
}
TASK="${R3_POLICY_TASK:-architecture-v2-r3-network-policy}"
BACKEND_DEPLOYMENT="${APP}-backend-api"
BACKEND_SERVICE="${APP}-backend"

cleanup() {
  local rc=$?
  trap - EXIT INT TERM HUP
  set +e
  if [[ "$KEEP_CLUSTER" != true ]]; then
    "$KIND_BIN" delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1
  fi
  if [[ "$rc" -eq 0 && "$KEEP_CLUSTER" != true ]]; then
    rm -rf "$WORK_DIR"
  else
    printf 'Calico policy diagnostics retained at %s\n' "$WORK_DIR" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM HUP

for command in "$KIND_BIN" "$KUBECTL_BIN" "$DOCKER_BIN" curl install python3 sha256sum; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'required command is missing: %s\n' "$command" >&2
    exit 1
  }
done

if "$KIND_BIN" get clusters 2>/dev/null | grep -Fxq "$CLUSTER_NAME"; then
  printf 'refusing to replace existing KIND cluster: %s\n' "$CLUSTER_NAME" >&2
  exit 1
fi

printf 'R3_POLICY_STAGE=calico_manifest\n'
if [[ -f "$CALICO_MANIFEST_CACHE" ]] \
  && printf '%s  %s\n' "$CALICO_SHA256" "$CALICO_MANIFEST_CACHE" \
    | sha256sum --check --status; then
  install -m 0644 "$CALICO_MANIFEST_CACHE" "${WORK_DIR}/calico.yaml"
  printf 'R3_POLICY_CALICO_SOURCE=verified_cache\n'
else
  curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 90 --retry 2 --retry-all-errors \
    --output "${WORK_DIR}/calico.yaml" "$CALICO_URL"
  printf '%s  %s\n' "$CALICO_SHA256" "${WORK_DIR}/calico.yaml" \
    | sha256sum --check --status
  mkdir -p "$CALICO_ARCHIVE_DIR"
  install -m 0644 "${WORK_DIR}/calico.yaml" "$CALICO_MANIFEST_CACHE"
  printf 'R3_POLICY_CALICO_SOURCE=verified_download\n'
fi
printf '%s  %s\n' "$CALICO_SHA256" "${WORK_DIR}/calico.yaml" | sha256sum --check --status

calico_images=(
  "docker.io/calico/cni:${CALICO_VERSION}"
  "docker.io/calico/node:${CALICO_VERSION}"
  "docker.io/calico/kube-controllers:${CALICO_VERSION}"
)
calico_archives=(
  "${CALICO_ARCHIVE_DIR}/calico_cni_v3.28.2.tar"
  "${CALICO_ARCHIVE_DIR}/calico_node_v3.28.2.tar"
  "${CALICO_ARCHIVE_DIR}/calico_kube-controllers_v3.28.2.tar"
)
calico_archive_hashes=(
  "0b88b65ca4ea6716c5158604a1cdd8a471d184bff08ed65ca4535f172ded49a1"
  "9cb46940b8c426d1fe329358b315207885b3054bc8f5d62b2d405f16daf0addd"
  "cd28db6133635b548dcbc0afaed89ab18e70b32a01f826727f2a3301927722f3"
)
for index in "${!calico_images[@]}"; do
  image="${calico_images[$index]}"
  archive="${calico_archives[$index]}"
  if ! "$DOCKER_BIN" image inspect "$image" >/dev/null 2>&1 && [[ -f "$archive" ]]; then
    printf '%s  %s\n' "${calico_archive_hashes[$index]}" "$archive" \
      | sha256sum --check --status
    "$DOCKER_BIN" load --input "$archive" >/dev/null
  fi
done
for image in "${calico_images[@]}" "$SERVER_IMAGE" "$CLIENT_IMAGE"; do
  if ! "$DOCKER_BIN" image inspect "$image" >/dev/null 2>&1; then
    "$DOCKER_BIN" pull "$image" >/dev/null
  fi
done

cat >"${WORK_DIR}/kind.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
nodes:
  - role: control-plane
  - role: worker
EOF

printf 'R3_POLICY_STAGE=cluster\n'
KUBECONFIG="$KUBECONFIG_PATH" "$KIND_BIN" create cluster \
  --name "$CLUSTER_NAME" \
  --image "$NODE_IMAGE" \
  --config "${WORK_DIR}/kind.yaml" \
  --kubeconfig "$KUBECONFIG_PATH" >/dev/null

mapfile -t kind_nodes < <("$KIND_BIN" get nodes --name "$CLUSTER_NAME")
all_images=("${calico_images[@]}" "$SERVER_IMAGE" "$CLIENT_IMAGE")
for index in "${!all_images[@]}"; do
  image="${all_images[$index]}"
  archive="${WORK_DIR}/image-${index}.tar"
  "$DOCKER_BIN" save --output "$archive" "$image"
  for node in "${kind_nodes[@]}"; do
    "$DOCKER_BIN" exec --privileged -i "$node" \
      ctr --namespace=k8s.io images import \
      --platform=linux/amd64 --snapshotter=overlayfs - \
      <"$archive" >/dev/null
  done
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

k apply -f "${WORK_DIR}/calico.yaml" >/dev/null
k rollout status daemonset/calico-node -n kube-system --timeout=300s >/dev/null
k rollout status deployment/calico-kube-controllers -n kube-system --timeout=300s >/dev/null
k wait --for=condition=Ready node --all --timeout=300s >/dev/null

printf 'R3_POLICY_STAGE=policy\n'
for namespace in "$NAMESPACE" app-platform-dev ingress-platform-dev; do
  k create namespace "$namespace" --dry-run=client -o yaml | k apply -f - >/dev/null
done
k label namespace app-platform-dev kubernetes.io/metadata.name=app-platform-dev --overwrite >/dev/null
k label namespace ingress-platform-dev kubernetes.io/metadata.name=ingress-platform-dev --overwrite >/dev/null
k apply -f "${BUNDLE}/30-network-policies.yaml" >/dev/null

cat <<EOF | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${BACKEND_DEPLOYMENT}
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      sunmoonai.com/app: ${APP}
      app.kubernetes.io/component: backend-api
  template:
    metadata:
      labels:
        sunmoonai.com/app: ${APP}
        app.kubernetes.io/component: backend-api
    spec:
      automountServiceAccountToken: false
      containers:
        - name: server
          image: ${SERVER_IMAGE}
          imagePullPolicy: Never
          command: ["python", "-m", "http.server", "8000"]
          ports:
            - {name: http, containerPort: 8000}
          readinessProbe:
            tcpSocket: {port: http}
            periodSeconds: 2
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
---
apiVersion: v1
kind: Service
metadata:
  name: ${BACKEND_SERVICE}
  namespace: ${NAMESPACE}
spec:
  selector:
    sunmoonai.com/app: ${APP}
    app.kubernetes.io/component: backend-api
  ports:
    - {name: http, port: 8000, targetPort: http}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: knowledge-policy-target
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: knowledge-policy-target
  template:
    metadata:
      labels:
        app: knowledge-policy-target
        sunmoonai.com/internal-provider: 'true'
    spec:
      automountServiceAccountToken: false
      containers:
        - name: server
          image: ${SERVER_IMAGE}
          imagePullPolicy: Never
          command: ["python", "-m", "http.server", "8000"]
          ports:
            - {name: http, containerPort: 8000}
          readinessProbe:
            tcpSocket: {port: http}
            periodSeconds: 2
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
---
apiVersion: v1
kind: Service
metadata:
  name: knowledge-admin-backend
  namespace: ${NAMESPACE}
spec:
  selector:
    app: knowledge-policy-target
  ports:
    - {name: http, port: 8000, targetPort: http}
EOF
k rollout status "deployment/${BACKEND_DEPLOYMENT}" -n "$NAMESPACE" --timeout=180s >/dev/null
k rollout status deployment/knowledge-policy-target -n "$NAMESPACE" --timeout=180s >/dev/null

probe() {
  local name="$1" labels="$2" expected="$3" target="${4:-http://${BACKEND_SERVICE}:8000/}" phase=""
  k delete pod "$name" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  k run "$name" -n "$NAMESPACE" \
    --restart=Never \
    --image="$CLIENT_IMAGE" \
    --image-pull-policy=Never \
    --labels="$labels" \
    --overrides='{"spec":{"automountServiceAccountToken":false}}' \
    --command -- sh -ec \
    "timeout 12 wget -q -T 5 -O /dev/null '${target}'" >/dev/null
  for _ in $(seq 1 30); do
    phase="$(k get pod "$name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ "$phase" == Succeeded || "$phase" == Failed ]] && break
    sleep 1
  done
  k logs "$name" -n "$NAMESPACE" --tail=20 >/dev/null 2>&1 || true
  k delete pod "$name" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  [[ "$phase" == "$expected" ]] || {
    printf 'network probe %s expected=%s actual=%s\n' "$name" "$expected" "$phase" >&2
    return 1
  }
}

printf 'R3_POLICY_STAGE=packet_gate\n'
probe r3-policy-internal "sunmoonai.com/allow-${APP}-internal=true" Succeeded
probe r3-policy-frontend "sunmoonai.com/app=${APP},app.kubernetes.io/component=admin-frontend" Succeeded
probe r3-policy-denied 'sunmoonai.com/r3-probe=denied' Failed
probe r3-policy-worker-knowledge \
  "sunmoonai.com/app=${APP},app.kubernetes.io/component=backend-worker" \
  Succeeded \
  'http://knowledge-admin-backend:8000/'
probe r3-policy-api-knowledge \
  "sunmoonai.com/app=${APP},app.kubernetes.io/component=backend-api" \
  Failed \
  'http://knowledge-admin-backend:8000/'
probe r3-policy-scheduler-knowledge \
  "sunmoonai.com/app=${APP},app.kubernetes.io/component=backend-scheduler" \
  Failed \
  'http://knowledge-admin-backend:8000/'

printf '{"task":"%s","result":"passed","cni":"calico","calico_version":"%s","internal_to_backend":200,"frontend_to_backend":200,"unlabelled_to_backend":"denied","worker_to_knowledge":200,"api_to_knowledge":"denied","scheduler_to_knowledge":"denied","credentials_printed":false}\n' "$TASK" "$CALICO_VERSION"
