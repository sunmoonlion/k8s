#!/usr/bin/env bash

# End-to-end R3 gate: render the canonical template, deploy it in an isolated
# namespace, validate runtime/policy, and run strict-TLS real-Casdoor browsers.

set -euo pipefail
umask 077

ROOT="/home/zymun"
TPL_ROOT="${ROOT}/tpl-app"
SCRIPT_ROOT="${ROOT}/k8s/sunmoonai/docs/architecture-v2/scripts"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="${R3_NAMESPACE:-tpl-architecture-v2-r3}"
PROVIDER_NAMESPACE="${R3_PROVIDER_NAMESPACE:-app-platform-dev}"
INGRESS_NAMESPACE="${R3_INGRESS_NAMESPACE:-ingress-platform-dev}"
APP="tpl"
RELEASE_ID="r3-001"
ADMIN_ORIGIN="https://tpl-admin-r3.sunmoonai.com:30443"
WEB_ORIGIN="https://tpl-web-r3.sunmoonai.com:30443"
CASDOOR_ORIGIN="https://casdoor.sunmoonai.com:30443"
CASDOOR_BACKCHANNEL="http://casdoor-sunmoonai.${PROVIDER_NAMESPACE}.svc.cluster.local:8000"
IDENTITY_SECRET="sunmoonai-architecture-v2-r3-identity"
OPERATOR_SECRET="sunmoonai-p0-005-browser-identity"
SOURCE_TLS_SECRET="traefik-tls-secret"
TARGET_TLS_SECRET="tpl-r3-tls"
SOURCE_PULL_SECRET="harbor-registry-secret"
TARGET_PULL_SECRET="harbor-registry-secret"

RELEASE_MANIFEST="${R3_RELEASE_MANIFEST:-${TPL_ROOT}/template-release-manifest.json}"

release_component_image() {
  python3 - "$RELEASE_MANIFEST" "$1" <<'PY'
import json
import sys

manifest_path, component_path = sys.argv[1:3]
with open(manifest_path, encoding="utf-8") as handle:
    release = json.load(handle)
for component in release["default_components"]:
    if component["path"] == component_path:
        print(component["image"])
        break
else:
    raise SystemExit(f"release component is absent: {component_path}")
PY
}

BACKEND_IMAGE="${BACKEND_IMAGE:-$(release_component_image tpl-backend)}"
ADMIN_IMAGE="${ADMIN_IMAGE:-$(release_component_image tpl-admin-frontend)}"
WEB_IMAGE="${WEB_IMAGE:-$(release_component_image tpl-web-frontend)}"
WEB_R2_IMAGE="harbor.sunmoonai.com:30443/app-images/tpl-web-frontend@sha256:ea5d872c82c764b01eaa427a32e6393b9197e9842a002d4c8cad2ef7b5648808"
POSTGRES_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql@sha256:dbd371582fbbb100b22b891e485f4559187362348c1d4b5d0a2191134807516b"
REDIS_IMAGE="harbor.sunmoonai.com:30443/k8s-images/redis@sha256:0d2c5324b7373522e1fce60d657d60c851aa2921b211fd795f20c8515bee429e"

WORK_DIR="$(mktemp -d /tmp/architecture-v2-r3.XXXXXX)"
BUNDLE_DIR="${WORK_DIR}/bundle"
DEPENDENCY_ENV="${WORK_DIR}/dependencies.env"
RUNTIME_ENV="${WORK_DIR}/backend-runtime.env"
EVIDENCE_DIR="${R3_EVIDENCE_DIR:-${ROOT}/k8s/sunmoonai/docs/architecture-v2/evidence/R3-template-gate}"
mkdir -p "$EVIDENCE_DIR"

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

secret_value() {
  local namespace="$1" secret="$2" key="$3" encoded
  encoded="$(k get secret "$secret" -n "$namespace" -o "jsonpath={.data.${key}}")"
  [[ -n "$encoded" ]] || {
    printf 'required Secret key is absent: %s/%s:%s\n' "$namespace" "$secret" "$key" >&2
    return 1
  }
  printf '%s' "$encoded" | base64 --decode
}

