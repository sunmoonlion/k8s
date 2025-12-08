#!/bin/bash

set -e

# 脚本目录（在加载模板前保存，防止被覆盖）
KIBANA_INGRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$KIBANA_INGRESS_SCRIPT_DIR"

# 导入统一部署模板（提供日志函数等基础设施）
# 在加载前保存 SCRIPT_DIR，因为 unified-deployment-template.sh 会覆盖它
SAVED_SCRIPT_DIR_FOR_TEMPLATE="$SCRIPT_DIR"
# 计算项目根目录
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
utils_path=""
if [[ -f "$PROJECT_ROOT/../../../../utils/unified-deployment-template.sh" ]]; then
    utils_path="$PROJECT_ROOT/../../../../utils/unified-deployment-template.sh"
elif [[ -f "/home/zym/k8s/utils/unified-deployment-template.sh" ]]; then
    utils_path="/home/zym/k8s/utils/unified-deployment-template.sh"
fi

if [[ -n "$utils_path" && -f "$utils_path" ]]; then
    source "$utils_path"
    # 立即恢复 SCRIPT_DIR，防止被 unified-deployment-template.sh 覆盖
    SCRIPT_DIR="$SAVED_SCRIPT_DIR_FOR_TEMPLATE"
else
    echo "警告: 无法找到 unified-deployment-template.sh，日志函数可能不可用" >&2
    # 定义基本的日志函数作为后备
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warn() { echo "[WARN] $*"; }
fi

# 确保 SCRIPT_DIR 正确
SCRIPT_DIR="$KIBANA_INGRESS_SCRIPT_DIR"
KB_INGRESS_FILE="$(dirname "$SCRIPT_DIR")/ingress.yaml"
# 主配置文件路径（相对于脚本目录）
# deploy-ingress.sh -> deploy-ingress/ -> ingress/ -> deploy-kibana/
# 所以是向上2级，不是3级
KIBANA_MAIN_CONFIG_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/deploy-kibana.conf"

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
        # 在加载前保存 SCRIPT_DIR
        local saved_script_dir="$SCRIPT_DIR"
        if [[ -f "$PROJECT_ROOT/../../../../utils/cluster-config-mapping.sh" ]]; then
            source "$PROJECT_ROOT/../../../../utils/cluster-config-mapping.sh"
            # 恢复 SCRIPT_DIR
            SCRIPT_DIR="$saved_script_dir"
            apply_cluster_config_mapping "$cluster_value"
            # 再次确保 SCRIPT_DIR 正确
            SCRIPT_DIR="$saved_script_dir"
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
    # 在加载配置文件前保存 SCRIPT_DIR
    local saved_script_dir="$SCRIPT_DIR"
    if [[ ! -f "$KIBANA_MAIN_CONFIG_FILE" ]]; then
        log_error "主配置文件不存在: $KIBANA_MAIN_CONFIG_FILE"
        exit 1
    fi
    
    # 加载主配置
    source "$KIBANA_MAIN_CONFIG_FILE"
    # 恢复 SCRIPT_DIR，防止被配置文件覆盖
    SCRIPT_DIR="$saved_script_dir"
    
    # 动态获取配置值
    # SERVICE_NAME: 从 PROJECT_ID 构建（格式：kibana-{project_id}）
    if [[ -z "${SERVICE_NAME:-}" ]]; then
        SERVICE_NAME="kibana-${KIBANA_PROJECT_ID}"
    fi
    
    # NAMESPACE: 从主配置获取
    NAMESPACE="${KIBANA_NAMESPACE:-data-platform-dev}"
    
    # KIBANA_PORT: 从 Kubernetes Service 动态获取
    if [[ -z "${KIBANA_PORT:-}" ]]; then
        KIBANA_PORT=$(get_service_port "$SERVICE_NAME" "$NAMESPACE")
        if [[ -z "$KIBANA_PORT" ]]; then
            log_warn "⚠️ 无法从 Service 获取端口，使用默认值 5601"
            KIBANA_PORT="5601"
        fi
    fi
    
    # UNIFIED_HOST: 从主配置的统一域名获取
    UNIFIED_HOST="${KIBANA_UNIFIED_HOST:-llmops.sunmoonai.com}"
    
    # 固定配置（不需要动态获取）
    ENTRY_POINT="web"
    APP_LABEL="data-platform-ingress"
    COMPONENT_LABEL="kibana-web"
    
    log_success "✅ 配置加载成功"
    log_info "服务名称: $SERVICE_NAME"
    log_info "命名空间: $NAMESPACE"
    log_info "服务端口: $KIBANA_PORT"
    log_info "统一域名: $UNIFIED_HOST"
}
check_ns() { kubectl get namespace "$1" >/dev/null 2>&1 || { log_error "命名空间不存在: $1"; return 1; }; }
verify_svc() { kubectl get svc -n "$1" "$SERVICE_NAME" >/dev/null 2>&1 || { log_error "服务不存在: $SERVICE_NAME"; return 1; }; }

deploy_web() {
  local ns="${1:-$NAMESPACE}"
  check_ns "$ns" || return 1
  [[ -f "$KB_INGRESS_FILE" ]] || { log_error "Ingress 不存在: $KB_INGRESS_FILE"; return 1; }
  verify_svc "$ns" || return 1
  local tmp=$(mktemp); cp "$KB_INGRESS_FILE" "$tmp"
  # 使用 sed 替换占位符
  sed -i "s|{{NAMESPACE}}|$NAMESPACE|g" "$tmp"
  sed -i "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" "$tmp"
  sed -i "s|{{SERVICE_PORT}}|$KIBANA_PORT|g" "$tmp"
  sed -i "s|{{UNIFIED_HOST}}|$UNIFIED_HOST|g" "$tmp"
  kubectl apply -f "$tmp" && log_success "Kibana Web 路由应用成功" || { log_error "应用失败"; rm -f "$tmp"; return 1; }
  rm -f "$tmp"
}

delete_web() { local ns="${1:-$NAMESPACE}"; kubectl delete -f "$KB_INGRESS_FILE" -n "$ns" 2>/dev/null || true; log_success "Kibana Web 路由删除完成"; }
status() { kubectl get ingressroute -n "$NAMESPACE" -l component=$COMPONENT_LABEL 2>/dev/null || echo 无 IngressRoute; kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" 2>/dev/null || echo 无 Service; }

# 解析命令行参数（支持 --cluster 或 -c）
declare -a PARSED_ARGS


main() {
    # 使用解析后的参数（已移除 --cluster 参数）
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"
    
    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi
    
    local action="${1:-deploy}"; local project_id="${2:-sunmoonai}"; local ns="${3:-$NAMESPACE}"; local env="${4:-development}"
    setup_kubectl_environment; load_config
    case "$action" in
        deploy) deploy_web "$ns" && status;;
        uninstall|delete) delete_web "$ns";;
        status) status;;
        *) echo "用法: $0 [--cluster C1|C2] [deploy|uninstall|status] [project_id] [namespace] [environment]";;
    esac
}

main "$@"


