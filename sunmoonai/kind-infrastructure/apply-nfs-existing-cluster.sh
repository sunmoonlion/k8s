#!/usr/bin/env bash
#
# 对现成集群（如 Kind）部署 NFS Provisioner，连接 WSL 宿主机上的 NFS 服务
# 前置：WSL 上已安装并启动 nfs-kernel-server，已 export /data/kind-nfs
# 使用当前 KUBECONFIG；供 Kind 使用，与远程 Step09 NFS 方案一致（同款 provisioner）
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"

PROVISIONER_NAME="nfs-provisioner-kind"
# Chart 创建的 Deployment 名为 release名-nfs-subdir-external-provisioner
DEPLOYMENT_NAME="${PROVISIONER_NAME}-nfs-subdir-external-provisioner"
# Kind 节点（容器）访问 WSL 宿主机：Docker 桥接网段一般为 172.17.0.1，可覆盖
KIND_NFS_SERVER_HOST="${KIND_NFS_SERVER_HOST:-172.17.0.1}"
KIND_NFS_PATH="${KIND_NFS_PATH:-/data/kind-nfs}"
# StorageClass 名称：与远程 dev 常用 nfs-2 一致，便于 values 复用
KIND_NFS_STORAGE_CLASS_NAME="${KIND_NFS_STORAGE_CLASS_NAME:-nfs-2}"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
    NFS_PROVISIONER_VERSION="${STEP09_NFS_PROVISIONER_VERSION:-4.0.2}"
    NFS_RECLAIM_POLICY="${STEP09_NFS_STORAGE_RECLAIM_POLICY:-Delete}"
    NFS_VOLUME_BINDING_MODE="${STEP09_NFS_STORAGE_VOLUME_BINDING_MODE:-Immediate}"
    HELM_NAMESPACE="${STEP09_HELM_NAMESPACE:-kube-system}"
}

main() {
    log_info "对现成集群部署 NFS Provisioner（连接宿主机 NFS：${KIND_NFS_SERVER_HOST}:${KIND_NFS_PATH}）"
    if ! kubectl cluster-info &>/dev/null; then
        log_error "当前 KUBECONFIG 无法访问集群，请先设置 KUBECONFIG 或连接管理器"
        exit 1
    fi
    if ! command -v helm &>/dev/null; then
        log_error "未找到 helm，请先安装 Helm"
        exit 1
    fi

    load_config

    # 1. Helm 仓库
    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ 2>/dev/null || true
    helm repo update

    # 2. 安装 NFS Provisioner（不自动创建 StorageClass）
    # 若 release 存在但 deployment 不存在（首次安装失败），先卸载再装
    if helm status "$PROVISIONER_NAME" -n "$HELM_NAMESPACE" &>/dev/null; then
        if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$HELM_NAMESPACE" &>/dev/null; then
            log_warn "Helm release 存在但 Deployment 不存在，卸载后重新安装"
            helm uninstall "$PROVISIONER_NAME" -n "$HELM_NAMESPACE" 2>/dev/null || true
        else
            log_info "NFS Provisioner 已存在，跳过安装"
        fi
    fi
    if ! helm status "$PROVISIONER_NAME" -n "$HELM_NAMESPACE" &>/dev/null || ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$HELM_NAMESPACE" &>/dev/null; then
        log_info "安装 NFS Provisioner（v${NFS_PROVISIONER_VERSION}）"
        helm install "$PROVISIONER_NAME" nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
            --namespace "$HELM_NAMESPACE" \
            --set image.repository=registry.k8s.io/sig-storage/nfs-subdir-external-provisioner \
            --set image.tag="v${NFS_PROVISIONER_VERSION}" \
            --set nfs.server="${KIND_NFS_SERVER_HOST}" \
            --set nfs.path="${KIND_NFS_PATH}" \
            --set storageClass.create=false \
            --set nfs.mountOptions[0]=rw \
            --set nfs.mountOptions[1]=sync \
            --set nfs.mountOptions[2]=hard \
            --set nfs.mountOptions[3]=intr \
            --set nfs.reclaimPolicy="${NFS_RECLAIM_POLICY}" \
            --version "$NFS_PROVISIONER_VERSION"
        # 等待 Deployment 就绪（Chart 的 deployment 名为 release名-nfs-subdir-external-provisioner）
        kubectl wait --for=condition=available "deployment/${DEPLOYMENT_NAME}" -n "$HELM_NAMESPACE" --timeout=120s || true
        log_success "NFS Provisioner 已就绪"
    fi

    # 3. 创建 StorageClass（与远程 nfs-2 等一致，便于 dev-values 复用）
    kubectl delete storageclass "$KIND_NFS_STORAGE_CLASS_NAME" --ignore-not-found=true 2>/dev/null || true
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${KIND_NFS_STORAGE_CLASS_NAME}
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: cluster.local/${PROVISIONER_NAME}-nfs-subdir-external-provisioner
volumeBindingMode: ${NFS_VOLUME_BINDING_MODE}
reclaimPolicy: ${NFS_RECLAIM_POLICY}
EOF
    log_success "StorageClass ${KIND_NFS_STORAGE_CLASS_NAME} 已创建"

    log_success "NFS 存储初始化完成"
    log_info "部署时由 values（如 dev-values）指定 storageClassName: ${KIND_NFS_STORAGE_CLASS_NAME} 即可，Kind 与远程一致"
}

main "$@"
