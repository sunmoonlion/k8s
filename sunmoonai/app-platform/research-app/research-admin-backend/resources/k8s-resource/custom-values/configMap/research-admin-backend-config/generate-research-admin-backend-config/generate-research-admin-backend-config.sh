#!/bin/bash
# research-admin-backend ConfigMap YAML 生成脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/generate-research-admin-backend-config.conf"
# 从 generate-research-admin-backend-config/ -> research-admin-backend-config/ -> configMap/ -> custom-values/ -> k8s-resource/
K8S_RESOURCE_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# 从 generate-research-admin-backend-config/ -> ... -> k8s-resource/ -> resources/ -> research-admin-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../../../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR"

MAIN_DEPLOY_CONFIG="$PROJECT_ROOT/deploy-research-admin-backend/app/deploy-app/deploy-research-admin-backend.conf"
if [ -f "$MAIN_DEPLOY_CONFIG" ]; then
    _temp_namespace=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${RESEARCH_ADMIN_BACKEND_NAMESPACE:-}")
    _temp_environment=$(source "$MAIN_DEPLOY_CONFIG" 2>/dev/null && echo "${ENVIRONMENT:-}")
    [ -n "$_temp_namespace" ] && [ -z "${NAMESPACE:-}" ] && export NAMESPACE="$_temp_namespace"
    [ -n "$_temp_environment" ] && [ -z "${ENVIRONMENT:-}" ] && export ENVIRONMENT="$_temp_environment"
    unset _temp_namespace _temp_environment
fi

log_info()    { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_error()   { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "配置文件不存在: $CONFIG_FILE"; exit 1
fi
source "$CONFIG_FILE"

# The deployment orchestrator historically uses the short label `dev`/`prod`
# for resource metadata.  The backend uses the semantic environment names for
# its production security checks, so normalize the aliases at the boundary.
case "${ENV:-}" in
    dev|development|"") ENV="development" ;;
    prod|production) ENV="production" ;;
esac

if [ "${ENABLED:-true}" != "true" ]; then
    log_info "跳过资源生成: configmap (已禁用)"; exit 0
fi

# ============================================================================
# 设置环境变量（用于模板替换）
# ============================================================================
export NAMESPACE="${NAMESPACE:-}"
export ENVIRONMENT="${ENVIRONMENT:-}"
export ENV="${ENV:-}"

export LOG_LEVEL="${LOG_LEVEL:-}"
export SESSION_TTL_SECONDS="${SESSION_TTL_SECONDS:-}"
export AGENT_SESSION_LOCK_TTL_SECONDS="${AGENT_SESSION_LOCK_TTL_SECONDS:-}"
export AGENT_V4_TRAFFIC_ENABLED="${AGENT_V4_TRAFFIC_ENABLED:-}"
export AGENT_V5_TRAFFIC_MODE="${AGENT_V5_TRAFFIC_MODE:-}"
export AGENT_REDIS_KEY_PREFIX="${AGENT_REDIS_KEY_PREFIX:-}"
export FRONTEND_BASE_URL="${FRONTEND_BASE_URL:-}"
export CASDOOR_ENDPOINT="${CASDOOR_ENDPOINT:-}"
export CASDOOR_ORGANIZATION="${CASDOOR_ORGANIZATION:-}"
export CASDOOR_APPLICATION="${CASDOOR_APPLICATION:-}"
export CASDOOR_REDIRECT_URI="${CASDOOR_REDIRECT_URI:-}"
export CASDOOR_VERIFY_SSL="${CASDOOR_VERIFY_SSL:-}"
export FRONTEND_ALLOWED_ORIGINS="${FRONTEND_ALLOWED_ORIGINS:-}"
export AUTH_POLICY_VERSION="${AUTH_POLICY_VERSION:-}"
export AUTH_ALLOWED_ALGORITHMS="${AUTH_ALLOWED_ALGORITHMS:-}"
export KNOWLEDGE_RETRIEVAL_URL="${KNOWLEDGE_RETRIEVAL_URL:-}"
export KNOWLEDGE_RETRIEVAL_SERVICE_APPLICATION="${KNOWLEDGE_RETRIEVAL_SERVICE_APPLICATION:-}"
export KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL="${KNOWLEDGE_RETRIEVAL_SERVICE_DISCOVERY_URL:-}"
export KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT="${KNOWLEDGE_RETRIEVAL_SERVICE_BACKCHANNEL_ENDPOINT:-}"
export KNOWLEDGE_RETRIEVAL_SERVICE_SCOPE="${KNOWLEDGE_RETRIEVAL_SERVICE_SCOPE:-}"
export KNOWLEDGE_RETRIEVAL_TIMEOUT_SECONDS="${KNOWLEDGE_RETRIEVAL_TIMEOUT_SECONDS:-}"
export CELERY_QUEUE="${CELERY_QUEUE:-}"

