# 工单：`dev-plan-refact` 轮

> 题目与验收标准见 [`dev-plan-refact.md`](dev-plan-refact.md)。
> 流程见 [`../../protocol/round-protocol.md`](../../protocol/round-protocol.md)。

```toml
round_id   = "dev-plan-refact"
status     = "DRAFT"                 # 开轮前须裁定 proposers / arbiter
tier       = "T2"                    # 权威层（触及内核）+ 不可逆（文档重排）+ 规模 365 节
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
  'B5 archive 内容不得引用::archive/development-lifecycle|archive/refact-fable|archive/runtime-architecture',
]
```

## 与 `executor-adapter` 轮的排队关系

两轮都是 DRAFT，协议只允许一个 ACTIVE。**先后由所有者定**，起草者的看法：

| | 先做的理由 | 后做的代价 |
| --- | --- | --- |
| `executor-adapter` | 证据最热（今晚刚测）；且它决定「投喂 vs SDK 是字段还是结构」，**会改动 `agent-dev-guide` 的架构主张** | 若后做，本轮重构完的文档可能又要因它而改 |
| `dev-plan-refact` | 文档越拖越乱；且它是**组织方式**，不改结论 | 若后做，`executor-adapter` 的产物又多一份无处安放的文档 |

⚠ **起草者倾向先 `executor-adapter`**：它可能改结论，而本轮明写「不改结论」——
**先做会改结论的那一轮，再做整理，顺序上更省一次返工**。但这是所有者的权力。

## 本轮的特殊之处

`runtime-refact` 轮是 64 节，本轮 **365 节**。规模差 5.7 倍，而
「靠一次通读做融合会丢东西，且丢了不会有人发现」这条已经被上一轮证实过一次。
**落点表因此是交付物而非附赠，且验收会抽查落点是否属实。**
