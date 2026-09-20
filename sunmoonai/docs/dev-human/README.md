# agent 开发规范

本目录的文件：

| 文件 | 内容 |
| --- | --- |
| [`turn-project.md`](turn-project.md) | **先读这一份**：人要看见的各种投影——任务目录、thread 与 turn 两级、`user-message.md` / `response.md` / `turn.md` 的形状与字段、编号；另有四个种类与**一问属于哪一类**、用户消息写多严、交给 agent 的活八条都成立、worktree、返工 |
| [`user-message.md`](user-message.md) · [`turn.md`](turn.md) | 两个模板文件，建 turn 时直接复制 |
| [`naming.md`](naming.md) | 命名与编号：thread、turn 与模块的目录名、编号、与运行时的对应，以及门禁的判据 |
| [`glossary.md`](glossary.md) | 词汇表：用词的唯一定义；改名须人确认 |
| [`lifecycle.md`](lifecycle.md) | **开发的生命周期**：一问从人发出到人拿到答的七站；与 [agent 版](../dev-agent/SDD/architecture/lifecycle.md) 对照 |
| [`workflow.md`](workflow.md) | 怎么走这套流程：现在的执行者是人 |
| [`finalize.md`](finalize.md) | 定稿：人怎么采纳 response——与批准、验收是三件事 |
| [`approvals.md`](approvals.md) | 人的批准点：对**动作**的放行——谁负责什么、批准绑定什么、裁量底线、人这一侧的义务、改判 |
| [`competition.md`](competition.md) | 多方竞争：一种交回物由多家各交一份再比较选定 |
| [`protocol/`](protocol/README.md) | 多方竞争在本平台怎么做：`GO.md` 是各家每个环节的入口；另有操作闭环与两份未生效草案 |

四个种类各两份：**用户消息怎么写**（规范不规定答；要规范答就在这一问里提）与**怎么定稿**（人把关时对照什么）。

| 种类 | 用户消息怎么写 | 怎么定稿 |
| --- | --- | --- |
| **PRD** 产品需求 | [`prd/message-rules.md`](prd/message-rules.md) 要什么、做到什么算满足 | [`prd/finalize.md`](prd/finalize.md) `PRD/` 怎么写、只写要什么 |
| **SDD** 软件设计说明 | [`sdd/message-rules.md`](sdd/message-rules.md) 怎样满足、问到能开工为止 | [`sdd/finalize.md`](sdd/finalize.md) `SDD/` 怎么写、设计原则、改已冻结契约 |
| **IMP** 实现 | [`imp/message-rules.md`](imp/message-rules.md) 工作区、工作单元、交回与证据 | [`imp/finalize.md`](imp/finalize.md) 交回物怎么把关、合并与发布 |
| **UAT** 用户验收测试 | [`uat/message-rules.md`](uat/message-rules.md) 验哪个提交、按哪几条判<br>另有 [`uat/verify-rules.md`](uat/verify-rules.md)：怎么验——三种结论、门的三档、证据采信、覆盖声明 | [`uat/finalize.md`](uat/finalize.md) 人看结论时把关什么 |
