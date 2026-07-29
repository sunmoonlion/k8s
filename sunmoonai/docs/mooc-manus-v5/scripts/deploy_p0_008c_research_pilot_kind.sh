#!/usr/bin/env bash

# Deploy the isolated P0-008C vertical:
# Next -> FastAPI Web BFF -> Research Runtime API/worker -> Knowledge/LLM.
# Stable Research resources are never patched by this script.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="app-platform-dev"
HOST="research-web-p0-008c.sunmoonai.com"
PUBLIC_PORT="30443"
DEPLOYMENT_ID="p0-008c-v1"
MODE="plan"

RUNTIME_IMAGE=""
WEB_BFF_IMAGE=""
NEXT_IMAGE=""

TASK_LABEL="v5-p0-008c"
RUNTIME_SECRET="sunmoonai-p0-008c-runtime"
LLM_SECRET="sunmoonai-p0-008c-llm"
BROWSER_SECRET="sunmoonai-p0-008c-web-identity"
SERVICE_CALLER_SECRET="sunmoonai-p0-008c-runtime-caller"
SERVICE_BINDING_SECRET="sunmoonai-p0-008c-runtime-binding"
RETRIEVAL_SECRET="research-knowledge-retrieval-client"
ADMIN_BROKER_SECRET="research-admin-backend-secret"
WORKER_BROKER_SECRET="celeryworker-research-admin-backend-secret"
POSTGRES_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
REDIS_IMAGE="harbor.sunmoonai.com:30443/k8s-images/redis:8.2.1-debian-12-r0"

usage() {
  cat <<'EOF'
Usage: deploy_p0_008c_research_pilot_kind.sh [--apply|--cleanup] [options]

  --runtime-image IMAGE@sha256:DIGEST
  --web-bff-image IMAGE@sha256:DIGEST
  --next-image IMAGE@sha256:DIGEST
  --deployment-id ID
  --kubeconfig PATH
  --namespace NAME

Before --apply, provision:
  sunmoonai-p0-008c-llm with keys
    AGENT_PILOT_LLM_BASE_URL
    AGENT_PILOT_LLM_API_KEY
    AGENT_PILOT_LLM_MODEL
  and run provision_p0_008c_identities.sh --apply.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --cleanup) MODE="cleanup"; shift ;;
    --runtime-image) RUNTIME_IMAGE="$2"; shift 2 ;;
    --web-bff-image) WEB_BFF_IMAGE="$2"; shift 2 ;;
    --next-image) NEXT_IMAGE="$2"; shift 2 ;;
    --deployment-id) DEPLOYMENT_ID="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

cleanup() {
  k delete ingressroute research-web-p0-008c -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  k delete pdb research-web-backend-p0-008c research-web-frontend-p0-008c \
    research-runtime-p0-008c -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  k delete service research-web-backend-p0-008c research-web-frontend-p0-008c \
    research-runtime-p0-008c p0-008c-web-postgresql \
    p0-008c-runtime-postgresql p0-008c-web-redis p0-008c-runtime-redis \
    -n "$NAMESPACE" --ignore-not-found=true >/dev/null
  k delete deployment research-web-backend-p0-008c research-web-frontend-p0-008c \
    research-runtime-p0-008c research-runtime-worker-p0-008c \
    p0-008c-web-postgresql p0-008c-runtime-postgresql \
    p0-008c-web-redis p0-008c-runtime-redis \
    -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  k delete job p0-008c-web-migration p0-008c-runtime-migration \
    -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  k delete configmap research-web-p0-008c-config research-runtime-p0-008c-config \
    -n "$NAMESPACE" --ignore-not-found=true >/dev/null
  k delete secret "$RUNTIME_SECRET" -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  for _attempt in $(seq 1 60); do
    if ! k get pod -n "$NAMESPACE" -o name \
      | grep -Eq '(p0-008c|research-runtime.*008c|research-web.*008c)'; then
      printf 'V5-P0-008C isolated deployments cleaned; identities and LLM Secret retained\n'
      return 0
    fi
    sleep 2
  done
  printf 'P0-008C terminating Pods remain after cleanup timeout\n' >&2
  return 1
}

if [[ "$MODE" == "cleanup" ]]; then
  cleanup
  exit 0
fi

printf 'PLAN namespace=%s host=%s:%s deployment=%s\n' \
  "$NAMESPACE" "$HOST" "$PUBLIC_PORT" "$DEPLOYMENT_ID"
