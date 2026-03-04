#!/usr/bin/env bash
#
# Kind 一键部署：按顺序执行 NFS 检查/安装、创建集群与平台初始化、WSL Harbor 解析。
# 均在 WSL 中执行。可选参数见下方用法。配置见同目录 deploy-kind.conf。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 加载配置（可选）
if [[ -f "$SCRIPT_DIR/deploy-kind.conf" ]]; then
    source "$SCRIPT_DIR/deploy-kind.conf"
fi
export HARBOR_HOST HARBOR_NODE_IP 2>/dev/null || true

NFS_EXPORT_DIR="${NFS_EXPORT_DIR:-/data/kind-nfs}"
RUN_CA_INIT="${DEPLOY_KIND_RUN_CA_INIT:-true}"
RUN_REGISTRY_CONFIG="${DEPLOY_KIND_RUN_REGISTRY_CONFIG:-true}"
RUN_NFS_PROVISIONER="${DEPLOY_KIND_RUN_NFS_PROVISIONER:-true}"
RUN_HARBOR_HOSTS="${DEPLOY_KIND_RUN_HARBOR_HOSTS:-true}"

# 镜像来源模式归一化：根据 KIND_IMAGE_SOURCE 统筹相关开关
KIND_IMAGE_SOURCE="${KIND_IMAGE_SOURCE:-tar}"
case "$KIND_IMAGE_SOURCE" in
    harbor)
        # 使用集群内 Harbor 作为镜像源：保留 registry 配置与 Harbor hosts 步骤，关闭本地 tar 预加载
        RUN_REGISTRY_CONFIG=true
        DEPLOY_KIND_RUN_PRELOAD_IMAGES="false"
        ;;
    tar)
        # 使用本地 tar 预加载镜像：关闭 registry/hosts 相关步骤，仅运行本地预加载
        RUN_REGISTRY_CONFIG=false
        RUN_HARBOR_HOSTS=false
        DEPLOY_KIND_RUN_PRELOAD_IMAGES="true"
        ;;
    *)
        echo "⚠️  未知 KIND_IMAGE_SOURCE='${KIND_IMAGE_SOURCE}'，按 tar 模式处理" >&2
        KIND_IMAGE_SOURCE="tar"
        RUN_REGISTRY_CONFIG=false
        RUN_HARBOR_HOSTS=false
        DEPLOY_KIND_RUN_PRELOAD_IMAGES="true"
        ;;
esac

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

