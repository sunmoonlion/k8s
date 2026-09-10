# 工单：`dev-plan-refact` 轮（第二次）

> 题目与验收标准：[`dev-plan-refact.md`](dev-plan-refact.md)　流程：[`../../protocol/round-protocol.md`](../../protocol/round-protocol.md)　裁定：[`rulings.md`](rulings.md)
>
> 下面 toml 块由 `round-status.py` 读取，**块里的字段才算数**；正文只是说明。

```toml
round_id   = "dev-plan-refact"
attempt    = 2                  # 第 1 次 09-07 开、09-08 作废（R1）
status     = "ACTIVE"
tier       = "T2"               # 触及内核 + 不可逆 + 260 节
round_dir  = "sunmoonai/docs/dev-plan/rounds/dev-plan-refact"
prefix     = "dev-plan-refact"

final_path = [                  # 两份都要交，缺一份即未交
  "sunmoonai/docs/dev-plan/pipeline.md",              # ①a 流程结构
  "sunmoonai/docs/dev-plan/dev-plan-architecture.md", # ①b 逐节安置
]
baseline   = "718c7f36"         # 重开后的主线

principal      = "owner"        # 所有者，见 agents.toml [owner]；本轮文书由 opus 代写（R2）
proposers      = ["opus", "luna", "kimi", "cursor", "qwen"]
arbiter        = "cursor"       # R6：所有者把裁决权全权委托给 cursor
arbiter_branch = "dev-plan-refact/cursor"
arbiter_is_proposer = true      # 裁决方同时是参赛方，R6 知情裁定，见正文「角色」
integrator     = "cursor"       # R4
base_author    = "luna"         # R5
acceptor       = "qwen"         # 按 §13 从处置表算出，组织者复算一致

anchor_roots   = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "~/master/investment-app", "."]
frozen_sections = []
mechanical_absent = [
  'B1 不得在本轮改结论::本轮改正|顺带修正|此处结论有误故改',
  'B7 request-baseline 路径不得变更::request-baseline 移|移入 archive/request-baseline|request-baseline/ →',
  'B13 必须交 ①a::（不用正则判：final_path 取 all()，缺 pipeline.md 即未交）',
]
```

## 角色

`cursor` 同时是参赛方、裁决方、整合方。这是所有者知情后的裁定（R6），不是疏漏。补偿有两条：

1. `cursor` 处置自己提的条目时，必须标「（自处置）」；
2. 验收方必须排除 `cursor`。

也因此，③ 之后的通知由所有者一侧写，不由 `cursor` 写（`findings.md` F-21）。
每个环节的组织者由 `round-status.py` 按上面字段算出并打印，不用人记。

## 第一次为什么作废

任务书把所有者已经拍板的框架降成了待议题，还给正确答案设了扣分。
结果两份已交候选只讲「文档怎么分类」，没讲「一条需求怎么走完」。
两份旧候选作废，不作参考。详见 `rulings.md` R1。

## 与 `pipeline` 轮的关系

`pipeline` 轮（2026-09-04 立，四家产出从未出现）不再单独复活。所有者 2026-09-08 明确：那道题就是本轮 ①a。
材料并入 `inputs/`，`docs/ai-dev-readiness/` 目录取消。
