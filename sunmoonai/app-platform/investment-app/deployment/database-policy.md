# Investment 数据库权限候选

`investment_database_policy.py` 只返回加法 GRANT，无连接、供给、撤权、迁移或部署入口。
依赖五仓并列拓扑里的模板公共六表策略，额外冻结 Investment 十二张领域/断点表的
完整列集合。缺表、新表或列变化一律拒绝，不根据现场发现自动全量授权。

API 可创建会话/运行、追加事件、受理恢复与取消；取消保留租约 epoch/expires_at 的
列更新，但不能 INSERT 租约或改 owner/command_id。Worker 读请求/控制，写运行快照、
追加事件、登记执行租约与副作用回执，以及真实 LangGraph PostgreSQL 断点。
它不能创建用户会话/运行、不能更新 pilot 审批控制。所有运行角色禁止读写旧失败
归档与 checkpoint_migrations，禁止 DELETE/TRUNCATE；Scheduler 无 schema/表授权。

**列权限不是产品审批或行级安全。**API 的取消列权限并不强制 epoch 只能递增、到期
时间只能设为失效，Worker 的断点权限也不限制它只能访问自己的 thread；原应用的
owner 校验、token 幂等、租约条件和已接受快照仍负责这些边界。只适用于可信 Backend
进程，不能把这些凭据给浏览器、任意工具或不受信 Agent。

测试使用现有 phase0/pilot 图，不代表未来统一 Task/Interaction 审批产品已完成。
真正调用生产 `phase0_postgres_checkpointer`，仅替换其连接配置为测试 Worker 的身份；
不使用管理员或内存 Saver 冒充数据库断点验收，不调用 `setup()`。

前置另行供给：全新独立角色、可信 owner、关闭继承/PUBLIC/历史/default ACL 旁路。
加法 GRANT 不能收紧现有宽权限身份。普通四项策略单测由平台 unittest 自动收集；
真实 PG 需独立 Python 进程和获准的一次性容器。先核完整 ID、标签、挂载与端口，
再设置 `RUNTIME_POLICY_TEST_DATABASE_URL`（精确 `127.0.0.1:55439/backlog_tests` 管理员）
及 `RUNTIME_POLICY_TEST_CONFIRM=disposable-b7r-only`；缺确认失败，不 skip。

```bash
# k8s 根；外部模型、检索、broker 不参与
../investment-app/investment-backend/app/.venv/bin/python -m pytest \
  -c ../investment-app/investment-backend/app/pyproject.toml \
  sunmoonai/app-platform/scripts/integration/test_investment_database_policy_pg.py -q -x
```

夹具每例新建并清理自己精确命名的两个库/四 LOGIN；图外的 draft/citation、远端副作用
和 publish 使用合成替身。未接远端 CI，未改变任何业务身份、镜像或部署。
