#!/usr/bin/env bash

# Restore the pre-Architecture-v2 Info/Knowledge API Redis ACLs from the
# currently deployed application Secrets. Secret values are copied as base64
# between namespaces and consumed through Job env references; they are never
# decoded or printed by this script.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="${APP_NAMESPACE:-app-platform-dev}"
DATA_NAMESPACE="${DATA_NAMESPACE:-data-platform-dev}"
REDIS_ADMIN_SECRET="${REDIS_ADMIN_SECRET:-redis-auth-secret}"
REDIS_HOST="${REDIS_HOST:-redis-sunmoonai-master.data-platform-dev.svc.cluster.local}"
REDIS_CLIENT_IMAGE="${REDIS_CLIENT_IMAGE:-harbor.sunmoonai.com:30443/k8s-images/redis:8.2.1-debian-12-r0}"
MODE="plan"

usage() {
  cat <<'EOF'
Usage: reconcile_pre_v2_redis_acls.sh [--apply] [options]

Options:
  --apply                 Reconcile ACLs, verify least privilege, restart APIs.
  --kubeconfig PATH       Kubeconfig (default: $KUBECONFIG or KIND config).
  --app-namespace NAME    Application namespace (default: app-platform-dev).
  --data-namespace NAME   Redis namespace (default: data-platform-dev).

Without --apply the command is a non-mutating plan.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --app-namespace) APP_NAMESPACE="$2"; shift 2 ;;
    --data-namespace) DATA_NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() {
  env -u DEBUG kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"
}

wait_for_job() {
  local job="$1" deadline=$((SECONDS + 120)) succeeded failed
  while (( SECONDS < deadline )); do
    succeeded="$(k get job "$job" -n "$DATA_NAMESPACE" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
    failed="$(k get job "$job" -n "$DATA_NAMESPACE" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
    [[ "$succeeded" == "1" ]] && return 0
    [[ -n "$failed" && "$failed" != "0" ]] && return 1
    sleep 2
  done
  return 1
}

cleanup_one() {
  local job="$1" secret="$2"
  k delete job "$job" -n "$DATA_NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  k delete secret "$secret" -n "$DATA_NAMESPACE" --ignore-not-found=true >/dev/null
}

reconcile_one() {
  local app="$1" source_secret="$2" allowed_key="$3" forbidden_key="$4"
  local temp_secret="architecture-v2-${app}-redis-acl"
  local job="architecture-v2-${app}-redis-acl"

  cleanup_one "$job" "$temp_secret"

  k get secret "$source_secret" -n "$APP_NAMESPACE" -o json \
    | jq --arg name "$temp_secret" --arg namespace "$DATA_NAMESPACE" '
        if (.data.REDIS_USER == null or .data.REDIS_PASSWORD == null) then
          error("source Secret lacks REDIS_USER or REDIS_PASSWORD")
        else
          {
            apiVersion: "v1",
            kind: "Secret",
            metadata: {
              name: $name,
              namespace: $namespace,
              labels: {
                "sunmoonai.com/architecture": "v2",
                "sunmoonai.com/purpose": "redis-acl-reconciliation"
              }
            },
            type: "Opaque",
            data: {
              REDIS_USER: .data.REDIS_USER,
              REDIS_PASSWORD: .data.REDIS_PASSWORD
            }
          }
        end
      ' \
    | k apply -f - >/dev/null

  cat <<EOF | k create -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${DATA_NAMESPACE}
  labels:
    sunmoonai.com/architecture: v2
    sunmoonai.com/purpose: redis-acl-reconciliation
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 120
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/architecture: v2
        sunmoonai.com/purpose: redis-acl-reconciliation
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: reconcile
          image: ${REDIS_CLIENT_IMAGE}
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          env:
            - name: REDIS_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${REDIS_ADMIN_SECRET}
                  key: redis-password
            - name: APP_REDIS_USER
              valueFrom:
                secretKeyRef:
                  name: ${temp_secret}
                  key: REDIS_USER
            - name: APP_REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${temp_secret}
                  key: REDIS_PASSWORD
          command: ["/bin/bash", "-ec"]
          args:
            - |
              export REDISCLI_AUTH="\$REDIS_ADMIN_PASSWORD"
              redis-cli -e -h '${REDIS_HOST}' --user default \
                ACL SETUSER "\$APP_REDIS_USER" reset on ">\$APP_REDIS_PASSWORD" \
                '~session:*' '~${app}:*' resetchannels \
                -@all +@read +@write +@connection +@hash +@string +@list +@set +@sortedset \
                -@dangerous >/dev/null
              redis-cli -e -h '${REDIS_HOST}' --user default ACL SAVE >/dev/null

              export REDISCLI_AUTH="\$APP_REDIS_PASSWORD"
              test "\$(redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" PING)" = PONG
              redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" \
                SET '${allowed_key}' ok EX 30 >/dev/null
              test "\$(redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" \
                GET '${allowed_key}')" = ok
              redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" \
                DEL '${allowed_key}' >/dev/null
              if redis-cli -e -h '${REDIS_HOST}' --user "\$APP_REDIS_USER" \
                SET '${forbidden_key}' denied EX 30 >/dev/null 2>&1; then
                printf 'out-of-scope Redis key was accepted\n' >&2
                exit 1
              fi
              printf 'redis_acl_reconciled app=${app} positive=passed negative=passed\n'
EOF

  if ! wait_for_job "$job"; then
    k logs "job/${job}" -n "$DATA_NAMESPACE" --tail=80 >&2 || true
    cleanup_one "$job" "$temp_secret"
    return 1
  fi
  k logs "job/${job}" -n "$DATA_NAMESPACE" --tail=20
  cleanup_one "$job" "$temp_secret"
}

printf 'PLAN source=current application Redis Secrets\n'
printf 'PLAN targets=info_admin_backend,knowledge_admin_backend\n'
printf 'PLAN mutation=two Redis ACL users and two API rollouts only\n'
printf 'PLAN output=no credentials\n'

[[ "$MODE" == "apply" ]] || exit 0

k get secret "$REDIS_ADMIN_SECRET" -n "$DATA_NAMESPACE" >/dev/null
k get service redis-sunmoonai-master -n "$DATA_NAMESPACE" >/dev/null

reconcile_one \
  info \
  info-admin-backend-redis-conn \
  'session:architecture-v2:info:acl-test' \
  'knowledge:architecture-v2:forbidden'
reconcile_one \
  knowledge \
  knowledge-admin-backend-redis-conn \
  'session:architecture-v2:knowledge:acl-test' \
  'info:architecture-v2:forbidden'

k rollout restart deployment/info-admin-backend deployment/knowledge-admin-backend \
  -n "$APP_NAMESPACE" >/dev/null
k rollout status deployment/info-admin-backend -n "$APP_NAMESPACE" --timeout=300s
k rollout status deployment/knowledge-admin-backend -n "$APP_NAMESPACE" --timeout=300s

for deployment in info-admin-backend knowledge-admin-backend; do
  ready="$(k get deployment "$deployment" -n "$APP_NAMESPACE" \
    -o jsonpath='{.status.readyReplicas}/{.status.replicas}')"
  [[ "$ready" == "1/1" ]] || {
    printf 'deployment not ready: %s=%s\n' "$deployment" "$ready" >&2
    exit 1
  }
done

printf 'architecture_v2_r2_redis_preflight=passed\n'
