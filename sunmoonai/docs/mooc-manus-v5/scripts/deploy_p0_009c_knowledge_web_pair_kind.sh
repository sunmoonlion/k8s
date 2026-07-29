#!/usr/bin/env bash

# Deploy an isolated Next Web + canonical FastAPI Web pair.
# The script never mutates Info/Knowledge/Research Deployments.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="app-platform-dev"
HOST="knowledge-web-p0-009c.sunmoonai.com"
PUBLIC_PORT="30443"
BACKEND_IMAGE=""
FRONTEND_IMAGE=""
DEPLOYMENT_ID="p0-009c-v1"
IDENTITY_SECRET="sunmoonai-p0-009c-web-identity"
RUNTIME_SECRET="sunmoonai-p0-009c-web-runtime"
MODE="plan"
POSTGRES_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
REDIS_IMAGE="harbor.sunmoonai.com:30443/k8s-images/redis:8.2.1-debian-12-r0"

usage() {
  cat <<'EOF'
Usage: deploy_p0_009c_knowledge_web_pair_kind.sh [--apply|--cleanup] [options]
  --backend-image IMAGE@sha256:DIGEST
  --frontend-image IMAGE@sha256:DIGEST
  --deployment-id ID
  --kubeconfig PATH
  --namespace NAME
  --host HOST
  --public-port PORT
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --cleanup) MODE="cleanup"; shift ;;
    --backend-image) BACKEND_IMAGE="$2"; shift 2 ;;
    --frontend-image) FRONTEND_IMAGE="$2"; shift 2 ;;
    --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --public-port) PUBLIC_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

cleanup() {
  k delete ingressroute knowledge-web-p0-009c -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  k delete pdb knowledge-web-backend-p0-009c knowledge-web-frontend-p0-009c \
    -n "$NAMESPACE" --ignore-not-found=true >/dev/null
  k delete service knowledge-web-backend-p0-009c knowledge-web-frontend-p0-009c \
    p0-009c-web-postgresql p0-009c-web-redis -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  k delete deployment knowledge-web-backend-p0-009c knowledge-web-frontend-p0-009c \
    p0-009c-web-postgresql p0-009c-web-redis -n "$NAMESPACE" \
    --ignore-not-found=true --wait=true >/dev/null
  k delete job p0-009c-web-migration -n "$NAMESPACE" \
    --ignore-not-found=true --wait=true >/dev/null
  k delete configmap knowledge-web-p0-009c-config -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  k delete secret "$RUNTIME_SECRET" -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  for _attempt in $(seq 1 60); do
    if ! k get pod -n "$NAMESPACE" -o name | grep -Eq '(knowledge-web.*p0-009c|p0-009c-web)'; then
      printf 'V5-P0-009C isolated runtime cleaned\n'
      return 0
    fi
    sleep 2
  done
  printf 'P0-009C terminating Pods remain after cleanup timeout\n' >&2
  k get pod -n "$NAMESPACE" -o name | grep -E '(knowledge-web.*p0-009c|p0-009c-web)' >&2 || true
  return 1
}

if [[ "$MODE" == "cleanup" ]]; then
  cleanup
  exit 0
fi

printf 'PLAN namespace=%s host=%s:%s deployment=%s\n' \
  "$NAMESPACE" "$HOST" "$PUBLIC_PORT" "$DEPLOYMENT_ID"
printf 'PLAN resources=PostgreSQL,Redis,migration,2xFastAPI,2xNext Web,Services,PDBs,IngressRoute\n'
[[ "$MODE" == "apply" ]] || exit 0

[[ "$BACKEND_IMAGE" =~ @sha256:[a-f0-9]{64}$ ]] || {
  printf 'backend image must be an immutable digest reference\n' >&2
  exit 1
}
[[ "$FRONTEND_IMAGE" =~ @sha256:[a-f0-9]{64}$ ]] || {
  printf 'frontend image must be an immutable digest reference\n' >&2
  exit 1
}
[[ "$HOST" == "knowledge-web-p0-009c.sunmoonai.com" ]] || {
  printf 'host is outside the P0-009C trust boundary\n' >&2
  exit 1
}
k get secret "$IDENTITY_SECRET" -n "$NAMESPACE" >/dev/null
k get secret harbor-registry-secret -n "$NAMESPACE" >/dev/null

