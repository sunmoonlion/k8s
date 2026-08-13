#!/usr/bin/env bash

set -euo pipefail
umask 077

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
NAMESPACE="${ARCH_V2_NAMESPACE:-app-platform-dev}"
OPERATOR_SECRET="architecture-v2-browser-operator"
DATABASE_SECRET="casdoor-postgresql-conn"
CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
JOB="architecture-v2-browser-operator-provision"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

k() { kubectl --kubeconfig "$KUBECONFIG_PATH" --request-timeout=30s "$@"; }

if ! k get secret "$OPERATOR_SECRET" -n "$NAMESPACE" >/dev/null 2>&1; then
  primary_password="$(openssl rand -hex 24)"
  secondary_password="$(openssl rand -hex 24)"
  k create secret generic "$OPERATOR_SECRET" -n "$NAMESPACE" \
    --from-literal=PRIMARY_USERNAME=architecture-v2-admin-a \
    --from-literal=PRIMARY_PASSWORD="$primary_password" \
    --from-literal=SECONDARY_USERNAME=architecture-v2-admin-b \
    --from-literal=SECONDARY_PASSWORD="$secondary_password" \
    --dry-run=client -o yaml | k apply -f - >/dev/null
  unset primary_password secondary_password
fi

k label secret "$OPERATOR_SECRET" -n "$NAMESPACE" \
  sunmoonai.com/managed-by=app-platform-v2 \
  app.kubernetes.io/component=browser-gate-identity --overwrite >/dev/null

k delete job "$JOB" -n "$NAMESPACE" --ignore-not-found=true --wait=true >/dev/null
cat <<EOF | k apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB}
  namespace: ${NAMESPACE}
  labels:
    sunmoonai.com/managed-by: app-platform-v2
    app.kubernetes.io/component: browser-gate-identity
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        sunmoonai.com/managed-by: app-platform-v2
        app.kubernetes.io/component: browser-gate-identity
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: harbor-registry-secret
      containers:
      - name: provision
        image: ${CLIENT_IMAGE}
        imagePullPolicy: IfNotPresent
        envFrom:
        - secretRef: {name: ${OPERATOR_SECRET}}
        - secretRef: {name: ${DATABASE_SECRET}}
        command: ["/bin/bash", "-ec"]
        args:
        - |
          export PGPASSWORD="\$APP_DB_PASSWORD"
          psql -h "\$DB_HOST" -p "\$DB_PORT" -U "\$APP_DB_USER" -d "\$APP_DB_NAME" \
            -v ON_ERROR_STOP=1 \
            --set=user_a="\$PRIMARY_USERNAME" --set=password_a="\$PRIMARY_PASSWORD" \
            --set=user_b="\$SECONDARY_USERNAME" --set=password_b="\$SECONDARY_PASSWORD" <<'SQL'
          INSERT INTO "user" (
            owner,name,created_time,updated_time,id,type,password,password_salt,
            display_name,avatar,email,phone,score,karma,ranking,is_default_avatar,
            is_online,is_admin,is_forbidden,is_deleted,signup_application,
            properties,address,created_ip,signin_wrong_times
          ) VALUES
            ('sunmoonai',:'user_a',NOW()::text,NOW()::text,gen_random_uuid()::text,
             'normal-user',:'password_a','','Architecture v2 Admin A',
             'https://cdn.casbin.org/img/casbin.svg','architecture-v2-admin-a@sunmoonai.local','',
             2000,0,1,false,false,true,false,false,'sunmoonai-info-r5-admin','{}','[]','127.0.0.1',0),
            ('sunmoonai',:'user_b',NOW()::text,NOW()::text,gen_random_uuid()::text,
             'normal-user',:'password_b','','Architecture v2 Admin B',
             'https://cdn.casbin.org/img/casbin.svg','architecture-v2-admin-b@sunmoonai.local','',
             2000,0,1,false,false,false,false,false,'sunmoonai-info-r5-admin','{}','[]','127.0.0.1',0)
          ON CONFLICT (owner, name) DO UPDATE SET
            password=EXCLUDED.password, updated_time=EXCLUDED.updated_time,
            signup_application=EXCLUDED.signup_application,
            is_forbidden=false, is_deleted=false, signin_wrong_times=0;
          SQL
EOF

k wait --for=condition=complete "job/$JOB" -n "$NAMESPACE" --timeout=180s >/dev/null || {
  k logs "job/$JOB" -n "$NAMESPACE" --tail=100 >&2 || true
  exit 1
}
k delete job "$JOB" -n "$NAMESPACE" --wait=true >/dev/null
echo "Architecture v2 browser operator reconciled without printing credentials"