printf 'PLAN resources=2PostgreSQL,2Redis,2migrations,2xRuntimeAPI,1xRuntimeWorker,2xWebBFF,2xNext\n'
[[ "$MODE" == "apply" ]] || exit 0

for image in "$RUNTIME_IMAGE" "$WEB_BFF_IMAGE" "$NEXT_IMAGE"; do
  [[ "$image" =~ @sha256:[a-f0-9]{64}$ ]] || {
    printf 'all candidate images must be immutable digest references\n' >&2
    exit 1
  }
done
[[ "$HOST" == "research-web-p0-008c.sunmoonai.com" ]] || {
  printf 'host is outside the P0-008C trust boundary\n' >&2
  exit 1
}
[[ -n "$DEPLOYMENT_ID" && "$DEPLOYMENT_ID" != *$'\n'* ]] || {
  printf 'deployment ID is invalid\n' >&2
  exit 1
}

for secret in harbor-registry-secret "$LLM_SECRET" "$BROWSER_SECRET" \
  "$SERVICE_CALLER_SECRET" "$SERVICE_BINDING_SECRET" "$RETRIEVAL_SECRET" \
  "$ADMIN_BROKER_SECRET" "$WORKER_BROKER_SECRET"; do
  k get secret "$secret" -n "$NAMESPACE" >/dev/null || {
    printf 'required Secret is missing: %s/%s\n' "$NAMESPACE" "$secret" >&2
    exit 1
  }
done
for key in AGENT_PILOT_LLM_BASE_URL AGENT_PILOT_LLM_API_KEY \
  AGENT_PILOT_LLM_MODEL; do
  [[ -n "$(k get secret "$LLM_SECRET" -n "$NAMESPACE" \
    -o "jsonpath={.data.${key}}")" ]] || {
    printf 'required LLM Secret key is missing: %s\n' "$key" >&2
    exit 1
  }
done

if ! k get secret "$RUNTIME_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  web_postgres_password="$(openssl rand -hex 24)"
  runtime_postgres_password="$(openssl rand -hex 24)"
  web_redis_password="$(openssl rand -hex 24)"
  runtime_redis_password="$(openssl rand -hex 24)"
  k create secret generic "$RUNTIME_SECRET" -n "$NAMESPACE" \
    --from-literal=WEB_POSTGRES_PASSWORD="$web_postgres_password" \
    --from-literal=RUNTIME_POSTGRES_PASSWORD="$runtime_postgres_password" \
    --from-literal=WEB_REDIS_PASSWORD="$web_redis_password" \
    --from-literal=RUNTIME_REDIS_PASSWORD="$runtime_redis_password" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  unset web_postgres_password runtime_postgres_password
  unset web_redis_password runtime_redis_password
fi
k label secret "$RUNTIME_SECRET" -n "$NAMESPACE" \
  sunmoonai.com/task="$TASK_LABEL" --overwrite >/dev/null

