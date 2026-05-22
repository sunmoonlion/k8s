#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP03
TARGET="${STEP03_TARGET:-all}"
K8S_VERSION="${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-}}"
APT_AUTO="${STEP03_APT_CHANNEL_AUTO:-true}"
HOLD_PKGS="${STEP03_HOLD_PACKAGES:-true}"
KUBELET_ARGS="${STEP03_KUBELET_EXTRA_ARGS:-}"
ONLINE_TIMEOUT="${STEP03_ONLINE_TIMEOUT:-600}"
REMOTE_DIR_FALLBACK="~/packages-to-be-installed"
PACKAGES_DEPLOY_MODE_EFFECTIVE="$(get_packages_deploy_mode)"

required_artifacts(){
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    local k8s_ver="${STEP03_K8S_VERSION:-$CLUSTER_VERSION}"
    echo "type=debs pattern='kubeadm_${k8s_ver}-*_amd64.deb'"
    echo "type=debs pattern='kubelet_${k8s_ver}-*_amd64.deb'"
    echo "type=debs pattern='kubectl_${k8s_ver}-*_amd64.deb'"
  fi
}

if [[ "${1:-}" == "--required-artifacts" ]]; then
  required_artifacts
  exit 0
fi

precheck(){ log_info "[Step03] 预检 K8s 二进制 ($K8S_VERSION)"; }
ensure_resources(){ :; }

# 统一的 kubelet 配置函数
_configure_kubelet_args(){
  local node="$1"
  # 写入 kubelet extra args（如 systemd cgroup）
  if [[ -n "$KUBELET_ARGS" ]]; then
    ssh_exec_sudo "$node" "bash -lc 'mkdir -p /etc/default && printf %s\\n \"KUBELET_EXTRA_ARGS=\\\"$KUBELET_ARGS\\\"\" > /etc/default/kubelet; systemctl daemon-reload'" || true
  fi
  # 确保 kubeadm init 前 kubelet 不占用 10250（首次安装常被自动启动）
  ssh_exec_sudo "$node" "bash -lc 'if [ ! -r /etc/kubernetes/admin.conf ]; then systemctl disable --now kubelet || true; fi'" || true
}

_add_k8s_repo_cmd(){
  # $1: channel like core:/stable:/v1.30
  local channel="$1"
  cat <<CMD
set -e
export DEBIAN_FRONTEND=noninteractive
APT_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
apt-get update -y || true
apt-get install -y \$APT_OPTS ca-certificates curl gnupg || true
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/$channel/deb/Release.key | gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
rm -f /etc/apt/sources.list.d/kubernetes.list
printf '%s\n' "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/$channel/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y || true
CMD
}

