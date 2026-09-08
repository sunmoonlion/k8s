# 工单：`dev-plan-refact` 轮（第二版）

> 题目与验收标准见 [`dev-plan-refact.md`](dev-plan-refact.md)。
> 流程见 [`../../protocol/round-protocol.md`](../../protocol/round-protocol.md)。
> ⚠ **第一次尝试已作废**，理由见 [`rulings.md`](rulings.md) R1。

```toml
round_id   = "dev-plan-refact"
attempt    = 2                       # ⚠ 第 1 次 2026-09-07 开、2026-09-08 作废（rulings R1）
status     = "ACTIVE"                # 2026-09-08 重开
tier       = "T2"                    # 权威层（触及内核）+ 不可逆（文档重排）+ 260 节
round_dir  = "sunmoonai/docs/dev-plan/rounds/dev-plan-refact"
prefix     = "dev-plan-refact"

# ⚠ 本轮**两个**最终路径——第一版只有一个，那正是 ①a 被写没了的形状。
# round-status.final_path_list() 允许 str 或 list；① 的判定对列表取 all()，
# 所以「只交了 ①b」会被判为未交，而不是像第一版那样通过。
final_path = [
  "sunmoonai/docs/dev-plan/pipeline.md",              # ①a 流程结构
  "sunmoonai/docs/dev-plan/dev-plan-architecture.md", # ①b 逐节安置
]

baseline   = "d121739e"             # 重开时的 master

# 所有者 2026-09-07：「鉴于本轮重要，你们都参加，我是裁决者。到时我指定谁吸收。」
proposers      = ["opus", "luna", "kimi", "cursor", "qwen"]   # 五家全参赛，含 opus
arbiter        = "owner"             # ⚠ 由 principal 担任裁决方
arbiter_branch = ""                  # 所有者不开分支；③ 的产物由 integrator 落盘
integrator     = ""                  # ③ 之后由所有者指定
acceptor       = ""                  # ③ 之后由处置表算出，⚠ 排除 integrator 而非 arbiter
anchor_roots   = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "~/master/investment-app", "."]
frozen_sections = []
mechanical_absent = [
  'B1 不得在本轮改结论::本轮改正|顺带修正|此处结论有误故改',
  'B7 request-baseline 路径不得变更::request-baseline 移|移入 archive/request-baseline|request-baseline/ →',
  'B13 必须交 ①a::（不用正则判：final_path 取 all()，缺 pipeline.md 即未交）',
]
```

## 第一次尝试为什么作废

一句话：**任务书把所有者已经拍板的框架降级成了待议题，还给正确答案设了罚分。**

于是两份已交候选（opus 737 行、luna 7968 行）都只有「文档怎么分类与安置」，
没有「一条需求怎么走完」。完整事实、判断与十项处置见 [`rulings.md`](rulings.md) R1。

**两份旧候选作废，不作参考**——理由是它们的分类结论在「套 PRD/TLD 要扣分」的约束下
得出，留作参考会让作者从分类倒推流程，次序又颠倒回去。
枚举 260 节那份苦工改由机器做一次（[`inventory.md`](inventory.md)），五家共用，废稿不造成重复劳动。

## 本轮与 `pipeline` 轮的关系

`pipeline` 轮（2026-09-04 立，判据密封于 `e7e37486`，**四家产出从未出现**）
不复活为独立轮次。所有者 2026-09-08 明确：**那道题就是本轮 ①a**。
材料整体并入 [`inputs/`](inputs/README.md)，`docs/ai-dev-readiness/` 目录取消。

## ⚠ 本轮的两处角色特例

1. **裁决方是所有者本人**（首次），不是某一家 agent；
2. **任务书由 opus 代写，而 opus 同为参赛方**，且 `inputs/` 五份参考也全由 opus 起草。
   双重利益冲突，约束见 [`inputs/README.md`](inputs/README.md) 四条与 [`rulings.md`](rulings.md) R2。

判据即命令，结论只依赖 git 提交；工作区文件不参与判定。
