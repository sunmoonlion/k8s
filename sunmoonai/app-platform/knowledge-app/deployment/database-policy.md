# Knowledge 数据库权限候选

`knowledge_database_policy.py` 是纯加法 GRANT 编译器，没有数据库连接、账号供给、
撤权、迁移或部署入口。依赖五仓并列拓扑中的模板公共六表策略；另外冻结 Knowledge
四张领域表的完整列集合。未知表或列一律拒绝，不自动全量授予。

API 保留摄入受理、状态更新、显式重试与知识检索读取；Provider 意图/回执账仅供
Worker 读取、插入和更新指定进展列。Worker 可创建文档、upsert 文档版本，但不能
伪造新摄入任务或重写其源身份/原始载荷。Scheduler 无 schema/表授权。

现有 `provider_receipts` CLI 的恢复用例需在经授权的 Worker 执行环境中运行，不能
因为 API 缺权限就扩展 API 的回执账授权。数据库权限不替代操作员审批；本包不新增
产品授权机制或正式运维身份。API 本来可以更新 job 状态及 metadata；ACL 不区分
JSON 子字段，也不验证状态转换，更不能把 job 显示成功当作已存在可信检索文档。

使用前必须另外建立：全新独立角色、正确 owner、无继承/PUBLIC/历史/default ACL
旁路。不能用本编译器收紧旧账号，不能向浏览器或不受信 Agent 暴露这些凭据。

普通测试由平台 unittest 收集；真实 PG 测试必须独立 Python 进程，不能混入另一个
App 的同名 `app` 包。先核对一次性 PG 完整 ID、标签、挂载及端口，再设置
`RUNTIME_POLICY_TEST_DATABASE_URL`（只接受 `127.0.0.1:55439/backlog_tests` 测试管理员）
和 `RUNTIME_POLICY_TEST_CONFIRM=disposable-b7q-only`；缺少确认失败，不 skip。
在 k8s 根运行：

```bash
../knowledge-app/knowledge-backend/app/.venv/bin/python -m pytest \
  -c ../knowledge-app/knowledge-backend/app/pyproject.toml \
  sunmoonai/app-platform/scripts/integration/test_knowledge_database_policy_pg.py -q -x
```

复用现有 Backend 测试里的合成 Provider/Artifact/契约样例辅助对象，真实运行迁移、
应用服务、SQL 与 delivery handlers。每例新建并清理自身两个库及四登录身份。
不证明真实 RAGFlow/S3/broker 到达，未接远端 CI，也没有变更业务环境。
