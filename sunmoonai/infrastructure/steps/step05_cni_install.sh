#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$BASE_DIR/../utils/common.sh"

load_config_file || exit 1

STEP_PREFIX=STEP05
TARGET="${STEP05_TARGET:-master}"
CNI="${STEP05_CNI:-calico}"
NS="${STEP05_HELM_NAMESPACE:-kube-system}"
EXTRA_OPTS="${STEP05_HELM_EXTRA_OPTS:-}"
PACKAGES_DEPLOY_MODE_EFFECTIVE="$(get_packages_deploy_mode)"
OFFLINE_DIR="${STEP05_HELM_OFFLINE_CHARTS_DIR:-}"
# 默认离线 charts 目录
if [[ -z "$OFFLINE_DIR" ]]; then
  OFFLINE_DIR="$HOME/packages-to-be-installed/charts"
fi
# 获取 Kubernetes 版本信息
K8S_VERSION_RESOLVED="${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-}}"
if [[ -n "$K8S_VERSION_RESOLVED" && "$K8S_VERSION_RESOLVED" != v* ]]; then
  K8S_VERSION_RESOLVED="v${K8S_VERSION_RESOLVED}"
fi

# 远端 kubeconfig 路径（用于所有远端 kubectl/helm 调用）
REMOTE_KUBECONFIG="${STEP05_REMOTE_KUBECONFIG:-/etc/kubernetes/admin.conf}"

# CNI 版本配置
CALICO_VER="${STEP05_CALICO_CHART_VERSION:-}"
FLANNEL_VER="${STEP05_FLANNEL_CHART_VERSION:-0.25.0}"
CILIUM_VER="${STEP05_CILIUM_CHART_VERSION:-1.16.1}"
WEAVE_VER="${STEP05_WEAVE_CHART_VERSION:-1.9.8}"

# 自动映射 Calico 版本（如果未指定）
if [[ -z "$CALICO_VER" && -n "$K8S_VERSION_RESOLVED" ]]; then
  minor="$(echo "$K8S_VERSION_RESOLVED" | sed -E 's/^v?([0-9]+)\.([0-9]+).*/\1.\2/')"
  case "$minor" in
    1.28) CALICO_VER="3.26.1" ;;
    1.29) CALICO_VER="3.27.0" ;;
    1.30) CALICO_VER="3.28.2" ;;
    *) CALICO_VER="3.28.2" ;;  # 默认使用最新稳定版本
  esac
fi

NS_NERDCTL="${STEP02_NERDCTL_NAMESPACE:-k8s.io}"
REMOTE_DIR_FALLBACK="~/packages-to-be-installed"

required_artifacts(){
  # 当镜像通过离线方式获取时，宣告所需镜像
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    _images_for_cni | while read -r img; do [[ -n "$img" ]] && echo "type=images image='$img'"; done
  fi
  # 当 CHARTS_AND_IMAGES_DEPLOY=offline 时，要求 charts 在远程安装目录（新架构：检查远程文件）
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    local pat; pat="$(_chart_pattern_for_cni)"; echo "type=charts pattern='$pat'"
  fi
}

if [[ "${1:-}" == "--required-artifacts" ]]; then
  required_artifacts
  exit 0
fi

# 版本兼容性检查
_check_calico_version_compatibility(){
  local k8s_minor="$1"
  local calico_ver="$2"
  
  if [[ -n "${STEP05_CALICO_CHART_VERSION:-}" ]]; then
    case "$k8s_minor" in
      1.28)
        if [[ "$calico_ver" != 3.26.* ]]; then
          log_warn "[Step05] 警告：K8s $k8s_minor 通常使用 Calico 3.26.x，当前使用 $calico_ver"
        fi
        ;;
      1.29)
        if [[ "$calico_ver" != 3.27.* ]]; then
          log_warn "[Step05] 警告：K8s $k8s_minor 通常使用 Calico 3.27.x，当前使用 $calico_ver"
        fi
        ;;
      1.30)
        if [[ "$calico_ver" != 3.28.* ]]; then
          log_warn "[Step05] 警告：K8s $k8s_minor 通常使用 Calico 3.28.x，当前使用 $calico_ver"
        fi
        ;;
    esac
  fi
}

