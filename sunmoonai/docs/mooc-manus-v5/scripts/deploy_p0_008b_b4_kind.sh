#!/usr/bin/env bash

# Deploy an isolated, same-origin Next + Nest B4 pair. The script never mutates
# Info/Knowledge/Research Deployments. Images must be immutable digest refs.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="app-platform-dev"
HOST="tpl-web-b4.sunmoonai.com"
PUBLIC_PORT="30443"
BACKEND_IMAGE=''
FRONTEND_IMAGE=''
DEPLOYMENT_ID='b4-v1'
# The legacy Web Secret is intentionally not used: it may predate a Redis ACL
# rotation. P0-005 continuously verifies the Admin session credential, so B4
# copies that currently valid credential into its own isolated Secret and uses
# a disjoint key prefix.
REDIS_SOURCE_SECRET='info-admin-backend-redis-conn'
REDIS_SECRET='sunmoonai-p0-008b-b4-redis'
REDIS_USER='tpl_web_backend_b4'
REDIS_KEY_PATTERN='sunmoonai:auth:info:web:tpl-b4:*'
REDIS_ADMIN_NAMESPACE='data-platform-dev'
REDIS_ADMIN_SECRET='redis-auth-secret'
REDIS_CLIENT_IMAGE='harbor.sunmoonai.com:30443/k8s-images/redis:8.2.1-debian-12-r0'
REDIS_PROVISION_SECRET='sunmoonai-p0-008b-b4-redis-provision'
IDENTITY_SECRET='sunmoonai-p0-008b-b4-identity'
MODE='plan'

usage() {
  cat <<'EOF'
Usage: deploy_p0_008b_b4_kind.sh [--apply|--cleanup] [options]
  --backend-image IMAGE@sha256:DIGEST   Immutable Nest image (required for apply)
  --frontend-image IMAGE@sha256:DIGEST  Immutable Next image (required for apply)
  --deployment-id ID                    Rollout identity (default: b4-v1)
  --kubeconfig PATH                     Kubeconfig path
  --namespace NAME                      Target namespace
  --host HOST                           B4 same-origin host
  --public-port PORT                    Browser-visible TLS port
  --redis-source-secret NAME            Credential source copied without output
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE='apply'; shift ;;
    --cleanup) MODE='cleanup'; shift ;;
    --backend-image) BACKEND_IMAGE="$2"; shift 2 ;;
    --frontend-image) FRONTEND_IMAGE="$2"; shift 2 ;;
    --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --public-port) PUBLIC_PORT="$2"; shift 2 ;;
    --redis-source-secret) REDIS_SOURCE_SECRET="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

validate_kubectl_compatibility() {
  local versions client_minor server_minor delta
  versions="$(env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" version -o json)"
  client_minor="$(jq -r '.clientVersion.minor | sub("[^0-9].*$"; "")' <<<"$versions")"
  server_minor="$(jq -r '.serverVersion.minor | sub("[^0-9].*$"; "")' <<<"$versions")"
  [[ "$client_minor" =~ ^[0-9]+$ && "$server_minor" =~ ^[0-9]+$ ]] || {
    printf 'unable to determine kubectl/client minor versions\n' >&2
    return 1
  }
  delta=$((client_minor - server_minor))
  (( delta < 0 )) && delta=$((-delta))
  (( delta <= 1 )) || {
    printf 'unsupported kubectl skew: client_minor=%s server_minor=%s; set KUBECTL_BIN to a compatible client\n' \
      "$client_minor" "$server_minor" >&2
    return 1
  }
  printf 'B4 kubectl skew preflight passed client_minor=%s server_minor=%s\n' \
    "$client_minor" "$server_minor"
}

wait_for_job() {
  local namespace="$1" job="$2" deadline=$((SECONDS + 120)) succeeded failed
  while (( SECONDS < deadline )); do
    succeeded="$(k get job "$job" -n "$namespace" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
    failed="$(k get job "$job" -n "$namespace" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
    [[ "$succeeded" == 1 ]] && return 0
    [[ -n "$failed" && "$failed" != 0 ]] && return 1
    sleep 2
  done
  return 1
}

