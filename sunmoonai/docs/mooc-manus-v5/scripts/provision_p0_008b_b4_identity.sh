#!/usr/bin/env bash

# Reconcile the isolated Casdoor application used by P0-008B/B4. The default
# mode is plan-only. Client credentials are stored only in Kubernetes Secrets
# and are never printed or written to the repository.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="app-platform-dev"
IDENTITY_SECRET="sunmoonai-p0-008b-b4-identity"
CASDOOR_DATABASE_SECRET="casdoor-postgresql-conn"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
APPLICATION="sunmoonai-tpl-web-b4"
REDIRECT_URI="https://tpl-web-b4.sunmoonai.com:30443/api/auth/callback"
APPLY=false

usage() {
  cat <<'EOF'
Usage: provision_p0_008b_b4_identity.sh [--apply] [options]
  --apply                 Reconcile the Secret and Casdoor application
  --kubeconfig PATH       Kubeconfig path
  --namespace NAME        Target namespace
  --redirect-uri URL      Exact B4 OIDC callback URI
  --client-image IMAGE    PostgreSQL client image
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --redirect-uri) REDIRECT_URI="$2"; shift 2 ;;
    --client-image) POSTGRES_CLIENT_IMAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

secret_value() {
  local key="$1" encoded
  encoded="$(k get secret "$IDENTITY_SECRET" -n "$NAMESPACE" \
    -o "jsonpath={.data.${key}}")"
  printf '%s' "$encoded" | base64 --decode
}

CLIENT_ID=''
CLIENT_SECRET=''

if k get secret "$IDENTITY_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  printf 'PLAN reuse identity Secret: %s/%s\n' "$NAMESPACE" "$IDENTITY_SECRET"
  if [[ "$APPLY" == true ]]; then
    CLIENT_ID="$(secret_value B4_CLIENT_ID)"
    CLIENT_SECRET="$(secret_value B4_CLIENT_SECRET)"
  fi
else
  printf 'PLAN create identity Secret: %s/%s\n' "$NAMESPACE" "$IDENTITY_SECRET"
  if [[ "$APPLY" == true ]]; then
    CLIENT_ID="$(openssl rand -hex 16)"
    CLIENT_SECRET="$(openssl rand -hex 32)"
    k create secret generic "$IDENTITY_SECRET" \
      -n "$NAMESPACE" \
      --from-literal=B4_CLIENT_ID="$CLIENT_ID" \
      --from-literal=B4_CLIENT_SECRET="$CLIENT_SECRET" \
      --dry-run=client -o yaml \
      | k apply -f - >/dev/null
    k label secret "$IDENTITY_SECRET" -n "$NAMESPACE" \
      sunmoonai.com/task=v5-p0-008b-b4 \
      app.kubernetes.io/component=identity-provisioning \
      --overwrite >/dev/null
  fi
fi

printf 'PLAN Casdoor application: %s redirect=%s\n' "$APPLICATION" "$REDIRECT_URI"
[[ "$APPLY" == true ]] || exit 0

[[ "$CLIENT_ID" =~ ^[a-f0-9]{32}$ ]] || {
  printf 'B4_CLIENT_ID is invalid\n' >&2
  exit 1
}
[[ "$CLIENT_SECRET" =~ ^[a-f0-9]{64}$ ]] || {
  printf 'B4_CLIENT_SECRET is invalid\n' >&2
  exit 1
}
[[ "$REDIRECT_URI" =~ ^https://tpl-web-b4\.sunmoonai\.com(:[0-9]+)?/api/auth/callback$ ]] || {
  printf 'redirect URI is outside the B4 trust boundary\n' >&2
  exit 1
}

JOB="p0-008b-b4-identity-provision"
k delete job "$JOB" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null

cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB}
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-008b-b4
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  ttlSecondsAfterFinished: 60
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
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: provision
          image: ${POSTGRES_CLIENT_IMAGE}
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          envFrom:
            - secretRef:
                name: ${IDENTITY_SECRET}
            - secretRef:
                name: ${CASDOOR_DATABASE_SECRET}
          env:
            - name: B4_REDIRECT_URI
              value: "${REDIRECT_URI}"
          command: ["/bin/bash", "-ec"]
          args:
            - |
              export PGPASSWORD="\$APP_DB_PASSWORD"
              psql -h "\$DB_HOST" -p "\$DB_PORT" -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
                -v ON_ERROR_STOP=1 \
                --set=client_id="\$B4_CLIENT_ID" \
                --set=client_secret="\$B4_CLIENT_SECRET" \
                --set=redirect_uri="\$B4_REDIRECT_URI" <<'SQL'
              INSERT INTO application (
                owner, name, created_time, display_name, client_id, client_secret,
                redirect_uris, cert, grant_types, organization, enable_sign_up,
                token_format, expire_in_hours, refresh_expire_in_hours
              ) VALUES (
                'admin', '${APPLICATION}', NOW()::text, 'SunMoon Template Web B4',
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
              printf 'B4 Casdoor application reconciled\n'
EOF

if ! k wait --for=condition=complete "job/${JOB}" -n "$NAMESPACE" --timeout=180s; then
  k logs "job/${JOB}" -n "$NAMESPACE" --tail=120 >&2 || true
  exit 1
fi
k logs "job/${JOB}" -n "$NAMESPACE" --tail=20
k delete job "$JOB" -n "$NAMESPACE" --wait=true >/dev/null
printf 'V5-P0-008B/B4 identity provisioning passed\n'
