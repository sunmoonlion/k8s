#!/usr/bin/env bash
#
# Kind 一键部署：按顺序创建集群与平台初始化、WSL Harbor 解析。
# 均在 WSL 中执行。可选参数见下方用法。配置见同目录 deploy-kind.conf。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../kind-cli.sh
source "${KIND_ROOT}/kind-cli.sh"
prepend_kind_to_path_if_needed || true

# 加载配置（可选）
if [[ -f "$SCRIPT_DIR/deploy-kind.conf" ]]; then
    source "$SCRIPT_DIR/deploy-kind.conf"
fi
export HARBOR_HOST HARBOR_NODE_IP 2>/dev/null || true

RUN_CA_INIT="${DEPLOY_KIND_RUN_CA_INIT:-true}"
RUN_REGISTRY_CONFIG=true
RUN_HARBOR_HOSTS=true

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

# 确保 Harbor 中存在部署所需项目（若不存在则自动创建为公开项目）
ensure_harbor_projects() {
    local api_base="https://${HARBOR_HOST:-harbor.sunmoonai.com}:${HARBOR_PORT:-30443}/api/v2.0"
    local projects="${HARBOR_PROJECT_NAMES:-${HARBOR_PROJECT_NAME:-k8s-images},app-images}"
    local user="${HARBOR_ADMIN_USER:-admin}"
    local pass="${HARBOR_ADMIN_PASSWORD:-}"

    if [[ -z "$pass" ]]; then
        log_warn "未提供 HARBOR_ADMIN_PASSWORD，跳过自动创建 Harbor 项目: ${projects}"
        return 0
    fi

    local save_ifs="$IFS"
    IFS=','
    for proj in $projects; do
        proj=$(echo "$proj" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$proj" ]] && continue

        # 查询项目是否已存在（GET /projects 无匹配时也返回 200，body 为空数组，需根据响应体判断）
        local body
        body=$(curl -sk --noproxy '*' -u "${user}:${pass}" "${api_base}/projects?name=${proj}" 2>/dev/null || true)
        if echo "$body" | grep -qE '"name"\s*:\s*"'"${proj}"'"'; then
            log_info "Harbor 项目 ${proj} 已存在"
            continue
        fi

        log_info "Harbor 项目 ${proj} 不存在，尝试自动创建..."
        code=$(curl -sk --noproxy '*' -u "${user}:${pass}" -o /dev/null -w '%{http_code}' \
            -H 'Content-Type: application/json' \
            -X POST "${api_base}/projects" \
            -d "{\"project_name\":\"${proj}\",\"metadata\":{\"public\":\"true\"}}" || echo "000")

        if [[ "$code" == "201" || "$code" == "409" ]]; then
            # 201: 创建成功；409: 已存在（并发等原因）
            log_info "Harbor 项目 ${proj} 已就绪（HTTP ${code}）"
            continue
        fi

        IFS="$save_ifs"
        log_error "自动创建 Harbor 项目 ${proj} 失败（HTTP ${code}），请手动在 Web 控制台创建该项目或调整配置"
        return 1
    done
    IFS="$save_ifs"
}

# 封装一次 Harbor 登录流程：等待就绪 + docker login（不包含创建项目，项目由一键部署流程在步骤 9 后统一调用 ensure_harbor_project_k8s_images）
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

    return 0
}

usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --skip-ca-init          跳过本地根 CA 生成（ensure-kind-ca.sh，与远程 Step12 同用途）"
    echo "  --skip-registry-config  跳过 Kind 节点 containerd 镜像拉取配置（apply-kind-registry-config.sh）"
    echo "  --skip-harbor-hosts     跳过 WSL /etc/hosts 中 Harbor 域名配置"
    echo "  -h, --help           显示此帮助"
    echo "配置: $SCRIPT_DIR/deploy-kind.conf"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-ca-init)           RUN_CA_INIT=false; shift ;;
        --skip-registry-config)   RUN_REGISTRY_CONFIG=false; shift ;;
        --skip-harbor-hosts)      RUN_HARBOR_HOSTS=false; shift ;;
        -h|--help)           usage; exit 0 ;;
        *)                   log_error "未知选项: $1"; usage; exit 1 ;;
    esac
done

log_info "Kind 一键部署开始（步骤 1/6：确保自建节点镜像存在（build-kind-node-image.sh，有则跳过））"
"$SCRIPT_DIR/build-kind-node-image/build-kind-node-image.sh"

log_info "步骤 2/6：创建集群与平台初始化（kind-up.sh）"
"$KIND_ROOT/kind-up.sh"