# 将相对路径（相对 deploy-kind 目录）转为绝对路径，与脚本执行目录无关
resolve_to_absolute() {
    local input="$1"
    local out=""
    local save_ifs="$IFS"
    IFS=','
    for item in $input; do
        item=$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$item" ]] && continue
        if [[ "$item" == /* ]]; then
            out="${out:+$out,}$item"
        else
            out="${out:+$out,}${SCRIPT_DIR}/${item}"
        fi
    done
    IFS="$save_ifs"
    echo "$out"
}

# 等待 Harbor 在指定地址就绪（/v2/ 可返回 JSON 即视为可用）
wait_for_harbor() {
    local host="${HARBOR_HOST:-harbor.sunmoonai.com}"
    local port="${HARBOR_PORT:-30443}"
    local timeout="${HARBOR_WAIT_TIMEOUT:-300}" # 最长等待秒数，默认 5 分钟
    local interval=5
    local start
    start=$(date +%s)

    log_info "等待 Harbor 就绪 (${host}:${port}，最长 ${timeout}s)..."
    while true; do
        # 不带凭证访问 /v2/，能返回 JSON（401/200）即认为 Harbor 已就绪
        if curl -sk --noproxy '*' "https://${host}:${port}/v2/" | grep -q '"errors"' ; then
            log_info "Harbor /v2/ 已响应"
            return 0
        fi
        local now
        now=$(date +%s)
        if (( now - start >= timeout )); then
            log_error "Harbor 在 ${timeout}s 内未就绪"
            return 1
        fi
        sleep "${interval}"
    done
}

# 确保 Harbor 中存在项目 k8s-images（若不存在则自动创建为公开项目）
ensure_harbor_project_k8s_images() {
    local api_base="https://${HARBOR_HOST:-harbor.sunmoonai.com}:${HARBOR_PORT:-30443}/api/v2.0"
    local proj="k8s-images"
    local user="${HARBOR_ADMIN_USER:-admin}"
    local pass="${HARBOR_ADMIN_PASSWORD:-}"

    if [[ -z "$pass" ]]; then
        log_warn "未提供 HARBOR_ADMIN_PASSWORD，跳过自动创建 Harbor 项目 ${proj}"
        return 0
    fi

    # 查询项目是否已存在（GET /projects 无匹配时也返回 200，body 为空数组，需根据响应体判断）
    local body
    body=$(curl -sk --noproxy '*' -u "${user}:${pass}" "${api_base}/projects?name=${proj}" 2>/dev/null || true)
    if echo "$body" | grep -qE '"name"\s*:\s*"'"${proj}"'"'; then
        log_info "Harbor 项目 ${proj} 已存在"
        return 0
    fi

    log_info "Harbor 项目 ${proj} 不存在，尝试自动创建..."
    code=$(curl -sk --noproxy '*' -u "${user}:${pass}" -o /dev/null -w '%{http_code}' \
        -H 'Content-Type: application/json' \
        -X POST "${api_base}/projects" \
        -d "{\"project_name\":\"${proj}\",\"metadata\":{\"public\":\"true\"}}" || echo "000")

    if [[ "$code" == "201" || "$code" == "409" ]]; then
        # 201: 创建成功；409: 已存在（并发等原因）
        log_info "Harbor 项目 ${proj} 已就绪（HTTP ${code}）"
        return 0
    fi

    log_error "自动创建 Harbor 项目 ${proj} 失败（HTTP ${code}），请手动在 Web 控制台创建该项目或调整配置"
    return 1
}

# 封装一次 Harbor 登录流程：等待就绪 + docker login + 确保项目存在
harbor_login_or_fail() {
    if ! wait_for_harbor; then
        log_error "Harbor 未就绪，终止 Harbor 登录流程"
        return 1
    fi

    if [[ -z "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
        log_error "未配置 HARBOR_ADMIN_PASSWORD，无法自动登录 Harbor"
        return 1
    fi

    login_host="${HARBOR_HOST:-harbor.sunmoonai.com}:${HARBOR_PORT:-30443}"
    log_info "登录 Harbor（${login_host}）..."
    if ! echo "${HARBOR_ADMIN_PASSWORD}" | docker login "${login_host}" -u "${HARBOR_ADMIN_USER:-admin}" --password-stdin; then
        log_error "docker login Harbor 失败"
        return 1
    fi

    # 在推送前确保 Harbor 中存在 k8s-images 项目（若失败则交由调用方决定是否终止）
    if ! ensure_harbor_project_k8s_images; then
        return 1
    fi

    return 0
}

usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --skip-ca-init          跳过本地根 CA 生成（ensure-kind-ca.sh，与远程 Step12 同用途）"
    echo "  --skip-registry-config  跳过 Kind 节点 containerd 镜像拉取配置（apply-kind-registry-config.sh）"
    echo "  --skip-nfs-provisioner  跳过集群内 NFS Provisioner 部署（apply-nfs-existing-cluster.sh）"
    echo "  --skip-harbor-hosts     跳过 WSL /etc/hosts 中 Harbor 域名配置"
    echo "  -h, --help           显示此帮助"
    echo "配置: $SCRIPT_DIR/deploy-kind.conf"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-ca-init)           RUN_CA_INIT=false; shift ;;
        --skip-registry-config)   RUN_REGISTRY_CONFIG=false; shift ;;
        --skip-nfs-provisioner)   RUN_NFS_PROVISIONER=false; shift ;;
        --skip-harbor-hosts)      RUN_HARBOR_HOSTS=false; shift ;;
        -h|--help)           usage; exit 0 ;;
        *)                   log_error "未知选项: $1"; usage; exit 1 ;;
    esac
done

log_info "Kind 一键部署开始（步骤 1/7：NFS）"
if ! [[ -f /etc/exports ]] || ! grep -qE "^${NFS_EXPORT_DIR}[[:space:]]" /etc/exports 2>/dev/null; then
    log_info "未检测到 NFS 导出，执行 wsl-setup-nfs-server.sh ..."
    "$KIND_ROOT/wsl-setup-nfs-server.sh"
else
    log_info "NFS 已配置，跳过"
fi

log_info "步骤 2/7：确保自建节点镜像存在（build-kind-node-image.sh，有则跳过）"
"$SCRIPT_DIR/build-kind-node-image/build-kind-node-image.sh"

log_info "步骤 3/7：创建集群与平台初始化（kind-up.sh）"
"$KIND_ROOT/kind-up.sh"

if [[ "$RUN_CA_INIT" == "true" ]]; then
    log_info "步骤 4/7：生成本地根 CA（ensure-kind-ca.sh，与远程 Step12 同用途）"
    export TRAEFIK_CA_LOCAL_DIR="${TRAEFIK_CA_LOCAL_DIR:-}"
    "$KIND_ROOT/ensure-kind-ca.sh"
else
    log_info "步骤 4/7：跳过本地根 CA 生成（--skip-ca-init）"
fi

if [[ "$KIND_IMAGE_SOURCE" == "harbor" ]]; then
    log_info "步骤 5/7：Kind 节点 Harbor 解析 + containerd 镜像拉取配置（来源: 集群内 Harbor）"
    "$KIND_ROOT/apply-kind-node-harbor-hosts.sh"
    if [[ "$RUN_REGISTRY_CONFIG" == "true" ]]; then
        export STEP02_REGISTRY_ENABLE STEP02_REGISTRY_MIRRORS STEP02_REGISTRY_DIRECT 2>/dev/null || true
        if "$KIND_ROOT/apply-kind-registry-config.sh"; then
            log_info "Kind 节点 registry 配置完成（apply-kind-registry-config.sh）"
        else
            log_warn "Kind 节点 registry 配置执行失败，跳过后续 registry 步骤（可单独运行 apply-kind-registry-config.sh 查看原因）"
        fi
    else
        log_info "步骤 5/7：KIND_IMAGE_SOURCE!=harbor 或显式跳过，未对 Kind 节点配置 registry"
    fi

    log_info "步骤 5.x：Kind 节点 Harbor TLS 信任（自签 CA 下发 + certs.d/hosts.toml）"
    if ! "$KIND_ROOT/apply-kind-harbor-tls.sh"; then
        log_warn "Kind 节点 Harbor TLS 信任配置执行失败，可稍后单独运行 apply-kind-harbor-tls.sh 查看原因"
    fi
else
    log_info "步骤 5/7：KIND_IMAGE_SOURCE='tar'，跳过与 Harbor 相关的节点 hosts/registry/TLS 配置"
fi

if [[ "$RUN_NFS_PROVISIONER" == "true" ]]; then
    log_info "步骤 6/7：集群内 NFS Provisioner 与 StorageClass（apply-nfs-existing-cluster.sh）"
    "$KIND_ROOT/apply-nfs-existing-cluster.sh"
else
    log_info "步骤 6/7：跳过 NFS Provisioner（--skip-nfs-provisioner）"
fi

if [[ "$RUN_HARBOR_HOSTS" == "true" ]]; then
    log_info "步骤 7/7：WSL 宿主机 Harbor 解析与登录（wsl-setup-harbor-hosts-and-login.sh）"
    export HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
    # 不在此处强制 HARBOR_IP，交给配置或脚本自动检测 Kind control-plane IP。
    # 此步骤只负责 WSL /etc/hosts + CA 分发，登录逻辑交给后续「推送到 Harbor」步骤处理。
    # 为避免脚本里的自动登录分支生效，这里显式屏蔽 HARBOR_ADMIN_PASSWORD 环境变量。
    (
        unset HARBOR_ADMIN_PASSWORD
        "$KIND_ROOT/wsl-setup-harbor-hosts-and-login.sh"
    )
else
    log_info "步骤 7/7：跳过 Harbor hosts（--skip-harbor-hosts）"
fi

if [[ "${DEPLOY_KIND_RUN_TRAEFIK:-false}" == "true" ]]; then
    log_info "可选步骤：在 Kind 集群中部署 Traefik（ingress-platform/deploy-ingress-platform-all）"
    # 传入 CLUSTER=KIND，使 Traefik 部署脚本识别为 Kind 并跳过节点镜像检查（与 Harbor 调用一致）
    if ! CLUSTER=KIND "$KIND_ROOT/../ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh"; then
        log_warn "Traefik 部署脚本执行失败，请检查 ingress-platform/deploy-ingress-platform-all 配置或单独运行该脚本查看原因"
    fi
fi

# 可选：在 Kind 集群创建完成后，自动将本地 tar 镜像加载到 Kind 所有节点（B 方案）
if [[ "${DEPLOY_KIND_RUN_PRELOAD_IMAGES:-false}" == "true" ]]; then
    log_info "可选步骤：预加载本地 tar 镜像到 Kind 所有节点（load-images/load-kind-images.sh）"
    PRELOAD_ARGS=()
    if [[ -n "${DEPLOY_KIND_PRELOAD_TAR_DIRS:-}" ]]; then
        PRELOAD_ARGS+=(--tar-dir "$(resolve_to_absolute "$DEPLOY_KIND_PRELOAD_TAR_DIRS")")
    fi
    if ! "$KIND_ROOT/load-images/load-kind-images.sh" "${PRELOAD_ARGS[@]}"; then
        log_warn "预加载镜像到 Kind 失败，可稍后手动运行 load-images/load-kind-images.sh 或使用 kind load docker-image"
    fi
fi

if [[ "${DEPLOY_KIND_RUN_HARBOR:-false}" == "true" ]]; then
    log_info "可选步骤：在 Kind 集群中部署 Harbor（cicd-platform/harbor/deploy-harbor）"
    # 使用 CLUSTER=KIND，deploy-harbor.sh 会根据 deploy-harbor.conf 选择命名空间和环境
    if ! CLUSTER=KIND "$KIND_ROOT/../cicd-platform/harbor/deploy-harbor/deploy-harbor.sh" deploy; then
        log_warn "Harbor 部署脚本执行失败，请检查 cicd-platform/harbor/deploy-harbor 配置或单独运行该脚本查看原因"
    fi
fi

# 可选：在一键流程中单独执行一次 WSL Harbor 登录（便于开发验证），失败仅告警不终止整体流程；
# 这里采用「尽力而为」策略：不再长时间等待 Harbor，就直接尝试一次 docker login，失败立即跳过。
if [[ "${DEPLOY_KIND_RUN_HARBOR_LOGIN:-false}" == "true" ]]; then
    log_info "可选步骤：WSL 宿主机 Harbor 登录（不推送镜像，仅登录验证，若失败立即跳过）"
    login_host="${HARBOR_HOST:-harbor.sunmoonai.com}:${HARBOR_PORT:-30443}"
    if [[ -z "${HARBOR_ADMIN_PASSWORD:-}" ]]; then
        log_warn "未配置 HARBOR_ADMIN_PASSWORD，跳过自动登录（可手动运行 wsl-setup-harbor-hosts-and-login.sh --login）"
    else
        if ! echo "${HARBOR_ADMIN_PASSWORD}" | docker login "${login_host}" -u "${HARBOR_ADMIN_USER:-admin}" --password-stdin; then
            log_warn "WSL Harbor 登录失败（${login_host}），可稍后手动执行 docker login 或运行 wsl-setup-harbor-hosts-and-login.sh --login"
        fi
    fi
fi

PUSH_ARGS=()
if [[ -n "${DEPLOY_KIND_PUSH_IMAGE_FILES:-}" ]]; then
    PUSH_ARGS+=(--img-file "$(resolve_to_absolute "$DEPLOY_KIND_PUSH_IMAGE_FILES")")
fi
if [[ -n "${DEPLOY_KIND_PUSH_TAR_DIRS:-}" ]]; then
    PUSH_ARGS+=(--tar-dir "$(resolve_to_absolute "$DEPLOY_KIND_PUSH_TAR_DIRS")")
fi

if [[ ${#PUSH_ARGS[@]} -gt 0 ]]; then
    if [[ "${DEPLOY_KIND_RUN_PUSH_TO_HARBOR:-false}" == "true" ]]; then
        log_info "可选步骤：根据 deploy-kind.conf 向 Harbor 推送镜像（push-to-harbor/push-images-to-harbor.sh）"

        # 推送前强制执行一次登录（等待 Harbor + 登录 + 确保项目）
        if ! harbor_login_or_fail; then
            log_error "Harbor 登录流程失败，终止 Harbor 镜像推送及一键部署流程"
            exit 1
        fi

        if ! "$KIND_ROOT/push-to-harbor/push-images-to-harbor.sh" "${PUSH_ARGS[@]}"; then
            log_error "push-images-to-harbor.sh 执行失败，请检查配置 DEPLOY_KIND_PUSH_IMAGE_FILES/DEPLOY_KIND_PUSH_TAR_DIRS 或单独运行该脚本查看原因"
            exit 1
        fi
    else
        log_info "已配置推送源，但 DEPLOY_KIND_RUN_PUSH_TO_HARBOR 未开启，跳过 Harbor 镜像推送"
    fi
else
    log_info "未配置 DEPLOY_KIND_PUSH_IMAGE_FILES/DEPLOY_KIND_PUSH_TAR_DIRS，跳过 Harbor 镜像推送"
fi

log_success "Kind 一键部署完成"
log_info "使用集群前请运行连接管理器或: export KUBECONFIG=\$HOME/.kube/kind-config"
log_info "后续可部署 Traefik、Harbor 等组件，详见 deploy-kind/deploy-kind.md"
