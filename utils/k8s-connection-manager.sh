#!/bin/bash

# 集群参数解析（轻量，无连接副作用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"

# Kubernetes 集群管理脚本 — 支持跳板机/直接访问/Kind 三种模式
set -euo pipefail

CONFIG_FILE="$(dirname "$0")/k8s-admin.conf"
STATUS_FILE="$SCRIPT_DIR/.k8s-status"
PID_FILE="$SCRIPT_DIR/.k8s-tunnel.pid"

# ── 颜色 & 日志 ───────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
msg()     { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()     { echo -e "${RED}❌ $1${NC}"; }

# ── WSL 检测 + 自适应 SSH 参数 ─────────────────────────────────────────────────
is_wsl() { [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; }
if is_wsl; then
  SSH_ALIVE_INTERVAL=10   # WSL 网络不稳时缩短心跳
  SSH_ALIVE_COUNT=6       # 60s 无响应才断
else
  SSH_ALIVE_INTERVAL=30
  SSH_ALIVE_COUNT=3       # 90s 无响应才断
fi
SSH_CM_PERSIST=120   # ControlMaster 空闲保持秒数
CM_SOCKET=""         # 将在 setup_ssh_control_master 中设置

# ── 工具函数 ──────────────────────────────────────────────────────────────────

# 检测本地端口是否已在监听
port_is_listening() {
  (echo >/dev/tcp/127.0.0.1/"$1") 2>/dev/null
}

# 等待本地端口开始监听（替代固定 sleep）
wait_for_tunnel_port() {
  local port="$1" timeout="${2:-20}"
  local i=0
  while [[ $i -lt $timeout ]]; do
    if port_is_listening "$port"; then return 0; fi
    sleep 1; i=$((i + 1))
  done
  return 1
}

# 释放本地端口：杀掉占用进程，等待端口真正空闲
release_local_port() {
  local port="$1" max_wait="${2:-5}"
  pkill -f "ssh.*[: ]${port}:127\.0\.0\.1:" >/dev/null 2>&1 || true
  pkill -f "ssh.*-L ?${port}:"              >/dev/null 2>&1 || true
  local waited=0
  while [[ $waited -lt $max_wait ]]; do
    local pids=""
    if command -v lsof >/dev/null 2>&1; then
      pids=$(lsof -ti "TCP:${port}" 2>/dev/null || true)
    elif command -v ss >/dev/null 2>&1; then
      pids=$(ss -tlnp 2>/dev/null | awk -v p=":${port}" '$0 ~ p {match($0,/pid=([0-9]+)/,a); if(a[1]) print a[1]}' || true)
    fi
    [[ -z "$pids" ]] && break
    echo "$pids" | xargs kill -9 2>/dev/null || true
    sleep 1; waited=$((waited + 1))
  done
}

# ── SSH ControlMaster（复用连接加速多次 SSH 操作）────────────────────────────

# 建立 ControlMaster 连接（用于 kubeconfig 下载等操作）
setup_ssh_control_master() {
  local host="$1" port="$2" user="$3" secret="${4:-}"
  CM_SOCKET="/tmp/.k8s-cm-${CLUSTER:-C1}-${host//[^a-zA-Z0-9_]/_}-$$"
  local opts=(-o ControlMaster=auto -o "ControlPath=${CM_SOCKET}"
              -o "ControlPersist=${SSH_CM_PERSIST}"
              -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
              -o LogLevel=ERROR
              -o "ConnectTimeout=${GLOBAL_TIMEOUT}"
              -o "ServerAliveInterval=${SSH_ALIVE_INTERVAL}"
              -o "ServerAliveCountMax=${SSH_ALIVE_COUNT}"
              -o TCPKeepAlive=yes
              -p "$port")
  [[ -n "$secret" ]] && opts+=(-i "$secret")
  ssh "${opts[@]}" "$user@$host" true 2>/dev/null || true
}

# 通过 ControlMaster 执行 SSH 命令
cm_ssh() {
  local host="$1" port="$2" user="$3" secret="${4:-}"
  shift 4
  local opts=(-o ControlMaster=no -o "ControlPath=${CM_SOCKET:-/dev/null}"
              -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
              -o LogLevel=ERROR
              -o "ConnectTimeout=${GLOBAL_TIMEOUT}"
              -o "ServerAliveInterval=${SSH_ALIVE_INTERVAL}"
              -o "ServerAliveCountMax=${SSH_ALIVE_COUNT}"
              -o TCPKeepAlive=yes
              -p "$port")
  [[ -n "$secret" ]] && opts+=(-i "$secret")
  ssh "${opts[@]}" "$user@$host" "$@"
}

# 通过 ControlMaster 执行 SCP
cm_scp() {
  local host="$1" port="$2" user="$3" secret="${4:-}" src="$5" dst="$6"
  local opts=(-o ControlMaster=no -o "ControlPath=${CM_SOCKET:-/dev/null}"
              -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
              -o LogLevel=ERROR
              -o "ConnectTimeout=${GLOBAL_TIMEOUT}"
              -P "$port")
  [[ -n "$secret" ]] && opts+=(-i "$secret")
  scp "${opts[@]}" "$user@$host:$src" "$dst"
}

# 关闭 ControlMaster
close_ssh_control_master() {
  if [[ -n "${CM_SOCKET:-}" && -S "$CM_SOCKET" ]]; then
    ssh -o "ControlPath=${CM_SOCKET}" -O exit dummy@dummy 2>/dev/null || true
    rm -f "$CM_SOCKET"
  fi
  CM_SOCKET=""
}

# ── 隧道管理 ──────────────────────────────────────────────────────────────────

# 获取当前模式的本地端口
_current_local_port() {
  case "${CURRENT_MODE:-}" in
    bastion) echo "${BASTION_LOCAL_PORT:-6441}" ;;
    direct)  echo "${DIRECT_LOCAL_PORT:-6441}" ;;
    *) echo "" ;;
  esac
}

