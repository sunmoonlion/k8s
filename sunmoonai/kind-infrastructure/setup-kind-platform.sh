#!/usr/bin/env bash
#
# 阶段三：Kind 平台初始化入口
# 按顺序执行命名空间 + 本地存储，使用当前 KUBECONFIG（需已指向 Kind 集群）。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }

log_info "Kind 平台初始化：命名空间 → 本地存储"
"$SCRIPT_DIR/apply-namespaces-existing-cluster.sh"
"$SCRIPT_DIR/apply-storage-local-existing-cluster.sh"
log_success "Kind 平台初始化完成"
