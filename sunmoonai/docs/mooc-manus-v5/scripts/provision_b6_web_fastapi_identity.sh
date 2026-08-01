#!/usr/bin/env bash

# Reconcile the isolated Casdoor application used by P0-008B-B6.3F. Credentials stay
# in Kubernetes Secrets and are never printed or written to the repository.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="app-platform-dev"
IDENTITY_SECRET="sunmoonai-p0-008b-b63f-web-identity"
CASDOOR_DATABASE_SECRET="casdoor-postgresql-conn"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
APPLICATION="sunmoonai-tpl-web-p0-008b-b63f"
REDIRECT_URI="https://tpl-web-p0-008b-b63f.sunmoonai.com:30443/api/auth/callback"
MODE="plan"

usage() {
  cat <<'EOF'
Usage: provision_b6_web_fastapi_identity.sh [--apply|--cleanup] [options]
  --apply                 Reconcile the Secret and Casdoor application
  --cleanup               Delete the Casdoor application and task Secret
  --kubeconfig PATH       Kubeconfig path
  --namespace NAME        Target namespace
  --redirect-uri URL      Exact P0-008B-B6.3F OIDC callback URI
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --cleanup) MODE="cleanup"; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --redirect-uri) REDIRECT_URI="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

wait_job() {
  local job="$1"
  if ! k wait --for=condition=complete "job/${job}" -n "$NAMESPACE" --timeout=180s; then
    k logs "job/${job}" -n "$NAMESPACE" --tail=100 >&2 || true
    return 1
  fi
  k logs "job/${job}" -n "$NAMESPACE" --tail=20
  k delete job "$job" -n "$NAMESPACE" --wait=true >/dev/null
}

delete_application() {
  local job="p0-008b-b63f-identity-delete"
  k get secret "$CASDOOR_DATABASE_SECRET" -n "$NAMESPACE" >/dev/null
  k delete job "$job" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
  cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b63f
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-008b-b63f
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: delete
          image: ${POSTGRES_CLIENT_IMAGE}
          envFrom:
            - secretRef:
                name: ${CASDOOR_DATABASE_SECRET}
          command: ["/bin/bash", "-ec"]
          args:
            - |
              export PGPASSWORD="\$APP_DB_PASSWORD"
              psql -h "\$DB_HOST" -p "\$DB_PORT" -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
                -v ON_ERROR_STOP=1 \
                -c "DELETE FROM application WHERE owner='admin' AND name='${APPLICATION}'" \
                >/dev/null
              printf 'P0-008B-B6.3F Casdoor application removed\n'
EOF
  wait_job "$job"
}

if [[ "$MODE" == "cleanup" ]]; then
  delete_application
  k delete secret "$IDENTITY_SECRET" -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  printf 'V5-P0-008B-B6.3F identity cleanup passed\n'
  exit 0
fi

printf 'PLAN Casdoor application=%s redirect=%s secret=%s/%s\n' \
  "$APPLICATION" "$REDIRECT_URI" "$NAMESPACE" "$IDENTITY_SECRET"
[[ "$MODE" == "apply" ]] || exit 0

[[ "$REDIRECT_URI" =~ ^https://tpl-web-p0-008b-b63f\.sunmoonai\.com(:[0-9]+)?/api/auth/callback$ ]] || {
  printf 'redirect URI is outside the P0-008B-B6.3F trust boundary\n' >&2
  exit 1
}
k get secret "$CASDOOR_DATABASE_SECRET" -n "$NAMESPACE" >/dev/null

if ! k get secret "$IDENTITY_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  client_id="$(openssl rand -hex 16)"
  client_secret="$(openssl rand -hex 32)"
  k create secret generic "$IDENTITY_SECRET" -n "$NAMESPACE" \
    --from-literal=CLIENT_ID="$client_id" \
    --from-literal=CLIENT_SECRET="$client_secret" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  unset client_id client_secret
fi
k label secret "$IDENTITY_SECRET" -n "$NAMESPACE" \
  sunmoonai.com/task=v5-p0-008b-b63f --overwrite >/dev/null

job="p0-008b-b63f-identity-provision"
k delete job "$job" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b63f
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-008b-b63f
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: provision
          image: ${POSTGRES_CLIENT_IMAGE}
          envFrom:
            - secretRef:
                name: ${IDENTITY_SECRET}
            - secretRef:
                name: ${CASDOOR_DATABASE_SECRET}
          env:
            - name: REDIRECT_URI
              value: "${REDIRECT_URI}"
          command: ["/bin/bash", "-ec"]
          args:
            - |
              test "\${#CLIENT_ID}" -eq 32
              test "\${#CLIENT_SECRET}" -eq 64
              export PGPASSWORD="\$APP_DB_PASSWORD"
              psql -h "\$DB_HOST" -p "\$DB_PORT" -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
                -v ON_ERROR_STOP=1 \
                --set=client_id="\$CLIENT_ID" \
                --set=client_secret="\$CLIENT_SECRET" \
                --set=redirect_uri="\$REDIRECT_URI" <<'SQL'
              INSERT INTO application (
                owner, name, created_time, display_name, client_id, client_secret,
                redirect_uris, cert, grant_types, organization, enable_sign_up,
                token_format, expire_in_hours, refresh_expire_in_hours
              ) VALUES (
                'admin', '${APPLICATION}', NOW()::text, 'Template Web FastAPI B6.3',
                :'client_id', :'client_secret',
                json_build_array(:'redirect_uri')::text,
                'cert-built-in', '["authorization_code"]', 'sunmoonai', false,
                'JWT', 1, 24
              ) ON CONFLICT (owner, name) DO UPDATE SET
                display_name=EXCLUDED.display_name,
                client_id=EXCLUDED.client_id,
                client_secret=EXCLUDED.client_secret,
                redirect_uris=EXCLUDED.redirect_uris,
                cert=EXCLUDED.cert,
                grant_types=EXCLUDED.grant_types,
                organization=EXCLUDED.organization,
                enable_sign_up=EXCLUDED.enable_sign_up,
                token_format=EXCLUDED.token_format,
                expire_in_hours=EXCLUDED.expire_in_hours,
                refresh_expire_in_hours=EXCLUDED.refresh_expire_in_hours;

              UPDATE application
              SET enable_password=true,
                  signin_methods='[{"name":"Password","displayName":"Password","rule":"All"}]',
                  signin_items=(
                    SELECT signin_items FROM application
                    WHERE owner='admin' AND name='app-built-in'
                  )
              WHERE owner='admin' AND name='${APPLICATION}';

              SELECT 1 / CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END
              FROM application
              WHERE owner='admin' AND name='${APPLICATION}'
                AND client_id=:'client_id'
                AND redirect_uris=json_build_array(:'redirect_uri')::text
                AND grant_types='["authorization_code"]';
              SQL
              printf 'P0-008B-B6.3F Casdoor application reconciled\n'
EOF
wait_job "$job"
printf 'V5-P0-008B-B6.3F identity provisioning passed\n'