origin="https://${HOST}:${PUBLIC_PORT}"
cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: research-web-p0-008c-config
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: ${TASK_LABEL}}
data:
  ENV: production
  LOG_LEVEL: INFO
  SERVICE_NAME: research-web-backend-p0-008c
  APP_SLUG: research
  SURFACE: web
  REDIS_HOST: p0-008c-web-redis
  REDIS_PORT: "6379"
  REDIS_DB: "0"
  CASDOOR_ENDPOINT: "https://casdoor.sunmoonai.com:${PUBLIC_PORT}"
  CASDOOR_DISCOVERY_URL: "https://casdoor.sunmoonai.com:${PUBLIC_PORT}/.well-known/openid-configuration"
  CASDOOR_BACKCHANNEL_ENDPOINT: "http://casdoor-sunmoonai:8000"
  CASDOOR_REDIRECT_URI: "${origin}/api/auth/callback"
  CASDOOR_ORGANIZATION: sunmoonai
  CASDOOR_APPLICATION: sunmoonai-research-web-p0-008c
  CASDOOR_VERIFY_SSL: "true"
  AUTH_POLICY_VERSION: research-web-p0-008c-v1
  AUTH_ROLE_ALLOWLIST: admin,operator
  AUTH_SCOPE_ALLOWLIST: profile:read
  AUTH_DEFAULT_RETURN_TO: /zh-CN/dashboard
  AUTH_ALLOWED_RETURN_PATHS: /zh-CN/dashboard,/en/dashboard,/zh-CN/login,/en/login
  FRONTEND_DEFAULT_LOCALE: zh-CN
  REFERENCE_INTERACTION_ENABLED: "false"
  RUNTIME_INTERACTION_ENABLED: "true"
  DOWNSTREAM_BASE_URL: "http://research-runtime-p0-008c:8000"
  DOWNSTREAM_SCOPE: research:runtime
  DOWNSTREAM_ALLOWED_PATH_PREFIXES: /internal/v1/research
  DOWNSTREAM_VERIFY_SSL: "true"
  FRONTEND_BASE_URL: "${origin}"
  FRONTEND_ALLOWED_ORIGINS: "${origin}"
  ALLOWED_HOSTS: "${HOST},research-web-backend-p0-008c"
  SESSION_COOKIE_SECURE: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: research-runtime-p0-008c-config
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: ${TASK_LABEL}}
data:
  ENV: production
  LOG_LEVEL: INFO
  SERVICE_NAME: research-runtime-p0-008c
  APP_SLUG: research
  SURFACE: admin
  REDIS_HOST: p0-008c-runtime-redis
  REDIS_PORT: "6379"
  REDIS_DB: "0"
  FRONTEND_BASE_URL: "https://research-admin.sunmoonai.com:${PUBLIC_PORT}"
  FRONTEND_ALLOWED_ORIGINS: "https://research-admin.sunmoonai.com:${PUBLIC_PORT}"
  ALLOWED_HOSTS: "research-runtime-p0-008c,research-admin.sunmoonai.com"
  SESSION_COOKIE_SECURE: "true"
  CELERY_QUEUE: research.p0-008c
  CELERY_TASK_DEFAULT_QUEUE: research.p0-008c
  AGENT_PILOT_ENABLED: "true"
  BROWSER_IDENTITY_ENABLED: "false"
  AGENT_PILOT_DATASET_KEYS: codex-smoke
  AGENT_REDIS_KEY_PREFIX: research:p0-008c:agent
  KNOWLEDGE_RETRIEVAL_URL: "http://knowledge-admin-backend:8000/api/internal/v1/knowledge/retrievals"
  KNOWLEDGE_RETRIEVAL_SERVICE_APPLICATION: sunmoonai-research-knowledge-retrieve
  KNOWLEDGE_RETRIEVAL_SERVICE_SCOPE: knowledge:retrieve
  KNOWLEDGE_RETRIEVAL_TIMEOUT_SECONDS: "20"
EOF

apply_stateful_dependency() {
  local name="$1" kind="$2" password_key="$3"
  if [[ "$kind" == "postgres" ]]; then
    cat <<EOF | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: ${TASK_LABEL}}
spec:
  replicas: 1
  selector: {matchLabels: {app: ${name}}}
  template:
    metadata:
      labels: {app: ${name}, sunmoonai.com/task: ${TASK_LABEL}}
    spec:
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      containers:
        - name: postgresql
          image: ${POSTGRES_IMAGE}
          ports: [{name: postgres, containerPort: 5432}]
          env:
            - {name: POSTGRESQL_DATABASE, value: tpl}
            - {name: POSTGRESQL_USERNAME, value: tpl}
            - name: POSTGRESQL_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: ${password_key}}}
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
metadata: {name: ${name}, namespace: ${NAMESPACE}}
spec:
  selector: {app: ${name}}
  ports: [{name: postgres, port: 5432, targetPort: postgres}]
EOF
  else
    cat <<EOF | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: ${TASK_LABEL}}
spec:
  replicas: 1
  selector: {matchLabels: {app: ${name}}}
  template:
    metadata:
      labels: {app: ${name}, sunmoonai.com/task: ${TASK_LABEL}}
    spec:
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      containers:
        - name: redis
          image: ${REDIS_IMAGE}
          ports: [{name: redis, containerPort: 6379}]
          env:
            - name: REDIS_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: ${password_key}}}
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
metadata: {name: ${name}, namespace: ${NAMESPACE}}
spec:
  selector: {app: ${name}}
  ports: [{name: redis, port: 6379, targetPort: redis}]
EOF
  fi
}

apply_stateful_dependency p0-008c-web-postgresql postgres WEB_POSTGRES_PASSWORD
apply_stateful_dependency p0-008c-runtime-postgresql postgres RUNTIME_POSTGRES_PASSWORD
apply_stateful_dependency p0-008c-web-redis redis WEB_REDIS_PASSWORD
apply_stateful_dependency p0-008c-runtime-redis redis RUNTIME_REDIS_PASSWORD
for deployment in p0-008c-web-postgresql p0-008c-runtime-postgresql \
  p0-008c-web-redis p0-008c-runtime-redis; do
  k rollout status "deployment/${deployment}" -n "$NAMESPACE" --timeout=180s
