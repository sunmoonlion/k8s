#!/bin/bash

# =============================================================================
# Harbor Registry Secret 部署脚本（Tools Admin Backend）
# 文件名: deploy-harbor-registry-secret.sh
# 用途: 部署 Harbor 镜像拉取 Secret 到 Kubernetes 集群
# 注意: 使用各组件自己的 generate-*.sh 生成的 YAML 文件
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_DIR="$(dirname "$SCRIPT_DIR")"  # harbor-registry-secret 目录
# 计算项目根目录（应用根目录）
# 从 deploy-harbor-registry-secret/ 向上 3 级到达应用根目录
# deploy-harbor-registry-secret/ -> harbor-registry-secret/ -> secret/ -> deploy-tools-admin-backend/ -> tools-admin-backend/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# 集群参数解析（轻量，无连接副作用）
find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}
K8S_ROOT_DIR="$(find_k8s_root_dir "$PROJECT_ROOT")"
if [[ -z "${K8S_ROOT_DIR:-}" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），PROJECT_ROOT=$PROJECT_ROOT" 1>&2
    exit 1
fi
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# 使用生成的 YAML 文件（由各组件自己的 generate-*.sh 生成）
K8S_RESOURCE_DIR="$PROJECT_ROOT/resources/k8s-resource"
HARBOR_SECRET_YAML="$K8S_RESOURCE_DIR/custom-values/secret/harbor-registry-secret/generate-harbor-registry-secret/harbor-registry-secret-generated.yaml"

log_info() { echo -e "[INFO] $*"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $*"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $*" >&2; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $*"; }

# 解析命令行参数（优先于配置文件加载，确保命令行参数优先级最高）
declare -a PARSED_ARGS

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

# 尝试加载主配置文件
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MAIN_CONFIG_FILE="$(find "$DEPLOY_ROOT/app/deploy-app" -maxdepth 1 -name "deploy-*.conf" | head -n 1)"
if [[ -f "$MAIN_CONFIG_FILE" ]]; then
    set +e
    source "$MAIN_CONFIG_FILE" 2>/dev/null
    set -e
    log_info "已加载主配置文件: $MAIN_CONFIG_FILE"
fi

# 加载配置文件
CONFIG_FILE="$SCRIPT_DIR/deploy-harbor-registry-secret.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"

    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
else
    log_error "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

DEFAULT_PROJECT_ID="${PROJECT_ID:-}"
DEFAULT_NAMESPACE="${NAMESPACE:-}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-}"

# 自动生成 YAML 文件的辅助函数
auto_generate_yaml() {
    local yaml_file="$1"
    local k8s_resource_dir="$2"

    if true; then
        log_info "重新生成 Harbor Registry Secret YAML 文件（确保使用当前集群 registry）"
        export NAMESPACE="${SECRET_NAMESPACE:-app-platform-dev}"
        export ENVIRONMENT="${ENVIRONMENT:-development}"
        export ENV="${ENV:-dev}"
        export DOCKER_SERVER="${DOCKER_SERVER:-harbor.sunmoonai.com}"

        local generate_script="$k8s_resource_dir/custom-values/secret/harbor-registry-secret/generate-harbor-registry-secret/generate-harbor-registry-secret.sh"
        if [ -f "$generate_script" ]; then
            if bash "$generate_script"; then
                log_success "YAML 文件生成成功"
            else
                log_error "YAML 文件生成失败"
                return 1
            fi
        else
            log_error "生成脚本不存在: $generate_script"
            return 1
        fi
    fi
    return 0
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    set -- "${PARSED_ARGS[@]}"

    if [[ -n "${CLUSTER:-}" ]]; then
        log_info "🎯 当前集群配置: ${CLUSTER}"
    fi

    local action="${1:-deploy}"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="false"

    if [[ "$action" != "deploy" ]]; then
        dry_run="true"
    fi

    log_info "部署 Harbor Registry Secret (Tools Admin Backend)..."
    log_info "部署参数："
    log_info "  - 操作: $action"
    log_info "  - 项目ID: $project_id"
    log_info "  - 命名空间: $namespace"
    log_info "  - 环境: $environment"
    echo ""

    if ! auto_generate_yaml "$HARBOR_SECRET_YAML" "$K8S_RESOURCE_DIR"; then
        log_error "无法生成或找到 Harbor Registry Secret YAML 文件"
        exit 1
    fi

    case "$action" in
        deploy)
            log_info "部署 Secret 到 Kubernetes 集群..."

            local _ns_err3
            _ns_err3=$(kubectl get namespace "$namespace" 2>&1)
            if [[ $? -ne 0 ]]; then
                if echo "$_ns_err3" | grep -qiE "not.?found|NotFound"; then
                    log_error "命名空间不存在: $namespace"
                    log_error "请先创建命名空间: kubectl create namespace $namespace"
                    exit 1
                else
                    log_warn "kubectl 连接失败，尝试自动重连后重试（${_ns_err3%%$'\n'*}）"
                    if command -v setup_kubectl_environment >/dev/null 2>&1 && setup_kubectl_environment >/dev/null 2>&1; then
                        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
                            log_success "✅ 重连后命名空间 $namespace 已存在"
                        else
                            log_error "kubectl 连接失败，无法验证命名空间 $namespace"
                            exit 1
                        fi
                    else
                        log_error "kubectl 连接失败，无法验证命名空间 $namespace（${_ns_err3%%$'\n'*}）"
                        exit 1
                    fi
                fi
            fi

            if kubectl apply -f "$HARBOR_SECRET_YAML" -n "$namespace"; then
                log_success "Secret 已部署: $SECRET_NAME (命名空间: $namespace)"
            else
                log_error "Secret 部署失败"
                exit 1
            fi
            ;;
        uninstall)
            log_info "卸载 Secret..."
            kubectl delete -f "$HARBOR_SECRET_YAML" -n "$namespace" --ignore-not-found
            log_success "Secret 卸载完成"
            ;;
        status)
            log_info "检查 Secret 状态..."
            kubectl get secret "$SECRET_NAME" -n "$namespace" 2>/dev/null || log_warn "Secret 不存在: $SECRET_NAME"
            ;;
        generate)
            log_success "YAML 文件已生成: $HARBOR_SECRET_YAML"
            ;;
        *)
            log_error "无效操作: $action"
            echo "用法: $0 <deploy|uninstall|status|generate> [project_id] [namespace] [environment]"
            exit 1
            ;;
    esac

    if [[ "$action" == "deploy" ]]; then
        if [[ "${RESTART_COMPONENTS:-false}" == "true" && -n "${RESTART_COMPONENTS_LIST:-}" ]]; then
            log_info "重启使用该 Secret 的组件..."
            IFS=',' read -ra COMPONENTS <<< "${RESTART_COMPONENTS_LIST}"
            for component in "${COMPONENTS[@]}"; do
                component=$(echo "$component" | xargs)
                if [[ -n "$component" ]]; then
                    log_info "重启组件: $component"
                    kubectl rollout restart deployment/"$component" -n "$namespace" 2>/dev/null || \
                    kubectl rollout restart statefulset/"$component" -n "$namespace" 2>/dev/null || \
                    log_warn "组件 $component 不存在或重启失败"
                fi
            done
        fi
    fi

    echo ""
    log_success "Harbor Registry Secret (Tools Admin Backend) 操作完成！"
    log_info "操作信息："
    log_info "  - 操作: $action"
    log_info "  - Secret 名称: $SECRET_NAME"
    log_info "  - 命名空间: $namespace"
    log_info "  - YAML 文件: $HARBOR_SECRET_YAML"
    log_info "  - 完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 显示帮助信息
show_help() {
    echo "Harbor Registry Secret 部署脚本 (Tools Admin Backend)"
    echo ""
    echo "用法:"
    echo "  $0 <deploy|uninstall|status|generate> [项目ID] [命名空间] [环境]"
    echo ""
    echo "配置文件: $SCRIPT_DIR/deploy-harbor-registry-secret.conf"
}

# 主程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
    main "$@"
fi
