# agent 开发规范

进行 agent 开发任务时要遵守的**通用规范**：换一个 agent、换一个项目仍然成立的原则、纪律和交付规范。
具体任务怎样落实、有哪些只对自己成立的规定，写在任务自己的目录里，并链接到这里所依据的规范；这里不引用任何具体任务。
**今后每一个 agent 都按这里的规范开发。**

## 交给 agent 的活，八条都成立

不论哪一段、不论单路还是并行、不论人还是 AI：

1. **不用计划覆盖原始需求**；
2. 只在范围、工具、数据、预算和副作用边界内行动；用户消息没说清边界、而越界会有影响时，先问；
3. **区分事实、推断、假设、缺失和未运行验证的结论**，不可混写；
4. 对可中断的工作持久化检查点；
5. 无法满足完成条件时请求输入或**明确失败**，不交半成品；
6. 在**最终固定版本**上运行与风险相称的验证；
7. 报告盲区、副作用和残余风险；
8. 未经授权不推送、合并、发布、删除远端资产或扩大外部影响。

第 3 条是 [UAT 规则](uat/uat-rules.md) 证据采信的前提：分不清事实与推断，采信分级就无从谈起。

## 从哪里读起

| 文件 | 内容 |
| --- | --- |
| [`lifecycle.md`](lifecycle.md) | **先读这一份**：任务的生命周期——五个阶段、任务目录、thread 与 turn 的形状与字段、用户消息写多严、定稿、worktree、返工 |
| [`human-workflow.md`](human-workflow.md) | human 版：人自己走这套流程时怎么做 |
| [`agent-workflow.md`](agent-workflow.md) | agent 版：由 supervisor 驱动时怎么做 |
| [`user-message.md`](user-message.md) · [`turn.md`](turn.md) | 两个模板文件，建 turn 时直接复制 |
| [`naming.md`](naming.md) | **命名与编号**：thread、turn 与模块的目录名、编号、与运行时的对应，以及门禁的判据 |
| [`glossary.md`](glossary.md) | 词汇表：standards 用词的唯一定义；改名须人确认 |
| [`brd/brd-rules.md`](brd/brd-rules.md) | **BRD** · Business Requirements Document（业务需求）：还不知道要做什么时先讨论清楚；可选，定稿成 `PRD/` |
| [`prd/prd-rules.md`](prd/prd-rules.md) | **PRD** · Product Requirements Document（产品需求）：`PRD/` 目录怎么写——`architecture/` 与 `modules/`；只写要什么，不写怎么做；定稿成 `SDD/` |
| [`sdd/sdd-rules.md`](sdd/sdd-rules.md) | **SDD** · Software Design Description（软件设计说明）：`SDD/` 目录怎么写——模块之间的结构与关系、各模块内部；设计原则与改契约的修订单；`modules/` 下就是子任务 |
| [`sdp/sdp-rules.md`](sdp/sdp-rules.md) | **SDP** · Software Development Plan（软件开发计划）：一个执行者在自己的 worktree 里动手——工作单元、worktree 与分支、两道门禁、并发与事故、交付与保留 |
| [`uat/uat-rules.md`](uat/uat-rules.md) | **UAT** · User Acceptance Testing（用户验收测试）：三种结论、门的三档、证据采信与覆盖声明、验证分层；测试写在 worktree 的 `test/` |
| [`detailed-rules/approvals.md`](detailed-rules/approvals.md) | 人的批准点：谁批什么、批准怎样成立、三道正交门、四档审批、人这一侧的义务、改判 |
| [`detailed-rules/protocol/competition-rules.md`](detailed-rules/protocol/competition-rules.md) | 多方竞争协议：档位、裁量、七个环节、判据与角色；同目录另有尚未生效的草案 |

先后由任务树决定：上一段定稿的结果决定下一段问什么；不是每件事都要把五段走一遍。

**正文没有模板。**问是开放的，固定栏目会给答案定骨架，也会把每一问都推向最严格那一档；要复制的是两个模板文件：[`user-message.md`](user-message.md) 与 [`turn.md`](turn.md)。
各段最少要说清什么，写在各自规则的「这一段的用户消息」里——讨论与设计段几乎没有必填的，
执行与验收段要说清的多（工作区、基线、完成条件、预算、要人批准的动作；被验的提交、判据、证据与分档），
因为执行者与验收者是另一个进程，只知道消息里写了的东西。

## 多方竞争

任何一段的交回都可能由多个 agent 各交一份，再比较选定。这时按 [`protocol/`](detailed-rules/protocol/competition-rules.md)
的多方竞争协议进行：各自提案、互评、裁决、异议、验收、确认、发布；各任务写明自己的操作做法，状态一律从产物反推，不从声明读取。
