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
case "${ORIGINAL_ARGS[0]}" in provision|rotate|status|revoke) ;; *) echo 'Unsupported provisioner action' >&2; exit 2 ;; esac
[[ "${CLUSTER:-}" =~ ^(KIND|C[1-9][0-9]*)$ ]] || { echo 'Explicit CLUSTER required' >&2; exit 1; }
source "$PROVISIONER_K8S_ROOT/utils/deploy-target.sh"
sunmoon_deploy_target_init "$PROVISIONER_K8S_ROOT" || exit 1
source "$PROVISIONER_K8S_ROOT/utils/provisioner-runtime.sh"


if [[ -f "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/../../../utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping
fi

HELPER="$SCRIPT_DIR/lib/declaration.py"
DATA_NAMESPACE="data-platform-dev"
ADMIN_SECRET="elasticsearch-secrets"
CA_SECRET="elasticsearch-sunmoonai-master-crt"
SERVICE_NAME="elasticsearch-sunmoonai"
SERVICE_HOST="$SERVICE_NAME.$DATA_NAMESPACE.svc.cluster.local"
LOCAL_PORT="${ELASTICSEARCH_PROVISIONER_PORT:-}"
CONNECT_TIMEOUT="${ELASTICSEARCH_PROVISIONER_CONNECT_TIMEOUT:-120}"
WORK_DIR=""
PORT_FORWARD_PID=""

die() {
    log_error "$*"
    exit 1
}

cleanup() {
    local result=$?
    trap - EXIT
    if [[ -n "$PORT_FORWARD_PID" ]]; then
        kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
        wait "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
    fi
    if [[ "$result" == 0 && -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf -- "$WORK_DIR"
    elif [[ "$result" != 0 ]]; then
        log_error "Elasticsearch operation failed; private recovery material retained: $WORK_DIR"
    fi
    exit "$result"
}
trap cleanup EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

choose_local_port() {
    [[ "$CONNECT_TIMEOUT" =~ ^[1-9][0-9]{0,2}$ && "$CONNECT_TIMEOUT" -le 300 ]] || die "Connection timeout must be 1..300 seconds"
    if [[ -n "$LOCAL_PORT" ]]; then
        [[ "$LOCAL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$LOCAL_PORT" -le 65535 ]] || die "Invalid local port"
        return
    fi
    require_command python3
    LOCAL_PORT="$(python3 - <<'PY'
import socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind(("127.0.0.1", 0))
    print(s.getsockname()[1])
PY
)"
    log_info "Elasticsearch provisioner 使用本地临时端口: $LOCAL_PORT"
}

ensure_cluster_connection() {
    sunmoon_deploy_target_check "$PROVISIONER_K8S_ROOT"
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
    python3 -B "$HELPER" render "$declaration" "$WORK_DIR"
}

load_admin_material() {
    ADMIN_PASSWORD="$(provisioner_kube get secret "$ADMIN_SECRET" -n "$DATA_NAMESPACE" \
        -o jsonpath='{.data.elasticsearch-password}' | base64 -d)"
    [[ -n "$ADMIN_PASSWORD" ]] || die "管理员密码为空"
    provisioner_kube get secret "$CA_SECRET" -n "$DATA_NAMESPACE" \
        -o jsonpath='{.data.ca\.crt}' | base64 -d > "$WORK_DIR/ca.crt"
    chmod 0600 "$WORK_DIR/ca.crt"
    builtin printf '%s\0' "$ADMIN_PASSWORD" "$WORK_DIR/ca.crt" | python3 -B -c '
import json,sys
password,ca,tail=sys.stdin.buffer.read(131073).split(b"\0")
if tail or not password or any(c in password for c in (b"\n",b"\r")):
    raise SystemExit("Invalid administrator credentials")
print("silent\nshow-error\nfail-with-body\nconnect-timeout = 2\nmax-time = 15\nnoproxy = \"*\"")
print("cacert = " + json.dumps(ca.decode()))
print("user = " + json.dumps("elastic:" + password.decode()))
' > "$WORK_DIR/curl.conf"
    chmod 0600 "$WORK_DIR/curl.conf"
}

start_port_forward() {
    local deadline=$((SECONDS + CONNECT_TIMEOUT))
    : > "$WORK_DIR/port-forward.log"

    while (( SECONDS < deadline )); do
        if [[ -z "$PORT_FORWARD_PID" ]] || ! kill -0 "$PORT_FORWARD_PID" >/dev/null 2>&1; then
            if [[ -n "$PORT_FORWARD_PID" ]]; then
                wait "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
            fi
            provisioner_kube port-forward --address 127.0.0.1 "service/$SERVICE_NAME" "$LOCAL_PORT:9200" \
                -n "$DATA_NAMESPACE" >> "$WORK_DIR/port-forward.log" 2>&1 &
            PORT_FORWARD_PID=$!
            sleep 1
        fi

        if curl --config "$WORK_DIR/curl.conf" \
            --resolve "$SERVICE_HOST:$LOCAL_PORT:127.0.0.1" \
            "https://$SERVICE_HOST:$LOCAL_PORT/_cluster/health" >/dev/null 2>&1; then
            return
        fi
        sleep 1
    done

    log_error 'Port forward did not become usable; private diagnostics retained in work directory'
    die "等待 Elasticsearch 连接超时 (${CONNECT_TIMEOUT}s)"
}

api() {
    local method="$1" path="$2" body="${3:-}" attempt status_code result
    local max_attempts="${ELASTICSEARCH_PROVISIONER_API_RETRIES:-10}"
    [[ "$max_attempts" =~ ^[0-9]+$ && "$max_attempts" -ge 1 && "$max_attempts" -le 10 ]] || return 1
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        sunmoon_deploy_target_check "$PROVISIONER_K8S_ROOT" || return 1
        if [[ -z "$PORT_FORWARD_PID" ]] || ! kill -0 "$PORT_FORWARD_PID" >/dev/null 2>&1; then
            start_port_forward || return 1
        fi
        local -a args=(--config "$WORK_DIR/curl.conf" -X "$method"
            --resolve "$SERVICE_HOST:$LOCAL_PORT:127.0.0.1"
            --output "$WORK_DIR/response.json" --write-out '%{http_code}')
        [[ -z "$body" ]] || args+=(-H 'Content-Type: application/json' --data-binary "@$body")
        result=0
        status_code=$(curl "${args[@]}" "https://$SERVICE_HOST:$LOCAL_PORT$path" 2>/dev/null) || result=$?
        if [[ "$result" == 0 && "$status_code" =~ ^2[0-9][0-9]$ ]]; then
            cat "$WORK_DIR/response.json"
            return 0
        fi
        [[ "$status_code" != 404 ]] || return 44
        if [[ "$status_code" != 000 && "$status_code" != 429 && ! "$status_code" =~ ^5[0-9][0-9]$ ]]; then
            log_error 'Elasticsearch request rejected; private response withheld'
            return 1
        fi
        (( attempt == max_attempts )) || sleep 2
    done
    log_error 'Elasticsearch request failed after bounded retries; private response withheld'
    return 1
}

load_or_generate_password() {
    local rotate="$1"
    ES_PASSWORD=""
    local existing_name existing_user remote_result=0
    existing_name=$(provisioner_kube get secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" -o name --ignore-not-found) || return 1
    if [[ -n "$existing_name" ]]; then
        existing_user="$(provisioner_kube get secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" -o jsonpath='{.data.ELASTICSEARCH_USERNAME}' | base64 -d)"
        [[ "$existing_user" == "$ES_USERNAME" ]] || die 'Existing Elasticsearch Secret belongs to another user'
    elif [[ "$rotate" != true ]]; then
        api GET "/_security/user/$ES_USERNAME" >/dev/null || remote_result=$?
        [[ "$remote_result" == 44 ]] || die 'User lookup did not confirm absence; recover credentials or explicitly rotate'
    fi
    if [[ "$rotate" != true && -n "$existing_name" ]]; then
        ES_PASSWORD="$(provisioner_kube get secret "$TARGET_SECRET_NAME" \
            -n "$TARGET_NAMESPACE" -o jsonpath='{.data.ELASTICSEARCH_PASSWORD}' \
            | base64 -d)"
    fi
    if [[ "$rotate" != true && -n "$existing_name" && -z "$ES_PASSWORD" ]]; then
        die 'Existing Elasticsearch Secret is incomplete; refusing implicit rotation'
    fi
    if [[ -z "$ES_PASSWORD" ]]; then
        require_command openssl
        ES_PASSWORD="$(openssl rand -hex 24)"
    fi
}

write_user_payload() {
    ES_PASSWORD_VALUE="$ES_PASSWORD" ES_ROLE_VALUE="$ES_ROLE_NAME" \
        python3 -c 'import json, os; print(json.dumps({
            "password": os.environ["ES_PASSWORD_VALUE"],
            "roles": [os.environ["ES_ROLE_VALUE"]],
            "full_name": "SunmoonAI managed application user",
            "metadata": {"managed_by": "sunmoonai-elasticsearch-provisioner"},
            "enabled": True
        }))' > "$WORK_DIR/user.json"
    chmod 0600 "$WORK_DIR/user.json"
}

