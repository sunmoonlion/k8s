#!/usr/bin/env bash
#
# Kind 环境下通过 unified-cert-secret-management 生成本地根 CA，与远程 Step12 完全共用同一套配置与流程。
# 使用 cert-secret.conf 中的 TRAEFIK_KIND_KIND combo，仅执行 init 模式（只生成 CA 到 LOCAL_CA_CERT_DIR，不 SSH 分发）。
# 供后续 Traefik 服务器证书、Harbor 等部署使用。
# 若在 WSL 且存在 /mnt/c，会将 ca.crt 同步到 Docker Desktop 的 certs.d，便于宿主机/WSL 从私有 Harbor 拉镜像（无需 insecure-registries）。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UNIFIED_CERT_DIR="$K8S_ROOT/utils/unified-cert-secret-management"
DEPLOY_SCRIPT="$UNIFIED_CERT_DIR/deploy-all.sh"
# 与 cert-secret.conf 中 TRAEFIK_KIND_KIND_LOCAL_CA_CERT_DIR / TRAEFIK_K1_K1_LOCAL_CA_CERT_DIR 一致
CA_SOURCE_DIR="${K8S_ROOT}/sunmoonai/ingress-platform/traefik/deploy-traefik/secrets/traefik-tls-secret/ca"
# unified-cert 在 init 模式下会先把 CA 生到 /tmp/<组合代码>-ca-certs 目录，
# 组合 TRAEFIK_KIND_KIND 在内部使用 TRAEFIK_KI_KI 作为组合代码
TMP_CA_DIR="/tmp/TRAEFIK_KI_KI-ca-certs"
# Docker Desktop 在 Windows 下的 certs.d（WSL 中访问路径）；私有仓库 host:port
DOCKER_CERTS_D_WSL="${DOCKER_DESKTOP_CERTS_D:-/mnt/c/ProgramData/docker/certs.d}"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-harbor.sunmoonai.com:30443}"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

if [[ ! -f "$DEPLOY_SCRIPT" ]]; then
    log_error "未找到 unified-cert-secret-management: $DEPLOY_SCRIPT"
    exit 1
fi

log_info "Kind 根 CA：调用 unified-cert-secret-management init（combo TRAEFIK_KIND_KIND，与远程 Step12 共用配置）"
cd "$UNIFIED_CERT_DIR" || { log_error "无法进入 $UNIFIED_CERT_DIR"; exit 1; }
if TLS_MODE=init bash "$DEPLOY_SCRIPT" init TRAEFIK_KIND_KIND; then
    log_success "根 CA 已由统一证书管理生成，后续 Traefik/Harbor 等部署可据此签发服务器证书"
else
    log_error "unified-cert init 失败"
    exit 1
fi

# 确保当前用户路径下存在 CA：如有必要从 unified-cert 的临时目录复制一份
if [[ ! -f "$CA_SOURCE_DIR/ca.crt" || ! -f "$CA_SOURCE_DIR/ca.key" ]]; then
    if [[ -f "$TMP_CA_DIR/ca.crt" && -f "$TMP_CA_DIR/ca.key" ]]; then
        log_info "在 unified-cert 临时目录下检测到 CA，准备同步到当前用户目录: $CA_SOURCE_DIR"
        mkdir -p "$CA_SOURCE_DIR"
        if cp "$TMP_CA_DIR/ca.crt" "$CA_SOURCE_DIR/ca.crt" && cp "$TMP_CA_DIR/ca.key" "$CA_SOURCE_DIR/ca.key"; then
            log_success "已从 $TMP_CA_DIR 同步 CA 到 $CA_SOURCE_DIR"
        else
            log_warn "无法从 $TMP_CA_DIR 同步 CA 到 $CA_SOURCE_DIR，请检查权限"
        fi
    else
        log_warn "未在 $CA_SOURCE_DIR 或 $TMP_CA_DIR 找到完整 CA 文件，后续 Traefik/Harbor 可能无法生成服务器证书"
    fi
fi

# 若在 WSL 且能访问 Windows 盘，将根 CA 放入 Docker Desktop certs.d，便于 docker pull 信任私有 Harbor
if [[ -f "$CA_SOURCE_DIR/ca.crt" ]] && [[ -d "$DOCKER_CERTS_D_WSL" ]]; then
    dest_dir="$DOCKER_CERTS_D_WSL/$HARBOR_REGISTRY"
    mkdir -p "$dest_dir"
    cp "$CA_SOURCE_DIR/ca.crt" "$dest_dir/ca.crt"
    log_success "已同步根 CA 到 Docker Desktop certs.d: $dest_dir/ca.crt（宿主机可从私有仓库拉镜像，无需 insecure-registries）"
    log_info "若仍无法拉取，请重启 Docker Desktop 后重试"
elif [[ -f "$CA_SOURCE_DIR/ca.crt" ]] && [[ ! -d "$DOCKER_CERTS_D_WSL" ]]; then
    log_warn "未检测到 Docker Desktop certs.d 目录（$DOCKER_CERTS_D_WSL），未同步 ca.crt；若需宿主机信任 Harbor，请手动将 $CA_SOURCE_DIR/ca.crt 放入该目录下 $HARBOR_REGISTRY/"
fi
