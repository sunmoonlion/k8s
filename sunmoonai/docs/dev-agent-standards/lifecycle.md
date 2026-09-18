# 任务的生命周期

任务不是事先排好的：一段一段问出来、答出来、定稿，再由定稿长出下一段和下一层。
本文写两版共同的骨架；人做和 agent 做不同的地方，见 [human 版](human-workflow.md) 与 [agent 版](agent-workflow.md)。

## 五个阶段

| 阶段 | 问什么 | 答（response）在哪 | 定稿成什么 |
| --- | --- | --- | --- |
| **BRD** 业务需求（可选） | 还不知道要做什么时，先讨论要解决什么问题 | turn 里 | `PRD/` 目录 |
| **PRD** 产品需求 | 按定稿的需求出设计 | turn 里 | `SDD/` 目录 |
| **SDD** 设计 | 按定稿的设计实现 | turn 里 | 实现（worktree） |
| **SDP** 实现 | 做出来 | 各自的 worktree | 审核通过后合并到 master |
| **UAT** 验收 | 验证是否满足 | worktree 的 `test/` | 验收结论写进回执 |

已经清楚要做什么时，可以直接从 PRD 起；不是每件事都要把五段走一遍。

## 一个例子

1. 一开始只有一句话：「做一个 AI 投资研究工具」。第 `0001` 个 thread 是 BRD：人问、AI 答、人改，几个 turn 之后人把 response 定稿成 `PRD/`。
2. 第 `0002` 个 thread 是 PRD：拿定稿的需求去问设计，response 定稿成 `SDD/`。`SDD/architecture` 写模块之间的结构与关系，`SDD/modules/` 下每个模块一个目录，就是一个子任务。
3. 某个子任务开自己的 thread，同样走 BRD、PRD、SDD 三段（需要哪段走哪段），再往下拆。
4. 要动代码时开 SDP thread：用户消息发出去，执行者在自己的 worktree 里做；回执记分支与提交。
5. UAT thread 派给验收者，测试写在 worktree 的 `test/`，结论写进回执。判定不通过，就在新的 turn 里写明理由重做。
6. 同一项交付物被打回第三次，停下来交给人判断。

## 任务目录里放什么

```text
<任务目录>/
├── thread/
│   └── <四位号>-<阶段>-<运行时 thread id>/     阶段是 brd、prd、sdd、sdp、uat
│       └── <四位号>-<运行时 turn id>/
│           ├── user-message.md   问：这一次发出去的用户消息
│           ├── response.md       答：BRD、PRD、SDD 阶段有；SDP、UAT 没有
│           ├── turn.md           交回时写的回执
│           └── others/           可选：人或 supervisor 追加的材料与附件
├── PRD/                          BRD 的 response 定稿
│   ├── architecture/             模块之间的结构与关系
│   └── modules/<四位号>-<短名>/  每个模块要满足什么
└── SDD/                          PRD 的 response 定稿
    ├── architecture/
    └── modules/<四位号>-<短名>/  子任务：内部是同样结构的任务目录
```

- `architecture/` 是目录，入口文件 `README.md`，可以再拆多份。
- `modules/` 与实现时 worktree 里的模块目录**一一对应**；**以定稿为准**：代码结构要变，先改定稿。
- 同一个模块在 `PRD/modules/` 与 `SDD/modules/` 下是同一个模块：前者写它要满足什么，后者是它的子任务目录。
- 改动过的代码留在 worktree 与它的提交里，不拷进任务目录。
- **不另写记录或进度文件。**做到哪、谁在做、第几次返工、在等谁，都从这些目录与提交推出来；给人看的进度视图是投影。
- **目录只是一种载体。**换成数据库、Issue、PR 或事件流承载也可以，但**不能丢失原始请求、边界、验收、基线、证据和改判历史**。

## thread 与 turn

目录名、编号与运行时的对应关系见 [命名与编号](naming.md)；这里只写生命周期本身的规矩。

- **一个文档 thread 对一个运行时 thread**：运行时换了 thread（resume、fork、上下文压缩后重开），就新开一个文档 thread，接着做什么写在它第一个 turn 的用户消息里。
- **一个 turn 就是一问一答**：`user-message.md` 是问，`response.md` 是答。
- **发出时就把用户消息存进 `user-message.md`**：发出去的是什么，存的就是什么，包括附带的打回理由。模型只知道这些，判断交回对不对也以此为准。
- **response 只有一份**，是这一问的答，写成一个文件。它是草稿：定稿时才拆进 `PRD/` 或 `SDD/` 的 `architecture/` 与 `modules/`。
- SDP、UAT 阶段的 turn **没有 `response.md`**：产物在各自的 worktree 里，UAT 的测试放 worktree 的 `test/`。回执里记分支与提交。
- **turn 交回即冻结**，不改、不删；要改，只能开新的 turn。
- **turn 只负责问，不承载审核**。审核意见不写进已有的 turn；要重做就开新 turn，理由写进它的 `user-message.md`。
- **并行**：同一问同时发给几个执行者时（多方竞争，或多次尝试取最好的一次），各家在各自的运行时 thread 里，所以是几个文档 thread 各开一个 turn，用户消息各存各的；定稿写明以哪一个为底。

## 用户消息写多严

用户消息就是发出去的那一问，存成 `user-message.md`。**模型只知道用户消息里写了的东西**：要它交回什么、能改哪些文件、
哪些动作必须先问人、有哪些背景和出处——凡是要它知道、要它遵守的，都必须写进去。没有哪个机制会替它补上。

