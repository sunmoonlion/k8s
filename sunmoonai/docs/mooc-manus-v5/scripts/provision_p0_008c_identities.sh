#!/usr/bin/env bash

# Provision the isolated browser identity and Web-BFF -> Runtime service
# identity for P0-008C. Tokens and client secrets are never printed.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
NAMESPACE="app-platform-dev"
PUBLIC_PORT="30443"
HOST="research-web-p0-008c.sunmoonai.com"
MODE="plan"
PROBE_IMAGE=""

BROWSER_SECRET="sunmoonai-p0-008c-web-identity"
RUNTIME_CALLER_SECRET="sunmoonai-p0-008c-runtime-caller"
RUNTIME_BINDING_SECRET="sunmoonai-p0-008c-runtime-binding"
CASDOOR_DATABASE_SECRET="casdoor-postgresql-conn"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
BROWSER_APPLICATION="sunmoonai-research-web-p0-008c"
RUNTIME_APPLICATION="sunmoonai-research-runtime-p0-008c"
RUNTIME_SCOPE="research:runtime"
PUBLIC_CASDOOR_ENDPOINT="https://casdoor.sunmoonai.com:${PUBLIC_PORT}"
BACKCHANNEL_CASDOOR_ENDPOINT="http://casdoor-sunmoonai:8000"

usage() {
  cat <<'EOF'
Usage: provision_p0_008c_identities.sh [--apply|--cleanup] [options]

  --apply               Reconcile both Casdoor applications and Secrets
  --cleanup             Delete only P0-008C applications and Secrets
  --probe-image DIGEST  Runtime image@sha256 used for signed-token validation
  --kubeconfig PATH
  --namespace NAME
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) MODE="apply"; shift ;;
    --cleanup) MODE="cleanup"; shift ;;
    --probe-image) PROBE_IMAGE="$2"; shift 2 ;;
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

k() { env -u DEBUG "$KUBECTL_BIN" --kubeconfig "$KUBECONFIG_PATH" "$@"; }

wait_job() {
  local job="$1"
  if ! k wait --for=condition=complete "job/${job}" \
    -n "$NAMESPACE" --timeout=180s; then
    k logs "job/${job}" -n "$NAMESPACE" --all-containers=true --tail=100 >&2 || true
    return 1
  fi
}

delete_job() {
  k delete job "$1" -n "$NAMESPACE" \
    --ignore-not-found=true --wait=true >/dev/null
}

delete_applications() {
  local job="p0-008c-identity-delete"
  delete_job "$job"
  cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: v5-p0-008c}
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels: {sunmoonai.com/task: v5-p0-008c}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: delete
          image: ${POSTGRES_CLIENT_IMAGE}
          envFrom:
            - secretRef: {name: ${CASDOOR_DATABASE_SECRET}}
          command: ["/bin/bash", "-ec"]
          args:
            - |
              export PGPASSWORD="\$APP_DB_PASSWORD"
              psql -h "\$DB_HOST" -p "\$DB_PORT" \
                -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
                -q -v ON_ERROR_STOP=1 \
                -c "DELETE FROM application WHERE owner='admin' AND name IN ('${BROWSER_APPLICATION}','${RUNTIME_APPLICATION}')"
              unset PGPASSWORD
              printf 'P0-008C Casdoor applications removed\n'
EOF
  wait_job "$job"
  delete_job "$job"
}

if [[ "$MODE" == "cleanup" ]]; then
  k get secret "$CASDOOR_DATABASE_SECRET" -n "$NAMESPACE" >/dev/null
  delete_applications
  k delete secret "$BROWSER_SECRET" "$RUNTIME_CALLER_SECRET" \
    "$RUNTIME_BINDING_SECRET" -n "$NAMESPACE" \
    --ignore-not-found=true >/dev/null
  printf 'V5-P0-008C identities cleaned\n'
  exit 0
fi

printf 'PLAN browser=%s runtime-service=%s namespace=%s\n' \
  "$BROWSER_APPLICATION" "$RUNTIME_APPLICATION" "$NAMESPACE"
[[ "$MODE" == "apply" ]] || exit 0

[[ "$HOST" == "research-web-p0-008c.sunmoonai.com" ]] || {
  printf 'host is outside the P0-008C trust boundary\n' >&2
  exit 1
}
[[ "$PROBE_IMAGE" =~ @sha256:[a-f0-9]{64}$ ]] || {
  printf -- '--probe-image must be an immutable Runtime digest reference\n' >&2
  exit 1
}
k get namespace "$NAMESPACE" >/dev/null
k get secret "$CASDOOR_DATABASE_SECRET" -n "$NAMESPACE" >/dev/null
k get secret harbor-registry-secret -n "$NAMESPACE" >/dev/null

if ! k get secret "$BROWSER_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  browser_client_id="$(openssl rand -hex 16)"
  browser_client_secret="$(openssl rand -hex 32)"
  k create secret generic "$BROWSER_SECRET" -n "$NAMESPACE" \
    --from-literal=CLIENT_ID="$browser_client_id" \
    --from-literal=CLIENT_SECRET="$browser_client_secret" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  unset browser_client_id browser_client_secret
