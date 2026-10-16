# B5 隔离恢复失败

步骤：B4 停止 backend API/worker/scheduler 后，确认三类 Pod 全部退出；开始 B5 静止库备份及两次隔离恢复演练。第一次隔离恢复的目录对账失败，停止在 B5；未运行 B6–B9。随后将 API/worker/scheduler 恢复为 2/1/1，三个 rollout 均成功。

命令：

```text
/home/zymun/worktrees/fable/investment-app/investment-backend/app/.venv/bin/python -B /home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/scripts/kind_database_rehearsal.py --app investment --kubeconfig /home/zymun/.kube/kind-config --cluster-uid 5d71ab3a-ea5a-4535-adc6-d7698d820249 --image harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:d9df1752d5ceb6c085bb8ba00c3b9ca84e41a800b2f4a2dc1e17b087e2e6d2ad --head 20260924_0009 --output /home/zymun/private/investment-wb-20260925 --cutover-release /home/zymun/worktrees/fable/k8s/sunmoonai/app-platform/investment-app/deployment/bundle/release.json
```

输出：备份 dump 已保存，SHA-256 为 `19d01b3e65e91d86a40e25d75db33122ef11d52df0ab00ce312c826f19e58f87`，扫描 18 张表；第一次恢复对账返回：

```text
{"status": "failed", "reason": "restored_catalog_mismatch"}
exit=1
```

私有目录中的 dump、快照和错误诊断文件均保留，未读取或回显其内容。未在 live 数据库运行迁移或授权。