precheck(){ 
  log_info "[Step05] 预检 CNI: $CNI"
  
  # 执行版本兼容性检查
  if [[ "$CNI" == "calico" && -n "$K8S_VERSION_RESOLVED" ]]; then
    minor="$(echo "$K8S_VERSION_RESOLVED" | sed -E 's/^v?([0-9]+)\.([0-9]+).*/\1.\2/')"
    _check_calico_version_compatibility "$minor" "$CALICO_VER"
  fi
}

# 准备远端 kubeconfig（使用统一函数）
_prepare_remote_kubeconfig(){
  local node_idx="${1:-$i}"
  prepare_remote_kubeconfig "$node_idx" "REMOTE_KUBECONFIG" || {
    log_error "[Step05] 无法在远端节点准备可读的 kubeconfig"
    return 1
  }
}
ensure_resources(){ 
  # 确保所有节点都加载了必要的 CNI 镜像
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    log_info "[Step05] 确保所有节点都加载了 CNI 镜像"
    for_each_node "all" _ensure_cni_images_on_node
  fi
}

# 在指定节点上确保 CNI 镜像已加载
_ensure_cni_images_on_node(){
  local dir; dir="$(resolve_remote_dir "$(get_server_var "$i" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
  local dir_expr
  if [[ "$dir" == ~* ]]; then
    dir_expr="\"\$HOME${dir#\~}\""
  else
    dir_expr="\"$dir\""
  fi
  
  # 检查所有必需的镜像是否已加载（使用实际的 CNI 镜像列表）
  local missing_images=false
  local required_images
  mapfile -t required_images < <(_images_for_cni)
  
  for img in "${required_images[@]}"; do
    [[ -z "$img" ]] && continue
    # 提取镜像名称的最后部分进行匹配
    local img_name="${img##*/}"
    img_name="${img_name%%:*}"
    if ! ssh_exec "$i" "bash -lc 'sudo nerdctl -n \"$NS_NERDCTL\" images | grep -q \"$img_name\"'"; then
      missing_images=true
      break
    fi
  done
  
  if [[ "$missing_images" == true ]]; then
    log_info "[Step05] 节点 $i 加载 CNI 镜像"
    ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; for tar_file in \"\$base/images\"/calico_*.tar \"\$base/images\"/quay.io_*.tar; do sudo nerdctl -n \"$NS_NERDCTL\" load -i \"\$tar_file\"; done'"
  else
    log_info "[Step05] 节点 $i 已加载所有 CNI 镜像，跳过"
  fi
}

# ---------------------------
# 镜像清单生成
# ---------------------------

_images_for_cni(){
  # 若 deploy-infrastructure-all.conf 定义了 STEP05_IMAGE_LIST 数组，则优先使用
  if declare -p STEP05_IMAGE_LIST >/dev/null 2>&1; then
    # shellcheck disable=SC2154
    local -a _arr=( "${STEP05_IMAGE_LIST[@]}" )
    if [[ ${#_arr[@]} -gt 0 ]]; then
      printf "%s\n" "${_arr[@]}"
      return 0
    fi
  fi
  case "$CNI" in
    calico)
      local op_img; op_img="$(_resolve_calico_operator_image)"
      printf "%s\n" \
        "$op_img" \
        "docker.io/calico/node:v${CALICO_VER}" \
        "docker.io/calico/cni:v${CALICO_VER}" \
        "docker.io/calico/pod2daemon-flexvol:v${CALICO_VER}" \
        "docker.io/calico/kube-controllers:v${CALICO_VER}" \
        "docker.io/calico/typha:v${CALICO_VER}" ;;
    flannel)
      printf "%s\n" "docker.io/flannel/flannel:v${FLANNEL_VER}" ;;
    cilium)
      printf "%s\n" "quay.io/cilium/cilium:v${CILIUM_VER}" ;;
    weave)
      printf "%s\n" "docker.io/weaveworks/weave-kube:v${WEAVE_VER}" ;;
    *) ;;
  esac
}

