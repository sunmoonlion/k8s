# 待确认的业务身份切换边界

目标仅为本机 `kind-kind`：Info、Knowledge、Investment；不是云端部署。
既有维护窗口与 codex-smoke 摄入许可保留，不把它们解释为已批准任意共享基础设施改动。
以下是待执行范围，不是执行成功记录；确认范围后仍须生成和验证具体 payload/digest。

| 对象 | 拟执行变更 |
| --- | --- |
| PostgreSQL 三业务库 | 为每 App 新建 API/Worker/Scheduler 三个独立登录，共 9 个；保留既有独立 Migration 角色及数据 owner |
| 数据库新角色名 | `info_backend_api/worker/scheduler`、`knowledge_backend_api/worker/scheduler`、`investment_backend_api/worker/scheduler`；执行前检查无同名既有对象，否则停止 |
| 权限 | 使用已验证的领域策略；封闭本 App 数据库 PUBLIC/schema/default ACL 的隐式宽权限；不授跨库权限、不影响其它数据库 |
| RabbitMQ | 保持原 App vhost/任务队列/交换机/绑定，新建每 App API/Worker/Scheduler 共 9 用户，名字 `<app>-backend-<role>-v2`；独立随机密码 |
| 运行配置 | 新建 `info-backend-runtime`、`knowledge-backend-runtime`、`investment-backend-runtime`，各 Pod 仅引用其角色键；先校验预声明拓扑，再启用对应模式 |
| 共享启动定义 | 更新 `messaging-platform-dev/rabbitmq-app-definitions` 中明确目标 App 的条目，保留所有非目标用户、vhost、资源和权限，前后逐项比对；不 purge，不盲目整包覆盖 |
| 旧账号 | 先完成备份恢复演练、停止旧写者和排空；新身份验证后使目标旧共享身份不能继续访问对应业务库/vhost，精确处理仍存连接；不删除账号/队列/业务数据 |
| Investment 入口 | 开发发布不再隐式调用旧共享账号供给和历史 LOGIN 切换；新路径须有 fail-closed 门禁、测试和固定发布回执，不直接跳过身份验收 |

备份恢复先行：数据库、必要对象、角色/ACL、旧 Secret 与共享 broker definitions 的恢复
材料必须实际保存于 Git 外的私有目录并验证；日志/回执不含凭据。实际切换还需静止窗口
新备份，按既有开发门禁绑定 cluster_uid、App、release_id 和备份摘要。

回滚不是只换旧镜像：须保持旧源码/镜像/schema/ACL/Secret/definitions 配套，并先隔离
新旧执行者、核外部回执；不会删除任务或伪造完成状态让回滚通过。Info→Knowledge→
Investment 串行，一项失败停止后续 App；不擅自变更 question-data、Casdoor、RAGFlow、
tools/research 等非目标业务。
