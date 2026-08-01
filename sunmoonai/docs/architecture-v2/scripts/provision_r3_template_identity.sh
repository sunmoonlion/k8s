#!/usr/bin/env bash

# Reconcile the two isolated browser clients used by the Architecture v2 R3
# template gate. Credentials remain in Kubernetes Secrets and are never printed.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
PROVIDER_NAMESPACE="app-platform-dev"
IDENTITY_SECRET="sunmoonai-architecture-v2-r3-identity"
CASDOOR_DATABASE_SECRET="casdoor-postgresql-conn"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
ADMIN_APPLICATION="sunmoonai-tpl-architecture-v2-r3-admin"
WEB_APPLICATION="sunmoonai-tpl-architecture-v2-r3-web"
ADMIN_REDIRECT_URI="https://tpl-admin-r3.sunmoonai.com:30443/api/auth/admin/callback"
WEB_REDIRECT_URI="https://tpl-web-r3.sunmoonai.com:30443/api/auth/web/callback"
MODE="plan"

usage() {
  cat <<'EOF'
Usage: provision_r3_template_identity.sh [--apply|--cleanup] [options]
  --apply                     Reconcile both clients and Casdoor applications
  --cleanup                   Delete both applications and the task Secret
  --kubeconfig PATH           Kubeconfig path
  --provider-namespace NAME   Namespace containing Casdoor and its DB Secret
  --admin-redirect-uri URL    Exact Admin callback URI
  --web-redirect-uri URL      Exact Web callback URI
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --cleanup) MODE="cleanup"; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --provider-namespace) PROVIDER_NAMESPACE="$2"; shift 2 ;;
    --admin-redirect-uri) ADMIN_REDIRECT_URI="$2"; shift 2 ;;
    --web-redirect-uri) WEB_REDIRECT_URI="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

wait_job() {
  local job="$1"
  if ! k wait --for=condition=complete "job/${job}" \
    -n "$PROVIDER_NAMESPACE" --timeout=180s; then
    k logs "job/${job}" -n "$PROVIDER_NAMESPACE" --tail=100 >&2 || true
    return 1
  fi
  k logs "job/${job}" -n "$PROVIDER_NAMESPACE" --tail=20
  k delete job "$job" -n "$PROVIDER_NAMESPACE" --wait=true >/dev/null
}

delete_applications() {
  local job="architecture-v2-r3-identity-delete"
  k get secret "$CASDOOR_DATABASE_SECRET" -n "$PROVIDER_NAMESPACE" >/dev/null
  k delete job "$job" -n "$PROVIDER_NAMESPACE" \
    --ignore-not-found=true --wait=true >/dev/null
  cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${PROVIDER_NAMESPACE}
  labels:
    sunmoonai.com/task: architecture-v2-r3
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/task: architecture-v2-r3
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
                -c "DELETE FROM application WHERE owner='admin' AND name IN ('${ADMIN_APPLICATION}','${WEB_APPLICATION}')" \
                >/dev/null
              printf 'Architecture v2 R3 Casdoor applications removed\n'
EOF
  wait_job "$job"
}

if [[ "$MODE" == "cleanup" ]]; then
  delete_applications
  k delete secret "$IDENTITY_SECRET" -n "$PROVIDER_NAMESPACE" \
    --ignore-not-found=true >/dev/null
  printf 'Architecture v2 R3 identity cleanup passed\n'
  exit 0
fi

printf 'PLAN R3 browser clients: admin=%s web=%s secret=%s/%s\n' \
  "$ADMIN_APPLICATION" "$WEB_APPLICATION" "$PROVIDER_NAMESPACE" "$IDENTITY_SECRET"
[[ "$MODE" == "apply" ]] || exit 0

