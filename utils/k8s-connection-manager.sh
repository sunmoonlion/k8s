#!/bin/bash

# 集群参数解析（轻量，无连接副作用）
# 注意：本脚本位于 k8s/utils 下，不依赖 PROJECT_ROOT；用脚本路径反推 k8s 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$K8S_ROOT_DIR/utils/cluster-arg-parser.sh"


# Kubernetes 集群管理脚本
# 支持跳板机模式和直接访问模式

set -euo pipefail

# 脚本目录
# SCRIPT_DIR 已在上方初始化，保留此处逻辑兼容
SCRIPT_DIR="${SCRIPT_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"}"
CONFIG_FILE="$(dirname "$0")/k8s-admin.conf"
STATUS_FILE="$SCRIPT_DIR/.k8s-status"
PID_FILE="$SCRIPT_DIR/.k8s-tunnel.pid"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 消息函数
msg() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err() { echo -e "${RED}❌ $1${NC}"; }

# SSH命令构建函数
build_ssh_cmd() {
  local host="$1"
  local port="$2"
  local user="$3"
  local secret="$4"
  local extra_args="$5"
  
  local ssh_cmd="ssh"
  if [[ -n "$secret" ]]; then
    ssh_cmd="$ssh_cmd -i $secret"
  fi
  ssh_cmd="$ssh_cmd -o ConnectTimeout=$GLOBAL_TIMEOUT -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes"
  if [[ -n "$extra_args" ]]; then
    ssh_cmd="$ssh_cmd $extra_args"
  fi
  ssh_cmd="$ssh_cmd -p $port $user@$host"
  
  echo "$ssh_cmd"
}

# 清理函数
cleanup() {
  msg "🛑 正在清理资源..."
  # 只有在有有效PID文件时才清理，避免误杀
  if [[ -f "$PID_FILE" ]]; then
    local saved_pid
    saved_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$saved_pid" && -e "/proc/$saved_pid" ]]; then
      stop_connection_quiet
    fi
  fi
  # 清理环境变量
  unset KUBECONFIG
  msg "✅ 已清理 KUBECONFIG 环境变量"
  msg "💡 提示：如需重新连接，请重新运行脚本"
  exit 0
}

# 设置信号处理 - 任何退出都清理
trap 'cleanup' EXIT INT TERM

# 检查并安装 kubectl
check_and_install_kubectl(){
  # 多种方式检测 kubectl
  local kubectl_found=false
  
  # 方法1: command -v
  if command -v kubectl >/dev/null 2>&1; then
    kubectl_found=true
  fi
  
  # 方法2: which
  if [[ "$kubectl_found" == "false" ]] && which kubectl >/dev/null 2>&1; then
    kubectl_found=true
  fi
  
  # 方法3: 直接检查常见路径
  if [[ "$kubectl_found" == "false" ]]; then
    for path in /snap/bin/kubectl /usr/local/bin/kubectl /usr/bin/kubectl; do
      if [[ -x "$path" ]]; then
        kubectl_found=true
        break
      fi
    done
  fi
  
  if [[ "$kubectl_found" == "false" ]]; then
    msg "🔧 检测到 kubectl 未安装，正在自动安装..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      if command -v apt-get >/dev/null 2>&1; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
      elif command -v yum >/dev/null 2>&1; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
      else
        err "❌ 不支持的操作系统包管理器，请手动安装 kubectl"
        exit 1
      fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      if command -v brew >/dev/null 2>&1; then
        brew install kubectl
      else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
      fi
    else
      err "❌ 不支持的操作系统，请手动安装 kubectl"
      exit 1
    fi
    success "✅ kubectl 安装完成"
  else
    msg "ℹ️  kubectl 已安装: $(kubectl version --client 2>/dev/null | head -1 || echo '版本信息获取失败')"
  fi
}

