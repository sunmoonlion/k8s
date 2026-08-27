# 架构决策记录（ADR）

> 最后更新：2026-08-27
>
> **ADR 追加不覆写。**一条决策被推翻时，写新的一条并在旧的一条上标注"被 ADR-XXXX 取代"，
> 不删除、不改写原文——作废的判断本身是证据，它记录了当时的信息状态。
>
> 这与 [`../`](../) 下的其他文档相反：那些是**现状投影，覆盖式重写**；
> ADR 是**决策历史，只追加**。两种修改语义不同，所以分开放。

## 这里回答什么

其他文档回答"**是什么**"，ADR 回答"**当初为什么这么定**"。
读到一条看起来别扭的约束时，先来这里找它的来由，再决定要不要挑战它。

## 索引

两批：0001–0006 是领域与集成的奠基决策（2026-06-11）；
0007–0013 是 Architecture v2 重构期的拓扑收敛决策（2026-08-01）。

| # | 决策 | 状态 | 相关 |
| --- | --- | --- | --- |
| [0001](0001-domain-boundaries.md) | 按长期业务领域划分 App，不按页面或部署组件划分 | 已接受 | [总览 §1](../../overall-architecture.md) |
| [0002](0002-system-of-record.md) | 每类业务数据只有一个权威主档，其余存储只保存引用/快照/可重建副本 | 已接受 | [`topics/data.md`](../topics/data.md) |
| [0003](0003-sync-and-event-integration.md) | 同步 API 与异步事件并用：即时查询走版本化同步 API，长耗时走事件 | 已接受 | [`topics/contracts.md`](../topics/contracts.md) |
| [0004](0004-object-storage-ownership.md) | 对象存储按领域拥有：物理可共享，Bucket / 凭据 / 生命周期必须隔离 | 已接受 | [`topics/data.md`](../topics/data.md) |
| [0005](0005-ragflow-as-derived-system.md) | **RAGFlow 是可重建的派生系统**，不保存唯一原文 | 已接受 | [`repos/knowledge-app.md`](../repos/knowledge-app.md) |
| [0006](0006-template-components-and-domain-boundaries.md) | 模板组件不定义领域边界；运行角色不等于领域服务 | **部分被取代**（0007 / 0008 / 0012） | — |
| [0007](0007-one-canonical-backend-per-app.md) | **每个领域 App 只有一个规范 Backend**（取代 admin/web 双 Backend） | 已接受 | [总览 §3](../../overall-architecture.md) |
| [0008](0008-backend-repository-convergence.md) | 以现有 Admin Backend 的 Git 历史主线收敛规范 Backend 仓库 | 已接受 | [`repos/`](../repos/) |
| [0009](0009-api-surfaces-and-identity.md) | **Admin / Web / Internal 是接口分面，不是三套应用层** | 已接受 | [`topics/identity.md`](../topics/identity.md) |
| [0010](0010-database-convergence.md) | 每个 App 收敛一个逻辑数据库和一条迁移链 | 已接受 | [`topics/data.md`](../topics/data.md) |
| [0011](0011-backend-runtime-roles.md) | **一个 Backend 代码库按运行角色部署**（API/Worker/Scheduler/Migration） | 已接受 | [总览 §3.1](../../overall-architecture.md) |
| [0012](0012-template-first-adoption.md) | **模板优先**：公共能力先进模板过门禁，再完整同步实例 | 已接受 | [`repos/tpl-app.md`](../repos/tpl-app.md) |
| [0013](0013-release-artifact-lifecycle.md) | 源码、镜像、部署与数据基线**共同发布**；仅靠 Git 标签不能恢复运行环境 | 已接受 | [`topics/release.md`](../topics/release.md) |

## 读的顺序

不必全读。按需：

- **要理解为什么是三个独立 App 而不是一个大 App** → 0001
- **要理解 RAGFlow / Elasticsearch 为什么不能当主档** → 0002、0005
- **要理解为什么只有一个 Backend、却有四个进程** → 0007、0011
- **要理解为什么改公共能力必须先动模板** → 0012
- **要理解为什么部署只认 digest 不认 tag** → 0013

## 提一条新 ADR

一条决策够格进这里，当且仅当它**会约束以后每个 App 或每个实例的做法**。
只影响单个 App 内部实现的选择不是 ADR。

编号全局递增、一经占用不复用。格式沿用现有：标题 / 状态 / 日期 / 背景 / 决策 / 后果。
被取代时在旧文件头部追加一行说明及取代者编号。
