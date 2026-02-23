#!/usr/bin/env bash
#
# Kind 一键部署：按顺序执行 NFS 检查/安装、创建集群与平台初始化、镜像预加载、WSL Harbor 解析。
# 均在 WSL 中执行。可选参数见下方用法。配置见同目录 deploy-kind.conf。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载配置（可选）
if [[ -f "$SCRIPT_DIR/deploy-kind.conf" ]]; then
    source "$SCRIPT_DIR/deploy-kind.conf"
fi
export HARBOR_HOST HARBOR_NODE_IP 2>/dev/null || true

NFS_EXPORT_DIR="${NFS_EXPORT_DIR:-/data/kind-nfs}"
RUN_CA_INIT="${DEPLOY_KIND_RUN_CA_INIT:-true}"
RUN_IMAGES="${DEPLOY_KIND_RUN_IMAGES:-true}"
RUN_REGISTRY_CONFIG="${DEPLOY_KIND_RUN_REGISTRY_CONFIG:-true}"
RUN_HARBOR_HOSTS="${DEPLOY_KIND_RUN_HARBOR_HOSTS:-true}"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --skip-ca-init          跳过本地根 CA 生成（ensure-kind-ca.sh，与远程 Step12 同用途）"
    echo "  --skip-images           跳过镜像预加载（load-initial-images-kind.sh）"
    echo "  --skip-registry-config  跳过 Kind 节点 containerd 镜像拉取配置（apply-kind-registry-config.sh）"
    echo "  --skip-harbor-hosts     跳过 WSL /etc/hosts 中 Harbor 域名配置"
    echo "  -h, --help           显示此帮助"
    echo "配置: $SCRIPT_DIR/deploy-kind.conf"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-ca-init)           RUN_CA_INIT=false; shift ;;
        --skip-images)            RUN_IMAGES=false; shift ;;
        --skip-registry-config)   RUN_REGISTRY_CONFIG=false; shift ;;
        --skip-harbor-hosts)      RUN_HARBOR_HOSTS=false; shift ;;
        -h|--help)           usage; exit 0 ;;
        *)                   log_error "未知选项: $1"; usage; exit 1 ;;
    esac
done

log_info "Kind 一键部署开始（步骤 1/6：NFS）"
if ! [[ -f /etc/exports ]] || ! grep -qE "^${NFS_EXPORT_DIR}[[:space:]]" /etc/exports 2>/dev/null; then
    log_info "未检测到 NFS 导出，执行 wsl-setup-nfs-server.sh ..."
    "$KIND_ROOT/wsl-setup-nfs-server.sh"
else
    log_info "NFS 已配置，跳过"
fi

log_info "步骤 2/6：创建集群与平台初始化（kind-up.sh）"
"$KIND_ROOT/kind-up.sh"

if [[ "$RUN_CA_INIT" == "true" ]]; then
    log_info "步骤 3/6：生成本地根 CA（ensure-kind-ca.sh，与远程 Step12 同用途）"
    export TRAEFIK_CA_LOCAL_DIR="${TRAEFIK_CA_LOCAL_DIR:-}"
    "$KIND_ROOT/ensure-kind-ca.sh"
else
    log_info "步骤 3/6：跳过本地根 CA 生成（--skip-ca-init）"
fi

log_info "步骤 4/6：Kind 节点 Harbor 解析 + containerd 镜像拉取配置"
"$KIND_ROOT/apply-kind-node-harbor-hosts.sh"
if [[ "$RUN_REGISTRY_CONFIG" == "true" ]]; then
    export STEP02_REGISTRY_ENABLE STEP02_REGISTRY_MIRRORS STEP02_REGISTRY_DIRECT 2>/dev/null || true
    "$KIND_ROOT/apply-kind-registry-config.sh"
else
    log_info "跳过 Kind 节点 registry 配置（--skip-registry-config）"
fi

if [[ "$RUN_IMAGES" == "true" ]]; then
    log_info "步骤 5/6：预加载 Traefik/Harbor 镜像（load-initial-images-kind.sh）"
    "$KIND_ROOT/load-initial-images-kind.sh"
else
    log_info "步骤 5/6：跳过镜像预加载（--skip-images）"
fi

if [[ "$RUN_HARBOR_HOSTS" == "true" ]]; then
    log_info "步骤 6/6：WSL 宿主机 Harbor 域名解析（wsl-setup-harbor-hosts.sh）"
    export HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
    export HARBOR_IP="${HARBOR_IP:-127.0.0.1}"
    "$KIND_ROOT/wsl-setup-harbor-hosts.sh"
else
    log_info "步骤 6/6：跳过 Harbor hosts（--skip-harbor-hosts）"
fi

log_success "Kind 一键部署完成"
log_info "使用集群前请运行连接管理器或: export KUBECONFIG=\$HOME/.kube/kind-config"
log_info "后续可部署 Traefik、Harbor 等组件，详见 deploy-kind/deploy-kind.md"
