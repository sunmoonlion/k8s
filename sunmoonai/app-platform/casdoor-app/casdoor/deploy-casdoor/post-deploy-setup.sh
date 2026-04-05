#!/bin/bash

# Casdoor 首次部署后初始化脚本
#
# 背景：Helm chart 将 PVC 挂载到 /conf，覆盖了镜像内置的 app.conf。
# beego 框架需要 copyrequestbody=true 才能正常读取请求体，
# 缺少此配置会导致登录时报 "unexpected end of JSON input"。
#
# 用法：
#   bash post-deploy-setup.sh [namespace] [--cluster C1|C2]

set -euo pipefail

NAMESPACE="${1:-app-platform-dev}"
RELEASE="casdoor-sunmoonai"

# 找到 Casdoor pod
POD=$(kubectl get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/instance=$RELEASE" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [[ -z "$POD" ]]; then
    echo "[ERROR] 未找到 Casdoor pod (release=$RELEASE, namespace=$NAMESPACE)" >&2
    exit 1
fi

echo "[INFO] 目标 Pod: $POD"

# 检查 app.conf 是否已存在
if kubectl exec -n "$NAMESPACE" "$POD" -- sh -c 'test -f /conf/app.conf && grep -q copyrequestbody /conf/app.conf' 2>/dev/null; then
    echo "[INFO] /conf/app.conf 已存在且包含 copyrequestbody，跳过写入"
else
    echo "[INFO] 写入 /conf/app.conf ..."
    kubectl exec -n "$NAMESPACE" "$POD" -- sh -c 'cat > /conf/app.conf << '"'"'EOF'"'"'
appname = casdoor
httpport = 8000
runmode = dev
SessionOn = true
copyrequestbody = true
logPostOnly = true
EOF'
    echo "[INFO] 重启 Casdoor deployment ..."
    kubectl rollout restart deployment/"$RELEASE" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=120s
    echo "[OK] Casdoor 初始化完成"
fi

echo ""
echo "=== Casdoor 访问信息 ==="
echo "地址：https://casdoor.sunmoonai.com:30443"
echo "账号：admin / 123（建议立即修改密码）"
