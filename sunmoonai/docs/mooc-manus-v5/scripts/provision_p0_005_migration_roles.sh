#!/usr/bin/env bash

# Provision dedicated PostgreSQL migration roles and app-namespace Secrets for
# V5-P0-005.  The default mode is read-only planning; mutations require
# explicit --apply.  Secret values are never printed.

set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/kind-config}"
APP_NAMESPACE="app-platform-dev"
DATA_NAMESPACE="data-platform-dev"
POSTGRES_SERVICE="postgresql-sunmoonai.data-platform-dev.svc.cluster.local"
POSTGRES_ADMIN_SECRET="postgresql-auth-secret"
POSTGRES_CLIENT_IMAGE="harbor.sunmoonai.com:30443/k8s-images/postgresql:17.6.0-debian-12-r4"
APPLY=false

usage() {
    cat <<'EOF'
Usage: provision_p0_005_migration_roles.sh [--apply] [options]

Options:
  --apply                     Reconcile roles and Secrets (default: plan only)
  --kubeconfig PATH           Kubeconfig path
  --app-namespace NAME        Application namespace (default: app-platform-dev)
  --data-namespace NAME       PostgreSQL namespace (default: data-platform-dev)
  --postgres-service HOST     PostgreSQL service hostname
  --client-image IMAGE        PostgreSQL client image
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY=true; shift ;;
        --kubeconfig) KUBECONFIG_PATH="$2"; shift 2 ;;
        --app-namespace) APP_NAMESPACE="$2"; shift 2 ;;
        --data-namespace) DATA_NAMESPACE="$2"; shift 2 ;;
        --postgres-service) POSTGRES_SERVICE="$2"; shift 2 ;;
        --client-image) POSTGRES_CLIENT_IMAGE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

kubectl_cmd() {
    kubectl --kubeconfig "$KUBECONFIG_PATH" "$@"
}

decode_secret_key() {
    local namespace="$1" secret="$2" key="$3" encoded
    encoded="$(kubectl_cmd get secret "$secret" -n "$namespace" \
        -o "jsonpath={.data.${key}}" 2>/dev/null || true)"
    [[ -n "$encoded" ]] || return 1
    printf '%s' "$encoded" | base64 --decode
}

require_identifier() {
    local label="$1" value="$2"
    if [[ ! "$value" =~ ^[a-z_][a-z0-9_]{0,62}$ ]]; then
        echo "$label is not a safe PostgreSQL identifier" >&2
        exit 1
    fi
}

wait_for_job() {
    local namespace="$1" job="$2" deadline=$((SECONDS + 180))
    while [[ $SECONDS -lt $deadline ]]; do
        local succeeded failed
        succeeded="$(kubectl_cmd get job "$job" -n "$namespace" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
        failed="$(kubectl_cmd get job "$job" -n "$namespace" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
        if [[ "$succeeded" == "1" ]]; then
            return 0
        fi
        if [[ -n "$failed" && "$failed" != "0" ]]; then
            return 1
        fi
        sleep 2
    done
    return 1
}

cleanup_provision_resources() {
    local job="$1" secret="$2"
    kubectl_cmd delete job "$job" -n "$DATA_NAMESPACE" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
    kubectl_cmd delete secret "$secret" -n "$DATA_NAMESPACE" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}

