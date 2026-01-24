#!/bin/bash

# Kind 集群初始化脚本
# 用于创建和管理 kind 本地 Kubernetes 集群

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/k8s-admin.conf"

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

# 读取 kind 配置
read_kind_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    err "配置文件不存在: $CONFIG_FILE"
    exit 1
  fi
  
  KIND_CLUSTER_NAME=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^cluster_name=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  KIND_KUBECONFIG=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kubeconfig=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  KIND_CONFIG=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kind_config=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  KIND_IMAGE=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$CONFIG_FILE" | grep "^kind_image=" | head -1 | cut -d'=' -f2 | tr -d ' ')
  
  # 展开路径
  KIND_KUBECONFIG="${KIND_KUBECONFIG/#\~/$HOME}"
  KIND_CONFIG="${KIND_CONFIG/#\~/$HOME}"
  
  # 设置默认值
  KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-kind}
  KIND_KUBECONFIG=${KIND_KUBECONFIG:-$HOME/.kube/kind-config}
}

# 检查 kind 是否安装
check_kind() {
  if ! command -v kind >/dev/null 2>&1; then
    err "kind 未安装"
    msg "安装方法："
    echo "  # Linux/macOS"
    echo "  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
    echo "  chmod +x ./kind"
    echo "  sudo mv ./kind /usr/local/bin/kind"
    echo ""
    echo "  或使用包管理器："
    echo "  # macOS"
    echo "  brew install kind"
    echo ""
    echo "  # 更多安装方法：https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
  fi
  success "kind 已安装: $(kind version)"
}

# 检查 Docker 是否运行
check_docker() {
  if ! docker info >/dev/null 2>&1; then
    err "Docker 未运行或未安装"
    msg "请确保 Docker 已安装并正在运行"
    exit 1
  fi
  success "Docker 正在运行"
}

# 创建 kind 集群
create_cluster() {
  msg "🚀 创建 kind 集群: $KIND_CLUSTER_NAME"
  
  # 检查集群是否已存在
  if kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
    warn "集群 $KIND_CLUSTER_NAME 已存在"
    read -rp "是否删除并重新创建? (y/N): " confirm
    if [[ "${confirm:-}" =~ ^[Yy]$ ]]; then
      delete_cluster
    else
      msg "取消创建"
      return 0
    fi
  fi
  
  # 构建 kind create 命令
  local create_cmd="kind create cluster --name $KIND_CLUSTER_NAME"
  
  # 如果指定了配置文件
  if [[ -n "$KIND_CONFIG" && -f "$KIND_CONFIG" ]]; then
    create_cmd="$create_cmd --config $KIND_CONFIG"
    msg "使用配置文件: $KIND_CONFIG"
  fi
  
  # 如果指定了镜像版本
  if [[ -n "$KIND_IMAGE" ]]; then
    create_cmd="$create_cmd --image $KIND_IMAGE"
    msg "使用镜像: $KIND_IMAGE"
  fi
  
  # 执行创建
  if eval "$create_cmd"; then
    success "集群创建成功"
  else
    err "集群创建失败"
    exit 1
  fi
  
  # 配置 kubeconfig
  setup_kubeconfig
}

# 删除 kind 集群
delete_cluster() {
  msg "🗑️  删除 kind 集群: $KIND_CLUSTER_NAME"
  
  if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
    warn "集群 $KIND_CLUSTER_NAME 不存在"
    return 0
  fi
  
  if kind delete cluster --name "$KIND_CLUSTER_NAME"; then
    success "集群删除成功"
  else
    err "集群删除失败"
    exit 1
  fi
}

# 设置 kubeconfig
setup_kubeconfig() {
  msg "📝 配置 kubeconfig"
  
  # kind 会自动将配置添加到 ~/.kube/config
  # 这里我们也可以导出到指定路径
  if [[ -n "$KIND_KUBECONFIG" && "$KIND_KUBECONFIG" != "$HOME/.kube/config" ]]; then
    mkdir -p "$(dirname "$KIND_KUBECONFIG")"
    kind get kubeconfig --name "$KIND_CLUSTER_NAME" > "$KIND_KUBECONFIG"
    success "kubeconfig 已保存到: $KIND_KUBECONFIG"
    msg "💡 使用方式: export KUBECONFIG=$KIND_KUBECONFIG"
  fi
  
  # 显示当前 context
  msg "当前 Kubernetes context:"
  kubectl config current-context
}

# 显示集群状态
show_status() {
  msg "📊 Kind 集群状态"
  
  if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
    warn "集群 $KIND_CLUSTER_NAME 不存在"
    return 1
  fi
  
  echo ""
  msg "集群信息:"
  kind get clusters
  
  echo ""
  msg "节点信息:"
  kind get nodes --name "$KIND_CLUSTER_NAME"
  
  echo ""
  msg "Kubernetes 集群信息:"
  kubectl cluster-info
  
  echo ""
  msg "节点详情:"
  kubectl get nodes -o wide
}

# 主菜单
main_menu() {
  while true; do
    echo ""
    msg "🔧 Kind 集群管理"
    echo "1) 创建集群"
    echo "2) 删除集群"
    echo "3) 查看状态"
    echo "4) 配置 kubeconfig"
    echo "q) 退出"
    echo ""
    
    read -rp "请选择: " choice
    
    case "${choice:-}" in
      1) create_cluster ;;
      2) delete_cluster ;;
      3) show_status ;;
      4) setup_kubeconfig ;;
      q|quit|exit) 
        msg "退出"
        exit 0
        ;;
      *) warn "无效选择" ;;
    esac
  done
}

# 主函数
main() {
  # 检查依赖
  check_kind
  check_docker
  
  # 读取配置
  read_kind_config
  
  # 如果有命令行参数，直接执行
  case "${1:-}" in
    create)
      create_cluster
      ;;
    delete)
      delete_cluster
      ;;
    status)
      show_status
      ;;
    *)
      main_menu
      ;;
  esac
}

# 运行主函数
main "$@"