done

run_migration() {
  local name="$1" image="$2" postgres_service="$3" password_key="$4" setup_checkpoint="$5"
  k delete job "$name" -n "$NAMESPACE" \
    --ignore-not-found=true --wait=true >/dev/null
  cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${name}
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: ${TASK_LABEL}}
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 240
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels: {sunmoonai.com/task: ${TASK_LABEL}}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: migrate
          image: ${image}
          command: ["/bin/sh", "-ec"]
          args:
            - |
              .venv/bin/alembic upgrade head
              if [ "${setup_checkpoint}" = "true" ]; then
                .venv/bin/python -c 'from app.infrastructure.graph.checkpointer import phase0_postgres_checkpointer; context=phase0_postgres_checkpointer(setup=True); context.__enter__(); context.__exit__(None, None, None)'
              fi
              .venv/bin/alembic current
          env:
            - name: POSTGRES_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: ${password_key}}}
            - name: DATABASE_URL
              value: "postgresql+asyncpg://tpl:\$(POSTGRES_PASSWORD)@${postgres_service}:5432/tpl"
            - {name: FRONTEND_ALLOWED_ORIGINS, value: "https://migration.invalid"}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
EOF
  if ! k wait --for=condition=complete "job/${name}" \
    -n "$NAMESPACE" --timeout=240s; then
    k logs "job/${name}" -n "$NAMESPACE" --tail=100 >&2 || true
    exit 1
  fi
  k logs "job/${name}" -n "$NAMESPACE" --tail=20
}

run_migration p0-008c-web-migration "$WEB_BFF_IMAGE" \
  p0-008c-web-postgresql WEB_POSTGRES_PASSWORD false
run_migration p0-008c-runtime-migration "$RUNTIME_IMAGE" \
  p0-008c-runtime-postgresql RUNTIME_POSTGRES_PASSWORD true

