#!/usr/bin/env bash

# Verify one Knowledge service-token relation against the real KIND workload.
# The default is the V5-P0-005 ingestion relation; P0-004 reuses the same
# mechanism with ``--relation retrieve``. The short-lived probe keeps provider
# signing material and tokens in memory and prints only statuses.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="app-platform-dev"
CASDOOR_DATABASE_SECRET="casdoor-postgresql-conn"
CALLER_SECRET="info-knowledge-ingest-client"
BINDING_SECRET="knowledge-info-ingest-service-binding"
RELATION="ingest"
TASK_ID="V5-P0-005"
SERVICE_ENDPOINT="http://knowledge-admin-backend:8000/api/internal/v1/knowledge/ingestions"
CALLER_CLIENT_ID_KEY="KNOWLEDGE_APP_SERVICE_CLIENT_ID"
CALLER_CLIENT_SECRET_KEY="KNOWLEDGE_APP_SERVICE_CLIENT_SECRET"
CALLER_DISCOVERY_KEY="KNOWLEDGE_APP_SERVICE_DISCOVERY_URL"
CALLER_BACKCHANNEL_KEY="KNOWLEDGE_APP_SERVICE_BACKCHANNEL_ENDPOINT"
BINDING_AUDIENCE_KEY="INTERNAL_AUTH_AUDIENCE"
BINDING_SUBJECTS_KEY="INTERNAL_AUTH_SUBJECT_ALLOWLIST"
BINDING_SCOPE_KEY="INTERNAL_AUTH_REQUIRED_SCOPE"
PROBE_IMAGE=""
RUN=false

usage() {
    cat <<'EOF'
Usage: verify_p0_005_service_negative_matrix.sh [--run] [options]

  --run                 Create the ephemeral verifier Job (default: plan only)
  --relation NAME       ingest (default) or retrieve
  --kubeconfig PATH     Kubeconfig path
  --namespace NAME      Application namespace
  --probe-image IMAGE   Backend image containing asyncpg, httpx and joserfc
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run) RUN=true; shift ;;
        --relation) RELATION="$2"; shift 2 ;;
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        --namespace) APP_NAMESPACE="$2"; shift 2 ;;
        --probe-image) PROBE_IMAGE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

case "$RELATION" in
    ingest) ;;
    retrieve)
        CALLER_SECRET="research-knowledge-retrieval-client"
        BINDING_SECRET="knowledge-research-retrieval-service-binding"
        TASK_ID="V5-P0-004"
        SERVICE_ENDPOINT="http://knowledge-admin-backend:8000/api/internal/v1/knowledge/retrievals"
        CALLER_CLIENT_ID_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID"
        CALLER_CLIENT_SECRET_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET"
        CALLER_DISCOVERY_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL"
        CALLER_BACKCHANNEL_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT"
        BINDING_AUDIENCE_KEY="RETRIEVAL_AUTH_AUDIENCE"
        BINDING_SUBJECTS_KEY="RETRIEVAL_AUTH_SUBJECT_ALLOWLIST"
        BINDING_SCOPE_KEY="RETRIEVAL_AUTH_REQUIRED_SCOPE"
        ;;
    *)
        echo "unsupported relation: $RELATION" >&2
        exit 2
        ;;
esac

k() { kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"; }

job="p0-${TASK_ID##*-}-service-negative-matrix"

cleanup() {
    k delete job "$job" -n "$APP_NAMESPACE" --ignore-not-found=true \
        --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_job() {
    local deadline=$((SECONDS + 180)) succeeded failed
    while [[ $SECONDS -lt $deadline ]]; do
        succeeded="$(k get job "$job" -n "$APP_NAMESPACE" \
            -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
        failed="$(k get job "$job" -n "$APP_NAMESPACE" \
            -o jsonpath='{.status.failed}' 2>/dev/null || true)"
        [[ "$succeeded" == "1" ]] && return 0
        [[ -n "$failed" && "$failed" != "0" ]] && return 1
        sleep 2
    done
    return 1
}

command -v kubectl >/dev/null 2>&1 || {
    echo "missing: kubectl" >&2
    exit 1
}

k get namespace "$APP_NAMESPACE" >/dev/null
for secret in "$CASDOOR_DATABASE_SECRET" "$CALLER_SECRET" "$BINDING_SECRET"; do
    k get secret "$secret" -n "$APP_NAMESPACE" >/dev/null
done

if [[ -z "$PROBE_IMAGE" ]]; then
    PROBE_IMAGE="$(k get deployment knowledge-admin-backend -n "$APP_NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].image}')"
fi
[[ -n "$PROBE_IMAGE" ]] || {
    echo "cannot resolve Knowledge probe image" >&2
    exit 1
}

echo "PLAN ephemeral Job: $APP_NAMESPACE/$job"
echo "PLAN control: valid provider-signed JWT reaches request validation (HTTP 422)"
echo "PLAN rejection cases: expired, wrong audience, wrong issuer, unbound subject, malformed scope, forged signature"
echo "PLAN output policy: statuses only; no token, credential, certificate or private key"
[[ "$RUN" == "true" ]] || {
    echo "PLAN ONLY: rerun with --run"
    exit 0
}

