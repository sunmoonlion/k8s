#!/usr/bin/env bash

# Shared local plan boundary: no configuration, credentials or API before this.
source "$(dirname -- "${BASH_SOURCE[0]}")/../../../../utils/deploy-plan.sh" || exit 2
sunmoon_deploy_entry "${BASH_SOURCE[0]}" named "$@" || exit $?
[[ "$SUNMOON_DEPLOY_PLAN_ONLY" != true ]] || exit 0
set -- "${SUNMOON_DEPLOY_EXEC_ARGS[@]}"

set -euo pipefail
set +x
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROVISIONER_SCRIPT_DIR="$SCRIPT_DIR"

PROVISIONER_K8S_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
source "$PROVISIONER_K8S_ROOT/utils/cluster-arg-parser.sh"
unified_parse_cluster_arg "$@"
ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
if [[ "${ORIGINAL_ARGS[0]:-}" == validate ]]; then
    [[ ${#ORIGINAL_ARGS[@]} == 2 ]] || { echo 'validate requires one declaration' >&2; exit 2; }
    exec python3 -B "$SCRIPT_DIR/lib/declaration.py" validate "${ORIGINAL_ARGS[1]}"
fi
[[ ${#ORIGINAL_ARGS[@]} == 2 ]] || { echo 'Expected action and declaration' >&2; exit 2; }
case "${ORIGINAL_ARGS[0]}" in provision|rotate|status|teardown) ;; *) echo 'Unsupported provisioner action' >&2; exit 2 ;; esac
[[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]] || { echo 'Explicit CLUSTER required' >&2; exit 1; }
source "$PROVISIONER_K8S_ROOT/utils/deploy-target.sh"
sunmoon_deploy_target_init "$PROVISIONER_K8S_ROOT" || exit 1
source "$PROVISIONER_K8S_ROOT/utils/provisioner-runtime.sh"


OBJECT_STORAGE_CONFIG_FILE="$PROJECT_ROOT/deploy-object-storage/deploy-object-storage.conf"
HELPER="$SCRIPT_DIR/lib/declaration.py"
if [[ ! -f "$OBJECT_STORAGE_CONFIG_FILE" ]]; then
    log_error "缺少 Object Storage 配置文件: $OBJECT_STORAGE_CONFIG_FILE"
    exit 1
fi
source "$OBJECT_STORAGE_CONFIG_FILE" >/dev/null 2>&1 || { echo "Object storage configuration failed" >&2; exit 1; }

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
    sunmoon_deploy_target_check "$PROVISIONER_K8S_ROOT"
}

cleanup_runtime_resources() {
    local result=$?
    trap - EXIT
    if [[ "$result" != 0 ]]; then
        log_error "Provisioning failed; preserve recovery material: $WORK_DIR; job=$JOB_NAME; runtime-secret=$RUNTIME_SECRET"
        exit "$result"
    fi
    if [[ -n "$JOB_NAME" ]]; then
        provisioner_kube delete job "$JOB_NAME" -n "$DATA_NAMESPACE" --ignore-not-found --wait=false >/dev/null || result=1
    fi
    if [[ -n "$RUNTIME_CONFIGMAP" ]]; then
        provisioner_kube delete configmap "$RUNTIME_CONFIGMAP" -n "$DATA_NAMESPACE" --ignore-not-found --wait=false >/dev/null || result=1
    fi
    if [[ -n "$RUNTIME_SECRET" && "$result" == 0 ]]; then
        provisioner_kube delete secret "$RUNTIME_SECRET" -n "$DATA_NAMESPACE" --ignore-not-found --wait=false >/dev/null || result=1
    fi
    if [[ "$result" == 0 && -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR"
    fi
    [[ "$result" == 0 ]] || log_error "Runtime cleanup incomplete; preserve $WORK_DIR for recovery"
    exit "$result"
}

load_declaration() {
    local declaration="$1"
    [[ -f "$declaration" ]] || die "声明文件不存在: $declaration"
    require_command python3
    python3 -B "$HELPER" validate "$declaration" >/dev/null

    WORK_DIR="$(mktemp -d)"
    python3 -B "$HELPER" shell "$declaration" > "$WORK_DIR/declaration.env"
    # shellcheck disable=SC1091
    source "$WORK_DIR/declaration.env"
    python3 -B "$HELPER" policy "$declaration" > "$WORK_DIR/policy.json"

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

    local existing_name
    existing_name=$(provisioner_kube get secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" -o name --ignore-not-found) || return 1
    if [[ "$rotate" != true && -n "$existing_name" ]]; then
        existing_access="$(provisioner_kube get secret "$TARGET_SECRET_NAME" \
            -n "$TARGET_NAMESPACE" -o jsonpath='{.data.S3_ACCESS_KEY_ID}' | base64 -d)"
        existing_secret="$(provisioner_kube get secret "$TARGET_SECRET_NAME" \
            -n "$TARGET_NAMESPACE" -o jsonpath='{.data.S3_SECRET_ACCESS_KEY}' | base64 -d)"
    fi

    if [[ "$rotate" != true && -n "$existing_name" && ( -z "$existing_access" || -z "$existing_secret" ) ]]; then
        die 'Existing S3 Secret is incomplete; refusing implicit credential rotation'
    fi
    if [[ -n "$existing_access" && -n "$existing_secret" ]]; then
        [[ "$existing_access" == "$DECLARATION_NAME" ]] || die 'Existing access key differs from declaration identity'
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
if [ "$UPDATE_USER" = "true" ]; then
    # Listing must succeed; authentication/network errors are never 'user absent'.
    mc --json admin user list platform > /tmp/sunmoon-users.json
    if [ -s /tmp/sunmoon-users.json ] && ! grep -q '"accessKey"' /tmp/sunmoon-users.json; then
        echo "Unsupported administrative response; refusing user changes" >&2
        exit 1
    fi
    if [ "$OPERATION" != "rotate" ] && grep -Eq '"accessKey"[[:space:]]*:[[:space:]]*"'"$APP_ACCESS_KEY"'"' /tmp/sunmoon-users.json; then
        echo "Remote user exists without matching saved credentials; explicit recovery or rotation required" >&2
        exit 1
    fi
    printf '%s\n%s\n' "$APP_ACCESS_KEY" "$APP_SECRET_KEY" | mc admin user add platform >/dev/null
else
    mc admin user info platform "$APP_ACCESS_KEY" >/dev/null
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
mc admin user info platform "$APP_ACCESS_KEY" >/dev/null
mc admin policy info platform "$POLICY_NAME" >/dev/null
mc admin policy detach platform "$POLICY_NAME" --user "$APP_ACCESS_KEY"
mc admin user rm platform "$APP_ACCESS_KEY"
mc admin policy rm platform "$POLICY_NAME"
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
    JOB_NAME="s3-${action}-${DECLARATION_NAME:0:24}-${suffix}"
    JOB_NAME="${JOB_NAME:0:63}"
    RUNTIME_CONFIGMAP="${JOB_NAME}-work"
    RUNTIME_CONFIGMAP="${RUNTIME_CONFIGMAP:0:63}"
    RUNTIME_SECRET="${JOB_NAME}-credentials"
    RUNTIME_SECRET="${RUNTIME_SECRET:0:63}"

    provisioner_kube create configmap "$RUNTIME_CONFIGMAP" \
        -n "$DATA_NAMESPACE" \
        --from-file=run.sh="$WORK_DIR/run.sh" \
        --from-file=policy.json="$WORK_DIR/policy.json"
    builtin printf '%s\0' accessKey "$ACCESS_KEY" secretKey "$SECRET_KEY" | \
        provisioner_secret --namespace "$DATA_NAMESPACE" --name "$RUNTIME_SECRET"
}

run_admin_job() {
    local action="$1"
    local timeout="${OBJECT_STORAGE_PROVISIONER_TIMEOUT:-180s}"
    [[ "$timeout" =~ ^([1-9][0-9]{0,2})s$ && "${timeout%s}" -le 300 ]] || die 'Provisioner timeout must be 1s..300s'

    provisioner_kube apply -f - <<EOF
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
  activeDeadlineSeconds: 300
  template:
    metadata:
      labels:
        app.kubernetes.io/name: object-storage-provisioner
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
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
            - name: OPERATION
              value: "${action}"
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

    if ! provisioner_kube wait --for=condition=complete "job/$JOB_NAME" \
        -n "$DATA_NAMESPACE" --timeout="$timeout"; then
        log_error "Job failed or timed out: $DATA_NAMESPACE/$JOB_NAME; raw logs withheld, recovery resources retained"
        return 1
    fi
    log_info "Administrative Job completed: $DATA_NAMESPACE/$JOB_NAME; raw logs withheld"
}

apply_backend_resources() {
    local buckets primary_bucket
    buckets="$(bucket_names_csv)"
    primary_bucket="${buckets%%,*}"

    builtin printf '%s\0' S3_ACCESS_KEY_ID "$ACCESS_KEY" S3_SECRET_ACCESS_KEY "$SECRET_KEY" | \
        provisioner_secret --namespace "$TARGET_NAMESPACE" --name "$TARGET_SECRET_NAME"

    provisioner_kube create configmap "$TARGET_CONFIGMAP_NAME" \
        -n "$TARGET_NAMESPACE" \
        --from-literal=S3_ENDPOINT="$S3_ENDPOINT" \
        --from-literal=S3_REGION="$S3_REGION" \
        --from-literal=S3_BUCKET="$primary_bucket" \
        --from-literal=S3_BUCKETS="$buckets" \
        --from-literal=S3_FORCE_PATH_STYLE="$S3_FORCE_PATH_STYLE" \
        --from-literal=S3_USE_TLS="$S3_USE_TLS" \
        --dry-run=client -o yaml | provisioner_kube apply -f -
}

remove_backend_resources() {
    provisioner_kube delete secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found
    provisioner_kube delete configmap "$TARGET_CONFIGMAP_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found
}

preflight() {
    require_command "$SUNMOON_KUBECTL"
    require_command base64
    ensure_cluster_connection
    provisioner_kube get namespace "$DATA_NAMESPACE" >/dev/null
    provisioner_kube get namespace "$TARGET_NAMESPACE" >/dev/null
    provisioner_kube get secret "$ROOT_SECRET_NAME" -n "$DATA_NAMESPACE" >/dev/null
    provisioner_kube get secret "$IMAGE_PULL_SECRET" -n "$DATA_NAMESPACE" >/dev/null
    provisioner_kube get service minio -n "$DATA_NAMESPACE" >/dev/null
}

execute_action() {
    local action="$1"
    local declaration="$2"

    load_declaration "$declaration"
    if [[ "$action" == "validate" ]]; then
        python3 -B "$HELPER" validate "$declaration"
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
