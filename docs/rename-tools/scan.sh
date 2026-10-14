#!/usr/bin/env bash
# 改名盘点：只看会被 R1 改到的源码与配置，不看依赖、构建产物、历史回执、录下来的样例
cd ~/worktrees/qwen
EX=(--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv --exclude-dir=.next --exclude-dir=dist --exclude-dir=results --exclude-dir=__pycache__ --exclude-dir=.pytest_cache --exclude-dir=coverage --exclude-dir=thread --exclude-dir=history --exclude-dir=fixtures --exclude-dir=.build --exclude=*.lock --exclude=pnpm-lock.yaml --exclude=uv.lock --exclude=*.sops.yaml)
REPOS=(info-app knowledge-app investment-app k8s runtime tpl-app)
grep -rIn "${EX[@]}" -E "$1" "${REPOS[@]}"
