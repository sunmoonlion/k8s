#!/usr/bin/env bash
#
# 对现成集群应用命名空间（与 Step07 配置同源）
# 使用当前 KUBECONFIG，不 SSH；供 Kind 或任意已有集群使用。
# 详见《kind使用指南.md》第 5.7 节
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

# 加载配置（与远程同源）
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # 只 source，不依赖 SERVER_* 等
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
    NAMESPACE_PLATFORM_ENVIRONMENTS="${NAMESPACE_PLATFORM_ENVIRONMENTS:-dev,prod}"
    NAMESPACE_PLATFORM_PLATFORMS="${NAMESPACE_PLATFORM_PLATFORMS:-app-platform,cicd-platform,data-platform,infrastructure,ingress-platform,messaging-platform,ops-platform}"
    NAMESPACE_PLATFORM_APPLY_POLICIES="${NAMESPACE_PLATFORM_APPLY_POLICIES:-true}"
}

# 解析逗号分隔列表（去引号、trim、去空）
parse_list() {
    local raw="${1//\"/}"
    local -a out=()
    IFS=',' read -ra arr <<< "$raw"
    for x in "${arr[@]}"; do
        x="${x#"${x%%[![:space:]]*}"}"
        x="${x%"${x##*[![:space:]]}"}"
        [[ -n "$x" ]] && out+=("$x")
    done
    echo "${out[@]}"
}

apply_namespace_policies() {
    local namespace="$1"
    if [[ "${NAMESPACE_PLATFORM_APPLY_POLICIES:-false}" != "true" ]]; then
        return 0
    fi
    log_info "应用命名空间策略: $namespace（占位，与 Step07 一致）"
}

main() {
    log_info "对现成集群应用命名空间（配置与 Step07 同源）"
    if ! kubectl cluster-info &>/dev/null; then
        log_error "当前 KUBECONFIG 无法访问集群，请先设置 KUBECONFIG 或连接管理器"
        exit 1
    fi

    load_config
    local envs; envs=($(parse_list "$NAMESPACE_PLATFORM_ENVIRONMENTS"))
    local platforms; platforms=($(parse_list "$NAMESPACE_PLATFORM_PLATFORMS"))
    log_info "环境: ${envs[*]}  平台: ${platforms[*]}"

    # Kind 默认仅有名为 standard 的 local-path StorageClass；与 values 中的 local-path 对齐
    local sc_manifest="${SCRIPT_DIR}/manifests/storageclass-local-path.yaml"
    if [[ -f "$sc_manifest" ]]; then
        if kubectl get storageclass local-path &>/dev/null; then
            log_info "StorageClass local-path 已存在，跳过创建"
        else
            kubectl apply -f "$sc_manifest"
            log_success "已应用 StorageClass local-path（与 rancher.io/local-path 兼容）"
        fi
    fi

    for env in "${envs[@]}"; do
        for platform in "${platforms[@]}"; do
            local namespace="${platform}-${env}"
            if kubectl get namespace "$namespace" &>/dev/null; then
                log_info "命名空间已存在: $namespace"
            else
                kubectl create namespace "$namespace"
                log_success "创建命名空间: $namespace"
            fi
            apply_namespace_policies "$namespace"
        done
    done

    log_success "命名空间平台初始化完成"
}

main "$@"