[[ "$ADMIN_REDIRECT_URI" =~ ^https://tpl-admin-r3\.sunmoonai\.com(:[0-9]+)?/api/auth/admin/callback$ ]] || {
  printf 'Admin redirect URI is outside the R3 trust boundary\n' >&2
  exit 1
}
[[ "$WEB_REDIRECT_URI" =~ ^https://tpl-web-r3\.sunmoonai\.com(:[0-9]+)?/api/auth/web/callback$ ]] || {
  printf 'Web redirect URI is outside the R3 trust boundary\n' >&2
  exit 1
}
k get secret "$CASDOOR_DATABASE_SECRET" -n "$PROVIDER_NAMESPACE" >/dev/null

if ! k get secret "$IDENTITY_SECRET" -n "$PROVIDER_NAMESPACE" >/dev/null 2>&1; then
  admin_client_id="$(openssl rand -hex 16)"
  admin_client_secret="$(openssl rand -hex 32)"
  web_client_id="$(openssl rand -hex 16)"
  web_client_secret="$(openssl rand -hex 32)"
  k create secret generic "$IDENTITY_SECRET" -n "$PROVIDER_NAMESPACE" \
    --from-literal=ADMIN_CLIENT_ID="$admin_client_id" \
    --from-literal=ADMIN_CLIENT_SECRET="$admin_client_secret" \
    --from-literal=WEB_CLIENT_ID="$web_client_id" \
    --from-literal=WEB_CLIENT_SECRET="$web_client_secret" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  unset admin_client_id admin_client_secret web_client_id web_client_secret
fi
k label secret "$IDENTITY_SECRET" -n "$PROVIDER_NAMESPACE" \
  sunmoonai.com/task=architecture-v2-r3 --overwrite >/dev/null

job="architecture-v2-r3-identity-provision"
k delete job "$job" -n "$PROVIDER_NAMESPACE" \
  --ignore-not-found=true --wait=true >/dev/null
cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${PROVIDER_NAMESPACE}
  labels:
    sunmoonai.com/task: architecture-v2-r3
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        sunmoonai.com/task: architecture-v2-r3
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
            - name: ADMIN_REDIRECT_URI
              value: "${ADMIN_REDIRECT_URI}"
            - name: WEB_REDIRECT_URI
              value: "${WEB_REDIRECT_URI}"
          command: ["/bin/bash", "-ec"]
          args:
            - |
              test "\${#ADMIN_CLIENT_ID}" -eq 32
              test "\${#ADMIN_CLIENT_SECRET}" -eq 64
              test "\${#WEB_CLIENT_ID}" -eq 32
              test "\${#WEB_CLIENT_SECRET}" -eq 64
              test "\$ADMIN_CLIENT_ID" != "\$WEB_CLIENT_ID"
              export PGPASSWORD="\$APP_DB_PASSWORD"
              psql -h "\$DB_HOST" -p "\$DB_PORT" -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
                -v ON_ERROR_STOP=1 \
                --set=admin_id="\$ADMIN_CLIENT_ID" \
                --set=admin_secret="\$ADMIN_CLIENT_SECRET" \
                --set=admin_redirect="\$ADMIN_REDIRECT_URI" \
                --set=web_id="\$WEB_CLIENT_ID" \
                --set=web_secret="\$WEB_CLIENT_SECRET" \
                --set=web_redirect="\$WEB_REDIRECT_URI" <<'SQL'
              INSERT INTO application (
                owner, name, created_time, display_name, client_id, client_secret,
                redirect_uris, cert, grant_types, organization, enable_sign_up,
                token_format, expire_in_hours, refresh_expire_in_hours
              ) VALUES
                ('admin', '${ADMIN_APPLICATION}', NOW()::text,
                 'Template Architecture v2 R3 Admin', :'admin_id', :'admin_secret',
                 json_build_array(:'admin_redirect')::text, 'cert-built-in',
                 '["authorization_code"]', 'sunmoonai', false, 'JWT', 1, 24),
                ('admin', '${WEB_APPLICATION}', NOW()::text,
                 'Template Architecture v2 R3 Web', :'web_id', :'web_secret',
                 json_build_array(:'web_redirect')::text, 'cert-built-in',
                 '["authorization_code"]', 'sunmoonai', false, 'JWT', 1, 24)
              ON CONFLICT (owner, name) DO UPDATE SET
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
              WHERE owner='admin'
                AND name IN ('${ADMIN_APPLICATION}', '${WEB_APPLICATION}');

              SELECT 1 / CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END
              FROM application
              WHERE owner='admin'
                AND ((name='${ADMIN_APPLICATION}' AND client_id=:'admin_id'
                      AND redirect_uris=json_build_array(:'admin_redirect')::text)
                  OR (name='${WEB_APPLICATION}' AND client_id=:'web_id'
                      AND redirect_uris=json_build_array(:'web_redirect')::text))
                AND grant_types='["authorization_code"]';
              SQL
              printf 'Architecture v2 R3 Casdoor applications reconciled\n'
EOF
wait_job "$job"
printf 'Architecture v2 R3 identity provisioning passed\n'
