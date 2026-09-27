#!/usr/bin/env bash
# Shared namespace implementation with cloud step07; default prints only.
# Actual use requires explicit locked kubectl, private kubeconfig and recorded UID.
# StorageClass belongs to the storage phase; this command creates namespaces only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${INFRA_CONFIG_FILE:-$SCRIPT_DIR/../infrastructure/deploy-infrastructure-all/deploy-infrastructure-all.conf}"
[[ -f "$CONFIG_FILE" && ! -L "$CONFIG_FILE" ]] || { echo 'Namespace config missing/symlinked' >&2; exit 1; }
# Trusted owner config, never print/export the complete configuration.
# shellcheck source=/dev/null
source "$CONFIG_FILE"
if [[ -n "${INFRA_PRIVATE_CONFIG_FILE:-}" ]]; then
    [[ -f "$INFRA_PRIVATE_CONFIG_FILE" && ! -L "$INFRA_PRIVATE_CONFIG_FILE" ]] || exit 1
    # shellcheck source=/dev/null
    source "$INFRA_PRIVATE_CONFIG_FILE"
fi
for name in NAMESPACE_PLATFORM_ENABLE NAMESPACE_PLATFORM_ENVIRONMENTS NAMESPACE_PLATFORM_PLATFORMS NAMESPACE_PLATFORM_APPLY_POLICIES; do
    override="KIND_${name}"
    if [[ -v "$override" ]]; then printf -v "$name" '%s' "${!override}"; fi
done
export SM_NAMESPACE_ENABLED="${NAMESPACE_PLATFORM_ENABLE:-false}"
export SM_NAMESPACE_ENVIRONMENTS="${NAMESPACE_PLATFORM_ENVIRONMENTS:-}"
export SM_NAMESPACE_PLATFORMS="${NAMESPACE_PLATFORM_PLATFORMS:-}"
export SM_NAMESPACE_POLICIES="${NAMESPACE_PLATFORM_APPLY_POLICIES:-false}"
python3 "$SCRIPT_DIR/../infrastructure/materials/resources_local.py" "$@"
