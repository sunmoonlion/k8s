#!/usr/bin/env bash
set -euo pipefail

# 通用工具函数（加载配置、日志、节点遍历、在线检测等）

export LC_ALL=C
export LANG=C
export LANGUAGE=C

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
K8S_ROOT_DIR=""
search_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [[ "$search_dir" != "/" ]]; do
  if [[ -f "$search_dir/utils/cluster-arg-parser.sh" ]]; then
    K8S_ROOT_DIR="$search_dir"
    break
  fi
  search_dir="$(dirname "$search_dir")"
done
if [[ -z "$K8S_ROOT_DIR" ]]; then
  echo "[ERROR] 无法定位 k8s 根目录（未找到 utils/cluster-arg-parser.sh），SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 1>&2
  exit 1
fi

log_info(){ echo -e "[INFO] $*"; }
log_warn(){ echo -e "\033[33m[WARN]\033[0m $*"; }
log_error(){ echo -e "\033[31m[ERROR]\033[0m $*" 1>&2; }
log_success(){ echo -e "\033[32m[SUCCESS]\033[0m $*"; }

need(){ command -v "$1" >/dev/null 2>&1; }

# 非交互 apt/dpkg：避免 config.toml 等配置文件冲突时阻塞（保留已有配置，不弹 Y/I/N/O）
# 注意：勿在值内嵌双引号，否则嵌入 ssh "..." 时会截断命令字符串
export APT_NONINTERACTIVE_PREFIX="export DEBIAN_FRONTEND=noninteractive"
export APT_INSTALL_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

## packages-management 模块已移除；如需离线准备，请使用各 Step 的 local 策略或按提示手动上传离线包。

artifact_dir_for_type(){
  # Map a loose type label to standardized subdir name
  local t="${1:-}"
  case "$t" in
    deb|debs|DEB|DEBS) echo "debs" ;;
    tar|tars|TAR|TARS) echo "tars" ;;
    img|image|images|IMG|IMAGE|IMAGES) echo "images" ;;
    *) echo "$t" ;;
  esac
}

get_local_artifacts_dir_for(){
  # Returns local artifacts dir for given type (defaults to $HOME/packages-to-be-installed)
  local t="$1"; local base="${LOCAL_ARTIFACTS_DIR:-$HOME/packages-to-be-installed}"; local sub; sub="$(artifact_dir_for_type "$t")"
  echo "$base/$sub"
}

# shellcheck source=/dev/null
source "$PROJECT_ROOT/utils/config.sh"
load_config_file(){ infra_load_config; }

# ---------------------------
# 新统一模式获取与校验
# ---------------------------
get_packages_deploy_mode(){
  local mode="${packages_deploy_mode:-offline}"
  case "$mode" in
    online|offline) printf '%s\n' "$mode" ;;
    *) log_error "packages_deploy_mode must be online or offline"; return 1 ;;
  esac
}

# 支持稀疏编号：返回已定义的 SERVER_n_PUBLIC_IP 或 SERVER_n_LOCAL_IP 的索引列表（空格分隔）
get_defined_server_indices(){ infra_server_indices; }
get_server_var(){ infra_server_value "$@"; }

node_should_run(){
  # $1: index, $2: step_target(master|worker|all)
  local idx="$1"; local tgt="${2:-all}"
  local type; type="$(get_server_var "$idx" TYPE)"
  case "${tgt:-all}" in
    all|ALL|All) return 0 ;;
    master|MASTER) [[ "$type" == "master" ]] && return 0 || return 1 ;;
    worker|WORKER) [[ "$type" == "worker" ]] && return 0 || return 1 ;;
    *) log_error "Unknown step target: $tgt"; return 1 ;;
  esac
}

# Literal ~ is intentionally passed to callers for expansion on the remote host.
# shellcheck disable=SC2088
resolve_remote_dir(){
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then echo "~/packages-to-be-installed"; return 0; fi
  # 若配置中误写成本机 $HOME，转换回远端家目录表达
  if [[ -n "$HOME" ]]; then
    if [[ "$raw" == "$HOME" ]]; then echo "~"; return 0; fi
    if [[ "$raw" == "$HOME/"* ]]; then echo "~/${raw#"${HOME}/"}"; return 0; fi
  fi
  echo "$raw"
}

