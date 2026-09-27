#!/usr/bin/env bash
#
# Step13: Ingress (Traefik) only. Cloud path 未经实机验证.
# Historical filename retained for existing callers; Harbor runs outside clusters.
# 职责：
# - 在远程集群上仅触发 Traefik 部署；
# - 实际是否部署仍由各组件自身的配置开关决定（保持历史行为），本步骤只负责在基础设施阶段统一调用。
#
set -euo pipefail
if [[ "${1:-}" == --dry-run || "${REGISTRY_DRY_RUN:-false}" == true ]]; then
  echo '[dry-run] Step13: deploy cluster ingress only; no Harbor lifecycle action; cloud 未经实机验证'
  exit 0
fi

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

# 本步骤不声明额外离线依赖（Traefik 所需镜像已由 Step11 准备）
required_artifacts(){ return 0; }
if [[ "${1:-}" == "--required-artifacts" ]]; then
  required_artifacts
  exit 0
fi

precheck(){
  log_info "[Step13] 预检 Ingress 部署"

  # 若全局开关关闭，直接退出（保持与 deploy-infrastructure-all 中的 STEP13_ENABLED 一致）
  if [[ "${STEP13_ENABLED:-true}" != "true" ]]; then
    log_info "[Step13] STEP13_ENABLED=false，跳过"
    exit 0
  fi

  # KIND 场景下不应执行本步骤（Kind 使用 kind-infrastructure/deploy-kind.sh）
  local cluster_selected="${CLUSTER:-C1}"
  local cluster_upper
  cluster_upper=$(echo "$cluster_selected" | tr '[:lower:]' '[:upper:]')
  if [[ "$cluster_upper" == "KIND" ]]; then
    log_info "[Step13] 当前集群为 KIND，跳过远程 Ingress 部署"
    exit 0
  fi
}

execute(){
  local cluster_selected="${CLUSTER:-C1}"
  log_info "[Step13] 使用集群: ${cluster_selected}"

  local project_root
  project_root="$(cd "$BASE_DIR/.." && pwd)"

  # 1. 部署 Traefik（ingress-platform）
  local traefik_deploy_all="$project_root/../ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh"
  if [[ -x "$traefik_deploy_all" ]]; then
    log_info "[Step13] 调用 Traefik 部署脚本: $traefik_deploy_all"
    if ! CLUSTER="$cluster_selected" "$traefik_deploy_all"; then
      log_error "[Step13] Traefik 部署脚本执行失败，停止本步骤"
      return 1
    else
      log_success "[Step13] Traefik 部署脚本执行完成"
    fi
  else
    log_error "[Step13] 找不到 Traefik 部署脚本或无执行权限: $traefik_deploy_all"
    return 1
  fi

  # Harbor is an independent host service, prepared before Step11.
  # Never invoke the historical in-cluster deployment from this step.

}

verify(){
  log_info "[Step13] Ingress 部署步骤已完成（仅表示子脚本成功返回；Pod 就绪和入口连通性仍需验收）"
}

main(){
  precheck
  execute
  verify
}

main "$@"
