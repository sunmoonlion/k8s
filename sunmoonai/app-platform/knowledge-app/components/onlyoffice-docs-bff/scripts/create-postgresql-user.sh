#!/bin/bash

# =============================================================================
# 创建 PostgreSQL 用户和数据库（ONLYOFFICE Docs）
# =============================================================================

set -euo pipefail

# 配置
PGHOST="101.126.151.0"
PGPORT="30444"
PGUSER="postgres"
PGPASSWORD="${PGPASSWORD:-PostgreSQL@12345}"  # 从环境变量获取，或使用默认值
DB_USER="onlyoffice_docs"
DB_NAME="onlyoffice_docs"
DB_PASSWORD="${ONLYOFFICE_DB_PASSWORD:-OnlyOffice@2024!}"  # 从环境变量获取，或使用默认值

echo "=========================================="
echo "创建 PostgreSQL 用户和数据库"
echo "=========================================="
echo "主机: $PGHOST:$PGPORT"
echo "管理员用户: $PGUSER"
echo "新用户: $DB_USER"
echo "新数据库: $DB_NAME"
echo ""

# 检查是否已存在
export PGPASSWORD="$PGPASSWORD"
if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    echo "⚠️  用户 $DB_USER 已存在"
    read -p "是否删除并重新创建？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;
EOF
    else
        echo "取消操作"
        exit 0
    fi
fi

# 创建用户和数据库
echo "正在创建用户和数据库..."
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ PostgreSQL 用户和数据库创建成功！"
    echo ""
    echo "创建信息："
    echo "  用户名: $DB_USER"
    echo "  数据库: $DB_NAME"
    echo "  密码: $DB_PASSWORD"
    echo ""
    echo "⚠️  请记住此密码，需要在 Secret 配置文件中设置："
    echo "  POSTGRESQL_PASSWORD=\"$DB_PASSWORD\""
else
    echo "❌ 创建失败"
    exit 1
fi

