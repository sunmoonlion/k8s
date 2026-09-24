# KIND runner release B 阶段结果（2026-09-25）

结论：B0 身份证据恢复通过，B1–B3（新后端镜像、源码锁、渲染与门禁）通过；A8 仅 knowledge 保持待办已说明的源码锁失败，investment 与 info 通过。B4 维护后，B5 静止库备份已生成，但隔离恢复演练失败于 `restored_catalog_mismatch`。依待办停止在 B5，没有运行 server-dry-run 或部署迁移。失败后将 backend 恢复到维护前副本数并确认 Ready。

## B0 身份证据恢复

新增 `app-platform/scripts/kind_identity_recover.py` 及单元测试。只读核对 live Secret、数据库目录，并执行真实数据库与 AMQP 探针；通过后写入 Git 外私有目录：

`/home/zymun/private/kind-cutover/investment-preparation-kind-b7-recovered-20260925-retry-001`

结果：plan SHA-256 `81070ec30f9acc068005e3710aa2829956c3cbb7cd01f3028bd97ca282549d0e`；数据库 revision `20260911_0007`；数据库权限探针 18 项通过；api/worker/scheduler 三个 AMQP 正向登录及三个跨 vhost 拒绝均通过，未触碰消息。四份输出文件均为 0600。使用 `kind_database_activation.load_preparation` 做过部署入口兼容性校验，结果通过。首次调用系统 Python 因缺少 `amqp` 依赖而在核验开始前失败，没有产生凭据文件；随后使用 investment-backend venv 成功。

恢复脚本相关测试与已有身份准备/激活测试合计 18 项通过。

## B1–B3 / A5–A9

- B1 backend 镜像构建推送成功：`harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:d9df1752d5ceb6c085bb8ba00c3b9ca84e41a800b2f4a2dc1e17b087e2e6d2ad`。
- B2 源码锁更新到 backend commit `923bc0ab6da7d478101542dce9a62b93756c8318`、tree `40557a914472e10e0b7a2bb14c9b0a051199e9bb`；开发输入绑定上述恢复摘要；deployment `.conf` 与镜像/release 匹配。
- A5 渲染通过。bundle diff 仅包含 backend 镜像、backend 源码锁/注解及派生哈希、`runtime_identity_upgrade` 和相应 release 哈希。
- A7 `verify-formal-instance.py` 通过；A9 `plan --cluster KIND` 通过，只读检查显示六个 Deployment 声明正确，`contains_credentials=false`。
- A8 指定测试总计 18 项，唯一失败是待办已知的 knowledge 重渲染/源码锁不一致；investment 与 info 子项通过。info bundle 只刷新了 `development_release.py` 源码哈希，资源 YAML 未变化。另运行其余四组指定测试，17 项全部通过。

## B4–B5

B4 停止 backend API/worker/scheduler，等待三类 Pod 全部消失；前端保持运行。B5 备份 SHA-256 为 `19d01b3e65e91d86a40e25d75db33122ef11d52df0ab00ce312c826f19e58f87`，读取 18 张表后，在第一次隔离恢复对账中失败。私有备份目录为 `/home/zymun/private/investment-wb-20260925`；目录中的 dump、快照及错误诊断文件均保留，未读取或回显其中可能含私密数据的内容。

B5 命令原始标准输出/错误：

```text
{
  "stage": "backup_started",
  "app": "investment",
  "output": "/home/zymun/private/investment-wb-20260925"
}

{
  "stage": "consistent_dump_saved",
  "app": "investment",
  "sha256": "19d01b3e65e91d86a40e25d75db33122ef11d52df0ab00ce312c826f19e58f87",
  "tables": 18,
  "rows": {
    "agent_delivery_failures_legacy_0006": 0,
    "agent_execution_leases": 0,
    "agent_pilot_controls": 0,
    "agent_pilot_requests": 0,
    "agent_runs": 28,
    "agent_sessions": 29,
    "alembic_version": 1,
    "auth_user": 3,
    "checkpoint_blobs": 40,
    "checkpoint_migrations": 10,
    "checkpoint_writes": 363,
    "checkpoints": 160,
    "inbox_message": 0,
    "outbox_dead_letter": 0,
    "outbox_execution": 0,
    "outbox_message": 0,
    "session_events": 278,
    "tool_side_effects": 21
  }
}

{
  "status": "failed",
  "reason": "restored_catalog_mismatch"
}
exit=1
```

失败后将后端恢复为维护前副本数：API 2/2、worker 1/1、scheduler 1/1；三项 rollout 全部成功。未运行 B6–B9，未对 live 数据库执行迁移或授权，也未替换集群镜像。

exit=1
