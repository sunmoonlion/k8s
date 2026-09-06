# 环节通知 ② 互评 ｜ `runtime-refact` 轮

> 组织者产物。**收到就开工，不需要额外指令。**
> 发给：luna / kimi / cursor / qwen（fable 已于 ① 退赛，见 `rulings.md` `R3`）

## 第一件事：确认你是谁

```bash
r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "❌ 不在 git 仓内"
```

命令跑不出名字就停下问人。**产品名、模型名、界面一律不是身份证据。**

## ① 已完成：四份候选，按 commit 冻结

**隔离到此解除**——现在你可以、也必须读其余三份。取件一律按 commit，**不看工作区**。

| 家 | 行 | 字节 | commit | sha256[:16] | 取件命令 |
| --- | --- | --- | --- | --- | --- |
| `luna` | 648 | 43921 | `39889605` | `cc47d068c39c9bcd` | `git show runtime-refact/luna:sunmoonai/docs/dev-plan/agent-dev-guide.md` |
| `kimi` | 917 | 71858 | `dc8efd59` | `913ccb082320b8e6` | `git show runtime-refact/kimi:sunmoonai/docs/dev-plan/agent-dev-guide.md` |
| `cursor` | 921 | 70095 | `d8fdb32a` | `926a974e02df238f` | `git show runtime-refact/cursor:sunmoonai/docs/dev-plan/agent-dev-guide.md` |
| `qwen` | 187 | 22316 | `7d31265a` | `e783ce080489c837` | `git show runtime-refact/qwen:sunmoonai/docs/dev-plan/agent-dev-guide.md` |

⚠ **四家建分支的方式一度不一致**：① 期间 luna / cursor 先建了 `runtime-refact/<家>`，
kimi / qwen 先提交在裸的 `<家>` 上、随后才补建轮次分支。现在四条轮次分支都在，
上表统一按 `runtime-refact/<家>` 给。**按上表的命令取，别自己拼 ref。**

**先验哈希再评**：取到手先跑 `| sha256sum`，与上表对不上就停下问人。

## 你要交什么

落点：`sunmoonai/docs/dev-plan/rounds/runtime-refact/reviews/review-<你的名字>.md`

四块，**缺一块该评审不计入裁决**（`round-protocol.md` §10）：

| 块 | 内容 |
| --- | --- |
| **A 自述** | 你自己那份：写了哪些节、哪些断言未验证并标 ⚠、与其他家的分歧；以及**你放弃了哪些本可以写但故意没写的内容，为什么**——这项能看出取舍是不是想过 |
| **B 候选集冻结** | 上表四份逐一列出路径、行数、字节数、SHA-256、commit。**少一份，你的评分作废** |
| **C 评优** | 按任务书 §8 的判据**逐条**给比较依据，对**全部四份（含你自己那份）**指出强项与缺陷，给出完整排序与「该选谁当基座」的理由 |
| **D 值得吸收的点** | 不管你选谁当基座，逐条列出**其他候选里值得并进最终稿的具体主张**：出自谁、在哪一节、为什么值得 |

**D 块是裁决阶段最有用的输入**，别敷衍。裁决方靠它避免只看整体印象、漏掉落选稿里的好东西。

## 本轮 ② 的三条特别提醒

1. **利益冲突必须声明。**你既是作者又是评优方，这不是独立终审。
   把自己排第一是允许的，但必须给出**与评别家同样标准**的比较依据。
2. **事实题用证据裁，不用票数裁。**多家说法一致但都没取证，输给一家带 `file:line` 的。
3. **重点核 D2 落点表是否属实。**任务书要求两份源稿的 **64 节**（`refact-fable.md` 31 节
   + `runtime-architecture.md` 33 节）逐节有落点。评优时**抽查几条声称的落点，
   看该节是不是真有对应内容**——声称落点而无内容，比不写落点表更严重，那是伪取证（判据 J2）。

⚠ 篇幅差异很大（187 行到 921 行）。**篇幅本身不是判据**（任务书 §10 Q5：不设上下限、
不按行数给分），判的是「该覆盖的有没有覆盖」与「同一条信息有没有被说三遍」。
**不要因为短就判它差，也不要因为长就判它全**——两个方向都要拿判据去核。

## 仍然生效的约束

- **不得读 `sunmoonai/docs/dev-plan/agent-dev-refact.md`**（裁定 `R2`）。
  ② 解除的是候选之间的隔离，**不解除这一条**。在你的评审里声明是否遵守。
- 评审写完即提交，**提交后不得再改**。

## 交完之后

```bash
python3 sunmoonai/docs/dev-plan/protocol/round-status.py --round runtime-refact
```

看到自己那一格变 ✅ 即完成。**成功判据是产物出现，不是命令返回 0。**
