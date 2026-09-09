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

baseline   = "718c7f36"          # 重开后的 master。⚠ 记录性提交晚一拍；判据以各家工作区 HEAD 为准

# 所有者 2026-09-07：「鉴于本轮重要，你们都参加，我是裁决者。到时我指定谁吸收。」
proposers      = ["opus", "luna", "kimi", "cursor", "qwen"]   # 五家全参赛，含 opus
arbiter        = "cursor"            # ⚠ 2026-09-08 由 owner 全权委托，见 rulings.md R6
arbiter_branch = "dev-plan-refact/cursor"   # ③ 产物落在整合方自己的分支上
# ⚠ 本轮 arbiter == integrator == cursor，且 cursor 自己是 ①② 参与方。
#   这是所有者知情后的裁定（R6），不是疏漏。代偿控制有两条，缺一不可：
#     1. cursor 对自己条目的处置必须打「（自处置）」标记（call-③.md §四）
#     2. acceptor 必须排除 cursor（§13 规则 1、2 在本轮同时指向它）
integrator     = "cursor"            # 所有者 2026-09-08 指定，见 rulings.md R4
                                     # ⚠ 条件：cursor 现推荐基座为 luna。若 ③ 选中 cursor
                                     #    自己的稿作基座，则整合方＝基座作者，须重议本项
acceptor       = "qwen"              # ③ 处置表算出（disposition.md §三），组织者已独立复跑复核一致
                                     # 排除 cursor（裁决/整合）、luna（基座作者）；
                                     # 余下 opus 6 / kimi 8 / qwen 4 → 最少 → qwen。无并列
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
