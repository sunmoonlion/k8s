#!/usr/bin/env bash
# Historical path: do not source configuration or invoke old operations.
printf '%s\n' '旧入口已停用。实现归档：legacy/cloud/sunmoonai/infrastructure/utils/image-cleanup/cron/install-cron.sh' '当前入口：sunmoonai/kind-infrastructure/docs/wsl-space-reclamation-plan.md' >&2
return 2 2>/dev/null || exit 2