execute(){
  log_info "[Step03] 在节点 $i 安装 kubeadm/kubelet/kubectl"
  
  # 检查 crictl 是否已安装
  _check_crictl "$i" || return 1
  
  local dir; dir="$(resolve_remote_dir "$(get_server_var "$i" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
  # 构造远端目录表达式（与 step02_runtime.sh 保持一致）：
  local dir_expr
  if [[ "$dir" == ~* ]]; then
    dir_expr="\"\$HOME${dir#\~}\""
  else
    dir_expr="\"$dir\""
  fi
  local export_proxy=""; if [[ "${PROXY_ENABLED:-false}" == "true" ]]; then
    export_proxy="export HTTP_PROXY='${HTTP_PROXY:-}'; export HTTPS_PROXY='${HTTPS_PROXY:-}'; export NO_PROXY='${NO_PROXY:-}';"
  fi
  # 基础目录与分类目录（统一创建 debs/tar/images，实际使用按类型选择）
  ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; mkdir -p \"\$base\" \"\$base/debs\" \"\$base/tar\" \"\$base/images\"'" || true

  # 已安装检测：若 kubeadm/kubelet/kubectl 都存在则跳过安装，仅按需写入 kubelet args
  if ssh_exec "$i" "bash -lc 'command -v kubeadm >/dev/null 2>&1 && command -v kubelet >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1'"; then
    log_info "[Step03] 节点 $i 已检测到 kubeadm/kubelet/kubectl，跳过安装"
    _configure_kubelet_args "$i"
    [[ "$HOLD_PKGS" == "true" ]] && ssh_exec_sudo "$i" "apt-mark hold kubelet kubeadm kubectl || true"
    return 0
  fi

  # 在线优先安装 kubeadm/kubelet/kubectl，失败或离线则使用离线 deb
  local want_ver="$K8S_VERSION"
  if [[ -z "$want_ver" ]]; then want_ver="$(ssh_exec "$i" "bash -lc 'apt-cache policy kubelet 2>/dev/null | awk \"/Candidate:/ {print \\$2}\"'" || true)"; fi
  local install_ok=false

  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "online" ]]; then
    # step03 在线模式：检查必要条件
    _check_step03_online_conditions() {
      # 检查网络连接（step03 需要访问 Kubernetes 仓库）
      log_info "[Step03] 检查网络连接..."
      local score; score="$(online_check_score)"
      if [[ "$score" -lt 1 ]]; then
        log_error "[Step03] 网络连接检查失败（得分: $score/3）"
        log_error "[Step03] 请检查网络连接或切换到离线模式"
        return 1
      fi
      log_info "[Step03] 网络连接检查通过（得分: $score/3）"
      
      # 检查远程节点的包管理器
      if ! ssh_exec "$i" "bash -lc 'command -v apt-get >/dev/null 2>&1'"; then
        log_error "[Step03] 远程节点不支持 apt-get，请使用支持 apt 的发行版或切换到离线模式"
        return 1
      fi
      
      # 检查必要的工具
      if ! ssh_exec "$i" "bash -lc 'command -v curl >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1'"; then
        log_warn "[Step03] 缺少必要工具，需要在线安装"
        ssh_exec_sudo "$i" "bash -lc '${APT_NONINTERACTIVE_PREFIX}; apt-get update -y && apt-get install -y ${APT_INSTALL_OPTS} curl gnupg ca-certificates'" || {
          log_error "[Step03] 无法安装必要工具"
          return 1
        }
      else
        log_info "[Step03] 必要工具已存在，跳过安装"
      fi
      
      return 0
    }
    
    _check_step03_online_conditions || return 1
    
    # 可选：动态切换仓库（简单固定到 1.30 通道；可后续扩展按版本挑选）
    if [[ "$APT_AUTO" == "true" ]]; then
      log_info "[Step03] 节点 $i 添加 K8s 仓库"
      # 计算版本通道（默认 v1.30；若配置了 K8S_VERSION 则按主次版本匹配）
      local channel="core:/stable:/v1.30"; if [[ -n "$K8S_VERSION" ]]; then local minor; minor="$(echo "$K8S_VERSION" | awk -F. '{print $1"."$2}')"; channel="core:/stable:/v$minor"; fi
      ssh_exec_sudo "$i" "$export_proxy $(_add_k8s_repo_cmd "$channel")" || true
      
      # 验证仓库是否添加成功
      log_info "[Step03] 节点 $i 验证 K8s 仓库"
      ssh_exec "$i" "bash -lc 'ls -l /etc/apt/sources.list.d/kubernetes.list; echo ====; cat /etc/apt/sources.list.d/kubernetes.list'" || true
      ssh_exec "$i" "bash -lc 'apt-cache policy kubelet | sed -n "1,20p"'" || true
    fi
    
    # 在线安装（可配置超时，默认 600s）
    log_info "[Step03] 节点 $i 尝试在线安装 K8s 组件"
    if ssh_exec "$i" "$export_proxy bash -lc '${APT_NONINTERACTIVE_PREFIX}; timeout ${ONLINE_TIMEOUT} sudo apt-get update -y && timeout ${ONLINE_TIMEOUT} sudo apt-get install -y ${APT_INSTALL_OPTS} kubelet kubeadm kubectl'"; then
      install_ok=true
    fi
  fi

  if [[ "$install_ok" == false ]]; then
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
      # 离线模式：优先使用本地离线包
      log_info "[Step03] 离线模式：使用本地离线包"
      
      local k8s_ver="${STEP03_K8S_VERSION:-$CLUSTER_VERSION}"
      
      # 检查远程 debs 文件
      if ! ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; ls \"\$base/debs\"/kube*.deb >/dev/null 2>&1'"; then
        log_error "[Step03] 节点 $i 缺少 Kubernetes $k8s_ver 的 deb 包"
        log_error "  - 期望文件模式: $dir/debs/kube*.deb"
        log_info "[Step03] 请使用 packages-management.sh 上传 Kubernetes deb 包到远程节点"
        return 1
      fi
      
      log_info "[Step03] 找到离线 Kubernetes deb 包"
      
      # 离线 deb 安装（寻找 debs 目录下的 kube*.deb）
      log_info "[Step03] 节点 $i 离线安装 Kubernetes deb 包"
      if ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; ls \"\$base/debs\"/kube*.deb >/dev/null 2>&1'"; then
        # 先复制 deb 包到临时目录，再以 root 权限安装
        ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; cp \"\$base/debs\"/kube*.deb \"\$base/debs\"/kubernetes-cni*.deb /tmp/ 2>/dev/null || cp \"\$base/debs\"/kube*.deb /tmp/'" || {
          log_error "[Step03] 复制 deb 包到临时目录失败"
          return 1
        }
        ssh_exec_sudo "$i" "bash -lc '${APT_NONINTERACTIVE_PREFIX}; set -e; shopt -s nullglob; files=(/tmp/kube*.deb); if [ \${#files[@]} -gt 0 ]; then if ls /tmp/kubernetes-cni*.deb >/dev/null 2>&1; then dpkg -i /tmp/kubernetes-cni*.deb || true; fi; if ls /tmp/kubernetes-cni*.deb >/dev/null 2>&1; then dpkg -i \"\${files[@]}\" || apt-get install -f -y ${APT_INSTALL_OPTS}; else dpkg -i --force-depends \"\${files[@]}\" || apt-get install -f -y ${APT_INSTALL_OPTS}; fi; fi; rm -f /tmp/kube*.deb /tmp/kubernetes-cni*.deb'" && install_ok=true || {
          log_error "[Step03] deb 包安装失败"
          return 1
        }
      else
        log_error "[Step03] 未找到 Kubernetes deb 包"
        return 1
      fi
    else
      # 在线模式：在线安装失败，直接报错
      local k8s_ver="${STEP03_K8S_VERSION:-$CLUSTER_VERSION}"
      log_error "[Step03] 节点 $i 在线安装失败：在线仓库不可用或无候选版本"
      log_error "请检查网络连接或切换到离线模式"
      log_error "离线模式需要准备以下 Kubernetes $k8s_ver deb 包："
      log_error "  - kubeadm_${k8s_ver}-*_amd64.deb"
      log_error "  - kubelet_${k8s_ver}-*_amd64.deb"
      log_error "  - kubectl_${k8s_ver}-*_amd64.deb"
      log_error "下载地址：https://pkgs.k8s.io/core:/stable:/v${k8s_ver%.*}/deb/"
      return 1
    fi
  fi

  if [[ "$install_ok" == false ]]; then
    local k8s_ver="${STEP03_K8S_VERSION:-$CLUSTER_VERSION}"
    log_error "[Step03] 节点 $i 安装 kubeadm/kubelet/kubectl 失败"
    return 1
  fi

  # 验证安装是否成功
  log_info "[Step03] 验证 Kubernetes 组件安装"
  if ! ssh_exec "$i" "bash -lc 'command -v kubelet >/dev/null 2>&1 && command -v kubeadm >/dev/null 2>&1 && command -v kubectl >/dev/null 2>&1'"; then
    log_error "[Step03] 节点 $i Kubernetes 组件安装验证失败"
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
      log_error "[Step03] 离线模式下无法重新安装，请检查离线包是否完整"
      return 1
    else
      log_info "[Step03] 尝试在线重新安装..."
      ssh_exec_sudo "$i" "bash -lc '${APT_NONINTERACTIVE_PREFIX}; apt-get update -y && apt-get install -y ${APT_INSTALL_OPTS} kubelet kubeadm kubectl'" || {
        log_error "[Step03] 重新安装失败"
        return 1
      }
    fi
  fi

  # 若为在线安装，尝试缓存已安装版本 deb 包至 debs 目录（便于后续离线）
  if ssh_exec "$i" "bash -lc 'command -v apt-get >/dev/null 2>&1'"; then
    # 先创建目录，再下载 deb 包到用户目录
    ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; mkdir -p \"\$base/debs\"'" || true
    # 简化：直接下载到 /tmp，然后移动到用户目录
    ssh_exec_sudo "$i" "bash -lc 'cd /tmp && apt-get download kubeadm kubelet kubectl || true'" || true
    ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; mv /tmp/kube*.deb \"\$base/debs/\" 2>/dev/null || true'" || true
  fi

  # 配置 kubelet
  _configure_kubelet_args "$i"

  # hold 包，避免被误升级
  if [[ "$HOLD_PKGS" == "true" ]]; then
    ssh_exec_sudo "$i" "apt-mark hold kubelet kubeadm kubectl || true"
  fi
}