# 解析 Calico operator 镜像 repo:tag
_resolve_calico_operator_image(){
  local repo tag
  repo="${STEP05_TIGERA_OPERATOR_IMAGE_REPO:-quay.io/tigera/operator}"
  tag="${STEP05_TIGERA_OPERATOR_IMAGE_TAG:-}"
  # 1) 若用户在 deploy-infrastructure-all.conf 指定了 TAG，直接使用
  if [[ -n "$tag" ]]; then echo "$repo:$tag"; return 0; fi
  # 2) 使用默认版本
  echo "$repo:v${CALICO_VER}"
}

# 准备 Calico 的 Helm values 配置（包含 IP 自动检测）
_prepare_calico_values(){
  local values=""
  local detection_method="${STEP05_CALICO_IP_AUTODETECTION:-auto}"
  local current_node_local_ip
  
  # 获取当前节点的本地 IP（用于 Calico 的 IP 自动检测）
  current_node_local_ip="$(get_server_var "$i" LOCAL_IP)"
  
  case "$detection_method" in
    auto)
      # 自动模式：收集所有节点的网段
      local cidrs=()
      local seen_networks=()
      
      # 遍历所有节点，收集不同的网段
      for idx in $(seq 1 10); do
        local node_ip
        node_ip="$(get_server_var "$idx" LOCAL_IP 2>/dev/null || true)"
        if [[ -n "$node_ip" ]]; then
          # 提取网段 (x.x.x.0/24)
          local network="$(echo "$node_ip" | cut -d. -f1-3).0/24"
          
          # 检查是否已经包含这个网段
          local already_seen=false
          for seen_net in "${seen_networks[@]}"; do
            if [[ "$seen_net" == "$network" ]]; then
              already_seen=true
              break
            fi
          done
          
          if [[ "$already_seen" == false ]]; then
            cidrs+=("$network")
            seen_networks+=("$network")
          fi
        fi
      done
      
      # 构建 CIDR 列表
      if [[ ${#cidrs[@]} -gt 0 ]]; then
        local cidr_list=""
        for cidr in "${cidrs[@]}"; do
          if [[ -n "$cidr_list" ]]; then
            cidr_list="$cidr_list,$cidr"
          else
            cidr_list="$cidr"
          fi
        done
        # 创建 YAML values 文件
        local values_file="/tmp/calico-values.yaml"
        cat > "$values_file" << EOF
installation:
  calicoNetwork:
    nodeAddressAutodetectionV4:
      cidrs:
EOF
        for cidr in "${cidrs[@]}"; do
          echo "        - $cidr" >> "$values_file"
        done
        values="--values $values_file"
      fi
      ;;
    interface=*)
      # 接口名称模式：interface=eth0
      local interface_name="${detection_method#interface=}"
      # 创建 YAML values 文件
      local values_file="/tmp/calico-values.yaml"
      cat > "$values_file" << EOF
installation:
  calicoNetwork:
    nodeAddressAutodetectionV4:
      interface: $interface_name
EOF
      values="--values $values_file"
      ;;
    cidr=*)
      # CIDR 网段模式：cidr=192.168.0.0/16
      local cidr_range="${detection_method#cidr=}"
      # 创建 YAML values 文件
      local values_file="/tmp/calico-values.yaml"
      cat > "$values_file" << EOF
installation:
  calicoNetwork:
    nodeAddressAutodetectionV4:
      cidrs:
        - $cidr_range
EOF
      values="--values $values_file"
      ;;
    can-reach=*)
      # 可达性模式：can-reach=8.8.8.8
      local target_ip="${detection_method#can-reach=}"
      # 创建 YAML values 文件
      local values_file="/tmp/calico-values.yaml"
      cat > "$values_file" << EOF
installation:
  calicoNetwork:
    nodeAddressAutodetectionV4:
      canReach: $target_ip
EOF
      values="--values $values_file"
      ;;
    *)
      # 未识别的配置方法，使用默认配置
      ;;
  esac
  
  echo "$values"
}

# ---------------------------
# Helm 环境准备
# ---------------------------

_remote_has_helm(){
  ssh_exec "$i" "bash -lc 'command -v helm >/dev/null 2>&1'"
}

