# 后端：设计层的模块结构与关系

> 依据：[后端要满足什么](../../PRD/requirement.md)。
> 本层定稿以 thread [0001/0001](../../thread/0001-sdd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-sdd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-sdd-none/0003-none/user-message.md) 的 response 为底；
> 模块划分本版重切，见下。

## 怎么切的

按**朝向**切成七块：**中心与内部判断不朝外，其余各对一侧**。

这不是按合同的七个阶段切——**阶段是时间，不是模块**。每块认领哪些 `F-*` 写在它自己那一份里；
一条义务跨两个模块时，定义放在**主要承担方**那一份，另一方只在自己文档里注明边界。

| 模块 | 拥有什么 | 朝哪一侧 |
| --- | --- | --- |
| [`0001-ledger`](../modules/0001-ledger.md) | 状态机与唯一转换函数、事件表、四本账、outbox 这张表、重启恢复 | **不朝外**，其余六块经它 |
| [`0002-router`](../modules/0002-router.md) | 身份、幂等、建单、契约固定、类别三层判定、Profile 与设备选择 | 客户端 ④ |
| [`0003-orchestrator`](../modules/0003-orchestrator.md) | workflow 游标、按步拆与派发、步骤契约、`escalate` 裁决、方法库与按步工具面 | **不朝外**（经 `0001-ledger` 与 `0004-bridge`） |
| [`0004-bridge`](../modules/0004-bridge.md) | 执行端对接：WSS 连接、设备身份与吊销、租约与 fencing、投递器、回传接收 | runtime ① |
| [`0005-interrupt`](../modules/0005-interrupt.md) | 中断与批准：Interaction 的创建与原子消费、两层审批后端侧、批准后执行副作用 | 人（经 ④） |
| [`0006-acceptance`](../modules/0006-acceptance.md) | 验收：确定性验收、语义验收派 Attempt、终态提交的发起 | **不朝外** |
| [`0007-delivery`](../modules/0007-delivery.md) | 交付：事件流投影与 cursor 续传、结果密文存取、通知 | 客户端 ④ |

**各模块承担什么、不承担什么，在 [`SDD/modules/`](../modules/) 下各自那一份**，本表只管关系。

## 同目录另有三份

| 文件 | 内容 |
| --- | --- |
| [`orchestration-boundary.md`](orchestration-boundary.md) | workflow 的步骤类型是开放集合；编排留在后端、按步下发 |
| [`methods.md`](methods.md) | 方法库的形态与按敏感度分档；跨 Task 上下文 |
| [`subtask.md`](subtask.md) | 子 Task 的派生规则与 `COORDINATION` 依赖编排 |

三方共用的契约（状态机、路由、Profile）不在这一层，在
[上层 `architecture/`](../../../../architecture/README.md)。

## 这七块对着九站的哪几站

上一层的 [请求生命周期](../../../../architecture/lifecycle.md) 把一条请求分成九站。
后端只出现在其中五站，其余四站在桌面应用与执行端：

| 站 | 在哪 | 后端这边是谁 |
| --- | --- | --- |
| 写 message | 桌面应用 + runtime | —— |
| 提交 | 桌面应用 → 后端 | 由 `0002-router` 接住 |
| **受理** | 后端 | `0002-router` |
| **派发** | 后端 → 执行端 | `0003-orchestrator` 决定下一步，`0004-bridge` 送达 |
| 执行 | 执行端 | —— |
| **中断** | 本地窗口 / 后端 | `0005-interrupt`（工具级在本机闭环的那半不经后端） |
| 封装 | 执行端 | —— |
| **验收** | 后端 | `0006-acceptance` 判，终态提交经 `0001-ledger` |
| **交付** | 后端 → 桌面应用 | `0007-delivery` |

`0001-ledger` **不对应任何一站**——它横穿全部五站：每一站的状态改与写账都经它。
这正是它单列的理由（见 [`0001-ledger.md`](../modules/0001-ledger.md)）。

**本版是重切**，不是在旧划分上加减。旧划分按合同七阶段切，而**阶段是时间、不是模块**——
状态机与四本账横穿四块却不归任何一块，P1 只能靠纪律守；新增一种 workflow 步骤类型
要连派发一起改。旧四块的设计取证留在 [`rules/`](../../rules/) 下的四份 `*-notes.md` 里，
本层两份 guide 仍在引用它们。

## 模块之间

- **只有 `0001-ledger` 能改状态与写账。**其余六块都是「请求 `0001-ledger` 做一次转换」，不自己写表。
  所有入口共用同一个转换函数，以状态版本比较交换；派发与状态改在同一事务里落 outbox。
- 传递只经数据库与事件流，**不经进程内状态**；后端不驻留内存状态，重启扫非终态恢复。
- **没有独立的待办表。**合同说的「任务队列」是**执行模式**，不是一张表：
  各块的后台活从持久状态**扫**出来——扫 `QUEUED` 的 Task 知道该派什么，扫过期租约的 Attempt
  知道该回收什么。另存一份待办，就和状态机成了两个真源，那正是同一段里反对图执行框架的理由。
  **唯一的例外是 outbox**：它记的是「待发出的消息」而不是 Task 状态，且与状态改同事务，不构成第二个真源。
- **outbox 的表在 `0001-ledger`、投递器在 `0004-bridge`**：表必须跟着事务走，worker 必须知道谁在线。
  投递器读表、送出去，送成之后请求 `0001-ledger` 标记已投递——标记也是状态改，照样经它。
- **`0003-orchestrator` 决定、`0004-bridge` 投递**：前者产出「下一步是什么」，后者负责送达与租约。分开是为了让
  「workflow 的步骤类型是开放集合」这句守得住。
- **方法工具经 `0004-bridge` 的 ① 通道代理回 `0003-orchestrator` 执行**：清单随派发下发、随换步失效，
  回来时由 `0003-orchestrator` 二次校验。Codex 到头到尾只跟 runtime 说话，「Codex 不直接连后端」没破。
- 与执行端之间只有一条通道，派发、续约、回传、工具调用都走它。

## 未决

- **D10b**：并行 Attempt 的两种含义（冗余择快 / 竞争择优）还没定，它决定 `0003-orchestrator`
  的停止规则与 `0006-acceptance` 的择优逻辑。
- 七块的子任务目录与各自第一个 PRD turn 的用户消息已建，**`executor` 都是 `unassigned`**——
  问已经写好，派给谁待定。用户消息来自本层 [`modules/`](../modules/) 下对应那一份，
  随本层定稿一起生效，人在定稿前可以改。

## 约束

[代码规则](../../../../../rules/constraints.md)、[IMP 规则](../../../../../../dev-human/imp/message-rules.md)，
以及上一层的 [不变量](../../../../architecture/invariants.md)。
