#!/bin/bash
# Unified Harbor Registry Secret YAML generator for app-platform components.

set -euo pipefail

CALLER_SCRIPT_DIR="${1:-}"
if [[ -z "$CALLER_SCRIPT_DIR" ]]; then
    echo "[ERROR] missing caller script dir" >&2
    exit 1
fi
shift || true

CALLER_SCRIPT_DIR="$(cd "$CALLER_SCRIPT_DIR" && pwd)"
CONFIG_FILE="$CALLER_SCRIPT_DIR/generate-harbor-registry-secret.conf"
K8S_RESOURCE_DIR="$(cd "$CALLER_SCRIPT_DIR/../../../.." && pwd)"
COMPONENT_ROOT="$(cd "$CALLER_SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$CALLER_SCRIPT_DIR"

log_info()    { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }

find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/secret-management/lib/secret-data.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}

discover_component_namespace() {
    local var_name
    local var_value

    if [[ -n "${NAMESPACE:-}" ]]; then
        return 0
    fi

    while IFS= read -r var_name; do
        case "$var_name" in
            NAMESPACE|DEFAULT_NAMESPACE|SECRET_NAMESPACE|KUBE_NAMESPACE|*_SECRET_NAMESPACE)
                continue
                ;;
        esac

        var_value="${!var_name:-}"
        if [[ -n "$var_value" ]]; then
            export NAMESPACE="$var_value"
            return 0
        fi
    done < <(compgen -v | grep '_NAMESPACE$' | sort)
}

source_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local had_errexit=0
        local had_nounset=0
        [[ $- == *e* ]] && had_errexit=1
        [[ $- == *u* ]] && had_nounset=1

        set +e +u
        # shellcheck disable=SC1090
        source "$file" >/dev/null 2>&1

        (( had_errexit )) && set -e
        (( had_nounset )) && set -u
    fi
}

load_component_deploy_config() {
    local deploy_config
    deploy_config="$(find "$COMPONENT_ROOT" -path "$COMPONENT_ROOT/deploy-*/app/deploy-app/deploy-*.conf" -type f | sort | head -n 1)"
    if [[ -n "$deploy_config" ]]; then
        source_if_exists "$deploy_config"
        discover_component_namespace
    fi
}

validate_yaml() {
    local yaml_file="$1"

    if [[ ! -s "$yaml_file" ]]; then
        log_error "YAML 文件为空: $(basename "$yaml_file")"
        return 1
    fi

    if ! grep -q '^apiVersion:' "$yaml_file" || ! grep -q '^kind:' "$yaml_file"; then
        log_error "YAML 基础字段缺失: $(basename "$yaml_file")"
        return 1
    fi

    log_success "YAML 基础验证通过: $(basename "$yaml_file")"
}

if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

K8S_ROOT_DIR="$(find_k8s_root_dir "$COMPONENT_ROOT" || true)"
if [[ -z "${K8S_ROOT_DIR:-}" ]]; then
    log_error "无法定位 k8s 根目录，未找到 utils/secret-management/lib/secret-data.sh"
    exit 1
fi

# shellcheck disable=SC1090
source "$K8S_ROOT_DIR/utils/secret-management/lib/secret-data.sh"
if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
    # shellcheck disable=SC1090
    source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
fi

load_component_deploy_config

_incoming_docker_server="${DOCKER_SERVER:-}"
# shellcheck disable=SC1090
source "$CONFIG_FILE"

if declare -F apply_cluster_config_mapping >/dev/null; then
    apply_cluster_config_mapping
fi

if [[ -z "$_incoming_docker_server" ]] && declare -F get_cluster_harbor_registry >/dev/null; then
    DOCKER_SERVER="$(get_cluster_harbor_registry)"
fi
unset _incoming_docker_server

if [[ "${ENABLED:-true}" != "true" ]]; then
    log_info "跳过资源生成: harbor-registry-secret (已禁用)"
    exit 0
fi

DOCKER_PASSWORD="$(resolve_docker_auth_password "${DOCKER_PASSWORD:-}")"
if [[ -z "${DOCKER_PASSWORD:-}" || "$DOCKER_PASSWORD" == "TODO_FILL_IN_HARBOR_PASSWORD" ]]; then
    log_error "Harbor 密码未配置，拒绝生成无效的镜像拉取 Secret"
    exit 1
fi

export NAMESPACE="${NAMESPACE:-app-platform-dev}"
export ENVIRONMENT="${ENVIRONMENT:-development}"
export ENV="${ENV:-dev}"

HARBOR_AUTH_STRING="$(echo -n "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" | base64 -w 0)"
HARBOR_DOCKER_CONFIG_JSON="$(echo -n "{\"auths\":{\"${DOCKER_SERVER}\":{\"username\":\"${DOCKER_USERNAME}\",\"password\":\"${DOCKER_PASSWORD}\",\"auth\":\"${HARBOR_AUTH_STRING}\"}}}" | base64 -w 0)"
export HARBOR_DOCKER_CONFIG_JSON

log_info "开始生成 Harbor Registry Secret YAML 文件..."

if [[ "${TEMPLATE_FILE:-}" = /* ]]; then
    full_template_path="$TEMPLATE_FILE"
else
    full_template_path="$K8S_RESOURCE_DIR/${TEMPLATE_FILE:-templates/secret/harbor-registry-secret.yaml}"
fi
full_output_path="$OUTPUT_DIR/${OUTPUT_FILE:-harbor-registry-secret-generated.yaml}"

if [[ ! -f "$full_template_path" ]]; then
    log_error "模板文件不存在: $full_template_path"
    exit 1
fi

log_info "生成 harbor-registry-secret: $(basename "$full_output_path")"
sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$full_output_path"
validate_yaml "$full_output_path"
log_success "✅ harbor-registry-secret 生成完成: $(basename "$full_output_path")"