fi

if ! k get secret "$RUNTIME_CALLER_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  runtime_client_id="$(openssl rand -hex 16)"
  runtime_client_secret="$(openssl rand -hex 32)"
  k create secret generic "$RUNTIME_CALLER_SECRET" -n "$NAMESPACE" \
    --from-literal=CLIENT_ID="$runtime_client_id" \
    --from-literal=CLIENT_SECRET="$runtime_client_secret" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  unset runtime_client_id runtime_client_secret
fi

k label secret "$BROWSER_SECRET" "$RUNTIME_CALLER_SECRET" \
  -n "$NAMESPACE" sunmoonai.com/task=v5-p0-008c --overwrite >/dev/null

job="p0-008c-identity-provision"
delete_job "$job"
cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: v5-p0-008c}
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels: {sunmoonai.com/task: v5-p0-008c}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: provision
          image: ${POSTGRES_CLIENT_IMAGE}
          envFrom:
            - secretRef: {name: ${CASDOOR_DATABASE_SECRET}}
          env:
            - name: BROWSER_CLIENT_ID
              valueFrom: {secretKeyRef: {name: ${BROWSER_SECRET}, key: CLIENT_ID}}
            - name: BROWSER_CLIENT_SECRET
              valueFrom: {secretKeyRef: {name: ${BROWSER_SECRET}, key: CLIENT_SECRET}}
            - name: RUNTIME_CLIENT_ID
              valueFrom: {secretKeyRef: {name: ${RUNTIME_CALLER_SECRET}, key: CLIENT_ID}}
            - name: RUNTIME_CLIENT_SECRET
              valueFrom: {secretKeyRef: {name: ${RUNTIME_CALLER_SECRET}, key: CLIENT_SECRET}}
          command: ["/bin/bash", "-ec"]
          args:
            - |
              test "\${#BROWSER_CLIENT_ID}" -eq 32
              test "\${#BROWSER_CLIENT_SECRET}" -eq 64
              test "\${#RUNTIME_CLIENT_ID}" -eq 32
              test "\${#RUNTIME_CLIENT_SECRET}" -eq 64
              export PGPASSWORD="\$APP_DB_PASSWORD"
              psql -h "\$DB_HOST" -p "\$DB_PORT" \
                -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
                -q -v ON_ERROR_STOP=1 \
                --set=browser_client_id="\$BROWSER_CLIENT_ID" \
                --set=browser_client_secret="\$BROWSER_CLIENT_SECRET" \
                --set=runtime_client_id="\$RUNTIME_CLIENT_ID" \
                --set=runtime_client_secret="\$RUNTIME_CLIENT_SECRET" <<'SQL'
              INSERT INTO application (
                owner, name, created_time, display_name, client_id, client_secret,
                redirect_uris, cert, grant_types, organization, enable_sign_up,
                token_format, expire_in_hours, refresh_expire_in_hours
              ) VALUES (
                'admin', '${BROWSER_APPLICATION}', NOW()::text,
                'Research Web P0-008C', :'browser_client_id',
                :'browser_client_secret',
                '["https://${HOST}:${PUBLIC_PORT}/api/auth/callback"]',
                'cert-built-in', '["authorization_code"]', 'sunmoonai', false,
                'JWT', 1, 24
              ) ON CONFLICT (owner, name) DO UPDATE SET
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
              WHERE owner='admin' AND name='${BROWSER_APPLICATION}';

              INSERT INTO application (
                owner, name, created_time, display_name, client_id, client_secret,
                redirect_uris, cert, grant_types, organization, enable_sign_up,
                token_format, expire_in_hours, refresh_expire_in_hours
              ) VALUES (
                'admin', '${RUNTIME_APPLICATION}', NOW()::text,
                'Research Runtime P0-008C', :'runtime_client_id',
                :'runtime_client_secret', '[]', 'cert-built-in',
                '["client_credentials"]', 'sunmoonai', false, 'JWT', 1, 1
              ) ON CONFLICT (owner, name) DO UPDATE SET
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

              SELECT 1 / CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END
              FROM application
              WHERE owner='admin'
                AND name IN ('${BROWSER_APPLICATION}','${RUNTIME_APPLICATION}');
              SQL
              unset PGPASSWORD
              printf 'P0-008C Casdoor applications reconciled\n'
EOF
wait_job "$job"
delete_job "$job"