copy_secret() {
  local source_namespace="$1" source_name="$2" target_name="$3"
  k get secret "$source_name" -n "$source_namespace" -o json \
    | python3 -c '
import json, sys
namespace, name = sys.argv[1:3]
value = json.load(sys.stdin)
value["metadata"] = {
    "name": name,
    "namespace": namespace,
    "labels": {"sunmoonai.com/task": "architecture-v2-r3"},
}
for key in ("status", "immutable"):
    value.pop(key, None)
json.dump(value, sys.stdout, separators=(",", ":"))
' "$NAMESPACE" "$target_name" \
    | k apply -f - >/dev/null
}

cleanup() {
  local rc=$?
  trap - EXIT INT TERM HUP
  set +e
  if [[ -f "${BUNDLE_DIR}/release.json" ]]; then
    python3 "${TPL_ROOT}/k8s-scaffold-v2/deploy.py" cleanup \
      --bundle "$BUNDLE_DIR" \
      --kubeconfig "$KUBECONFIG_PATH" \
      --delete-namespace >/dev/null 2>&1
  else
    k delete namespace "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null 2>&1
  fi
  "${SCRIPT_ROOT}/provision_r3_template_identity.sh" --cleanup \
    --kubeconfig "$KUBECONFIG_PATH" \
    --provider-namespace "$PROVIDER_NAMESPACE" >/dev/null 2>&1
  if [[ "$rc" -eq 0 ]]; then
    rm -rf "$WORK_DIR"
  else
    printf 'R3 gate failed; diagnostics retained at %s\n' "$WORK_DIR" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM HUP

for command in "$KUBECTL_BIN" python3 node openssl base64 certutil; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'required command is missing: %s\n' "$command" >&2
    exit 1
  }
done

printf 'R3_STAGE=preflight\n'
k get namespace "$PROVIDER_NAMESPACE" >/dev/null
k get namespace "$INGRESS_NAMESPACE" >/dev/null
k get secret "$SOURCE_TLS_SECRET" -n "$INGRESS_NAMESPACE" >/dev/null
k get secret "$SOURCE_PULL_SECRET" -n "$PROVIDER_NAMESPACE" >/dev/null
k get secret "$OPERATOR_SECRET" -n "$PROVIDER_NAMESPACE" >/dev/null

printf 'R3_STAGE=identity\n'
"${SCRIPT_ROOT}/provision_r3_template_identity.sh" --apply \
  --kubeconfig "$KUBECONFIG_PATH" \
  --provider-namespace "$PROVIDER_NAMESPACE"

admin_client_id="$(secret_value "$PROVIDER_NAMESPACE" "$IDENTITY_SECRET" ADMIN_CLIENT_ID)"
admin_client_secret="$(secret_value "$PROVIDER_NAMESPACE" "$IDENTITY_SECRET" ADMIN_CLIENT_SECRET)"
web_client_id="$(secret_value "$PROVIDER_NAMESPACE" "$IDENTITY_SECRET" WEB_CLIENT_ID)"
web_client_secret="$(secret_value "$PROVIDER_NAMESPACE" "$IDENTITY_SECRET" WEB_CLIENT_SECRET)"
[[ "$admin_client_id" != "$web_client_id" && "$admin_client_secret" != "$web_client_secret" ]]

printf 'R3_STAGE=render\n'
python3 "${TPL_ROOT}/k8s-scaffold-v2/scaffold.py" \
  --app "$APP" \
  --namespace "$NAMESPACE" \
  --release-id "$RELEASE_ID" \
  --backend-image "$BACKEND_IMAGE" \
  --admin-image "$ADMIN_IMAGE" \
  --web-image "$WEB_IMAGE" \
  --admin-origin "$ADMIN_ORIGIN" \
  --web-origin "$WEB_ORIGIN" \
  --casdoor-origin "$CASDOOR_ORIGIN" \
  --casdoor-backchannel-origin "$CASDOOR_BACKCHANNEL" \
  --casdoor-namespace "$PROVIDER_NAMESPACE" \
  --admin-client-id "$admin_client_id" \
  --web-client-id "$web_client_id" \
  --admin-application sunmoonai-tpl-architecture-v2-r3-admin \
  --web-application sunmoonai-tpl-architecture-v2-r3-web \
  --tls-secret "$TARGET_TLS_SECRET" \
  --image-pull-secret "$TARGET_PULL_SECRET" \
  --ingress-namespace "$INGRESS_NAMESPACE" \
  --redis-host tpl-r3-redis \
  --output-dir "$BUNDLE_DIR" \
  >"${EVIDENCE_DIR}/render.json"