# 检查 crictl 是否已安装
_check_crictl() {
  local node="$1"
  
  log_info "[Step03] 节点 $node 检查 crictl 工具"
  
  if ! ssh_exec "$node" "bash -lc 'command -v crictl >/dev/null 2>&1'"; then
    log_error "[Step03] 节点 $node crictl 未安装"
    log_error "[Step03] 请先运行 Step02 安装容器运行时和 crictl"
    return 1
  fi
  
  # 验证 crictl 版本
  local crictl_version
  crictl_version="$(ssh_exec "$node" "bash -lc 'crictl --version 2>/dev/null | head -1 | grep -o \"v[0-9.]*\" || echo \"unknown\"'")"
  
  if [[ "$crictl_version" == "unknown" ]]; then
    log_warn "[Step03] 节点 $node crictl 版本检测失败，但工具存在"
  else
    log_info "[Step03] 节点 $node crictl 版本: $crictl_version"
  fi
  
  # 验证 crictl 功能
  if ! ssh_exec "$node" "bash -lc 'crictl version >/dev/null 2>&1'"; then
    log_warn "[Step03] 节点 $node crictl 功能验证失败，但继续执行（crictl 主要用于容器运行时调试，不影响 kubeadm 和 kubelet 的正常工作）"
  else
    log_info "[Step03] 节点 $node crictl 功能正常"
  fi
  
  return 0
}

verify(){
  log_info "[Step03] 验证 kubeadm/kubelet/kubectl"
  for_each_node "$TARGET" _verify_k8s_binaries
}

_verify_k8s_binaries(){
  log_info "[Step03] 节点 $i 验证 Kubernetes 二进制文件"
  
  # 验证 kubeadm
  if ssh_exec "$i" "bash -lc 'kubeadm version 2>/dev/null'"; then
    log_info "[Step03] 节点 $i kubeadm 验证成功"
  else
    log_warn "[Step03] 节点 $i kubeadm 验证失败"
  fi
  
  # 验证 kubectl
  if ssh_exec "$i" "bash -lc 'kubectl version --client 2>/dev/null'"; then
    log_info "[Step03] 节点 $i kubectl 验证成功"
  else
    log_warn "[Step03] 节点 $i kubectl 验证失败"
  fi
  
  # 验证 kubelet
  if ssh_exec "$i" "bash -lc 'kubelet --version 2>/dev/null'"; then
    log_info "[Step03] 节点 $i kubelet 验证成功"
  else
    log_warn "[Step03] 节点 $i kubelet 验证失败"
  fi
}

main(){ precheck; ensure_resources; for_each_node "$TARGET" execute; verify; }
main "$@"


