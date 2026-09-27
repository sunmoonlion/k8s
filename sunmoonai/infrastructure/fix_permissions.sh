#!/usr/bin/env bash
# 只修复当前工作树的步骤脚本权限，不访问其他检出。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shopt -s nullglob
scripts=("$SCRIPT_DIR"/steps/step*.sh)
if [[ ${#scripts[@]} -eq 0 ]]; then
    echo "未找到步骤脚本" >&2
    exit 1
fi
chmod +x -- "${scripts[@]}"
ls -l -- "${scripts[@]}"