_install_helm_offline(){
  [[ -z "$OFFLINE_DIR" ]] && return 1
  local local_tgz
  if [[ -f "$OFFLINE_DIR/helm-linux-amd64.tar.gz" ]]; then
    local_tgz="$OFFLINE_DIR/helm-linux-amd64.tar.gz"
  else
    local_tgz="$(ls -1 "$OFFLINE_DIR"/helm-v*-linux-amd64.tar.gz 2>/dev/null | head -1 || true)"
  fi
  [[ -z "$local_tgz" ]] && return 1
  scp_copy_to "$i" "$local_tgz" "/tmp/helm-linux-amd64.tgz" || return 1
  ssh_exec_sudo "$i" "bash -lc 'cd /tmp && tar -xzf helm-linux-amd64.tgz && install -m 0755 linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64 helm-linux-amd64.tgz'"
}

_install_helm_online(){
  ssh_exec_sudo "$i" "bash -lc 'curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'"
}

# 统一的上游仓库管理函数
_ensure_upstream_repos(){
  local cni="$1"
  case "$cni" in
    calico)
      ssh_exec "$i" "bash -lc 'helm repo remove projectcalico >/dev/null 2>&1 || true; helm repo add projectcalico https://projectcalico.docs.tigera.io/charts >/dev/null 2>&1 || true; helm repo update >/dev/null 2>&1 || true'" ;;
    flannel)
      ssh_exec "$i" "bash -lc 'helm repo add flannel https://flannel-io.github.io/flannel >/dev/null 2>&1 || true; helm repo update >/dev/null 2>&1 || true'" ;;
    cilium)
      ssh_exec "$i" "bash -lc 'helm repo add cilium https://helm.cilium.io >/dev/null 2>&1 || true; helm repo update >/dev/null 2>&1 || true'" ;;
    weave)
      ssh_exec "$i" "bash -lc 'helm repo add weaveworks https://weaveworks.github.io/weave >/dev/null 2>&1 || true; helm repo update >/dev/null 2>&1 || true'" ;;
  esac
}

_ensure_helm_and_repos(){
  if ! _remote_has_helm; then
    if ! _install_helm_offline; then
      _install_helm_online || return 1
    fi
  fi
  
  # 根据CHARTS_AND_IMAGES_DEPLOY决定是否添加在线仓库
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    # 离线模式：添加在线仓库（用于下载Chart包）
    _ensure_upstream_repos "$CNI"
  else
    # 在线模式：不添加在线仓库，Chart将从Harbor拉取
    log_info "[Step05] 在线模式：跳过在线仓库添加，Chart将从Harbor拉取"
  fi
}



# ---------------------------
# Chart 管理
# ---------------------------

_helm_install(){
  local chart="$1"; shift
  local version="$1"; shift
  local values="$1"; shift || true
  local cmd="helm upgrade --install $CNI $chart --namespace $NS --create-namespace --version $version $EXTRA_OPTS $values"
  echo "$cmd"
}

# 识别远程离线 chart 文件名通配符
_chart_pattern_for_cni(){
  case "$CNI" in
    calico) echo "tigera-operator-*.tgz" ;;
    flannel) echo "flannel-*.tgz" ;;
    cilium) echo "cilium-*.tgz" ;;
    weave) echo "weave-*.tgz" ;;
    *) echo "*.tgz" ;;
  esac
}



# ---------------------------
# 主要执行逻辑
# ---------------------------