# 只启动 SSH 隧道（不含 kubeconfig 下载，用于重连）
_start_tunnel_ssh() {
  local mode="${CURRENT_MODE:-direct}"
  case "$mode" in
    bastion)
      local bhost_ip="${BASTION_HOST%%:*}"
      local bhost_port="${BASTION_HOST##*:}"; bhost_port="${bhost_port:-22}"
      local target_ip="${BASTION_API_SERVER%%:*}"
      local api_port="${BASTION_API_PORT:-6443}"
      local opts=(); [[ -n "${BASTION_SECRET:-}" ]] && opts+=(-i "$BASTION_SECRET")
      release_local_port "$BASTION_LOCAL_PORT"
      ssh "${opts[@]}" \
        -o ConnectTimeout="$GLOBAL_TIMEOUT" \
        -o ServerAliveInterval="$SSH_ALIVE_INTERVAL" \
        -o ServerAliveCountMax="$SSH_ALIVE_COUNT" \
        -o TCPKeepAlive=yes \
        -L "$BASTION_LOCAL_PORT:$target_ip:$api_port" \
        "$BASTION_USER@$bhost_ip" -p "$bhost_port" -N &
      TUNNEL_PID=$!
      echo "$TUNNEL_PID" > "$PID_FILE"
      wait_for_tunnel_port "$BASTION_LOCAL_PORT"
      ;;
    direct)
      local dhost_ip="${DIRECT_HOST%%:*}"
      local dhost_port="${DIRECT_HOST##*:}"; dhost_port="${dhost_port:-22}"
      local api_port="${TUNNEL_API_PORT:-6443}"
      local opts=(); [[ -n "${DIRECT_SECRET:-}" ]] && opts+=(-i "$DIRECT_SECRET")
      release_local_port "$DIRECT_LOCAL_PORT"
      ssh "${opts[@]}" \
        -o ConnectTimeout="$GLOBAL_TIMEOUT" \
        -o ServerAliveInterval="$SSH_ALIVE_INTERVAL" \
        -o ServerAliveCountMax="$SSH_ALIVE_COUNT" \
        -o TCPKeepAlive=yes \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -L "$DIRECT_LOCAL_PORT:127.0.0.1:$api_port" \
        -p "$dhost_port" "$DIRECT_USER@$dhost_ip" -N &
      TUNNEL_PID=$!
      echo "$TUNNEL_PID" > "$PID_FILE"
      wait_for_tunnel_port "$DIRECT_LOCAL_PORT"
      ;;
    *)
      return 1
      ;;
  esac
}

# 确保隧道在运行，如果断了则自动重连（最多重试 3 次）
ensure_tunnel() {
  [[ "${CURRENT_MODE:-}" == "kind" ]] && return 0

  local port; port=$(_current_local_port)
  [[ -z "$port" ]] && return 1

  # 快速路径：进程活着且端口在监听
  if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null \
     && port_is_listening "$port"; then
    return 0
  fi

  warn "⚠️  隧道断开，正在自动重连..."
  local attempt=0
  while [[ $attempt -lt 3 ]]; do
    attempt=$((attempt + 1))
    msg "重连尝试 ${attempt}/3..."
    if _start_tunnel_ssh; then
      save_status
      success "✅ 隧道重连成功 (PID: $TUNNEL_PID)"
      return 0
    fi
    sleep 2
  done
  err "❌ 隧道重连失败，请重新运行脚本"
  return 1
}

# 菜单中执行 kubectl 命令的统一入口（自动重连）
run_kubectl_cmd() {
  if [[ "${CURRENT_MODE:-}" != "kind" ]] && ! ensure_tunnel; then
    err "❌ 无法建立连接，请重新运行脚本"
    return 1
  fi
  KUBECONFIG="$CURRENT_KUBECONFIG" "$@"
}

# ── 公共：配置域名别名 + 更新 kubeconfig server ──────────────────────────────
# 返回：写入 /etc/hosts 的域名
setup_bind_alias() {
  local kubeconfig="$1" local_port="$2"

  # 从 kubeconfig 提取 CA 证书并解析 SAN 域名
  local cert_tmp; cert_tmp=$(mktemp)
  local valid_domain=""

  # 优先用 yq
  if command -v yq >/dev/null 2>&1; then
    local cert_data
    cert_data=$(yq e '.clusters[0].cluster["certificate-authority-data"]' "$kubeconfig" 2>/dev/null || echo "")
    [[ -n "$cert_data" ]] && echo "$cert_data" | base64 -d > "$cert_tmp" 2>/dev/null
  fi
  # 兜底：直接从文件 grep base64 data
  if [[ ! -s "$cert_tmp" ]]; then
    grep -m1 'certificate-authority-data:' "$kubeconfig" | \
      awk '{print $2}' | base64 -d > "$cert_tmp" 2>/dev/null || true
  fi
  if [[ -s "$cert_tmp" ]]; then
    valid_domain=$(openssl x509 -in "$cert_tmp" -noout -text 2>/dev/null \
      | grep -oE 'DNS:[^,[:space:]]+' | head -n1 | cut -d: -f2 || true)
  fi
  rm -f "$cert_tmp"

  if [[ -z "$valid_domain" ]]; then
    valid_domain="kubernetes"
    warn "⚠️  无法解析证书SAN，使用默认域名: $valid_domain"
  fi

  # /etc/hosts 添加（带标记，去重）
  if grep -q "127\.0\.0\.1[[:space:]]\+${valid_domain}[[:space:]]\+# added_by_k8s_manager" /etc/hosts 2>/dev/null; then
    msg "域名别名已存在: 127.0.0.1 $valid_domain"
  else
    echo "127.0.0.1 $valid_domain # added_by_k8s_manager" | sudo tee -a /etc/hosts >/dev/null
    msg "已添加域名别名: 127.0.0.1 $valid_domain"
  fi

  # 修改 kubeconfig server（替换 IP/域名，保留端口）
  sed -i "s|server: https://[^:]*:[0-9]*|server: https://${valid_domain}:${local_port}|g" "$kubeconfig"
  msg "🔧 已配置域名别名严格 TLS 模式"
  echo "$valid_domain"
}