# 读取配置文件
read_config(){
  if [[ ! -f "$CONFIG_FILE" ]]; then
    err "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
  fi
  
  # 读取全局配置
  GLOBAL_DEFAULT_MODE=$(sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^default_mode=" | cut -d'=' -f2 | tr -d ' ')
  GLOBAL_AUTO_STOP=$(sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^auto_stop=" | cut -d'=' -f2 | tr -d ' ')
  GLOBAL_TIMEOUT=$(sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^timeout=" | cut -d'=' -f2 | tr -d ' ')
  GLOBAL_DEFAULT_CLUSTER=$(sed -n '/\[GLOBAL\]/,/^\[/p' "$CONFIG_FILE" | grep "^default_cluster=" | cut -d'=' -f2 | tr -d ' ')
  
  # 确定使用的集群（优先级：环境变量 > 配置文件默认值）
  local cluster_name="${CLUSTER:-${GLOBAL_DEFAULT_CLUSTER:-C1}}"
  local cluster_name_upper
  cluster_name_upper=$(echo "$cluster_name" | tr '[:lower:]' '[:upper:]')
  
  # 如果目标是 KIND，直接返回 Kind 配置
  if [[ "$cluster_name_upper" == "KIND" ]]; then
    msg "🔧 使用 Kind 集群配置: $cluster_name"
    read_kind_config
    return 0
  fi
  
  # 验证集群名称格式：必须是 C{数字} 格式（如 C1, C2, C3, C10 等）
  # 支持不连续的集群编号（如只有 C1 和 C3，没有 C2）
  if [[ ! "$cluster_name" =~ ^C[0-9]+$ ]]; then
    err "❌ 无效的集群名称: $cluster_name (格式必须为 C{数字}，如 C1, C2, C3 等)"
    exit 1
  fi
  
  msg "🔧 使用集群配置: $cluster_name"
  
  # 根据集群名称确定配置段
  local bastion_section_literal="[${cluster_name}_BASTION]"
  local direct_section_literal="[${cluster_name}_DIRECT]"
  local bastion_section="\\[${cluster_name}_BASTION\\]"
  local direct_section="\\[${cluster_name}_DIRECT\\]"
  
  # 检查集群特定配置是否存在，如果不存在则使用默认配置段
  local use_default=false
  # 使用固定字符串匹配，避免 [] 被当作字符类
  if ! grep -Fq "${bastion_section_literal}" "$CONFIG_FILE"; then
    warn "⚠️  未找到 ${bastion_section_literal}，使用默认 [BASTION] 配置"
    use_default=true
  fi
  
  # 展开路径中的 ~ 和环境变量
  expand_path() {
    local path="$1"
    # 展开 ~ 为 $HOME
    path="${path/#\~/$HOME}"
    # 展开环境变量
    path=$(eval echo "$path")
    echo "$path"
  }

  # 仅取第一行，防止值中包含换行导致显示异常
  first_line() {
    local v="$1"
    # 删除可能的回车并截断到第一行
    v=${v//$'\r'/}
    printf '%s' "${v%%$'\n'*}"
  }
  
  # 读取跳板机模式配置
  if [[ "$use_default" == "true" ]]; then
    BASTION_HOST=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_USER=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_SECRET=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_PASS=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_SUDO_PASS=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_API_SERVER=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^api_server=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_API_USER=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^api_user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_API_PORT=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_LOCAL_PORT=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_KUBECONFIG=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_BIND_ALIAS=$(sed -n '/^\[BASTION\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  else
    BASTION_HOST=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_USER=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_SECRET=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_PASS=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_SUDO_PASS=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_API_SERVER=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^api_server=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_API_USER=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^api_user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_API_PORT=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_LOCAL_PORT=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_KUBECONFIG=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    BASTION_BIND_ALIAS=$(sed -n "/^${bastion_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  fi

  # 规范化为单行值
  BASTION_HOST=$(first_line "$BASTION_HOST")
  BASTION_USER=$(first_line "$BASTION_USER")
  BASTION_SECRET=$(first_line "$BASTION_SECRET")
  BASTION_PASS=$(first_line "$BASTION_PASS")
  BASTION_SUDO_PASS=$(first_line "$BASTION_SUDO_PASS")
  BASTION_API_SERVER=$(first_line "$BASTION_API_SERVER")
  BASTION_API_USER=$(first_line "$BASTION_API_USER")
  BASTION_API_PORT=$(first_line "$BASTION_API_PORT")
  BASTION_LOCAL_PORT=$(first_line "$BASTION_LOCAL_PORT")
  BASTION_KUBECONFIG=$(first_line "$BASTION_KUBECONFIG")
  BASTION_BIND_ALIAS=$(first_line "$BASTION_BIND_ALIAS")
  
  # 读取直接访问模式配置
  if [[ "$use_default" == "true" ]]; then
    DIRECT_HOST=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_USER=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_SECRET=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_PASS=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_SUDO_PASS=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_LOCAL_PORT=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_KUBECONFIG=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_BIND_ALIAS=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_REMOTE_API_HOST=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^remote_api_host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_REMOTE_API_PORT=$(sed -n '/^\[DIRECT\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^remote_api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  else
    DIRECT_HOST=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_USER=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^user=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_SECRET=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^secret=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_PASS=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_SUDO_PASS=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^sudo_pass=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_LOCAL_PORT=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^local_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_KUBECONFIG=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_BIND_ALIAS=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^bind_alias=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_REMOTE_API_HOST=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^remote_api_host=" | head -1 | cut -d'=' -f2 | tr -d ' ')
    DIRECT_REMOTE_API_PORT=$(sed -n "/^${direct_section}$/,/^\[[A-Z]/p" "$CONFIG_FILE" | grep "^remote_api_port=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  fi

  # 规范化为单行值
  DIRECT_HOST=$(first_line "$DIRECT_HOST")
  DIRECT_USER=$(first_line "$DIRECT_USER")
  DIRECT_SECRET=$(first_line "$DIRECT_SECRET")
  DIRECT_PASS=$(first_line "$DIRECT_PASS")
  DIRECT_SUDO_PASS=$(first_line "$DIRECT_SUDO_PASS")
  DIRECT_LOCAL_PORT=$(first_line "$DIRECT_LOCAL_PORT")
  DIRECT_KUBECONFIG=$(first_line "$DIRECT_KUBECONFIG")
  DIRECT_BIND_ALIAS=$(first_line "$DIRECT_BIND_ALIAS")
  DIRECT_REMOTE_API_HOST=$(first_line "$DIRECT_REMOTE_API_HOST")
  DIRECT_REMOTE_API_PORT=$(first_line "$DIRECT_REMOTE_API_PORT")
  
  # 展开所有路径配置
  BASTION_SECRET=$(expand_path "$BASTION_SECRET")
  BASTION_KUBECONFIG=$(expand_path "$BASTION_KUBECONFIG")
  DIRECT_SECRET=$(expand_path "$DIRECT_SECRET")
  DIRECT_KUBECONFIG=$(expand_path "$DIRECT_KUBECONFIG")
  
  # 设置默认值
  GLOBAL_DEFAULT_MODE=${GLOBAL_DEFAULT_MODE:-bastion}
  GLOBAL_AUTO_STOP=${GLOBAL_AUTO_STOP:-true}
  GLOBAL_TIMEOUT=${GLOBAL_TIMEOUT:-30}
}

# 读取 kind 配置
read_kind_config() {
  KIND_CLUSTER_NAME=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^cluster_name=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  KIND_KUBECONFIG=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  
  # 展开路径
  KIND_KUBECONFIG="${KIND_KUBECONFIG/#\~/$HOME}"
  
  # 设置默认值
  KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-kind}
  KIND_KUBECONFIG=${KIND_KUBECONFIG:-$HOME/.kube/config}
}

# 保存连接状态
save_status(){
  cat >"$STATUS_FILE" <<EOF
CURRENT_MODE=${CURRENT_MODE:-}
CURRENT_KUBECONFIG=${CURRENT_KUBECONFIG:-}
TUNNEL_PID=${TUNNEL_PID:-}
EOF
}

# 加载连接状态
load_status(){
  # 初始化变量（只有在未定义时才初始化）
  CURRENT_MODE=${CURRENT_MODE:-""}
  CURRENT_KUBECONFIG=${CURRENT_KUBECONFIG:-""}
  TUNNEL_PID=${TUNNEL_PID:-""}
  
  if [[ -f "$STATUS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATUS_FILE"
  fi
}

# 清除连接状态
clear_status(){
  rm -f "$STATUS_FILE" "$PID_FILE"
}

# 选择访问方式
select_access_mode(){
  # 如果当前目标集群是 KIND（命令行/环境变量/default_cluster），直接使用 Kind
  local cluster_name="${CLUSTER:-${GLOBAL_DEFAULT_CLUSTER:-C1}}"
  local cluster_upper
  cluster_upper=$(echo "$cluster_name" | tr '[:lower:]' '[:upper:]')
  if [[ "$cluster_upper" == "KIND" ]]; then
    CURRENT_MODE="kind"
    success "✅ 使用 Kind 本地集群"
    start_connection
    return 0
  fi
  
  local available_modes=()
  
  # 检查跳板机模式配置是否完整
  if [[ -n "$BASTION_HOST" ]] && [[ -n "$BASTION_API_SERVER" ]] && [[ -n "$BASTION_LOCAL_PORT" ]]; then
    available_modes+=("bastion")
  fi
  
  # 检查直接访问模式配置是否完整
  if [[ -n "$DIRECT_HOST" ]] && [[ -n "$DIRECT_LOCAL_PORT" ]]; then
    available_modes+=("direct")
  fi
  

  
  if [[ ${#available_modes[@]} -eq 0 ]]; then
    err "❌ 没有配置任何可用的访问方式，请检查配置文件"
    exit 1
  fi
  
  echo ""
  msg "🔧 请选择访问方式："
  
  local i=1
  for mode in "${available_modes[@]}"; do
    case "$mode" in
      "bastion")
        echo "$i) 跳板机模式 ($BASTION_HOST → $BASTION_API_SERVER)"
        ;;
      "direct")
        echo "$i) 直接访问模式 ($DIRECT_HOST)"
        ;;

    esac
    i=$((i+1))  # 使用显式赋值，避免 ((i++)) 在某些情况下导致的问题
  done
  
  # 确定默认选择
  local default_choice=1
  for i in "${!available_modes[@]}"; do
    if [[ "${available_modes[$i]}" == "$GLOBAL_DEFAULT_MODE" ]]; then
      default_choice=$((i+1))
      break
    fi
  done
  
  echo ""
  read -rp "请选择 (直接回车使用默认): " choice || true
  
  # 处理选择
  local selected_mode
  if [[ -z "${choice:-}" ]]; then
    selected_mode="${available_modes[$((default_choice-1))]}"
  else
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#available_modes[@]} ]]; then
      selected_mode="${available_modes[$((choice-1))]}"
    else
      err "❌ 无效选择"
      exit 1
    fi
  fi
  
  CURRENT_MODE="$selected_mode"
  success "✅ 已选择: $selected_mode 模式"
  
  # 自动启动连接
  msg "🚀 自动启动连接..."
  start_connection
}

# 启动连接
start_connection(){
  
  case "$CURRENT_MODE" in
    "kind")
      msg "🚀 使用 Kind 本地集群..."
      
      # 检查 kind 是否安装
      if ! command -v kind >/dev/null 2>&1; then
        err "❌ kind 未安装"
        msg "💡 安装方法: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
      fi
      
      # 检查集群是否存在
      if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        warn "⚠️  Kind 集群 $KIND_CLUSTER_NAME 不存在"
        msg "💡 请先运行: cd ../sunmoonai/kind-infrastructure && ./kind-up.sh"
        msg "💡 或手动创建: kind create cluster --name $KIND_CLUSTER_NAME"
        exit 1
      fi
      
      # 设置 kubeconfig
      if [[ -n "$KIND_KUBECONFIG" && "$KIND_KUBECONFIG" != "$HOME/.kube/config" ]]; then
        # 如果指定了单独的 kubeconfig 文件，导出到该文件
        mkdir -p "$(dirname "$KIND_KUBECONFIG")"
        kind get kubeconfig --name "$KIND_CLUSTER_NAME" > "$KIND_KUBECONFIG"
        export KUBECONFIG="$KIND_KUBECONFIG"
        CURRENT_KUBECONFIG="$KIND_KUBECONFIG"
      else
        # 使用默认的 ~/.kube/config（kind 会自动配置）
        export KUBECONFIG="$HOME/.kube/config"
        CURRENT_KUBECONFIG="$HOME/.kube/config"
      fi
      
      msg "✅ 已设置环境变量: export KUBECONFIG=$CURRENT_KUBECONFIG"
      msg "💡 Kind 集群已就绪，可以直接使用 kubectl 命令"
      
      # 验证连接
      if kubectl cluster-info >/dev/null 2>&1; then
        success "✅ Kind 集群连接正常"
        kubectl cluster-info
      else
        warn "⚠️  无法连接到 Kind 集群，请检查集群状态"
      fi
      ;;
      
    "bastion")
      msg "🚀 启动跳板机模式连接..."
      
      # 构建 SSH 命令参数
      local ssh_args=""
      if [[ -n "$BASTION_SECRET" ]]; then
        ssh_args="-i $BASTION_SECRET"
      fi
      if [[ -n "$BASTION_PASS" ]]; then
        ssh_args="$ssh_args -o PasswordAuthentication=yes"
      fi
      
      # 启动隧道
      msg "📡 建立隧道: 本地:$BASTION_LOCAL_PORT → $BASTION_HOST → $BASTION_API_SERVER:6443"
      # 解析跳板机主机和端口
      local bastion_host_ip
      local bastion_host_port
      bastion_host_ip=$(echo "$BASTION_HOST" | cut -d':' -f1)
      bastion_host_port=$(echo "$BASTION_HOST" | cut -d':' -f2)
      bastion_host_port=${bastion_host_port:-22}
      
      # 解析目标服务器信息
      local target_host_ip
      local target_host_port
      target_host_ip=$(echo "$BASTION_API_SERVER" | cut -d':' -f1)
      target_host_port=$(echo "$BASTION_API_SERVER" | cut -d':' -f2)
      target_host_port=${target_host_port:-22}
      
      # 隧道转发到目标服务器的Kubernetes API端口
      local api_port="${BASTION_API_PORT:-6443}"
      ssh $ssh_args -o ConnectTimeout="$GLOBAL_TIMEOUT" -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -L "$BASTION_LOCAL_PORT:$target_host_ip:$api_port" "$BASTION_USER@$bastion_host_ip" -p "$bastion_host_port" -N &
      TUNNEL_PID=$!
      echo "$TUNNEL_PID" > "$PID_FILE"
      
      # 等待隧道建立
      sleep 2
      if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        err "❌ 隧道启动失败"
        exit 1
      fi
      
      success "✅ 隧道已启动 (PID: $TUNNEL_PID)"
      
      # 获取 kubeconfig
      msg "📥 获取 kubeconfig..."
      # 手动获取 kubeconfig
      local remote_tmp="/tmp/admin.conf.$$"
      local ssh_base=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout="$GLOBAL_TIMEOUT" -p "$bastion_host_port")
      local scp_base=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout="$GLOBAL_TIMEOUT" -P "$bastion_host_port")
      
      # 构建 SSH 和 SCP 命令
      local ssh_cmd
      local scp_cmd
      if [[ -n "$BASTION_SECRET" ]]; then
        ssh_cmd=(ssh -i "$BASTION_SECRET" "${ssh_base[@]}" "$BASTION_USER@$bastion_host_ip")
        scp_cmd=(scp -i "$BASTION_SECRET" "${scp_base[@]}")
      else
        ssh_cmd=(ssh "${ssh_base[@]}" "$BASTION_USER@$bastion_host_ip")
        scp_cmd=(scp "${scp_base[@]}")
      fi
      
      # 通过跳板机直接获取 kubeconfig
      # target_host_ip 和 target_host_port 已在上面定义
      
      # 确保本地 kubeconfig 目录存在
      mkdir -p "$(dirname "$BASTION_KUBECONFIG")"
      
      # 通过跳板机SSH到目标服务器获取 kubeconfig
      local api_user="${BASTION_API_USER:-$BASTION_USER}"
      if ! "${ssh_cmd[@]}" "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=$GLOBAL_TIMEOUT -p $target_host_port $api_user@$target_host_ip 'sudo cat /etc/kubernetes/admin.conf'" > "$BASTION_KUBECONFIG"; then
        err "❌ 无法从目标服务器获取 kubeconfig"
        stop_connection_quiet
        exit 1
      fi
      
      CURRENT_KUBECONFIG="$BASTION_KUBECONFIG"
      
      # 设置环境变量，使 kubectl 使用远程集群配置
      export KUBECONFIG="$BASTION_KUBECONFIG"
      msg "✅ 已设置环境变量: export KUBECONFIG=$BASTION_KUBECONFIG"
      msg "💡 提示：使用远程集群时，请保持此环境变量设置"
      msg "💡 提示：使用本地集群时，请运行: unset KUBECONFIG"
      
      # 绑定别名
      if [[ "$BASTION_BIND_ALIAS" == "true" ]]; then
        msg "🔗 配置别名并保持严格 TLS..."
        
        # 动态解析证书SAN，选择有效的域名
        local cert_tmp=$(mktemp)
        local valid_domain=""
        
        # 从kubeconfig中提取证书并解析SAN
        if command -v yq >/dev/null 2>&1; then
          # 使用yq提取证书数据
          local cert_data
          cert_data=$(yq e '.clusters[0].cluster["certificate-authority-data"]' "$BASTION_KUBECONFIG" 2>/dev/null || echo "")
          if [[ -n "$cert_data" ]]; then
            echo "$cert_data" | base64 -d > "$cert_tmp" 2>/dev/null
            valid_domain=$(openssl x509 -in "$cert_tmp" -noout -text 2>/dev/null | grep -oP 'DNS:[^,\s]+' | head -n1 | cut -d: -f2)
          fi
        fi
        
        # 如果yq不可用或解析失败，尝试使用grep直接解析
        if [[ -z "$valid_domain" ]]; then
          valid_domain=$(grep -oP 'certificate-authority-data:\s*\K[^[:space:]]+' "$BASTION_KUBECONFIG" | head -n1 | base64 -d 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -oP 'DNS:[^,\s]+' | head -n1 | cut -d: -f2)
        fi
        
        # 如果还是失败，使用默认域名
        if [[ -z "$valid_domain" ]]; then
          valid_domain="kubernetes"
          warn "⚠️  无法解析证书SAN，使用默认域名: $valid_domain"
        fi
        
        rm -f "$cert_tmp"
        
        # hosts 添加域名别名（带标记）
        if ! grep -q "^127.0.0.1[[:space:]]\+$valid_domain[[:space:]]\+# added_by_k8s_manager$" /etc/hosts 2>/dev/null; then
          echo "127.0.0.1 $valid_domain # added_by_k8s_manager" | sudo tee -a /etc/hosts >/dev/null
        fi
        
        # 修改 kubeconfig 使用有效域名
        msg "🔧 修改 kubeconfig 服务器地址..."
        sed -i "s|server: https://.*:6443|server: https://$valid_domain:$BASTION_LOCAL_PORT|g" "$BASTION_KUBECONFIG"
        
        msg "🔧 已配置严格 TLS 模式"
      else
        # 回环方案：将 server 改为 127.0.0.1:PORT，并添加 insecure，删除证书字段
        msg "🔧 修改 kubeconfig 服务器地址 (回环) ..."
        sed -i "s|server: https://.*:6443|server: https://127.0.0.1:$BASTION_LOCAL_PORT|g" "$BASTION_KUBECONFIG"
        sed -i '/certificate-authority-data:/d' "$BASTION_KUBECONFIG"
        sed -i '/certificate-authority:/d' "$BASTION_KUBECONFIG"
        sed -i "/server: https:\/\/127.0.0.1:$BASTION_LOCAL_PORT/a\\    insecure-skip-tls-verify: true" "$BASTION_KUBECONFIG"
        
        msg "🔧 已配置回环模式并应用 TLS 设置"
      fi
      ;;
      
    "direct")
      msg "🚀 启动直接访问模式连接..."
      
      # 解析主机和端口
      local direct_host_ip
      local direct_host_port
      direct_host_ip=$(echo "$DIRECT_HOST" | cut -d':' -f1)
      direct_host_port=$(echo "$DIRECT_HOST" | cut -d':' -f2)
      direct_host_port=${direct_host_port:-22}
      
      # 构建 SSH 命令参数
      local ssh_args=()
      if [[ -n "$DIRECT_SECRET" ]]; then
        ssh_args+=("-i" "$DIRECT_SECRET")
      fi
      if [[ -n "$DIRECT_PASS" ]]; then
        ssh_args+=("-o" "PasswordAuthentication=yes")
      fi
      
      # 启动隧道（先清理可能残留的转发，先用回环目标，稍后根据 kubeconfig 再调整）
      pkill -f "ssh.*$DIRECT_LOCAL_PORT:127.0.0.1:6443" >/dev/null 2>&1 || true
      msg "📡 建立隧道(初始): 本地:$DIRECT_LOCAL_PORT → 127.0.0.1:6443"
      ssh "${ssh_args[@]}" -o ConnectTimeout="$GLOBAL_TIMEOUT" -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -L "$DIRECT_LOCAL_PORT:127.0.0.1:6443" -p "$direct_host_port" "$DIRECT_USER@$direct_host_ip" -N &
      TUNNEL_PID=$!
      echo "$TUNNEL_PID" > "$PID_FILE"
      
      # 等待隧道建立
      sleep 2
      if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        err "❌ 隧道启动失败"
        exit 1
      fi
      
      success "✅ 隧道已启动 (PID: $TUNNEL_PID)"
      
      # 获取 kubeconfig
      msg "📥 获取 kubeconfig..."
      # 手动获取 kubeconfig
      local remote_tmp="/tmp/admin.conf.$$"
      local ssh_base=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout="$GLOBAL_TIMEOUT" -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -p "$direct_host_port")
      local scp_base=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout="$GLOBAL_TIMEOUT" -P "$direct_host_port")
      
      # 构建 SSH 和 SCP 命令
      local ssh_cmd
      local ssh_cmd_tty
      local scp_cmd
      if [[ -n "$DIRECT_SECRET" ]]; then
        ssh_cmd=(ssh -i "$DIRECT_SECRET" "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        ssh_cmd_tty=(ssh -t -i "$DIRECT_SECRET" "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        scp_cmd=(scp -i "$DIRECT_SECRET" "${scp_base[@]}")
      else
        ssh_cmd=(ssh "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        ssh_cmd_tty=(ssh -t "${ssh_base[@]}" "$DIRECT_USER@$direct_host_ip")
        scp_cmd=(scp "${scp_base[@]}")
      fi
      
      # 首先测试 SSH 连接是否正常
      msg "🔍 测试 SSH 连接..."
      if ! "${ssh_cmd[@]}" "echo 'SSH connection test successful'" >/dev/null 2>&1; then
        err "❌ SSH 连接测试失败，请检查网络连接和认证配置"
        stop_connection_quiet
        exit 1
      fi
      
      # 检查原始文件是否存在（使用 sudo，因为文件通常需要 root 权限）
      msg "🔍 检查远程 kubeconfig 文件..."
      if ! "${ssh_cmd[@]}" "sudo test -f /etc/kubernetes/admin.conf" 2>/dev/null; then
        err "❌ /etc/kubernetes/admin.conf 不存在或无法访问"
        err "💡 提示：请确保远程服务器上已安装 Kubernetes 并初始化了集群"
        stop_connection_quiet
        exit 1
      fi
      
      # 创建可读的临时副本
      msg "📋 准备远程 kubeconfig 副本..."
      local prepare_success=false
      
      # 方法1: 尝试使用 sudo（免密 sudo，不需要 -t）
      msg "🔑 尝试使用 sudo..."
      if "${ssh_cmd[@]}" "sudo cp -f /etc/kubernetes/admin.conf '$remote_tmp' && sudo chmod 0644 '$remote_tmp'" >/dev/null 2>&1; then
        # 检查文件是否成功创建
        sleep 1
        if "${ssh_cmd[@]}" "test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null; then
          prepare_success=true
        fi
      fi
      
      # 方法2: 如果方法1失败且配置了 sudo 密码，尝试使用密码（需要 -t）
      if [[ "$prepare_success" == "false" && -n "$DIRECT_SUDO_PASS" ]]; then
        msg "🔑 使用 sudo 密码进行认证..."
        if echo "$DIRECT_SUDO_PASS" | "${ssh_cmd_tty[@]}" "sudo -S cp -f /etc/kubernetes/admin.conf '$remote_tmp' && sudo -S chmod 0644 '$remote_tmp'" 2>&1 | grep -vE "(Pseudo-terminal|Warning)" >/dev/null 2>&1; then
          sleep 1
          if "${ssh_cmd[@]}" "test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null; then
            prepare_success=true
          fi
        fi
      fi
      
      # 方法3: 如果 sudo 失败，尝试直接复制（如果文件权限允许）
      if [[ "$prepare_success" == "false" ]]; then
        msg "🔍 尝试直接复制（不使用 sudo）..."
        if "${ssh_cmd[@]}" "cp -f /etc/kubernetes/admin.conf '$remote_tmp' 2>/dev/null && chmod 0644 '$remote_tmp' 2>/dev/null && test -f '$remote_tmp' && test -r '$remote_tmp'" 2>/dev/null; then
          prepare_success=true
        fi
      fi
      
      if [[ "$prepare_success" == "false" ]]; then
        err "❌ 无法在远程服务器上准备 kubeconfig"
        err "💡 提示：请确保配置了免密 sudo，或检查 /etc/kubernetes/admin.conf 的文件权限"
        err "💡 提示：可以在远程服务器运行: sudo chmod 644 /etc/kubernetes/admin.conf"
        stop_connection_quiet
        exit 1
      fi
      
      # 验证远程文件存在
      if ! "${ssh_cmd[@]}" "test -s '$remote_tmp'" 2>/dev/null; then
        err "❌ 远程 kubeconfig 文件不存在或为空"
        stop_connection_quiet
        exit 1
      fi
      
      # 确保本地 kubeconfig 目录存在
      mkdir -p "$(dirname "$DIRECT_KUBECONFIG")"
      
      # 下载 kubeconfig
      msg "📥 下载 kubeconfig..."
      if ! "${scp_cmd[@]}" -P "$direct_host_port" "$DIRECT_USER@$direct_host_ip:$remote_tmp" "$DIRECT_KUBECONFIG" 2>/dev/null; then
        err "❌ 无法下载 kubeconfig"
        stop_connection_quiet
        exit 1
      fi
      
      # 清理远程临时文件
      "${ssh_cmd[@]}" "sudo rm -f '$remote_tmp'" >/dev/null 2>&1 || true
      
      CURRENT_KUBECONFIG="$DIRECT_KUBECONFIG"
      
      # 设置环境变量，使 kubectl 使用远程集群配置
      export KUBECONFIG="$DIRECT_KUBECONFIG"
      msg "✅ 已设置环境变量: export KUBECONFIG=$DIRECT_KUBECONFIG"
      msg "💡 提示：使用远程集群时，请保持此环境变量设置"
      msg "💡 提示：使用本地集群时，请运行: unset KUBECONFIG"
      
      # 读取从远端获取的 kubeconfig 中原始 server，决定是否走别名严格 TLS
      local original_server_url
      original_server_url=$(grep -m1 '^\s*server:' "$DIRECT_KUBECONFIG" | awk '{print $2}')
      local original_host
      local original_port
      original_host=$(echo "$original_server_url" | sed -E 's#https?://([^:/]+).*#\1#')
      original_port=$(echo "$original_server_url" | sed -E 's#https?://[^:/]+:([0-9]+).*#\1#')
      if [[ -z "$original_port" ]]; then original_port=6443; fi

      if [[ "$DIRECT_BIND_ALIAS" == "true" ]]; then
        # 使用域名别名保持严格 TLS
        msg "🔗 配置域名别名并保持严格 TLS"
        # 重启隧道指向 127.0.0.1
        if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          kill "$TUNNEL_PID" 2>/dev/null || true
          wait "$TUNNEL_PID" 2>/dev/null || true
        fi
        pkill -f "ssh.*$DIRECT_LOCAL_PORT:127.0.0.1:$original_port" >/dev/null 2>&1 || true
        msg "📡 建立隧道: 本地:$DIRECT_LOCAL_PORT → 127.0.0.1:$original_port"
        ssh "${ssh_args[@]}" -o ConnectTimeout="$GLOBAL_TIMEOUT" -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -L "$DIRECT_LOCAL_PORT:127.0.0.1:$original_port" -p "$direct_host_port" "$DIRECT_USER@$direct_host_ip" -N &
        TUNNEL_PID=$!
        echo "$TUNNEL_PID" > "$PID_FILE"

        # 动态解析证书SAN，选择有效的域名
        local cert_tmp=$(mktemp)
        local valid_domain=""
        
        # 从kubeconfig中提取证书并解析SAN
        if command -v yq >/dev/null 2>&1; then
          # 使用yq提取证书数据
          local cert_data
          cert_data=$(yq e '.clusters[0].cluster["certificate-authority-data"]' "$DIRECT_KUBECONFIG" 2>/dev/null || echo "")
          if [[ -n "$cert_data" ]]; then
            echo "$cert_data" | base64 -d > "$cert_tmp" 2>/dev/null
            valid_domain=$(openssl x509 -in "$cert_tmp" -noout -text 2>/dev/null | grep -oP 'DNS:[^,\s]+' | head -n1 | cut -d: -f2)
          fi
        fi
        
        # 如果yq不可用或解析失败，尝试使用grep直接解析
        if [[ -z "$valid_domain" ]]; then
          valid_domain=$(grep -oP 'certificate-authority-data:\s*\K[^[:space:]]+' "$DIRECT_KUBECONFIG" | head -n1 | base64 -d 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -oP 'DNS:[^,\s]+' | head -n1 | cut -d: -f2)
        fi
        
        # 如果还是失败，使用默认域名
        if [[ -z "$valid_domain" ]]; then
          valid_domain="kubernetes"
          warn "⚠️  无法解析证书SAN，使用默认域名: $valid_domain"
        fi
        
        rm -f "$cert_tmp"
        
        # hosts 添加域名别名（带标记）
        if ! grep -q "^127.0.0.1[[:space:]]\+$valid_domain[[:space:]]\+# added_by_k8s_manager$" /etc/hosts 2>/dev/null; then
          echo "127.0.0.1 $valid_domain # added_by_k8s_manager" | sudo tee -a /etc/hosts >/dev/null
        fi
        # 修改 kubeconfig 使用有效域名
        sed -i "s|server: https://.*:6443|server: https://$valid_domain:$DIRECT_LOCAL_PORT|g" "$DIRECT_KUBECONFIG"
        msg "🔧 已配置域名别名严格 TLS 模式"
      else
        # 回环方案：将 server 改为 127.0.0.1:PORT，并添加 insecure，删除证书字段
        msg "🔧 修改 kubeconfig 服务器地址 (回环) ..."
        sed -i "s|server: https://.*:6443|server: https://127.0.0.1:$DIRECT_LOCAL_PORT|g" "$DIRECT_KUBECONFIG"
        sed -i '/certificate-authority-data:/d' "$DIRECT_KUBECONFIG"
        sed -i '/certificate-authority:/d' "$DIRECT_KUBECONFIG"
        sed -i "/server: https:\/\/127.0.0.1:$DIRECT_LOCAL_PORT/a\\    insecure-skip-tls-verify: true" "$DIRECT_KUBECONFIG"
        msg "🔧 已配置回环模式并应用 TLS 设置"
      fi
      ;;
      

  esac
  
  save_status
  success "✅ 连接已建立"
  
  # 等待连接稳定
  msg "⏳ 等待连接稳定..."
  sleep 3
  
  # 测试连接是否可用
  if check_connection_status; then
    success "✅ 连接测试通过"
  else
    warn "⚠️  连接测试失败，但隧道已建立，请稍后重试"
  fi
}

# 停止连接（静默模式）
stop_connection_quiet(){
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  
  # 清理别名（只删除带标记的条目）
  case "$CURRENT_MODE" in
    "bastion")
      if [[ "$BASTION_BIND_ALIAS" == "true" ]] && [[ -n "$BASTION_API_SERVER" ]]; then
        local api_ip
        api_ip=$(echo "$BASTION_API_SERVER" | cut -d':' -f1)
        sudo sed -i "/127.0.0.1 $api_ip # added_by_k8s_manager$/d" /etc/hosts 2>/dev/null || true
      fi
      ;;
    "direct")
      if [[ "$DIRECT_BIND_ALIAS" == "true" ]] && [[ -n "$DIRECT_HOST" ]]; then
        local api_ip
        api_ip=$(echo "$DIRECT_HOST" | cut -d':' -f1)
        sudo sed -i "/127.0.0.1 $api_ip # added_by_k8s_manager$/d" /etc/hosts 2>/dev/null || true
        # 同时清理可能添加的域名别名
        sudo sed -i "/# added_by_k8s_manager$/d" /etc/hosts 2>/dev/null || true
      fi
      ;;
  esac
  
  clear_status
}

# 停止连接
stop_connection(){
  if [[ -z "$CURRENT_MODE" ]]; then
    err "❌ 没有活动的连接"
    return 1
  fi
  
  msg "🛑 正在停止连接..."
  stop_connection_quiet
  success "✅ 连接已停止"
}

# 显示连接信息和使用提示
show_connection_info(){
  echo ""
  msg "🔗 连接已建立，可在其他终端窗口中使用："
  echo ""
  msg "💡 在其他终端窗口中运行以下命令："
  echo "export KUBECONFIG=$CURRENT_KUBECONFIG"
  echo ""
  msg "💡 然后就可以使用 kubectl 命令操作集群："
  echo "kubectl get nodes"
  echo "kubectl get pods -A"
  echo ""
  msg "💡 提示：可以不关闭此窗口，在其他终端窗口中使用连接"
  echo ""
  read -rp "按回车键进入操作菜单..." || true
}

# 显示状态
show_status(){
  if [[ -z "$CURRENT_MODE" ]]; then
    msg "📊 当前状态: 未连接"
    return
  fi
  
  msg "📊 当前状态:"
  msg "  访问方式: $CURRENT_MODE"
  msg "  Kubeconfig: $CURRENT_KUBECONFIG"
  
  case "$CURRENT_MODE" in
    "kind")
      msg "  集群名称: $KIND_CLUSTER_NAME"
      if kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        msg "  集群状态: 运行中"
        msg "  节点信息:"
        kind get nodes --name "$KIND_CLUSTER_NAME" 2>/dev/null || true
      else
        msg "  集群状态: 不存在"
      fi
      ;;
    "bastion")
      if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
        msg "  隧道状态: 运行中 (PID: $TUNNEL_PID)"
        msg "  跳板机: $BASTION_HOST"
        msg "  目标节点: $BASTION_API_SERVER"
        msg "  本地端口: $BASTION_LOCAL_PORT"
      else
        msg "  隧道状态: 未运行"
      fi
      ;;
    "direct")
      if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
        msg "  隧道状态: 运行中 (PID: $TUNNEL_PID)"
        msg "  目标节点: $DIRECT_HOST"
        msg "  本地端口: $DIRECT_LOCAL_PORT"
      else
        msg "  隧道状态: 未运行"
      fi
      ;;
  esac
}

