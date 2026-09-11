# ④ 异议 ｜ cursor ｜ `runtime-refact`

> 作者：cursor。身份由工作目录判定：`/home/zym/worktrees/cursor/k8s`。
> 本环节只就自己被处置到的条目发言。不评稿子整体（那是 ⑤ 的事）。

**裁定 R2**：本稿未读 `sunmoonai/docs/dev-plan/agent-dev-refact.md`，
未对其做打开 / `git show` / `grep` / `rg`。④ 不解除这一条。

取件（按 commit / 裁决方 worktree，不看本 worktree 的冲突文件）：

| 对象 | 取法 |
| --- | --- |
| 裁决稿 | `runtime-refact/arbiter` worktree（`/home/zym/worktrees/opus/k8s`，ref `runtime-refact/arbiter` = `9a57b0de`；`call-④.md` 记裁决稿 HEAD `6228ed18`，其后一提交只加本环节通知） |
| 处置记录 | 同分支 `disposition.md` |
| luna 对 cursor 的原指控 | `luna` 评审 `review-luna.md` C4（`d8fdb32a:agent-dev-guide.md` §5.1） |
| 我自己的冻结候选 | ① 提交 `d8fdb32a`（本评审 `review-cursor.md` B 表已冻结）；本 worktree 的 `agent-dev-guide.md` 现有未解决冲突，**正文不从该工作区取** |

---

## 独立复核（通知点名的三处）

### 1. 验收方计算：无异议

处置表逐条重数「接受 + 部分接受」：

| 家 | 接受 | 部分接受 | 不采纳 | 计入 |
| --- | --- | --- | --- | --- |
| cursor | C1–C8 = 8 | 0 | C9 = 1 | **8** |
| qwen | Q1–Q4 = 4 | 0 | 0 | **4** |
| kimi | K1, K2 = 2 | K3 = 1 | K4 = 1 | **3** |

协议 §13 依次排除裁决方 `opus`、基座 `luna`，余下最少者为 `kimi`。与处置记录「三」一致。
本条改判 A-3 **不会**改变这张计数表，故验收方人选不受本异议牵动。

### 2. 落点表：无异议（非我的主张处置）

按通知「其余 61 行未核」这一已知边界，抽查与我被吸收主张重叠的 3 行正文是否存在：

| 抽查 | 裁决稿位置 | 结果 |
| --- | --- | --- |
| C1「六个结构问题」 | §0.0 表 6 行 | 有 |
| C6「三件同时满足」 | §3.3 表后三段 | 有 |
| C5 H8 五步 | §4.3「`dev.change` 的 H8 具体这样接」 | 有 |

未抽其余 61 行。不把「没抽到」写成「落点表过了」。

### 3. A-3：有异议

见下条。

### 其余属于我的处置

| 条目 | 裁定 | 我的态度 |
| --- | --- | --- |
| C1–C8 | 接受 | 无异议。C2/C3/C4/C5/C6/C7 在裁决稿里都能对上对应段；C8 经 K2 落入 §7.4 第 4 行，主张已在，不要求单独再开一个提交 |
| C9 | 不采纳（A-1） | **无异议。**冻结候选 §4.1 形状示例确写了 `luna: model="gpt-5.6"`、`kimi: "kimi-k3"`、`fable: "claude-fable-5.1"`，且注「取值以 `agents.toml` 为准」；对该文件 `^\s*(model\|provider)\s*=` 命中 **0**（仅注释里出现这些词）。锚点不支持断言，J5 加重档成立 |

A-1b（「与 cursor 自己的 ⚠ 自相矛盾」不采信）不是我的主张，不单列异议。
事实更正一句：冻结候选 §4.1 末确有「⚠ 未验证：luna / kimi 的 argv 未钉 `--model`…推断不得进登记表取值」。
有这条 ⚠ **仍不挽救 C9**——表里还是填了具体值。故不要求改 C9。

---

## 异议 1

| 项 | 内容 |
| --- | --- |
| **条目** | `disposition.md` A-3（luna 指 cursor 违反 B4；裁决 **推翻**） |
| **为什么错** | 推翻所反驳的，不是 luna 实际写下的指控。luna 评审 C4 的原句是：冻结候选 `d8fdb32a:agent-dev-guide.md` **§5.1** 写「人的 Attempt 无 checkpoint 义务」，把人重新放回 Attempt；并另指 §5.2 H5「人执行该动作」。裁决方取证写的是「产物→状态机」表里 `publisher COMPLETED` 的注文「Side Effect 由人执行本地合并」，外加「没有任何条目把人标成执行者」。**那两处都不是 luna 点名的 §5.1。** 同一份处置记录的 A-2 给 kimi 定罪，用的正是「可跨会话续接」落成「人的 Attempt 无 checkpoint 义务」这一句。cursor 冻结候选 §5.1 差异表有**同一句**。对同一句话，kimi 成立、cursor 推翻，且推翻理由避开了那句话。 |
| **应当是什么** | A-3 针对 §5.1「人的 Attempt」应改为 **成立**，标准与 A-2 相同：Attempt 是执行者跑的东西，给人即违反 B4。luna 指控的另一半（§5.2 H5「人执行该动作」）与基座 L1「principal 只批准、publisher 执行动作」冲突，已被基座覆盖；若裁决方只想推翻这一半，必须把 A-3 **拆成两条**，不能用状态机表注文的辩护覆盖 §5.1。 **不要求改裁决稿结构**：基座是 luna，裁决稿全文「人的 Attempt」命中 0，该句本来就没被吸收。要改的是处置记录的裁定与理由。验收方计数不变。 |
| **可复跑证据** | 1. luna 原指控：`review-luna.md` C4，「`d8fdb32a:agent-dev-guide.md` §5.1 写“人的 Attempt 无 checkpoint 义务”」。2. 同一句话给 kimi 定罪：`disposition.md` A-2。3. cursor 冻结候选确有该句：`git show d8fdb32a:sunmoonai/docs/dev-plan/agent-dev-guide.md` 中 §5.1 差异表「可跨会话续接」行（本评审冻结表 commit `d8fdb32a`；kimi 同源句在其稿「可跨会话续接」行）。4. 裁决稿未吸收该句：对 `runtime-refact/arbiter` 上 `agent-dev-guide.md` 搜 `人的 Attempt`，命中 0。5. A-3 自己写的取证对象是「产物→状态机」表 / `publisher COMPLETED`，与 luna C4 点名的 §5.1 不是同一处。 |

---

## 覆盖声明

**查了**：`call-④.md`；处置记录全文；裁决稿中与 C1–C8、A-3、H8、未决 H5 拆分、落点表抽 3 行相关的正文；luna 评审 C4 原句；冻结候选 §4.1 登记表示例与 §5.1 差异表；`agents.toml` 是否含 `model=` / `provider=` 赋值；裁决稿是否含「人的 Attempt」。

**没查**：落点表其余 61 行逐行对正文；kimi / qwen 候选全文（只为 A-2/A-3 对照搜了「人的 Attempt」）；本会话 Shell 被拦，未能亲自 `git show d8fdb32a:...`，该 blob 的存在与 §5.1 引文以 ② 已冻结的 `review-cursor.md` B 表和 luna 评审对 `d8fdb32a` 的逐字引用为据。

**不能排除**：本 worktree 的 `agent-dev-guide.md` 处于未解决冲突，若有人只看工作区会看到冲突标记两侧。本稿断言一律绑 commit / 裁决方 worktree，不绑该工作区文件。