apply_target_configuration() {
    local aliases
    aliases="$(cat "$WORK_DIR/aliases.json")"
    local ca_contents
    ca_contents=$(cat "$WORK_DIR/ca.crt") || return 1
    builtin printf '%s\0' ELASTICSEARCH_USERNAME "$ES_USERNAME" ELASTICSEARCH_PASSWORD "$ES_PASSWORD" ca.crt "$ca_contents" | \
        provisioner_secret --namespace "$TARGET_NAMESPACE" --name "$TARGET_SECRET_NAME" || return 1
    provisioner_kube create configmap "$TARGET_CONFIGMAP_NAME" \
        -n "$TARGET_NAMESPACE" \
        --from-literal="ELASTICSEARCH_URL=https://$SERVICE_HOST:9200" \
        --from-literal="ELASTICSEARCH_CA_CERT_PATH=/var/run/secrets/sunmoonai/elasticsearch/ca.crt" \
        --from-literal="ELASTICSEARCH_ALIASES=$aliases" \
        --dry-run=client -o yaml | provisioner_kube apply -f - >/dev/null
}

provision() {
    local rotate="$1"
    local index template_var physical_var template physical
    load_or_generate_password "$rotate"

    for ((index = 0; index < DATASET_COUNT; index++)); do
        template_var="DATASET_${index}_TEMPLATE"
        physical_var="DATASET_${index}_PHYSICAL"
        template="${!template_var}"
        physical="${!physical_var}"
        api PUT "/_index_template/$template" "$WORK_DIR/template-$index.json" >/dev/null
        local lookup_result=0
        api GET "/$physical/_settings" >/dev/null || lookup_result=$?
        if [[ "$lookup_result" == 44 ]]; then
            api PUT "/$physical" "$WORK_DIR/index-$index.json" >/dev/null || return 1
        elif [[ "$lookup_result" != 0 ]]; then
            return "$lookup_result"
        fi
    done

    api PUT "/_security/role/$ES_ROLE_NAME" "$WORK_DIR/role.json" >/dev/null
    write_user_payload
    api PUT "/_security/user/$ES_USERNAME" "$WORK_DIR/user.json" >/dev/null
    apply_target_configuration
    log_success "✅ Elasticsearch 资源已配置: $DECLARATION_NAME"
}

