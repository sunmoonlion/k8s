#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUSINESS_APP_ROOT="$(dirname "$THIS_DIR")"
BUSINESS_APP_NAME="$(basename "$BUSINESS_APP_ROOT")"

K8S_ROOT_DIR=""
search_dir="$THIS_DIR"
while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
        K8S_ROOT_DIR="$search_dir"
        break
    fi
    search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
    echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），THIS_DIR=$THIS_DIR" 1>&2
    exit 1
fi

source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"

red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }

ORIGINAL_ARGS=("$@")
if [[ $# -gt 0 ]]; then
    unified_parse_cluster_arg "$@"
    ORIGINAL_ARGS=("${PARSED_ARGS[@]}")
fi

CONFIG_FILE="$THIS_DIR/deploy-${BUSINESS_APP_NAME}-all.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
    log_info "已加载 ${BUSINESS_APP_NAME} 配置: $CONFIG_FILE"
else
    log_error "缺少 ${BUSINESS_APP_NAME} 配置文件: $CONFIG_FILE"
    exit 1
fi

VAR_PREFIX="$(echo "$BUSINESS_APP_NAME" | tr '[:lower:]-' '[:upper:]_')"
project_var="${VAR_PREFIX}_PROJECT_ID"
namespace_var="${VAR_PREFIX}_NAMESPACE"

eval "DEFAULT_PROJECT_ID=\${${project_var}:-sunmoonai}"
eval "DEFAULT_NAMESPACE=\${${namespace_var}:-app-platform-dev}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-development}"

call_subscript() {
    local script_path="$1"
    shift
    if [[ -n "${CLUSTER:-}" ]]; then
        DISABLE_AUTO_CLEANUP=true "$script_path" --cluster "$CLUSTER" "$@"
    else
        DISABLE_AUTO_CLEANUP=true "$script_path" "$@"
    fi
}

find_component_script() {
    local component_dir="$1"
    local matches=()
    shopt -s nullglob
    matches=("$component_dir"/deploy-*/app/deploy-app/deploy-*.sh)
    if [[ ${#matches[@]} -eq 0 ]]; then
        matches=("$component_dir"/deploy-*/deploy-*.sh)
    fi
    shopt -u nullglob

    if [[ ${#matches[@]} -gt 0 ]]; then
        printf '%s\n' "${matches[0]}"
        return 0
    fi
    return 1
}

collect_components() {
    local components=()
    local component_dir component_name var_base enabled_var priority_var enabled priority script_path

    for component_dir in "$BUSINESS_APP_ROOT"/*; do
        [[ -d "$component_dir" ]] || continue
        component_name="$(basename "$component_dir")"
        [[ "$component_name" =~ ^deploy-.*-all$ ]] && continue
        [[ "$component_name" == "db-access-bootstrap" || "$component_name" == "resources" || "$component_name" == "client" || "$component_name" == "docs" ]] && continue

        var_base="$(echo "$component_name" | tr '-' '_')"
        enabled_var="${var_base}_enabled"
        priority_var="${var_base}_priority"
        enabled="false"
        priority="100"
        eval "enabled=\${${enabled_var}:-false}"
        eval "priority=\${${priority_var}:-100}"

        if script_path="$(find_component_script "$component_dir")"; then
            components+=("$priority:$component_name:$enabled:$script_path")
        elif [[ "$enabled" == "true" ]]; then
            components+=("$priority:$component_name:$enabled:")
        fi
    done

    printf '%s\n' "${components[@]}"
}

run_components_by_priority() {
    local action="$1"
    local project_id="$2"
    local namespace="$3"
    local environment="$4"
    local dry_run="${5:-false}"
    local components=()

    while IFS= read -r line; do
        [[ -n "$line" ]] && components+=("$line")
    done < <(collect_components)

    if [[ ${#components[@]} -eq 0 ]]; then
        log_warn "⚠️  ${BUSINESS_APP_NAME} 没有发现可部署组件"
        return 0
    fi

    local sort_flag="-nr"
    [[ "$action" == "uninstall" ]] && sort_flag="-n"
    IFS=$'\n' sorted_components=($(sort -t: -k1 $sort_flag <<<"${components[*]}"))
    unset IFS

    log_info "📋 ${BUSINESS_APP_NAME} 组件${action}顺序："
    for component_info in "${sorted_components[@]}"; do
        IFS=':' read -r priority component_name enabled script_path <<< "$component_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "  🚀 $component_name (优先级: $priority)"
        else
            log_info "  ⏭️  $component_name (优先级: $priority，已禁用)"
        fi
    done

    local failed=false
    for component_info in "${sorted_components[@]}"; do
        IFS=':' read -r priority component_name enabled script_path <<< "$component_info"
        [[ "$enabled" == "true" ]] || continue

        if [[ -z "${script_path:-}" || ! -f "$script_path" ]]; then
            log_error "❌ 组件部署脚本不存在: ${BUSINESS_APP_ROOT}/${component_name}"
            return 1
        fi

        log_info "🚀 ${action} $component_name..."
        if call_subscript "$script_path" "$action" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ $component_name ${action} 成功"
        else
            log_error "❌ $component_name ${action} 失败"
            failed=true
            [[ "$action" == "uninstall" ]] || return 1
        fi
    done

    [[ "$failed" == "false" ]]
}

run_business_app() {
    local action="$1"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"

    log_info "开始执行 ${BUSINESS_APP_NAME}: $action"
    log_info "项目: $project_id, 命名空间: $namespace, 环境: $environment"

    run_components_by_priority "$action" "$project_id" "$namespace" "$environment" "$dry_run"

    log_success "✅ ${BUSINESS_APP_NAME} $action 完成！"
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"
    [[ -n "${CLUSTER:-}" ]] && log_info "🎯 当前集群配置: ${CLUSTER}"

    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" || "$action" == "logs" ]]; then
        shift
    fi

    local project_id="${1:-$DEFAULT_PROJECT_ID}"
    local namespace="${2:-$DEFAULT_NAMESPACE}"
    local environment="${3:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${4:-false}"

    case "$action" in
        deploy|uninstall|status|logs)
            run_business_app "$action" "$project_id" "$namespace" "$environment" "$dry_run"
            ;;
        *)
            log_error "未知操作: $action"
            echo "用法: $0 [--cluster C1|C2|KIND] [deploy|uninstall|status|logs] [project_id] [namespace] [environment] [dry_run]"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
