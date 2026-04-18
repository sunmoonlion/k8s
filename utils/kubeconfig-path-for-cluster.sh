#!/usr/bin/env bash
# 从 k8s-admin.conf 解析指定集群应使用的 kubeconfig 文件路径（单一路径，供总控脚本与校验逻辑共用）
# 用法: kubeconfig_path_from_admin_conf <k8s-admin.conf 绝对路径> <KIND|C1|C2|...>
# 成功时打印路径；无法解析时返回非 0

kubeconfig_path_from_admin_conf() {
    local conf="$1"
    local cu
    cu=$(echo "${2:-}" | tr '[:lower:]' '[:upper:]')
    [[ -f "$conf" ]] || return 1

    if [[ "$cu" == "KIND" ]]; then
        local path
        path=$(sed -n '/^\[KIND\]$/,/^\[/p' "$conf" | grep '^kubeconfig=' | head -1 | cut -d'=' -f2- | tr -d ' ')
        path="${path/#\~/$HOME}"
        path=$(eval echo "$path")
        [[ -n "$path" ]] || { echo "${HOME}/.kube/kind-config"; return 0; }
        echo "$path"
        return 0
    fi

    if [[ "$cu" =~ ^C[0-9]+$ ]]; then
        local path
        path=$(sed -n "/^\[${cu}_DIRECT\]$/,/^\[/p" "$conf" | grep '^kubeconfig=' | head -1 | cut -d'=' -f2- | tr -d ' ')
        if [[ -z "$path" ]]; then
            path=$(sed -n "/^\[${cu}_BASTION\]$/,/^\[/p" "$conf" | grep '^kubeconfig=' | head -1 | cut -d'=' -f2- | tr -d ' ')
        fi
        path="${path/#\~/$HOME}"
        path=$(eval echo "$path")
        [[ -n "$path" ]] || return 1
        echo "$path"
        return 0
    fi

    return 1
}