delete_job_and_wait() {
  local namespace="$1" job="$2"
  k delete job "$job" -n "$namespace" \
    --ignore-not-found=true --wait=true >/dev/null
}

job_logs() {
  local namespace="$1" job="$2" tail_lines="$3" pod
  pod="$(
    k get pods -n "$namespace" -l "job-name=${job}" \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true
  )"
  if [[ -z "$pod" ]]; then
    printf 'no Pod found for Job %s/%s\n' "$namespace" "$job" >&2
    return 1
  fi
  k logs "pod/${pod}" -n "$namespace" --tail="$tail_lines"
}

reconcile_redis_acl() {
  local job='p0-008b-b4-redis-provision'
  printf 'B4_REDIS_STAGE=admin_secret_preflight\n'
  k get secret "$REDIS_ADMIN_SECRET" -n "$REDIS_ADMIN_NAMESPACE" >/dev/null
  k get secret "$REDIS_SECRET" -n "$NAMESPACE" -o json \
    | jq --arg name "$REDIS_PROVISION_SECRET" --arg ns "$REDIS_ADMIN_NAMESPACE" '
        {
          apiVersion: "v1",
          kind: "Secret",
          metadata: {
            name: $name,
            namespace: $ns,
            labels: {"sunmoonai.com/task": "v5-p0-008b-b4"}
          },
          type: "Opaque",
          data: {
            REDIS_USER: .data.REDIS_USER,
            REDIS_PASSWORD: .data.REDIS_PASSWORD
          }
        }
    ' \
    | k apply -f - >/dev/null
  printf 'B4_REDIS_STAGE=provision_secret_ready\n'
  delete_job_and_wait "$REDIS_ADMIN_NAMESPACE" "$job"
  printf 'B4_REDIS_STAGE=old_job_removed\n'
  cat <<EOF | k create -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${REDIS_ADMIN_NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 120
  # The script deletes the Job after collecting its bounded evidence. A short
  # TTL can race a slow/local API client and erase success before the Job poll.
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-008b-b4
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
        - name: provision
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
            - name: B4_REDIS_USER
              valueFrom:
                secretKeyRef:
                  name: ${REDIS_PROVISION_SECRET}
                  key: REDIS_USER
            - name: B4_REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${REDIS_PROVISION_SECRET}
                  key: REDIS_PASSWORD
          command: ["/bin/bash", "-ec"]
          args:
            - |
              HOST='redis-sunmoonai-master.data-platform-dev.svc.cluster.local'
              REDISCLI_AUTH="\$REDIS_ADMIN_PASSWORD" redis-cli -e -h "\$HOST" --user default \
                ACL SETUSER "\$B4_REDIS_USER" reset on ">\$B4_REDIS_PASSWORD" \
                '~${REDIS_KEY_PATTERN}' resetchannels \
                -@all +@read +@write +@connection +@hash +@string +@list +@set +@sortedset \
                -@dangerous >/dev/null
              REDISCLI_AUTH="\$REDIS_ADMIN_PASSWORD" redis-cli -e -h "\$HOST" --user default \
                ACL SAVE >/dev/null
              TEST_KEY='sunmoonai:auth:info:web:tpl-b4:acl-preflight'
              REDISCLI_AUTH="\$B4_REDIS_PASSWORD" redis-cli -e -h "\$HOST" --user "\$B4_REDIS_USER" \
                SET "\$TEST_KEY" ok EX 30 >/dev/null
              test "\$(REDISCLI_AUTH="\$B4_REDIS_PASSWORD" redis-cli -e -h "\$HOST" \
                --user "\$B4_REDIS_USER" GET "\$TEST_KEY")" = ok
              REDISCLI_AUTH="\$B4_REDIS_PASSWORD" redis-cli -e -h "\$HOST" --user "\$B4_REDIS_USER" \
                DEL "\$TEST_KEY" >/dev/null
              if REDISCLI_AUTH="\$B4_REDIS_PASSWORD" redis-cli -e -h "\$HOST" --user "\$B4_REDIS_USER" \
                SET 'sunmoonai:auth:info:admin:forbidden' denied >/dev/null 2>&1; then
                printf 'B4 Redis ACL allowed an out-of-scope key\n' >&2
                exit 1
              fi
              printf 'B4 Redis least-privilege ACL passed\n'
EOF
  printf 'B4_REDIS_STAGE=job_created\n'
  if ! wait_for_job "$REDIS_ADMIN_NAMESPACE" "$job"; then
    job_logs "$REDIS_ADMIN_NAMESPACE" "$job" 80 >&2 || true
    return 1
  fi
  printf 'B4_REDIS_STAGE=job_complete\n'
  job_logs "$REDIS_ADMIN_NAMESPACE" "$job" 20
  delete_job_and_wait "$REDIS_ADMIN_NAMESPACE" "$job"
  k delete secret "$REDIS_PROVISION_SECRET" -n "$REDIS_ADMIN_NAMESPACE" \
    --ignore-not-found=true >/dev/null
}

delete_redis_acl() {
  local job='p0-008b-b4-redis-deprovision'
  k get secret "$REDIS_ADMIN_SECRET" -n "$REDIS_ADMIN_NAMESPACE" >/dev/null 2>&1 || return 0
  delete_job_and_wait "$REDIS_ADMIN_NAMESPACE" "$job"
  cat <<EOF | k create -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${REDIS_ADMIN_NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 120
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-008b-b4
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
        - name: deprovision
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
          command: ["/bin/bash", "-ec"]
          args:
            - |
              HOST='redis-sunmoonai-master.data-platform-dev.svc.cluster.local'
              REDISCLI_AUTH="\$REDIS_ADMIN_PASSWORD" redis-cli -e -h "\$HOST" --user default \
                ACL DELUSER '${REDIS_USER}' >/dev/null
              REDISCLI_AUTH="\$REDIS_ADMIN_PASSWORD" redis-cli -e -h "\$HOST" --user default \
                ACL SAVE >/dev/null
              printf 'B4 Redis ACL removed\n'
EOF
  if wait_for_job "$REDIS_ADMIN_NAMESPACE" "$job"; then
    job_logs "$REDIS_ADMIN_NAMESPACE" "$job" 20
  else
    job_logs "$REDIS_ADMIN_NAMESPACE" "$job" 80 >&2 || true
    return 1
  fi
  delete_job_and_wait "$REDIS_ADMIN_NAMESPACE" "$job"
}

cleanup() {
  k delete ingressroute tpl-web-b4 -n "$NAMESPACE" --ignore-not-found=true >/dev/null
  k delete pdb tpl-web-backend-b4 tpl-web-frontend-b4 -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  k delete service tpl-web-backend-b4 tpl-web-frontend-b4 -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  k delete deployment tpl-web-backend-b4 tpl-web-frontend-b4 -n "$NAMESPACE" \
    --ignore-not-found=true --wait=true >/dev/null
  k delete configmap tpl-web-b4-config -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  delete_redis_acl
  k delete secret "$REDIS_SECRET" -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  printf 'V5-P0-008B/B4 isolated runtime cleaned\n'
}

if [[ "$MODE" == 'cleanup' ]]; then
  validate_kubectl_compatibility
  cleanup
  exit 0
fi

printf 'PLAN namespace=%s host=%s:%s deployment=%s\n' \
  "$NAMESPACE" "$HOST" "$PUBLIC_PORT" "$DEPLOYMENT_ID"
printf 'PLAN resources=2xNest,2xNext,2xService,2xPDB,IngressRoute,isolated-Redis-Secret\n'
[[ "$MODE" == 'apply' ]] || exit 0
validate_kubectl_compatibility

[[ "$BACKEND_IMAGE" =~ @sha256:[a-f0-9]{64}$ ]] || {
  printf 'backend image must be an immutable digest reference\n' >&2
  exit 1
}
[[ "$FRONTEND_IMAGE" =~ @sha256:[a-f0-9]{64}$ ]] || {
  printf 'frontend image must be an immutable digest reference\n' >&2
  exit 1
}
[[ "$DEPLOYMENT_ID" =~ ^[a-z0-9][a-z0-9.-]{1,63}$ ]] || {
  printf 'deployment ID is invalid\n' >&2
  exit 1
}
[[ "$HOST" == 'tpl-web-b4.sunmoonai.com' ]] || {
  printf 'B4 host is outside the isolated trust boundary\n' >&2
  exit 1
}

k get secret "$IDENTITY_SECRET" -n "$NAMESPACE" >/dev/null
REDIS_JSON="$(k get secret "$REDIS_SOURCE_SECRET" -n "$NAMESPACE" -o json)"
CURRENT_REDIS_USER="$(
  k get secret "$REDIS_SECRET" -n "$NAMESPACE" \
    -o jsonpath='{.data.REDIS_USER}' 2>/dev/null \
    | base64 --decode 2>/dev/null || true
)"
if [[ "$CURRENT_REDIS_USER" != "$REDIS_USER" ]]; then
  REDIS_PASSWORD="$(openssl rand -hex 32)"
  REDIS_PASSWORD_B64="$(printf '%s' "$REDIS_PASSWORD" | base64 -w0)"
else
  REDIS_PASSWORD_B64="$(
    k get secret "$REDIS_SECRET" -n "$NAMESPACE" -o jsonpath='{.data.REDIS_PASSWORD}'
  )"
