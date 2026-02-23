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
# Kind 节点访问 NFS 宿主机：必须用 WSL 本机 IP（ifconfig eth0 的 inet），未设置时自动取 hostname -I 首地址；不能用 172.18.0.1/172.17.0.1（Docker 桥，不转发 NFS）
_detect_nfs_host() {
    [[ -n "${KIND_NFS_SERVER_HOST:-}" ]] && return
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}' | grep -E '^[0-9.]+$')
    if [[ -n "$ip" ]]; then
        KIND_NFS_SERVER_HOST="$ip"
    else
        KIND_NFS_SERVER_HOST="172.18.0.1"
    fi
}
_detect_nfs_host
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
    # Chart 版本：4.0.18 从 repo 拉取更稳；若需 4.0.2 可设 STEP09_NFS_CHART_VERSION=4.0.2 或放 tgz 到 charts/
    NFS_CHART_VERSION="${STEP09_NFS_CHART_VERSION:-4.0.18}"
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

    # 若 deploy-kind.conf 里配置了 HTTP_PROXY_WSL/HTTPS_PROXY_WSL，则在本次脚本中生效（WSL 连 GitHub 用 Windows 代理）
    KIND_DEPLOY_CONF="${SCRIPT_DIR}/deploy-kind/deploy-kind.conf"
    if [[ -f "$KIND_DEPLOY_CONF" ]]; then
        # shellcheck disable=SC1090
        source "$KIND_DEPLOY_CONF" 2>/dev/null || true
        if [[ -n "${HTTP_PROXY_WSL:-}" ]]; then
            export HTTP_PROXY="${HTTP_PROXY_WSL}"
            export HTTPS_PROXY="${HTTPS_PROXY_WSL:-$HTTP_PROXY_WSL}"
            log_info "使用代理下载 chart: HTTPS_PROXY=$HTTPS_PROXY"
        fi
    fi

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
        # 若刚卸载过，旧 PVC 可能仍在 Terminating，等待消失后再安装，避免新 Pod 因 "pvc not found" 一直 Pending
        pvc_name="pvc-nfs-provisioner-kind-nfs-subdir-external-provisioner"
        for _ in {1..30}; do
            if ! kubectl get pvc "$pvc_name" -n "$HELM_NAMESPACE" &>/dev/null; then break; fi
            log_info "等待旧 PVC $pvc_name 删除完成..."
            sleep 1
        done
        log_info "安装 NFS Provisioner（chart ${NFS_CHART_VERSION}，image v${NFS_PROVISIONER_VERSION}）"
        chart_installed=false
        # 优先使用本地 chart（网络不好时可将 tgz 放到 charts/ 或设 NFS_CHART_TGZ）
        local_chart="${NFS_CHART_TGZ:-$SCRIPT_DIR/charts/nfs-subdir-external-provisioner-${NFS_CHART_VERSION}.tgz}"
        if [[ -f "$local_chart" ]]; then
            log_info "使用本地 chart: $local_chart"
            if helm install "$PROVISIONER_NAME" "$local_chart" \
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
                --set nfs.mountOptions[4]=vers=3 \
                --set nfs.mountOptions[5]=proto=tcp \
                --set nfs.mountOptions[6]=nolock \
                --set nfs.reclaimPolicy="${NFS_RECLAIM_POLICY}"; then
                chart_installed=true
            fi
        fi
        if [[ "$chart_installed" != "true" ]] && helm install "$PROVISIONER_NAME" nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
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
            --set nfs.mountOptions[4]=vers=3 \
            --set nfs.mountOptions[5]=proto=tcp \
            --set nfs.mountOptions[6]=nolock \
            --set nfs.reclaimPolicy="${NFS_RECLAIM_POLICY}" \
            --version "$NFS_CHART_VERSION"; then
            chart_installed=true
        else
            log_warn "从 repo 安装失败（多为网络/EOF），尝试用 curl 下载 chart 后本地安装（会走 HTTP_PROXY/HTTPS_PROXY）..."
            chart_tgz="/tmp/nfs-subdir-external-provisioner-${NFS_CHART_VERSION}.tgz"
            chart_url="https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/releases/download/nfs-subdir-external-provisioner-${NFS_CHART_VERSION}/nfs-subdir-external-provisioner-${NFS_CHART_VERSION}.tgz"
            if curl -L -f --connect-timeout 15 --max-time 90 -o "$chart_tgz" "$chart_url"; then
                if helm install "$PROVISIONER_NAME" "$chart_tgz" \
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
                    --set nfs.mountOptions[4]=vers=3 \
                    --set nfs.mountOptions[5]=proto=tcp \
                    --set nfs.mountOptions[6]=nolock \
                    --set nfs.reclaimPolicy="${NFS_RECLAIM_POLICY}"; then
                    chart_installed=true
                fi
            fi
            [[ -f "$chart_tgz" ]] && rm -f "$chart_tgz"
        fi
        if [[ "$chart_installed" != "true" ]]; then
            log_error "NFS Provisioner 安装失败，请检查网络或设置 HTTPS_PROXY 后重试"
            exit 1
        fi
        # 等待 Deployment 就绪（最多 60s；超时不阻塞，Pod 可能仍在挂载 NFS）
        if kubectl wait --for=condition=available "deployment/${DEPLOYMENT_NAME}" -n "$HELM_NAMESPACE" --timeout=60s 2>/dev/null; then
            log_success "NFS Provisioner 已就绪"
        else
            log_warn "等待 Pod 就绪超时，请稍后执行: kubectl get pods -n kube-system -l app=nfs-subdir-external-provisioner"
        fi
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
    log_info "若 Pod 仍报 NFS 错误：确认脚本已用 WSL 本机 IP（hostname -I），或 WSL 自测: mount -t nfs -o vers=3,proto=tcp 127.0.0.1:${KIND_NFS_PATH} /mnt"
}

main "$@"
