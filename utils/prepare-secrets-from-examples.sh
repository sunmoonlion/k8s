#!/bin/bash
# 将各组件 deploy 下 secrets 目录中的 .yaml.example 复制为正式 .yaml，
# 便于启动集群前一次性生成占位文件，无需手动复制。运行后可按需编辑 .yaml 填入真实密码。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# k8s 仓库根目录（utils 的上一级）
K8S_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUNMOONAI_ROOT="$K8S_ROOT/sunmoonai"

if [[ ! -d "$SUNMOONAI_ROOT" ]]; then
  echo "错误: 未找到 sunmoonai 目录: $SUNMOONAI_ROOT" >&2
  exit 1
fi

echo "从 .yaml.example 生成各组件 secret 的 .yaml 占位文件..."
count=0
while IFS= read -r -d '' src; do
  dir="$(dirname "$src")"
  base="$(basename "$src")"
  dest_name="${base%.yaml.example}.yaml"
  dest="$dir/$dest_name"
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "  保留已有文件: $dest"
    continue
  fi
  cp --no-clobber -- "$src" "$dest"
  echo "  $src -> $dest_name"
  ((count++)) || true
done < <(find "$SUNMOONAI_ROOT" -path '*/deploy-*/secrets/*' -name '*.yaml.example' -print0 2>/dev/null)

echo "已从 .yaml.example 生成 $count 个 secret 文件，仅生成缺失模板；部署前须按组件要求准备真实私有配置，不能将占位文件当作可用凭据。"
