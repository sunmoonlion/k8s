# 工单：`dev-plan-refact` 轮

> 题目与验收标准见 [`dev-plan-refact.md`](dev-plan-refact.md)。
> 流程见 [`../../protocol/round-protocol.md`](../../protocol/round-protocol.md)。

```toml
round_id   = "dev-plan-refact"
status     = "DRAFT"                 # 开轮前须裁定 proposers / arbiter
tier       = "T2"                    # 权威层（触及内核）+ 不可逆（文档重排）+ 规模 399 节
final_path = "sunmoonai/docs/dev-plan/dev-plan-architecture.md"
round_dir  = "sunmoonai/docs/dev-plan/rounds/dev-plan-refact"
prefix     = "dev-plan-refact"
baseline   = ""                      # 开轮时填
proposers  = []                      # ⚠ 无默认，必须显式填
arbiter        = ""                  # ⚠ 同上
arbiter_branch = ""
acceptor       = ""                  # ③ 之后由处置表算出
anchor_roots      = ["~/repo/codex", "~/repo/deepseek-harness", "~/repo/openclaw", "~/master/investment-app", "."]
frozen_sections   = []
mechanical_absent = [
  'B1 不得在本轮改结论::本轮改正|顺带修正|此处结论有误故改',
  'B7 request-baseline 路径不得变更::request-baseline 移|移入 archive/request-baseline|request-baseline/ →',
]
# B8「三份未落点历史稿并入后删除」是**存在性**要求，机械条查不出「缺了什么」，
# 只能由 M1 落点表覆盖 399 节这一条兜住。见 dev-plan-refact.md §2 一、§4.1 B8。
```

## 与 `executor-adapter` 轮的排队关系 —— **已定**

**所有者 2026-09-07 裁定：先 `dev-plan-refact`，`executor-adapter` 押后。**
理由（所有者原话）：**「executor-adapter 现在做不了啊，它应该不会改结论」**。

⚠ **这一条推翻了起草者的建议，如实记录。** 起草者原写：

> ⚠ 起草者倾向先 `executor-adapter`：它可能改结论，而本轮明写「不改结论」——
> 先做会改结论的那一轮，再做整理，顺序上更省一次返工。

所有者不同意的是其中的**事实前提**，不只是权衡：起草者说「它可能改结论」，
所有者判「它应该不会改结论」。二者是可证伪的分歧，处理如下：

| | 内容 |
| --- | --- |
| 本轮按哪个走 | **按所有者的判定**：`executor-adapter` 不改结论，故本轮重构不必等它 |
| 前提若被推翻会怎样 | 若 `executor-adapter` 日后确实改了 `agent-dev-guide` 的架构主张，本轮产物需按新结论做一次**定向修订**，不是重做——因为本轮只动组织方式（B1） |
| 风险落在哪 | 落在**架构对「投喂 / SDK 差异」这一类内容的容纳能力**上。故新架构须能安置一份「执行器适配」类文档，即使现在还没有 |

另有「现在做不了」的事实原因：`executor-adapter` 需要 SDK 侧的实测取证，
而今晚的测试已证明 CLI 投喂路径答不了审批请求，SDK 路径尚未搭起来。
**取不到证据的轮次不能开**——这与协议 §8「验收判据先于产出冻结」同源。

## 本轮的特殊之处

`runtime-refact` 轮是 64 节，本轮 **399 节**。规模差 6.2 倍，而
「靠一次通读做融合会丢东西，且丢了不会有人发现」这条已经被上一轮证实过一次。
**落点表因此是交付物而非附赠，且验收会抽查落点是否属实。**
