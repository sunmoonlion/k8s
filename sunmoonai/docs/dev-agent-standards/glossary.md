# 词汇表

standards 的用词以本表为准：**同一个意思只用一个词**，「不要用」一栏的词不得在 standards 里指代同一个意思。
本表只增不改；要改名，按文末「用词纪律」办。各任务把这些词对应到具体产品或执行环境的名字，写在任务自己的目录里，不写在这里。

## 任务与目录

| 词 | 含义 | 不要用 |
| --- | --- | --- |
| 任务 | 交给 agent 做的一件事。一个任务目录就是一个任务；在需求树里也叫节点 | 工单、需求（指任务时） |
| 任务目录 | 一个任务的全部文件：`thread/`、`PRD/`、`SDD/`。目录本身不设任务书 | — |
| 文档 thread | 任务目录 `thread/` 下的一个目录，对应一个运行时 thread；名为「本地号-阶段-运行时 thread id」，阶段是 brd、prd、sdd、sdp、uat。运行时换了 thread 就新开一个 | 会话、turns、rounds |
| 运行时 thread | 执行环境自己的 thread，只有 id；与文档 thread 一对一 | 会话 |
| 运行时 turn | 执行环境自己的 turn，只有 id；一个文档 turn 可能覆盖它好几个 | — |
| 文档 turn | 一问一答：一次派工和它的交回，是文档 thread 下的一个目录。目录名为「本地号-运行时 turn id」，如 `0002-01k8h9t1cc`；本地号四位数字，在所属文档 thread 内按派出顺序编，不跳、不复用；交回即冻结。行文引用写「文档 thread 号/turn 号」，如 `0001/0002` | 轮、轮次、回合 |
| `user-message.md` | turn 里的任务书，就是这一次发出去的全文——这一问 | turn 里的 `task.md` |
| `response.md` | turn 里的答：这一问的回答，只有一份。BRD、PRD、SDD 阶段有；SDP、UAT 阶段的产物在 worktree 里 | 交回物文件、答复目录 |
| `others/` | turn 里可选的一个目录：人或 supervisor 追加给模型的材料与附件 | 附件目录 |
| `turn.md` | 文档 turn 的回执：状态、交回时间、所在提交，交回 UAT 时还有结论；交回时写，写完冻结。没有它就是还没交回 | 状态文件 |
| 并行 | 同一问同时发给几个执行者：各家在各自的运行时 thread 里，所以是几个文档 thread 各开一个 turn，任务书各存各的 | 并行尝试 |
| 任务书 | 发给 agent 的那一问，存为 turn 的 `user-message.md`；须写明这一问要交回哪一种、由哪类 agent 交。见 [任务的生命周期](lifecycle.md)「任务书写多严」 | PRD（指这一问时）、需求文档 |
| 附件 | 与 `user-message.md` 放在一起、随它发出的材料 | — |
| 派工 | 发出一个 turn | — |
| 交回物 | 某个 turn 交回来的东西：BRD、PRD、SDD 阶段是 `response.md`；SDP、UAT 阶段是 worktree 分支上的提交 | 交付物（指这一份时） |
| 定稿 | 人读完 response 后整理出的结论：BRD 的定稿是 `PRD/`，PRD 的定稿是 `SDD/`；写明以哪个 turn 为底、改了什么；整理即批准 | composition、设计稿、交接文件 |
| `architecture/` | `PRD/` 与 `SDD/` 下的一个目录：模块之间的结构与关系；入口文件 `README.md` | composition（指这一层时） |
| `modules/` | `PRD/` 与 `SDD/` 下的一个目录，按「四位号-短名」编号。`PRD/modules/<模块>/` 写这个模块要满足什么；`SDD/modules/<模块>/` 是子任务，内部是同样结构的任务目录。与实现时 worktree 里的模块目录一一对应 | components、子任务目录 |
| 上层任务 | 其 `SDD/modules/` 拆出了子任务的那个任务 | 父任务 |
| worktree | 开发侧的 git worktree：SDP 在里面实现，UAT 的测试在它的 `test/`；审核者在被审的 worktree 之上再开一个 | 工作区（指产品运行时的工作区时） |

