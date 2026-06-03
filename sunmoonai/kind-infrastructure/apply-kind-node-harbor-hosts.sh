#!/usr/bin/env bash
#
# 在 Kind 各节点内写入 /etc/hosts：harbor.sunmoonai.com -> 指定 IP。
# 因 kind v1alpha4 不支持节点 extraHosts，建集群后通过本脚本补上，供 containerd 拉镜像时解析。
# 应在 kind-up.sh 之后、apply-kind-registry-config.sh 之前执行。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"
# shellcheck source=kind-cli.sh
source "${SCRIPT_DIR}/kind-cli.sh"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

upsert_host_entry() {
    local node="$1"
    docker exec \
        -e HARBOR_HOST="$HARBOR_HOST" \
        -e HARBOR_NODE_IP="$HARBOR_NODE_IP" \
        "$node" sh -c '
set -e
tmp="$(mktemp)"
awk -v host="$HARBOR_HOST" "\$2 != host { print }" /etc/hosts > "$tmp"
printf "%s %s\n" "$HARBOR_NODE_IP" "$HARBOR_HOST" >> "$tmp"
cat "$tmp" > /etc/hosts
rm -f "$tmp"
'
}

install_host_entry_service() {
    local node="$1"
    docker exec \
        -e HARBOR_HOST="$HARBOR_HOST" \
        "$node" sh -c '
set -e
cat >/usr/local/bin/kind-harbor-hosts.sh <<'"'"'EOF'"'"'
#!/bin/sh
set -eu
host="${HARBOR_HOST:-harbor.sunmoonai.com}"
control_plane="${KIND_CONTROL_PLANE_NAME:-kind-control-plane}"
ip="$(getent hosts "$control_plane" 2>/dev/null | awk "{ print \$1; exit }" || true)"
if [ -z "$ip" ] && [ "$(hostname)" = "$control_plane" ]; then
    ip="$(hostname -I 2>/dev/null | awk "{ print \$1; exit }" || true)"
fi
[ -n "$ip" ] || exit 0
tmp="$(mktemp)"
sed -E "/^[0-9.]+[[:space:]]+${host}[[:space:]]*$/d" /etc/hosts > "$tmp"
printf "%s %s\n" "$ip" "$host" >> "$tmp"
cat "$tmp" > /etc/hosts
rm -f "$tmp"
EOF
chmod +x /usr/local/bin/kind-harbor-hosts.sh

mkdir -p /etc/systemd/system
cat >/etc/systemd/system/kind-harbor-hosts.service <<EOF
[Unit]
Description=Refresh Harbor hosts entry for Kind node image pulls
After=network-online.target
Before=containerd.service kubelet.service

[Service]
Type=oneshot
Environment=HARBOR_HOST=${HARBOR_HOST}
ExecStart=/usr/local/bin/kind-harbor-hosts.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable kind-harbor-hosts.service >/dev/null 2>&1 || true
'
}

# 集群名与节点内 Harbor 解析 IP。
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
HARBOR_NODE_IP="${HARBOR_NODE_IP:-}"

if [[ -f "$K8S_ADMIN_CONF" ]]; then
    section=$(sed -n '/^\[KIND\]$/,/^\[[A-Z]/p' "$K8S_ADMIN_CONF" 2>/dev/null || true)
    [[ -n "${section}" ]] && KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-$(echo "$section" | grep "^cluster_name=" | head -1 | cut -d'=' -f2- | tr -d ' ')}"
fi
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"

# 如未在配置中显式指定 HARBOR_NODE_IP，则自动推导：
# 默认使用 control-plane 容器的 IP，供 NodePort 暴露的「集群内 Harbor」使用。
if [[ -z "${HARBOR_NODE_IP:-}" ]]; then
    if docker inspect kind-control-plane &>/dev/null; then
        HARBOR_NODE_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kind-control-plane 2>/dev/null || true)"
    fi
fi

HARBOR_NODE_IP="${HARBOR_NODE_IP:-172.18.0.2}"

prepend_kind_to_path_if_needed || true
if ! command -v kind &>/dev/null; then
    log_error "未找到 kind 命令（请安装: ~/.local/bin/kind 或加入 PATH）"
    exit 1
fi

nodes=$(kind get nodes --name "$KIND_CLUSTER_NAME" 2>/dev/null || true)
if [[ -z "$nodes" ]]; then
    log_error "未找到 Kind 集群节点: $KIND_CLUSTER_NAME"
    exit 1
fi

log_info "在 Kind 各节点 /etc/hosts 中添加/更新 ${HARBOR_HOST} -> ${HARBOR_NODE_IP}（集群: $KIND_CLUSTER_NAME）"
count=0
while IFS= read -r node; do
    [[ -z "$node" ]] && continue
    if docker exec "$node" sh -c "grep -q '${HARBOR_HOST}' /etc/hosts 2>/dev/null"; then
        # 若已存在但 IP 不一致，则更新
        cur_line=$(docker exec "$node" sh -c "grep ' ${HARBOR_HOST}\$' /etc/hosts 2>/dev/null | head -1" || true)
        if [[ -n "$cur_line" && "$cur_line" != "${HARBOR_NODE_IP} ${HARBOR_HOST}" ]]; then
            log_info "  节点 $node: 更新 ${HARBOR_HOST} 映射为 ${HARBOR_NODE_IP}（原记录: ${cur_line}）"
            upsert_host_entry "$node"
        else
            log_info "  节点 $node 已存在 ${HARBOR_HOST}，且 IP 一致，跳过"
        fi
    else
        upsert_host_entry "$node"
        log_info "  节点 $node: 已添加 ${HARBOR_HOST} -> ${HARBOR_NODE_IP}"
    fi
    install_host_entry_service "$node" || log_warn "  节点 $node: 安装 Harbor hosts 开机修复服务失败"
    ((count++)) || true
done <<< "$nodes"

if [[ $count -eq 0 ]]; then
    log_warn "未处理任何节点"
    exit 1
fi
log_success "已在 $count 个节点配置 ${HARBOR_HOST} 解析"
