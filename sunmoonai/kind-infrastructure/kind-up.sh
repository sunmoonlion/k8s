#!/usr/bin/env bash
# Historical path: do not source configuration or invoke old operations.
printf '%s\n' '旧入口已停用。实现归档：legacy/local/sunmoonai/kind-infrastructure/kind-up.sh' '当前入口：sunmoonai/kind-infrastructure/formal/README.md' >&2
return 2 2>/dev/null || exit 2