fi
printf '%s' "$REDIS_JSON" \
  | jq --arg name "$REDIS_SECRET" --arg ns "$NAMESPACE" \
      --arg user "$(printf '%s' "$REDIS_USER" | base64 -w0)" \
      --arg password "$REDIS_PASSWORD_B64" '
      {
        apiVersion: "v1",
        kind: "Secret",
        metadata: {
          name: $name,
          namespace: $ns,
          labels: {
            "sunmoonai.com/task": "v5-p0-008b-b4",
            "app.kubernetes.io/component": "verification-redis"
          }
        },
        type: "Opaque",
        data: {
          REDIS_HOST: .data.REDIS_HOST,
          REDIS_PORT: .data.REDIS_PORT,
          REDIS_DB: .data.REDIS_DB,
          REDIS_USER: $user,
          REDIS_PASSWORD: $password
        }
      }
    ' \
  | k apply -f - >/dev/null
unset REDIS_JSON
unset REDIS_PASSWORD REDIS_PASSWORD_B64 CURRENT_REDIS_USER
reconcile_redis_acl
REDIS_REVISION="$(
  k get secret "$REDIS_SECRET" -n "$NAMESPACE" -o json \
    | jq -c '.data | to_entries | sort_by(.key)' \
    | sha256sum \
    | awk '{print $1}'
)"

