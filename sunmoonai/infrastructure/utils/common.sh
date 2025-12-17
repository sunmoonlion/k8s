#!/usr/bin/env bash
set -euo pipefail

# 通用工具函数（加载配置、日志、节点遍历、在线检测等）

export LC_ALL=C
export LANG=C
export LANGUAGE=C

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

log_info(){ echo -e "[INFO] $*"; }
log_warn(){ echo -e "\033[33m[WARN]\033[0m $*"; }
log_error(){ echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }

need(){ command -v "$1" >/dev/null 2>&1; }


## packages-management 模块已移除；如需离线准备，请使用各 Step 的 local 策略或按提示手动上传离线包。

artifact_dir_for_type(){
  # Map a loose type label to standardized subdir name
  local t="${1:-}"
  case "$t" in
    deb|debs|DEB|DEBS) echo "debs" ;;
    tar|tars|TAR|TARS) echo "tar" ;;
    img|image|images|IMG|IMAGE|IMAGES) echo "images" ;;
    *) echo "$t" ;;
  esac
}

get_local_artifacts_dir_for(){
  # Returns local artifacts dir for given type (defaults to $HOME/packages-to-be-installed)
  local t="$1"; local base="${LOCAL_ARTIFACTS_DIR:-$HOME/packages-to-be-installed}"; local sub; sub="$(artifact_dir_for_type "$t")"
  echo "$base/$sub"
}

load_config_file(){
  local loaded=""
  
  # 处理 CLUSTER 环境变量（如果提供）
  # 支持 C1/C2 或 1/2 格式，统一转换为 C{数字} 格式
  local saved_cluster="${CLUSTER:-}"
  if [[ -n "$saved_cluster" ]]; then
    if [[ "$saved_cluster" =~ ^[0-9]+$ ]]; then
      saved_cluster="C${saved_cluster}"
    elif [[ ! "$saved_cluster" =~ ^C[0-9]+$ ]]; then
      log_error "无效的 CLUSTER 环境变量值: $saved_cluster (应为数字如 1 或 2，或格式如 C1 或 C2)"
      return 1
    fi
    export CLUSTER="$saved_cluster"
  fi
  
  # 优先加载新的配置文件
  if [[ -f "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf" ]]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/deploy-infrastructure-all/deploy-infrastructure-all.conf"; loaded="deploy-infrastructure-all.conf"
  elif [[ -f "$PROJECT_ROOT/config/deploy.conf" ]]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/config/deploy.conf"; loaded="deploy.conf"; log_warn "未找到 deploy-infrastructure-all.conf，回退 config/deploy.conf"
  elif [[ -f "$PROJECT_ROOT/config/cluster.conf" ]]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/config/cluster.conf"; loaded="cluster.conf"; log_warn "未找到 deploy.conf，回退 config/cluster.conf"
  else
    log_error "未找到配置文件: deploy-infrastructure-all/deploy-infrastructure-all.conf 或 config/deploy.conf 或 config/cluster.conf"; return 1
  fi
  
  # 恢复环境变量的优先级（如果之前设置了 CLUSTER，恢复它）
  if [[ -n "$saved_cluster" ]]; then
    export CLUSTER="$saved_cluster"
  else
    # 如果之前未设置 CLUSTER，但配置文件中可能有 CLUSTER="${CLUSTER:-}" 将其设置为空字符串
    # 需要清空它，以便后续逻辑能正确读取默认值
    if [[ "${CLUSTER:-}" == "" ]]; then
      unset CLUSTER
    fi
  fi
  
  # 集群选择逻辑（优先级：环境变量 CLUSTER > 全局配置文件 default_cluster > C1）
  # 如果 CLUSTER 未设置，尝试从全局配置文件读取默认集群
  local cluster_selected="${CLUSTER:-}"
  if [[ -z "$cluster_selected" ]]; then
    # 尝试加载 cluster-config-mapping.sh 以获取全局默认集群
    # 尝试多个可能的路径
    local mapping_script=""
    for path in "$PROJECT_ROOT/../../utils/cluster-config-mapping.sh" \
                "$HOME/k8s/utils/cluster-config-mapping.sh" \
                "$PROJECT_ROOT/../utils/cluster-config-mapping.sh"; do
      if [[ -f "$path" ]]; then
        mapping_script="$path"
        break
      fi
    done
    
    if [[ -n "$mapping_script" ]]; then
      # shellcheck disable=SC1090
      source "$mapping_script"
      cluster_selected=$(get_global_default_cluster)
    else
      # 如果无法加载，回退到 C1（与原来行为一致）
      cluster_selected="C1"
    fi
  fi
  
  # 设置 CLUSTER 环境变量，以便后续使用
  export CLUSTER="$cluster_selected"
  
  # 验证集群值格式：必须是 C{数字} 格式（如 C1, C2, C3, C10 等）
  # 支持不连续的集群编号（如只有 C1 和 C3，没有 C2）
  if [[ ! "$cluster_selected" =~ ^C[0-9]+$ ]]; then
    log_error "无效的集群值: $cluster_selected (格式必须为 C{数字}，如 C1, C2, C3 等)"
    return 1
  fi
  
  # 将 C*_SERVER_n_* 变量映射到 SERVER_n_*
  # 支持所有可能的字段：TYPE, PUBLIC_IP, LOCAL_IP, USER, SECRET, PASS, SSH_PORT, DIR, 
  #                     CURRENT_HOSTNAME, CLUSTER_HOSTNAME, EXTRA_LABELS, TAINTS
  local server_num=1
  local cluster_prefix="${cluster_selected}_"
  
  while true; do
    # 检查是否存在对应集群的 SERVER_n_PUBLIC_IP（作为判断是否有该节点的依据）
    local cluster_pub_ip_var="${cluster_prefix}SERVER_${server_num}_PUBLIC_IP"
    
    if [[ -z "${!cluster_pub_ip_var:-}" ]]; then
      # 该节点不存在，停止映射
      break
    fi
    
    # 映射所有字段
    local fields=("TYPE" "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT" "DIR" 
                  "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS")
    
    for field in "${fields[@]}"; do
      local cluster_var="${cluster_prefix}SERVER_${server_num}_${field}"
      local server_var="SERVER_${server_num}_${field}"
      
      if [[ -n "${!cluster_var:-}" ]]; then
        # 使用间接变量赋值
        eval "$server_var=\"${!cluster_var}\""
      fi
    done
    
    server_num=$((server_num+1))
  done
  
  # 清空后续的 SERVER_n_* 变量（如果有的话）
  local check_var_name="SERVER_${server_num}_PUBLIC_IP"
  while [[ -n "${!check_var_name:-}" ]]; do
    local fields=("TYPE" "PUBLIC_IP" "LOCAL_IP" "USER" "SECRET" "PASS" "SSH_PORT" "DIR" 
                  "CURRENT_HOSTNAME" "CLUSTER_HOSTNAME" "EXTRA_LABELS" "TAINTS")
    for field in "${fields[@]}"; do
      eval "unset SERVER_${server_num}_${field}"
    done
    server_num=$((server_num+1))
    check_var_name="SERVER_${server_num}_PUBLIC_IP"
  done
  
  # 应用集群配置映射（使用 utils 中的通用函数）
  if [[ -f "$PROJECT_ROOT/../utils/cluster-config-mapping.sh" ]]; then
    source "$PROJECT_ROOT/../utils/cluster-config-mapping.sh"
    apply_cluster_config_mapping "$cluster_selected"
  fi
  
  log_info "加载配置: $loaded (集群: $cluster_selected, 节点数: $((server_num-1)))"
  return 0
}

