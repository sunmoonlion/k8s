#!/usr/bin/env bash
# 修复步骤脚本权限

cd ~/master/k8s/sunmoonai/infrastructure/steps

# 给所有步骤脚本添加执行权限
chmod +x step*.sh

# 显示权限
ls -la step*.sh

echo "权限修复完成"
