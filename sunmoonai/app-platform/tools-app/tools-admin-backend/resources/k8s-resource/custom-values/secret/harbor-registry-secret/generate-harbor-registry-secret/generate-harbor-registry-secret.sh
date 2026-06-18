#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_k8s_root_dir() {
    local search_dir="$1"
    while [[ -n "$search_dir" && "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/sunmoonai/app-platform/utils/generate-harbor-registry-secret.sh" ]]; then
            echo "$search_dir"
            return 0
        fi
        search_dir="$(dirname "$search_dir")"
    done
    return 1
}

K8S_ROOT_DIR="$(find_k8s_root_dir "$SCRIPT_DIR")" || {
    echo "[ERROR] 无法定位 k8s 根目录" >&2
    exit 1
}

exec bash "$K8S_ROOT_DIR/sunmoonai/app-platform/utils/generate-harbor-registry-secret.sh" "$SCRIPT_DIR" "$@"