## 阶段与交付物

**阶段**有五个：BRD、PRD、SDD、SDP、UAT，规则见 [BRD](brd/brd-rules.md)、[PRD](prd/prd-rules.md)、[SDD](sdd/sdd-rules.md)、[SDP](sdp/sdp-rules.md)、[UAT](uat/uat-rules.md)。每一问的任务书怎么写，见各阶段规则的「这一段的任务书」与 [任务的生命周期](lifecycle.md)「任务书写多严」。

| 词 | 含义 | 不要用 |
| --- | --- | --- |
| BRD | 业务需求：要解决谁的什么问题、做成什么样算解决、边界与取舍。可选的第一段，定稿成 `PRD/` | — |
| PRD | 产品需求：要什么、做到什么算满足，不写怎么实现。`PRD/` 是 BRD 的定稿目录，也是 PRD 阶段的输入；定稿成 `SDD/` | 需求文档（指任务书时） |
| SDD | 软件设计说明：设计成什么样——模块之间的结构与关系、接口、共同约束，以及各模块内部的结构、协议与数据、失败与恢复 | TLD |
| SDP | 软件开发计划：怎样做出来——工作单元、先后顺序、实施记录、代码与证据 | — |
| 工作单元 | SDP 里可以独立交付、验证、回滚的一块 | 任务（指工作单元时） |
| UAT | 用户验收测试：按任务书逐条验证是否满足、能否接收 | — |

## agent 与人

| 词 | 含义 | 不要用 |
| --- | --- | --- |
| discussion agent | 答 BRD、PRD 两段的问 | — |
| 规划 agent（planning） | 答 SDD 段的问；定稿之后按 `SDD/modules/` 的拆分建子任务 | — |
| 执行 agent（execution） | 做 SDP：在自己的 worktree 里实现 | — |
| 验收 agent（acceptance） | 做 UAT：在 worktree 的 `test/` 里验收；不是实现这份 SDP 的那一个 | — |
| supervisor | agent 版里驱动流程的程序：发起 turn、验收、打回、清理 worktree；human 版由人兼这个角色 | — |
| 人 | 写任务书、整理定稿、批准、裁决。standards 里不写具体是谁 | 具体人名或角色名 |
| principal、requester | 持有某项决定权的主体、提出请求的主体；见 [人的批准点](detailed-rules/approvals.md) | — |

## 过程

| 词 | 含义 | 不要用 |
| --- | --- | --- |
| 验收 | 验收 agent 在自己的 turn 里做 UAT，写明验收的是哪个 turn，结论写进回执 | — |
| 打回 | 判定交回物不满足任务书。打回就是开新的 turn，理由写进新 turn 的 `user-message.md` | — |
| 返工 | 同一项交付物因打回而重做；第三次被打回就停下交给人 | — |
| 改判 | 修改标准或判断时写清触发、原判断错在哪、新判断；见 [人的批准点「改判」](detailed-rules/approvals.md) | — |
| 多方竞争 | 一种交付物由多个 agent 各交一份、比较选定；各家的交回各占一个 turn。见 [多方竞争协议](detailed-rules/protocol/competition-rules.md) | 轮次、评优轮 |
| 档位 | T0、T1、T2：这件事该走多重的流程；见多方竞争协议「档位」 | — |
| 冻结 | 已发出的任务书、已交回的交回物不改、不删；要改只能开新的 turn | — |
| 进度 | 从 `thread/`、`PRD/`、`SDD/` 及它们的提交推出的投影；不另写记录或进度文件 | 交接文件、状态文件 |

## 用词纪律

1. 同一个意思只用一个词；新词先进本表再用。
2. **改名须人确认**，按 [改判](detailed-rules/approvals.md) 的三要素写清为什么改，并且一次改遍全仓、跑完检查，不留新旧两名并存。
3. 与具体产品、执行环境的名字怎样对应，写在任务自己的目录里；本表不出现具体产品名。
