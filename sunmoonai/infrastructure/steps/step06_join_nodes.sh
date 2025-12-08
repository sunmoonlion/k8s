#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP06
TARGET="${STEP06_TARGET:-all}"
PARALLEL="${STEP06_PARALLEL_JOBS:-3}"
JOIN_CP="${STEP06_JOIN_CONTROL_PLANE:-true}"
PACKAGES_DEPLOY_MODE_EFFECTIVE="$(get_packages_deploy_mode)"

# 远端 kubeconfig 路径（用于在主节点上执行所有 kubectl 调用）
REMOTE_KUBECONFIG="${STEP06_REMOTE_KUBECONFIG:-/etc/kubernetes/admin.conf}"

# 获取统一的 K8s 版本
K8S_VERSION_RESOLVED="$(get_k8s_version_resolved)"

required_artifacts(){
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    # 加入节点常见最小镜像：pause 与 kube-proxy（具体版本与 repo 由 init/集群组件决定，这里给出占位，后续可按版本解析）
    echo "type=images image='registry.k8s.io/pause:3.9'"
  fi
}

if [[ "${1:-}" == "--required-artifacts" ]]; then
  required_artifacts
  exit 0
fi

precheck(){ log_info "[Step06] 预检 join 节点"; }
ensure_resources(){ :; }

# 在指定索引节点上准备可读的 kubeconfig（使用统一函数）
_prepare_remote_kubeconfig_for_idx(){
  local idx="$1"
  prepare_remote_kubeconfig "$idx" "REMOTE_KUBECONFIG" || {
    log_error "[Step06] 无法在远端节点 $idx 准备可读的 kubeconfig"
    return 1
  }
}

_get_join_cmd(){
  # 动态查找 master 节点并生成 join 命令
  local master_idx=""
  local idx
  
  # 遍历所有节点，找到第一个 master 节点
  for idx in $(seq 1 10); do
    local node_type_raw
    node_type_raw="$(get_server_var "$idx" TYPE 2>/dev/null || true)"
    
    if [[ -n "$node_type_raw" ]]; then
      local node_type="$node_type_raw"
      if [[ "$node_type" == "master" ]]; then
        master_idx="$idx"
        break
      fi
    fi
  done
  
  if [[ -z "$master_idx" ]]; then
    log_error "[Step06] 未找到 master 节点"
    return 1
  fi
  
  local join_cmd
  join_cmd="$(ssh_exec_sudo "$master_idx" "kubeadm token create --print-join-command --kubeconfig /etc/kubernetes/admin.conf" 2>&1)"
  local exit_code=$?
  
  if [[ $exit_code -eq 0 && -n "$join_cmd" ]]; then
    echo "$join_cmd"
  else
    log_error "[Step06] 生成 join 命令失败"
    return 1
  fi
}

