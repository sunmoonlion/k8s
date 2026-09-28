#!/usr/bin/env bash
# Retired general-purpose node loader; do not read old configuration or touch nodes.
printf '%s\n' \
    '旧通用 KIND 镜像加载入口已退役，不再接受镜像列表或扫描 tar 目录。' \
    '发布镜像：./sunmoon harbor publish --batch <绝对路径 JSON>（默认只打印）' \
    '建群自举：sunmoonai/kind-infrastructure/formal/README.md' \
    '退役清单：sunmoonai/kind-infrastructure/docs/harbor-external-integration-plan.md 第 9 节' >&2
return 2 2>/dev/null || exit 2
