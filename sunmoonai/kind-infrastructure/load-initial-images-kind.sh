#!/usr/bin/env bash
#
# Kind 等效于远程 Step11 的「初始镜像加载」：在宿主机上 docker pull 后 kind load 到集群，
# 便于在尚未部署 Harbor 前就能部署 Traefik、Harbor 等组件。
# 镜像列表与 deploy-infrastructure-all.conf 中 STEP_IMAGE_* 同源，未配置时使用与 Step11 相同的默认列表。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ADMIN_CONF="${SCRIPT_DIR}/../../utils/k8s-admin.conf"
INFRA_CONF="${SCRIPT_DIR}/../../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"

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

# 与 Step11 默认列表一致
default_image_list() {
    echo "traefik:v3.5.2"
    echo "bitnami/harbor-core:2.13.2-debian-12-r3"
    echo "bitnami/harbor-portal:2.13.2-debian-12-r1"
    echo "bitnami/harbor-jobservice:2.13.2-debian-12-r3"
    echo "bitnami/harbor-registry:2.13.2-debian-12-r2"
    echo "bitnami/harbor-registryctl:2.13.2-debian-12-r3"
    echo "bitnami/harbor-adapter-trivy:2.13.2-debian-12-r2"
    echo "bitnami/harbor-exporter:2.13.2-debian-12-r2"
    echo "bitnami/nginx:1.29.1-debian-12-r0"
    echo "bitnami/redis:8.2.1-debian-12-r0"
    echo "bitnami/postgresql:17.6.0-debian-12-r4"
    echo "bitnami/os-shell:12-debian-12-r50"
}

# 从 deploy-infrastructure-all.conf 读取 STEP_IMAGE_*
read_image_list() {
    local list=()
    if [[ -f "$INFRA_CONF" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            list+=("$line")
        done < <(grep -E '^STEP_IMAGE_[0-9]+="' "$INFRA_CONF" 2>/dev/null | sed 's/^STEP_IMAGE_[0-9]*="\(.*\)"$/\1/' | sort -u)
    fi
    if [[ ${#list[@]} -eq 0 ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && list+=("$line")
        done < <(default_image_list)
        log_info "使用默认镜像列表（与 Step11 一致），共 ${#list[@]} 个"
    else
        log_info "从 $INFRA_CONF 读取 STEP_IMAGE_*，共 ${#list[@]} 个"
    fi
    printf '%s\n' "${list[@]}"
}

read_kind_config
if ! kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
    log_error "Kind 集群 ${KIND_CLUSTER_NAME} 不存在，请先执行 ./kind-up.sh 创建集群"
    exit 1
fi

IMAGE_LIST=()
while IFS= read -r line; do
    [[ -n "$line" ]] && IMAGE_LIST+=("$line")
done < <(read_image_list)

if [[ ${#IMAGE_LIST[@]} -eq 0 ]]; then
    log_error "镜像列表为空"
    exit 1
fi

log_info "开始拉取并加载镜像到 Kind 集群 ${KIND_CLUSTER_NAME}（等效远程 Step11）"
ok=0
fail=0
for img in "${IMAGE_LIST[@]}"; do
    if docker pull "$img" 2>/dev/null; then
        if kind load docker-image "$img" --name "$KIND_CLUSTER_NAME" 2>/dev/null; then
            log_success "已加载: $img"
            ((ok++)) || true
        else
            log_warn "kind load 失败: $img"
            ((fail++)) || true
        fi
    else
        log_warn "docker pull 失败（跳过）: $img"
        ((fail++)) || true
    fi
done
log_info "完成: 成功 $ok, 失败/跳过 $fail"
exit 0