validate_yaml() {
    local yaml_file="$1"
    if grep -q '\${[^}]*}' "$yaml_file"; then
        log_error "YAML 仍包含未解析模板变量: $(basename "$yaml_file")"
        return 1
    fi
    if [[ -x /usr/bin/python3 ]] && /usr/bin/python3 -c 'import yaml' &> /dev/null; then
        if /usr/bin/python3 -c 'import sys, yaml; docs=list(yaml.safe_load_all(open(sys.argv[1], encoding="utf-8"))); assert docs and all(isinstance(d, dict) and d.get("apiVersion") and d.get("kind") for d in docs)' "$yaml_file"; then
            log_success "YAML 验证通过: $(basename "$yaml_file")"
            return 0
        fi
        log_error "YAML 验证失败: $(basename "$yaml_file")"
        return 1
    elif command -v kubectl &> /dev/null; then
        if ! kubectl cluster-info --request-timeout=2s &> /dev/null; then
            log_warn "Kubernetes API 不可用，已完成离线门禁/模板检查，跳过 OpenAPI 验证"
            return 0
        fi
        if kubectl apply --dry-run=client -f "$yaml_file" &> /dev/null; then
            log_success "YAML 验证通过: $(basename "$yaml_file")"
            return 0
        else
            log_error "YAML 验证失败: $(basename "$yaml_file")"
            kubectl apply --dry-run=client -f "$yaml_file" 2>&1 | head -20
            return 1
        fi
    else
        log_warn "kubectl 未安装，跳过 YAML 验证"
        return 0
    fi
}

main() {
    log_info "开始生成 research-admin-backend ConfigMap YAML 文件..."
    log_info "输出目录: $OUTPUT_DIR"

    local full_template_path
    if [[ "$TEMPLATE_FILE" = /* ]]; then
        full_template_path="$TEMPLATE_FILE"
    else
        full_template_path="$K8S_RESOURCE_DIR/$TEMPLATE_FILE"
    fi
    local full_output_path="$OUTPUT_DIR/$OUTPUT_FILE"
    local temporary_output_path
    temporary_output_path="$(mktemp "$OUTPUT_DIR/.${OUTPUT_FILE}.XXXXXX.tmp.yaml")"
    trap 'rm -f "${temporary_output_path:-}"' EXIT

    if [ ! -f "$full_template_path" ]; then
        log_error "模板文件不存在: $full_template_path"; exit 1
    fi

    log_info "生成 configmap: $OUTPUT_FILE"
    sed -e 's/\${\([^:}]*\):-[^}]*}/\${\1}/g' "$full_template_path" | envsubst > "$temporary_output_path"

    local traffic_gate_validator="$SCRIPT_DIR/validate-agent-traffic-gate.sh"
    if ! bash "$traffic_gate_validator" "$temporary_output_path"; then
        log_error "Agent 流量门禁验证失败，拒绝生成可部署配置"
        exit 1
    fi
    if ! validate_yaml "$temporary_output_path"; then exit 1; fi
    mv "$temporary_output_path" "$full_output_path"
    trap - EXIT
    log_success "✅ configmap 生成完成: $OUTPUT_FILE"
}

main "$@"