execute(){
  log_info "[Step05] 通过 Helm 安装 $CNI"
  # 准备远端 kubeconfig，确保后续 kubectl/helm 可用
  _prepare_remote_kubeconfig || return 1
  
  # step05 通用检查：Kubernetes 集群和 Helm 环境（移到已安装检测之前）
  _check_step05_common_conditions() {
    # 检查 Kubernetes 集群是否就绪
    log_info "[Step05] 检查 Kubernetes 集群状态..."
    if ! ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; kubectl get nodes >/dev/null 2>&1'"; then
      log_error "[Step05] Kubernetes 集群未就绪，请先完成 step04 kubeadm init"
      return 1
    fi
    log_info "[Step05] Kubernetes 集群就绪"
    
    # 检查 Helm 环境
    _ensure_helm_and_repos || { log_error "[Step05] Helm 环境准备失败"; return 1; }
    return 0
  }
  
  _check_step05_common_conditions || return 1
  
  # 已安装检测：检查Calico相关组件是否存在（移到 Helm 环境检查之后）
  if [[ "$CNI" == "calico" ]]; then
    # 检查是否有强制重新安装的标志
    if [[ "${STEP05_FORCE_REINSTALL:-false}" == "true" ]]; then
      log_info "[Step05] 强制重新安装模式，跳过已安装检测"
    else
      # Calico使用tigera-operator，检查相关组件
      if ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; kubectl -n kube-system get deploy | grep -qi tigera-operator && kubectl -n calico-system get ds | grep -qi calico-node'"; then
        log_info "[Step05] 节点 $i 检测到 Calico 已安装，跳过"
        return 0
      fi
    fi
  else
    # 其他CNI的检测逻辑
    if ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; kubectl -n kube-system get ds | grep -qi $CNI || kubectl -n kube-system get deploy | grep -qi $CNI'"; then
      log_info "[Step05] 节点 $i 检测到 $CNI 已安装，跳过"
      return 0
    fi
  fi
  
  # 准备 Helm 安装
  local chart="" ver="" vals=""
  case "$CNI" in
    calico) chart="projectcalico/tigera-operator"; ver="$CALICO_VER";;
    flannel) chart="flannel/flannel"; ver="$FLANNEL_VER";;
    cilium) chart="cilium/cilium"; ver="$CILIUM_VER";;
    weave) chart="weaveworks/weave"; ver="$WEAVE_VER";;
    *) log_error "不支持的 CNI: $CNI"; return 1;;
  esac
  
  # 准备 Calico 特殊配置（IP 自动检测）
  local calico_values=""
  if [[ "$CNI" == "calico" ]]; then
    calico_values="$(_prepare_calico_values)"
    
    # 输出 Calico 配置信息
    local detection_method="${STEP05_CALICO_IP_AUTODETECTION:-auto}"
    local current_node_local_ip
    current_node_local_ip="$(get_server_var "$i" LOCAL_IP)"
    
    case "$detection_method" in
      auto)
        # 收集所有节点的网段用于日志显示
        local detected_cidrs=()
        local seen_networks=()
        
        for idx in $(seq 1 10); do
          local node_ip
          node_ip="$(get_server_var "$idx" LOCAL_IP 2>/dev/null || true)"
          if [[ -n "$node_ip" ]]; then
            local network="$(echo "$node_ip" | cut -d. -f1-3).0/24"
            local already_seen=false
            for seen_net in "${seen_networks[@]}"; do
              if [[ "$seen_net" == "$network" ]]; then
                already_seen=true
                break
              fi
            done
            
            if [[ "$already_seen" == false ]]; then
              detected_cidrs+=("$network")
              seen_networks+=("$network")
            fi
          fi
        done
        
        if [[ ${#detected_cidrs[@]} -gt 0 ]]; then
          local cidr_display=""
          for cidr in "${detected_cidrs[@]}"; do
            if [[ -n "$cidr_display" ]]; then
              cidr_display="$cidr_display, $cidr"
            else
              cidr_display="$cidr"
            fi
          done
          log_info "[Step05] 配置 Calico IP 自动检测 (auto): 检测到网段 $cidr_display"
        else
          log_warn "[Step05] auto 模式下未找到任何节点的本地 IP 配置，使用 Calico 默认 IP 自动检测"
        fi
        ;;
      interface=*)
        local interface_name="${detection_method#interface=}"
        log_info "[Step05] 配置 Calico IP 自动检测: 使用网络接口 $interface_name"
        ;;
      cidr=*)
        local cidr_range="${detection_method#cidr=}"
        log_info "[Step05] 配置 Calico IP 自动检测: 使用 CIDR 网段 $cidr_range"
        ;;
      can-reach=*)
        local target_ip="${detection_method#can-reach=}"
        log_info "[Step05] 配置 Calico IP 自动检测: 使用可达性检测目标 $target_ip"
        ;;
      *)
        log_warn "[Step05] 未识别的 Calico IP 自动检测方法: $detection_method，使用默认配置"
        ;;
    esac
  fi
  
  # 执行 Helm 安装（新架构：根据 CHARTS_AND_IMAGES_DEPLOY 配置选择安装方式）
  if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
    # 离线模式：统一检查所有资源
    log_info "[Step05] 离线模式：检查所有必需资源"
    
    local missing_resources=()
    local has_missing=false
    
    # 准备路径变量
    local dir; dir="$(resolve_remote_dir "$(get_server_var "$i" DIR)")"; dir="${dir:-$REMOTE_DIR_FALLBACK}"
    local dir_expr
    if [[ "$dir" == ~* ]]; then
      dir_expr="\"\$HOME${dir#\~}\""
    else
      dir_expr="\"$dir\""
    fi
    
    # 检查镜像（离线模式）
    if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" ]]; then
                     # 检查远程 images 目录下的 CNI 镜像 tar 文件
               if ! ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; ls \"\$base/images\"/calico_*.tar \"\$base/images\"/quay.io_*.tar >/dev/null 2>&1'"; then
                 missing_resources+=("镜像文件")
                 has_missing=true
                 log_error "[Step05] 节点 $i 缺少 CNI 镜像 tar 文件："
                 log_error "  - 期望文件模式: $dir/images/calico_*.tar 或 $dir/images/quay.io_*.tar"
      fi
    fi
    
    # 检查远程 chart 文件
    local pat; pat="$(_chart_pattern_for_cni)"
    
    if ! ssh_exec "$i" "bash -lc 'base='"$dir_expr"'; ls \"\$base/charts\"/$pat >/dev/null 2>&1'"; then
      missing_resources+=("Chart文件")
      has_missing=true
      log_error "[Step05] 节点 $i 缺少 CNI chart 文件："
      log_error "  - 期望文件模式: $dir/charts/$pat"
    fi
    
    # 如果有缺失资源，统一提示并退出
    if [[ "$has_missing" == true ]]; then
      log_error "[Step05] 离线模式下缺少以下资源：${missing_resources[*]}"
      log_error "[Step05] 请准备好所有必需资源后重试"
                       if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" && " ${missing_resources[*]} " =~ " 镜像文件 " ]]; then
                   log_info "[Step05] 镜像准备：请使用 packages-management.sh 拉取并安装 CNI 镜像"
                   log_info "文件模式: $dir/images/calico_*.tar 或 $dir/images/quay.io_*.tar"
        log_info "在镜像拉取界面中输入以下镜像（每行一个，输入完成后直接按回车）："
        local imgs; imgs="$(_images_for_cni)"
        while IFS= read -r img; do
          [[ -z "$img" ]] && continue
          echo "  $img"
        done <<EOF
