# Architecture v2 R6 跨 App 真实竖线方案

状态：`DONE`

日期：2026-08-11

适用分支：`architecture-v2`

上游基线：Info R5 DONE、Knowledge R5 DONE、Investment R5 DONE

## 1. 目标

R6 证明 Architecture v2 的三个独立领域 App 能在正式声明式拓扑中形成一条不掺假的业务竖线：

```text
Info versioned S3 Artifact + transactional delivery outbox
  -> Knowledge service-authenticated ingestion + real RAGFlow index
  -> Investment service-authenticated retrieval + governed citation
```

R6 不以既有索引、任意历史文档、Mock Provider、直接跨库读取或手工伪造下游记录代替闭环。

## 2. 冻结约束

1. 本轮新建唯一、可追踪的 Info 上传版本和真实版本化 S3 Artifact；
2. Info 只能经自己的 Outbox、RabbitMQ Worker 和 `knowledge:ingest` 服务身份通知 Knowledge；
3. Knowledge 必须实际读取并校验 Artifact，调用真实 RAGFlow，最终形成 `indexed` 稳定版本；
4. Investment 只能经 `knowledge:retrieve` 独立服务身份和 Knowledge v1 API 检索；
5. 检索必须按本轮 `source_document_version_id` 过滤，并返回同一 content hash；
6. Citation 只保存稳定 lineage 和受控相对链接，不泄漏 Artifact URI、Provider ID 或正文到证据文件；
7. 重放同一 Info 交付只能命中同一 Knowledge ingestion/version，不得产生第二份领域或 Provider 绑定；
8. Info、Knowledge、Investment 仍使用独立数据库；验证器只在各 App 自己的 Pod 内读取本地状态；
9. 所有正式工作负载使用本轮测试通过并写回 formal bundle 的不可变 digest 和已冻结服务身份，
   禁止用 `kubectl set image/env` 形成未声明临时覆盖；
10. R6 不删除 R5 回滚资产，不标记正式 `2.0.0`；这些属于 R7。

## 3. 施工步骤

### R6-V0 正式拓扑与契约预检

- [x] 三套 R5 API/Worker/Scheduler 和 RAGFlow Ready；
- [x] Info 正式 ingest URL 从旧零副本 Service 修正为 `knowledge-r5-backend`；
- [x] Info ingest、Investment retrieve 与 Knowledge resource binding 保持独立最小 Secret；
- [x] 三套正式声明重复 apply 后零漂移。

### R6-V1 唯一 Info 事实与可靠投递

- [x] 创建带唯一 marker 的 Markdown 上传版本；
- [x] S3 object/version/hash/lineage 均由 Info 正式服务生成；
- [x] 同事务创建 Distribution 与唯一 Outbox；
- [x] 真实 RabbitMQ publish 和 Info Worker 消费完成；
- [x] Distribution 与 Outbox 进入 succeeded/completed。

### R6-V2 Knowledge 真实摄取与索引

- [x] `knowledge:ingest` 服务身份通过，跨关系身份不能替代；
- [x] Artifact 的 bucket、prefix、version、size 与 hash 校验通过；
- [x] 真实 RAGFlow 完成上传、解析和索引；
- [x] Knowledge ingestion=succeeded、version=indexed；
- [x] Knowledge stable IDs 与 Info version/hash 对齐。

### R6-V3 Investment 检索、引用与重放

- [x] Investment Worker 使用独立 `knowledge:retrieve` 身份；
- [x] 精确版本过滤返回本轮 governed evidence；
- [x] Citation lineage 与 Knowledge/Info 一致且无 Provider 字段；
- [x] 重放相同 Distribution 后 Knowledge ingestion/version 仍各为 1；
- [x] Outbox 使用同一操作 ID 完成第二次 at-least-once 交付。

### R6-V4 声明式与证据收口

- [x] 三套 formal bundle 静态门禁、server-side dry-run、apply、零漂移通过；
- [x] R6 证据只包含稳定 ID、状态、计数和安全布尔值；
- [x] KIND 临时 Job/Pod/port-forward 全部清理；
- [x] GitHub/Gitee `architecture-v2` SHA 对齐后标记 R6 DONE。

## 4. 退出门禁

只有 V0～V4 全部闭合，且单次真实竖线与相同消息重放都通过，才能进入 R7。任何 Mock、旧
Service 回退、直接数据库跨读、只到 `artifact_verified`、检索任意历史索引或 Provider 字段泄漏都
视为失败。

## 5. 验收结论

2026-08-11 的 KIND 门禁已证明完整真实竖线及同消息重放均通过。重放后仍只有一个 Knowledge
ingestion、一个 Knowledge document version 和一个 Provider binding；证据见
`evidence/R6-cross-app-vertical/result.json`。施工中发现并修复了 UUID 数据库默认值缺口、Info
outbox commit 后 ORM 过期读取，以及 Celery 多任务复用跨事件循环 asyncpg 连接池三个真实缺陷；
修复均已进入对应正式镜像与声明式 bundle，不存在集群临时覆盖。