if ! k get secret "$RUNTIME_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  postgres_password="$(openssl rand -hex 24)"
  redis_password="$(openssl rand -hex 24)"
  k create secret generic "$RUNTIME_SECRET" -n "$NAMESPACE" \
    --from-literal=POSTGRES_PASSWORD="$postgres_password" \
    --from-literal=REDIS_PASSWORD="$redis_password" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  unset postgres_password redis_password
fi
k label secret "$RUNTIME_SECRET" -n "$NAMESPACE" \
  sunmoonai.com/task=v5-p0-009c-web --overwrite >/dev/null

origin="https://${HOST}:${PUBLIC_PORT}"
cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: knowledge-web-p0-009c-config
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-009c-web
data:
  # The deterministic interaction adapter is available only in this isolated
  # verification profile. Strict TLS and real Casdoor remain mandatory.
  ENV: test
  LOG_LEVEL: INFO
  SERVICE_NAME: knowledge-web-backend-p0-009c
  APP_SLUG: knowledge
  SURFACE: web
  REDIS_HOST: p0-009c-web-redis
  REDIS_PORT: "6379"
  REDIS_DB: "0"
  CASDOOR_ENDPOINT: "https://casdoor.sunmoonai.com:${PUBLIC_PORT}"
  CASDOOR_DISCOVERY_URL: "https://casdoor.sunmoonai.com:${PUBLIC_PORT}/.well-known/openid-configuration"
  CASDOOR_BACKCHANNEL_ENDPOINT: "http://casdoor-sunmoonai:8000"
  CASDOOR_REDIRECT_URI: "${origin}/api/auth/callback"
  CASDOOR_ORGANIZATION: sunmoonai
  CASDOOR_APPLICATION: sunmoonai-knowledge-web-p0-009c
  CASDOOR_VERIFY_SSL: "true"
  AUTH_POLICY_VERSION: knowledge-web-p0-009c-v1
  AUTH_ROLE_ALLOWLIST: admin,operator
  AUTH_SCOPE_ALLOWLIST: profile:read
  AUTH_DEFAULT_RETURN_TO: /zh-CN/dashboard
  AUTH_ALLOWED_RETURN_PATHS: /zh-CN/dashboard,/en/dashboard,/zh-CN/login,/en/login
  FRONTEND_DEFAULT_LOCALE: zh-CN
  REFERENCE_INTERACTION_ENABLED: "true"
  FRONTEND_BASE_URL: "${origin}"
  FRONTEND_ALLOWED_ORIGINS: "${origin}"
  ALLOWED_HOSTS: "${HOST},knowledge-web-backend-p0-009c"
  SESSION_COOKIE_SECURE: "true"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: p0-009c-web-postgresql
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-009c-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: p0-009c-web-postgresql
  template:
    metadata:
      labels:
        app: p0-009c-web-postgresql
        sunmoonai.com/task: v5-p0-009c-web
    spec:
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: postgresql
          image: ${POSTGRES_IMAGE}
          ports:
            - name: postgres
              containerPort: 5432
          env:
            - name: POSTGRESQL_DATABASE
              value: tpl
            - name: POSTGRESQL_USERNAME
              value: tpl
            - name: POSTGRESQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${RUNTIME_SECRET}
                  key: POSTGRES_PASSWORD
          readinessProbe:
            exec:
              command: ["/bin/bash", "-ec", "PGPASSWORD=\$POSTGRESQL_PASSWORD pg_isready -U tpl -d tpl"]
            initialDelaySeconds: 3
            periodSeconds: 3
          resources:
            requests: {cpu: 50m, memory: 128Mi}
            limits: {cpu: 500m, memory: 512Mi}
---
apiVersion: v1
kind: Service
metadata:
  name: p0-009c-web-postgresql
  namespace: ${NAMESPACE}
