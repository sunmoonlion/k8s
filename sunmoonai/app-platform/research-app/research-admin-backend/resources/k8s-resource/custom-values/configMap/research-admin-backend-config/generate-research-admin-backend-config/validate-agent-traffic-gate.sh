#!/usr/bin/env bash
set -euo pipefail

yaml_file="${1:-}"

if [[ -z "$yaml_file" || ! -f "$yaml_file" ]]; then
    echo "[ERROR] 用法: $0 <research-admin-backend-config.yaml>" >&2
    exit 2
fi

v4_count="$(grep -cE '^[[:space:]]+AGENT_V4_TRAFFIC_ENABLED:[[:space:]]+"false"[[:space:]]*$' "$yaml_file" || true)"
v5_count="$(grep -cE '^[[:space:]]+AGENT_V5_TRAFFIC_MODE:[[:space:]]+"off"[[:space:]]*$' "$yaml_file" || true)"

if [[ "$v4_count" != "1" ]]; then
    echo "[ERROR] AGENT_V4_TRAFFIC_ENABLED 必须且只能为 \"false\"" >&2
    exit 1
fi

if [[ "$v5_count" != "1" ]]; then
    echo "[ERROR] AGENT_V5_TRAFFIC_MODE 必须且只能为 \"off\"" >&2
    exit 1
fi

echo "[SUCCESS] Agent traffic gates are closed"