# 测试连接
test_connection(){
  if [[ -z "$CURRENT_MODE" ]]; then
    err "❌ 没有活动的连接"
    return 1
  fi
  
  msg "🧪 测试连接..."
  
  case "$CURRENT_MODE" in
    "kind")
      if kubectl cluster-info >/dev/null 2>&1; then
        success "✅ Kind 集群连接正常"
        kubectl cluster-info
        kubectl get nodes -o wide
      else
        err "❌ Kind 集群连接失败"
        return 1
      fi
      ;;
    "bastion"|"direct")
      if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
        if KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes >/dev/null 2>&1; then
          success "✅ 连接正常"
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes -o wide
        else
          err "❌ 连接失败"
        fi
      else
        err "❌ 隧道未运行"
      fi
      ;;
  esac
}

# 端口检查功能
check_ports(){
  if [[ -z "$CURRENT_MODE" ]]; then
    err "❌ 没有活动的连接"
    return 1
  fi
  
  msg "🔍 开始端口检查..."
  warn "⚠️  注意：在云企业网架构下，Worker节点端口显示关闭是正常的"
  warn "⚠️  这是因为不同网段间直接TCP访问被限制，但K8s内部通信正常"
  echo ""
  
  case "$CURRENT_MODE" in
    "bastion")
      msg "📡 通过跳板机检查端口..."
      # 通过跳板机执行端口检查
      local ssh_cmd
      if [[ -n "$BASTION_SECRET" ]]; then
        ssh_cmd="ssh -i $BASTION_SECRET -o ConnectTimeout=$GLOBAL_TIMEOUT -p $BASTION_LOCAL_PORT localhost"
      else
        ssh_cmd="ssh -o ConnectTimeout=$GLOBAL_TIMEOUT -p $BASTION_LOCAL_PORT localhost"
      fi
      
      # 在远程执行端口检查
      $ssh_cmd "echo '=== Master 节点端口检查 ===' && \
        for port in 6443 2379 2380 10250 10257 10259 179 5473 22; do \
          if timeout 5 bash -c \"</dev/tcp/127.0.0.1/\$port\" 2>/dev/null; then \
            echo \"✅ \$port - 开放\"; \
          else \
            echo \"❌ \$port - 关闭\"; \
          fi; \
        done && \
        echo '=== Worker 节点状态检查 ===' && \
        kubectl get nodes -o wide | grep -v NAME | while read node node_status roles age version internal_ip external_ip os_image kernel_version container_runtime; do \
          if [[ \"\$roles\" != \"control-plane\" ]]; then \
            echo \"检查节点: \$node (\$internal_ip)\"; \
            echo \"  状态: \$node_status\"; \
            echo \"  角色: \$roles\"; \
            echo \"  版本: \$version\"; \
            pod_count=\$(kubectl get pods --all-namespaces -o wide | grep \"\$node\" | wc -l); \
            echo \"  运行 Pod: \$pod_count 个\"; \
            if timeout 5 bash -c \"</dev/tcp/\$internal_ip/10250\" 2>/dev/null; then \
              echo \"  ✅ kubelet (10250) - 可访问\"; \
            else \
              echo \"  ❌ kubelet (10250) - 不可访问\"; \
            fi; \
            if timeout 5 bash -c \"</dev/tcp/\$internal_ip/179\" 2>/dev/null; then \
              echo \"  ✅ Calico BGP (179) - 可访问\"; \
            else \
              echo \"  ❌ Calico BGP (179) - 不可访问\"; \
            fi; \
            echo \"\"; \
          fi; \
        done"
      ;;
      
    "direct")
      msg "📡 直接检查端口..."
      # 直接通过 SSH 执行端口检查
      local direct_host_ip
      local direct_host_port
      direct_host_ip=$(echo "$DIRECT_HOST" | cut -d':' -f1)
      direct_host_port=$(echo "$DIRECT_HOST" | cut -d':' -f2)
      direct_host_port=${direct_host_port:-22}
      
      local ssh_cmd
      if [[ -n "$DIRECT_SECRET" ]]; then
        ssh_cmd="ssh -i $DIRECT_SECRET -o ConnectTimeout=$GLOBAL_TIMEOUT -p $direct_host_port $DIRECT_USER@$direct_host_ip"
      else
        ssh_cmd="ssh -o ConnectTimeout=$GLOBAL_TIMEOUT -p $direct_host_port $DIRECT_USER@$direct_host_ip"
      fi
      
      # 在远程执行端口检查
      $ssh_cmd "echo '=== Master 节点端口检查 ===' && \
        for port in 6443 2379 2380 10250 10257 10259 179 5473 22; do \
          if timeout 5 bash -c \"</dev/tcp/127.0.0.1/\$port\" 2>/dev/null; then \
            echo \"✅ \$port - 开放\"; \
          else \
            echo \"❌ \$port - 关闭\"; \
          fi; \
        done && \
        echo '=== Worker 节点状态检查 ===' && \
        kubectl get nodes -o wide | grep -v NAME | while read node node_status roles age version internal_ip external_ip os_image kernel_version container_runtime; do \
          if [[ \"\$roles\" != \"control-plane\" ]]; then \
            echo \"检查节点: \$node (\$internal_ip)\"; \
            echo \"  状态: \$node_status\"; \
            echo \"  角色: \$roles\"; \
            echo \"  版本: \$version\"; \
            pod_count=\$(kubectl get pods --all-namespaces -o wide | grep \"\$node\" | wc -l); \
            echo \"  运行 Pod: \$pod_count 个\"; \
            if timeout 5 bash -c \"</dev/tcp/\$internal_ip/10250\" 2>/dev/null; then \
              echo \"  ✅ kubelet (10250) - 可访问\"; \
            else \
              echo \"  ❌ kubelet (10250) - 不可访问\"; \
            fi; \
            if timeout 5 bash -c \"</dev/tcp/\$internal_ip/179\" 2>/dev/null; then \
              echo \"  ✅ Calico BGP (179) - 可访问\"; \
            else \
              echo \"  ❌ Calico BGP (179) - 不可访问\"; \
            fi; \
            echo \"\"; \
          fi; \
        done"
      ;;
  esac
}