probe_job="p0-008c-runtime-token-probe"
delete_job "$probe_job"
cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${probe_job}
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: v5-p0-008c}
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels: {sunmoonai.com/task: v5-p0-008c}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
        - name: harbor-registry-secret
      containers:
        - name: probe
          image: ${PROBE_IMAGE}
          env:
            - name: CLIENT_ID
              valueFrom: {secretKeyRef: {name: ${RUNTIME_CALLER_SECRET}, key: CLIENT_ID}}
            - name: CLIENT_SECRET
              valueFrom: {secretKeyRef: {name: ${RUNTIME_CALLER_SECRET}, key: CLIENT_SECRET}}
          command: ["/bin/sh", "-ec"]
          args:
            - |
              cd /app
              .venv/bin/python - <<'PY'
              import asyncio
              import base64
              import os
              from urllib.parse import urlsplit, urlunsplit

              import httpx
              from joserfc import jwt
              from joserfc.jwk import KeySet
              from joserfc.jwt import JWTClaimsRegistry

              public = "${PUBLIC_CASDOOR_ENDPOINT}"
              backchannel = "${BACKCHANNEL_CASDOOR_ENDPOINT}"
              public_parts = urlsplit(public)
              backchannel_parts = urlsplit(backchannel)
              headers = {"Accept": "application/json", "Host": public_parts.netloc}

              def routed(url: str) -> str:
                  parsed = urlsplit(url)
                  if parsed.netloc != public_parts.netloc:
                      raise RuntimeError("provider metadata escaped canonical origin")
                  return urlunsplit((
                      backchannel_parts.scheme,
                      backchannel_parts.netloc,
                      parsed.path,
                      parsed.query,
                      "",
                  ))

              async def main() -> None:
                  async with httpx.AsyncClient(timeout=15, follow_redirects=False) as client:
                      discovery = await client.get(
                          f"{backchannel}/.well-known/openid-configuration",
                          headers=headers,
                      )
                      discovery.raise_for_status()
                      metadata = discovery.json()
                      response = await client.post(
                          routed(metadata["token_endpoint"]),
                          data={
                              "grant_type": "client_credentials",
                              "client_id": os.environ["CLIENT_ID"],
                              "client_secret": os.environ["CLIENT_SECRET"],
                              "scope": "${RUNTIME_SCOPE}",
                          },
                          headers=headers,
                      )
                      response.raise_for_status()
                      encoded = response.json()["access_token"]
                      keys = await client.get(routed(metadata["jwks_uri"]), headers=headers)
                      keys.raise_for_status()
                  claims = jwt.decode(
                      encoded,
                      KeySet.import_key_set(keys.json()),
                      algorithms=["RS256"],
                  ).claims
                  JWTClaimsRegistry(
                      iss={"essential": True, "value": metadata["issuer"]},
                      sub={"essential": True},
                      aud={"essential": True, "value": os.environ["CLIENT_ID"]},
                      exp={"essential": True},
                      iat={"essential": True},
                  ).validate(claims)
                  subject = claims["sub"]
                  if not isinstance(subject, str) or not subject:
                      raise RuntimeError("service subject is unavailable")
                  print("P0_SUBJECT_B64=" + base64.b64encode(subject.encode()).decode())
                  print("P0-008C service token signature/audience/subject passed")

              asyncio.run(main())
              PY
EOF
wait_job "$probe_job"
probe_logs="$(k logs "job/${probe_job}" -n "$NAMESPACE")"
subject_b64="$(printf '%s\n' "$probe_logs" | sed -n 's/^P0_SUBJECT_B64=//p' | tail -n 1)"
[[ "$subject_b64" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] || {
  printf 'service token probe returned no valid subject\n' >&2
  exit 1
}
verified_subject="$(printf '%s' "$subject_b64" | base64 --decode)"
[[ "$verified_subject" =~ ^[A-Za-z0-9._:@/-]{1,256}$ ]] || {
  printf 'service token subject has an unsupported format\n' >&2
  exit 1
}
printf '%s\n' "$probe_logs" | sed '/^P0_SUBJECT_B64=/d'
delete_job "$probe_job"

runtime_client_id="$(
  k get secret "$RUNTIME_CALLER_SECRET" -n "$NAMESPACE" \
    -o jsonpath='{.data.CLIENT_ID}' | base64 --decode
)"
cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${RUNTIME_BINDING_SECRET}
  namespace: ${NAMESPACE}
  labels: {sunmoonai.com/task: v5-p0-008c}
type: Opaque
stringData:
  AGENT_PILOT_INTERNAL_AUTH_APPLICATION: "${RUNTIME_APPLICATION}"
  AGENT_PILOT_INTERNAL_AUTH_DISCOVERY_URL: "${PUBLIC_CASDOOR_ENDPOINT}/.well-known/openid-configuration"
  AGENT_PILOT_INTERNAL_AUTH_BACKCHANNEL_ENDPOINT: "${BACKCHANNEL_CASDOOR_ENDPOINT}"
  AGENT_PILOT_INTERNAL_AUTH_AUDIENCE: "${runtime_client_id}"
  AGENT_PILOT_INTERNAL_AUTH_SUBJECTS: "${verified_subject}"
  AGENT_PILOT_INTERNAL_AUTH_REQUIRED_SCOPE: "${RUNTIME_SCOPE}"
EOF
unset runtime_client_id verified_subject subject_b64 probe_logs
printf 'V5-P0-008C browser and Runtime identities reconciled without printing credentials\n'