provision_one() {
    local app_name="$1" runtime_secret="$2" migration_secret="$3"
    local database runtime_role host port migration_role migration_password existing_url
    database="$(decode_secret_key "$APP_NAMESPACE" "$runtime_secret" APP_DB_NAME)"
    runtime_role="$(decode_secret_key "$APP_NAMESPACE" "$runtime_secret" APP_DB_USER)"
    host="$(decode_secret_key "$APP_NAMESPACE" "$runtime_secret" DB_HOST)"
    port="$(decode_secret_key "$APP_NAMESPACE" "$runtime_secret" DB_PORT)"
    require_identifier APP_DB_NAME "$database"
    require_identifier APP_DB_USER "$runtime_role"
    [[ "$port" =~ ^[0-9]{2,5}$ ]] || { echo "invalid DB_PORT for $app_name" >&2; exit 1; }

    existing_url="$(decode_secret_key "$APP_NAMESPACE" "$migration_secret" MIGRATION_DATABASE_URL 2>/dev/null || true)"
    if [[ -n "$existing_url" ]]; then
        local authority credentials
        authority="${existing_url#*://}"
        credentials="${authority%%@*}"
        migration_role="${credentials%%:*}"
        migration_password="${credentials#*:}"
        [[ "$migration_password" != "$credentials" ]] || {
            echo "existing migration URL has no password: $migration_secret" >&2
            exit 1
        }
    else
        migration_role="${runtime_role}_migration"
        migration_password="$(openssl rand -hex 32)"
    fi
    require_identifier MIGRATION_DB_USER "$migration_role"
    [[ "$migration_password" =~ ^[a-f0-9]{64}$ ]] || {
        echo "migration password must be a generated 64-character hex value" >&2
        exit 1
    }
    if [[ "$migration_role" == "$runtime_role" ]]; then
        echo "migration and runtime roles must differ: $app_name" >&2
        exit 1
    fi

    echo "PLAN app=$app_name database=$database runtime_role=$runtime_role migration_role=$migration_role"
    if [[ "$APPLY" != "true" ]]; then
        return 0
    fi

    local provision_secret="${app_name}-migration-provision"
    local provision_job="${app_name}-migration-role-provision"
    cleanup_provision_resources "$provision_job" "$provision_secret"

    cat <<EOF | kubectl_cmd apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${provision_secret}
  namespace: ${DATA_NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-005
type: Opaque
stringData:
  APP_DATABASE: "${database}"
  RUNTIME_ROLE: "${runtime_role}"
  MIGRATION_ROLE: "${migration_role}"
  MIGRATION_PASSWORD: "${migration_password}"
EOF

    cat <<EOF | kubectl_cmd apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${provision_job}
  namespace: ${DATA_NAMESPACE}
  labels:
    sunmoonai.com/task: v5-p0-005
    app.kubernetes.io/component: migration-role-provisioner
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 180
  template:
    metadata:
      labels:
        sunmoonai.com/task: v5-p0-005
        app.kubernetes.io/component: migration-role-provisioner
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
        - name: POSTGRES_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ${POSTGRES_ADMIN_SECRET}
              key: admin_password
        envFrom:
        - secretRef:
            name: ${provision_secret}
        command: ["/bin/bash", "-ec"]
        args:
        - |
          export PGPASSWORD="\$POSTGRES_ADMIN_PASSWORD"
          psql -h "${POSTGRES_SERVICE}" -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 \
            --set=migration_role="\$MIGRATION_ROLE" \
            --set=migration_password="\$MIGRATION_PASSWORD" \
            --set=runtime_role="\$RUNTIME_ROLE" \
            --set=app_database="\$APP_DATABASE" <<'SQL'
          SELECT format(
              'CREATE ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION',
              :'migration_role', :'migration_password'
          )
          WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'migration_role') \gexec
          SELECT format(
              'ALTER ROLE %I LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION',
              :'migration_role', :'migration_password'
          ) \gexec
          SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'app_database', :'migration_role') \gexec
          SELECT format('ALTER DATABASE %I OWNER TO %I', :'app_database', :'migration_role') \gexec
          \connect :app_database
          SELECT format('ALTER SCHEMA public OWNER TO %I', :'migration_role') \gexec
          SELECT format('ALTER TABLE %I.%I OWNER TO %I', n.nspname, c.relname, :'migration_role')
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'f') \gexec
          SELECT format('ALTER VIEW %I.%I OWNER TO %I', n.nspname, c.relname, :'migration_role')
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public' AND c.relkind = 'v' \gexec
          SELECT format('ALTER MATERIALIZED VIEW %I.%I OWNER TO %I', n.nspname, c.relname, :'migration_role')
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public' AND c.relkind = 'm' \gexec
          SELECT format('ALTER SEQUENCE %I.%I OWNER TO %I', n.nspname, c.relname, :'migration_role')
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public' AND c.relkind = 'S' \gexec
          SELECT format('ALTER TYPE %I.%I OWNER TO %I', n.nspname, t.typname, :'migration_role')
          FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
          WHERE n.nspname = 'public' AND t.typrelid = 0 AND t.typtype IN ('d', 'e') \gexec
          SELECT format(
              'ALTER %s %I.%I(%s) OWNER TO %I',
              CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
              n.nspname,
              p.proname,
              pg_get_function_identity_arguments(p.oid),
              :'migration_role'
          )
          FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
          WHERE n.nspname = 'public' \gexec
          SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'runtime_role') \gexec
          SELECT format(
              'GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO %I',
              :'runtime_role'
          ) \gexec
          SELECT format(
              'GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO %I',
              :'runtime_role'
          ) \gexec
          SELECT format('REVOKE CREATE ON SCHEMA public FROM %I', :'runtime_role') \gexec
          REVOKE CREATE ON SCHEMA public FROM PUBLIC;
          SELECT format(
              'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES TO %I',
              :'migration_role', :'runtime_role'
          ) \gexec
          SELECT format(
              'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO %I',
              :'migration_role', :'runtime_role'
          ) \gexec
          SQL
          can_create="\$(psql -h "${POSTGRES_SERVICE}" -p 5432 -U postgres -d "\$APP_DATABASE" -tAc \
            "SELECT has_schema_privilege('\$RUNTIME_ROLE', 'public', 'CREATE')")"
          [[ "\$can_create" == "f" ]]
          echo "migration role reconciled; runtime CREATE revoked"