# 检查连接状态
check_connection_status(){
  # Kind 模式下没有隧道，只需简单验证 kubectl 是否可用
  if [[ "${CURRENT_MODE:-}" == "kind" ]]; then
    if KUBECONFIG="$CURRENT_KUBECONFIG" kubectl cluster-info >/dev/null 2>&1; then
      return 0
    else
      return 1
    fi
  fi
  
  # 远程模式需要检查隧道 PID
  if [[ -z "${TUNNEL_PID:-}" ]] || ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    return 1  # 连接断开
  fi
  
  # 测试 kubectl 连接（带重试）
  local retry_count=0
  local max_retries=5  # 增加重试次数
  
  while [[ $retry_count -lt $max_retries ]]; do
    if KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes >/dev/null 2>&1; then
      return 0  # 连接正常
    fi
    
    retry_count=$((retry_count+1))  # 使用显式赋值，避免 ((retry_count++)) 在某些情况下导致的问题
    if [[ $retry_count -lt $max_retries ]]; then
      sleep 3  # 等待3秒后重试
    fi
  done
  
  return 1  # 连接不可用
}


# 操作菜单
operation_menu(){
  if [[ -z "$CURRENT_MODE" ]]; then
    err "❌ 没有活动的连接"
    return 1
  fi
  
  # Kind 模式下没有 SSH 隧道，提供简化菜单，直接基于当前 KUBECONFIG 运行 kubectl
  if [[ "$CURRENT_MODE" == "kind" ]]; then
    while true; do
      echo ""
      msg "🔧 Kubernetes 操作菜单 (当前: kind)"
      msg "1) 查看节点"
      msg "2) 查看 Pod"
      msg "3) 查看服务"
      msg "4) 查看命名空间"
      msg "5) 查看集群信息"
      msg "6) 查看部署"
      msg "7) 查看配置映射"
      msg "8) 查看密钥"
      msg "9) 测试连接"
      msg "10) 检查端口"
      msg "q) 退出操作菜单"
      
      if ! read -rp "请选择: " choice; then
        msg "🛑 用户中断，退出操作菜单"
        msg "💡 提示：如需重新连接，请重新运行脚本"
        break
      fi
      
      case "${choice:-}" in
        1) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes -o wide ;;
        2) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get pods -A ;;
        3) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get svc -A ;;
        4) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get ns ;;
        5) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl cluster-info ;;
        6) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get deploy -A ;;
        7) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get configmaps -A ;;
        8) KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get secrets -A ;;
        9) test_connection ;;
        10) check_ports ;;
        q|quit|exit)
          msg "🛑 正在退出操作菜单..."
          msg "💡 提示：如需重新连接，请重新运行脚本"
          break
          ;;
        *) warn "❌ 无效选择" ;;
      esac
      
      echo ""
      read -rp "按回车键继续..." || true
    done
    
    return 0
  fi
  
  # 远程模式：需要维护 SSH 隧道
  while true; do
    # 检查连接状态（更宽松的检查）
    if [[ -z "${TUNNEL_PID:-}" ]] || ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
      warn "⚠️  隧道已断开，请手动重新启动脚本"
      msg "💡 提示：请运行以下命令设置环境变量："
      echo "export KUBECONFIG=$CURRENT_KUBECONFIG"
      break
    fi
    
    echo ""
    msg "🔧 Kubernetes 操作菜单 (当前: $CURRENT_MODE)"
    msg "1) 查看节点"
    msg "2) 查看 Pod"
    msg "3) 查看服务"
    msg "4) 查看命名空间"
    msg "5) 查看集群信息"
    msg "6) 查看部署"
    msg "7) 查看配置映射"
    msg "8) 查看密钥"
    msg "9) 测试连接"
    msg "10) 检查端口"
    msg "q) 退出操作菜单"
    
    if ! read -rp "请选择: " choice; then
      msg "🛑 用户中断，退出操作菜单"
      msg "💡 提示：隧道和连接将被清理"
      msg "💡 提示：如需重新连接，请重新运行脚本"
      break
    fi
    
    case "${choice:-}" in
      1) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get nodes -o wide
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      2) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get pods -A
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      3) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get svc -A
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      4) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get namespaces
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      5) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl cluster-info
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      6) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get deployments -A
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      7) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get configmaps -A
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      8) 
        # 检查隧道是否运行
        if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
          KUBECONFIG="$CURRENT_KUBECONFIG" kubectl get secrets -A
        else
          err "❌ 隧道已断开，请重新启动脚本"
        fi
        ;;
      9) test_connection ;;
      10) check_ports ;;
      q|quit|exit) 
        msg "🛑 正在退出操作菜单..."
        msg "💡 提示：隧道和连接将被清理"
        msg "💡 提示：如需重新连接，请重新运行脚本"
        return 0
        ;;
      *) warn "❌ 无效选择" ;;
    esac
    
    echo ""
    read -rp "按回车键继续..." || true
  done
}