status() {
    local index template_var physical_var read_alias_var write_alias_var
    local template physical read_alias write_alias
    log_info "检查角色: $ES_ROLE_NAME"
    api GET "/_security/role/$ES_ROLE_NAME" >/dev/null
    log_info "检查用户: $ES_USERNAME"
    api GET "/_security/user/$ES_USERNAME" >/dev/null
    for ((index = 0; index < DATASET_COUNT; index++)); do
        template_var="DATASET_${index}_TEMPLATE"
        physical_var="DATASET_${index}_PHYSICAL"
        read_alias_var="DATASET_${index}_READ_ALIAS"
        write_alias_var="DATASET_${index}_WRITE_ALIAS"
        template="${!template_var}"
        physical="${!physical_var}"
        read_alias="${!read_alias_var}"
        write_alias="${!write_alias_var}"
        log_info "检查索引模板: $template"
        api GET "/_index_template/$template" >/dev/null
        log_info "检查物理索引: $physical"
        api GET "/$physical/_settings" >/dev/null
        log_info "检查读别名: $read_alias"
        api GET "/_alias/$read_alias" >/dev/null
        log_info "检查写别名: $write_alias"
        api GET "/_alias/$write_alias" >/dev/null
    done
    log_info "检查目标 Secret/ConfigMap: $TARGET_NAMESPACE/$TARGET_SECRET_NAME"
    provisioner_kube get secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" >/dev/null
    provisioner_kube get configmap "$TARGET_CONFIGMAP_NAME" -n "$TARGET_NAMESPACE" >/dev/null
    log_success "✅ Elasticsearch 资源状态正常: $DECLARATION_NAME"
}

revoke() {
    local delete_result=0
    api DELETE "/_security/user/$ES_USERNAME" >/dev/null || delete_result=$?
    [[ "$delete_result" == 0 || "$delete_result" == 44 ]] || return 1
    delete_result=0
    api DELETE "/_security/role/$ES_ROLE_NAME" >/dev/null || delete_result=$?
    [[ "$delete_result" == 0 || "$delete_result" == 44 ]] || return 1
    provisioner_kube delete secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found >/dev/null
    provisioner_kube delete configmap "$TARGET_CONFIGMAP_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found >/dev/null
    log_success "✅ 已撤销访问权限，索引和模板保留: $DECLARATION_NAME"
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    local action="${1:-help}"
    local declaration="${2:-}"

    case "$action" in
        validate)
            python3 -B "$HELPER" validate "$declaration"
            return
            ;;
        provision|rotate|status|revoke)
            ;;
        *)
            echo "用法: $0 [--cluster KIND|C1] <validate|provision|status|rotate|revoke> DECLARATION.json"
            return 1
            ;;
    esac

    require_command "$SUNMOON_KUBECTL"
    require_command curl
    load_declaration "$declaration"
    ensure_cluster_connection
    provisioner_kube get namespace "$TARGET_NAMESPACE" >/dev/null
    choose_local_port
    load_admin_material
    start_port_forward

    case "$action" in
        provision) provision false ;;
        rotate) provision true ;;
        status) status ;;
        revoke) revoke ;;
    esac
}

main "$@"
