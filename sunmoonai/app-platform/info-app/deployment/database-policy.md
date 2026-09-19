# Info 数据库权限候选

`info_database_policy.py` 只返回加法 GRANT，不连接数据库，不供给账号或修改部署。
依赖五仓并列拓扑中的 `tpl-app/k8s-deployment/runtime_database_policy.py`；公共六表
授权原样复用，Info 只增加自己的领域授权。完整证据见
[B7p 验证报告](../../../docs/legacy-backlog/verification-index.md)。

前置条件是全新独立角色、可信对象所有者、没有继承/PUBLIC/历史/default ACL 旁路。
不能将输出用于“收紧”现有宽权限账号；也不替代行级、租户、浏览器或工具权限。
运行角色没有旧投递归档读写权限；运维盘点应另用获准的只读审计身份。

普通测试跟随平台 `unittest discover`。真实 PG 门禁需要独立的一次性容器，先核对完整
ID、标签、挂载和 `127.0.0.1:55439` 映射；只接受 `backlog_tests` 测试管理员连接，
使用环境变量 `RUNTIME_POLICY_TEST_DATABASE_URL` 与
`RUNTIME_POLICY_TEST_CONFIRM=disposable-b7p-only`。没有环境确认会失败，不 skip。
在 k8s 根运行（不要与其他 App 的 PG 测试放在同一 Python 进程）：

```bash
../info-app/info-backend/app/.venv/bin/python -m pytest \
  -c ../info-app/info-backend/app/pyproject.toml \
  sunmoonai/app-platform/scripts/integration/test_info_database_policy_pg.py -q -x
```

测试真实运行 Info 全部迁移、应用服务及 delivery handlers；外部 HTTP、对象存储、
搜索和 Knowledge 客户端为替身。只在新测试库安装旧迁移所需 `uuid-ossp`，不改已有
迁移。每例独立创建、清理精确命名的两个库与四登录角色；不是生产供给器，未接远端 CI。