online_check_score(){
  local ok=0
  if need curl; then
    if curl -fsSL --connect-timeout 4 --max-time 6 https://download.docker.com >/dev/null 2>&1; then ok=$((ok+1)); fi
    if curl -fsSL --connect-timeout 4 --max-time 6 https://pkgs.k8s.io >/dev/null 2>&1; then ok=$((ok+1)); fi
    if curl -fsSL --connect-timeout 4 --max-time 6 https://registry.k8s.io >/dev/null 2>&1; then ok=$((ok+1)); fi
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

# Strict key/agent authentication shared by cluster steps. Cloud 未经实机验证.
# Passwords remain in the existing owner's configuration until separately moved;
# these transports never put them into command arguments or retry sudo actions.
infra_ssh_options(){
  local idx="$1" user host identity port
  host="$(get_server_var "$idx" PUBLIC_IP)"
  [[ -n "$host" ]] || host="$(get_server_var "$idx" LOCAL_IP)"
  user="$(get_server_var "$idx" USER)"
  identity="$(get_server_var "$idx" SECRET)"
  port="$(get_server_var "$idx" SSH_PORT)"; port="${port:-22}"
  [[ "$host" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ && "$user" =~ ^[a-z_][a-z0-9_-]*$ && "$port" =~ ^[0-9]{1,5}$ ]] || {
    log_error "Invalid SSH destination for node $idx"; return 1;
  }
  (( 10#$port >= 1 && 10#$port <= 65535 )) || return 1
  INFRA_SSH_DESTINATION="$user@$host"
  INFRA_SSH_PORT="$port"
  INFRA_SSH_OPTIONS=(-o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10
                     -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o RequestTTY=no)
  if [[ -n "$identity" ]]; then
    [[ -f "$identity" ]] || { log_error "Explicit SSH key missing for node $idx"; return 1; }
    INFRA_SSH_OPTIONS+=(-o IdentitiesOnly=yes -i "$identity")
  fi
}

ssh_exec(){
  local idx="$1"; shift
  infra_ssh_options "$idx" || return 1
  # Caller supplies intentional remote shell code. Never prefix a compound
  # command with stdbuf or retry a partially completed mutation.
  ssh "${INFRA_SSH_OPTIONS[@]}" -p "$INFRA_SSH_PORT" "$INFRA_SSH_DESTINATION" "$@"
}

ssh_exec_sudo(){
  local idx="$1"; shift
  # Send the script through stdin, avoiding temporary files and command-line
  # exposure. The target requires noninteractive sudo; failure is returned once.
  ssh_exec "$idx" 'sudo -n bash -se' <<< "$*"
}

scp_copy_to(){
  local idx="$1" lpath="$2" rpath="$3"
  infra_ssh_options "$idx" || return 1
  scp "${INFRA_SSH_OPTIONS[@]}" -P "$INFRA_SSH_PORT" -- "$lpath" "$INFRA_SSH_DESTINATION:$rpath"
}

generate_hosts_entries(){
  # 输出形如 "<LOCAL_IP> <CLUSTER_HOSTNAME>" 的行，若无 LOCAL_IP 则用 PUBLIC_IP
  local indices; indices="$(get_defined_server_indices)"
  local out=""
  local j
  for j in $indices; do
    local lip pip
    lip="$(get_server_var "$j" LOCAL_IP)"; pip="$(get_server_var "$j" PUBLIC_IP)"
    local chost
    chost="$(get_server_var "$j" CLUSTER_HOSTNAME)"
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
  local target_node="$1" variable="$2" default_path="${3:-/etc/kubernetes/admin.conf}"
  [[ "$variable" =~ ^[A-Z][A-Z0-9_]*$ ]] || return 1
  local current_path="${!variable:-$default_path}" quoted
  [[ "$current_path" == /* && "$current_path" != *$'\n'* ]] || {
    log_error "Explicit absolute kubeconfig path required"; return 1;
  }
  printf -v quoted '%q' "$current_path"
  if ! ssh_exec "$target_node" "test -r $quoted"; then
    log_error "Configured kubeconfig is unreadable; provision its owned 0600 copy explicitly"
    return 1
  fi
  printf -v "$variable" '%s' "$current_path"
}
