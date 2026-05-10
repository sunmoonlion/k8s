#!/usr/bin/env bash
#
# 构建“带预装 Harbor/Traefik 等镜像”的 Kind 节点镜像。无需先建集群：本脚本仅做 docker build，不执行 kind create。
# 推荐流程：先执行本脚本生成节点镜像并更新 deploy-kind/kind-cluster.yaml → 再执行 deploy-kind.sh 或 kind-up.sh 建集群。
#
# 方式：用 Dockerfile 基于官方 kindest/node 在构建层内 ctr import 导入镜像数据。
# 基础镜像与后缀优先从 deploy-kind.conf 中读取：
#   - KIND_BASE_IMAGE：kindest/node 基础镜像版本；
#   - CUSTOM_NODE_SUFFIX：自建节点镜像后缀（如 sunmoonai）。
# 若未在配置中指定 KIND_BASE_IMAGE，则从 deploy-kind/kind-cluster.yaml 中解析当前节点 image，并在末尾去掉 CUSTOM_NODE_SUFFIX 得到基础镜像。
#
# 镜像数据来源与 load-images 一致，有两种（均由 build-kind-node-image.conf 配置，路径相对本目录 build-kind-node-image/ 或为绝对路径）：
#   1) BUILD_KIND_IMAGE_LIST_FILE：镜像列表文件（镜像名，每行一个）；镜像须已在本机 docker 中（不执行 docker pull），脚本仅 docker save 成 tar。
#   2) BUILD_KIND_TAR_DIR：已有 .tar 所在目录，直接 COPY 到构建镜像中再 ctr import。
# 基础镜像 BASE_IMAGE（如 kindest/node:v1.27.3）也须已存在于本机，否则 docker build 会失败；本脚本在 build 前显式检查并报错提示先 docker pull。
# 两者只能二选一：若两者同时非空则报错。执行后会自动更新 kind-cluster.yaml 中所有节点 image 为本镜像。
#
set -euo pipefail

# 脚本在 kind-infrastructure/deploy-kind/build-kind-node-image/ 下，KIND_ROOT 为 kind-infrastructure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEPLOY_KIND_DIR="${KIND_ROOT}/deploy-kind"
CONF_FILE="${SCRIPT_DIR}/build-kind-node-image.conf"

# 默认配置（可被 build-kind-node-image.conf 覆盖）
BUILD_KIND_IMAGE_LIST_FILE=""
BUILD_KIND_TAR_DIR="image-init-dir"

if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
fi