# ---------------------------
# 新统一模式获取与校验
# ---------------------------
get_packages_deploy_mode(){
  # 优先使用新开关 packages_deploy_mode
  local mode="${packages_deploy_mode:-}"
  local old_a="${DEBS_AND_TARS_DEPLOY:-}"
  local old_b="${CHARTS_AND_IMAGES_DEPLOY:-}"

  # 若新开关明确设置，直接返回（同时如旧开关残留则提示警告）
  if [[ -n "$mode" ]]; then
    if [[ -n "$old_a" || -n "$old_b" ]]; then
      log_warn "检测到旧开关(DEBS_AND_TARS_DEPLOY/CHARTS_AND_IMAGES_DEPLOY)残留，将忽略旧开关，仅使用 packages_deploy_mode=$mode"
    fi
    echo "$mode"; return 0
  fi

  # 未设置新开关时，尝试兼容映射；如出现混合或缺失，Fail-fast
  if [[ -n "$old_a" && -n "$old_b" ]]; then
    if [[ "$old_a" == "$old_b" ]]; then
      log_warn "旧开关将被弃用：请在 deploy.conf 中设置 packages_deploy_mode=$old_a，并删除旧开关"
      echo "$old_a"; return 0
    else
      log_error "检测到旧开关不一致：DEBS_AND_TARS_DEPLOY=$old_a, CHARTS_AND_IMAGES_DEPLOY=$old_b；请在 deploy.conf 显式设置 packages_deploy_mode=online|offline，并删除旧开关"
      exit 1
    fi
  fi

  if [[ -n "$old_a" || -n "$old_b" ]]; then
    log_error "检测到仅设置了一个旧开关：请在 deploy.conf 显式设置 packages_deploy_mode=online|offline，并删除旧开关"
    exit 1
  fi

  # 默认模式：online（与新架构默认一致）
  echo "online"
}


