#!/usr/bin/env bash

set -euo pipefail

red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }

log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_ONE_SCRIPT="$SCRIPT_DIR/update-static-pv-path-from-cluster.sh"

if [[ ! -x "$UPDATE_ONE_SCRIPT" ]]; then
  log_error "未找到或不可执行: $UPDATE_ONE_SCRIPT"
  exit 1
fi

# 计算 SunmoonAI 项目根目录（k8s/sunmoonai）
SUNMOONAI_ROOT="$(cd "$SCRIPT_DIR/../sunmoonai" && pwd)"

log_info "SunmoonAI 根目录: $SUNMOONAI_ROOT"
log_info "使用单组件更新脚本: $UPDATE_ONE_SCRIPT"
echo

fail_count=0

run_update() {
  local ns="$1"
  local pvc="$2"
  local yaml="$3"
  local desc="$4"

  log_info "==== 更新 $desc ===="
  log_info "  命名空间: $ns"
  log_info "  动态 PVC : $pvc"
  log_info "  YAML 文件: $yaml"

  if [[ ! -f "$yaml" ]]; then
    log_warn "  跳过：YAML 文件不存在: $yaml"
    ((fail_count++)) || true
    echo
    return 0
  fi

  if "$UPDATE_ONE_SCRIPT" "$ns" "$pvc" "$yaml"; then
    log_success "  $desc 已更新完成"
  else
    log_warn "  $desc 更新失败，请检查上方错误信息"
    ((fail_count++)) || true
  fi
  echo
}

log_info "开始批量更新静态 PV YAML 中的 NFS server/path..."
echo

# 1. RabbitMQ（messaging-platform-dev）
run_update \
  "messaging-platform-dev" \
  "data-rabbitmq-sunmoonai-0" \
  "$SUNMOONAI_ROOT/messaging-platform/rabbitmq/resources/custom-values/rabbitmq-dev-pv-pvc.yaml" \
  "RabbitMQ"

# 2. PostgreSQL（data-platform-dev）
run_update \
  "data-platform-dev" \
  "data-postgresql-sunmoonai-0" \
  "$SUNMOONAI_ROOT/data-platform/postgresql/resources/custom-values/postgresql-dev-pv-pvc.yaml" \
  "PostgreSQL"

# 3. MongoDB（data-platform-dev）
run_update \
  "data-platform-dev" \
  "data-mongodb-sunmoonai-0" \
  "$SUNMOONAI_ROOT/data-platform/mongodb/resources/custom-values/mongodb-dev-pv-pvc.yaml" \
  "MongoDB"

# 4. Redis（data-platform-dev，主节点）
run_update \
  "data-platform-dev" \
  "data-redis-sunmoonai-master-0" \
  "$SUNMOONAI_ROOT/data-platform/redis/resources/custom-values/redis-dev-pv-pvc.yaml" \
  "Redis Master"

# 5. Elasticsearch（data-platform-dev，仅 master 节点持久化）
run_update \
  "data-platform-dev" \
  "data-elasticsearch-sunmoonai-master-0" \
  "$SUNMOONAI_ROOT/data-platform/elasticsearch/resources/custom-values/elasticsearch-dev-pv-pvc.yaml" \
  "Elasticsearch Master"

# 6. Neo4j（data-platform-dev，如未启用则 PVC 不存在）
run_update \
  "data-platform-dev" \
  "data-neo4j-sunmoonai-0" \
  "$SUNMOONAI_ROOT/data-platform/neo4j/resources/custom-values/neo4j-dev-pv-pvc.yaml" \
  "Neo4j"

if (( fail_count == 0 )); then
  log_success "🎉 所有组件的静态 PV YAML 已成功更新。"
  log_info "   现在可以在复用模式下安全使用这些 *-dev-pv-pvc.yaml。"
else
  log_warn "⚠️ 共 $fail_count 个组件更新过程中出现问题，请根据日志逐一检查。"
fi

