#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$THIS_DIR")"

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
# shellcheck source=deploy-runtime-helpers.sh
[[ -f "$K8S_ROOT_DIR/utils/deploy-runtime-helpers.sh" ]] && source "$K8S_ROOT_DIR/utils/deploy-runtime-helpers.sh"

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

APP_PLATFORM_CONFIG_FILE="$THIS_DIR/deploy-app-platform-all.conf"
if [[ -f "$APP_PLATFORM_CONFIG_FILE" ]]; then
    source "$APP_PLATFORM_CONFIG_FILE"
    if [[ -f "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh" ]]; then
        source "$K8S_ROOT_DIR/utils/cluster-config-mapping.sh"
        apply_cluster_config_mapping
    fi
    log_info "已加载 App Platform 配置: $APP_PLATFORM_CONFIG_FILE"
else
    log_error "缺少 App Platform 配置文件: $APP_PLATFORM_CONFIG_FILE"
    exit 1
fi

DEFAULT_PROJECT_ID="${APP_PLATFORM_PROJECT_ID:-sunmoonai}"
DEFAULT_NAMESPACE="${APP_PLATFORM_NAMESPACE:-app-platform-dev}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-development}"

call_subscript() {
    local script_path="$1"
    shift
    if declare -F call_deploy_subscript >/dev/null 2>&1; then
        call_deploy_subscript "$K8S_ROOT_DIR" "$script_path" "$@"
        return $?
    fi
    if [[ -n "${CLUSTER:-}" ]]; then
        DISABLE_AUTO_CLEANUP=true "$script_path" --cluster "$CLUSTER" "$@"
    else
        DISABLE_AUTO_CLEANUP=true "$script_path" "$@"
    fi
}

collect_business_apps() {
    local apps=()
    local app_dir app_name var_base enabled_var priority_var enabled priority script_path

    for app_dir in "$PROJECT_ROOT"/*-app; do
        [[ -d "$app_dir" ]] || continue
        app_name="$(basename "$app_dir")"
        var_base="$(echo "$app_name" | tr '-' '_')"
        enabled_var="${var_base}_enabled"
        priority_var="${var_base}_priority"
        enabled="false"
        priority="100"
        eval "enabled=\${${enabled_var}:-false}"
        eval "priority=\${${priority_var}:-100}"
        script_path="$app_dir/deploy-${app_name}-all/deploy-${app_name}-all.sh"

        apps+=("$priority:$app_name:$enabled:$script_path")
    done

    if [[ -d "$PROJECT_ROOT/research-app" ]]; then
        log_error "发现已退役的活动目录: $PROJECT_ROOT/research-app"
        log_error "未来 Research App 必须按新领域重新实例化，不能复用历史 Investment 前身。"
        return 1
    fi

    printf '%s\n' "${apps[@]}"
}

run_business_apps_by_priority() {
    local action="$1"
    local project_id="$2"
    local namespace="$3"
    local environment="$4"
    local dry_run="${5:-false}"
    local apps=()

    while IFS= read -r line; do
        [[ -n "$line" ]] && apps+=("$line")
    done < <(collect_business_apps)

    if [[ ${#apps[@]} -eq 0 ]]; then
        log_warn "⚠️  没有发现业务应用目录"
        return 0
    fi

    local sort_flag="-nr"
    [[ "$action" == "uninstall" ]] && sort_flag="-n"
    IFS=$'\n' sorted_apps=($(sort -t: -k1 $sort_flag <<<"${apps[*]}"))
    unset IFS

    log_info "📋 业务应用${action}顺序："
    for app_info in "${sorted_apps[@]}"; do
        IFS=':' read -r priority app_name enabled script_path <<< "$app_info"
        if [[ "$enabled" == "true" ]]; then
            log_info "  🚀 $app_name (优先级: $priority)"
        else
            log_info "  ⏭️  $app_name (优先级: $priority，已禁用)"
        fi
    done

    local failed=false
    for app_info in "${sorted_apps[@]}"; do
        IFS=':' read -r priority app_name enabled script_path <<< "$app_info"
        [[ "$enabled" == "true" ]] || continue

        if [[ ! -f "$script_path" ]]; then
            log_error "❌ 业务应用总控脚本不存在: $script_path"
            return 1
        fi

        log_info "🚀 ${action} $app_name..."
        if call_subscript "$script_path" "$action" "$project_id" "$namespace" "$environment" "$dry_run"; then
            log_success "✅ $app_name ${action} 成功"
        else
            log_error "❌ $app_name ${action} 失败"
            failed=true
            [[ "$action" == "uninstall" ]] || return 1
        fi
    done

    [[ "$failed" == "false" ]]
}

run_app_platform() {
    local action="$1"
    local project_id="${2:-$DEFAULT_PROJECT_ID}"
    local namespace="${3:-$DEFAULT_NAMESPACE}"
    local environment="${4:-$DEFAULT_ENVIRONMENT}"
    local dry_run="${5:-false}"

    log_info "开始执行 App Platform: $action"
    log_info "项目: $project_id, 命名空间: $namespace, 环境: $environment"

    run_business_apps_by_priority "$action" "$project_id" "$namespace" "$environment" "$dry_run"

    log_success "✅ App Platform $action 完成！"
}

main() {
    set -- "${ORIGINAL_ARGS[@]}"

    [[ -n "${CLUSTER:-}" ]] && log_info "🎯 当前集群配置: ${CLUSTER}"

    local action="${1:-deploy}"
    if [[ "$action" == "deploy" || "$action" == "uninstall" || "$action" == "status" || "$action" == "logs" ]]; then
        shift
    fi

    local project_id="${1:-${APP_PLATFORM_PROJECT_ID:-$DEFAULT_PROJECT_ID}}"
    local namespace="${2:-${APP_PLATFORM_NAMESPACE:-$DEFAULT_NAMESPACE}}"
    local environment="${3:-${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}}"
    local dry_run="${4:-false}"

    case "$action" in
        deploy|uninstall|status|logs)
            run_app_platform "$action" "$project_id" "$namespace" "$environment" "$dry_run"
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