# 支持稀疏编号：返回已定义的 SERVER_n_PUBLIC_IP 或 SERVER_n_LOCAL_IP 的索引列表（空格分隔）
get_defined_server_indices(){
  local max="${MAX_SERVERS:-64}"
  local idx
  local out=""
  for idx in $(seq 1 "$max"); do
    local public_ip="SERVER_${idx}_PUBLIC_IP"
    local local_ip="SERVER_${idx}_LOCAL_IP"
    # 检查是否有 PUBLIC_IP 或 LOCAL_IP
    if [[ -n "${!public_ip-}" ]] || [[ -n "${!local_ip-}" ]]; then
      out+="$idx "
    fi
  done
  echo "$out"
}

get_server_var(){
  # $1: index, $2: KEY（如 PUBLIC_IP/USER/TYPE/SSH_PORT/DIR/PASS/SECRET）
  local idx="$1"; local key="$2"
  local var="SERVER_${idx}_${key}"
  echo "${!var-}"
}

node_should_run(){
  # $1: index, $2: step_target(master|worker|all)
  local idx="$1"; local tgt="${2:-all}"
  local type; type="$(get_server_var "$idx" TYPE)"
  case "${tgt:-all}" in
    all|ALL|All) return 0 ;;
    master|MASTER) [[ "$type" == "master" ]] && return 0 || return 1 ;;
    worker|WORKER) [[ "$type" == "worker" ]] && return 0 || return 1 ;;
    *) return 0 ;;
  esac
}

resolve_remote_dir(){
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then echo "~/packages-to-be-installed"; return 0; fi
  # 若配置中误写成本机 $HOME，转换回远端家目录表达
  if [[ -n "$HOME" ]]; then
    if [[ "$raw" == "$HOME" ]]; then echo "~"; return 0; fi
    if [[ "$raw" == "$HOME/"* ]]; then echo "~/${raw#${HOME}/}"; return 0; fi
  fi
  echo "$raw"
}

online_check_score(){
  local ok=0
  if need curl; then
    curl -fsSL --connect-timeout 4 --max-time 6 https://download.docker.com >/dev/null 2>&1 && ok=$((ok+1)) || true
    curl -fsSL --connect-timeout 4 --max-time 6 https://pkgs.k8s.io >/dev/null 2>&1 && ok=$((ok+1)) || true
    curl -fsSL --connect-timeout 4 --max-time 6 https://registry.k8s.io >/dev/null 2>&1 && ok=$((ok+1)) || true
  fi
  echo "$ok"
}

for_each_node(){
  # $1: step_target, $2..: command to eval with $i exported
  local target="$1"; shift || true
  local indices; indices="$(get_defined_server_indices)"
  for i in $indices; do
    if node_should_run "$i" "$target"; then
      # 直接调用传入的函数名，避免修改 IFS 导致后续分词异常
      "$@"
    fi
  done
}

# ---------------------------
# 远程执行与文件操作
# ---------------------------

_ssh_base_opts(){
  echo "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
}

ssh_exec(){
  # $1 index, $2 command string
  local idx="$1"; shift; local cmd="$*"
  local host user pass secret port
  host="$(get_server_var "$idx" PUBLIC_IP)"
  user="$(get_server_var "$idx" USER)"
  pass="$(get_server_var "$idx" PASS)"
  secret="$(get_server_var "$idx" SECRET)"
  port="$(get_server_var "$idx" SSH_PORT)"; port="${port:-22}"
  # 使用参数数组，避免 -o 选项被拼接为单个参数
  local -a ssh_opts_arr
  ssh_opts_arr=( -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o BatchMode=no -o RequestTTY=no -p "$port" )
  if [[ -n "$host" && -n "$user" ]]; then
    # 在远程命令中添加输出刷新，确保实时显示
    local cmd_with_flush="stdbuf -oL -eL $cmd"
    if [[ -n "$secret" && -f "$secret" ]]; then
      ssh -i "$secret" "${ssh_opts_arr[@]}" "$user@$host" "$cmd_with_flush"
      return $?
    elif [[ -n "$pass" ]]; then
      sshpass -p "$pass" ssh "${ssh_opts_arr[@]}" "$user@$host" "$cmd_with_flush"
      return $?
    else
      ssh "${ssh_opts_arr[@]}" "$user@$host" "$cmd_with_flush"
      return $?
    fi
  else
    log_warn "节点$idx 未配置 host/user，跳过"
    return 1
  fi
}

