#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROVISIONER_SCRIPT_DIR="$SCRIPT_DIR"

source "$PROJECT_ROOT/../../../utils/unified-deployment-template.sh"
SCRIPT_DIR="$PROVISIONER_SCRIPT_DIR"

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]] && type unified_parse_cluster_arg >/dev/null 2>&1; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

OBJECT_STORAGE_CONFIG_FILE="$PROJECT_ROOT/deploy-object-storage/deploy-object-storage.conf"
HELPER="$SCRIPT_DIR/lib/declaration.py"
if [[ ! -f "$OBJECT_STORAGE_CONFIG_FILE" ]]; then
    log_error "缺少 Object Storage 配置文件: $OBJECT_STORAGE_CONFIG_FILE"
    exit 1
fi
source "$OBJECT_STORAGE_CONFIG_FILE"

if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

case "$(printf '%s' "${CLUSTER:-}" | tr '[:lower:]' '[:upper:]')" in
    KIND) export K8S_TARGET_MODE="kind" ;;
    C[0-9]*) export K8S_TARGET_MODE="remote" ;;
esac

DATA_NAMESPACE="${OBJECT_STORAGE_NAMESPACE:-data-platform-dev}"
ROOT_SECRET_NAME="${OBJECT_STORAGE_ROOT_SECRET_NAME:-object-storage-root-credentials}"
IMAGE_PULL_SECRET="${OBJECT_STORAGE_IMAGE_PULL_SECRET_NAME:-harbor-registry-secret}"
PROVISIONER_IMAGE="${OBJECT_STORAGE_PROVISIONER_IMAGE}"
S3_ENDPOINT="${OBJECT_STORAGE_S3_INTERNAL_ENDPOINT}"

WORK_DIR=""
JOB_NAME=""
RUNTIME_CONFIGMAP=""
RUNTIME_SECRET=""

die() {
    log_error "$*"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

ensure_cluster_connection() {
    if kubectl get nodes >/dev/null 2>&1; then
        return 0
    fi
    setup_kubectl_environment
    kubectl get nodes >/dev/null
}

cleanup_runtime_resources() {
    if [[ -n "$JOB_NAME" ]]; then
        kubectl delete job "$JOB_NAME" -n "$DATA_NAMESPACE" \
            --ignore-not-found --wait=false >/dev/null 2>&1 || true
    fi
    if [[ -n "$RUNTIME_CONFIGMAP" ]]; then
        kubectl delete configmap "$RUNTIME_CONFIGMAP" -n "$DATA_NAMESPACE" \
            --ignore-not-found >/dev/null 2>&1 || true
    fi
    if [[ -n "$RUNTIME_SECRET" ]]; then
        kubectl delete secret "$RUNTIME_SECRET" -n "$DATA_NAMESPACE" \
            --ignore-not-found >/dev/null 2>&1 || true
    fi
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

load_declaration() {
    local declaration="$1"
    [[ -f "$declaration" ]] || die "声明文件不存在: $declaration"
    require_command python3
    python3 "$HELPER" validate "$declaration" >/dev/null

    WORK_DIR="$(mktemp -d)"
    python3 "$HELPER" shell "$declaration" > "$WORK_DIR/declaration.env"
    # shellcheck disable=SC1091
    source "$WORK_DIR/declaration.env"
    python3 "$HELPER" policy "$declaration" > "$WORK_DIR/policy.json"

    POLICY_NAME="$DECLARATION_NAME"
    ACCESS_KEY="$DECLARATION_NAME"
}

bucket_names_csv() {
    local result=""
    local index name_var name
    for ((index = 0; index < BUCKET_COUNT; index++)); do
        name_var="BUCKET_${index}_NAME"
        name="${!name_var}"
        [[ -n "$result" ]] && result+=","
        result+="$name"
    done
    printf '%s\n' "$result"
}

load_or_generate_credentials() {
    local rotate="$1"
    local existing_access=""
    local existing_secret=""

    if [[ "$rotate" != "true" ]] && kubectl get secret "$TARGET_SECRET_NAME" \
        -n "$TARGET_NAMESPACE" >/dev/null 2>&1; then
        existing_access="$(kubectl get secret "$TARGET_SECRET_NAME" \
            -n "$TARGET_NAMESPACE" -o jsonpath='{.data.S3_ACCESS_KEY_ID}' | base64 -d)"
        existing_secret="$(kubectl get secret "$TARGET_SECRET_NAME" \
            -n "$TARGET_NAMESPACE" -o jsonpath='{.data.S3_SECRET_ACCESS_KEY}' | base64 -d)"
    fi

    if [[ -n "$existing_access" && -n "$existing_secret" ]]; then
        ACCESS_KEY="$existing_access"
        SECRET_KEY="$existing_secret"
        UPDATE_USER="false"
    else
        require_command openssl
        SECRET_KEY="$(openssl rand -hex 24)"
        UPDATE_USER="true"
    fi
}

write_job_script() {
    local action="$1"
    local index name_var version_var lock_var bucket versioning object_lock

    cat > "$WORK_DIR/run.sh" <<'EOF'
#!/bin/sh
set -eu

. /root-credentials/config.env
APP_ACCESS_KEY="$(cat /app-credentials/accessKey)"
APP_SECRET_KEY="$(cat /app-credentials/secretKey)"

mc alias set platform "$S3_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
EOF

    case "$action" in
        provision|rotate)
            for ((index = 0; index < BUCKET_COUNT; index++)); do
                name_var="BUCKET_${index}_NAME"
                version_var="BUCKET_${index}_VERSIONING"
                lock_var="BUCKET_${index}_OBJECT_LOCK"
                bucket="${!name_var}"
                versioning="${!version_var}"
                object_lock="${!lock_var}"

                if [[ "$object_lock" == "true" ]]; then
                    printf 'mc mb --ignore-existing --with-lock --region "$S3_REGION" platform/%q\n' \
                        "$bucket" >> "$WORK_DIR/run.sh"
                elif [[ "$versioning" == "true" ]]; then
                    printf 'mc mb --ignore-existing --with-versioning --region "$S3_REGION" platform/%q\n' \
                        "$bucket" >> "$WORK_DIR/run.sh"
                else
                    printf 'mc mb --ignore-existing --region "$S3_REGION" platform/%q\n' \
                        "$bucket" >> "$WORK_DIR/run.sh"
                fi
                if [[ "$versioning" == "true" ]]; then
                    printf 'mc version enable platform/%q\n' "$bucket" >> "$WORK_DIR/run.sh"
                fi
            done

            cat >> "$WORK_DIR/run.sh" <<'EOF'
mc admin policy create platform "$POLICY_NAME" /work/policy.json
if [ "$UPDATE_USER" = "true" ] || ! mc admin user info platform "$APP_ACCESS_KEY" >/dev/null 2>&1; then
    mc admin user add platform "$APP_ACCESS_KEY" "$APP_SECRET_KEY"
fi
mc admin policy attach platform "$POLICY_NAME" --user "$APP_ACCESS_KEY"
mc admin user info platform "$APP_ACCESS_KEY"
mc admin policy info platform "$POLICY_NAME"
EOF
            ;;
        status)
            cat >> "$WORK_DIR/run.sh" <<'EOF'
mc admin user info platform "$APP_ACCESS_KEY"
mc admin policy info platform "$POLICY_NAME"
EOF
            for ((index = 0; index < BUCKET_COUNT; index++)); do
                name_var="BUCKET_${index}_NAME"
                version_var="BUCKET_${index}_VERSIONING"
                bucket="${!name_var}"
                versioning="${!version_var}"
                printf 'mc stat platform/%q\n' "$bucket" >> "$WORK_DIR/run.sh"
                if [[ "$versioning" == "true" ]]; then
                    printf 'mc version info platform/%q\n' "$bucket" >> "$WORK_DIR/run.sh"
                fi
            done
            ;;
        teardown)
            cat >> "$WORK_DIR/run.sh" <<'EOF'