EOF

    if ! wait_for_job "$DATA_NAMESPACE" "$provision_job"; then
        kubectl_cmd logs "job/$provision_job" -n "$DATA_NAMESPACE" --all-containers=true || true
        kubectl_cmd describe job "$provision_job" -n "$DATA_NAMESPACE" || true
        cleanup_provision_resources "$provision_job" "$provision_secret"
        echo "migration role provisioning failed: $app_name" >&2
        exit 1
    fi
    kubectl_cmd logs "job/$provision_job" -n "$DATA_NAMESPACE"

    local migration_url="postgresql+asyncpg://${migration_role}:${migration_password}@${host}:${port}/${database}"
    cat <<EOF | kubectl_cmd apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: ${migration_secret}
  namespace: ${APP_NAMESPACE}
  labels:
    app: ${app_name}
    app.kubernetes.io/component: database-migration
    sunmoonai.com/task: v5-p0-005
type: Opaque
stringData:
  MIGRATION_DATABASE_URL: "${migration_url}"
  MIGRATION_DATABASE_USER: "${migration_role}"
EOF
    unset migration_password migration_url existing_url
    cleanup_provision_resources "$provision_job" "$provision_secret"
    echo "APPLIED app=$app_name migration_secret=$APP_NAMESPACE/$migration_secret"
}

for command in kubectl base64 openssl; do
    command -v "$command" >/dev/null 2>&1 || { echo "missing command: $command" >&2; exit 1; }
done

kubectl_cmd get namespace "$APP_NAMESPACE" >/dev/null
kubectl_cmd get namespace "$DATA_NAMESPACE" >/dev/null
kubectl_cmd get secret "$POSTGRES_ADMIN_SECRET" -n "$DATA_NAMESPACE" >/dev/null

provision_one info-admin-backend \
    info-admin-backend-postgresql-conn \
    info-admin-backend-migration-postgresql-conn
provision_one knowledge-admin-backend \
    knowledge-admin-backend-postgresql-conn \
    knowledge-admin-backend-migration-postgresql-conn
provision_one research-admin-backend \
    research-admin-backend-postgresql-conn \
    research-admin-backend-migration-postgresql-conn

if [[ "$APPLY" == "true" ]]; then
    echo "V5-P0-005 migration roles reconciled without printing credentials"
else
    echo "PLAN ONLY: rerun with --apply after review"
fi