# ── 清理 ──────────────────────────────────────────────────────────────────────
cleanup() {
  if [[ -f "$PID_FILE" ]]; then
    local saved_pid; saved_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    [[ -n "$saved_pid" && -e "/proc/$saved_pid" ]] && stop_connection_quiet
  fi
  close_ssh_control_master
  unset KUBECONFIG
  msg "✅ 已清理资源"
  exit 0
}
trap 'cleanup' EXIT INT TERM

# ── kubectl 检测与安装 ────────────────────────────────────────────────────────
check_and_install_kubectl() {
  local found=false
  command -v kubectl >/dev/null 2>&1 && found=true
  if [[ "$found" == "false" ]]; then
    for p in /snap/bin/kubectl /usr/local/bin/kubectl /usr/bin/kubectl; do
      [[ -x "$p" ]] && found=true && break
    done
  fi

  if [[ "$found" == "false" ]]; then
    msg "🔧 检测到 kubectl 未安装，正在自动安装..."
    local stable_ver; stable_ver=$(curl -sL https://dl.k8s.io/release/stable.txt)
    local arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && arch="arm64"
    local os="linux"; [[ "$OSTYPE" == "darwin"* ]] && os="darwin"
    curl -sLO "https://dl.k8s.io/release/${stable_ver}/bin/${os}/${arch}/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    success "✅ kubectl 安装完成"
  else
    msg "ℹ️  kubectl 已安装: $(kubectl version --client 2>/dev/null | head -1 || echo '版本信息获取失败')"
  fi
}

# ── 配置文件读取 ──────────────────────────────────────────────────────────────
read_config() {
  [[ ! -f "$CONFIG_FILE" ]] && { err "❌ 配置文件不存在: $CONFIG_FILE"; exit 1; }

  expand_path() { local p="${1/#\~/$HOME}"; p=$(eval echo "$p"); echo "$p"; }
  first_line()  { local v="${1//$'\r'/}"; printf '%s' "${v%%$'\n'*}"; }

  # 全局配置
  GLOBAL_DEFAULT_MODE=$(  sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^default_mode=" | cut -d= -f2 | tr -d ' ')
  GLOBAL_AUTO_STOP=$(     sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^auto_stop="    | cut -d= -f2 | tr -d ' ')
  GLOBAL_TIMEOUT=$(       sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^timeout="      | cut -d= -f2 | tr -d ' ')
  GLOBAL_DEFAULT_CLUSTER=$(sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^default_cluster=" | cut -d= -f2 | tr -d ' ')

  local cluster_name="${CLUSTER:-${GLOBAL_DEFAULT_CLUSTER:-C1}}"
  local cluster_upper; cluster_upper=$(echo "$cluster_name" | tr '[:lower:]' '[:upper:]')

  if [[ "$cluster_upper" == "KIND" ]]; then
    msg "🔧 使用 Kind 集群配置: $cluster_name"
    read_kind_config; return 0
  fi

  [[ ! "$cluster_name" =~ ^C[0-9]+$ ]] && { err "❌ 无效的集群名称: $cluster_name"; exit 1; }
  msg "🔧 使用集群配置: $cluster_name"

  local bs="[${cluster_name}_BASTION]" bs_re="\\[${cluster_name}_BASTION\\]"
  local ds="[${cluster_name}_DIRECT]"  ds_re="\\[${cluster_name}_DIRECT\\]"
  local use_default=false
  grep -Fq "$bs" "$CONFIG_FILE" || use_default=true

  _read_section() {
    local section="$1" key="$2" use_def="$3" def_section="$4"
    if [[ "$use_def" == "true" ]]; then
      sed -n "/^${def_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^${key}=" | head -1 | cut -d= -f2- | tr -d ' '
    else
      sed -n "/^${section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^${key}=" | head -1 | cut -d= -f2- | tr -d ' '
    fi
  }

  # Bastion
  BASTION_HOST=$(      _read_section "$bs_re" host        "$use_default" '\[BASTION\]')
  BASTION_USER=$(      _read_section "$bs_re" user        "$use_default" '\[BASTION\]')
  BASTION_SECRET=$(    _read_section "$bs_re" secret      "$use_default" '\[BASTION\]')
  BASTION_PASS=$(      _read_section "$bs_re" pass        "$use_default" '\[BASTION\]')
  BASTION_SUDO_PASS=$( _read_section "$bs_re" sudo_pass   "$use_default" '\[BASTION\]')
  BASTION_API_SERVER=$(_read_section "$bs_re" api_server  "$use_default" '\[BASTION\]')
  BASTION_API_USER=$(  _read_section "$bs_re" api_user    "$use_default" '\[BASTION\]')
  BASTION_API_PORT=$(  _read_section "$bs_re" api_port    "$use_default" '\[BASTION\]')
  BASTION_LOCAL_PORT=$(_read_section "$bs_re" local_port  "$use_default" '\[BASTION\]')
  BASTION_KUBECONFIG=$(_read_section "$bs_re" kubeconfig  "$use_default" '\[BASTION\]')
  BASTION_BIND_ALIAS=$(_read_section "$bs_re" bind_alias  "$use_default" '\[BASTION\]')

  # Direct
  DIRECT_HOST=$(         _read_section "$ds_re" host             "$use_default" '\[DIRECT\]')
  DIRECT_USER=$(         _read_section "$ds_re" user             "$use_default" '\[DIRECT\]')
  DIRECT_SECRET=$(       _read_section "$ds_re" secret           "$use_default" '\[DIRECT\]')
  DIRECT_PASS=$(         _read_section "$ds_re" pass             "$use_default" '\[DIRECT\]')
  DIRECT_SUDO_PASS=$(    _read_section "$ds_re" sudo_pass        "$use_default" '\[DIRECT\]')
  DIRECT_LOCAL_PORT=$(   _read_section "$ds_re" local_port       "$use_default" '\[DIRECT\]')
  DIRECT_KUBECONFIG=$(   _read_section "$ds_re" kubeconfig       "$use_default" '\[DIRECT\]')
  DIRECT_BIND_ALIAS=$(   _read_section "$ds_re" bind_alias       "$use_default" '\[DIRECT\]')
  DIRECT_REMOTE_API_HOST=$(_read_section "$ds_re" remote_api_host "$use_default" '\[DIRECT\]')
  DIRECT_REMOTE_API_PORT=$(_read_section "$ds_re" remote_api_port "$use_default" '\[DIRECT\]')

  # 规范化单行
  for v in BASTION_HOST BASTION_USER BASTION_SECRET BASTION_PASS BASTION_SUDO_PASS \
            BASTION_API_SERVER BASTION_API_USER BASTION_API_PORT BASTION_LOCAL_PORT \
            BASTION_KUBECONFIG BASTION_BIND_ALIAS \
            DIRECT_HOST DIRECT_USER DIRECT_SECRET DIRECT_PASS DIRECT_SUDO_PASS \
            DIRECT_LOCAL_PORT DIRECT_KUBECONFIG DIRECT_BIND_ALIAS \
            DIRECT_REMOTE_API_HOST DIRECT_REMOTE_API_PORT; do
    printf -v "$v" '%s' "$(first_line "${!v:-}")"
  done

  BASTION_SECRET=$(expand_path "$BASTION_SECRET")
  BASTION_KUBECONFIG=$(expand_path "$BASTION_KUBECONFIG")
  DIRECT_SECRET=$(expand_path "$DIRECT_SECRET")
  DIRECT_KUBECONFIG=$(expand_path "$DIRECT_KUBECONFIG")

  GLOBAL_DEFAULT_MODE=${GLOBAL_DEFAULT_MODE:-bastion}
  GLOBAL_AUTO_STOP=${GLOBAL_AUTO_STOP:-true}
  GLOBAL_TIMEOUT=${GLOBAL_TIMEOUT:-30}
}

read_kind_config() {
  KIND_CLUSTER_NAME=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^cluster_name=" | head -1 | cut -d= -f2 | tr -d ' ')
  KIND_KUBECONFIG=$(  sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig="   | head -1 | cut -d= -f2 | tr -d ' ')
  KIND_KUBECONFIG="${KIND_KUBECONFIG/#\~/$HOME}"
  KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-kind}
  KIND_KUBECONFIG=${KIND_KUBECONFIG:-$HOME/.kube/config}
}

# ── 连接状态持久化 ────────────────────────────────────────────────────────────
save_status() {
  cat > "$STATUS_FILE" <<EOF
CURRENT_MODE=${CURRENT_MODE:-}
CURRENT_KUBECONFIG=${CURRENT_KUBECONFIG:-}
TUNNEL_PID=${TUNNEL_PID:-}
TUNNEL_API_PORT=${TUNNEL_API_PORT:-6443}
EOF
}

load_status() {
  CURRENT_MODE=${CURRENT_MODE:-""}
  CURRENT_KUBECONFIG=${CURRENT_KUBECONFIG:-""}
  TUNNEL_PID=${TUNNEL_PID:-""}
  TUNNEL_API_PORT=${TUNNEL_API_PORT:-6443}
  [[ -f "$STATUS_FILE" ]] && source "$STATUS_FILE"
}

clear_status() { rm -f "$STATUS_FILE" "$PID_FILE"; }

# ── 选择访问方式 ──────────────────────────────────────────────────────────────
select_access_mode() {
  local cluster_upper; cluster_upper=$(echo "${CLUSTER:-${GLOBAL_DEFAULT_CLUSTER:-C1}}" | tr '[:lower:]' '[:upper:]')
  if [[ "$cluster_upper" == "KIND" ]]; then
    CURRENT_MODE="kind"; success "✅ 使用 Kind 本地集群"; start_connection; return 0
  fi

  local available_modes=()
  [[ -n "${BASTION_HOST:-}" && -n "${BASTION_API_SERVER:-}" && -n "${BASTION_LOCAL_PORT:-}" ]] && available_modes+=("bastion")
  [[ -n "${DIRECT_HOST:-}"  && -n "${DIRECT_LOCAL_PORT:-}" ]]                                 && available_modes+=("direct")
  [[ ${#available_modes[@]} -eq 0 ]] && { err "❌ 没有配置任何可用的访问方式"; exit 1; }

  echo ""; msg "🔧 请选择访问方式："
  local i=1
  for mode in "${available_modes[@]}"; do
    case "$mode" in
      bastion) echo "$i) 跳板机模式 ($BASTION_HOST → $BASTION_API_SERVER)" ;;
      direct)  echo "$i) 直接访问模式 ($DIRECT_HOST)" ;;
    esac
    i=$((i + 1))
  done

  local default_choice=1
  for i in "${!available_modes[@]}"; do
    [[ "${available_modes[$i]}" == "$GLOBAL_DEFAULT_MODE" ]] && default_choice=$((i + 1)) && break
  done

  echo ""; read -rp "请选择 (直接回车使用默认): " choice || true
  local selected_mode
  if [[ -z "${choice:-}" ]]; then
    selected_mode="${available_modes[$((default_choice - 1))]}"
  elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#available_modes[@]} ]]; then
    selected_mode="${available_modes[$((choice - 1))]}"
  else
    err "❌ 无效选择"; exit 1
  fi

  CURRENT_MODE="$selected_mode"
  success "✅ 已选择: $selected_mode 模式"
  msg "🚀 自动启动连接..."
  start_connection
}

# ── 启动连接 ──────────────────────────────────────────────────────────────────
start_connection() {
  case "$CURRENT_MODE" in

    # ── Kind ──────────────────────────────────────────────────────────────────
    "kind")
      msg "🚀 使用 Kind 本地集群..."
      command -v kind >/dev/null 2>&1 || { err "❌ kind 未安装"; exit 1; }
      kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$" || {
        warn "⚠️  Kind 集群 $KIND_CLUSTER_NAME 不存在"
        msg "💡 请先运行: kind create cluster --name $KIND_CLUSTER_NAME"
        exit 1
      }
      if [[ -n "$KIND_KUBECONFIG" && "$KIND_KUBECONFIG" != "$HOME/.kube/config" ]]; then
        mkdir -p "$(dirname "$KIND_KUBECONFIG")"
        kind get kubeconfig --name "$KIND_CLUSTER_NAME" > "$KIND_KUBECONFIG"
        export KUBECONFIG="$KIND_KUBECONFIG"
      else
        export KUBECONFIG="$HOME/.kube/config"
      fi
      CURRENT_KUBECONFIG="$KUBECONFIG"
      msg "✅ 已设置环境变量: export KUBECONFIG=$CURRENT_KUBECONFIG"
      kubectl cluster-info >/dev/null 2>&1 && success "✅ Kind 集群连接正常" \
        || warn "⚠️  无法连接到 Kind 集群，请检查集群状态"
      ;;

    # ── 跳板机 ────────────────────────────────────────────────────────────────
    "bastion")
      msg "🚀 启动跳板机模式连接..."
      local bhost_ip="${BASTION_HOST%%:*}"
      local bhost_port="${BASTION_HOST##*:}"; bhost_port="${bhost_port:-22}"
      local target_ip="${BASTION_API_SERVER%%:*}"
      local api_port="${BASTION_API_PORT:-6443}"
      TUNNEL_API_PORT="$api_port"

      local ssh_opts=(); [[ -n "${BASTION_SECRET:-}" ]] && ssh_opts+=(-i "$BASTION_SECRET")
      [[ -n "${BASTION_PASS:-}" ]] && ssh_opts+=(-o PasswordAuthentication=yes)

      release_local_port "$BASTION_LOCAL_PORT"
      msg "📡 建立隧道: 本地:$BASTION_LOCAL_PORT → $BASTION_HOST → $target_ip:$api_port"
      ssh "${ssh_opts[@]}" \
        -o ConnectTimeout="$GLOBAL_TIMEOUT" \
        -o ServerAliveInterval="$SSH_ALIVE_INTERVAL" \
        -o ServerAliveCountMax="$SSH_ALIVE_COUNT" \
        -o TCPKeepAlive=yes \
        -L "$BASTION_LOCAL_PORT:$target_ip:$api_port" \
        "$BASTION_USER@$bhost_ip" -p "$bhost_port" -N &
      TUNNEL_PID=$!; echo "$TUNNEL_PID" > "$PID_FILE"

      msg "⏳ 等待隧道端口就绪..."
      if ! wait_for_tunnel_port "$BASTION_LOCAL_PORT" 20; then
        err "❌ 隧道启动失败（端口 $BASTION_LOCAL_PORT 未监听）"
        stop_connection_quiet; exit 1
      fi
      success "✅ 隧道已启动 (PID: $TUNNEL_PID)"

      # 建立 ControlMaster 加速后续 SSH 操作
      msg "📥 获取 kubeconfig..."
      setup_ssh_control_master "$bhost_ip" "$bhost_port" "$BASTION_USER" "${BASTION_SECRET:-}"
      local api_user="${BASTION_API_USER:-$BASTION_USER}"
      mkdir -p "$(dirname "$BASTION_KUBECONFIG")"
      if ! cm_ssh "$bhost_ip" "$bhost_port" "$BASTION_USER" "${BASTION_SECRET:-}" \
           "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
                -o ConnectTimeout=$GLOBAL_TIMEOUT -p ${target_ip##*:} $api_user@${target_ip%%:*} \
                'sudo cat /etc/kubernetes/admin.conf'" > "$BASTION_KUBECONFIG"; then
        err "❌ 无法从目标服务器获取 kubeconfig"
        close_ssh_control_master; stop_connection_quiet; exit 1
      fi
      close_ssh_control_master
      CURRENT_KUBECONFIG="$BASTION_KUBECONFIG"
      export KUBECONFIG="$BASTION_KUBECONFIG"
      msg "✅ 已设置环境变量: export KUBECONFIG=$BASTION_KUBECONFIG"

      if [[ "${BASTION_BIND_ALIAS:-}" == "true" ]]; then
        msg "🔗 配置域名别名并保持严格 TLS"
        setup_bind_alias "$BASTION_KUBECONFIG" "$BASTION_LOCAL_PORT" > /dev/null
      else
        msg "🔧 修改 kubeconfig 服务器地址 (回环)..."
        sed -i "s|server: https://.*:[0-9]*|server: https://127.0.0.1:$BASTION_LOCAL_PORT|g" "$BASTION_KUBECONFIG"
        sed -i '/certificate-authority-data:/d; /certificate-authority:/d' "$BASTION_KUBECONFIG"
        grep -q "insecure-skip-tls-verify" "$BASTION_KUBECONFIG" \
          || sed -i "/server: https:\/\/127.0.0.1:$BASTION_LOCAL_PORT/a\\    insecure-skip-tls-verify: true" "$BASTION_KUBECONFIG"
      fi
      ;;

    # ── 直接访问 ──────────────────────────────────────────────────────────────
    "direct")
      msg "🚀 启动直接访问模式连接..."
      local dhost_ip="${DIRECT_HOST%%:*}"
      local dhost_port="${DIRECT_HOST##*:}"; dhost_port="${dhost_port:-22}"

      local ssh_opts=(); [[ -n "${DIRECT_SECRET:-}" ]] && ssh_opts+=(-i "$DIRECT_SECRET")
      [[ -n "${DIRECT_PASS:-}" ]] && ssh_opts+=(-o PasswordAuthentication=yes)

      # 初始隧道：先用 127.0.0.1:6443，获取 kubeconfig 后再精确化
      release_local_port "$DIRECT_LOCAL_PORT"
      msg "📡 建立隧道(初始): 本地:$DIRECT_LOCAL_PORT → 127.0.0.1:6443"
      ssh "${ssh_opts[@]}" \
        -o ConnectTimeout="$GLOBAL_TIMEOUT" \
        -o ServerAliveInterval="$SSH_ALIVE_INTERVAL" \
        -o ServerAliveCountMax="$SSH_ALIVE_COUNT" \
        -o TCPKeepAlive=yes \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -L "$DIRECT_LOCAL_PORT:127.0.0.1:6443" \
        -p "$dhost_port" "$DIRECT_USER@$dhost_ip" -N &
      TUNNEL_PID=$!; echo "$TUNNEL_PID" > "$PID_FILE"

      msg "⏳ 等待隧道端口就绪..."
      if ! wait_for_tunnel_port "$DIRECT_LOCAL_PORT" 20; then
        err "❌ 隧道启动失败（端口 $DIRECT_LOCAL_PORT 未监听）"
        stop_connection_quiet; exit 1
      fi
      success "✅ 隧道已启动 (PID: $TUNNEL_PID)"

      # ControlMaster 加速后续操作
      msg "📥 获取 kubeconfig..."
      setup_ssh_control_master "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}"

      msg "🔍 测试 SSH 连接..."
      if ! cm_ssh "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}" \
           "echo 'SSH connection test successful'" >/dev/null 2>&1; then
        err "❌ SSH 连接测试失败"; close_ssh_control_master; stop_connection_quiet; exit 1
      fi

      msg "🔍 检查远程 kubeconfig 文件..."
      if ! cm_ssh "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}" \
           "sudo test -f /etc/kubernetes/admin.conf" 2>/dev/null; then
        err "❌ /etc/kubernetes/admin.conf 不存在"
        close_ssh_control_master; stop_connection_quiet; exit 1
      fi

      # 创建可读副本
      msg "📋 准备远程 kubeconfig 副本..."
      local remote_tmp="/tmp/admin.conf.$$"
      local prepare_ok=false

      if cm_ssh "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}" \
           "sudo cp -f /etc/kubernetes/admin.conf '$remote_tmp' && sudo chmod 0644 '$remote_tmp'" >/dev/null 2>&1; then
        sleep 1
        cm_ssh "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}" \
          "test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null && prepare_ok=true
      fi

      # 兜底：sudo 密码方式
      if [[ "$prepare_ok" == "false" && -n "${DIRECT_SUDO_PASS:-}" ]]; then
        msg "🔑 使用 sudo 密码..."
        local ssh_tty_opts=(-o ControlMaster=no -o "ControlPath=${CM_SOCKET:-/dev/null}"
                            -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
                            -o LogLevel=ERROR -o ConnectTimeout="$GLOBAL_TIMEOUT" -p "$dhost_port")
        [[ -n "${DIRECT_SECRET:-}" ]] && ssh_tty_opts+=(-i "$DIRECT_SECRET")
        echo "$DIRECT_SUDO_PASS" | ssh "${ssh_tty_opts[@]}" "$DIRECT_USER@$dhost_ip" \
          "sudo -S cp -f /etc/kubernetes/admin.conf '$remote_tmp' && sudo -S chmod 0644 '$remote_tmp'" \
          2>&1 | grep -vE '(Pseudo-terminal|Warning)' >/dev/null 2>&1 || true
        sleep 1
        cm_ssh "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}" \
          "test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null && prepare_ok=true
      fi

      if [[ "$prepare_ok" == "false" ]]; then
        err "❌ 无法在远程准备 kubeconfig（请确认免密 sudo 已配置）"
        close_ssh_control_master; stop_connection_quiet; exit 1
      fi

      mkdir -p "$(dirname "$DIRECT_KUBECONFIG")"
      msg "📥 下载 kubeconfig..."
      if ! cm_scp "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}" \
           "$remote_tmp" "$DIRECT_KUBECONFIG" 2>/dev/null; then
        err "❌ 无法下载 kubeconfig"
        close_ssh_control_master; stop_connection_quiet; exit 1
      fi
      cm_ssh "$dhost_ip" "$dhost_port" "$DIRECT_USER" "${DIRECT_SECRET:-}" \
        "sudo rm -f '$remote_tmp'" >/dev/null 2>&1 || true
      close_ssh_control_master

      CURRENT_KUBECONFIG="$DIRECT_KUBECONFIG"
      export KUBECONFIG="$DIRECT_KUBECONFIG"
      msg "✅ 已设置环境变量: export KUBECONFIG=$DIRECT_KUBECONFIG"
      msg "💡 提示：使用远程集群时，请保持此环境变量设置"
      msg "💡 提示：使用本地集群时，请运行: unset KUBECONFIG"

      # 解析 kubeconfig 中实际的 API server 端口
      local orig_url; orig_url=$(grep -m1 '^\s*server:' "$DIRECT_KUBECONFIG" | awk '{print $2}')
      local orig_port; orig_port=$(echo "$orig_url" | sed -E 's#https?://[^:/]+:([0-9]+).*#\1#')
      [[ -z "$orig_port" ]] && orig_port=6443
      TUNNEL_API_PORT="$orig_port"

      if [[ "${DIRECT_BIND_ALIAS:-}" == "true" ]]; then
        msg "🔗 配置域名别名并保持严格 TLS"
        # 重建精确隧道
        if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          kill "$TUNNEL_PID" 2>/dev/null || true
          wait "$TUNNEL_PID" 2>/dev/null || true
        fi
        release_local_port "$DIRECT_LOCAL_PORT"
        msg "📡 建立隧道: 本地:$DIRECT_LOCAL_PORT → 127.0.0.1:$orig_port"
        ssh "${ssh_opts[@]}" \
          -o ConnectTimeout="$GLOBAL_TIMEOUT" \
          -o ServerAliveInterval="$SSH_ALIVE_INTERVAL" \
          -o ServerAliveCountMax="$SSH_ALIVE_COUNT" \
          -o TCPKeepAlive=yes \
          -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -L "$DIRECT_LOCAL_PORT:127.0.0.1:$orig_port" \
          -p "$dhost_port" "$DIRECT_USER@$dhost_ip" -N &
        TUNNEL_PID=$!; echo "$TUNNEL_PID" > "$PID_FILE"
        wait_for_tunnel_port "$DIRECT_LOCAL_PORT" 20 \
          || warn "⚠️  隧道端口等待超时，继续..."
        setup_bind_alias "$DIRECT_KUBECONFIG" "$DIRECT_LOCAL_PORT" > /dev/null
      else
        msg "🔧 修改 kubeconfig 服务器地址 (回环)..."
        sed -i "s|server: https://.*:[0-9]*|server: https://127.0.0.1:$DIRECT_LOCAL_PORT|g" "$DIRECT_KUBECONFIG"
        sed -i '/certificate-authority-data:/d; /certificate-authority:/d' "$DIRECT_KUBECONFIG"
        grep -q "insecure-skip-tls-verify" "$DIRECT_KUBECONFIG" \
          || sed -i "/server: https:\/\/127.0.0.1:$DIRECT_LOCAL_PORT/a\\    insecure-skip-tls-verify: true" "$DIRECT_KUBECONFIG"
        msg "🔧 已配置回环模式"
      fi
      ;;
  esac

  save_status
  success "✅ 连接已建立"

  # 连接可用性验证（不阻塞）
  if check_connection_status; then
    success "✅ 连接测试通过"
  else
    warn "⚠️  连接测试失败，但隧道已建立，请稍后重试"
  fi
}

# ── 停止连接 ──────────────────────────────────────────────────────────────────
stop_connection_quiet() {
  if [[ -f "$PID_FILE" ]]; then
    local pid; pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  # 清理 /etc/hosts 中带标记的条目
  sudo sed -i '/# added_by_k8s_manager$/d' /etc/hosts 2>/dev/null || true
  clear_status
}

stop_connection() {
  [[ -z "${CURRENT_MODE:-}" ]] && { err "❌ 没有活动的连接"; return 1; }
  msg "🛑 正在停止连接..."
  stop_connection_quiet
  success "✅ 连接已停止"
}

# ── 连接状态检查 ──────────────────────────────────────────────────────────────
check_connection_status() {
  if [[ "${CURRENT_MODE:-}" == "kind" ]]; then
    KUBECONFIG="$CURRENT_KUBECONFIG" kubectl cluster-info --request-timeout=10s >/dev/null 2>&1
    return $?
  fi

  # 1. 进程检查
  [[ -z "${TUNNEL_PID:-}" ]] || ! kill -0 "$TUNNEL_PID" 2>/dev/null && return 1

  # 2. 端口检查（最快，避免 kubectl 挂起）
  local port; port=$(_current_local_port)
  if [[ -n "$port" ]] && ! port_is_listening "$port"; then
    return 1
  fi

  # 3. kubectl 检查（带超时，最多重试 3 次）
  local retry=0
  while [[ $retry -lt 3 ]]; do
    if KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
      return 0
    fi
    retry=$((retry + 1))
    [[ $retry -lt 3 ]] && sleep 2
  done
  return 1
}

# ── 连接信息展示 ──────────────────────────────────────────────────────────────
show_connection_info() {
  echo ""; msg "🔗 连接已建立，可在其他终端窗口中使用："
  echo ""; msg "💡 在其他终端窗口中运行以下命令："
  echo "export KUBECONFIG=$CURRENT_KUBECONFIG"
  echo ""; msg "💡 然后就可以使用 kubectl 命令操作集群："
  echo "kubectl get nodes"; echo "kubectl get pods -A"; echo ""
  msg "💡 提示：可以不关闭此窗口，在其他终端窗口中使用连接"; echo ""
  read -rp "按回车键进入操作菜单..." || true
}

show_status() {
  [[ -z "${CURRENT_MODE:-}" ]] && { msg "📊 当前状态: 未连接"; return; }
  msg "📊 当前状态:"
  msg "  访问方式: $CURRENT_MODE"
  msg "  Kubeconfig: $CURRENT_KUBECONFIG"
  case "$CURRENT_MODE" in
    kind)
      kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$" \
        && msg "  集群状态: 运行中" || msg "  集群状态: 不存在"
      ;;
    bastion|direct)
      local port; port=$(_current_local_port)
      if kill -0 "${TUNNEL_PID:-0}" 2>/dev/null && port_is_listening "$port"; then
        msg "  隧道状态: 运行中 (PID: $TUNNEL_PID, 端口: $port)"
      else
        msg "  隧道状态: 未运行"
      fi
      ;;
  esac
}

# ── 端口检查 ──────────────────────────────────────────────────────────────────
test_connection() {
  [[ -z "${CURRENT_MODE:-}" ]] && { err "❌ 没有活动的连接"; return 1; }
  msg "🧪 测试连接..."
  if check_connection_status; then
    success "✅ 连接正常"
    KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes -o wide
  else
    err "❌ 连接失败"
    return 1
  fi
}

check_ports() {
  [[ -z "${CURRENT_MODE:-}" ]] && { err "❌ 没有活动的连接"; return 1; }
  msg "🔍 开始端口检查..."
  warn "⚠️  注意：云企业网架构下 Worker 节点端口显示关闭是正常的"
  local port_check_cmd='
    echo "=== Master 节点端口 ==="
    for port in 6443 2379 2380 10250 10257 10259 22; do
      if (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null; then echo "✅ $port 开放"
      else echo "❌ $port 关闭"; fi
    done'

  case "$CURRENT_MODE" in
    bastion)
      local bhost_ip="${BASTION_HOST%%:*}"; local bhost_port="${BASTION_HOST##*:}"; bhost_port="${bhost_port:-22}"
      ssh -o ConnectTimeout="$GLOBAL_TIMEOUT" ${BASTION_SECRET:+-i "$BASTION_SECRET"} \
          -p "$bhost_port" "$BASTION_USER@$bhost_ip" "$port_check_cmd"
      ;;
    direct)
      local dhost_ip="${DIRECT_HOST%%:*}"; local dhost_port="${DIRECT_HOST##*:}"; dhost_port="${dhost_port:-22}"
      ssh -o ConnectTimeout="$GLOBAL_TIMEOUT" ${DIRECT_SECRET:+-i "$DIRECT_SECRET"} \
          -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -p "$dhost_port" "$DIRECT_USER@$dhost_ip" "$port_check_cmd"
      ;;
  esac
}