ORIGIN="https://${HOST}:${PUBLIC_PORT}"

cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: tpl-web-b4-config
  namespace: ${NAMESPACE}
  labels: &labels
    sunmoonai.com/task: v5-p0-008b-b4
data:
  NODE_TLS_REJECT_UNAUTHORIZED: "1"
  APP_ORIGIN: "${ORIGIN}"
  FRONTEND_URL: "${ORIGIN}"
  CASDOOR_ENDPOINT: "https://casdoor.sunmoonai.com:${PUBLIC_PORT}"
  CASDOOR_ISSUER: "https://casdoor.sunmoonai.com:${PUBLIC_PORT}"
  CASDOOR_DISCOVERY_URL: "https://casdoor.sunmoonai.com:${PUBLIC_PORT}/.well-known/openid-configuration"
  CASDOOR_BACKCHANNEL_ENDPOINT: "http://casdoor-sunmoonai:8000"
  CASDOOR_REDIRECT_URI: "${ORIGIN}/api/auth/callback"
  CASDOOR_ORGANIZATION: "sunmoonai"
  CASDOOR_APPLICATION: "sunmoonai-tpl-web-b4"
  AUTH_APP: "info"
  AUTH_INSTANCE: "tpl-b4"
  AUTH_POLICY_VERSION: "tpl-web-b4-v1"
  AUTH_SESSION_COOKIE_NAME: "sunmoonai_info_web_sid"
  AUTH_TRANSACTION_COOKIE_NAME: "sunmoonai_info_web_oidc_tx"
  AUTH_SESSION_KEY_PREFIX: "sunmoonai:auth:info:web:tpl-b4:session:"
  AUTH_TRANSACTION_KEY_PREFIX: "sunmoonai:auth:info:web:tpl-b4:oidc:"
  AUTH_ALLOWED_ORIGINS: "${ORIGIN}"
  AUTH_ALLOWED_RETURN_PATHS: "/zh-CN/dashboard,/en/dashboard"
  AUTH_DEFAULT_RETURN_TO: "/zh-CN/dashboard"
  AUTH_ALLOWED_ALGORITHMS: "RS256,ES256"
  SESSION_COOKIE_SECURE: "true"
  FRONTEND_DEFAULT_LOCALE: "zh-CN"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tpl-web-backend-b4
  namespace: ${NAMESPACE}
  labels:
    app: tpl-web-backend-b4
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  replicas: 2
  revisionHistoryLimit: 5
  minReadySeconds: 5
  progressDeadlineSeconds: 300
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: tpl-web-backend-b4
  template:
    metadata:
      labels:
        app: tpl-web-backend-b4
        sunmoonai.com/task: v5-p0-008b-b4
      annotations:
        sunmoonai.com/deployment-id: "${DEPLOYMENT_ID}"
        sunmoonai.com/redis-credential-revision: "${REDIS_REVISION}"
    spec:
      terminationGracePeriodSeconds: 30
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        fsGroupChangePolicy: OnRootMismatch
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app: tpl-web-backend-b4
      containers:
        - name: backend
          image: ${BACKEND_IMAGE}
          imagePullPolicy: IfNotPresent
          command: ["node", "dist/b4-verification-main.js"]
          ports:
            - name: http
              containerPort: 8000
          envFrom:
            - configMapRef:
                name: tpl-web-b4-config
            - secretRef:
                name: ${REDIS_SECRET}
          env:
            - name: NODE_ENV
              value: production
            - name: PORT
              value: "8000"
            - name: PREFIX
              value: /api
            - name: CORS
              value: "false"
            - name: APP_NAME
              value: tpl-web-backend-b4
            - name: APP_SURFACE
              value: web
            - name: DEPLOYMENT_ID
              value: "${DEPLOYMENT_ID}"
            - name: CONTRACT_VERSION
              value: "1"
            - name: B4_VERIFICATION_MODE
              value: "true"
            - name: CASDOOR_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: ${IDENTITY_SECRET}
                  key: B4_CLIENT_ID
            - name: CASDOOR_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: ${IDENTITY_SECRET}
                  key: B4_CLIENT_SECRET
          readinessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 3
            periodSeconds: 3
            failureThreshold: 20
          livenessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 10"]
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
---
apiVersion: v1
kind: Service
metadata:
  name: tpl-web-backend-b4
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  selector:
    app: tpl-web-backend-b4
  ports:
    - name: http
      port: 8000
      targetPort: http
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: tpl-web-backend-b4
  namespace: ${NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: tpl-web-backend-b4
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tpl-web-frontend-b4
  namespace: ${NAMESPACE}
  labels:
    app: tpl-web-frontend-b4
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  replicas: 2
  revisionHistoryLimit: 5
  minReadySeconds: 5
  progressDeadlineSeconds: 300
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: tpl-web-frontend-b4
  template:
    metadata:
      labels:
        app: tpl-web-frontend-b4
        sunmoonai.com/task: v5-p0-008b-b4
      annotations:
        sunmoonai.com/deployment-id: "${DEPLOYMENT_ID}"
    spec:
      terminationGracePeriodSeconds: 30
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        fsGroup: 1001
        fsGroupChangePolicy: OnRootMismatch
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app: tpl-web-frontend-b4
      containers:
        - name: frontend
          image: ${FRONTEND_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 3000
          env:
            - name: NODE_ENV
              value: production
            - name: DEPLOYMENT_ENV
              value: production
            - name: AUTH_APP
              value: info
            - name: APP_ORIGIN
              value: "${ORIGIN}"
            - name: WEB_BACKEND_INTERNAL_URL
              value: http://tpl-web-backend-b4:8000
            - name: DEPLOYMENT_ID
              value: "${DEPLOYMENT_ID}"
            - name: REFERENCE_UI_ENABLED
              value: "true"
          readinessProbe:
            httpGet:
              path: /zh-CN
              port: http
            initialDelaySeconds: 3
            periodSeconds: 3
            failureThreshold: 20
          livenessProbe:
            httpGet:
              path: /zh-CN
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 10"]
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: next-cache
              mountPath: /app/.next/cache
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: next-cache
          emptyDir: {}
        - name: tmp
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: tpl-web-frontend-b4
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  selector:
    app: tpl-web-frontend-b4
  ports:
    - name: http
      port: 3000
      targetPort: http
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: tpl-web-frontend-b4
  namespace: ${NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: tpl-web-frontend-b4
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: tpl-web-b4
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(\`${HOST}\`) && PathPrefix(\`/api\`)
      priority: 200
      services:
        - name: tpl-web-backend-b4
          port: 8000
    - kind: Rule
      match: Host(\`${HOST}\`) && PathPrefix(\`/\`)
      priority: 100
      services:
        - name: tpl-web-frontend-b4
          port: 3000
  tls: {}
EOF

k rollout status deployment/tpl-web-backend-b4 -n "$NAMESPACE" --timeout=240s
k rollout status deployment/tpl-web-frontend-b4 -n "$NAMESPACE" --timeout=240s

# Readiness proves that HTTP is alive; this bounded preflight additionally
# proves the session store credential and ACL before the deployment can pass.
k exec deployment/tpl-web-backend-b4 -n "$NAMESPACE" -- node -e '
  const Redis = require("ioredis");
  const client = new Redis({
    host: process.env.REDIS_HOST,
    port: Number(process.env.REDIS_PORT),
    db: Number(process.env.REDIS_DB),
    username: process.env.REDIS_USER || undefined,
    password: process.env.REDIS_PASSWORD,
    lazyConnect: true,
    enableReadyCheck: false,
    connectTimeout: 5000,
    commandTimeout: 5000,
    maxRetriesPerRequest: 0,
  });
  (async () => {
    try {
      await client.connect();
      if ((await client.ping()) !== "PONG") throw new Error("unexpected Redis PING response");
      process.stdout.write("B4 Redis preflight passed\n");
    } finally {
      client.disconnect();
    }
  })().catch(() => {
    process.stderr.write("B4 Redis preflight failed\n");
    process.exit(1);
  });
'

READY_BACKEND="$(k get deployment tpl-web-backend-b4 -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')"
READY_FRONTEND="$(k get deployment tpl-web-frontend-b4 -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')"
[[ "$READY_BACKEND" == 2 && "$READY_FRONTEND" == 2 ]] || {
  printf 'B4 pair did not reach 2+2 ready replicas\n' >&2
  exit 1
}
printf 'V5-P0-008B/B4 isolated deployment passed ready=2+2 deployment=%s\n' "$DEPLOYMENT_ID"