if mc admin user info platform "$APP_ACCESS_KEY" >/dev/null 2>&1; then
    mc admin policy detach platform "$POLICY_NAME" --user "$APP_ACCESS_KEY" || true
    mc admin user rm platform "$APP_ACCESS_KEY"
fi
if mc admin policy info platform "$POLICY_NAME" >/dev/null 2>&1; then
    mc admin policy rm platform "$POLICY_NAME"
fi
echo "Buckets retained by deletionPolicy=Retain"
EOF
            ;;
        *)
            die "不支持的 Job action: $action"
            ;;
    esac
    chmod 0700 "$WORK_DIR/run.sh"
}

create_runtime_resources() {
    local action="$1"
    local suffix
    suffix="$(date +%s)-$RANDOM"
    JOB_NAME="s3-${action}-${DECLARATION_NAME}-${suffix}"
    JOB_NAME="${JOB_NAME:0:63}"
    RUNTIME_CONFIGMAP="${JOB_NAME}-work"
    RUNTIME_CONFIGMAP="${RUNTIME_CONFIGMAP:0:63}"
    RUNTIME_SECRET="${JOB_NAME}-credentials"
    RUNTIME_SECRET="${RUNTIME_SECRET:0:63}"

    kubectl create configmap "$RUNTIME_CONFIGMAP" \
        -n "$DATA_NAMESPACE" \
        --from-file=run.sh="$WORK_DIR/run.sh" \
        --from-file=policy.json="$WORK_DIR/policy.json"
    kubectl create secret generic "$RUNTIME_SECRET" \
        -n "$DATA_NAMESPACE" \
        --from-literal=accessKey="$ACCESS_KEY" \
        --from-literal=secretKey="$SECRET_KEY"
}