execute(){
  local i="${1:-$i}"    # 优先使用传入参数 $1，否则使用现成的 i（兼容旧用法）
  
  # 检查当前节点是否是 master 节点，如果是则跳过
  local node_type_raw
  node_type_raw="$(get_server_var "$i" TYPE 2>/dev/null || true)"
  log_info "[Step06] 节点 $i 类型: '$node_type_raw'"
  if [[ -n "$node_type_raw" && "$node_type_raw" == "master" ]]; then
    log_info "[Step06] 节点 $i 是 master 节点，跳过 join 操作"
    return 0
  fi
  
  # 仅对 worker 节点执行 join
  local join; join="$(_get_join_cmd)"
  if [[ -z "$join" ]]; then log_warn "[Step06] 未获得 join 命令，跳过"; return 0; fi
  
  # 检查控制平面是否就绪
  log_info "[Step06] 检查控制平面状态..."
  
  # 动态查找 master 节点
  local master_idx=""
  local idx_master
  for idx_master in $(seq 1 10); do
    if [[ -n "$(get_server_var "$idx_master" TYPE 2>/dev/null || true)" ]]; then
      local node_type="$(get_server_var "$idx_master" TYPE)"
      if [[ "$node_type" == "master" ]]; then
        master_idx="$idx_master"
        break
      fi
    fi
  done
  
  if [[ -z "$master_idx" ]]; then
    log_error "[Step06] 未找到 master 节点"
    return 1
  fi
  
  _prepare_remote_kubeconfig_for_idx "$master_idx" || return 1
  if ! ssh_exec "$master_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get nodes >/dev/null 2>&1'"; then
    log_error "[Step06] 控制平面未就绪，请先完成 step04 kubeadm init"
    return 1
  fi
  log_info "[Step06] 控制平面就绪"
  
  # 已加入检测：若 kubelet.service 存在且节点就绪则跳过
  # 在主节点上使用 KUBECONFIG 检查节点是否已存在
  local node_name
  node_name="$(ssh_exec "$i" "bash -lc 'hostname'" 2>/dev/null || true)"
  if [[ -n "$node_name" ]] && ssh_exec "$master_idx" "bash -lc 'KUBECONFIG=\"$REMOTE_KUBECONFIG\" kubectl get nodes --no-headers 2>/dev/null | grep -q "^$node_name\\b"'"; then
    log_info "[Step06] 节点 $i 已在集群中，跳过"
    return 0
  fi
  
  # 检查节点是否有旧的 Kubernetes 配置，如果有则清理
  if ssh_exec "$i" "bash -lc 'test -f /etc/kubernetes/kubelet.conf || test -f /etc/kubernetes/pki/ca.crt || test -d /etc/kubernetes/pki'"; then
    log_warn "[Step06] 节点 $i 存在旧的 Kubernetes 配置，正在清理..."
    ssh_exec_sudo "$i" "kubeadm reset --force" || true
    ssh_exec_sudo "$i" "rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd" || true
    ssh_exec_sudo "$i" "systemctl stop kubelet" || true
    log_info "[Step06] 节点 $i 旧配置清理完成"
  fi
  
  # 根据 packages_deploy_mode 选择镜像获取方式
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    # 使用 packages 方式：检查远程安装目录下的镜像 tar 文件
    log_info "[Step06] 检查远程安装目录下的 join 节点镜像 tar 文件"
    
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$i" DIR)")"; dir="${dir:-~/packages-to-be-installed}"
    local dir_expr
    if [[ "$dir" == ~* ]]; then
      dir_expr="\"\$HOME${dir#\~}\""
    else
      dir_expr="\"$dir\""
    fi
    
    # 检查远程 images 目录下的 tar 文件
    if ! ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; ls \"\$base/images\"/registry.k8s.io_*.tar >/dev/null 2>&1'"; then
      log_error "[Step06] 节点 $i 缺少 join 节点镜像 tar 文件"
      log_error "  - 期望文件模式: $dir/images/registry.k8s.io_*.tar"
      log_info "[Step06] 请使用 packages-management.sh 拉取并安装这些镜像"
      log_info "在镜像拉取界面中输入以下镜像（每行一个，输入完成后直接按回车）："
      echo "  registry.k8s.io/pause:3.9"
      echo "  registry.k8s.io/kube-proxy:${K8S_VERSION_RESOLVED:-v1.30.0}"
      return 1
    else
      log_info "[Step06] join 节点镜像 tar 文件已存在，开始加载"
      # 加载镜像 tar 文件
      ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; for tar_file in \"\$base/images\"/registry.k8s.io_*.tar; do sudo nerdctl -n k8s.io load -i \"\$tar_file\"; done'"
    fi
  else
    # 在线：允许 kubeadm/容器运行时直接从上游仓库拉取镜像
    log_info "[Step06] 在线模式：将使用默认镜像仓库在线拉取（如需镜像加速请在 step02 配置 containerd mirror）"
    local score; score="$(online_check_score)"
    if [[ "$score" -lt 1 ]]; then
      log_error "[Step06] 网络连接检查失败（得分: $score/3）"
      log_error "[Step06] 请检查网络连接或切换到 offline 模式"
      return 1
    fi
  fi
  
  log_info "[Step06] 节点 $i 执行: $join"
  ssh_exec_sudo "$i" "$join" || true
}

verify(){ log_info "[Step06] join 完成（略）"; }

main(){ precheck; ensure_resources; for_each_node "$TARGET" execute; verify; }
main "$@"


