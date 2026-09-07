# 环节通知 ④ 异议 ｜ `runtime-refact` 轮

> 组织者产物。**收到就开工，不需要额外指令。**
> 发给：luna / kimi / cursor / qwen（fable 于 ① 退赛，见 `rulings.md` `R3`）

## 第一件事：确认你是谁

```bash
r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "❌ 不在 git 仓内"
```

跑不出名字就停下问人。**产品名、模型名、界面一律不是身份证据。**

## ③ 已完成，取件方式

裁决方分支 `runtime-refact/arbiter`，本环节全部产物按 commit 取，**不看工作区**：

```bash
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/agent-dev-guide.md                          # 裁决稿
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/disposition.md        # 处置记录
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/mechanical-results.md # 机械条
git show runtime-refact/arbiter:sunmoonai/docs/dev-plan/rounds/runtime-refact/arbiter-selfcheck.md  # 裁决方自检
```

裁决稿 HEAD 为 `6228ed18`。基座 = **luna**；吸收 11 条，**一条主张一个提交**，
可用 `git log runtime-refact/arbiter --oneline` 与处置记录逐条对账。

## 你要交什么

落点：`sunmoonai/docs/dev-plan/rounds/runtime-refact/reviews/objection-<你的名字>.md`

**没有异议也要交**，写明「无异议」。**空回复无法与「还没看」区分**——
这是本环节唯一能让「没人反对」和「没人看过」分开的办法。

异议的形状固定四项，缺一项该条不予处置：

| 项 | 内容 |
| --- | --- |
| **条目** | 指向处置记录的哪一条（如 `A-3`、`C9`、验收方计算） |
| **为什么错** | 不是「我不同意」，是**它与什么事实冲突** |
| **应当是什么** | 给出你认为正确的处置 |
| **可复跑证据** | 一条命令或一处 `file:line`。**没有证据的异议按未提出计** |

## 本环节请重点看的三处

裁决方在自检里主动列了三个自知的薄弱点，**不是客套**：

1. **`disposition.md` 的 `A-3`：裁决方推翻了你们四家的一处共识。**
   luna 指 `cursor` 与 `kimi` 都违反 B4，裁决判**只有 kimi 违反**——
   `cursor` 那处在「产物→状态机」表里，Attempt 一格是 `publisher COMPLETED`，
   注文「Side Effect 由人执行本地合并」描述的是物理动作，且该稿明写
   「没有任何条目把人标成执行者」。**这是本轮唯一一处推翻，请独立复核而不是采信。**
2. **验收方计算**（`cursor` 8 / `qwen` 4 / `kimi` 3 → 验收方 `kimi`）。
   **条目归属若算错，验收方人选就错了。**
3. **落点表 64 行，裁决方只打开正文逐行核过 3 行。**其余 61 行未核，
   这是本轮覆盖的已知边界，已写进自检。

## 仍然生效的约束

- **不得读 `agent-dev-refact.md`**（裁定 `R2`）。④ 不解除这一条。
  在你的异议稿里声明是否遵守——**如实说「读了」不扣分，不如实说才扣**。
- 提交后不得再改。

## 两条本轮新裁定，取件前先读

- `R9`：任务书 §1.3「两份源稿将删除」的前提**已作废**，源稿保留。
  ⚠ 但**不因此放宽任何已冻结判据**，落点表要求照旧。
- `R10`：源稿**降为历史档案**，不再有规范效力；冲突时以裁决稿为准。
  **降级不等于作废**——历史档案仍可被引用为「当时的判断与取证」。

## 交完之后

```bash
python3 sunmoonai/docs/dev-plan/protocol/round-status.py --round runtime-refact
```

看到自己那格变 ✅ 即完成。**成功判据是产物出现，不是命令返回 0。**
