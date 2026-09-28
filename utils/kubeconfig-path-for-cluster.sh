#!/usr/bin/env bash
# Read the selected mapping as data; no eval, implicit KIND fallback or context merge.
kubeconfig_path_from_admin_conf() {
    local module_dir
    module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || return 1
    python3 -B "$module_dir/kubeconfig_path.py" "$1" "${2:-}"
}
