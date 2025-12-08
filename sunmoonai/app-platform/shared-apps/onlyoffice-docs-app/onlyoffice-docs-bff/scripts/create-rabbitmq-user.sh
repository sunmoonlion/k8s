#!/bin/bash

# =============================================================================
# 创建 RabbitMQ 用户（ONLYOFFICE Docs）
# =============================================================================

set -euo pipefail

# 配置
export KUBECONFIG="${KUBECONFIG:-/home/zym/.kube/cluster-c2-admin.conf}"
NAMESPACE="messaging-platform-dev"
RABBITMQ_USER="onlyoffice_docs"
RABBITMQ_PASSWORD="${ONLYOFFICE_RABBITMQ_PASSWORD:-RabbitMQ@2024!}"  # 从环境变量获取，或使用默认值

echo "=========================================="
echo "创建 RabbitMQ 用户"
echo "=========================================="
echo "命名空间: $NAMESPACE"
echo "用户名: $RABBITMQ_USER"
echo ""

# 查找 RabbitMQ Pod
RABBITMQ_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=rabbitmq 2>/dev/null | grep Running | head -1 | awk '{print $1}')

if [ -z "$RABBITMQ_POD" ]; then
    echo "❌ 未找到运行中的 RabbitMQ Pod"
    echo "请检查 RabbitMQ 是否已部署"
    exit 1
fi

echo "找到 RabbitMQ Pod: $RABBITMQ_POD"
echo ""

# 检查用户是否已存在
if kubectl exec -it "$RABBITMQ_POD" -n "$NAMESPACE" -- rabbitmqctl list_users 2>/dev/null | grep -q "$RABBITMQ_USER"; then
    echo "⚠️  用户 $RABBITMQ_USER 已存在"
    read -p "是否删除并重新创建？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl exec -it "$RABBITMQ_POD" -n "$NAMESPACE" -- rabbitmqctl delete_user "$RABBITMQ_USER" 2>/dev/null || true
    else
        echo "取消操作"
        exit 0
    fi
fi

# 创建用户
echo "正在创建用户..."
kubectl exec -it "$RABBITMQ_POD" -n "$NAMESPACE" -- rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"

# 授予权限
echo "正在授予权限..."
kubectl exec -it "$RABBITMQ_POD" -n "$NAMESPACE" -- rabbitmqctl set_permissions -p / "$RABBITMQ_USER" ".*" ".*" ".*"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ RabbitMQ 用户创建成功！"
    echo ""
    echo "创建信息："
    echo "  用户名: $RABBITMQ_USER"
    echo "  虚拟主机: /"
    echo "  密码: $RABBITMQ_PASSWORD"
    echo ""
    echo "⚠️  请记住此密码，需要在 Secret 配置文件中设置："
    echo "  RABBITMQ_PASSWORD=\"$RABBITMQ_PASSWORD\""
    
    # 验证
    echo ""
    echo "验证用户列表："
    kubectl exec -it "$RABBITMQ_POD" -n "$NAMESPACE" -- rabbitmqctl list_users
else
    echo "❌ 创建失败"
    exit 1
fi