spec:
  selector:
    app: p0-009c-web-postgresql
  ports:
    - name: postgres
      port: 5432
      targetPort: postgres
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: p0-009c-web-redis
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-009c-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: p0-009c-web-redis
  template:
    metadata:
      labels:
        app: p0-009c-web-redis
        sunmoonai.com/task: v5-p0-009c-web
    spec:
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: redis
          image: ${REDIS_IMAGE}
          ports:
            - name: redis
              containerPort: 6379
          env:
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${RUNTIME_SECRET}
                  key: REDIS_PASSWORD
          readinessProbe:
            exec:
              command: ["/bin/bash", "-ec", "REDISCLI_AUTH=\$REDIS_PASSWORD redis-cli -h 127.0.0.1 ping | grep -qx PONG"]
            initialDelaySeconds: 3
            periodSeconds: 3
          resources:
            requests: {cpu: 25m, memory: 64Mi}
            limits: {cpu: 250m, memory: 256Mi}
---
apiVersion: v1
kind: Service
metadata:
  name: p0-009c-web-redis
  namespace: ${NAMESPACE}
spec:
  selector:
    app: p0-009c-web-redis
  ports:
    - name: redis
      port: 6379
      targetPort: redis
EOF

k rollout status deployment/p0-009c-web-postgresql -n "$NAMESPACE" --timeout=180s
k rollout status deployment/p0-009c-web-redis -n "$NAMESPACE" --timeout=180s

k delete job p0-009c-web-migration -n "$NAMESPACE" \
  --ignore-not-found=true --wait=true >/dev/null
cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: p0-009c-web-migration
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-009c-web
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-009c-web
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
        - name: migrate
          image: ${BACKEND_IMAGE}
          command: ["/bin/sh", "-ec"]
          args:
            - |
              for attempt in \$(seq 1 30); do
                .venv/bin/python -c "import socket; socket.create_connection(('p0-009c-web-postgresql', 5432), 2).close()" && break
                [ "\$attempt" -eq 30 ] && exit 1
                sleep 2
              done
              exec .venv/bin/alembic upgrade head
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${RUNTIME_SECRET}
                  key: POSTGRES_PASSWORD
            - name: DATABASE_URL
              value: postgresql+asyncpg://tpl:\$(POSTGRES_PASSWORD)@p0-009c-web-postgresql:5432/tpl
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
EOF
k wait --for=condition=complete job/p0-009c-web-migration \
  -n "$NAMESPACE" --timeout=180s
k logs job/p0-009c-web-migration -n "$NAMESPACE" --tail=20

cat <<EOF | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: knowledge-web-backend-p0-009c
  namespace: ${NAMESPACE}
  labels:
    app: knowledge-web-backend-p0-009c
    sunmoonai.com/task: v5-p0-009c-web
