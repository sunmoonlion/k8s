#!/usr/bin/env bash
# Pure request helpers. Sourcing this file does not contact services or write files.

# Call before configuration, connection libraries, traps or temporary files.
# Profiles describe existing positional APIs; named --dry-run works for all of them.
# Outputs: SUNMOON_DEPLOY_PLAN_ONLY (handled without execution) and
# SUNMOON_DEPLOY_EXEC_ARGS (normalized API; deploy-project removes optional deploy).
sunmoon_deploy_entry() {
    local entry="$1" profile="$2"
    shift 2
    local named='' positional='' inherited="${SUNMOON_DEPLOY_DRY_RUN:-false}"
    local cluster="${CLUSTER:-<配置默认>}" value='' index=-1 action=deploy
    local -a positions=() position_indices=()
    SUNMOON_DEPLOY_EXEC_ARGS=()
    SUNMOON_DEPLOY_PLAN_ONLY=false
    [[ "$inherited" == true || "$inherited" == false ]] || {
        printf '%s\n' 'SUNMOON_DEPLOY_DRY_RUN 必须为 true/false' >&2; return 2;
    }
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run|--dry-run=*)
                [[ -z "$named" ]] || { printf '%s\n' '重复的 --dry-run' >&2; return 2; }
                value=true
                if [[ "$1" == --dry-run=* ]]; then
                    value="${1#*=}"
                elif [[ "${2:-}" == true || "${2:-}" == false ]]; then
                    value="$2"; shift
                fi
                [[ "$value" == true || "$value" == false ]] || {
                    printf '%s\n' '--dry-run 只接受 true/false' >&2; return 2;
                }
                named="$value"; shift ;;
            --[cC][lL][uU][sS][tT][eE][rR]|-c|-C)
                [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || {
                    printf '%s\n' 'cluster 参数缺少值' >&2; return 2;
                }
                cluster="$2"; SUNMOON_DEPLOY_EXEC_ARGS+=("$1" "$2"); shift 2 ;;
            --[cC][lL][uU][sS][tT][eE][rR]=*)
                cluster="${1#*=}"
                [[ -n "$cluster" ]] || return 2
                SUNMOON_DEPLOY_EXEC_ARGS+=("$1"); shift ;;
            -[cC][0-9]*)
                cluster="${1:2}"; SUNMOON_DEPLOY_EXEC_ARGS+=("$1"); shift ;;
            --help|-h)
                position_indices+=("${#SUNMOON_DEPLOY_EXEC_ARGS[@]}")
                positions+=("$1"); SUNMOON_DEPLOY_EXEC_ARGS+=("$1"); shift ;;
            --*)
                # These legacy entries have no other named API. Never let a typo deploy.
                printf '%s\n' '不支持的部署选项；请核对该入口的参数说明' >&2; return 2 ;;
            *)
                position_indices+=("${#SUNMOON_DEPLOY_EXEC_ARGS[@]}")
                positions+=("$1"); SUNMOON_DEPLOY_EXEC_ARGS+=("$1"); shift ;;
        esac
    done
    case "$profile" in
        root) index=3; action="${positions[0]:-deploy}" ;;
        action) index=4; action="${positions[0]:-deploy}" ;;
        action-logs-tail)
            index=4; action="${positions[0]:-deploy}"
            # RabbitMQ's existing logs API uses this slot for a numeric tail count.
            if [[ "$action" == logs && "${positions[4]:-}" =~ ^-?[0-9]+$ ]]; then index=-1; fi
            ;;
        project) index=3 ;;
        deploy-project)
            # These Secret writers implement deployment only. Reject action words
            # before configuration, rather than interpreting status as project_id.
            case "${positions[0]:-}" in
                deploy)
                    unset 'SUNMOON_DEPLOY_EXEC_ARGS[position_indices[0]]'
                    SUNMOON_DEPLOY_EXEC_ARGS=("${SUNMOON_DEPLOY_EXEC_ARGS[@]}")
                    positions=("${positions[@]:1}") ;;
            esac
            case "${positions[0]:-}" in
                deploy|status|uninstall|delete|logs|upgrade|apply|generate|restart|start|stop|cleanup|plan|verify|install)
                    printf '%s\n' '此 Secret 入口仅支持 deploy；其他动作请使用组件总控。' >&2
                    return 2 ;;
            esac
            if [[ "${positions[0]:-}" == help || "${positions[0]:-}" == -h || "${positions[0]:-}" == --help ]]; then
                [[ ${#positions[@]} -eq 1 ]] || { printf '%s\n' 'help 不接受位置参数' >&2; return 2; }
                SUNMOON_DEPLOY_PLAN_ONLY=true
                printf '用法: %q [deploy] [project namespace environment dry_run] [--cluster CLUSTER] [--dry-run]\n' "$entry"
                printf '%s\n' '仅部署 Secret；dry_run 为 true/false。status/uninstall 等动作词不能用作项目ID。'
                return 0
            fi
            [[ ${#positions[@]} -le 4 ]] || { printf '%s\n' 'Secret 部署位置参数过多' >&2; return 2; }
            index=3 ;;
        optional-action)
            index=3
            case "${positions[0]:-}" in
                deploy|upgrade|uninstall|delete|status|logs|help|-h|--help)
                    index=4; action="${positions[0]}" ;;
            esac
            ;;
        namespace)
            action="${positions[0]:-deploy}"
            # Compact API: action namespace dry_run; legacy parent API has five args.
            if [[ ${#positions[@]} -le 3 ]]; then index=2; else index=4; fi
            ;;
        named) ;; # Auxiliary tools keep their existing positional API.
        *) printf '%s\n' '未知部署参数契约' >&2; return 2 ;;
    esac
    if (( index >= 0 && ${#positions[@]} > index )); then
        positional="${positions[$index]}"
        [[ "$positional" == true || "$positional" == false ]] || {
            printf '%s\n' '位置参数 dry_run 必须为 true/false；也可使用 --dry-run' >&2; return 2;
        }
    fi
    if [[ -n "$named" && -n "$positional" && "$named" != "$positional" ]]; then
        printf '%s\n' '命名与位置 dry_run 参数冲突' >&2; return 2
    fi
    if [[ "$inherited" == true && ( "$named" == false || "$positional" == false ) ]]; then
        printf '%s\n' '子请求不能关闭继承的 dry-run' >&2; return 2
    fi
    if [[ "$inherited" == true || "$named" == true || "$positional" == true ]]; then
        SUNMOON_DEPLOY_PLAN_ONLY=true
        export SUNMOON_DEPLOY_DRY_RUN=true DISABLE_AUTO_CLEANUP=true
        printf '请求计划 entry=%q action=%q cluster=%q\n' "$entry" "$action" "$cluster"
        printf '%s\n' '请求已在加载配置之前识别为计划；组件直接返回，总控可继续读取本地配置列出计划。'
        printf '%s\n' '不执行部署、连接服务、生成凭据文件或清理。'
        printf '%s\n' '这里只确认请求为计划模式；配置、模板、参数目标和实际部署结果仍需另行核对。'
    fi
    return 0
}

sunmoon_deploy_validate_mode() {
    case "${1:-}" in
        true) export DISABLE_AUTO_CLEANUP=true ;;
        false) ;;
        *)
            # Invalid requests must not fall through to legacy EXIT cleanup either.
            export DISABLE_AUTO_CLEANUP=true
            printf '%s\n' 'dry_run 必须为 true 或 false' >&2
            return 1
            ;;
    esac
}

sunmoon_deploy_print_plan() {
    local component="$1" action="$2" project="$3" namespace="$4" environment="$5"
    case "$action" in
        deploy|upgrade|uninstall|status|logs) ;;
        console)
            [[ "$component" == object-storage ]] || {
                printf '%s\n' 'console 计划只适用于 object-storage' >&2; return 1;
            }
            ;;
        *) printf '不支持的计划动作: %q\n' "$action" >&2; return 1 ;;
    esac
    printf '计划 component=%q action=%q cluster=%q project=%q namespace=%q environment=%q\n' \
        "$component" "$action" "${CLUSTER:-<未指定>}" "$project" "$namespace" "$environment"
    printf '%s\n' '仅列出请求；不连接集群、不调用子脚本、不生成 Secret/values、不执行 Helm 或连接清理。'
    printf '%s\n' '本输出不是 Helm 渲染结果，也不证明凭据、镜像、存储或服务可部署。'
}
