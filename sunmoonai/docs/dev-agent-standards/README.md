# agent 开发规范

进行 agent 开发任务时要遵守的**通用规范**：换一个 agent、换一个项目仍然成立的原则、纪律和交付规范。
具体任务怎样落实、有哪些只对自己成立的规定，写在任务自己的目录里，并链接到这里所依据的规范；这里不引用任何具体任务。
**今后每一个 agent 都按这里的规范开发。**

## 从哪里读起

| 文件 | 内容 |
| --- | --- |
| [`lifecycle.md`](lifecycle.md) | **先读这一份**：任务的生命周期——五个阶段、任务目录、thread 与 turn 的形状与字段、定稿、worktree、返工 |
| [`human-workflow.md`](human-workflow.md) | human 版：人自己走这套流程时怎么做 |
| [`agent-workflow.md`](agent-workflow.md) | agent 版：由 supervisor 驱动时怎么做 |
| [`glossary.md`](glossary.md) | 词汇表：standards 用词的唯一定义；改名须人确认 |
| [`task-brief-rules.md`](task-brief-rules.md) | **任务书**：每个 turn 的 `user-message.md`——这一问要什么、做到什么算满足。附录是最严格的一种模板 |
| [`brd/brd-rules.md`](brd/brd-rules.md) | **BRD** · Business Requirements Document（业务需求）：还不知道要做什么时先讨论清楚；可选，定稿成 `PRD/` |
| [`prd/prd-rules.md`](prd/prd-rules.md) | **PRD** · Product Requirements Document（产品需求）：`PRD/` 目录怎么写——`architecture/` 与 `modules/`；只写要什么，不写怎么做；定稿成 `SDD/` |
| [`sdd/sdd-rules.md`](sdd/sdd-rules.md) | **SDD** · Software Design Description（软件设计说明）：`SDD/` 目录怎么写——模块之间的结构与关系、各模块内部；`modules/` 下就是子任务 |
| [`sdp/sdp-rules.md`](sdp/sdp-rules.md) | **SDP** · Software Development Plan（软件开发计划）：执行者的共同纪律、工作单元、实施记录；产物在 worktree |
| [`uat/uat-rules.md`](uat/uat-rules.md) | **UAT** · User Acceptance Testing（用户验收测试）：开工与完成、门的三档、证据采信；测试写在 worktree 的 `test/` |
| [`detailed-rules/approvals.md`](detailed-rules/approvals.md) | 人的批准点：谁批什么、批准怎样成立、权限、审批档位、人这一侧的义务、改判 |
| [`detailed-rules/protocol/competition-rules.md`](detailed-rules/protocol/competition-rules.md) | 多方竞争协议；同目录另有尚未生效的草案 |

先后由任务树决定：上一段定稿的结果决定下一段问什么；不是每件事都要把五段走一遍。

## 多方竞争

任何一段的交回都可能由多个 agent 各交一份，再比较选定。这时按 [`protocol/`](detailed-rules/protocol/competition-rules.md)
的多方竞争协议进行：各自提案、互评、裁决、异议、验收、确认、发布；各任务写明自己的操作做法，状态一律从产物反推，不从声明读取。
