#!/usr/bin/env bash
# Historical path: do not source configuration or invoke old operations.
printf '%s\n' '旧入口已停用。实现归档：legacy/local/sunmoonai/kind-infrastructure/deploy-kind/build-kind-node-image/build-kind-node-image.sh' '当前入口：sunmoonai/kind-infrastructure/formal/README.md' >&2
return 2 2>/dev/null || exit 2
