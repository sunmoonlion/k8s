# 后端：设计层的模块结构与关系

> 依据：[后端要满足什么](../../PRD/requirement.md)。
> 本层定稿以 thread [0001/0001](../../thread/0001-sdd-none/0001-none/user-message.md)、[0001/0002](../../thread/0001-sdd-none/0002-none/user-message.md)、[0001/0003](../../thread/0001-sdd-none/0003-none/user-message.md) 的 response 为底；
> 模块划分本版重切，见下。

## 怎么切的

按 [`control-plane.md`](../../PRD/control-plane.md) 已经命名的五个角色（router、orchestrator、
validator、acceptor、publisher）加上「控制面怎么实现」那一段，切成六块：**中心独立，其余各对一侧**。

| 模块 | 拥有什么 | 朝哪一侧 |
| --- | --- | --- |
| [`0001-state`](../modules/0001-state.md) | 状态机与唯一转换函数、事件表、四本账、outbox 与投递器、任务队列、重启恢复 | **不朝外**，其余五块经它 |
| [`0002-router`](../modules/0002-router.md) | 身份、幂等、建单、契约固定、类别三层判定、Profile 与设备选择 | 客户端 ④ |
| [`0003-orchestrator`](../modules/0003-orchestrator.md) | workflow 游标、按步拆与派发、步骤契约、`escalate` 裁决、方法库与按步工具面 | 内部（经 kernel 与 gateway） |
| [`0004-bridge`](../modules/0004-bridge.md) | 执行端对接：WSS 连接、设备身份与吊销、租约与 fencing、投递器、回传接收 | runtime ① |
| [`0005-interrupt`](../modules/0005-interrupt.md) | 中断与批准：Interaction 的创建与原子消费、两层审批后端侧、批准后执行副作用 | 人（经 ④） |
| [`0006-acceptance`](../modules/0006-acceptance.md) | 确定性验收、语义验收派 Attempt、终态提交的发起、事件流投影与结果取件 | 客户端 ④ |

**各模块承担什么、不承担什么，在 [`SDD/modules/`](../modules/) 下各自那一份**，本表只管关系。

**本版是重切**，不是在旧划分上加减。旧划分按合同七阶段切，而**阶段是时间、不是模块**——
状态机与四本账横穿四块却不归任何一块，P1 只能靠纪律守；新增一种 workflow 步骤类型
要连派发一起改。旧四块的设计取证留在 [`rules/`](../../rules/) 下的四份 `*-notes.md` 里，
本层两份 guide 仍在引用它们。

## 模块之间

- **只有 `0001-state` 能改状态与写账。**其余五块都是「请求 `0001-state` 做一次转换」，不自己写表。
  所有入口共用同一个转换函数，以状态版本比较交换；派发与状态改在同一事务里落 outbox。
- 传递只经数据库与事件流，**不经进程内状态**；后端不驻留内存状态，重启扫非终态恢复。
- **没有独立的待办表。**`control-plane.md` 说的「任务队列」是**执行模式**，不是一张表：
  各块的后台活从持久状态**扫**出来——扫 `QUEUED` 的 Task 知道该派什么，扫过期租约的 Attempt
  知道该回收什么。另存一份待办，就和状态机成了两个真源，那正是同一段里反对图执行框架的理由。
  **唯一的例外是 outbox**：它记的是「待发出的消息」而不是 Task 状态，且与状态改同事务，不构成第二个真源。
- **outbox 的表在 `0001-state`、投递器在 `0004-bridge`**：表必须跟着事务走，worker 必须知道谁在线。
  投递器读表、送出去，送成之后请求 `0001-state` 标记已投递——标记也是状态改，照样经它。
- **`0007` 决定、`0008` 投递**：前者产出「下一步是什么」，后者负责送达与租约。分开是为了让
  「workflow 的步骤类型是开放集合」这句守得住。
- **方法工具经 `0008` 的 ① 通道代理回 `0007` 执行**：清单随派发下发、随换步失效，
  回来时由 `0007` 二次校验。Codex 到头到尾只跟 runtime 说话，「Codex 不直接连后端」没破。
- 与执行端之间只有一条通道，派发、续约、回传、工具调用都走它。

## 未决

- **D10b**：并行 Attempt 的两种含义（冗余择快 / 竞争择优）还没定，它决定 `0003-orchestrator`
  的停止规则与 `0006-acceptance` 的择优逻辑。
- 六块的子任务目录与各自第一个 PRD turn 的用户消息已建，**`executor` 都是 `unassigned`**——
  问已经写好，派给谁待定。用户消息来自本层 [`modules/`](../modules/) 下对应那一份，
  随本层定稿一起生效，人在定稿前可以改。

## 约束

[代码规则](../../../../../rules/constraints.md)、[IMP 规则](../../../../../../dev-human/imp/message-rules.md)，
以及上一层的 [不变量](../../../../architecture/invariants.md)。
