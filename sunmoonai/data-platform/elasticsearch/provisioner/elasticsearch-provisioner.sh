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
LOCAL_PORT="${ELASTICSEARCH_PROVISIONER_PORT:-19200}"
CONNECT_TIMEOUT="${ELASTICSEARCH_PROVISIONER_CONNECT_TIMEOUT:-120}"
WORK_DIR=""
PORT_FORWARD_PID=""

die() {
    log_error "$*"
    exit 1
}

cleanup() {
    if [[ -n "$PORT_FORWARD_PID" ]]; then
        kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
        wait "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
    fi
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

ensure_cluster_connection() {
    if kubectl get nodes >/dev/null 2>&1; then
        return
    fi
    setup_kubectl_environment
    kubectl get nodes >/dev/null
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
    python3 "$HELPER" render "$declaration" "$WORK_DIR"
}

load_admin_material() {
    ADMIN_PASSWORD="$(kubectl get secret "$ADMIN_SECRET" -n "$DATA_NAMESPACE" \
        -o jsonpath='{.data.elasticsearch-password}' | base64 -d)"
    [[ -n "$ADMIN_PASSWORD" ]] || die "管理员密码为空"
    kubectl get secret "$CA_SECRET" -n "$DATA_NAMESPACE" \
        -o jsonpath='{.data.ca\.crt}' | base64 -d > "$WORK_DIR/ca.crt"
    chmod 0600 "$WORK_DIR/ca.crt"
    cat > "$WORK_DIR/curl.conf" <<EOF
silent
show-error
fail-with-body
connect-timeout = 2
max-time = 15
noproxy = "*"
cacert = "$WORK_DIR/ca.crt"
user = "elastic:$ADMIN_PASSWORD"
EOF
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
            kubectl port-forward "service/$SERVICE_NAME" "$LOCAL_PORT:9200" \
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

    cat "$WORK_DIR/port-forward.log" >&2
    die "等待 Elasticsearch 连接超时 (${CONNECT_TIMEOUT}s)"
}

api() {
    local method="$1"
    local path="$2"
    local body="${3:-}"
    if [[ -n "$body" ]]; then
        curl --config "$WORK_DIR/curl.conf" -X "$method" \
            -H "Content-Type: application/json" \
            --resolve "$SERVICE_HOST:$LOCAL_PORT:127.0.0.1" \
            --data-binary "@$body" "https://$SERVICE_HOST:$LOCAL_PORT$path"
    else
        curl --config "$WORK_DIR/curl.conf" -X "$method" \
            --resolve "$SERVICE_HOST:$LOCAL_PORT:127.0.0.1" \
            "https://$SERVICE_HOST:$LOCAL_PORT$path"
    fi
}

load_or_generate_password() {
    local rotate="$1"
    ES_PASSWORD=""
    if [[ "$rotate" != "true" ]] && kubectl get secret "$TARGET_SECRET_NAME" \
        -n "$TARGET_NAMESPACE" >/dev/null 2>&1; then
        ES_PASSWORD="$(kubectl get secret "$TARGET_SECRET_NAME" \
            -n "$TARGET_NAMESPACE" -o jsonpath='{.data.ELASTICSEARCH_PASSWORD}' \
            | base64 -d)"
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
    kubectl create secret generic "$TARGET_SECRET_NAME" \
        -n "$TARGET_NAMESPACE" \
        --from-literal="ELASTICSEARCH_USERNAME=$ES_USERNAME" \
        --from-literal="ELASTICSEARCH_PASSWORD=$ES_PASSWORD" \
        --from-file="ca.crt=$WORK_DIR/ca.crt" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    kubectl create configmap "$TARGET_CONFIGMAP_NAME" \
        -n "$TARGET_NAMESPACE" \
        --from-literal="ELASTICSEARCH_URL=https://$SERVICE_HOST:9200" \
        --from-literal="ELASTICSEARCH_CA_CERT_PATH=/var/run/secrets/sunmoonai/elasticsearch/ca.crt" \
        --from-literal="ELASTICSEARCH_ALIASES=$aliases" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
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
        if ! api GET "/$physical/_settings" >/dev/null 2>&1; then
            api PUT "/$physical" "$WORK_DIR/index-$index.json" >/dev/null
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
    kubectl get secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" >/dev/null
    kubectl get configmap "$TARGET_CONFIGMAP_NAME" -n "$TARGET_NAMESPACE" >/dev/null
    log_success "✅ Elasticsearch 资源状态正常: $DECLARATION_NAME"
}

revoke() {
    api DELETE "/_security/user/$ES_USERNAME" >/dev/null 2>&1 || true
    api DELETE "/_security/role/$ES_ROLE_NAME" >/dev/null 2>&1 || true
    kubectl delete secret "$TARGET_SECRET_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found >/dev/null
    kubectl delete configmap "$TARGET_CONFIGMAP_NAME" -n "$TARGET_NAMESPACE" \
        --ignore-not-found >/dev/null
    log_success "✅ 已撤销访问权限，索引和模板保留: $DECLARATION_NAME"
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    local action="${1:-help}"
    local declaration="${2:-}"

    case "$action" in
        validate)
            python3 "$HELPER" validate "$declaration"
            return
            ;;
        provision|rotate|status|revoke)
            ;;
        *)
            echo "用法: $0 [--cluster KIND|C1] <validate|provision|status|rotate|revoke> DECLARATION.json"
            return 1
            ;;
    esac

    require_command kubectl
    require_command curl
    load_declaration "$declaration"
    ensure_cluster_connection
    kubectl get namespace "$TARGET_NAMESPACE" >/dev/null
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