写多严按任务轻重。下面说的是任务里要**表达出什么**，不是要用什么格式：一段自然语言说清了就算满足。

| 程度 | 适用 | 至少要说清 |
| --- | --- | --- |
| 一段话 | 可逆、局部、方向明确（T0） | 要什么、交回哪一种，以及要它遵守的任何限制 |
| 加边界与验收 | 影响跨多个文件或多个仓（T1） | 要什么、交回哪一种、范围、验收标准 |
| 按模板填全 | 命中任一条 T2 判据：不可逆、权威层、已知对立、判据未定 | 本阶段模板的每一栏；不适用的写「不适用」及理由 |

档位判据见 [多方竞争协议](detailed-rules/protocol/competition-rules.md)「档位」；各阶段的模板与本阶段要写清什么，见各自的规则。

- **用户消息由人写**；由上层定稿拆出的任务，用户消息来自定稿的相应一节，随定稿一起生效，人在定稿前可以修改。
- **写清边界**：含什么、不含什么、不含的归谁——否则执行者会自行扩大范围，或漏掉本该做的。
- **给可判定的验收标准，不给倾向性结论**——否则产出向写用户消息的人的结论收敛，等于白问。
- 验收标准在派工前定下；**出题的人与答题的 agent 分开**。agent 不改用户消息，发现用户消息有问题时停下来问。
- 哪些动作需要人批准，见 [人的批准点](detailed-rules/approvals.md)；写用户消息的人要把它们写进用户消息。人这一侧的其余义务见同一份的「人这一侧的义务」。

## turn 的固定字段

`user-message.md` 开头用下面几项（YAML 头），发出时写好，随用户消息冻结：

| 字段 | 写什么 |
| --- | --- |
| `executor` | 派给谁；**还没派出去写 `unassigned`** |
| `verifies` | 只有 UAT 填：验收的是哪个 turn，写「thread 号/turn 号」，如 `0004/0001` |

阶段不进 YAML 头：它的唯一真源是 thread 目录名（见 [命名与编号](naming.md)），正文里那句「交回什么」把它当面告诉模型。

`turn.md` 交回时写，写完冻结；**没有 `turn.md` 就是还没交回**：

| 字段 | 写什么 |
| --- | --- |
| `status` | `completed`、`interrupted` 或 `failed` |
| `completed_at` | 交回时间 |
| `commit` | response 所在的提交；SDP、UAT 填 worktree 分支上的提交 |
| `worktree` | 只有 SDP、UAT 填：分支名 |
| `provider_record` | 运行时自己的记录在哪；没有写 `none` |
| `error` | 只有 `failed` 填：失败原因 |
| `reason` | 只有 `interrupted` 填，且必填：`interrupted`、`replaced`、`review-ended`、`budget-limited` 或 `cancelled` |
| `verdict` | 只有交回 UAT 时填：`pass`、`fail` 或 `undecidable` |

不知道的值写 `unknown`，还没发出的写 `pending`，不得空着。

## 定稿

- **读完 response 再定稿**：BRD 的 response 定稿成 `PRD/`，PRD 的 response 定稿成 `SDD/`。定稿时写明以哪个 turn 为底、改了什么。整理即批准；批准怎样才算成立，见 [人的批准点](detailed-rules/approvals.md)。
- **子任务从 `SDD/modules/` 长出来**：只有定稿设计里拆出的模块才建子任务目录，同时写好它第 `0001` 个 turn 的 `user-message.md`。**不预先建还没派出的子任务。**
- 定稿改版后拆分变了：新多出来的模块建新目录；不再需要的**不删目录**，由上层定稿写明「第 n 版起取消」及原因，该子任务不再开新的 turn。
- SDD 的 response 定稿之后就该动代码：这一段的「定稿」是实现本身，走下面的 worktree。

## SDP 与 UAT 的 worktree

- 执行者在自己的 git worktree 里实现；验收者在 worktree 的 `test/` 里写测试。
- 交回时 `turn.md` 记分支与提交；产物不拷进任务目录。
- 审核者在被审的 worktree 之上再开一个审核 worktree，逐层向上，最后合并到 master。层数、谁审谁、谁清理，两版不同，见 [human 版](human-workflow.md) 与 [agent 版](agent-workflow.md)。
- **worktree 完成后才清理**；清理前分支或标签必须留下——工作区可以删，提交不能跟着消失。

## 返工怎么做、最多几次

- **打回就是开新的 turn**：理由写进新 turn 的 `user-message.md`——任务里的哪一条要求（或本规范的哪一条）没满足、证据在哪、要求改什么；任务本身没说清、无法判定的，写「不可判」并交给人，不自己发明标准。返工派回出问题的那一段——设计有问题回设计，实现有问题回实现。
- 标准或判断变了，写进新 turn 的 `user-message.md`，并写清改判三要素：触发、原判断错在哪、新判断（见 [人的批准点「改判」](detailed-rules/approvals.md)）。
- **同一项交付物被打回第三次时停下**：不再开新的 turn，由人判断是用户消息本身有问题、判据写错了，还是要换做法或换执行者；人的裁决写进下一个 turn 的 `user-message.md` 后才能继续。
- 返工上限可以在 turn 的 `user-message.md` 里按任务调整；**调高上限须人确认**——多给几次自动重来的机会，就是少一次人的检查。
- 某项交付物需要多个 agent 各交一份再比较时，按 [多方竞争协议](detailed-rules/protocol/competition-rules.md) 进行；各家的交回各占一个 turn，竞争内部的回退不计入本任务的返工次数，竞争的最终结果被打回才计入。
