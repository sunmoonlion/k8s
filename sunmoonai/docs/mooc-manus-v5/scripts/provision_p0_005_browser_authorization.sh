#!/usr/bin/env bash

# Bind verified Casdoor subjects to local Admin authorization policy for
# V5-P0-005. The binding starts from Casdoor's stable user ID, never from an
# unverified browser claim, and updates each app by the immutable
# (issuer, subject) pair created by the real OIDC callback.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="app-platform-dev"
OPERATOR_SECRET="sunmoonai-p0-005-browser-identity"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
APPLY=false

usage() {
    cat <<'EOF'
Usage: provision_p0_005_browser_authorization.sh [--apply] [options]

  --apply              Reconcile local authorization policy (default: plan only)
  --kubeconfig PATH    Kubeconfig path
  --namespace NAME     Application namespace
  --client-image IMAGE PostgreSQL client image
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=true; shift ;;
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        --namespace) APP_NAMESPACE="$2"; shift 2 ;;
        --client-image) POSTGRES_CLIENT_IMAGE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

k() { kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"; }

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

require_secret() {
    k get secret "$1" -n "$APP_NAMESPACE" >/dev/null 2>&1 || {
        echo "required Secret missing: $APP_NAMESPACE/$1" >&2
        exit 1
    }
}

reconcile_authorization() {
    local job="p0-005-browser-authorization-provision"
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
    app.kubernetes.io/component: authorization-provisioning
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-005
        app.kubernetes.io/component: authorization-provisioning
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
        - name: PRIMARY_USERNAME
          valueFrom: {secretKeyRef: {name: ${OPERATOR_SECRET}, key: PRIMARY_USERNAME}}
        - name: SECONDARY_USERNAME
          valueFrom: {secretKeyRef: {name: ${OPERATOR_SECRET}, key: SECONDARY_USERNAME}}
        - name: CASDOOR_DB_HOST
          valueFrom: {secretKeyRef: {name: casdoor-postgresql-conn, key: DB_HOST}}
        - name: CASDOOR_DB_PORT
          valueFrom: {secretKeyRef: {name: casdoor-postgresql-conn, key: DB_PORT}}
        - name: CASDOOR_DB_NAME
          valueFrom: {secretKeyRef: {name: casdoor-postgresql-conn, key: APP_DB_NAME}}
        - name: CASDOOR_DB_USER
          valueFrom: {secretKeyRef: {name: casdoor-postgresql-conn, key: APP_DB_USER}}
        - name: CASDOOR_DB_PASSWORD
          valueFrom: {secretKeyRef: {name: casdoor-postgresql-conn, key: APP_DB_PASSWORD}}
        - name: INFO_DB_HOST
          valueFrom: {secretKeyRef: {name: info-admin-backend-postgresql-conn, key: DB_HOST}}
        - name: INFO_DB_PORT
          valueFrom: {secretKeyRef: {name: info-admin-backend-postgresql-conn, key: DB_PORT}}
        - name: INFO_DB_NAME
          valueFrom: {secretKeyRef: {name: info-admin-backend-postgresql-conn, key: APP_DB_NAME}}
        - name: INFO_DB_USER
          valueFrom: {secretKeyRef: {name: info-admin-backend-postgresql-conn, key: APP_DB_USER}}
        - name: INFO_DB_PASSWORD
          valueFrom: {secretKeyRef: {name: info-admin-backend-postgresql-conn, key: APP_DB_PASSWORD}}
        - name: KNOWLEDGE_DB_HOST
          valueFrom: {secretKeyRef: {name: knowledge-admin-backend-postgresql-conn, key: DB_HOST}}
        - name: KNOWLEDGE_DB_PORT
          valueFrom: {secretKeyRef: {name: knowledge-admin-backend-postgresql-conn, key: DB_PORT}}
        - name: KNOWLEDGE_DB_NAME
          valueFrom: {secretKeyRef: {name: knowledge-admin-backend-postgresql-conn, key: APP_DB_NAME}}
        - name: KNOWLEDGE_DB_USER
          valueFrom: {secretKeyRef: {name: knowledge-admin-backend-postgresql-conn, key: APP_DB_USER}}
        - name: KNOWLEDGE_DB_PASSWORD
          valueFrom: {secretKeyRef: {name: knowledge-admin-backend-postgresql-conn, key: APP_DB_PASSWORD}}
        - name: RESEARCH_DB_HOST
          valueFrom: {secretKeyRef: {name: research-admin-backend-postgresql-conn, key: DB_HOST}}
        - name: RESEARCH_DB_PORT
          valueFrom: {secretKeyRef: {name: research-admin-backend-postgresql-conn, key: DB_PORT}}
        - name: RESEARCH_DB_NAME
          valueFrom: {secretKeyRef: {name: research-admin-backend-postgresql-conn, key: APP_DB_NAME}}
        - name: RESEARCH_DB_USER
          valueFrom: {secretKeyRef: {name: research-admin-backend-postgresql-conn, key: APP_DB_USER}}
        - name: RESEARCH_DB_PASSWORD
          valueFrom: {secretKeyRef: {name: research-admin-backend-postgresql-conn, key: APP_DB_PASSWORD}}
        - name: INFO_ISSUER
          valueFrom: {secretKeyRef: {name: info-admin-backend-browser-oidc, key: CASDOOR_ENDPOINT}}
        - name: KNOWLEDGE_ISSUER
          valueFrom: {secretKeyRef: {name: knowledge-admin-backend-browser-oidc, key: CASDOOR_ENDPOINT}}
        - name: RESEARCH_ISSUER
          valueFrom: {secretKeyRef: {name: research-admin-backend-browser-oidc, key: CASDOOR_ENDPOINT}}
        command: ["/bin/bash", "-ec"]
        args:
        - |
          set -euo pipefail
          [[ "\$INFO_ISSUER" == "\$KNOWLEDGE_ISSUER" ]]
          [[ "\$INFO_ISSUER" == "\$RESEARCH_ISSUER" ]]
          [[ "\$INFO_ISSUER" =~ ^https://[A-Za-z0-9._-]+(:[0-9]+)?\$ ]]

          export PGPASSWORD="\$CASDOOR_DB_PASSWORD"
          primary_subject="\$(
            psql -h "\$CASDOOR_DB_HOST" -p "\$CASDOOR_DB_PORT" \
              -U "\$CASDOOR_DB_USER" -d "\$CASDOOR_DB_NAME" -Atq \
              --set=username="\$PRIMARY_USERNAME" <<'IDENTITY_SQL'
          SELECT id FROM "user"
          WHERE owner='sunmoonai' AND name=:'username'
            AND is_forbidden=false AND is_deleted=false;
          IDENTITY_SQL
          )"
          secondary_subject="\$(
            psql -h "\$CASDOOR_DB_HOST" -p "\$CASDOOR_DB_PORT" \
              -U "\$CASDOOR_DB_USER" -d "\$CASDOOR_DB_NAME" -Atq \
              --set=username="\$SECONDARY_USERNAME" <<'IDENTITY_SQL'
          SELECT id FROM "user"
          WHERE owner='sunmoonai' AND name=:'username'
            AND is_forbidden=false AND is_deleted=false;
          IDENTITY_SQL
          )"
          [[ "\$primary_subject" =~ ^[0-9a-fA-F-]{36}\$ ]]
          [[ "\$secondary_subject" =~ ^[0-9a-fA-F-]{36}\$ ]]
          [[ "\$primary_subject" != "\$secondary_subject" ]]

          export PGPASSWORD="\$INFO_DB_PASSWORD"
          psql -h "\$INFO_DB_HOST" -p "\$INFO_DB_PORT" -U "\$INFO_DB_USER" \
            -d "\$INFO_DB_NAME" -q -v ON_ERROR_STOP=1 \
            --set=issuer="\$INFO_ISSUER" --set=subject="\$primary_subject" \
            --set=scope="info:admin" >/dev/null <<'SQL'
          BEGIN;
          SELECT count(*) = 1 AS binding_ok FROM auth_user
          WHERE issuer = :'issuer' AND subject = :'subject' \gset
          \if :binding_ok
            UPDATE auth_user SET roles='["admin"]'::jsonb,
              scopes=jsonb_build_array(:'scope'), updated_at=NOW()
            WHERE issuer=:'issuer' AND subject=:'subject';
          \else
            \echo 'Info verified identity binding count mismatch'
            \quit 1
          \endif
          COMMIT;
          SQL

          export PGPASSWORD="\$KNOWLEDGE_DB_PASSWORD"
          psql -h "\$KNOWLEDGE_DB_HOST" -p "\$KNOWLEDGE_DB_PORT" -U "\$KNOWLEDGE_DB_USER" \
            -d "\$KNOWLEDGE_DB_NAME" -q -v ON_ERROR_STOP=1 \
            --set=issuer="\$KNOWLEDGE_ISSUER" --set=subject="\$primary_subject" \
            --set=scope="knowledge:admin" >/dev/null <<'SQL'
          BEGIN;
          SELECT count(*) = 1 AS binding_ok FROM auth_user
          WHERE issuer = :'issuer' AND subject = :'subject' \gset
          \if :binding_ok
            UPDATE auth_user SET roles='["admin"]'::jsonb,
              scopes=jsonb_build_array(:'scope'), updated_at=NOW()
            WHERE issuer=:'issuer' AND subject=:'subject';
          \else
            \echo 'Knowledge verified identity binding count mismatch'
            \quit 1
          \endif
          COMMIT;
          SQL

          export PGPASSWORD="\$RESEARCH_DB_PASSWORD"
          psql -h "\$RESEARCH_DB_HOST" -p "\$RESEARCH_DB_PORT" -U "\$RESEARCH_DB_USER" \
            -d "\$RESEARCH_DB_NAME" -q -v ON_ERROR_STOP=1 \
            --set=issuer="\$RESEARCH_ISSUER" --set=primary_subject="\$primary_subject" \
            --set=secondary_subject="\$secondary_subject" \
            --set=scope="research:admin" >/dev/null <<'SQL'
          BEGIN;
          SELECT count(*) = 1 AS primary_ok FROM auth_user
          WHERE issuer = :'issuer' AND subject = :'primary_subject' \gset
          SELECT count(*) = 1 AS secondary_ok FROM auth_user
          WHERE issuer = :'issuer' AND subject = :'secondary_subject' \gset
          \if :primary_ok
            \if :secondary_ok
              UPDATE auth_user SET roles='["admin"]'::jsonb,
                scopes=jsonb_build_array(:'scope'), updated_at=NOW()
              WHERE issuer=:'issuer'
                AND subject IN (:'primary_subject', :'secondary_subject');
            \else
              \echo 'Research secondary verified identity binding count mismatch'
              \quit 1
            \endif
          \else
            \echo 'Research primary verified identity binding count mismatch'
            \quit 1
          \endif
          COMMIT;
          SQL
          unset PGPASSWORD primary_subject secondary_subject
          echo "browser authorization policies reconciled: info=1 knowledge=1 research=2"
EOF
    if ! wait_job "$job"; then
        k logs "job/$job" -n "$APP_NAMESPACE" --all-containers=true || true
        k describe job "$job" -n "$APP_NAMESPACE" || true
        exit 1
    fi
    k logs "job/$job" -n "$APP_NAMESPACE"
    k delete job "$job" -n "$APP_NAMESPACE" --wait=false >/dev/null
}

for command in kubectl; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "missing: $command" >&2
        exit 1
    }
done
k get namespace "$APP_NAMESPACE" >/dev/null
for secret in \
    "$OPERATOR_SECRET" \
    casdoor-postgresql-conn \
    info-admin-backend-postgresql-conn \
    knowledge-admin-backend-postgresql-conn \
    research-admin-backend-postgresql-conn \
    info-admin-backend-browser-oidc \
    knowledge-admin-backend-browser-oidc \
    research-admin-backend-browser-oidc; do
    require_secret "$secret"
done

echo "PLAN bind verified primary subject to Info, Knowledge and Research Admin"
echo "PLAN bind verified secondary subject to Research Admin for owner-isolation tests"
[[ "$APPLY" == "true" ]] || {
    echo "PLAN ONLY: rerun with --apply after successful real OIDC login"
    exit 0
}

reconcile_authorization
echo "V5-P0-005 browser authorization reconciled without printing identities or credentials"
