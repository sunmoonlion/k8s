#!/usr/bin/env bash
#
# 对现成集群应用本地存储 local-path（与 Step09 本地存储配置同源）
# 使用当前 KUBECONFIG，不 SSH；供 Kind 或任意已有集群使用。
# 详见《现成集群平台初始化.md》
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"
LOCAL_PATH_MANIFEST_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
    STEP09_LOCAL_STORAGE_CLASS_NAME="${STEP09_LOCAL_STORAGE_CLASS_NAME:-local-storage}"
    STEP09_LOCAL_STORAGE_DEFAULT_CLASS="${STEP09_LOCAL_STORAGE_DEFAULT_CLASS:-true}"
    STEP09_LOCAL_STORAGE_RECLAIM_POLICY="${STEP09_LOCAL_STORAGE_RECLAIM_POLICY:-Delete}"
    STEP09_LOCAL_STORAGE_VOLUME_BINDING_MODE="${STEP09_LOCAL_STORAGE_VOLUME_BINDING_MODE:-WaitForFirstConsumer}"
    STEP09_LOCAL_STORAGE_VERSION="${STEP09_LOCAL_STORAGE_VERSION:-v0.0.32}"
}

main() {
    log_info "对现成集群应用本地存储 local-path（配置与 Step09 同源）"
    if ! kubectl cluster-info &>/dev/null; then
        log_error "当前 KUBECONFIG 无法访问集群，请先设置 KUBECONFIG 或连接管理器"
        exit 1
    fi

    load_config
    local image_tag="rancher/local-path-provisioner:${STEP09_LOCAL_STORAGE_VERSION}"

    # 1. 安装 local-path-provisioner（与 Step09 同源 manifest）
    if kubectl get deployment local-path-provisioner -n local-path-storage &>/dev/null; then
        log_info "local-path-provisioner 已存在，跳过安装"
    else
        log_info "安装 local-path-provisioner（${STEP09_LOCAL_STORAGE_VERSION}）"
        if ! curl -sL "$LOCAL_PATH_MANIFEST_URL" | sed "s|rancher/local-path-provisioner:.*|$image_tag|g" | kubectl apply -f -; then
            log_error "无法拉取或应用 manifest，请检查网络或 KUBECONFIG"
            exit 1
        fi
        kubectl wait --for=condition=ready pod -l app=local-path-provisioner -n local-path-storage --timeout=120s
        log_success "local-path-provisioner 已就绪"
    fi

    # 2. 删除 manifest 自带的 StorageClass "local-path"，改用 conf 中的名称与策略
    kubectl delete storageclass local-path --ignore-not-found=true 2>/dev/null || true
    kubectl delete storageclass "${STEP09_LOCAL_STORAGE_CLASS_NAME}" --ignore-not-found=true 2>/dev/null || true

    # 3. 创建 StorageClass（与 Step09 一致）
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STEP09_LOCAL_STORAGE_CLASS_NAME}
  annotations:
    storageclass.kubernetes.io/is-default-class: "${STEP09_LOCAL_STORAGE_DEFAULT_CLASS}"
provisioner: rancher.io/local-path
volumeBindingMode: ${STEP09_LOCAL_STORAGE_VOLUME_BINDING_MODE}
reclaimPolicy: ${STEP09_LOCAL_STORAGE_RECLAIM_POLICY}
EOF
    log_success "StorageClass ${STEP09_LOCAL_STORAGE_CLASS_NAME} 已创建"

    # 4. 若为默认，移除其它 StorageClass 的 default 注解
    if [[ "${STEP09_LOCAL_STORAGE_DEFAULT_CLASS}" == "true" ]]; then
        log_info "设为默认 StorageClass，移除其它 default 注解"
        kubectl get sc -o name | while read -r sc; do
            name="${sc#storageclass.storage.k8s.io/}"
            [[ "$name" == "${STEP09_LOCAL_STORAGE_CLASS_NAME}" ]] && continue
            kubectl patch sc "$name" -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' 2>/dev/null || true
        done
    fi

    log_success "本地存储初始化完成"
}

main "$@"
