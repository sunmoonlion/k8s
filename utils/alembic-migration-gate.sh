#!/usr/bin/env bash

# Shared Alembic migration gate for Python Admin backends.
#
# This helper is sourced by the component deployment scripts.  It deliberately
# runs before the Deployment is applied, uses a dedicated migration Secret, and
# refuses to fall back to the runtime DATABASE_URL.

run_alembic_migration_gate() {
    local namespace="$1"
    local app_name="$2"
    local image="$3"
    local image_pull_secret="$4"
    local configmap_name="$5"
    local app_secret_name="$6"
    local runtime_database_secret="$7"
    local migration_database_secret="$8"
    local job_name="${app_name}-migration-gate"
    local timeout_seconds="${ALEMBIC_MIGRATION_GATE_TIMEOUT_SECONDS:-300}"
    local migration_url

    if [[ -z "$migration_database_secret" || "$migration_database_secret" == "$runtime_database_secret" ]]; then
        log_error "迁移门禁要求独立于运行时数据库 Secret: app=$app_name"
        return 1
    fi

    if ! kubectl get secret "$migration_database_secret" -n "$namespace" >/dev/null 2>&1; then
        log_error "迁移 Secret 不存在: $namespace/$migration_database_secret"
        log_error "拒绝部署 $app_name；请先运行 V5-P0-005 migration-role provisioner"
        return 1
    fi
    migration_url="$(kubectl get secret "$migration_database_secret" -n "$namespace" \
        -o jsonpath='{.data.MIGRATION_DATABASE_URL}' 2>/dev/null || true)"
    if [[ -z "$migration_url" ]]; then
        log_error "迁移 Secret 缺少非空 MIGRATION_DATABASE_URL: $namespace/$migration_database_secret"
        return 1
    fi
    unset migration_url

    log_info "执行 Alembic 迁移门禁: $namespace/$job_name"
    kubectl delete job "$job_name" -n "$namespace" --ignore-not-found=true --wait=true >/dev/null

    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job_name}
  namespace: ${namespace}
  labels:
    app: ${app_name}
    app.kubernetes.io/component: database-migration
    sunmoonai.com/gate: alembic
spec:
  backoffLimit: 0
  activeDeadlineSeconds: ${timeout_seconds}
  template:
    metadata:
      labels:
        app: ${app_name}
        app.kubernetes.io/component: database-migration
        sunmoonai.com/gate: alembic
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      imagePullSecrets:
      - name: ${image_pull_secret}
      containers:
      - name: migrate
        image: ${image}
        imagePullPolicy: IfNotPresent
        command: ["/bin/sh", "-ec"]
        args:
        - |
          cd /app
          .venv/bin/python - <<'PY'
          import os
          from sqlalchemy.engine import make_url
          from core.config import get_settings

          settings = get_settings()
          migration_url = getattr(settings, "migration_database_url", None)
          if not migration_url:
              raise SystemExit("migration gate: image does not resolve MIGRATION_DATABASE_URL")
          migration_user = make_url(migration_url).username
          runtime_user = make_url(settings.database_url).username
          expected_user = os.environ.get("MIGRATION_DATABASE_USER")
          if not migration_user or migration_user == runtime_user:
              raise SystemExit("migration gate: migration and runtime database users must differ")
          if not expected_user or migration_user != expected_user:
              raise SystemExit("migration gate: resolved migration user does not match Secret metadata")
          print(f"migration identity verified: user={migration_user}")
          PY
          .venv/bin/alembic upgrade head
          .venv/bin/alembic current
        envFrom:
        - configMapRef:
            name: ${configmap_name}
        - secretRef:
            name: ${app_secret_name}
        - secretRef:
            name: ${runtime_database_secret}
        - secretRef:
            name: ${migration_database_secret}
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
EOF

    local deadline=$((SECONDS + timeout_seconds))
    while [[ $SECONDS -lt $deadline ]]; do
        local succeeded failed
        succeeded="$(kubectl get job "$job_name" -n "$namespace" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)"
        failed="$(kubectl get job "$job_name" -n "$namespace" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
        if [[ "$succeeded" == "1" ]]; then
            kubectl logs "job/$job_name" -n "$namespace"
            log_success "Alembic 迁移门禁通过: $namespace/$job_name"
            return 0
        fi
        if [[ -n "$failed" && "$failed" != "0" ]]; then
            kubectl logs "job/$job_name" -n "$namespace" --all-containers=true || true
            kubectl describe job "$job_name" -n "$namespace" || true
            log_error "Alembic 迁移门禁失败: $namespace/$job_name"
            return 1
        fi
        sleep 2
    done

    kubectl logs "job/$job_name" -n "$namespace" --all-containers=true || true
    kubectl describe job "$job_name" -n "$namespace" || true
    log_error "Alembic 迁移门禁超时: $namespace/$job_name"
    return 1
}
