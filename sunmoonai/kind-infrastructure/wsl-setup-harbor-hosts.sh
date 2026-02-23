#!/usr/bin/env bash
#
# 在 WSL 宿主机 /etc/hosts 中添加 harbor.sunmoonai.com 解析，
# 便于在宿主机访问 Harbor（浏览器、docker login、docker pull 等）。
# 需在 WSL 中执行，且需 sudo 写 /etc/hosts。
#
set -euo pipefail

HARBOR_HOST="${HARBOR_HOST:-harbor.sunmoonai.com}"
# Kind 将 30443 映射到宿主机，故宿主机用 127.0.0.1；集群外 Harbor 时改为该入口 IP
HARBOR_IP="${HARBOR_IP:-127.0.0.1}"

if ! grep -q "[[:space:]]${HARBOR_HOST}[[:space:]]*$" /etc/hosts 2>/dev/null && \
   ! grep -q "[[:space:]]${HARBOR_HOST}$" /etc/hosts 2>/dev/null; then
    echo "添加 ${HARBOR_IP} ${HARBOR_HOST} 到 /etc/hosts"
    echo "${HARBOR_IP} ${HARBOR_HOST}" | sudo tee -a /etc/hosts
else
    echo "已存在 ${HARBOR_HOST} 解析，跳过"
fi
