#!/usr/bin/env bash
# 供 kind-infrastructure 下各脚本 source：保证 kind 在 PATH 中（与 k8s/utils/prepend-dev-cli-path 一致）
# 用法：source "${SCRIPT_DIR}/kind-cli.sh" 后调用 prepend_kind_to_path_if_needed

_KIND_INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_K8S_ROOT="$(cd "${_KIND_INFRA_DIR}/../.." && pwd)"
# shellcheck source=../../utils/prepend-dev-cli-path.sh
source "${_K8S_ROOT}/utils/prepend-dev-cli-path.sh"

prepend_kind_to_path_if_needed() {
    prepend_dev_cli_to_path
    if command -v kind &>/dev/null; then
        return 0
    fi
    local p
    for p in "${HOME}/.local/bin/kind" /usr/local/bin/kind; do
        if [[ -x "$p" ]]; then
            export PATH="$(dirname "$p"):${PATH}"
            return 0
        fi
    done
    return 1
}
