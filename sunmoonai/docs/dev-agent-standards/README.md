# agent 开发规范

进行 agent 开发任务时要遵守的**通用规范**：换一个 agent、换一个项目仍然成立的原则、纪律和交付规范。
具体任务怎样落实、有哪些只对自己成立的规定，写在任务自己的目录里，并链接到这里所依据的规范；这里不引用任何具体任务。
**今后每一个 agent 都按这里的规范开发。**

## 从哪里读起

| 文件 | 内容 |
| --- | --- |
| [`general-rules.md`](general-rules.md) | 通用规则：基本理念、总则、执行者的共同纪律、改判；任务的生命周期（任务目录、turn、定稿与建子任务、返工）——**先读这一份** |
| [`glossary.md`](glossary.md) | 词汇表：standards 用词的唯一定义；改名须人确认 |
| [`approvals.md`](approvals.md) | 人的批准点：谁批什么、批准怎样成立、权限、审批档位、人这一侧的义务 |
| [`prd/prd-rules.md`](prd/prd-rules.md) | PRD（任务书）规则；附录是最严格的一种模板 |
| [`deliverables/sdd/sdd-rules.md`](deliverables/sdd/sdd-rules.md) | SDD 规则：规划 agent 交回的设计，以及执行 agent 实现前的设计 |
| [`deliverables/sdp/sdp-rules.md`](deliverables/sdp/sdp-rules.md) | SDP 规则：执行 agent 交回的计划、实施与交付 |
| [`deliverables/uat/uat-rules.md`](deliverables/uat/uat-rules.md) | UAT 规则：验收 agent 的验证与采信 |
| [`protocol/competition-rules.md`](protocol/competition-rules.md) | 多方竞争协议；同目录另有尚未生效的草案 |

## 任务与交付物

| 目录 | 是什么 | 由谁写 / 交付 | 回答什么 |
| --- | --- | --- | --- |
| [`prd/`](prd/prd-rules.md) | **PRD** · Product Requirements Document（产品需求文档）：即任务——从入口收到的那段文本，一段话或严格写成的任务书 | 人写；由上层设计拆出的，随那份设计经人批准 | 要什么、做到什么算满足 |
| [`deliverables/sdd/`](deliverables/sdd/sdd-rules.md) | **SDD** · Software Design Description（软件设计说明）：结构层写划分、关系与接口，组成层写内部结构、协议、失败与恢复 | 规划 agent（只交 SDD）；执行 agent（实现前可以先交，不拆子任务） | 设计成什么样 |
| [`deliverables/sdp/`](deliverables/sdp/sdp-rules.md) | **SDP** · Software Development Plan（软件开发计划）：拆成可独立交付、验证、回滚的单元，先后顺序，实施记录，代码与证据 | 执行 agent | 怎样做出来 |
| [`deliverables/uat/`](deliverables/uat/uat-rules.md) | **UAT** · User Acceptance Testing（用户验收测试）：按派工时任务里说清的要求逐条验证，证据按规则采信，写明查了什么、没查什么 | 验收 agent（只交 UAT；不是交付被验 SDD 或 SDP 的 agent） | 是否满足、能否接收 |

先后由任务树决定：上层任务交回的结果决定下一步派什么任务；不是每次开发都要把四种都走一遍。

## 多方竞争

任何一种交付物（SDD、SDP、UAT）都可能由多个 agent 各交一份，再比较选定。这时按 [`protocol/`](protocol/competition-rules.md)
的多方竞争协议进行：各自提案、互评、裁决、异议、验收、确认、发布；各任务写明自己的操作做法，状态一律从产物反推，不从声明读取。