# 优先从 deploy-kind.conf 读取 KIND_BASE_IMAGE/CUSTOM_NODE_SUFFIX（若未定义则使用默认后缀 sunmoonai）
KIND_BASE_IMAGE="${KIND_BASE_IMAGE:-}"
CUSTOM_SUFFIX="${CUSTOM_NODE_SUFFIX:-sunmoonai}"
FORCE_REBUILD=false

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn() { echo "⚠️  $*"; }
log_error() { echo "❌ $*"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_REBUILD=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [--force]"
            echo "  无参数：如目标节点镜像已存在则跳过构建；不存在时才构建。"
            echo "  --force：无论目标镜像是否存在，强制重新构建并更新 kind-cluster.yaml。"
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            exit 1
            ;;
    esac
done

KIND_YAML="${DEPLOY_KIND_DIR}/kind-cluster.yaml"
if [[ ! -f "$KIND_YAML" ]]; then
    log_error "未找到 $KIND_YAML"
    exit 1
fi

# 确定基础镜像 BASE_IMAGE：
# 1) 若在 deploy-kind.conf 中显式配置了 KIND_BASE_IMAGE，则直接使用；
# 2) 否则从 deploy-kind/kind-cluster.yaml 解析当前节点 image：
#    - 如 image 以 -${CUSTOM_SUFFIX} 结尾，则去掉后缀得到基础镜像；
#    - 否则直接将当前 image 视为基础镜像。
BASE_IMAGE="$KIND_BASE_IMAGE"
if [[ -z "$BASE_IMAGE" ]]; then
    CURRENT_IMAGE=$(grep -E '^\s*image:\s*kindest/node:' "$KIND_YAML" | head -1 | sed 's/.*image:[[:space:]]*//;s/[[:space:]]*#.*//;s/[[:space:]]*$//')
    if [[ -z "$CURRENT_IMAGE" ]]; then
        log_error "无法从 $KIND_YAML 解析 kindest/node 镜像，请在 deploy-kind.conf 中配置 KIND_BASE_IMAGE"
        exit 1
    fi
    if [[ "$CURRENT_IMAGE" == *"-${CUSTOM_SUFFIX}" ]]; then
        BASE_IMAGE="${CURRENT_IMAGE%-${CUSTOM_SUFFIX}}"
    else
        BASE_IMAGE="$CURRENT_IMAGE"
    fi
fi

CUSTOM_IMAGE="${BASE_IMAGE}-${CUSTOM_SUFFIX}"

# 若未指定 --force 且目标镜像已存在，则直接跳过构建
if [[ "$FORCE_REBUILD" != true ]]; then
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -qx "$CUSTOM_IMAGE"; then
        log_info "目标节点镜像已存在: $CUSTOM_IMAGE，跳过构建（如需重新构建请使用 --force）"
        exit 0
    fi
fi

DOCKER_COPY_SUBDIR=""

# 解析镜像数据来源（与 load-images 类似，通过 build-kind-node-image.conf 配置，二选一）
IMAGE_LIST_FILE_RESOLVED=""
TAR_DIR_RESOLVED=""

if [[ -n "$BUILD_KIND_IMAGE_LIST_FILE" && -n "$BUILD_KIND_TAR_DIR" ]]; then
    log_error "BUILD_KIND_IMAGE_LIST_FILE 与 BUILD_KIND_TAR_DIR 不能同时非空，请在 build-kind-node-image.conf 中二选一配置"
    exit 1
fi

if [[ -n "$BUILD_KIND_IMAGE_LIST_FILE" ]]; then
    if [[ "$BUILD_KIND_IMAGE_LIST_FILE" = /* ]]; then
        IMAGE_LIST_FILE_RESOLVED="$BUILD_KIND_IMAGE_LIST_FILE"
    else
        IMAGE_LIST_FILE_RESOLVED="${SCRIPT_DIR}/${BUILD_KIND_IMAGE_LIST_FILE}"
    fi
    if [[ ! -f "$IMAGE_LIST_FILE_RESOLVED" ]]; then
        log_error "镜像列表文件不存在: $IMAGE_LIST_FILE_RESOLVED（请检查 build-kind-node-image.conf 中的 BUILD_KIND_IMAGE_LIST_FILE）"
        exit 1
    fi
elif [[ -n "$BUILD_KIND_TAR_DIR" ]]; then
    if [[ "$BUILD_KIND_TAR_DIR" = /* ]]; then
        TAR_DIR_RESOLVED="$BUILD_KIND_TAR_DIR"
    else
        TAR_DIR_RESOLVED="${SCRIPT_DIR}/${BUILD_KIND_TAR_DIR}"
    fi
    if [[ ! -d "$TAR_DIR_RESOLVED" ]] || ! ls -1 "$TAR_DIR_RESOLVED"/*.tar >/dev/null 2>&1; then
        log_error "未在目录中找到任何 .tar: $TAR_DIR_RESOLVED（请检查 build-kind-node-image.conf 中的 BUILD_KIND_TAR_DIR）"
        exit 1
    fi
else
    log_error "未在 build-kind-node-image.conf 中配置 BUILD_KIND_IMAGE_LIST_FILE 或 BUILD_KIND_TAR_DIR，请至少配置一种镜像数据来源"
    exit 1
fi

# 统一将 tar 放入 deploy-kind/.kind-node-build-tars 下，作为 Docker build 的 COPY 源（脚本临时目录，带 . 表示隐藏）
TMP_SUBDIR=".kind-node-build-tars"
TAR_TARGET_DIR="${DEPLOY_KIND_DIR}/${TMP_SUBDIR}"
rm -rf "$TAR_TARGET_DIR"
mkdir -p "$TAR_TARGET_DIR"
# 脚本结束时删除临时目录（正常退出或异常退出都会执行）
trap 'rm -rf "${TAR_TARGET_DIR:-}"' EXIT

if [[ -n "$TAR_DIR_RESOLVED" ]]; then
    # 方式 2：已有 tar 目录，直接复制到 staging 目录
    cp "${TAR_DIR_RESOLVED}/"*.tar "$TAR_TARGET_DIR"/
else
    # 方式 1：镜像列表文件 -> 仅使用本地已有镜像 docker save（不执行 docker pull）
    while IFS= read -r line || [[ -n "$line" ]]; do
        img=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$img" || "$img" =~ ^# ]] && continue
        if ! docker image inspect "$img" >/dev/null 2>&1; then
            log_error "本地未找到镜像: $img（本脚本不会自动 docker pull）"
            log_error "请先执行: docker pull $img（配置好代理/镜像加速后再试），然后再运行本脚本。"
            exit 1
        fi
        log_info "打包本地镜像为 tar: $img"
        safe_name=$(echo "$img" | sed 's/[^a-zA-Z0-9_.-]/_/g')
        tar_path="${TAR_TARGET_DIR}/${safe_name}.tar"
        if ! docker save -o "$tar_path" "$img"; then
            log_error "docker save 失败: $img"
            exit 1
        fi
    done < "$IMAGE_LIST_FILE_RESOLVED"
fi

if ! ls -1 "$TAR_TARGET_DIR"/*.tar >/dev/null 2>&1; then
    log_error "未在 $TAR_TARGET_DIR 中发现任何 tar，请检查 images-init.txt 或 tar-default-dir 内容"
    exit 1
fi

if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
    log_error "本地未找到 Docker 基础镜像: $BASE_IMAGE（docker build 不会自动从仓库拉取）"
    log_error "请先执行: docker pull $BASE_IMAGE（配置好代理/镜像加速后再试），然后再运行 deploy-kind.sh 或本脚本。"
    exit 1
fi

DOCKER_COPY_SUBDIR="$TMP_SUBDIR"
DOCKERFILE_PATH="${DEPLOY_KIND_DIR}/Dockerfile.kind-node"

log_info "使用 Dockerfile 构建节点镜像（base=$BASE_IMAGE, 镜像数据目录=$DOCKER_COPY_SUBDIR，build context=$DEPLOY_KIND_DIR）"
cat > "$DOCKERFILE_PATH" << DOCKERFILE_END
# 由 build-kind-node-image.sh 生成。在构建层内 ctr import 导入镜像，供 kind-cluster.yaml 使用。
ARG BASE_IMAGE=${BASE_IMAGE}
FROM \${BASE_IMAGE}
COPY ${DOCKER_COPY_SUBDIR} /tmp/images
RUN set -e; \\
    ( containerd >/dev/null 2>&1 & ); \\
    for i in 1 2 3 4 5 6 7 8 9 10; do [ -S /run/containerd/containerd.sock ] && break; sleep 1; done; \\
    for f in /tmp/images/*.tar; do [ -f "\$f" ] && ctr -n k8s.io images import --digests --snapshotter=overlayfs "\$f" || true; done; \\
    pkill -x containerd || true; \\
    rm -rf /tmp/images
DOCKERFILE_END

log_info "执行 docker build（context=$DEPLOY_KIND_DIR）..."
if ! docker build -f "$DOCKERFILE_PATH" -t "$CUSTOM_IMAGE" "$DEPLOY_KIND_DIR"; then
    log_error "docker build 失败"
    exit 1
fi
log_success "已生成节点镜像: $CUSTOM_IMAGE"

if sed -i "s|image: kindest/node:[^[:space:]]*|image: ${CUSTOM_IMAGE}|g" "$KIND_YAML" 2>/dev/null; then
    log_success "已更新 kind-cluster.yaml 中所有节点 image 为 $CUSTOM_IMAGE"
else
    log_warn "无法更新 kind-cluster.yaml，请手动将各节点 image 改为: $CUSTOM_IMAGE"
fi

echo ""
echo "后续：直接执行 deploy-kind.sh 或 kind-up.sh 创建/重建集群，节点内已含 Harbor/Traefik 等镜像，无需再加载。"