run_admin_job() {
    local action="$1"
    local timeout="${OBJECT_STORAGE_PROVISIONER_TIMEOUT:-180s}"

    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${DATA_NAMESPACE}
  labels:
    app.kubernetes.io/name: object-storage-provisioner
    storage.sunmoonai.com/declaration: ${DECLARATION_NAME}
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    metadata:
      labels:
        app.kubernetes.io/name: object-storage-provisioner
    spec:
      restartPolicy: Never
      imagePullSecrets:
        - name: ${IMAGE_PULL_SECRET}
      containers:
        - name: mc
          image: ${PROVISIONER_IMAGE}
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh", "/work/run.sh"]
          env:
            - name: MC_CONFIG_DIR
              value: "/tmp/.mc"
            - name: S3_ENDPOINT
              value: "${S3_ENDPOINT}"
            - name: S3_REGION
              value: "${S3_REGION}"
            - name: POLICY_NAME
              value: "${POLICY_NAME}"
            - name: UPDATE_USER
              value: "${UPDATE_USER}"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            runAsNonRoot: true
            runAsUser: 1000
            runAsGroup: 1000
            seccompProfile:
              type: RuntimeDefault
          volumeMounts:
            - name: work
              mountPath: /work
              readOnly: true
            - name: root-credentials
              mountPath: /root-credentials
              readOnly: true
            - name: app-credentials
              mountPath: /app-credentials
              readOnly: true
      volumes:
        - name: work
          configMap:
            name: ${RUNTIME_CONFIGMAP}
            defaultMode: 0555
        - name: root-credentials
          secret:
            secretName: ${ROOT_SECRET_NAME}
        - name: app-credentials
          secret:
            secretName: ${RUNTIME_SECRET}
EOF

    if ! kubectl wait --for=condition=complete "job/$JOB_NAME" \
        -n "$DATA_NAMESPACE" --timeout="$timeout"; then
        kubectl logs -n "$DATA_NAMESPACE" "job/$JOB_NAME" --all-containers=true || true
        return 1
    fi
    kubectl logs -n "$DATA_NAMESPACE" "job/$JOB_NAME" --all-containers=true
}

apply_backend_resources() {
    local buckets primary_bucket
    buckets="$(bucket_names_csv)"
    primary_bucket="${buckets%%,*}"

    kubectl create secret generic "$TARGET_SECRET_NAME" \
        -n "$TARGET_NAMESPACE" \
        --from-literal=S3_ACCESS_KEY_ID="$ACCESS_KEY" \
        --from-literal=S3_SECRET_ACCESS_KEY="$SECRET_KEY" \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl create configmap "$TARGET_CONFIGMAP_NAME" \
        -n "$TARGET_NAMESPACE" \
        --from-literal=S3_ENDPOINT="$S3_ENDPOINT" \
        --from-literal=S3_REGION="$S3_REGION" \
        --from-literal=S3_BUCKET="$primary_bucket" \
        --from-literal=S3_BUCKETS="$buckets" \
        --from-literal=S3_FORCE_PATH_STYLE="$S3_FORCE_PATH_STYLE" \
        --from-literal=S3_USE_TLS="$S3_USE_TLS" \
        --dry-run=client -o yaml | kubectl apply -f -
}

remove_backend_resources() {
    kubectl delete secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found
    kubectl delete configmap "$TARGET_CONFIGMAP_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found
}

preflight() {
    require_command kubectl
    require_command base64
    ensure_cluster_connection
    kubectl get namespace "$DATA_NAMESPACE" >/dev/null
    kubectl get namespace "$TARGET_NAMESPACE" >/dev/null
    kubectl get secret "$ROOT_SECRET_NAME" -n "$DATA_NAMESPACE" >/dev/null
    kubectl get secret "$IMAGE_PULL_SECRET" -n "$DATA_NAMESPACE" >/dev/null
    kubectl get service minio -n "$DATA_NAMESPACE" >/dev/null
}

execute_action() {
    local action="$1"
    local declaration="$2"

    load_declaration "$declaration"
    if [[ "$action" == "validate" ]]; then
        python3 "$HELPER" validate "$declaration"
        return
    fi

    preflight
    case "$action" in
        provision)
            load_or_generate_credentials "false"
            ;;
        rotate)
            load_or_generate_credentials "true"
            ;;
        status|teardown)
            ACCESS_KEY="$DECLARATION_NAME"
            SECRET_KEY="not-used-by-${action}"
            UPDATE_USER="false"
            ;;
        *)
            die "不支持的 action: $action"
            ;;
    esac

    write_job_script "$action"
    create_runtime_resources "$action"
    run_admin_job "$action"

    case "$action" in
        provision|rotate)
            apply_backend_resources
            log_success "S3 访问资源已下发: $TARGET_NAMESPACE/$TARGET_SECRET_NAME"
            ;;
        teardown)
            remove_backend_resources
            log_success "S3 用户、Policy 和目标配置已回收，Bucket 数据已保留"
            ;;
    esac
}

usage() {
    cat <<EOF
用法:
  $0 [--cluster KIND] validate DECLARATION.json
  $0 [--cluster KIND] provision DECLARATION.json
  $0 [--cluster KIND] status DECLARATION.json
  $0 [--cluster KIND] rotate DECLARATION.json
  $0 [--cluster KIND] teardown DECLARATION.json
EOF
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    local action="${1:-}"
    local declaration="${2:-}"
    if [[ -z "$action" || -z "$declaration" ]]; then
        usage
        return 1
    fi

    trap cleanup_runtime_resources EXIT
    execute_action "$action" "$declaration"
}

main "$@"
