#!/usr/bin/env bash

# Reconcile the Info distribution worker -> Knowledge ingestion service
# identity for V5-P0-005. Default mode is plan-only. Credentials and tokens
# are never printed, written to generated YAML, or passed in command arguments.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="app-platform-dev"
OPERATOR_SECRET="sunmoonai-p0-005-service-identity"
CALLER_SECRET="info-knowledge-ingest-client"
BINDING_SECRET="knowledge-info-ingest-service-binding"
CASDOOR_DATABASE_SECRET="casdoor-postgresql-conn"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
PUBLIC_CASDOOR_ENDPOINT="https://casdoor.sunmoonai.com:30443"
BACKCHANNEL_CASDOOR_ENDPOINT="http://casdoor-sunmoonai:8000"
SERVICE_APPLICATION="sunmoonai-info-knowledge-ingest"
SERVICE_DISPLAY_NAME="SunMoon Info to Knowledge Ingest"
SERVICE_SCOPE="knowledge:ingest"
RELATION="ingest"
TASK_ID="v5-p0-005"
CALLER_NAME="info-distribution-worker"
RELATION_LABEL="info-knowledge-ingest"
CALLER_CLIENT_ID_KEY="KNOWLEDGE_APP_SERVICE_CLIENT_ID"
CALLER_CLIENT_SECRET_KEY="KNOWLEDGE_APP_SERVICE_CLIENT_SECRET"
CALLER_DISCOVERY_KEY="KNOWLEDGE_APP_SERVICE_DISCOVERY_URL"
CALLER_BACKCHANNEL_KEY="KNOWLEDGE_APP_SERVICE_BACKCHANNEL_ENDPOINT"
BINDING_APPLICATION_KEY="INTERNAL_AUTH_CASDOOR_APPLICATION"
BINDING_DISCOVERY_KEY="INTERNAL_AUTH_DISCOVERY_URL"
BINDING_BACKCHANNEL_KEY="INTERNAL_AUTH_BACKCHANNEL_ENDPOINT"
BINDING_AUDIENCE_KEY="INTERNAL_AUTH_AUDIENCE"
BINDING_SUBJECTS_KEY="INTERNAL_AUTH_SUBJECT_ALLOWLIST"
BINDING_SCOPE_KEY="INTERNAL_AUTH_REQUIRED_SCOPE"
PROBE_IMAGE=""
APPLY=false

usage() {
    cat <<'EOF'
Usage: provision_p0_005_service_identity.sh [--apply] [options]

  --apply                     Reconcile Casdoor and Secrets (default: plan only)
  --relation NAME             ingest (default), retrieve (legacy Research), or investment-retrieve
  --kubeconfig PATH           Kubeconfig path
  --namespace NAME            Application namespace
  --public-endpoint URL       Canonical public Casdoor origin
  --backchannel-endpoint URL  Fixed in-cluster Casdoor transport origin
  --client-image IMAGE        PostgreSQL client image
  --probe-image IMAGE         Python backend image containing httpx + joserfc
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=true; shift ;;
        --relation) RELATION="$2"; shift 2 ;;
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        --namespace) APP_NAMESPACE="$2"; shift 2 ;;
        --public-endpoint) PUBLIC_CASDOOR_ENDPOINT="$2"; shift 2 ;;
        --backchannel-endpoint) BACKCHANNEL_CASDOOR_ENDPOINT="$2"; shift 2 ;;
        --client-image) POSTGRES_CLIENT_IMAGE="$2"; shift 2 ;;
        --probe-image) PROBE_IMAGE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