# 初始化函数
initialize_environment(){
  # 确保 .kube 目录存在
  local kube_dir="$HOME/.kube"
  if [[ ! -d "$kube_dir" ]]; then
    msg "📁 创建 .kube 目录: $kube_dir"
    mkdir -p "$kube_dir"
    success "✅ .kube 目录已创建"
  fi
  
  # 检查 kubectl 是否安装
  check_and_install_kubectl
}

# 解析集群参数

# 主函数
main(){
  # 注意：原有的 trap cleanup EXIT INT TERM 已经设置，这里不需要重复设置
  
  # 解析集群参数（支持 --cluster 或 -c，或环境变量）
  unified_parse_cluster_arg "$@"
  
  # 检查依赖
  if ! command -v ssh >/dev/null 2>&1; then
    err "❌ 未找到 ssh 命令，请先安装 OpenSSH"
    exit 1
  fi
  
  # 初始化环境
  initialize_environment
  
  # 读取配置
  read_config
  
  # 加载状态
  load_status
  
  # 显示欢迎信息
  echo ""
  msg "🚀 Kubernetes 集群管理工具"
  msg "配置文件: $CONFIG_FILE"
  if [[ -n "${CLUSTER:-}" ]]; then
    msg "🎯 当前集群配置: ${CLUSTER}"
  fi
  echo ""
  
  # 选择访问方式
  select_access_mode
  # 显示连接信息和使用提示
  show_connection_info
  
  # 显示操作菜单
  operation_menu
}

# 运行主函数
main "$@"
