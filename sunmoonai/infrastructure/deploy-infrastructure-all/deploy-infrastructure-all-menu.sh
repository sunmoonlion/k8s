#!/usr/bin/env bash
# 云上升级路径未经实机验证。菜单只转发到同目录总控，不另维护步骤或配置。
set -euo pipefail

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROLLER="$THIS_DIR/deploy-infrastructure-all.sh"
K8S_ROOT_DIR="$(cd "$THIS_DIR/../../.." && pwd)"
# shellcheck source=/dev/null
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"
unified_parse_cluster_arg "$@"

run_command() {
    local action="$1"
    shift
    case "$action" in
        full|deploy|all) action=deploy ;;
        reset) action=step00_reset ;;
        baseline) action=step01_os_baseline ;;
        runtime) action=step02_runtime ;;
        binaries) action=step03_k8s_binaries ;;
        init) action=step04_kubeadm_init ;;
        cni) action=step05_cni_install ;;
        join) action=step06_join_nodes ;;
        namespaces) action=step07_create_namespaces ;;
        validate) action=step08_validate ;;
        storage) action=step09_storage ;;
        nodes) action=step10_k8s_nodes_management ;;
        images) action=step11_load_initial_images ;;
        ca|step12) action=step12_ca_generation ;;
        ingress|step13) action=step13_ingress_and_harbor ;;
    esac
    bash "$CONTROLLER" "$action" "$@"
}

if [[ ${#PARSED_ARGS[@]} -gt 0 ]]; then
    run_command "${PARSED_ARGS[@]}"
    exit $?
fi
if [[ ! -t 0 ]]; then
    echo "用法: $0 --cluster C1 [deploy|status|baseline|runtime|binaries|init|cni|join|namespaces|validate|storage|nodes|images|ca|ingress]"
    exit 0
fi
if [[ ! "${CLUSTER:-}" =~ ^C[0-9]+$ ]]; then
    echo "必须用 --cluster Cn 或 CLUSTER=Cn 显式指定集群" >&2
    exit 1
fi
while true; do
    cat <<MENU

Kubernetes 部署菜单 — ${CLUSTER}（云上升级路径未经实机验证）
1) 完整部署（不自动调用 step00，旧步骤仍待整改）
2) 历史集群重置（本次迁移禁用）
3) 操作系统基线      4) 容器运行时       5) Kubernetes 工具
6) 控制面初始化      7) 网络插件         8) 节点加入
9) 命名空间          10) 集群验证        11) 存储
12) 节点管理         13) 初始镜像        14) CA 管理
15) 入口 Traefik（Harbor 独立运行）
s) 脚本状态          0) 退出
MENU
    read -r -p "请选择操作: " choice || break
    case "$choice" in
        1) action=deploy ;;
        2) echo "旧重置脚本会删除运行时和数据，本次迁移不可使用。"; continue ;;
        3) action=baseline ;; 4) action=runtime ;; 5) action=binaries ;;
        6) action="init" ;; 7) action=cni ;; 8) action="join" ;;
        9) action=namespaces ;; 10) action=validate ;; 11) action=storage ;;
        12) action=nodes ;; 13) action=images ;; 14) action=ca ;;
        15) action=ingress ;; s|c) action=status ;;
        0|q) break ;;
        *) echo "无效选择"; continue ;;
    esac
    # 经同一别名映射转发；不放在 if/! 条件中，以免影响 errexit。
    run_command "$action"
done