python3 "${TPL_ROOT}/k8s-scaffold-v2/deploy.py" plan \
  --bundle "$BUNDLE_DIR" \
  >"${EVIDENCE_DIR}/plan.json"

for resource in "${BUNDLE_DIR}"/*.yaml; do
  k apply --dry-run=client --validate=false -f "$resource" >/dev/null
done

printf 'R3_STAGE=dependencies\n'
k apply -f "${BUNDLE_DIR}/00-prerequisites.yaml" >/dev/null
copy_secret "$INGRESS_NAMESPACE" "$SOURCE_TLS_SECRET" "$TARGET_TLS_SECRET"
copy_secret "$PROVIDER_NAMESPACE" "$SOURCE_PULL_SECRET" "$TARGET_PULL_SECRET"

postgres_admin_password="$(openssl rand -hex 24)"
migration_db_password="$(openssl rand -hex 24)"
api_db_password="$(openssl rand -hex 24)"
worker_db_password="$(openssl rand -hex 24)"
scheduler_db_password="$(openssl rand -hex 24)"
redis_password="$(openssl rand -hex 24)"

cat >"$DEPENDENCY_ENV" <<EOF
POSTGRES_ADMIN_PASSWORD=${postgres_admin_password}
MIGRATION_DB_PASSWORD=${migration_db_password}
API_DB_PASSWORD=${api_db_password}
WORKER_DB_PASSWORD=${worker_db_password}
SCHEDULER_DB_PASSWORD=${scheduler_db_password}
REDIS_PASSWORD=${redis_password}
EOF
chmod 600 "$DEPENDENCY_ENV"
k create secret generic tpl-r3-dependencies -n "$NAMESPACE" \
  --from-env-file="$DEPENDENCY_ENV" --dry-run=client -o yaml \
  | k apply -f - >/dev/null
k label secret tpl-r3-dependencies -n "$NAMESPACE" \
  sunmoonai.com/task=architecture-v2-r3 --overwrite >/dev/null

cat <<EOF | k apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tpl-r3-postgresql
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: architecture-v2-r3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tpl-r3-postgresql
  template:
    metadata:
      labels:
        app: tpl-r3-postgresql
        sunmoonai.com/backend-dependency: tpl
        sunmoonai.com/task: architecture-v2-r3
    spec:
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: ${TARGET_PULL_SECRET}
      containers:
        - name: postgresql
          image: ${POSTGRES_IMAGE}
          ports:
            - {name: postgres, containerPort: 5432}
          env:
            - {name: POSTGRESQL_DATABASE, value: tpl}
            - {name: POSTGRESQL_USERNAME, value: tpl_migration}
            - name: POSTGRESQL_PASSWORD
              valueFrom: {secretKeyRef: {name: tpl-r3-dependencies, key: MIGRATION_DB_PASSWORD}}
            - name: POSTGRESQL_POSTGRES_PASSWORD
              valueFrom: {secretKeyRef: {name: tpl-r3-dependencies, key: POSTGRES_ADMIN_PASSWORD}}
          readinessProbe:
            exec:
              command: ["/bin/bash", "-ec", "PGPASSWORD=\$POSTGRESQL_PASSWORD pg_isready -h 127.0.0.1 -U tpl_migration -d tpl"]
            initialDelaySeconds: 3
            periodSeconds: 3
          resources:
            requests: {cpu: 50m, memory: 128Mi}
            limits: {cpu: 500m, memory: 512Mi}
---
apiVersion: v1
kind: Service
metadata:
  name: tpl-r3-postgresql
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/backend-dependency: tpl
    sunmoonai.com/task: architecture-v2-r3
spec:
  selector: {app: tpl-r3-postgresql}
  ports:
    - {name: postgres, port: 5432, targetPort: postgres}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tpl-r3-redis
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: architecture-v2-r3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tpl-r3-redis
  template:
    metadata:
      labels:
        app: tpl-r3-redis
        sunmoonai.com/backend-dependency: tpl
        sunmoonai.com/task: architecture-v2-r3
    spec:
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: ${TARGET_PULL_SECRET}
      containers:
        - name: redis
          image: ${REDIS_IMAGE}
          ports:
            - {name: redis, containerPort: 6379}
          env:
            - name: REDIS_PASSWORD
              valueFrom: {secretKeyRef: {name: tpl-r3-dependencies, key: REDIS_PASSWORD}}
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
  name: tpl-r3-redis
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/backend-dependency: tpl
    sunmoonai.com/task: architecture-v2-r3
spec:
  selector: {app: tpl-r3-redis}
  ports:
    - {name: redis, port: 6379, targetPort: redis}
EOF

k rollout status deployment/tpl-r3-postgresql -n "$NAMESPACE" --timeout=180s
k rollout status deployment/tpl-r3-redis -n "$NAMESPACE" --timeout=180s

cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: tpl-r3-postgresql-roles
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: architecture-v2-r3
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        sunmoonai.com/task: architecture-v2-r3
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: ${TARGET_PULL_SECRET}
      containers:
        - name: roles
          image: ${POSTGRES_IMAGE}
          envFrom:
            - secretRef: {name: tpl-r3-dependencies}
          command: ["/bin/bash", "-ec"]
          args:
            - |
              export PGPASSWORD="\$POSTGRES_ADMIN_PASSWORD"
              ready=false
              for attempt in \$(seq 1 30); do
                if psql -h tpl-r3-postgresql -U postgres -d tpl \
                  -v ON_ERROR_STOP=1 -c 'SELECT 1' >/dev/null 2>&1; then
                  ready=true
                  break
                fi
                sleep 2
              done
              test "\$ready" = true
              psql -h tpl-r3-postgresql -U postgres -d tpl -v ON_ERROR_STOP=1 \
                --set=api_password="\$API_DB_PASSWORD" \
                --set=worker_password="\$WORKER_DB_PASSWORD" \
                --set=scheduler_password="\$SCHEDULER_DB_PASSWORD" <<'SQL'
              DO \$roles\$
              BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tpl_api') THEN
                  CREATE ROLE tpl_api LOGIN;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tpl_worker') THEN
                  CREATE ROLE tpl_worker LOGIN;
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tpl_scheduler') THEN
                  CREATE ROLE tpl_scheduler LOGIN;
                END IF;
              END
              \$roles\$;
              ALTER ROLE tpl_api PASSWORD :'api_password';
              ALTER ROLE tpl_worker PASSWORD :'worker_password';
              ALTER ROLE tpl_scheduler PASSWORD :'scheduler_password';
              GRANT CONNECT ON DATABASE tpl TO tpl_api, tpl_worker, tpl_scheduler;
              GRANT USAGE ON SCHEMA public TO tpl_api, tpl_worker, tpl_scheduler;
              ALTER DEFAULT PRIVILEGES FOR ROLE tpl_migration IN SCHEMA public
                GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tpl_api, tpl_worker;
              ALTER DEFAULT PRIVILEGES FOR ROLE tpl_migration IN SCHEMA public
                GRANT SELECT ON TABLES TO tpl_scheduler;
              ALTER DEFAULT PRIVILEGES FOR ROLE tpl_migration IN SCHEMA public
                GRANT USAGE, SELECT ON SEQUENCES TO tpl_api, tpl_worker;
              SQL
              printf 'R3 database roles reconciled\n'
EOF
k wait --for=condition=complete job/tpl-r3-postgresql-roles \
  -n "$NAMESPACE" --timeout=180s
k logs job/tpl-r3-postgresql-roles -n "$NAMESPACE" --tail=20
k delete job tpl-r3-postgresql-roles -n "$NAMESPACE" --wait=true >/dev/null

cat >"$RUNTIME_ENV" <<EOF
ADMIN_CASDOOR_CLIENT_SECRET=${admin_client_secret}
API_CELERY_BROKER_URL=redis://:${redis_password}@tpl-r3-redis:6379/0
API_DATABASE_URL=postgresql+asyncpg://tpl_api:${api_db_password}@tpl-r3-postgresql:5432/tpl
MIGRATION_DATABASE_URL=postgresql+asyncpg://tpl_migration:${migration_db_password}@tpl-r3-postgresql:5432/tpl
REDIS_PASSWORD=${redis_password}
SCHEDULER_CELERY_BROKER_URL=redis://:${redis_password}@tpl-r3-redis:6379/0
SCHEDULER_DATABASE_URL=postgresql+asyncpg://tpl_scheduler:${scheduler_db_password}@tpl-r3-postgresql:5432/tpl
WEB_CASDOOR_CLIENT_SECRET=${web_client_secret}
WORKER_CELERY_BROKER_URL=redis://:${redis_password}@tpl-r3-redis:6379/0
WORKER_DATABASE_URL=postgresql+asyncpg://tpl_worker:${worker_db_password}@tpl-r3-postgresql:5432/tpl
WORKER_CELERY_RESULT_BACKEND=redis://:${redis_password}@tpl-r3-redis:6379/0
EOF
chmod 600 "$RUNTIME_ENV"
unset admin_client_secret web_client_secret postgres_admin_password
unset migration_db_password api_db_password worker_db_password scheduler_db_password redis_password

printf 'R3_STAGE=deploy\n'
python3 "${TPL_ROOT}/k8s-scaffold-v2/deploy.py" apply \
  --bundle "$BUNDLE_DIR" \
  --secret-env-file "$RUNTIME_ENV" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --timeout 300 \
  | tee "${EVIDENCE_DIR}/deploy.txt"

printf 'R3_STAGE=kind_structure_gate\n'
python3 "${SCRIPT_ROOT}/verify_r3_template_kind.py" \
  --bundle "$BUNDLE_DIR" \
  --namespace "$NAMESPACE" \
  --kubeconfig "$KUBECONFIG_PATH" \
  --skip-network-runtime \
  | tee "${EVIDENCE_DIR}/kind.json"

printf 'R3_STAGE=strict_tls_browser_gate\n'
KUBECONFIG="$KUBECONFIG_PATH" \
R3_NAMESPACE="$NAMESPACE" \
R3_PROVIDER_NAMESPACE="$PROVIDER_NAMESPACE" \
node "${SCRIPT_ROOT}/verify_r3_template_browser.mjs" \
  | tee "${EVIDENCE_DIR}/browser.json"

printf 'R3_STAGE=rollback_forward_gate\n'
KUBECONFIG="$KUBECONFIG_PATH" \
R3_NAMESPACE="$NAMESPACE" \
R3_WEB_ORIGIN="$WEB_ORIGIN" \
"${SCRIPT_ROOT}/verify_r3_template_rollback.sh" \
  --bundle "$BUNDLE_DIR" \
  --r2-image "$WEB_R2_IMAGE" \
  | tee "${EVIDENCE_DIR}/rollback.txt"

printf 'R3_STAGE=post_forward_browser_gate\n'
KUBECONFIG="$KUBECONFIG_PATH" \
R3_NAMESPACE="$NAMESPACE" \
R3_PROVIDER_NAMESPACE="$PROVIDER_NAMESPACE" \
node "${SCRIPT_ROOT}/verify_r3_template_browser.mjs" \
  | tee "${EVIDENCE_DIR}/browser-after-forward.json"

printf 'R3_STAGE=calico_network_policy_gate\n'
"${SCRIPT_ROOT}/verify_r3_network_policy_calico.sh" \
  --bundle "$BUNDLE_DIR" \
  | tee "${EVIDENCE_DIR}/network-policy.txt"

cp "${BUNDLE_DIR}/release.json" "${EVIDENCE_DIR}/release.json"
printf '{"task":"architecture-v2-r3","result":"passed","formal_release":false,"credentials_printed":false}\n' \
  | tee "${EVIDENCE_DIR}/result.json"
printf 'R3 gate passed; evidence directory=%s\n' "$EVIDENCE_DIR"