spec:
  replicas: 2
  revisionHistoryLimit: 3
  minReadySeconds: 5
  strategy:
    type: RollingUpdate
    rollingUpdate: {maxUnavailable: 0, maxSurge: 1}
  selector:
    matchLabels:
      app: knowledge-web-backend-p0-009c
  template:
    metadata:
      labels:
        app: knowledge-web-backend-p0-009c
        sunmoonai.com/task: v5-p0-009c-web
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
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: backend
          image: ${BACKEND_IMAGE}
          ports:
            - name: http
              containerPort: 8000
          envFrom:
            - configMapRef:
                name: knowledge-web-p0-009c-config
          env:
            - name: DEPLOYMENT_ID
              value: "${DEPLOYMENT_ID}"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${RUNTIME_SECRET}
                  key: POSTGRES_PASSWORD
            - name: DATABASE_URL
              value: postgresql+asyncpg://tpl:\$(POSTGRES_PASSWORD)@p0-009c-web-postgresql:5432/tpl
            - name: REDIS_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${RUNTIME_SECRET}
                  key: REDIS_PASSWORD
            - name: CASDOOR_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: ${IDENTITY_SECRET}
                  key: CLIENT_ID
            - name: CASDOOR_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: ${IDENTITY_SECRET}
                  key: CLIENT_SECRET
          readinessProbe:
            httpGet:
              path: /ready
              port: http
              httpHeaders:
                - name: Host
                  value: "${HOST}"
            initialDelaySeconds: 3
            periodSeconds: 3
            failureThreshold: 30
          livenessProbe:
            httpGet:
              path: /health
              port: http
              httpHeaders:
                - name: Host
                  value: "${HOST}"
            initialDelaySeconds: 10
            periodSeconds: 10
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 10"]
          resources:
            requests: {cpu: 50m, memory: 128Mi}
            limits: {cpu: 500m, memory: 512Mi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1001
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: knowledge-web-backend-p0-009c
  namespace: ${NAMESPACE}
spec:
  selector:
    app: knowledge-web-backend-p0-009c
  ports:
    - name: http
      port: 8000
      targetPort: http
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: knowledge-web-backend-p0-009c
  namespace: ${NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: knowledge-web-backend-p0-009c
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: knowledge-web-frontend-p0-009c
  namespace: ${NAMESPACE}
  labels:
    app: knowledge-web-frontend-p0-009c
    sunmoonai.com/task: v5-p0-009c-web
spec:
  replicas: 2
  revisionHistoryLimit: 3
  minReadySeconds: 5
  strategy:
    type: RollingUpdate
    rollingUpdate: {maxUnavailable: 0, maxSurge: 1}
  selector:
    matchLabels:
      app: knowledge-web-frontend-p0-009c
  template:
    metadata:
      labels:
        app: knowledge-web-frontend-p0-009c
        sunmoonai.com/task: v5-p0-009c-web
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
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: frontend
          image: ${FRONTEND_IMAGE}
          ports:
            - name: http
              containerPort: 3000
          env:
            - name: DEPLOYMENT_ENV
              value: production
            - name: AUTH_APP
              value: knowledge
            - name: APP_ORIGIN
              value: "${origin}"
            - name: WEB_BACKEND_INTERNAL_URL
              value: http://knowledge-web-backend-p0-009c:8000
            - name: DEPLOYMENT_ID
              value: "${DEPLOYMENT_ID}"
            # Isolated P0-009C only: enable the deterministic reference workspace UI.
            - name: REFERENCE_UI_ENABLED
              value: "true"
          readinessProbe:
            httpGet: {path: /zh-CN, port: http}
            initialDelaySeconds: 3
            periodSeconds: 3
          livenessProbe:
            httpGet: {path: /zh-CN, port: http}
            initialDelaySeconds: 10
            periodSeconds: 10
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh", "-c", "sleep 10"]
          resources:
            requests: {cpu: 50m, memory: 128Mi}
            limits: {cpu: 500m, memory: 512Mi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1001
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: knowledge-web-frontend-p0-009c
  namespace: ${NAMESPACE}
spec:
  selector:
    app: knowledge-web-frontend-p0-009c
  ports:
    - name: http
      port: 3000
      targetPort: http
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: knowledge-web-frontend-p0-009c
  namespace: ${NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: knowledge-web-frontend-p0-009c
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: knowledge-web-p0-009c
  namespace: ${NAMESPACE}
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`${HOST}\`) && PathPrefix(\`/api\`)
      kind: Rule
      priority: 100
      services:
        - name: knowledge-web-backend-p0-009c
          port: 8000
    - match: Host(\`${HOST}\`) && PathPrefix(\`/\`)
      kind: Rule
      priority: 10
      services:
        - name: knowledge-web-frontend-p0-009c
          port: 3000
  tls: {}
EOF

k rollout status deployment/knowledge-web-backend-p0-009c \
  -n "$NAMESPACE" --timeout=240s
k rollout status deployment/knowledge-web-frontend-p0-009c \
  -n "$NAMESPACE" --timeout=240s

backend_ready="$(k get deployment knowledge-web-backend-p0-009c -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
frontend_ready="$(k get deployment knowledge-web-frontend-p0-009c -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
[[ "$backend_ready" == 2 && "$frontend_ready" == 2 ]] || {
  printf 'P0-009C pair is not ready at 2+2\n' >&2
  exit 1
}
printf 'V5-P0-009C isolated pair deployed backend=%s frontend=%s\n' \
  "$backend_ready" "$frontend_ready"
