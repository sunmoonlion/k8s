#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP04
TARGET="${STEP04_TARGET:-master}"
POD_CIDR="${STEP04_POD_CIDR:-10.244.0.0/16}"
SVC_CIDR="${STEP04_SERVICE_CIDR:-10.96.0.0/12}"
PROXY_MODE="${STEP04_KUBE_PROXY_MODE:-ipvs}"
UPLOAD_CERTS="${STEP04_UPLOAD_CERTS:-true}"
APISERVER_SANS="${STEP04_APISERVER_CERT_SANS:-}"


CONTROLPLANE_ENDPOINT="${STEP04_CONTROLPLANE_ENDPOINT:-}"
K8S_VERSION_RESOLVED="${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-}}"
if [[ -n "$K8S_VERSION_RESOLVED" && "$K8S_VERSION_RESOLVED" != v* ]]; then
  K8S_VERSION_RESOLVED="v${K8S_VERSION_RESOLVED}"
fi
# 映射 CoreDNS 和 Etcd 版本（留空则按 K8s 版本自动映射）
CORE_DNS_TAG="${STEP04_COREDNS_IMAGE_TAG:-}"
ETCD_REPO="registry.k8s.io"
ETCD_TAG="${STEP04_ETCD_IMAGE_TAG:-}"

# 自动映射逻辑
if [[ -z "$CORE_DNS_TAG$ETCD_TAG" && -n "$K8S_VERSION_RESOLVED" ]]; then
  minor="$(echo "$K8S_VERSION_RESOLVED" | sed -E 's/^v?([0-9]+)\.([0-9]+).*/\1.\2/')"
  case "$minor" in
    1.28) : "${CORE_DNS_TAG:=v1.10.1}"; : "${ETCD_TAG:=3.5.9-0}" ;;
    1.29) : "${CORE_DNS_TAG:=v1.11.1}"; : "${ETCD_TAG:=3.5.10-0}" ;;
    1.30) : "${CORE_DNS_TAG:=v1.11.1}"; : "${ETCD_TAG:=3.5.12-0}" ;;
    *) : "${CORE_DNS_TAG:=v1.11.1}"; : "${ETCD_TAG:=3.5.12-0}" ;;
  esac
fi

# 兼容性检查
_check_version_compatibility(){
  local k8s_minor="$1"
  local coredns_tag="$2"
  local etcd_tag="$3"
  
  # 检查 CoreDNS 版本兼容性
  if [[ -n "$STEP04_COREDNS_IMAGE_TAG" ]]; then
    case "$k8s_minor" in
      1.28)
        if [[ "$coredns_tag" != v1.10.* ]]; then
          log_warn "[Step04] 警告：K8s $k8s_minor 通常使用 CoreDNS v1.10.x，当前使用 $coredns_tag"
        fi
        ;;
      1.29|1.30)
        if [[ "$coredns_tag" != v1.11.* ]]; then
          log_warn "[Step04] 警告：K8s $k8s_minor 通常使用 CoreDNS v1.11.x，当前使用 $coredns_tag"
        fi
        ;;
    esac
  fi
  
  # 检查 Etcd 版本兼容性
  if [[ -n "$STEP04_ETCD_IMAGE_TAG" ]]; then
    case "$k8s_minor" in
      1.28)
        if [[ "$etcd_tag" != 3.5.9-* ]]; then
          log_warn "[Step04] 警告：K8s $k8s_minor 通常使用 Etcd 3.5.9-x，当前使用 $etcd_tag"
        fi
        ;;
      1.29)
        if [[ "$etcd_tag" != 3.5.10-* ]]; then
          log_warn "[Step04] 警告：K8s $k8s_minor 通常使用 Etcd 3.5.10-x，当前使用 $etcd_tag"
        fi
        ;;
      1.30)
        if [[ "$etcd_tag" != 3.5.12-* ]]; then
          log_warn "[Step04] 警告：K8s $k8s_minor 通常使用 Etcd 3.5.12-x，当前使用 $etcd_tag"
        fi
        ;;
    esac
  fi
}

# 执行兼容性检查
if [[ -n "$K8S_VERSION_RESOLVED" ]]; then
  minor="$(echo "$K8S_VERSION_RESOLVED" | sed -E 's/^v?([0-9]+)\.([0-9]+).*/\1.\2/')"
  _check_version_compatibility "$minor" "$CORE_DNS_TAG" "$ETCD_TAG"
fi

PACKAGES_DEPLOY_MODE_EFFECTIVE="$(get_packages_deploy_mode)"

# CRI socket 配置
CRI_SOCKET="${STEP02_CRI_SOCKET_OVERRIDE:-unix:///var/run/containerd/containerd.sock}"

