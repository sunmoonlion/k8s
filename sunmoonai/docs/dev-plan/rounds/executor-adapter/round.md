# 工单：`executor-adapter` 轮

> 题目与验收标准见 [`task.md`](task.md)。流程见 [`../../protocol/round-protocol.md`](../../protocol/round-protocol.md)。

```toml
round_id   = "executor-adapter"
status     = "DRAFT"                 # 协议规定同时只允许一个 ACTIVE 轮次；等 runtime-refact 走完 ⑦
tier       = "T2"                    # 权威层（要动 agent-dev-refact 的架构主张）+ 判据未定
final_path = "sunmoonai/docs/dev-plan/executor-adapter.md"
round_dir  = "sunmoonai/docs/dev-plan/rounds/executor-adapter"
prefix     = "executor-adapter"
baseline   = ""                      # 开轮时填
proposers  = []                      # ⚠ 无默认，必须显式填；开轮前由所有者定
arbiter        = ""                  # ⚠ 同上
arbiter_branch = ""
acceptor       = ""                  # ③ 之后由处置表算出
anchor_roots      = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "~/master/investment-app", "."]
frozen_sections   = []
mechanical_absent = [
  'B2 不得新增内核状态词::新增状态|新的状态词|扩展状态机',
  'B1 不得自建被调 agent::自建 agent|自己实现 agent|fork 一个 agent',
]
```

## 为什么现在只能是 DRAFT

`round-protocol.md`「本轮定义」规定**同时只允许一个 `status = ACTIVE` 的轮次**，
现在 ACTIVE 的是 `runtime-refact`。本轮排在它之后。

先起工单不是抢跑，是**趁证据还热把它固定住**：今晚三种失败的原始输出、
两次被参数名误导的过程、以及那个「投喂模式下运行时不持有循环」的疑点，
再过几天就只剩结论、没有现场了。

## 与 `runtime-refact` 的关系

`runtime-refact` 产出的是**面向今后开发的指导文档**；本轮要判定的，
是那份文档里「开发与产品只差 Profile」这一主张在**执行者接入方式**这一处成不成立。

⚠ **两轮的先后不代表结论的先后**：若本轮判「结构」，
`runtime-refact` 的定稿要按 `agent-dev-refact.md` §6「要改内核时，工作单元长什么样」
的规矩起修订单元，**不是回头改已发布的稿子**。
