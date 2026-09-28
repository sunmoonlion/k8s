#!/usr/bin/env bash
# Compatibility navigation only; use the same explicit publisher on every host.
# Cloud execution 未经实机验证. Old positional, tar-directory and cleanup modes are retired.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    printf '%s\n' 'Use ./sunmoon harbor publish --batch <absolute JSON>; do not source this entry.' >&2
    return 2
fi
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
exec python3 -B "$K8S_ROOT/sunmoonai/registry-platform/publish.py" "$@"
