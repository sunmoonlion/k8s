#!/usr/bin/env bash

set -euo pipefail

red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }

log_info() { echo "ℹ️  $*"; }
log_success() { green "✅ $*"; }
log_warn() { yellow "⚠️  $*"; }
log_error() { red "❌ $*"; }

usage() {
  cat <<EOF
用法:
  $0 <namespace> <dynamic_pvc_name> <static_pv_yaml>

作用:
  - 在当前集群中查找绑定到 <namespace>/<dynamic_pvc_name> 的动态 PV；
  - 读取该 PV.spec.nfs.server 与 PV.spec.nfs.path；
  - 基于占位符模板 <static_pv_yaml>.template.yaml 生成实际的 <static_pv_yaml>，
    并在生成的文件中更新 spec.nfs.server 与 spec.nfs.path 两行。

示例:
  # PostgreSQL（data-platform-dev）
  $0 data-platform-dev data-postgresql-sunmoonai-0 \\
     ./data-platform/postgresql/resources/custom-values/postgresql-dev-pv-pvc.yaml

  # MongoDB（data-platform-dev）
  $0 data-platform-dev data-mongodb-sunmoonai-0 \\
     ./data-platform/mongodb/resources/custom-values/mongodb-dev-pv-pvc.yaml

  # RabbitMQ（messaging-platform-dev）
  $0 messaging-platform-dev data-rabbitmq-sunmoonai-0 \\
     ./messaging-platform/rabbitmq/resources/custom-values/rabbitmq-dev-pv-pvc.yaml
EOF
}

if [[ $# -ne 3 ]]; then
  log_error "参数数量不正确。"
  usage
  exit 1
fi

NS="$1"
PVC_NAME="$2"
YAML="$3"

if ! command -v kubectl >/dev/null 2>&1; then
  log_error "未找到 kubectl，请先安装并配置好 KUBECONFIG。"
  exit 1
fi

TEMPLATE="${YAML%.yaml}.template.yaml"

if [[ ! -f "$TEMPLATE" ]]; then
  log_error "占位符模板不存在: $TEMPLATE"
  log_error "请确保模板文件以 .template.yaml 结尾，例如: postgresql-dev-pv-pvc.template.yaml"
  exit 1
fi

log_info "使用模板文件生成实际 YAML:"
log_info "  模板: $TEMPLATE"
log_info "  目标: $YAML"

log_info "在集群中查找绑定到 $NS/$PVC_NAME 的 PV..."

PV_LINE=$(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.spec.claimRef.namespace}{"|"}{.spec.claimRef.name}{"\n"}{end}' 2>/dev/null | \
  awk -F'|' -v ns="$NS" -v pvc="$PVC_NAME" '$2 == ns && $3 == pvc {print $0; exit}')

if [[ -z "${PV_LINE:-}" ]]; then
  log_error "未找到绑定到 $NS/$PVC_NAME 的 PV。请确认 PVC 是否存在且已绑定。"
  exit 1
fi

PV_NAME=$(echo "$PV_LINE" | awk -F'|' '{print $1}')
log_info "找到 PV: $PV_NAME"

SERVER=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.nfs.server}' 2>/dev/null || true)
PATH_VAL=$(kubectl get pv "$PV_NAME" -o jsonpath='{.spec.nfs.path}' 2>/dev/null || true)

if [[ -z "${SERVER:-}" || -z "${PATH_VAL:-}" ]]; then
  log_error "PV $PV_NAME 上未找到 spec.nfs.server 或 spec.nfs.path，请确认该 PV 使用 NFS。"
  exit 1
fi

log_info "将在 $YAML 中更新 NFS 配置："
log_info "  server: $SERVER"
log_info "  path:   $PATH_VAL"

# 先基于模板生成实际 YAML，再做备份和替换
cp "$TEMPLATE" "$YAML"
cp "$YAML" "${YAML}.bak"

# 更新 server 与 path 行（仅替换以 'server:' / 'path:' 开头的行）
sed -i -E "s#(^[[:space:]]*server:[[:space:]]*).*\$#\1$SERVER#" "$YAML"
sed -i -E "s#(^[[:space:]]*path:[[:space:]]*).*\$#\1$PATH_VAL#" "$YAML"

log_success "已根据模板 $TEMPLATE 生成 $YAML，并更新其中的 NFS server/path（备份: ${YAML}.bak）"