_core_images_for_init(){
  # 使用默认的 registry.k8s.io，依赖 Step02 的 containerd 配置进行仓库替换
  printf "%s\n" \
    "registry.k8s.io/kube-apiserver:${K8S_VERSION_RESOLVED}" \
    "registry.k8s.io/kube-controller-manager:${K8S_VERSION_RESOLVED}" \
    "registry.k8s.io/kube-scheduler:${K8S_VERSION_RESOLVED}" \
    "registry.k8s.io/kube-proxy:${K8S_VERSION_RESOLVED}" \
    "registry.k8s.io/pause:3.9" \
    "registry.k8s.io/coredns/coredns:${CORE_DNS_TAG}" \
    "$ETCD_REPO/etcd:${ETCD_TAG}"
}

required_artifacts(){
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    while IFS= read -r img; do
      [[ -z "$img" ]] && continue
      echo "type=images image='$img'"
    done < <(_core_images_for_init)
  fi
}

if [[ "${1:-}" == "--required-artifacts" ]]; then
  required_artifacts
  exit 0
fi

precheck(){ log_info "[Step04] 预检 kubeadm init"; }

ensure_cri_ready(){
  log_info "[Step04] 确保节点 $i containerd CRI 就绪"
  local pause_img="${STEP02_SANDBOX_IMAGE:-registry.k8s.io/pause:3.9}"
  # 以远端脚本方式修改，尽量保留原配置，仅修改关键项
  local patch_script
  patch_script="$(cat <<'EOS'
set -e
systemctl enable --now containerd >/dev/null 2>&1 || true
if [[ ! -s /etc/containerd/config.toml ]]; then
  containerd config default | tee /etc/containerd/config.toml >/dev/null
fi
PIMG="__PIMG__"
# SystemdCgroup=true
sed -ri 's/^\s*SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || true
# sandbox_image 替换为配置值
sed -ri "s#^\s*sandbox_image = \".*\"#sandbox_image = \"${PIMG}\"#" /etc/containerd/config.toml || true
# 取消禁用插件
if grep -q '^disabled_plugins' /etc/containerd/config.toml; then
  sed -ri 's/^disabled_plugins = .*/disabled_plugins = []/' /etc/containerd/config.toml || true
fi
systemctl restart containerd
EOS
)"
  patch_script="${patch_script//__PIMG__/$pause_img}"
  local ps_b64; ps_b64="$(printf '%s' "$patch_script" | base64 -w0)"
  ssh_exec_sudo "$i" "echo $ps_b64 | base64 -d | bash"
  # 基本校验
  ssh_exec_sudo "$i" "bash -lc 'ctr version >/dev/null 2>&1 && nerdctl -n k8s.io info >/dev/null 2>&1'" || log_warn "[Step04] 节点 $i CRI 校验告警（继续尝试 init）"
}

ensure_resources(){
  for_each_node "$TARGET" ensure_cri_ready
}

