参与方：luna｜worktree：/home/zym/worktrees/luna/k8s｜HEAD：ef6922da0db09352859a7b81e9deef4143ac4b6b
# runtime 轮 ④ 异议：luna

已读裁决方处置记录钉定版：332 行，SHA-256
`9f140f121349782a3ea3796e706f10f21de469c44257a6f568973a900be91d85`。本文只对关于 luna 的处置提一条异议；
对 C.2 其余四项更正及 G-1–G-7 的吸收无异议。

## O-L1：拆除条件 5 不应整项拒绝

### 处置条目

处置记录 `6cefa580:runtime-disposition.md:93,278` 将 luna 的拆除条件 5 概括为
“无命令入口者从可路由集合移除”，以其与 `task.md` §6.4 要求处理“存在但不可自动分发”的执行者相悖为由，
裁定 **拒绝**。

### 为什么错

该概括漏掉了原主张二选一的第一支，也混淆了“登记集合”和“自动路由候选集合”。luna 原文
`1ddff5c2:runtime-architecture.md:133-134` 是：无命令入口者**要么**经显式 `human_bridge` 产生可审计 Delivery，
**要么**从可路由集合移除；它没有要求从 Agent Profile 登记表删除执行者。

冻结任务书 `runtime/h1:task.md:352-361` 要求 schema 能登记“存在但不可自动分发”的执行者。这与上述主张相容：

1. 有显式人工桥的执行者仍登记，但不冒充 argv 自动分发；
2. 没有命令入口、也没有显式桥的执行者不得进入自动路由候选集。

裁决稿本身也采用了这一语义：`023bd75d:runtime-architecture.md:140-160` 登记
`dispatch = manual` / `observability = fs-only`，`:185-187` 用可审计 `dispatch_event` 记录人工传输，
`:231-238` 又把 `dispatch = manual` 与 argv adapter 分开。因此处置记录一面拒绝该条件，一面在裁决稿里采用其
“显式桥接、不得冒充自动分发”的实质，处置分类与实际吸收不一致。

这不是重述 ① 的偏好，而是用冻结任务书的集合语义和裁决稿的实际实现，指出处置理由中的类别混淆。

### 应当是什么

将机器可读处置表中 luna 的“拆除条件 5”由 **拒绝** 改为 **部分接受**，并把 C.2 的处置改为：

> 接受“无命令入口者必须显式桥接，否则不得进入自动路由候选集”的强制条件；术语采用基座的
> `dispatch = manual` + `dispatch_event`，并把“可路由集合”澄清为“自动路由候选集”。Agent Profile 仍保留登记。

这样既保留 fable 的可数传输欠账，也保留 luna 条件真正禁止的失败模式：不可见手工粘贴被宣称为自动分发。

### 可复跑证据

```bash
git show 1ddff5c2:sunmoonai/docs/dev-plan/runtime-architecture.md | \
  nl -ba | sed -n '127,138p'

git show runtime/h1:sunmoonai/docs/dev-plan/rounds/runtime/task.md | \
  nl -ba | sed -n '352,362p'

git show 023bd75d:sunmoonai/docs/dev-plan/runtime-architecture.md | \
  nl -ba | sed -n '140,160p;183,190p;231,239p'

git show 6cefa580:sunmoonai/docs/dev-plan/rounds/runtime/runtime-disposition.md | \
  nl -ba | sed -n '85,94p;270,279p'
```

## 无其他异议

- C.2 的 §8-2：缺 `AUTH-FREEZE`、`AUTH-CANCEL` 未展开，判“部分”正确；
- C.2 的 §8-3：历史 H1 后漏写验证阶段的 `VALIDATING` 中间状态，更正正确；
- C.2 的 §8-8：合法边引用应由 `:205-209` 更正为 `:222-228`；
- C.2 的 OP-2：原文把 OP-2 已明确的新 Artifact 说成“任意 blob 直接塞行”，降为“细化”正确；
- G-1–G-7 对 luna 主张的吸收与原意一致。