$imgs
EOF
      fi
      
      # 提示 chart 文件准备（仅在 chart 缺失时）
      if [[ "$PACKAGES_DEPLOY_MODE_EFFECTIVE" == "offline" && " ${missing_resources[*]} " =~ " Chart文件 " ]]; then
        log_info "[Step05] Chart 文件准备：请使用 packages-management.sh 下载以下 chart"
        log_info "文件模式: $dir/charts/$pat"
        log_info "在 packages-management.sh 的 chart 下载界面中输入（每行一个，输入完成后直接按回车）："
        
        # 根据不同的 CNI 提供相应的 chart 名称
        case "$CNI" in
          calico)
            echo "  projectcalico/tigera-operator ${CALICO_VER}"
            ;;
          flannel)
            echo "  flannel/flannel ${FLANNEL_VER}"
            ;;
          cilium)
            echo "  cilium/cilium ${CILIUM_VER}"
            ;;
          weave)
            echo "  weaveworks/weave ${WEAVE_VER}"
            ;;
        esac
      fi
      return 1
    fi
    
    # 所有资源都存在，执行安装
    log_info "[Step05] 所有必需资源已就绪，开始安装"
    
    # 注意：镜像已在 ensure_resources 阶段加载，此处跳过重复加载
    
    log_info "[Step05] 使用远程 chart 文件: $dir/charts/$pat"
    log_info "[Step05] Calico values: '${calico_values:-}'"
    
    # 安装 tigera-operator 并应用 Calico 配置
    if [[ -n "$calico_values" ]]; then
      # 如果有 calico_values，需要将 YAML 文件传输到远程节点
      if [[ "$calico_values" =~ ^--values ]]; then
        # 提取本地 YAML 文件路径
        local local_yaml_file="${calico_values#--values }"
        local remote_yaml_file="/tmp/calico-values.yaml"
        
        # 传输 YAML 文件到远程节点
        scp_copy_to "$i" "$local_yaml_file" "$remote_yaml_file"
        
        # 使用远程 YAML 文件执行 Helm 安装
        ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; base='"$dir_expr"'; chart_file=\"\$(ls \"\$base/charts\"/$pat | head -1)\"; if [[ -z \"\$chart_file\" ]]; then echo \"Error: Chart file not found in \$base/charts/$pat\"; exit 1; fi; helm upgrade --install $CNI \"\$chart_file\" --namespace $NS --create-namespace ${EXTRA_OPTS:-} --values $remote_yaml_file; rm -f $remote_yaml_file'"
      else
        # 如果不是 --values 格式，使用原来的方式
        ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; base='"$dir_expr"'; chart_file=\"\$(ls \"\$base/charts\"/$pat | head -1)\"; if [[ -z \"\$chart_file\" ]]; then echo \"Error: Chart file not found in \$base/charts/$pat\"; exit 1; fi; helm upgrade --install $CNI \"\$chart_file\" --namespace $NS --create-namespace ${EXTRA_OPTS:-} $calico_values'"
      fi
    else
      # 如果没有 calico_values，正常安装
      ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; base='"$dir_expr"'; chart_file=\"\$(ls \"\$base/charts\"/$pat | head -1)\"; if [[ -z \"\$chart_file\" ]]; then echo \"Error: Chart file not found in \$base/charts/$pat\"; exit 1; fi; helm upgrade --install $CNI \"\$chart_file\" --namespace $NS --create-namespace ${EXTRA_OPTS:-}'"
    fi
    
    # 清理本地 YAML 文件
    if [[ -n "$calico_values" && "$calico_values" =~ ^--values ]]; then
      local local_yaml_file="${calico_values#--values }"
      rm -f "$local_yaml_file"
    fi
    
    # 等待 tigera-operator 就绪
    log_info "[Step05] 等待 tigera-operator 就绪..."
    ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; kubectl wait --for=condition=available --timeout=300s deployment/tigera-operator -n $NS'"
    
    
    # 等待 Calico 组件就绪
    log_info "[Step05] 等待 Calico 组件就绪..."
    local max_wait=300
    local wait_count=0
    while [[ $wait_count -lt $max_wait ]]; do
      if ssh_exec "$i" "bash -lc 'export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; kubectl get daemonset calico-node -n calico-system -o jsonpath=\"{.status.numberReady}\" | grep -q \"^[1-9]\"'"; then
        log_info "[Step05] Calico 安装成功"
        break
      fi
      sleep 5
      wait_count=$((wait_count + 5))
      log_info "[Step05] 等待 Calico 组件就绪... (${wait_count}s/${max_wait}s)"
    done
    
    if [[ $wait_count -ge $max_wait ]]; then
      log_error "[Step05] Calico 安装超时，停止部署"
      return 1
    fi
  else
    # 在线模式：使用上游 Helm 仓库
    log_info "[Step05] 在线模式：从上游 Helm 仓库安装 ${CNI}@${ver}"
    # 确保添加上游 repo
    _ensure_upstream_repos "$CNI"
    # 在线安装
    local cmd
    cmd="export KUBECONFIG=\"$REMOTE_KUBECONFIG\"; helm upgrade --install $CNI $chart --namespace $NS --create-namespace --version $ver $EXTRA_OPTS $vals $calico_values"
    ssh_exec "$i" "bash -lc '$cmd'"
  fi
}

verify(){ log_info "[Step05] 验证 CNI 组件就绪（略）"; }

main(){ precheck; ensure_resources; for_each_node "$TARGET" execute; verify; }

main "$@"