case "$RELATION" in
    ingest) ;;
    retrieve)
        OPERATOR_SECRET="sunmoonai-p0-004-retrieval-identity"
        CALLER_SECRET="research-knowledge-retrieval-client"
        BINDING_SECRET="knowledge-research-retrieval-service-binding"
        SERVICE_APPLICATION="sunmoonai-research-knowledge-retrieve"
        SERVICE_DISPLAY_NAME="SunMoon Research to Knowledge Retrieval"
        SERVICE_SCOPE="knowledge:retrieve"
        TASK_ID="v5-p0-004"
        CALLER_NAME="research-knowledge-retrieval-worker"
        RELATION_LABEL="research-knowledge-retrieve"
        CALLER_CLIENT_ID_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID"
        CALLER_CLIENT_SECRET_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET"
        CALLER_DISCOVERY_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL"
        CALLER_BACKCHANNEL_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT"
        BINDING_APPLICATION_KEY="RETRIEVAL_AUTH_CASDOOR_APPLICATION"
        BINDING_DISCOVERY_KEY="RETRIEVAL_AUTH_DISCOVERY_URL"
        BINDING_BACKCHANNEL_KEY="RETRIEVAL_AUTH_BACKCHANNEL_ENDPOINT"
        BINDING_AUDIENCE_KEY="RETRIEVAL_AUTH_AUDIENCE"
        BINDING_SUBJECTS_KEY="RETRIEVAL_AUTH_SUBJECT_ALLOWLIST"
        BINDING_SCOPE_KEY="RETRIEVAL_AUTH_REQUIRED_SCOPE"
        ;;
    investment-retrieve)
        OPERATOR_SECRET="sunmoonai-r5-investment-retrieval-identity"
        CALLER_SECRET="investment-knowledge-retrieval-client"
        BINDING_SECRET="knowledge-investment-retrieval-service-binding"
        SERVICE_APPLICATION="sunmoonai-investment-knowledge-retrieve"
        SERVICE_DISPLAY_NAME="SunMoon Investment to Knowledge Retrieval"
        SERVICE_SCOPE="knowledge:retrieve"
        TASK_ID="r5-investment-retrieval"
        CALLER_NAME="investment-backend-worker"
        RELATION_LABEL="investment-knowledge-retrieve"
        CALLER_CLIENT_ID_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_ID"
        CALLER_CLIENT_SECRET_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_CLIENT_SECRET"
        CALLER_DISCOVERY_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL"
        CALLER_BACKCHANNEL_KEY="KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT"
        BINDING_APPLICATION_KEY="RETRIEVAL_AUTH_CASDOOR_APPLICATION"
        BINDING_DISCOVERY_KEY="RETRIEVAL_AUTH_DISCOVERY_URL"
        BINDING_BACKCHANNEL_KEY="RETRIEVAL_AUTH_BACKCHANNEL_ENDPOINT"
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

secret_value() {
    local secret="$1" key="$2" encoded
    encoded="$(k get secret "$secret" -n "$APP_NAMESPACE" \
        -o "jsonpath={.data.${key}}" 2>/dev/null || true)"
    [[ -n "$encoded" ]] || return 1
    printf '%s' "$encoded" | base64 --decode
}

