#!/usr/bin/env bash
#
# Step13: Ingress (Traefik) & Harbor 部署
# 职责：
# - 在远程集群上触发 Traefik 与 Harbor 的部署脚本；
# - 实际是否部署仍由各组件自身的配置开关决定（保持历史行为），本步骤只负责在基础设施阶段统一调用。
#
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP13
TARGET="${STEP13_TARGET:-master}"

# 本步骤不声明额外离线依赖（Traefik/Harbor 所需镜像已由 Step11 准备）
required_artifacts(){ return 0; }
if [[ "${1:-}" == "--required-artifacts" ]]; then
  required_artifacts
  exit 0
fi

precheck(){
  log_info "[Step13] 预检 Ingress/Harbor 部署"

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
    log_info "[Step13] 当前集群为 KIND，跳过远程 Ingress/Harbor 部署"
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
      log_warn "[Step13] Traefik 部署脚本执行失败，请检查 ingress-platform/deploy-ingress-platform-all 或单独运行该脚本查看原因"
    else
      log_success "[Step13] Traefik 部署脚本执行完成"
    fi
  else
    log_warn "[Step13] 找不到 Traefik 部署脚本或无执行权限: $traefik_deploy_all"
  fi

  # 2. 部署 Harbor（cicd-platform/harbor）
  local harbor_deploy_sh="$project_root/../cicd-platform/harbor/deploy-harbor/deploy-harbor.sh"
  if [[ -x "$harbor_deploy_sh" ]]; then
    log_info "[Step13] 调用 Harbor 部署脚本: $harbor_deploy_sh deploy"
    if ! CLUSTER="$cluster_selected" "$harbor_deploy_sh" deploy; then
      log_warn "[Step13] Harbor 部署脚本执行失败，请检查 cicd-platform/harbor/deploy-harbor 或单独运行该脚本查看原因"
    else
      log_success "[Step13] Harbor 部署脚本执行完成"
    fi
  else
    log_warn "[Step13] 找不到 Harbor 部署脚本或无执行权限: $harbor_deploy_sh"
  fi
}

verify(){
  log_info "[Step13] Ingress/Harbor 部署步骤已完成（具体启用状态由各组件自身配置决定）"
}

main(){
  precheck
  execute
  verify
}

main "$@"

