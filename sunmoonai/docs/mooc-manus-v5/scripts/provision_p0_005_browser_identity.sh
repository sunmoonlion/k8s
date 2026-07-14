#!/usr/bin/env bash

# Reconcile the real Casdoor Admin browser applications and per-Pod OIDC
# Secrets for V5-P0-005. Default mode is plan-only; credentials are never
# printed or written to the repository.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="app-platform-dev"
OPERATOR_SECRET="sunmoonai-p0-005-browser-identity"
CASDOOR_DATABASE_SECRET="casdoor-postgresql-conn"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
PUBLIC_CASDOOR_ENDPOINT="https://casdoor.sunmoonai.com:30443"
BACKCHANNEL_CASDOOR_ENDPOINT="http://casdoor-sunmoonai:8000"
APPLY=false

usage() {
    cat <<'EOF'
Usage: provision_p0_005_browser_identity.sh [--apply] [options]

  --apply                     Reconcile Casdoor and Secrets (default: plan only)
  --kubeconfig PATH           Kubeconfig path
  --namespace NAME            Application namespace
  --public-endpoint URL       Browser-visible Casdoor origin
  --backchannel-endpoint URL  Fixed in-cluster Casdoor transport origin
  --client-image IMAGE        PostgreSQL client image
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=true; shift ;;
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        --namespace) APP_NAMESPACE="$2"; shift 2 ;;
        --public-endpoint) PUBLIC_CASDOOR_ENDPOINT="$2"; shift 2 ;;
        --backchannel-endpoint) BACKCHANNEL_CASDOOR_ENDPOINT="$2"; shift 2 ;;
        --client-image) POSTGRES_CLIENT_IMAGE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

k() { kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"; }

secret_value() {
    local secret="$1" key="$2" encoded
    encoded="$(k get secret "$secret" -n "$APP_NAMESPACE" \
        -o "jsonpath={.data.${key}}" 2>/dev/null || true)"
    [[ -n "$encoded" ]] || return 1
    printf '%s' "$encoded" | base64 --decode
}

valid_hex() {
    [[ "$2" =~ ^[a-f0-9]+$ && ${#2} -ge $3 ]] || {
        echo "$1 is not a valid generated credential" >&2; exit 1;
    }
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

INFO_CLIENT_ID=""
INFO_CLIENT_SECRET=""
KNOWLEDGE_CLIENT_ID=""
KNOWLEDGE_CLIENT_SECRET=""
RESEARCH_CLIENT_ID=""
RESEARCH_CLIENT_SECRET=""
PRIMARY_USERNAME="p0-admin-a"
PRIMARY_PASSWORD=""
SECONDARY_USERNAME="p0-admin-b"
SECONDARY_PASSWORD=""

load_or_create_operator_secret() {
    if k get secret "$OPERATOR_SECRET" -n "$APP_NAMESPACE" >/dev/null 2>&1; then
        INFO_CLIENT_ID="$(secret_value "$OPERATOR_SECRET" INFO_ADMIN_CLIENT_ID)"
        INFO_CLIENT_SECRET="$(secret_value "$OPERATOR_SECRET" INFO_ADMIN_CLIENT_SECRET)"
        KNOWLEDGE_CLIENT_ID="$(secret_value "$OPERATOR_SECRET" KNOWLEDGE_ADMIN_CLIENT_ID)"
        KNOWLEDGE_CLIENT_SECRET="$(secret_value "$OPERATOR_SECRET" KNOWLEDGE_ADMIN_CLIENT_SECRET)"
        RESEARCH_CLIENT_ID="$(secret_value "$OPERATOR_SECRET" RESEARCH_ADMIN_CLIENT_ID)"
        RESEARCH_CLIENT_SECRET="$(secret_value "$OPERATOR_SECRET" RESEARCH_ADMIN_CLIENT_SECRET)"
        PRIMARY_USERNAME="$(secret_value "$OPERATOR_SECRET" PRIMARY_USERNAME)"
        PRIMARY_PASSWORD="$(secret_value "$OPERATOR_SECRET" PRIMARY_PASSWORD)"
        SECONDARY_USERNAME="$(secret_value "$OPERATOR_SECRET" SECONDARY_USERNAME)"
        SECONDARY_PASSWORD="$(secret_value "$OPERATOR_SECRET" SECONDARY_PASSWORD)"
        echo "PLAN reuse operator Secret: $APP_NAMESPACE/$OPERATOR_SECRET"
        return
    fi

    echo "PLAN create operator Secret: $APP_NAMESPACE/$OPERATOR_SECRET"
    [[ "$APPLY" == "true" ]] || return 0
    INFO_CLIENT_ID="$(openssl rand -hex 16)"
    INFO_CLIENT_SECRET="$(openssl rand -hex 32)"
    KNOWLEDGE_CLIENT_ID="$(openssl rand -hex 16)"
    KNOWLEDGE_CLIENT_SECRET="$(openssl rand -hex 32)"
    RESEARCH_CLIENT_ID="$(openssl rand -hex 16)"
    RESEARCH_CLIENT_SECRET="$(openssl rand -hex 32)"
    PRIMARY_PASSWORD="$(openssl rand -hex 24)"
    SECONDARY_PASSWORD="$(openssl rand -hex 24)"

    cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${OPERATOR_SECRET}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-005
    app.kubernetes.io/component: identity-provisioning
type: Opaque
stringData:
  INFO_ADMIN_CLIENT_ID: "${INFO_CLIENT_ID}"
  INFO_ADMIN_CLIENT_SECRET: "${INFO_CLIENT_SECRET}"
  KNOWLEDGE_ADMIN_CLIENT_ID: "${KNOWLEDGE_CLIENT_ID}"
  KNOWLEDGE_ADMIN_CLIENT_SECRET: "${KNOWLEDGE_CLIENT_SECRET}"
  RESEARCH_ADMIN_CLIENT_ID: "${RESEARCH_CLIENT_ID}"
  RESEARCH_ADMIN_CLIENT_SECRET: "${RESEARCH_CLIENT_SECRET}"
  PRIMARY_USERNAME: "${PRIMARY_USERNAME}"
  PRIMARY_PASSWORD: "${PRIMARY_PASSWORD}"
  SECONDARY_USERNAME: "${SECONDARY_USERNAME}"
  SECONDARY_PASSWORD: "${SECONDARY_PASSWORD}"
EOF
}

validate_credentials() {
    [[ "$PRIMARY_USERNAME" =~ ^[a-z0-9-]{3,40}$ ]] || exit 1
    [[ "$SECONDARY_USERNAME" =~ ^[a-z0-9-]{3,40}$ ]] || exit 1
    valid_hex INFO_ADMIN_CLIENT_ID "$INFO_CLIENT_ID" 32
    valid_hex INFO_ADMIN_CLIENT_SECRET "$INFO_CLIENT_SECRET" 64
    valid_hex KNOWLEDGE_ADMIN_CLIENT_ID "$KNOWLEDGE_CLIENT_ID" 32
    valid_hex KNOWLEDGE_ADMIN_CLIENT_SECRET "$KNOWLEDGE_CLIENT_SECRET" 64
    valid_hex RESEARCH_ADMIN_CLIENT_ID "$RESEARCH_CLIENT_ID" 32
    valid_hex RESEARCH_ADMIN_CLIENT_SECRET "$RESEARCH_CLIENT_SECRET" 64
    valid_hex PRIMARY_PASSWORD "$PRIMARY_PASSWORD" 48
    valid_hex SECONDARY_PASSWORD "$SECONDARY_PASSWORD" 48
}

reconcile_casdoor() {
    local job="p0-005-browser-identity-provision"
    k delete job "$job" -n "$APP_NAMESPACE" --ignore-not-found=true \
        --wait=true >/dev/null
    cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  namespace: ${APP_NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-005
    app.kubernetes.io/component: identity-provisioning
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-005
        app.kubernetes.io/component: identity-provisioning
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: provision
        image: ${POSTGRES_CLIENT_IMAGE}
        imagePullPolicy: IfNotPresent
        envFrom:
        - secretRef:
            name: ${OPERATOR_SECRET}
        - secretRef:
            name: ${CASDOOR_DATABASE_SECRET}
        command: ["/bin/bash", "-ec"]
        args:
        - |
          export PGPASSWORD="\$APP_DB_PASSWORD"
          psql -h "\$DB_HOST" -p "\$DB_PORT" -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
            -v ON_ERROR_STOP=1 \
            --set=info_id="\$INFO_ADMIN_CLIENT_ID" \
            --set=info_secret="\$INFO_ADMIN_CLIENT_SECRET" \
            --set=knowledge_id="\$KNOWLEDGE_ADMIN_CLIENT_ID" \
            --set=knowledge_secret="\$KNOWLEDGE_ADMIN_CLIENT_SECRET" \
            --set=research_id="\$RESEARCH_ADMIN_CLIENT_ID" \
            --set=research_secret="\$RESEARCH_ADMIN_CLIENT_SECRET" \
            --set=user_a="\$PRIMARY_USERNAME" --set=password_a="\$PRIMARY_PASSWORD" \
            --set=user_b="\$SECONDARY_USERNAME" --set=password_b="\$SECONDARY_PASSWORD" <<'SQL'
          INSERT INTO organization (
            owner, name, created_time, display_name, default_application,
            password_type, country_codes, init_score, is_profile_public, languages
          ) VALUES (
            'admin', 'sunmoonai', NOW()::text, 'SunMoon AI', 'sunmoonai-info-admin',
            'plain', '["CN"]', 2000, false, '["en","zh"]'
          ) ON CONFLICT (owner, name) DO UPDATE SET
            display_name=EXCLUDED.display_name,
            default_application=EXCLUDED.default_application,
            password_type=EXCLUDED.password_type,
            country_codes=EXCLUDED.country_codes,
            init_score=EXCLUDED.init_score,
            is_profile_public=EXCLUDED.is_profile_public,
            languages=EXCLUDED.languages;

          INSERT INTO application (
            owner, name, created_time, display_name, client_id, client_secret,
            redirect_uris, cert, grant_types, organization, enable_sign_up,
            token_format, expire_in_hours, refresh_expire_in_hours
          ) VALUES
            ('admin','sunmoonai-info-admin',NOW()::text,'SunMoon Info Admin',
             :'info_id',:'info_secret','["http://127.0.0.1:18082/api/auth/callback"]',
             'cert-built-in','["authorization_code"]','sunmoonai',false,'JWT',1,24),
            ('admin','sunmoonai-knowledge-admin',NOW()::text,'SunMoon Knowledge Admin',
             :'knowledge_id',:'knowledge_secret','["http://127.0.0.1:18083/api/auth/callback"]',
             'cert-built-in','["authorization_code"]','sunmoonai',false,'JWT',1,24),
            ('admin','sunmoonai-research-admin',NOW()::text,'SunMoon Research Admin',
             :'research_id',:'research_secret','["http://127.0.0.1:18084/api/auth/callback"]',
             'cert-built-in','["authorization_code"]','sunmoonai',false,'JWT',1,24)
          ON CONFLICT (owner, name) DO UPDATE SET
            display_name=EXCLUDED.display_name, client_id=EXCLUDED.client_id,
            client_secret=EXCLUDED.client_secret, redirect_uris=EXCLUDED.redirect_uris,
            cert=EXCLUDED.cert, grant_types=EXCLUDED.grant_types,
            organization=EXCLUDED.organization, enable_sign_up=EXCLUDED.enable_sign_up,
            token_format=EXCLUDED.token_format, expire_in_hours=EXCLUDED.expire_in_hours,
            refresh_expire_in_hours=EXCLUDED.refresh_expire_in_hours;

          DO \$casdoor\$
          BEGIN
            IF NOT EXISTS (
              SELECT 1 FROM application
              WHERE owner='admin' AND name='app-built-in' AND signin_items IS NOT NULL
            ) THEN
              RAISE EXCEPTION 'Casdoor built-in signin form baseline is unavailable';
            END IF;
          END
          \$casdoor\$;

          UPDATE application
          SET enable_password=true,
              signin_methods='[{"name":"Password","displayName":"Password","rule":"All"}]',
              signin_items=(
                SELECT signin_items FROM application
                WHERE owner='admin' AND name='app-built-in'
              )
          WHERE owner='admin'
            AND name IN (
              'sunmoonai-info-admin',
              'sunmoonai-knowledge-admin',
              'sunmoonai-research-admin'
            );

          INSERT INTO "user" (
            owner,name,created_time,updated_time,id,type,password,password_salt,
            display_name,avatar,email,phone,score,karma,ranking,is_default_avatar,
            is_online,is_admin,is_forbidden,is_deleted,signup_application,
            properties,address,created_ip,signin_wrong_times
          ) VALUES
            ('sunmoonai',:'user_a',NOW()::text,NOW()::text,gen_random_uuid()::text,
             'normal-user',:'password_a','','P0 Admin A',
             'https://cdn.casbin.org/img/casbin.svg','p0-admin-a@sunmoonai.local','',
             2000,0,1,false,false,true,false,false,'sunmoonai-info-admin','{}','[]','127.0.0.1',0),
            ('sunmoonai',:'user_b',NOW()::text,NOW()::text,gen_random_uuid()::text,
             'normal-user',:'password_b','','P0 Admin B',
             'https://cdn.casbin.org/img/casbin.svg','p0-admin-b@sunmoonai.local','',
             2000,0,1,false,false,false,false,false,'sunmoonai-info-admin','{}','[]','127.0.0.1',0)
          ON CONFLICT (owner, name) DO UPDATE SET
            password=EXCLUDED.password, updated_time=EXCLUDED.updated_time,
            signup_application=EXCLUDED.signup_application,
            is_forbidden=false, is_deleted=false;
          SQL
          echo "Casdoor browser applications and test users reconciled"
EOF
    if ! wait_job "$job"; then
        k logs "job/$job" -n "$APP_NAMESPACE" --all-containers=true || true
        k describe job "$job" -n "$APP_NAMESPACE" || true
        exit 1
    fi
    k logs "job/$job" -n "$APP_NAMESPACE"
    k delete job "$job" -n "$APP_NAMESPACE" --wait=false >/dev/null
}

apply_app_secret() {
    local app="$1" application="$2" client_id="$3" client_secret="$4"
    local backend_port="$5" frontend_port="$6"
    cat <<EOF | k apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${app}-browser-oidc
  namespace: ${APP_NAMESPACE}
  labels:
    app: ${app}
    sunmoonai.com/task: v5-p0-005
    app.kubernetes.io/component: browser-identity
type: Opaque
stringData:
  CASDOOR_ENDPOINT: "${PUBLIC_CASDOOR_ENDPOINT}"
  CASDOOR_BACKCHANNEL_ENDPOINT: "${BACKCHANNEL_CASDOOR_ENDPOINT}"
  CASDOOR_CLIENT_ID: "${client_id}"
  CASDOOR_CLIENT_SECRET: "${client_secret}"
  CASDOOR_REDIRECT_URI: "http://127.0.0.1:${backend_port}/api/auth/callback"
  CASDOOR_APPLICATION: "${application}"
  CASDOOR_VERIFY_SSL: "true"
  FRONTEND_BASE_URL: "http://127.0.0.1:${frontend_port}"
  FRONTEND_ALLOWED_ORIGINS: "http://127.0.0.1:${frontend_port}"
  SESSION_COOKIE_SECURE: "false"
EOF
    echo "APPLIED app=$app secret=$APP_NAMESPACE/${app}-browser-oidc"
}

for command in kubectl base64 openssl; do
    command -v "$command" >/dev/null 2>&1 || { echo "missing: $command" >&2; exit 1; }
done
[[ "$PUBLIC_CASDOOR_ENDPOINT" =~ ^https://[A-Za-z0-9._-]+(:[0-9]+)?$ ]] || exit 1
[[ "$BACKCHANNEL_CASDOOR_ENDPOINT" =~ ^https?://[A-Za-z0-9._-]+(:[0-9]+)?$ ]] || exit 1
k get namespace "$APP_NAMESPACE" >/dev/null
k get secret "$CASDOOR_DATABASE_SECRET" -n "$APP_NAMESPACE" >/dev/null

echo "PLAN sunmoonai-info-admin -> http://127.0.0.1:18082/api/auth/callback"
echo "PLAN sunmoonai-knowledge-admin -> http://127.0.0.1:18083/api/auth/callback"
echo "PLAN sunmoonai-research-admin -> http://127.0.0.1:18084/api/auth/callback"
load_or_create_operator_secret
[[ "$APPLY" == "true" ]] || { echo "PLAN ONLY: rerun with --apply"; exit 0; }

validate_credentials
reconcile_casdoor
apply_app_secret info-admin-backend sunmoonai-info-admin \
    "$INFO_CLIENT_ID" "$INFO_CLIENT_SECRET" 18082 19082
apply_app_secret knowledge-admin-backend sunmoonai-knowledge-admin \
    "$KNOWLEDGE_CLIENT_ID" "$KNOWLEDGE_CLIENT_SECRET" 18083 19083
apply_app_secret research-admin-backend sunmoonai-research-admin \
    "$RESEARCH_CLIENT_ID" "$RESEARCH_CLIENT_SECRET" 18084 19084

unset INFO_CLIENT_ID INFO_CLIENT_SECRET KNOWLEDGE_CLIENT_ID KNOWLEDGE_CLIENT_SECRET
unset RESEARCH_CLIENT_ID RESEARCH_CLIENT_SECRET PRIMARY_PASSWORD SECONDARY_PASSWORD
echo "V5-P0-005 browser identity reconciled without printing credentials"
