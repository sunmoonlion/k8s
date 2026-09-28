#!/usr/bin/env bash
# ONLYOFFICE local renderer. No API calls; secrets require explicit selection.
set -euo pipefail
set +x
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
requested=()
dry_run=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --resource)
            [[ $# -ge 2 && -n "$2" && "$2" != */* && "$2" != -* ]] || { echo 'Expected a configured resource output filename' >&2; exit 2; }
            requested+=("$2"); shift 2 ;;
        --dry-run) dry_run=true; shift ;;
        --help|-h)
            echo 'generate.sh [--resource OUTPUT_FILE ...] [--dry-run]'
            echo 'Default: non-Secret resources only. A Secret must be explicitly selected with its configured value.'
            exit 0 ;;
        *) echo 'Unsupported renderer option' >&2; exit 2 ;;
    esac
done
if [[ "$dry_run" == true || "${SUNMOON_DEPLOY_DRY_RUN:-false}" == true ]]; then
    echo 'ONLYOFFICE rendering plan only; no config, credentials, files or API accessed.'
    exit 0
fi
[[ "${SUNMOON_DEPLOY_DRY_RUN:-false}" == false ]] || { echo 'Invalid inherited dry-run mode' >&2; exit 2; }
# Explicit caller values take precedence over deployment configuration defaults.
incoming_namespace="${NAMESPACE:-}"
incoming_service="${SERVICE_NAME:-}"
incoming_port="${SERVICE_PORT:-}"
incoming_host="${UNIFIED_HOST:-}"
declare -A incoming_values=()
for key in JWT_SECRET_VALUE POSTGRESQL_PASSWORD RABBITMQ_PASSWORD REDIS_PASSWORD SECRET_NAME TARGET_SECRET_KEY; do
    if [[ -v "$key" ]]; then incoming_values[$key]="${!key}"; fi
done
source "$SCRIPT_DIR/generate.conf" >/dev/null 2>&1
if [[ -n "${DEPLOY_CONFIG:-}" ]]; then
    [[ -f "$SCRIPT_DIR/$DEPLOY_CONFIG" ]] || { echo 'ONLYOFFICE deployment config missing' >&2; exit 1; }
    source "$SCRIPT_DIR/$DEPLOY_CONFIG" >/dev/null 2>&1
fi
for key in "${!incoming_values[@]}"; do export "$key=${incoming_values[$key]}"; done
export NAMESPACE="${incoming_namespace:-${NAMESPACE:-${ONLYOFFICE_NAMESPACE:-app-platform-dev}}}"
export SERVICE_NAME="${incoming_service:-onlyoffice-docs-${ONLYOFFICE_PROJECT_ID:-sunmoonai}}"
export SERVICE_PORT="${incoming_port:-${ONLYOFFICE_SERVICE_PORT:-8888}}"
export UNIFIED_HOST="${incoming_host:-${ONLYOFFICE_UNIFIED_HOST:-www.sunmoonai.com}}"
# No Harbor auth construction and no random JWT. Only a selected Secret needs a value.
export JWT_SECRET_VALUE="${JWT_SECRET_VALUE:-}" POSTGRESQL_PASSWORD="${POSTGRESQL_PASSWORD:-}"
export RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-}" REDIS_PASSWORD="${REDIS_PASSWORD:-}"
export PVC_ACCESS_MODE="${PVC_ACCESS_MODE:-}" PVC_STORAGE_CLASS="${PVC_STORAGE_CLASS:-}" PVC_STORAGE_SIZE="${PVC_STORAGE_SIZE:-}"
selected=()
matched=()
for resource_config in "${GENERATE_RESOURCES[@]}"; do
    IFS=':' read -r resource_type template_path output_file enabled <<< "$resource_config"
    choose=false
    if [[ ${#requested[@]} -eq 0 ]]; then
        [[ "$resource_type" == secret ]] || choose=true
    else
        for request in "${requested[@]}"; do
            if [[ "$request" == "$output_file" ]]; then choose=true; matched+=("$request"); fi
        done
    fi
    [[ "$choose" == true ]] || continue
    if [[ "$enabled" != true ]]; then
        [[ ${#requested[@]} -gt 0 ]] || continue
        echo 'Selected resource is disabled' >&2; exit 1
    fi
    [[ "$output_file" != */* && "$output_file" != .* && -n "$output_file" ]] || { echo 'Invalid output filename' >&2; exit 1; }
    [[ "$template_path" != *harbor-registry-secret* ]] || { echo 'Harbor Secret belongs to registry-platform' >&2; exit 1; }
    selected+=("$resource_config")
done
for request in "${requested[@]}"; do
    found=false
    for item in "${matched[@]}"; do [[ "$item" != "$request" ]] || found=true; done
    [[ "$found" == true ]] || { echo 'Requested resource is not configured' >&2; exit 1; }
done
[[ ${#selected[@]} -gt 0 ]] || { echo 'No resources selected' >&2; exit 1; }
for resource_config in "${selected[@]}"; do
    IFS=':' read -r resource_type template_path output_file enabled <<< "$resource_config"
    if [[ "$template_path" != /* ]]; then template_path="$SCRIPT_DIR/$template_path"; fi
    python3 -B "$SCRIPT_DIR/render_resource.py" "$template_path" "$SCRIPT_DIR/$output_file" || exit 1
    printf 'Rendered selected resource: %s\n' "$output_file"
done