if [[ "$RUN_CA_INIT" == "true" ]]; then
    log_info "步骤 3/6：生成本地根 CA（ensure-kind-ca.sh，与远程 Step12 同用途）"
    export TRAEFIK_CA_LOCAL_DIR="${TRAEFIK_CA_LOCAL_DIR:-}"
    "$KIND_ROOT/ensure-kind-ca.sh"
else
    log_info "步骤 3/6：跳过本地根 CA 生成（--skip-ca-init）"
fi

log_info "步骤 4/6：Kind 节点 Harbor 解析 + containerd 镜像拉取配置"
"$KIND_ROOT/apply-kind-node-harbor-hosts.sh"
export STEP02_REGISTRY_ENABLE STEP02_REGISTRY_MIRRORS STEP02_REGISTRY_DIRECT 2>/dev/null || true
if "$KIND_ROOT/apply-kind-registry-config.sh"; then
    log_info "Kind 节点 registry 配置完成（apply-kind-registry-config.sh）"
else
    log_warn "Kind 节点 registry 配置执行失败，可稍后单独运行 apply-kind-registry-config.sh 查看原因"
fi

log_info "步骤 4.x：Kind 节点 Harbor TLS 信任（自签 CA 下发 + certs.d/hosts.toml）"
if ! "$KIND_ROOT/apply-kind-harbor-tls.sh"; then
    log_warn "Kind 节点 Harbor TLS 信任配置执行失败，可稍后单独运行 apply-kind-harbor-tls.sh 查看原因"
fi

if [[ "$RUN_HARBOR_HOSTS" == "true" ]]; then
    log_info "步骤 5/6：WSL 宿主机 Harbor 域名解析（仅 hosts，登录放在 Harbor 部署完成后执行）"
    export HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
    # 不在此处强制 HARBOR_IP，交给脚本自动检测 Kind control-plane IP。
    "$KIND_ROOT/wsl-setup-harbor-hosts.sh"
else
    log_info "步骤 5/6：跳过 Harbor hosts（--skip-harbor-hosts）"
fi

log_info "步骤 6/6：在 Kind 集群中部署 Traefik + Harbor"
log_info "步骤 6a：Traefik（ingress-platform/deploy-ingress-platform-all）"
# 传入 CLUSTER=KIND，使 Traefik 部署脚本识别为 Kind 并跳过节点镜像检查（与 Harbor 调用一致）
if ! CLUSTER=KIND "$KIND_ROOT/../ingress-platform/deploy-ingress-platform-all/deploy-ingress-platform-all.sh"; then
    log_warn "Traefik 部署脚本执行失败，请检查 ingress-platform/deploy-ingress-platform-all 配置或单独运行该脚本查看原因"
fi

log_info "步骤 6b：Harbor（cicd-platform/harbor/deploy-harbor）"
# 使用 CLUSTER=KIND，deploy-harbor.sh 会根据 deploy-harbor.conf 选择命名空间和环境
if ! CLUSTER=KIND "$KIND_ROOT/../cicd-platform/harbor/deploy-harbor/deploy-harbor.sh" deploy; then
    log_warn "Harbor 部署脚本执行失败，请检查 cicd-platform/harbor/deploy-harbor 配置或单独运行该脚本查看原因"
else
    # Harbor 部署成功后：等待 /v2/ 就绪 → 登录 → 确保 k8s-images 项目存在（组件镜像均推到此项目）
    if wait_for_harbor; then
        log_info "Harbor 已就绪，尝试在 WSL 上执行 Harbor 登录（wsl-setup-harbor-login.sh）"
        if ! "$KIND_ROOT/wsl-setup-harbor-login.sh"; then
            log_warn "Harbor 登录脚本执行返回非零状态，可稍后在 WSL 手动运行: $KIND_ROOT/wsl-setup-harbor-login.sh"
        fi
        # 一键部署时必须确保镜像项目存在，否则组件与业务镜像 push/pull 会失败（ImagePullBackOff）
        if ! ensure_harbor_projects; then
            log_warn "Harbor 项目创建失败，请手动在 Harbor 控制台创建所需项目，或配置 HARBOR_ADMIN_PASSWORD 后重试"
        fi
    else
        log_warn "Harbor 在预期时间内未完全就绪，跳过自动登录；可稍后手动运行: $KIND_ROOT/wsl-setup-harbor-login.sh"
    fi
fi

log_success "Kind 一键部署完成"
log_info "使用集群前请运行连接管理器或: export KUBECONFIG=\$HOME/.kube/kind-config"
log_info "后续可部署 Traefik、Harbor 等组件，详见 deploy-kind/deploy-kind.md"