# ── 操作菜单 ──────────────────────────────────────────────────────────────────
operation_menu() {
  [[ -z "${CURRENT_MODE:-}" ]] && { err "❌ 没有活动的连接"; return 1; }

  while true; do
    # 对远程模式检查隧道（自动重连）
    if [[ "$CURRENT_MODE" != "kind" ]]; then
      if ! ensure_tunnel; then
        err "❌ 连接无法恢复，退出菜单"
        break
      fi
    fi

    echo ""; msg "🔧 Kubernetes 操作菜单 (当前: $CURRENT_MODE)"
    msg "1) 查看节点"      ; msg "2) 查看 Pod"
    msg "3) 查看服务"      ; msg "4) 查看命名空间"
    msg "5) 查看集群信息"  ; msg "6) 查看部署"
    msg "7) 查看配置映射"  ; msg "8) 查看密钥"
    msg "9) 测试连接"      ; msg "10) 检查端口"
    msg "q) 退出"

    if ! read -rp "请选择: " choice; then
      msg "🛑 用户中断"; break
    fi

    case "${choice:-}" in
      1)  run_kubectl_cmd kubectl get nodes -o wide ;;
      2)  run_kubectl_cmd kubectl get pods -A ;;
      3)  run_kubectl_cmd kubectl get svc -A ;;
      4)  run_kubectl_cmd kubectl get namespaces ;;
      5)  run_kubectl_cmd kubectl cluster-info ;;
      6)  run_kubectl_cmd kubectl get deployments -A ;;
      7)  run_kubectl_cmd kubectl get configmaps -A ;;
      8)  run_kubectl_cmd kubectl get secrets -A ;;
      9)  test_connection ;;
      10) check_ports ;;
      q|quit|exit) msg "🛑 退出操作菜单"; break ;;
      *)  warn "❌ 无效选择" ;;
    esac

    echo ""; read -rp "按回车键继续..." || true
  done
}

# ── 初始化 & 主函数 ───────────────────────────────────────────────────────────
initialize_environment() {
  [[ -d "$HOME/.kube" ]] || mkdir -p "$HOME/.kube"
  check_and_install_kubectl
}

main() {
  unified_parse_cluster_arg "$@"
  command -v ssh >/dev/null 2>&1 || { err "❌ 未找到 ssh 命令"; exit 1; }
  initialize_environment
  read_config
  load_status

  echo ""; msg "🚀 Kubernetes 集群管理工具"
  msg "配置文件: $CONFIG_FILE"
  [[ -n "${CLUSTER:-}" ]] && msg "🎯 当前集群配置: ${CLUSTER}"
  echo ""

  select_access_mode
  show_connection_info
  operation_menu
}

main "$@"
