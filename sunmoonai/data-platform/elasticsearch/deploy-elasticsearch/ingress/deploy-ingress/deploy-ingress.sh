#!/bin/bash

set -e

# 导入统一部署模板
source "$(dirname "$0")/../../../../../../utils/unified-deployment-template.sh"

# 计算项目根目录（k8s目录）
PROJECT_ROOT="$(cd "$(dirname "$0")/../../../../../../.." && pwd)"

# 脚本目录
ELASTICSEARCH_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ES_INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
# 主配置文件路径（相对于脚本目录：向上2层到 deploy-elasticsearch 目录）
ELASTICSEARCH_MAIN_CONFIG_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-elasticsearch.conf"

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
parse_cluster_arg() {
    local args=("$@")
    PARSED_ARGS=()
    local cluster_value=""
    local i=0
    
    while [[ $i -lt ${#args[@]} ]]; do
        # 启用大小写不敏感匹配
        shopt -s nocasematch
        case "${args[$i]}" in
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                # 支持等号形式：--cluster=C1 或 --CLUSTER=C1（大小写不敏感）
                cluster_value="${args[$i]#*=}"
                cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                export CLUSTER="$cluster_value"
                log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                # 支持空格形式：--cluster C1 或 -c C1（大小写不敏感）
                if [[ $((i+1)) -lt ${#args[@]} ]]; then
                    cluster_value="${args[$((i+1))]}"
                    cluster_value=$(echo "$cluster_value" | tr '[:lower:]' '[:upper:]')
                    export CLUSTER="$cluster_value"
                    log_info "🔧 设置集群环境变量: CLUSTER=$cluster_value"
                    i=$((i+1))
                else
                    log_error "❌ --cluster 参数需要指定值（格式：C{数字}，如 C1, C2, C3 等）"
                    exit 1
                fi
                ;;
            *)
                PARSED_ARGS+=("${args[$i]}")
                ;;
        esac
        # 恢复大小写敏感匹配
        shopt -u nocasematch
        i=$((i+1))
    done
    
    if [[ -n "$cluster_value" ]]; then
        if [[ -f "$PROJECT_ROOT/utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/utils/cluster-config-mapping.sh"
            if command -v apply_cluster_config_mapping &>/dev/null; then
                apply_cluster_config_mapping "$cluster_value"
            fi
        fi
    fi
}

# 先解析命令行参数（如果提供）
# 保存原始参数，以便在 main 函数中使用
ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 加载配置
load_config() {
    if [[ ! -f "$ELASTICSEARCH_MAIN_CONFIG_FILE" ]]; then
        log_error "主配置文件不存在: $ELASTICSEARCH_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$ELASTICSEARCH_MAIN_CONFIG_FILE"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：elasticsearch-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="elasticsearch-${ELASTICSEARCH_PROJECT_ID}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${ELASTICSEARCH_NAMESPACE:-data-platform-dev}"
    
    # ELASTICSEARCH_PORT: 从 Kubernetes Service 动态获取
    if [[ -z "${ELASTICSEARCH_PORT:-}" ]]; then
        ELASTICSEARCH_PORT=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -z "$ELASTICSEARCH_PORT" ]]; then
            log_warn "⚠️ 无法从 Service 获取端口，使用默认值 9200"
            ELASTICSEARCH_PORT="9200"
        fi
    fi
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${ELASTICSEARCH_UNIFIED_HOST:-llmops.sunmoonai.com}"
    
    # 固定配置（不需要动态获取）
    ENTRY_POINT="web"
    APP_LABEL="data-platform-ingress"
    COMPONENT_LABEL="elasticsearch-web"
    
    log_success "✅ 配置加载成功"
    log_info "服务名称: $SERVICE_NAME"
    log_info "命名空间: $NAMESPACE"
    log_info "服务端口: $ELASTICSEARCH_PORT"
    log_info "统一域名: $UNIFIED_HOST"
}

check_namespace() {
  local namespace="$1"
  kubectl get namespace "$namespace" >/dev/null 2>&1 || {
    log_error "命名空间不存在: $namespace"; return 1; }
}

verify_service() {
  local namespace="$1"
  kubectl get service -n "$namespace" "$SERVICE_NAME" >/dev/null 2>&1 || {
    log_error "服务不存在: $SERVICE_NAME"; return 1; }
}

deploy_web_route() {
  local namespace="${1:-$NAMESPACE}"
  check_namespace "$namespace" || return 1
  [[ -f "$ES_INGRESS_FILE" ]] || { log_error "Ingress 文件不存在: $ES_INGRESS_FILE"; return 1; }
  verify_service "$namespace" || return 1

  local tmp
  tmp=$(mktemp)
  cp "$ES_INGRESS_FILE" "$tmp"
  # 使用 sed 替换占位符
  sed -i "s|{{NAMESPACE}}|$NAMESPACE|g" "$tmp"
  sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$tmp"
  sed -i "s|{{SERVICE_PORT}}|$ELASTICSEARCH_PORT|g" "$tmp"
  sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$tmp"

  if kubectl apply -f "$tmp"; then
    log_success "Elasticsearch Web 路由应用成功"
    rm -f "$tmp"
  else
    log_error "Elasticsearch Web 路由应用失败"; rm -f "$tmp"; return 1
  fi
}

delete_web_route() {
  local namespace="${1:-$NAMESPACE}"
  kubectl delete -f "$ES_INGRESS_FILE" -n "$namespace" 2>/dev/null || true
  log_success "Elasticsearch Web 路由删除完成"
}

status() {
  kubectl get ingressroute -n "$NAMESPACE" -l component=$COMPONENT_LABEL 2>/dev/null || echo "无 IngressRoute"
  kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo "无 Service"
}

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"
    local project_id="${2:-sunmoonai}"
    local namespace="${3:-data-platform-dev}"  # 默认命名空间，load_config 会覆盖
    local environment="${4:-development}"

    setup_kubectl_environment
    load_config
    # load_config 后，NAMESPACE 已设置，使用配置中的值
    namespace="${NAMESPACE:-$namespace}"

    case "$action" in
        deploy) deploy_web_route "$namespace" && status ;;
        uninstall|delete) delete_web_route "$namespace" ;;
        status) status ;;
        *) echo "用法: $0 [--cluster C1|C2] [deploy|uninstall|status] [project_id] [namespace] [environment]" ;;
    esac
}

main "$@"