cleanup
k wait --for=delete "job/$job" -n "$APP_NAMESPACE" --timeout=60s \
    >/dev/null 2>&1 || true

cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: ${TASK_ID,,}
    app.kubernetes.io/component: service-token-negative-matrix
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  ttlSecondsAfterFinished: 300
  template:
    metadata:
      labels:
        sunmoonai.com/task: ${TASK_ID,,}
        app.kubernetes.io/component: service-token-negative-matrix
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: verify
        image: ${PROBE_IMAGE}
        imagePullPolicy: IfNotPresent
        env:
        - name: DB_HOST
          valueFrom: {secretKeyRef: {name: ${CASDOOR_DATABASE_SECRET}, key: DB_HOST}}
        - name: DB_PORT
          valueFrom: {secretKeyRef: {name: ${CASDOOR_DATABASE_SECRET}, key: DB_PORT}}
        - name: DB_NAME
          valueFrom: {secretKeyRef: {name: ${CASDOOR_DATABASE_SECRET}, key: APP_DB_NAME}}
        - name: DB_USER
          valueFrom: {secretKeyRef: {name: ${CASDOOR_DATABASE_SECRET}, key: APP_DB_USER}}
        - name: DB_PASSWORD
          valueFrom: {secretKeyRef: {name: ${CASDOOR_DATABASE_SECRET}, key: APP_DB_PASSWORD}}
        - name: SERVICE_CLIENT_ID
          valueFrom: {secretKeyRef: {name: ${CALLER_SECRET}, key: ${CALLER_CLIENT_ID_KEY}}}
        - name: SERVICE_CLIENT_SECRET
          valueFrom: {secretKeyRef: {name: ${CALLER_SECRET}, key: ${CALLER_CLIENT_SECRET_KEY}}}
        - name: SERVICE_DISCOVERY_URL
          valueFrom: {secretKeyRef: {name: ${CALLER_SECRET}, key: ${CALLER_DISCOVERY_KEY}}}
        - name: SERVICE_BACKCHANNEL_ENDPOINT
          valueFrom: {secretKeyRef: {name: ${CALLER_SECRET}, key: ${CALLER_BACKCHANNEL_KEY}}}
        - name: EXPECTED_AUDIENCE
          valueFrom: {secretKeyRef: {name: ${BINDING_SECRET}, key: ${BINDING_AUDIENCE_KEY}}}
        - name: EXPECTED_SUBJECTS
          valueFrom: {secretKeyRef: {name: ${BINDING_SECRET}, key: ${BINDING_SUBJECTS_KEY}}}
        - name: EXPECTED_SCOPE
          valueFrom: {secretKeyRef: {name: ${BINDING_SECRET}, key: ${BINDING_SCOPE_KEY}}}
        command: ["/bin/sh", "-ec"]
        args:
        - |
          cd /app
          .venv/bin/python - <<'PY'
          import asyncio
          import base64
          import json
          import os
          import time
          from urllib.parse import urlsplit, urlunsplit

          import asyncpg
          import httpx
          from joserfc import jwt
          from joserfc.jwk import RSAKey

          ENDPOINT = "${SERVICE_ENDPOINT}"

          def decode_header(encoded: str) -> dict:
              segment = encoded.split(".", 1)[0]
              segment += "=" * (-len(segment) % 4)
              value = json.loads(base64.urlsafe_b64decode(segment).decode())
              if not isinstance(value, dict) or value.get("alg") != "RS256":
                  raise RuntimeError("real service token header is not RS256")
              return value

          def routed(url: str, public_origin: str, backchannel: str) -> str:
              parsed = urlsplit(url)
              public = urlsplit(public_origin)
              internal = urlsplit(backchannel)
              if (parsed.scheme, parsed.netloc) != (public.scheme, public.netloc):
                  raise RuntimeError("provider metadata escaped canonical origin")
              return urlunsplit(
                  (internal.scheme, internal.netloc, parsed.path, parsed.query, "")
              )

          async def main() -> None:
              discovery_url = os.environ["SERVICE_DISCOVERY_URL"]
              public_parts = urlsplit(discovery_url)
              public_origin = urlunsplit(
                  (public_parts.scheme, public_parts.netloc, "", "", "")
              ).rstrip("/")
              backchannel = os.environ["SERVICE_BACKCHANNEL_ENDPOINT"].rstrip("/")
              expected_audience = os.environ["EXPECTED_AUDIENCE"]
              if expected_audience != os.environ["SERVICE_CLIENT_ID"]:
                  raise RuntimeError("caller and resource audience binding diverged")
              expected_subject = next(
                  (
                      item.strip()
                      for item in os.environ["EXPECTED_SUBJECTS"].split(",")
                      if item.strip()
                  ),
                  "",
              )
              if not expected_subject:
                  raise RuntimeError("resource subject binding is empty")

              connection = await asyncpg.connect(
                  host=os.environ["DB_HOST"],
                  port=int(os.environ["DB_PORT"]),
                  database=os.environ["DB_NAME"],
                  user=os.environ["DB_USER"],
                  password=os.environ["DB_PASSWORD"],
              )
              try:
                  private_pem = await connection.fetchval(
                      # The surrounding Job manifest uses an unquoted shell
                      # heredoc so that deployment values are interpolated.
                      # Escape PostgreSQL positional parameters here; otherwise
                      # bash expands \$1/\$2 while rendering the manifest under
                      # `set -u` and aborts before the Job is created.
                      "SELECT private_key FROM cert WHERE owner=\$1 AND name=\$2",
                      "admin",
                      "cert-built-in",
                  )
              finally:
                  await connection.close()
              if not isinstance(private_pem, str) or "PRIVATE KEY" not in private_pem:
                  raise RuntimeError("provider signing key is unavailable")

              provider_key = RSAKey.import_key(private_pem)
              headers = {"Accept": "application/json", "Host": public_parts.netloc}
              async with httpx.AsyncClient(timeout=15, follow_redirects=False) as client:
                  metadata_response = await client.get(
                      f"{backchannel}/.well-known/openid-configuration",
                      headers=headers,
                  )
                  metadata_response.raise_for_status()
                  metadata = metadata_response.json()
                  if metadata.get("issuer", "").rstrip("/") != public_origin:
                      raise RuntimeError("provider issuer differs from resource binding")
                  token_response = await client.post(
                      routed(metadata["token_endpoint"], public_origin, backchannel),
                      data={
                          "grant_type": "client_credentials",
                          "client_id": os.environ["SERVICE_CLIENT_ID"],
                          "client_secret": os.environ["SERVICE_CLIENT_SECRET"],
                          "scope": os.environ["EXPECTED_SCOPE"],
                      },
                      headers=headers,
                  )
                  token_response.raise_for_status()
                  real_token = token_response.json().get("access_token")
                  if not isinstance(real_token, str) or not real_token:
                      raise RuntimeError("provider did not issue a service token")
                  real_header = decode_header(real_token)
                  signing_header = {"alg": "RS256"}
                  if isinstance(real_header.get("kid"), str):
                      signing_header["kid"] = real_header["kid"]

                  now = int(time.time())
                  base_claims = {
                      "iss": public_origin,
                      "sub": expected_subject,
                      "aud": expected_audience,
                      "iat": now,
                      "exp": now + 300,
                      "scope": os.environ["EXPECTED_SCOPE"],
                  }

                  def signed(overrides: dict, key: RSAKey = provider_key) -> str:
                      claims = dict(base_claims)
                      claims.update(overrides)
                      return jwt.encode(
                          signing_header,
                          claims,
                          key,
                          algorithms=["RS256"],
                      )

                  attacker = RSAKey.generate_key(
                      key_size=2048,
                      parameters={"kid": signing_header.get("kid", "forged-key")},
                  )
                  cases = {
                      "valid_control": (signed({}), 422),
                      "expired": (signed({"iat": now - 600, "exp": now - 300}), 401),
                      "wrong_audience": (signed({"aud": "p0-wrong-audience"}), 401),
                      "wrong_issuer": (signed({"iss": f"{public_origin}/wrong"}), 401),
                      "unbound_subject": (signed({"sub": "p0-unbound-service"}), 403),
                      "malformed_scope": (signed({"scope": 42}), 401),
                      "forged_signature": (signed({}, attacker), 401),
                  }
                  statuses = {}
                  for name, (encoded, expected) in cases.items():
                      response = await client.post(
                          ENDPOINT,
                          headers={"Authorization": f"Bearer {encoded}"},
                          json={},
                      )
                      statuses[name] = response.status_code
                      if response.status_code != expected:
                          raise RuntimeError(
                              f"{name} returned {response.status_code}; expected {expected}"
                          )

              private_pem = ""
              real_token = ""
              print(json.dumps({
                  "task": "${TASK_ID}-service-negative-matrix",
                  "result": "passed",
                  "statuses": statuses,
                  "token_printed": False,
                  "credentials_printed": False,
                  "provider_private_key_printed": False,
                  "service_account_token_mounted": False,
              }, separators=(",", ":")))

          try:
              asyncio.run(main())
          except Exception as exc:
              print(json.dumps({
                  "task": "${TASK_ID}-service-negative-matrix",
                  "result": "failed",
                  "reason": type(exc).__name__,
                  "token_printed": False,
                  "credentials_printed": False,
                  "provider_private_key_printed": False,
              }, separators=(",", ":")))
              raise SystemExit(1) from None
          PY
EOF

if ! wait_job; then
    k logs "job/$job" -n "$APP_NAMESPACE" --all-containers=true || true
    echo "$TASK_ID service negative matrix failed" >&2
    exit 1
fi

k logs "job/$job" -n "$APP_NAMESPACE"
echo "$TASK_ID service negative matrix passed"
