#!/bin/bash

# =============================================================================
# 检查 Redis 密码配置
# =============================================================================

set -euo pipefail

# 配置
REDIS_HOST="101.126.151.0"
REDIS_PORT="30446"
REDIS_PASSWORD="${ONLYOFFICE_REDIS_PASSWORD:-}"

echo "=========================================="
echo "检查 Redis 密码配置"
echo "=========================================="
echo "主机: $REDIS_HOST:$REDIS_PORT"
echo ""

# 尝试无密码连接
if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" PING 2>/dev/null | grep -q PONG; then
    echo "⚠️  Redis 未设置密码（可以无密码连接）"
    echo ""
    echo "建议："
    echo "  1. 在 dev-values.yaml 中设置 redisNoPass: true"
    echo "  2. 或者在 Secret 配置文件中留空 REDIS_PASSWORD"
    echo ""
    read -p "是否设置 Redis 密码？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -z "$REDIS_PASSWORD" ]; then
            read -sp "请输入 Redis 密码: " REDIS_PASSWORD
            echo
        fi
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" CONFIG SET requirepass "$REDIS_PASSWORD"
        echo "✅ Redis 密码已设置"
        echo ""
        echo "⚠️  请在 Secret 配置文件中设置："
        echo "  REDIS_PASSWORD=\"$REDIS_PASSWORD\""
    fi
else
    echo "Redis 已设置密码"
    if [ -z "$REDIS_PASSWORD" ]; then
        echo ""
        echo "⚠️  需要在 Secret 配置文件中设置 REDIS_PASSWORD"
        echo "  或者通过以下方式获取密码："
        echo "  1. 查看 Redis 配置文件"
        echo "  2. 查看 Redis Secret"
    else
        # 测试密码
        if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" PING 2>/dev/null | grep -q PONG; then
            echo "✅ 密码验证成功"
            echo ""
            echo "⚠️  请在 Secret 配置文件中设置："
            echo "  REDIS_PASSWORD=\"$REDIS_PASSWORD\""
        else
            echo "❌ 密码验证失败，请检查密码是否正确"
        fi
    fi
fi