_gen_init_cfg(){
  cat <<CFG
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: $CRI_SOCKET
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podSubnet: "$POD_CIDR"
  serviceSubnet: "$SVC_CIDR"
$( [[ -n "$K8S_VERSION_RESOLVED" ]] && echo "kubernetesVersion: $K8S_VERSION_RESOLVED" )
etcd:
  local:
    imageRepository: "$ETCD_REPO"
    imageTag: "$ETCD_TAG"
dns:
  imageTag: "$CORE_DNS_TAG"
apiServer:
  certSANs:
$(for s in ${APISERVER_SANS//,/ }; do echo "  - $s"; done)
# 移除 imageRepository 配置，依赖 Step02 的 containerd 配置进行仓库替换
$( [[ -n "$CONTROLPLANE_ENDPOINT" ]] && echo "controlPlaneEndpoint: $CONTROLPLANE_ENDPOINT" )
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "$PROXY_MODE"
CFG
}

execute(){
  log_info "[Step04] 在节点 $i 执行 kubeadm init"
  # 已初始化检测：只有当 admin.conf 存在且可用（能 kubectl get nodes 成功）才跳过
  if ssh_exec "$i" "bash -lc 'test -r /etc/kubernetes/admin.conf && KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes >/dev/null 2>&1'"; then
    log_info "[Step04] 节点 $i 已初始化且可访问，跳过"
    return 0
  fi
  # 残留清单检测：若 manifests 已存在，则提示或按开关清理后再继续，避免二次 init 触发 preflight 错误
  local has_residuals=false
  if ssh_exec "$i" "bash -lc 'ls /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-scheduler.yaml /etc/kubernetes/manifests/etcd.yaml >/dev/null 2>&1'"; then
    has_residuals=true
    log_warn "[Step04] 检测到 /etc/kubernetes/manifests 残留（可能是上次失败残留）"
  fi
  
  # 检测端口占用（6443, 10259, 10257）可能表示控制面组件仍在运行
  local ports_in_use=""
  if ssh_exec "$i" "bash -lc 'ss -lntp 2>/dev/null | grep -q \":6443\\|:10259\\|:10257\"'"; then
    ports_in_use="$(ssh_exec "$i" "bash -lc 'ss -lntp 2>/dev/null | grep -E \":6443|:10259|:10257\" | head -3'")"
    log_warn "[Step04] 检测到控制面端口被占用："
    echo "$ports_in_use" | sed 's/^/[Step04]   /'
    has_residuals=true
  fi
  
  if [[ "$has_residuals" == "true" ]]; then
    if [[ "${STEP04_AUTO_CLEAN_RESIDUALS:-false}" == "true" ]]; then
      log_info "[Step04] STEP04_AUTO_CLEAN_RESIDUALS=true，执行自动清理"
      
      # 停止所有控制面组件和 kubelet
      ssh_exec_sudo "$i" "bash -lc '
        systemctl stop kubelet || true
        pkill -9 kubelet 2>/dev/null || true
        pkill -9 kube-apiserver 2>/dev/null || true
        pkill -9 kube-controller-manager 2>/dev/null || true
        pkill -9 kube-scheduler 2>/dev/null || true
        pkill -9 etcd 2>/dev/null || true
        # 清理端口占用
        for port in 6443 10259 10257 10250 2379 2380; do
          pids=\$(ss -lntp 2>/dev/null | awk \"/:$port/ {print \\\$NF}\" | sed -n \"s/.*pid=\\\\([0-9]*\\\\)/\\1/p\" | sort -u)
          [ -n \"\$pids\" ] && kill -9 \$pids 2>/dev/null || true
        done
        # 清理清单和 etcd 数据
        rm -f /etc/kubernetes/manifests/kube-apiserver.yaml \
              /etc/kubernetes/manifests/kube-controller-manager.yaml \
              /etc/kubernetes/manifests/kube-scheduler.yaml \
              /etc/kubernetes/manifests/etcd.yaml
        rm -rf /var/lib/etcd
        # 执行 kubeadm reset（如果已初始化过）
        if command -v kubeadm >/dev/null 2>&1; then
          kubeadm reset -f 2>/dev/null || true
        fi
      '"
      log_info "[Step04] 清理完成，等待端口释放..."
      sleep 2
    else
      log_error "[Step04] 存在控制面残留（清单或端口占用）。请先执行以下之一："
      log_error "  1. 手动执行: ssh <节点> 'sudo kubeadm reset -f'"
      log_error "  2. 在 deploy-infrastructure-all.conf 设置 STEP04_AUTO_CLEAN_RESIDUALS=true 后重试"
      return 1
    fi
  fi

  # 确保 kubelet 停止且 10250 端口空闲（由 kubeadm init 负责启动 kubelet）
  ssh_exec_sudo "$i" "bash -lc 'systemctl stop kubelet || true; pkill -9 kubelet 2>/dev/null || true; pids_10250=\$(ss -lntp | awk \"/:10250/ {print \\\$NF}\" | sed -n \"s/.*pid=\\\\([0-9]*\\\\)/\\1/p\"); [ -n \"\$pids_10250\" ] && kill -9 \$pids_10250 || true'"
  
  # 确保必要的依赖包已安装（使用离线包）
  log_info "[Step04] 确保 Kubernetes 依赖包已安装（离线模式）"
  local remote_dir; remote_dir="$(get_server_var "$i" DIR)"
  remote_dir="$(resolve_remote_dir "$remote_dir")"
  
  # 检查离线包是否存在
  if ssh_exec "$i" "bash -lc 'dir=\"$remote_dir\"; case \"\$dir\" in ~*) dir=\"/home/zym\${dir#\~}\" ;; esac; test -f \"\$dir/debs/conntrack_1%3a1.4.8-1ubuntu1_amd64.deb\" && test -f \"\$dir/debs/socat_1.8.0.0-4build3_amd64.deb\"'"; then
    log_info "[Step04] 使用离线 deb 包安装依赖"
    ssh_exec_sudo "$i" "bash -lc 'dir=\"$remote_dir\"; case \"\$dir\" in ~*) dir=\"/home/zym\${dir#\~}\" ;; esac; cd \"\$dir/debs\" && dpkg -i conntrack_1%3a1.4.8-1ubuntu1_amd64.deb socat_1.8.0.0-4build3_amd64.deb || apt-get install -f -y'" || true
  else
    log_warn "[Step04] 离线包不存在，回退到在线安装"
    ssh_exec_sudo "$i" "bash -lc 'apt-get update -y >/dev/null 2>&1 || true; apt-get install -y conntrack-tools socat >/dev/null 2>&1 || true'"
  fi
  # 根据 packages_deploy_mode 选择镜像获取方式
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    # 使用 packages 方式：检查远程安装目录下的镜像 tar 文件
    log_info "[Step04] 检查远程安装目录下的 Kubernetes 核心镜像 tar 文件"
    
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$i" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
    local user; user="$(get_server_var "$i" USER)"; user="${user:-root}"
    
    # 解析实际路径（处理 ~ 符号）
    local actual_dir="$dir"
    if [[ "$dir" == ~* ]]; then
      actual_dir="/home/$user${dir#\~}"
    fi
    
    # 检查远程 images 目录下的 tar 文件
    if ! ssh_exec "$i" "bash -lc 'ls \"$actual_dir/images\"/registry.k8s.io_*.tar >/dev/null 2>&1'"; then
      log_error "[Step04] 节点 $i 缺少 Kubernetes 核心镜像 tar 文件"
      log_error "  - 期望文件模式: $actual_dir/images/registry.k8s.io_*.tar"
      log_info "[Step04] 请使用 packages-management.sh 拉取并安装这些镜像"
      log_info "在镜像拉取界面中输入以下镜像（每行一个，输入完成后直接按回车）："
      while IFS= read -r img; do
        [[ -z "$img" ]] && continue
        echo "  $img"
      done < <(_core_images_for_init)
      return 1
    else
      log_info "[Step04] Kubernetes 核心镜像 tar 文件已存在，开始加载"
      # 加载镜像 tar 文件
      ssh_exec_sudo "$i" "bash -lc 'for tar_file in \"$actual_dir/images\"/registry.k8s.io_*.tar; do nerdctl -n k8s.io load -i \"\$tar_file\"; done'"
    fi
  else
    # 在线：允许 kubeadm/容器运行时直接从上游仓库拉取镜像
    log_info "[Step04] 在线模式：将使用默认镜像仓库在线拉取（如需镜像加速请在 step02 配置 containerd mirror）"
    local score; score="$(online_check_score)"
    if [[ "$score" -lt 1 ]]; then
      log_error "[Step04] 网络连接检查失败（得分: $score/3）"
      log_error "[Step04] 请检查网络连接或切换到 offline 模式"
      return 1
    fi
  fi

  # 确保 kubelet 正确安装和配置
  log_info "[Step04] 验证 kubelet 安装状态"
  if ! ssh_exec "$i" "bash -lc 'command -v kubelet >/dev/null 2>&1'"; then
    log_error "[Step04] kubelet 未找到"
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
      log_error "[Step04] 离线模式下 kubelet 缺失，请检查 Step03 是否正确执行"
      return 1
    else
      log_warn "[Step04] 尝试在线重新安装 kubelet"
      ssh_exec_sudo "$i" "bash -lc 'apt-get update -y && apt-get install -y kubelet'" || {
        log_error "[Step04] kubelet 安装失败"
        return 1
      }
    fi
  fi
  
  # 确保 kubelet 服务配置正确
  ssh_exec_sudo "$i" "bash -lc 'systemctl daemon-reload && systemctl enable kubelet'"
  
  local cfg; cfg="$(_gen_init_cfg)"
  local cfg_b64; cfg_b64="$(printf '%s' "$cfg" | base64 -w0)"
  ssh_exec_sudo "$i" "echo $cfg_b64 | base64 -d > /tmp/kubeadm-init.yaml"
  local extra=""; [[ "$UPLOAD_CERTS" == "true" ]] && extra="--upload-certs"
  # 正常执行（镜像已离线导入，kubeadm 不会再拉取）。
  # 若回退执行，也显式固定版本，避免 kubeadm 选用 stable-1.30 最新补丁。
  # 忽略 conntrack 和 socat 的 preflight 检查，因为这些工具在某些环境中可能不可用
  ssh_exec_sudo "$i" "kubeadm init --config=/tmp/kubeadm-init.yaml $extra --ignore-preflight-errors=FileExisting-conntrack,FileExisting-socat || kubeadm init --kubernetes-version \"$K8S_VERSION_RESOLVED\" --pod-network-cidr='$POD_CIDR' $extra --ignore-preflight-errors=FileExisting-conntrack,FileExisting-socat"
  # 配置 kubeconfig 到普通用户
  ssh_exec_sudo "$i" "mkdir -p /home/\$(logname)/.kube && cp -f /etc/kubernetes/admin.conf /home/\$(logname)/.kube/config && chown \$(logname):\$(logname) /home/\$(logname)/.kube/config || true"
  
  # 清理临时文件
  ssh_exec_sudo "$i" "rm -f /tmp/kubeadm-init.yaml"
}

verify(){ 
  log_info "[Step04] kubeadm init 已执行（如失败会在上一步报错）"
  log_info "[Step04] 如需获取 kubeconfig 到本机，请运行："
  log_info "  bootstrap-kubectl.sh <master-host> <user> [--secret <key>|--pass <password>]"
}

main(){ precheck; ensure_resources; for_each_node "$TARGET" execute; verify; }
main "$@"