wait_job() {
    local job="$1" deadline=$((SECONDS + 180)) succeeded failed
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

cleanup_job() {
    k delete job "$1" -n "$APP_NAMESPACE" --ignore-not-found=true \
        --wait=false >/dev/null 2>&1 || true
}

SERVICE_CLIENT_ID=""
SERVICE_CLIENT_SECRET=""
VERIFIED_SUBJECT=""

load_or_create_operator_secret() {
    if k get secret "$OPERATOR_SECRET" -n "$APP_NAMESPACE" >/dev/null 2>&1; then
        echo "PLAN reuse operator Secret: $APP_NAMESPACE/$OPERATOR_SECRET"
        [[ "$APPLY" == "true" ]] || return 0
        SERVICE_CLIENT_ID="$(secret_value "$OPERATOR_SECRET" SERVICE_CLIENT_ID)"
        SERVICE_CLIENT_SECRET="$(secret_value "$OPERATOR_SECRET" SERVICE_CLIENT_SECRET)"
        return 0
    fi

    echo "PLAN create operator Secret: $APP_NAMESPACE/$OPERATOR_SECRET"
    [[ "$APPLY" == "true" ]] || return 0
    SERVICE_CLIENT_ID="$(openssl rand -hex 16)"
    SERVICE_CLIENT_SECRET="$(openssl rand -hex 32)"
    cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${OPERATOR_SECRET}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: ${TASK_ID}
    app.kubernetes.io/component: service-identity-provisioning
type: Opaque
stringData:
  SERVICE_CLIENT_ID: "${SERVICE_CLIENT_ID}"
  SERVICE_CLIENT_SECRET: "${SERVICE_CLIENT_SECRET}"
EOF
}

validate_credentials() {
    [[ "$SERVICE_CLIENT_ID" =~ ^[a-f0-9]{32}$ ]] || {
        echo "service client ID is not a generated 32-character hex value" >&2
        exit 1
    }
    [[ "$SERVICE_CLIENT_SECRET" =~ ^[a-f0-9]{64}$ ]] || {
        echo "service client secret is not a generated 64-character hex value" >&2
        exit 1
    }
}

reconcile_casdoor_application() {
    local job="p0-${TASK_ID##*-}-service-identity-provision"
    cleanup_job "$job"
    k wait --for=delete "job/$job" -n "$APP_NAMESPACE" --timeout=60s \
        >/dev/null 2>&1 || true
    cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: ${TASK_ID}
    app.kubernetes.io/component: service-identity-provisioning
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        sunmoonai.com/task: ${TASK_ID}
        app.kubernetes.io/component: service-identity-provisioning
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: provision
        image: ${POSTGRES_CLIENT_IMAGE}
        imagePullPolicy: IfNotPresent
        env:
        - name: SERVICE_CLIENT_ID
          valueFrom: {secretKeyRef: {name: ${OPERATOR_SECRET}, key: SERVICE_CLIENT_ID}}
        - name: SERVICE_CLIENT_SECRET
          valueFrom: {secretKeyRef: {name: ${OPERATOR_SECRET}, key: SERVICE_CLIENT_SECRET}}
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
        command: ["/bin/bash", "-ec"]
        args:
        - |
          set -euo pipefail
          export PGPASSWORD="\$DB_PASSWORD"
          psql -h "\$DB_HOST" -p "\$DB_PORT" -U "\$DB_USER" -d "\$DB_NAME" \
            -q -v ON_ERROR_STOP=1 \
            --set=client_id="\$SERVICE_CLIENT_ID" \
            --set=client_secret="\$SERVICE_CLIENT_SECRET" \
            --set=service_application="${SERVICE_APPLICATION}" \
            --set=service_display_name="${SERVICE_DISPLAY_NAME}" <<'SQL'
          SELECT count(*) = 1 AS organization_ok FROM organization
          WHERE owner='admin' AND name='sunmoonai' \gset
          \if :organization_ok
          \else
            \echo 'required Casdoor organization is unavailable'
            \quit 1
          \endif

          INSERT INTO application (
            owner, name, created_time, display_name, client_id, client_secret,
            redirect_uris, cert, grant_types, organization, enable_sign_up,
            token_format, expire_in_hours, refresh_expire_in_hours
          ) VALUES (
            'admin',:'service_application',NOW()::text,
            :'service_display_name',:'client_id',:'client_secret',
            '[]','cert-built-in','["client_credentials"]','sunmoonai',false,
            'JWT',1,1
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

          SELECT count(*) = 1 AS application_ok FROM application
          WHERE owner='admin'
            AND name=:'service_application'
            AND client_id=:'client_id'
            AND grant_types='["client_credentials"]'
            AND redirect_uris='[]'
            AND token_format='JWT'
            AND expire_in_hours=1 \gset
          \if :application_ok
          \else
            \echo 'Casdoor service application reconciliation mismatch'
            \quit 1
          \endif
          SQL
          unset PGPASSWORD
          echo "Casdoor service application reconciled with client_credentials only"
EOF
    if ! wait_job "$job"; then
        k logs "job/$job" -n "$APP_NAMESPACE" --all-containers=true || true
        k describe job "$job" -n "$APP_NAMESPACE" || true
        cleanup_job "$job"
        exit 1
    fi
    k logs "job/$job" -n "$APP_NAMESPACE"
    cleanup_job "$job"
}

resolve_probe_image() {
    if [[ -n "$PROBE_IMAGE" ]]; then
        return 0
    fi
    PROBE_IMAGE="$(k get deployment knowledge-admin-backend -n "$APP_NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
    [[ -n "$PROBE_IMAGE" ]] || {
        echo "cannot resolve a backend probe image; use --probe-image" >&2
        exit 1
    }
}

probe_real_token_claims() {
    local job="p0-${TASK_ID##*-}-service-token-probe" logs subject_b64
    resolve_probe_image
    cleanup_job "$job"
    k wait --for=delete "job/$job" -n "$APP_NAMESPACE" --timeout=60s \
        >/dev/null 2>&1 || true
    cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: ${TASK_ID}
    app.kubernetes.io/component: service-token-probe
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        sunmoonai.com/task: ${TASK_ID}
        app.kubernetes.io/component: service-token-probe
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: probe
        image: ${PROBE_IMAGE}
        imagePullPolicy: IfNotPresent
        env:
        - name: SERVICE_CLIENT_ID
          valueFrom: {secretKeyRef: {name: ${OPERATOR_SECRET}, key: SERVICE_CLIENT_ID}}
        - name: SERVICE_CLIENT_SECRET
          valueFrom: {secretKeyRef: {name: ${OPERATOR_SECRET}, key: SERVICE_CLIENT_SECRET}}
        - name: PUBLIC_ENDPOINT
          value: "${PUBLIC_CASDOOR_ENDPOINT}"
        - name: BACKCHANNEL_ENDPOINT
          value: "${BACKCHANNEL_CASDOOR_ENDPOINT}"
        - name: SERVICE_SCOPE
          value: "${SERVICE_SCOPE}"
        - name: TASK_ID
          value: "${TASK_ID}"
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

          import httpx
          from joserfc import jwt
          from joserfc.jwk import KeySet
          from joserfc.jwt import JWTClaimsRegistry

          public = os.environ["PUBLIC_ENDPOINT"].rstrip("/")
          backchannel = os.environ["BACKCHANNEL_ENDPOINT"].rstrip("/")
          client_id = os.environ["SERVICE_CLIENT_ID"]
          client_secret = os.environ["SERVICE_CLIENT_SECRET"]
          scope = os.environ["SERVICE_SCOPE"]
          public_parts = urlsplit(public)
          backchannel_parts = urlsplit(backchannel)
          headers = {"Accept": "application/json", "Host": public_parts.netloc}

          def routed(url: str) -> str:
              parsed = urlsplit(url)
              if (parsed.scheme, parsed.netloc) != (public_parts.scheme, public_parts.netloc):
                  raise RuntimeError("provider metadata escaped the canonical origin")
              return urlunsplit((backchannel_parts.scheme, backchannel_parts.netloc,
                                  parsed.path, parsed.query, ""))

          async def main() -> None:
              async with httpx.AsyncClient(timeout=15, follow_redirects=False) as client:
                  discovery_url = f"{backchannel}/.well-known/openid-configuration"
                  discovery = await client.get(discovery_url, headers=headers)
                  discovery.raise_for_status()
                  metadata = discovery.json()
                  if metadata.get("issuer", "").rstrip("/") != public:
                      raise RuntimeError("standard discovery issuer mismatch")
                  token_endpoint = metadata.get("token_endpoint")
                  jwks_uri = metadata.get("jwks_uri")
                  if not isinstance(token_endpoint, str) or not isinstance(jwks_uri, str):
                      raise RuntimeError("standard discovery is incomplete")
                  token_response = await client.post(
                      routed(token_endpoint),
                      data={
                          "grant_type": "client_credentials",
                          "client_id": client_id,
                          "client_secret": client_secret,
                          "scope": scope,
                      },
                      headers=headers,
                  )
                  token_response.raise_for_status()
                  encoded = token_response.json().get("access_token")
                  if not isinstance(encoded, str) or not encoded:
                      raise RuntimeError("access token is unavailable")
                  jwks_response = await client.get(routed(jwks_uri), headers=headers)
                  jwks_response.raise_for_status()
                  key_set = KeySet.import_key_set(jwks_response.json())

              decoded = jwt.decode(encoded, key_set, algorithms=["RS256"])
              claims = decoded.claims
              JWTClaimsRegistry(
                  leeway=30,
                  iss={"essential": True, "value": metadata["issuer"]},
                  sub={"essential": True},
                  aud={"essential": True},
                  exp={"essential": True},
                  iat={"essential": True},
              ).validate(claims)
              audience = claims.get("aud")
              if audience != client_id and audience != [client_id]:
                  raise RuntimeError("service token audience mismatch")
              subject = claims.get("sub")
              if not isinstance(subject, str) or not subject:
                  raise RuntimeError("service token subject is unavailable")
              if int(claims["exp"]) > int(time.time()) + 7200:
                  raise RuntimeError("service token lifetime exceeds P0 policy")
              raw_scope = claims.get("scope", claims.get("scp"))
              if raw_scope is not None and not (
                  isinstance(raw_scope, str)
                  or (
                      isinstance(raw_scope, list)
                      and all(isinstance(item, str) for item in raw_scope)
                  )
              ):
                  raise RuntimeError("service token scope shape is invalid")
              subject_b64 = base64.b64encode(subject.encode()).decode()
              print(f"P0_SUBJECT_B64={subject_b64}")
              print(json.dumps({
                  "task": os.environ["TASK_ID"].upper() + "-service-token-probe",
                  "result": "passed",
                  "signature": "RS256",
                  "issuer_exact": True,
                  "audience_exact": True,
                  "subject_present": True,
                  "scope_shape_valid": True,
                  "token_printed": False,
              }, separators=(",", ":")))

          try:
              asyncio.run(main())
          except Exception as exc:
              print(json.dumps({
                  "task": os.environ["TASK_ID"].upper() + "-service-token-probe",
                  "result": "failed",
                  "reason": type(exc).__name__,
                  "token_printed": False,
              }, separators=(",", ":")))
              raise SystemExit(1) from None
          finally:
              client_secret = ""
          PY
EOF
    if ! wait_job "$job"; then
        k logs "job/$job" -n "$APP_NAMESPACE" --all-containers=true || true
        k describe job "$job" -n "$APP_NAMESPACE" || true
        cleanup_job "$job"
        exit 1
    fi
    logs="$(k logs "job/$job" -n "$APP_NAMESPACE")"
    subject_b64="$(printf '%s\n' "$logs" | sed -n 's/^P0_SUBJECT_B64=//p' | tail -n 1)"
    [[ "$subject_b64" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] || {
        echo "service token probe returned no valid subject binding" >&2
        cleanup_job "$job"
        exit 1
    }
    VERIFIED_SUBJECT="$(printf '%s' "$subject_b64" | base64 --decode)"
    [[ "$VERIFIED_SUBJECT" =~ ^[A-Za-z0-9._:@/-]{1,256}$ ]] || {
        echo "service token subject has an unsupported format" >&2
        cleanup_job "$job"
        exit 1
    }
    printf '%s\n' "$logs" | sed '/^P0_SUBJECT_B64=/d'
    cleanup_job "$job"
    unset logs subject_b64
}

apply_runtime_secrets() {
    cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${CALLER_SECRET}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: ${TASK_ID}
    app.kubernetes.io/component: service-identity-caller
    sunmoonai.com/service-relation: ${RELATION_LABEL}
type: Opaque
stringData:
  ${CALLER_CLIENT_ID_KEY}: "${SERVICE_CLIENT_ID}"
  ${CALLER_CLIENT_SECRET_KEY}: "${SERVICE_CLIENT_SECRET}"
  ${CALLER_DISCOVERY_KEY}: "${PUBLIC_CASDOOR_ENDPOINT}/.well-known/openid-configuration"
  ${CALLER_BACKCHANNEL_KEY}: "${BACKCHANNEL_CASDOOR_ENDPOINT}"
---
apiVersion: v1
kind: Secret
metadata:
  name: ${BINDING_SECRET}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: ${TASK_ID}
    app.kubernetes.io/component: service-identity-resource-binding
    sunmoonai.com/service-relation: ${RELATION_LABEL}
type: Opaque
stringData:
  ${BINDING_APPLICATION_KEY}: "${SERVICE_APPLICATION}"
  ${BINDING_DISCOVERY_KEY}: "${PUBLIC_CASDOOR_ENDPOINT}/.well-known/openid-configuration"
  ${BINDING_BACKCHANNEL_KEY}: "${BACKCHANNEL_CASDOOR_ENDPOINT}"
  ${BINDING_AUDIENCE_KEY}: "${SERVICE_CLIENT_ID}"
  ${BINDING_SUBJECTS_KEY}: "${VERIFIED_SUBJECT}"
  ${BINDING_SCOPE_KEY}: "${SERVICE_SCOPE}"
EOF
    echo "APPLIED caller Secret: $APP_NAMESPACE/$CALLER_SECRET"
    echo "APPLIED resource binding Secret: $APP_NAMESPACE/$BINDING_SECRET"
}

for command in kubectl base64 openssl sed; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "missing: $command" >&2
        exit 1
    }
done
[[ "$PUBLIC_CASDOOR_ENDPOINT" =~ ^https://[A-Za-z0-9._-]+(:[0-9]+)?$ ]] || {
    echo "public endpoint must be an HTTPS origin without a path" >&2
    exit 1
}
[[ "$BACKCHANNEL_CASDOOR_ENDPOINT" =~ ^https?://[A-Za-z0-9._-]+(:[0-9]+)?$ ]] || {
    echo "backchannel endpoint must be an HTTP(S) origin without a path" >&2
    exit 1
}
k get namespace "$APP_NAMESPACE" >/dev/null
k get secret "$CASDOOR_DATABASE_SECRET" -n "$APP_NAMESPACE" >/dev/null

echo "PLAN relation: $CALLER_NAME -> knowledge-admin-backend"
echo "PLAN grant: client_credentials, exact audience/subject, local scope=$SERVICE_SCOPE"
echo "PLAN runtime caller Secret: $APP_NAMESPACE/$CALLER_SECRET"
echo "PLAN runtime resource binding Secret: $APP_NAMESPACE/$BINDING_SECRET"
load_or_create_operator_secret
[[ "$APPLY" == "true" ]] || {
    echo "PLAN ONLY: rerun with --apply"
    exit 0
}

validate_credentials
reconcile_casdoor_application
probe_real_token_claims
apply_runtime_secrets
unset SERVICE_CLIENT_ID SERVICE_CLIENT_SECRET VERIFIED_SUBJECT
echo "${TASK_ID^^} service identity reconciled and empirically bound without printing credentials"
