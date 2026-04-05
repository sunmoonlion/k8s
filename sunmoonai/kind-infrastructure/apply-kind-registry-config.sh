#!/usr/bin/env bash
#
# 在 Kind 各节点内写入 containerd 的镜像拉取配置（/etc/containerd/certs.d/），
# 与远程 Step02 的 registry mirrors / direct 逻辑对齐，实现「本地 Harbor → 官方」的拉取顺序。
# 配置来源：deploy-infrastructure-all.conf 的 STEP02_REGISTRY_*（可与 deploy-kind.conf 覆写）。
# 应在 kind-up.sh 之后、load-images/load-kind-images.sh 之前执行，以便与远程 Step02→Step11 顺序一致。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"
# 从 kind-infrastructure 到 sunmoonai/infrastructure，只需返回一层到 sunmoonai 再进入 infrastructure
INFRA_CONF="${SCRIPT_DIR}/../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

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

# 从 infra 配置读 STEP02_REGISTRY_*；若调用方已通过环境变量传入则优先使用（如 deploy-kind.conf 覆写）
load_registry_config() {
    REG_ENABLE="${STEP02_REGISTRY_ENABLE:-false}"
    REG_MIRRORS_RAW="${STEP02_REGISTRY_MIRRORS:-}"
    REG_DIRECT_RAW="${STEP02_REGISTRY_DIRECT:-}"
    if [[ -f "$INFRA_CONF" ]]; then
        while IFS= read -r line; do
            [[ "$line" =~ ^STEP02_REGISTRY_ENABLE= ]] && REG_ENABLE="${line#*=}"
            [[ "$line" =~ ^STEP02_REGISTRY_MIRRORS= ]] && REG_MIRRORS_RAW="${line#*=}"
            [[ "$line" =~ ^STEP02_REGISTRY_DIRECT= ]] && REG_DIRECT_RAW="${line#*=}"
        done < <(grep -E '^STEP02_REGISTRY_(ENABLE|MIRRORS|DIRECT)=' "$INFRA_CONF" 2>/dev/null || true)
    fi
    # 去除可能的引号；环境变量覆写（deploy-kind.conf 中 export 后传入）
    REG_ENABLE="${REG_ENABLE//\"/}"
    REG_MIRRORS_RAW="${REG_MIRRORS_RAW//\"/}"
    REG_DIRECT_RAW="${REG_DIRECT_RAW//\"/}"
    # 下面三行在“未设置环境变量”时 [[ -n '' ]] 为假返回 1，set -e 会误杀脚本，故加 || true
    [[ -n "${STEP02_REGISTRY_ENABLE+set}" ]] && REG_ENABLE="${STEP02_REGISTRY_ENABLE//\"/}" || true
    [[ -n "${STEP02_REGISTRY_MIRRORS+set}" ]] && REG_MIRRORS_RAW="${STEP02_REGISTRY_MIRRORS//\"/}" || true
    [[ -n "${STEP02_REGISTRY_DIRECT+set}" ]] && REG_DIRECT_RAW="${STEP02_REGISTRY_DIRECT//\"/}" || true
}

# 在临时目录生成与 Step02 一致的 certs.d 目录结构
generate_certs_d() {
    local root="$1"
    mkdir -p "$root"
    local dir file content ep dir_host server_url

    # mirrors: registry=ep1,ep2;registry2=...
    if [[ -n "${REG_MIRRORS_RAW:-}" ]]; then
        IFS=';' read -r -a mappings <<< "${REG_MIRRORS_RAW}"
        for kv in "${mappings[@]}"; do
            [[ -z "$kv" ]] && continue
            reg="${kv%%=*}"; reg="${reg//[[:space:]]/}"
            eps="${kv#*=}"
            [[ -z "$reg" || -z "$eps" ]] && continue
            dir="$root/$reg"
            mkdir -p "$dir"
            file="$dir/hosts.toml"
            content="server = \"https://$reg\""
            IFS=',' read -r -a arr <<< "$eps"
            for ep in "${arr[@]}"; do
                ep="${ep//[[:space:]]/}"
                [[ -z "$ep" ]] && continue
                case "$ep" in http://*|https://*) ;; *) ep="http://$ep" ;; esac
                content="$content"$'\n'"[host.\"$ep\"]"$'\n'"  capabilities = [\"pull\", \"resolve\"]"
            done
            printf '%s\n' "$content" > "$file"
        done
    fi

    # direct
    if [[ -n "${REG_DIRECT_RAW:-}" ]]; then
        raw="${REG_DIRECT_RAW}"
        server_url="$raw"
        if [[ "$raw" != http://* && "$raw" != https://* ]]; then
            if [[ "$raw" == *:443 ]]; then server_url="https://$raw"; else server_url="http://$raw"; fi
        fi
        dir_host="$raw"
        if [[ "$raw" == http://* || "$raw" == https://* ]]; then dir_host="${raw#*://}"; fi
        dir="$root/$dir_host"
        mkdir -p "$dir"
        file="$dir/hosts.toml"
        printf 'server = "%s"\n[host."%s"]\n  capabilities = ["pull", "push", "resolve"]\n' "$server_url" "$server_url" > "$file"
    fi
}

main() {
    read_kind_config
    load_registry_config

    if [[ "$REG_ENABLE" != "true" ]]; then
        log_info "STEP02_REGISTRY_ENABLE 未启用，跳过 Kind 节点 registry 配置"
        exit 0
    fi
    if [[ -z "${REG_MIRRORS_RAW:-}" && -z "${REG_DIRECT_RAW:-}" ]]; then
        log_info "未配置 STEP02_REGISTRY_MIRRORS / STEP02_REGISTRY_DIRECT，跳过"
        exit 0
    fi

    if ! command -v kind &>/dev/null; then
        log_warn "未找到 kind 命令，跳过 registry 配置"
        exit 0
    fi
    if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        log_warn "Kind 集群 $KIND_CLUSTER_NAME 不存在，跳过 registry 配置"
        exit 0
    fi

    tmpdir=""
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    generate_certs_d "$tmpdir"

    nodes=()
    while IFS= read -r n; do
        [[ -n "$n" ]] && nodes+=("$n")
    done < <(kind get nodes --name "$KIND_CLUSTER_NAME" 2>/dev/null || true)
    if [[ ${#nodes[@]} -eq 0 ]]; then
        log_warn "未获取到 Kind 节点列表，跳过"
        exit 0
    fi

    for node in "${nodes[@]}"; do
        log_info "在节点 $node 写入 containerd certs.d 配置"
        for reg_dir in "$tmpdir"/*/; do
            [[ -d "$reg_dir" ]] || continue
            reg_name="$(basename "$reg_dir")"
            docker exec "$node" mkdir -p "/etc/containerd/certs.d/$reg_name"
            docker cp "$reg_dir/hosts.toml" "$node:/etc/containerd/certs.d/$reg_name/hosts.toml"
        done
        # 使 containerd 重新读取配置（部分版本需重启进程）
        if docker exec "$node" kill -HUP 1 2>/dev/null; then
            :
        else
            log_info "节点 $node：发送 SIGHUP 未生效时，新配置将在下次拉取或节点重启后生效"
        fi
    done
    log_success "已在 ${#nodes[@]} 个 Kind 节点写入 registry 配置（与远程 Step02 对齐）"
}

main "$@"