ssh_exec_sudo(){
  # $1 index, $2 command string (without sudo)
  local idx="$1"; shift; local raw="$*"
  local pass; pass="$(get_server_var "$idx" PASS)"
  # 以 base64 传输命令，避免引号/通配符在远端 shell 被误解析
  local raw_b64
  raw_b64="$(printf '%s' "$raw" | base64 -w0)"
  # 尝试无密码 sudo（避免 trap 使用未绑定变量）
  if ssh_exec "$idx" "bash -lc 't=\$(mktemp) || exit 1; echo $raw_b64 | base64 -d > \$t; sudo -n bash \$t; rc=\$?; rm -f \$t; exit \$rc'"; then
    return 0
  fi
  # 尝试密码 sudo
  if [[ -n "$pass" ]]; then
    ssh_exec "$idx" "bash -lc 't=\$(mktemp) || exit 1; echo $raw_b64 | base64 -d > \$t; echo \"$pass\" | sudo -S bash \$t; rc=\$?; rm -f \$t; exit \$rc'"
    return $?
  else
    return 1
  fi
}

scp_copy_to(){
  # $1 idx, $2 local_path, $3 remote_path
  local idx="$1"; local lpath="$2"; local rpath="$3"
  local host user pass secret port
  host="$(get_server_var "$idx" PUBLIC_IP)"
  user="$(get_server_var "$idx" USER)"
  pass="$(get_server_var "$idx" PASS)"
  secret="$(get_server_var "$idx" SECRET)"
  port="$(get_server_var "$idx" SSH_PORT)"; port="${port:-22}"
  # 使用参数数组，避免 -o 选项被拼接为单个参数
  local -a scp_opts_arr
  scp_opts_arr=( -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -P "$port" )
  if [[ -n "$secret" && -f "$secret" ]]; then
    scp -i "$secret" "${scp_opts_arr[@]}" "$lpath" "$user@$host:$rpath"
  elif [[ -n "$pass" ]]; then
    sshpass -p "$pass" scp "${scp_opts_arr[@]}" "$lpath" "$user@$host:$rpath"
  else
    scp "${scp_opts_arr[@]}" "$lpath" "$user@$host:$rpath"
  fi
}

generate_hosts_entries(){
  # 输出形如 "<LOCAL_IP> <CLUSTER_HOSTNAME>" 的行，若无 LOCAL_IP 则用 PUBLIC_IP
  local indices; indices="$(get_defined_server_indices)"
  local out=""
  local j
  for j in $indices; do
    local lip="$(get_server_var "$j" LOCAL_IP)"; local pip="$(get_server_var "$j" PUBLIC_IP)"
    local chost="$(get_server_var "$j" CLUSTER_HOSTNAME)"
    local ip="${lip:-$pip}"
    if [[ -n "$ip" && -n "$chost" ]]; then
      out+="$ip $chost\n"
    fi
  done
  printf "%b" "$out"
}

# ---------------------------
# 统一版本和 Kubeconfig 管理函数
# ---------------------------

# 获取统一的 K8s 版本（解析并添加 v 前缀）
get_k8s_version_resolved() {
  local ver="${STEP03_K8S_VERSION:-${CLUSTER_VERSION:-}}"
  if [[ -n "$ver" && "$ver" != v* ]]; then
    ver="v${ver}"
  fi
  echo "$ver"
}

# 统一的远程 kubeconfig 准备函数
prepare_remote_kubeconfig() {
  local target_node="$1"
  local kubeconfig_var_name="$2"  # 变量名，如 "REMOTE_KUBECONFIG"
  local default_path="${3:-/etc/kubernetes/admin.conf}"
  
  # 获取当前变量值
  local current_path
  eval "current_path=\${$kubeconfig_var_name:-$default_path}"
  
  # 检查可读的 kubeconfig
  if ssh_exec "$target_node" "bash -lc 'test -r \"$current_path\"'"; then
    return 0
  fi
  # 回退到用户家目录配置
        if ssh_exec "$target_node" "bash -lc 'test -r \"\$HOME/.kube/config\"'"; then
          eval "$kubeconfig_var_name='\$HOME/.kube/config'"
          return 0
        fi
  # 使用 sudo 复制到用户家目录
  if ssh_exec_sudo "$target_node" "bash -lc 'mkdir -p \$HOME/.kube && cp -f /etc/kubernetes/admin.conf \$HOME/.kube/config && chmod 0644 \$HOME/.kube/config'"; then
    eval "$kubeconfig_var_name='\$HOME/.kube/config'"
    return 0
  fi
  log_error "无法在远端节点 $target_node 准备可读的 kubeconfig"
  return 1
}
