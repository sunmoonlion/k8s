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
# shellcheck source=kind-cli.sh
source "${SCRIPT_DIR}/kind-cli.sh"

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

    prepend_kind_to_path_if_needed || true
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

        # 4) 确保 containerd 不走代理访问 Harbor（Kind 节点继承宿主机代理，域名不在 NO_PROXY 会走代理导致 EOF）
        # 代理可能来自 3 个源：systemd override、/etc/default/containerd、或进程环境继承
        # 必须全部覆盖，否则 containerd 仍会走代理
        docker exec "$node" bash -lc "
set -euo pipefail
proxy_conf=/etc/systemd/system/containerd.service.d/http-proxy.conf

# 情况 A：已有 systemd override — 追加域名到 NO_PROXY
if [[ -f \"\$proxy_conf\" ]] && grep -q 'NO_PROXY' \"\$proxy_conf\" && ! grep -q '${host}' \"\$proxy_conf\"; then
    sed -i 's|\\(NO_PROXY=.*\\)\"|\\1,${host}\"|' \"\$proxy_conf\" 2>/dev/null || true
    sed -i 's|\\(no_proxy=.*\\)\"|\\1,${host}\"|' \"\$proxy_conf\" 2>/dev/null || true

# 情况 B：没有 systemd override，但 containerd 进程继承了宿主机代理 — 创建 override
elif ! [[ -f \"\$proxy_conf\" ]]; then
    cur_http=\$(cat /proc/\$(pidof containerd)/environ 2>/dev/null | tr '\\0' '\\n' | grep '^HTTP_PROXY=' | cut -d= -f2- || true)
    cur_https=\$(cat /proc/\$(pidof containerd)/environ 2>/dev/null | tr '\\0' '\\n' | grep '^HTTPS_PROXY=' | cut -d= -f2- || true)
    cur_no=\$(cat /proc/\$(pidof containerd)/environ 2>/dev/null | tr '\\0' '\\n' | grep '^NO_PROXY=' | cut -d= -f2- || true)
    if [[ -n \"\$cur_http\" || -n \"\$cur_https\" ]]; then
        [[ \"\$cur_no\" != *${host}* ]] && cur_no=\"\${cur_no:+\$cur_no,}${host}\"
        mkdir -p /etc/systemd/system/containerd.service.d
        cat >\"\$proxy_conf\" <<EOFCONF
[Service]
Environment=\"HTTP_PROXY=\${cur_http}\"
Environment=\"HTTPS_PROXY=\${cur_https}\"
Environment=\"NO_PROXY=\${cur_no}\"
EOFCONF
    fi
fi

# /etc/default/containerd（部分发行版使用）
if [[ -f /etc/default/containerd ]] && grep -q 'NO_PROXY' /etc/default/containerd && ! grep -q '${host}' /etc/default/containerd; then
    sed -i 's|\\(NO_PROXY=.*\\)\"|\\1,${host}\"|' /etc/default/containerd 2>/dev/null || true
fi

# profile.d（供新 shell 继承）
if [[ -n \"\${NO_PROXY:-}\" ]] && [[ \"\$NO_PROXY\" != *${host}* ]]; then
    mkdir -p /etc/profile.d
    echo 'export NO_PROXY=\"\${NO_PROXY},${host}\"' >> /etc/profile.d/harbor-no-proxy.sh
    echo 'export no_proxy=\"\${no_proxy},${host}\"' >> /etc/profile.d/harbor-no-proxy.sh
fi
" 2>/dev/null || log_warn "节点 ${node} 更新 NO_PROXY 失败，可手动检查"

        # 5) 清理 Docker 从 WSL /etc/resolv.conf 继承的异常 search/domain。
        #    WSL/VPN 场景可能出现 `search 172.16.8.0/22` 这类 CIDR 字段，Pod 继承后会把
        #    *.svc.cluster.local 先拼成 *.svc.cluster.local.172.16.8.0/22，导致 CoreDNS 转发超时。
        docker exec "$node" bash -lc '
set -euo pipefail
cat >/usr/local/bin/kind-clean-resolv.sh <<EOF
#!/bin/sh
set -eu
if grep -Eq "^(search|domain)[[:space:]]" /etc/resolv.conf; then
    cp /etc/resolv.conf /etc/resolv.conf.kind-backup 2>/dev/null || true
    sed -E "/^(search|domain)[[:space:]]/d" /etc/resolv.conf > /tmp/resolv.conf.kind-clean
    cat /tmp/resolv.conf.kind-clean > /etc/resolv.conf
    rm -f /tmp/resolv.conf.kind-clean
fi
EOF
chmod +x /usr/local/bin/kind-clean-resolv.sh

mkdir -p /etc/systemd/system
cat >/etc/systemd/system/kind-clean-resolv.service <<EOF
[Unit]
Description=Remove invalid DNS search/domain entries inherited by Kind node containers
After=network-online.target
Before=containerd.service kubelet.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kind-clean-resolv.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable kind-clean-resolv.service >/dev/null 2>&1 || true

if grep -Eq "^(search|domain)[[:space:]]" /etc/resolv.conf; then
    cp /etc/resolv.conf /etc/resolv.conf.kind-backup 2>/dev/null || true
    sed -E "/^(search|domain)[[:space:]]/d" /etc/resolv.conf > /tmp/resolv.conf.kind-clean
    cat /tmp/resolv.conf.kind-clean > /etc/resolv.conf
    rm -f /tmp/resolv.conf.kind-clean
fi
' || log_warn "节点 ${node} 清理 /etc/resolv.conf search/domain 失败，可手动检查"

        # 6) 提高 inotify 与 fd 限制，避免重启后 containerd CRI 插件因 fsnotify watcher 不足而无法加载。
        docker exec "$node" bash -lc '
set -euo pipefail
cat >/etc/sysctl.d/99-kind-inotify.conf <<EOF
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.inotify.max_queued_events=65536
EOF
sysctl -p /etc/sysctl.d/99-kind-inotify.conf >/dev/null 2>&1 || true

mkdir -p /etc/systemd/system/containerd.service.d /etc/systemd/system/kubelet.service.d
cat >/etc/systemd/system/containerd.service.d/99-nofile.conf <<EOF
[Service]
LimitNOFILE=1048576
EOF
cat >/etc/systemd/system/kubelet.service.d/99-nofile.conf <<EOF
[Service]
LimitNOFILE=1048576
EOF
' || log_warn "节点 ${node} 更新 inotify/NOFILE 限制失败，可手动检查"

        # 7) 重启 containerd/kubelet，使新配置立即生效
        if ! docker exec "$node" bash -lc 'systemctl daemon-reload; systemctl restart containerd; systemctl restart kubelet'; then
            log_warn "节点 ${node} 重启 containerd/kubelet 失败，新配置可能在下次节点重启后才生效"
        fi
    done

    log_success "已在 ${#nodes[@]} 个 Kind 节点写入 Harbor TLS 信任配置（根 CA + certs.d/hosts.toml）"
}

main "$@"
