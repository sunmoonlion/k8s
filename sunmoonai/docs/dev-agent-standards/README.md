# agent 开发规范

**通用规范**：换一个 agent、换一个项目仍然成立。具体任务怎样落实、有哪些只对自己成立的规定，
写在任务自己的目录里并链接回这里；本目录不引用任何具体任务。

| 文件 | 内容 |
| --- | --- |
| [`lifecycle.md`](lifecycle.md) | **先读这一份**：五个阶段、任务目录、thread 与 turn 的形状与字段、用户消息写多严、交给 agent 的活八条都成立、定稿、worktree、返工 |
| [`user-message.md`](user-message.md) · [`turn.md`](turn.md) | 两个模板文件，建 turn 时直接复制 |
| [`naming.md`](naming.md) | 命名与编号：thread、turn 与模块的目录名、编号、与运行时的对应，以及门禁的判据 |
| [`glossary.md`](glossary.md) | 词汇表：用词的唯一定义；改名须人确认 |
| [`human-workflow.md`](human-workflow.md) | 人自己走这套流程时怎么做 |
| [`agent-workflow.md`](agent-workflow.md) | 由 supervisor 驱动时怎么做 |
| [`brd/brd-rules.md`](brd/brd-rules.md) | **BRD** 业务需求：还不知道要做什么时先讨论清楚；可选，定稿成 `PRD/` |
| [`prd/prd-rules.md`](prd/prd-rules.md) | **PRD** 产品需求：`PRD/` 怎么写；只写要什么，不写怎么做；定稿成 `SDD/` |
| [`sdd/sdd-rules.md`](sdd/sdd-rules.md) | **SDD** 软件设计说明：`SDD/` 怎么写、设计原则、改已冻结契约；`modules/` 下就是子任务 |
| [`sdp/sdp-rules.md`](sdp/sdp-rules.md) | **SDP** 软件开发计划：一个执行者在自己的 worktree 里动手 |
| [`uat/uat-rules.md`](uat/uat-rules.md) | **UAT** 用户验收测试：三种结论、门的三档、证据采信与覆盖声明 |
| [`detailed-rules/approvals.md`](detailed-rules/approvals.md) | 人的批准点：谁批什么、批准怎样成立、三道正交门、四档审批、改判 |
| [`detailed-rules/protocol/competition-rules.md`](detailed-rules/protocol/competition-rules.md) | 多方竞争协议：一种交回物由多家各交一份再比较选定；同目录另有尚未生效的草案 |