cat <<EOF | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: research-runtime-p0-008c
  namespace: ${NAMESPACE}
  labels: {app: research-runtime-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
spec:
  replicas: 2
  minReadySeconds: 5
  strategy: {type: RollingUpdate, rollingUpdate: {maxUnavailable: 0, maxSurge: 1}}
  selector: {matchLabels: {app: research-runtime-p0-008c}}
  template:
    metadata:
      labels: {app: research-runtime-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
      annotations: {sunmoonai.com/deployment-id: "${DEPLOYMENT_ID}"}
    spec:
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: runtime
          image: ${RUNTIME_IMAGE}
          ports: [{name: http, containerPort: 8000}]
          envFrom:
            - configMapRef: {name: research-runtime-p0-008c-config}
            - secretRef: {name: ${ADMIN_BROKER_SECRET}}
            - secretRef: {name: ${RETRIEVAL_SECRET}}
            - secretRef: {name: ${SERVICE_BINDING_SECRET}}
            - secretRef: {name: ${LLM_SECRET}}
          env:
            - name: POSTGRES_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: RUNTIME_POSTGRES_PASSWORD}}
            - name: DATABASE_URL
              value: "postgresql+asyncpg://tpl:\$(POSTGRES_PASSWORD)@p0-008c-runtime-postgresql:5432/tpl"
            - name: REDIS_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: RUNTIME_REDIS_PASSWORD}}
          readinessProbe:
            httpGet: {path: /ready, port: http, httpHeaders: [{name: Host, value: research-runtime-p0-008c}]}
            initialDelaySeconds: 3
            periodSeconds: 3
            failureThreshold: 30
          livenessProbe:
            httpGet: {path: /health, port: http, httpHeaders: [{name: Host, value: research-runtime-p0-008c}]}
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests: {cpu: 100m, memory: 256Mi}
            limits: {cpu: "1", memory: 1Gi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
            readOnlyRootFilesystem: true
          volumeMounts: [{name: tmp, mountPath: /tmp}]
      volumes: [{name: tmp, emptyDir: {}}]
---
apiVersion: v1
kind: Service
metadata: {name: research-runtime-p0-008c, namespace: ${NAMESPACE}}
spec:
  selector: {app: research-runtime-p0-008c}
  ports: [{name: http, port: 8000, targetPort: http}]
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: research-runtime-p0-008c, namespace: ${NAMESPACE}}
spec:
  minAvailable: 1
  selector: {matchLabels: {app: research-runtime-p0-008c}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: research-runtime-worker-p0-008c
  namespace: ${NAMESPACE}
  labels: {app: research-runtime-worker-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
spec:
  replicas: 1
  selector: {matchLabels: {app: research-runtime-worker-p0-008c}}
  template:
    metadata:
      labels: {app: research-runtime-worker-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
      annotations: {sunmoonai.com/deployment-id: "${DEPLOYMENT_ID}"}
    spec:
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: worker
          image: ${RUNTIME_IMAGE}
          command: ["/bin/sh", "-ec"]
          args:
            - exec celery -A app.worker:celery_app worker -l INFO -Q research.p0-008c -c 1
          envFrom:
            - configMapRef: {name: research-runtime-p0-008c-config}
            - secretRef: {name: ${WORKER_BROKER_SECRET}}
            - secretRef: {name: ${RETRIEVAL_SECRET}}
            - secretRef: {name: ${SERVICE_BINDING_SECRET}}
            - secretRef: {name: ${LLM_SECRET}}
          env:
            - name: POSTGRES_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: RUNTIME_POSTGRES_PASSWORD}}
            - name: DATABASE_URL
              value: "postgresql+asyncpg://tpl:\$(POSTGRES_PASSWORD)@p0-008c-runtime-postgresql:5432/tpl"
            - name: REDIS_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: RUNTIME_REDIS_PASSWORD}}
          resources:
            requests: {cpu: 100m, memory: 256Mi}
            limits: {cpu: "1", memory: 1Gi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
            readOnlyRootFilesystem: true
          volumeMounts: [{name: tmp, mountPath: /tmp}]
      volumes: [{name: tmp, emptyDir: {}}]
EOF

cat <<EOF | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: research-web-backend-p0-008c
  namespace: ${NAMESPACE}
  labels: {app: research-web-backend-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
spec:
  replicas: 2
  minReadySeconds: 5
  strategy: {type: RollingUpdate, rollingUpdate: {maxUnavailable: 0, maxSurge: 1}}
  selector: {matchLabels: {app: research-web-backend-p0-008c}}
  template:
    metadata:
      labels: {app: research-web-backend-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
      annotations: {sunmoonai.com/deployment-id: "${DEPLOYMENT_ID}"}
    spec:
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: backend
          image: ${WEB_BFF_IMAGE}
          ports: [{name: http, containerPort: 8000}]
          envFrom: [{configMapRef: {name: research-web-p0-008c-config}}]
          env:
            - {name: DEPLOYMENT_ID, value: "${DEPLOYMENT_ID}"}
            - name: POSTGRES_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: WEB_POSTGRES_PASSWORD}}
            - name: DATABASE_URL
              value: "postgresql+asyncpg://tpl:\$(POSTGRES_PASSWORD)@p0-008c-web-postgresql:5432/tpl"
            - name: REDIS_PASSWORD
              valueFrom: {secretKeyRef: {name: ${RUNTIME_SECRET}, key: WEB_REDIS_PASSWORD}}
            - name: CASDOOR_CLIENT_ID
              valueFrom: {secretKeyRef: {name: ${BROWSER_SECRET}, key: CLIENT_ID}}
            - name: CASDOOR_CLIENT_SECRET
              valueFrom: {secretKeyRef: {name: ${BROWSER_SECRET}, key: CLIENT_SECRET}}
            - name: DOWNSTREAM_CLIENT_ID
              valueFrom: {secretKeyRef: {name: ${SERVICE_CALLER_SECRET}, key: CLIENT_ID}}
            - name: DOWNSTREAM_CLIENT_SECRET
              valueFrom: {secretKeyRef: {name: ${SERVICE_CALLER_SECRET}, key: CLIENT_SECRET}}
          readinessProbe:
            httpGet: {path: /ready, port: http, httpHeaders: [{name: Host, value: "${HOST}"}]}
            initialDelaySeconds: 3
            periodSeconds: 3
            failureThreshold: 30
          livenessProbe:
            httpGet: {path: /health, port: http, httpHeaders: [{name: Host, value: "${HOST}"}]}
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests: {cpu: 100m, memory: 256Mi}
            limits: {cpu: "1", memory: 1Gi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
            readOnlyRootFilesystem: true
          volumeMounts: [{name: tmp, mountPath: /tmp}]
      volumes: [{name: tmp, emptyDir: {}}]
---
apiVersion: v1
kind: Service
metadata: {name: research-web-backend-p0-008c, namespace: ${NAMESPACE}}
spec:
  selector: {app: research-web-backend-p0-008c}
  ports: [{name: http, port: 8000, targetPort: http}]
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: research-web-backend-p0-008c, namespace: ${NAMESPACE}}
spec:
  minAvailable: 1
  selector: {matchLabels: {app: research-web-backend-p0-008c}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: research-web-frontend-p0-008c
  namespace: ${NAMESPACE}
  labels: {app: research-web-frontend-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
spec:
  replicas: 2
  minReadySeconds: 5
  strategy: {type: RollingUpdate, rollingUpdate: {maxUnavailable: 0, maxSurge: 1}}
  selector: {matchLabels: {app: research-web-frontend-p0-008c}}
  template:
    metadata:
      labels: {app: research-web-frontend-p0-008c, sunmoonai.com/task: ${TASK_LABEL}}
      annotations: {sunmoonai.com/deployment-id: "${DEPLOYMENT_ID}"}
    spec:
      automountServiceAccountToken: false
      imagePullSecrets: [{name: harbor-registry-secret}]
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        runAsGroup: 1001
        seccompProfile: {type: RuntimeDefault}
      containers:
        - name: frontend
          image: ${NEXT_IMAGE}
          ports: [{name: http, containerPort: 3000}]
          env:
            - {name: DEPLOYMENT_ENV, value: production}
            - {name: AUTH_APP, value: research}
            - {name: APP_ORIGIN, value: "${origin}"}
            - {name: WEB_BACKEND_INTERNAL_URL, value: "http://research-web-backend-p0-008c:8000"}
            - {name: DEPLOYMENT_ID, value: "${DEPLOYMENT_ID}"}
          readinessProbe:
            httpGet: {path: /zh-CN, port: http}
            initialDelaySeconds: 3
            periodSeconds: 3
          livenessProbe:
            httpGet: {path: /zh-CN, port: http}
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests: {cpu: 100m, memory: 256Mi}
            limits: {cpu: "1", memory: 1Gi}
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: {drop: ["ALL"]}
            readOnlyRootFilesystem: true
          volumeMounts: [{name: tmp, mountPath: /tmp}]
      volumes: [{name: tmp, emptyDir: {}}]
---
apiVersion: v1
kind: Service
metadata: {name: research-web-frontend-p0-008c, namespace: ${NAMESPACE}}
spec:
  selector: {app: research-web-frontend-p0-008c}
  ports: [{name: http, port: 3000, targetPort: http}]
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: research-web-frontend-p0-008c, namespace: ${NAMESPACE}}
spec:
  minAvailable: 1
  selector: {matchLabels: {app: research-web-frontend-p0-008c}}
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: research-web-p0-008c
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: ${TASK_LABEL}}
spec:
  entryPoints: [websecure]
  routes:
    - match: Host(\`${HOST}\`) && PathPrefix(\`/api\`)
      kind: Rule
      priority: 100
      services: [{name: research-web-backend-p0-008c, port: 8000}]
    - match: Host(\`${HOST}\`) && PathPrefix(\`/\`)
      kind: Rule
      priority: 10
      services: [{name: research-web-frontend-p0-008c, port: 3000}]
  tls: {}
EOF

for deployment in research-runtime-p0-008c research-runtime-worker-p0-008c \
  research-web-backend-p0-008c research-web-frontend-p0-008c; do
  k rollout status "deployment/${deployment}" -n "$NAMESPACE" --timeout=300s
done

runtime_ready="$(k get deployment research-runtime-p0-008c -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
worker_ready="$(k get deployment research-runtime-worker-p0-008c -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
bff_ready="$(k get deployment research-web-backend-p0-008c -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
next_ready="$(k get deployment research-web-frontend-p0-008c -n "$NAMESPACE" \
  -o jsonpath='{.status.readyReplicas}')"
[[ "$runtime_ready" == 2 && "$worker_ready" == 1 \
  && "$bff_ready" == 2 && "$next_ready" == 2 ]] || {
  printf 'P0-008C readiness mismatch runtime=%s worker=%s bff=%s next=%s\n' \
    "$runtime_ready" "$worker_ready" "$bff_ready" "$next_ready" >&2
  exit 1
}
printf 'V5-P0-008C isolated pilot deployed runtime=%s worker=%s bff=%s next=%s\n' \
  "$runtime_ready" "$worker_ready" "$bff_ready" "$next_ready"
