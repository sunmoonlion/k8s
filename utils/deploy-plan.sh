#!/usr/bin/env bash
# Pure request helpers. Sourcing this file does not contact services or write files.

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
