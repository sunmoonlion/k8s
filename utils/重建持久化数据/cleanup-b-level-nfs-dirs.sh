#!/usr/bin/env bash

set -euo pipefail

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

red() { echo -e "${RED}$*${NC}"; }
green() { echo -e "${GREEN}$*${NC}"; }
yellow() { echo -e "${YELLOW}$*${NC}"; }

log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }

BASE_DIR="${1:-/data/kind-nfs}"

if [[ ! -d "$BASE_DIR" ]]; then
  log_error "NFS 目录不存在: $BASE_DIR"
  exit 1
fi

log_info "目标 NFS 根目录: $BASE_DIR"
log_warn "当前为交互式删除模式：仅在你对单个目录回答 y 时才会执行 sudo rm -rf。"
echo

if ! command -v kubectl >/dev/null 2>&1; then
  log_error "未找到 kubectl 命令，请在有 KUBECONFIG 的环境下运行。"
  exit 1
fi

log_info "从 Kubernetes PV 中收集 NFS 路径与 PV 名称映射..."
declare -A PATH_TO_PV
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # 形如: /data/kind-nfs/...###pv-name
  local_path="${line%%###*}"
  pv_name="${line##*###}"
  PATH_TO_PV["$local_path"]="$pv_name"
done < <(kubectl get pv -o jsonpath='{range .items[*]}{.spec.nfs.path}{"###"}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep "^${BASE_DIR}/" || true)

log_info "已收集 PV 数据条目: ${#PATH_TO_PV[@]}"
echo

B_PREFIXES=(
  "cicd-platform-dev-data-sunmoonai-harbor-postgresql-0-pvc-"   # Harbor PostgreSQL
  "cicd-platform-dev-redis-data-sunmoonai-harbor-redis-master-0-pvc-"  # Harbor Redis
  "cicd-platform-dev-sunmoonai-harbor-registry-pvc-"            # Harbor Registry
  "cicd-platform-dev-sunmoonai-harbor-jobservice-pvc-"          # Harbor Jobservice
  "cicd-platform-dev-data-sunmoonai-harbor-trivy-0-pvc-"        # Harbor Trivy
  "ingress-platform-dev-traefik-sunmoonai-pvc-"                 # Traefik
  "ops-platform-dev-pgadmin-sunmoonai-pgadmin4-pvc-"            # pgAdmin
  "ops-platform-dev-redisinsight-sunmoonai-pvc-"                # RedisInsight
  "ops-platform-dev-mongo-express-sunmoonai-pvc-"               # Mongo Express
  "ops-platform-dev-flower-sunmoonai-pvc-"                      # Flower
)

declare -a CANDIDATES=()

for prefix in "${B_PREFIXES[@]}"; do
  log_info "==== B 级前缀: $prefix ===="

  # 找到所有匹配目录
  mapfile -t dirs < <(find "$BASE_DIR" -maxdepth 1 -type d -name "${prefix}*" -printf '%P\n' | sort || true)

  if [[ "${#dirs[@]}" -eq 0 ]]; then
    log_info "未发现匹配目录，跳过。"
    echo
    continue
  fi

  for d in "${dirs[@]}"; do
    full_path="$BASE_DIR/$d"
    pv_name="${PATH_TO_PV[$full_path]:-}"
    if [[ -n "$pv_name" ]]; then
      log_info "目录: $full_path"
      log_info "  状态: 正在被 PV 使用 -> $pv_name"
      log_info "  提示: 如需清理，请先 kubectl delete pvc / pv，再手工 rm -rf 该目录。"
    else
      yellow "目录: $full_path"
      yellow "  状态: 当前无 PV 使用（候选可删除目录）"
      CANDIDATES+=("$full_path")
    fi
    echo
  done

  echo
done

if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
  log_success "没有发现可删除的 B 级历史目录。"
  exit 0
fi

log_info "共发现 ${#CANDIDATES[@]} 个候选可删除目录："
for i in "${!CANDIDATES[@]}"; do
  echo "  [$((i+1))] ${CANDIDATES[$i]}"
done
echo

read -r -p "选择删除模式：[a] 全部删除  [i] 逐条确认  [n] 取消 (默认 n): " mode
case "$mode" in
  a|A)
    for path in "${CANDIDATES[@]}"; do
      yellow "删除: $path"
      sudo rm -rf -- "$path"
    done
    log_success "已删除所有候选 B 级历史目录。"
    ;;
  i|I)
    for path in "${CANDIDATES[@]}"; do
      read -r -p "是否删除 $path ? [y/N] " ans
      case "$ans" in
        y|Y)
          yellow "  正在删除: $path"
          sudo rm -rf -- "$path"
          ;;
        *)
          log_info "  跳过: $path"
          ;;
      esac
    done
    log_success "逐条确认删除完成。"
    ;;
  *)
    log_warn "已取消删除操作，未删除任何目录。"
    ;;
esac



