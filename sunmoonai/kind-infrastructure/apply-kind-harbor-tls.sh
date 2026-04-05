#!/usr/bin/env bash
#
# 在 Kind 各节点内下发 Harbor 根 CA，并为 harbor.sunmoonai.com:30443 写入 containerd certs.d/hosts.toml，
# 确保节点能直接通过自签 CA 校验证书，从 Harbor 拉取镜像时不再出现 x509: unknown authority。
#
# 设计要点：
# - 仅依赖已生成的根 CA（由 ensure-kind-ca.sh 生成），找不到 CA 时安全跳过，不中断整体 deploy-kind。
# - 自动检测 Kind 集群名称与节点列表，与 apply-kind-registry-config.sh 的逻辑保持一致。
# - 仅为 Harbor 直接地址写入 hosts.toml，不影响其他 registry mirrors 配置。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"

log_info()    { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn()    { echo "⚠️  $*"; }
log_error()   { echo "❌ $*"; }

read_kind_config() {
    if [[ ! -f "$K8S_ADMIN_CONF" ]]; then
        KIND_CLUSTER_NAME=kind
        return
    fi
    local section
    section=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF")
    KIND_CLUSTER_NAME=$(echo "$section" | grep "^cluster_name=" | head -1 | cut -d'=' -f2- | tr -d ' ')
    KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-kind}
}

main() {
    read_kind_config

    # 根 CA 路径：默认沿用 WSL 侧脚本的约定，如需自定义可通过 KIND_HARBOR_CA_PATH 覆盖
    local ca_src
    ca_src="${KIND_HARBOR_CA_PATH:-$HOME/k8s/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca/ca.crt}"

    if [[ ! -f "$ca_src" ]]; then
        log_warn "未找到 Harbor 根 CA: $ca_src，跳过 Kind 节点 TLS 信任配置（可先运行 ensure-kind-ca.sh 再重试）"
        exit 0
    fi

    if ! command -v kind &>/dev/null; then
        log_warn "未找到 kind 命令，跳过 Harbor TLS 配置"
        exit 0
    fi
    if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        log_warn "Kind 集群 ${KIND_CLUSTER_NAME} 不存在，跳过 Harbor TLS 配置"
        exit 0
    fi

    mapfile -t nodes < <(kind get nodes --name "$KIND_CLUSTER_NAME" 2>/dev/null || true)
    if [[ ${#nodes[@]} -eq 0 ]]; then
        log_warn "未获取到 Kind 节点列表，跳过 Harbor TLS 配置"
        exit 0
    fi

    local host port reg
    host="${HARBOR_HOST:-harbor.sunmoonai.com}"
    port="${HARBOR_PORT:-30443}"
    reg="${host}:${port}"

    for node in "${nodes[@]}"; do
        log_info "为 Kind 节点 ${node} 安装 Harbor 根 CA 并写入 containerd hosts.toml（${reg}）"

        # 1) 安装根 CA 到系统信任
        if ! docker cp "$ca_src" "${node}:/usr/local/share/ca-certificates/sunmoonai-root-ca.crt" 2>/dev/null; then
            log_warn "无法将根 CA 拷贝到节点 ${node}，跳过该节点"
            continue
        fi
        docker exec "$node" bash -lc 'update-ca-certificates >/dev/null 2>&1 || true'

        # 2) 确保 containerd 使用 /etc/containerd/certs.d 目录
        docker exec "$node" bash -lc '
set -euo pipefail
cfg=/etc/containerd/config.toml
if [[ ! -f "$cfg" ]]; then
    exit 0
fi
if ! grep -q "\[plugins.\"io.containerd.grpc.v1.cri\".registry\]" "$cfg"; then
    cat >>"$cfg" <<EOF

[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "/etc/containerd/certs.d"
EOF
else
    if ! grep -q "config_path *= *\"/etc/containerd/certs.d\"" "$cfg"; then
        sed -i "/\[plugins.\"io.containerd.grpc.v1.cri\".registry\]/a \  config_path = \"/etc/containerd/certs.d\"" "$cfg"
    fi
fi
' || log_warn "节点 ${node} 更新 containerd config.toml 失败，可手动检查"

        # 3) 为 Harbor 直连地址写入 hosts.toml，显式指定 ca 路径
        docker exec "$node" bash -lc "
set -euo pipefail
dir=/etc/containerd/certs.d/${reg}
mkdir -p \"\$dir\"
cat >\"\$dir/hosts.toml\" <<EOF
server = \"https://${reg}\"

[host.\"https://${reg}\"]
  capabilities = [\"pull\", \"resolve\", \"push\"]
  ca = \"/usr/local/share/ca-certificates/sunmoonai-root-ca.crt\"
EOF
" || log_warn "节点 ${node} 写入 ${reg} hosts.toml 失败，可手动检查"

        # 4) 重启 containerd/kubelet，使新配置立即生效
        if ! docker exec "$node" bash -lc 'systemctl restart containerd; systemctl restart kubelet'; then
            log_warn "节点 ${node} 重启 containerd/kubelet 失败，新配置可能在下次节点重启后才生效"
        fi
    done

    log_success "已在 ${#nodes[@]} 个 Kind 节点写入 Harbor TLS 信任配置（根 CA + certs.d/hosts.toml）"
}

main "$@"

