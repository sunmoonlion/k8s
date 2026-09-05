# 终审：refact-fable.md（12:15 最后稿）

> 日期：2026-09-05 ｜ 评审者：cursor（Grok 4.6）｜ 对象：`refact-fable.md` 12:15 修订（§8 未冻结）
> 性质：终审。上一轮 `review-refact-fable-cursor.md` 的 C1–C3 / D1–D5 / T1–T3 逐条核对吸收情况；
> 只写最后稿里还站得住的问题。引用关系：本稿建立在自己上一轮上，重叠条目按 3.2 视同 `same-runtime`。

**总体判断：骨架可以冻。**上一轮阻断级三点（全表回执仓、T0 改任务类包、引导轮独立成 `bootstrap`）
与映射表补边、删 Profile C、P0 范围限定，都按裁定写进了正文，不是口头吸收。
剩下的不再是结构自相矛盾，是**三处时间点 / 命名没对齐**——按现在的字面实现，S1/R1 会先卡死或把 `paths` 检查做成空转。
这三处建议在冻结 §8 前改字，不必再开一轮结构讨论。

---

## 上一轮处置核对（关闭，不重开）

| 上轮 | 最后稿落点 | 结论 |
| --- | --- | --- |
| C1 全表回执仓、删 H2「或 rulings.md」 | §3.3 统一规则 + H3/H4/H6 = `ruling/<id>/<n>`；H7 例外保留 | 关闭 |
| C2 T0 改命名任务类包 | §3.6 `paths` + `gates` + `covers`；禁止自拼子集 | 关闭（示例过宽见 F3） |
| C3 R0/S1 不适用新 T0 | §6 `bootstrap` 档；效力来自本文冻结 | 关闭 |
| D1 `WAITING → SUCCEEDED` 非法边 | 3.1.1 改为 `WAITING → QUEUED` 再 `RUNNING → SUCCEEDED`；§8 第 4 条加边 ⊆ 合法转换 | 关闭 |
| D2 `RECEIVED` / `BUDGET_EXCEEDED` 缺行 | 3.1.1 各占一行；§8 第 4 条改对称差 | 关闭 |
| D3 删 Profile C | §0 / §3.1：协议演化 = 开发 Profile 钉 T2 | 关闭 |
| D4 P0 只管词表与边 | §0 第 1 句已写「不宣称 git 具备并发语义」 | 关闭 |
| D5 T0 仍有 H5、观察值加签名次数 | §3.6 / §3.4 / §7.9 / §7.13 | 关闭 |
| T1 四词 vs 五词 | §0 已改五词；§5.2 仍写「3.9 四词」，见 F4 | 部分关闭 |
| T2 引用钉 protocol-v2 | 文首「引用钉定」段 | 关闭 |
| T3 集合比较改对称 | §8 第 4 条 | 关闭 |

不采纳「恢复人路径自足」、不把签名回执降为可选——维持同意。

---

## 冻结前必改

### F1：T0 的 `paths` / `gates` 被写成了开工门，但开工时还没有 diff

**为什么错**：三处把「diff ⊆ 包 `paths`」绑在分发 / H1 上：

- H1 `enforcement_point`：「T0 校验包名存在且 **diff ⊆ 包 `paths`**」
- H2 `enforcement_point`：「`round-dispatch.py` 在回执仓 tag 出现前**不分发**」（未给 T0 + `decide` 开口）
- §8 第 5 条：「diff 触及文件 ⊆ 包 `paths`……违反前提的工单脚本**拒绝分发**」

T0 开工前零触点成立的条件是：策略已签、包名合法、`RouteDecision` 落账。此时工作还没做，**没有 diff**。
空 diff ⊆ 任何 `paths` 恒真——按字面实现，这条检查在分发时空转，真正越权的 diff 要到完工才出现。
反过来，若实现者坚持「没 diff 就不分发」，T0 永远开不了工。

H2 的强制点与 `auto_policy` 也打架：T0 + `decide` 按设计不产生 tag，但「tag 出现前不分发」会把 T0 卡死，
§8 第 5 条「T0 为零次」随之不成立。

**应当是什么**：拆成两道门，写进 H1/H2 强制点和 §8 第 5 条：

| 何时 | 查什么 | 失败则 |
| --- | --- | --- |
| **开工**（H2 / 分发） | 包名 ∈ 已签策略；T0 + `decide` 有 `RouteDecision`；T1/T2 有回执仓 tag | 拒发 |
| **完工**（L0 / L1 / H5） | 实际 diff ⊆ 包 `paths`；`gates` 全过；H5 内容门 | 不进 H5 / 不判确认 |

H1 对 T0 只查「acceptance 是一个已签包名」（策略 tag 已承担冻结），不要查 diff。

**证据**：`refact-fable.md` §3.3 H1/H2 强制列；§3.6「T0 的承诺只是开工前零触点」；§8 第 5 条「拒绝分发」。

### F2：回执仓的 tag 名字空间没跟上全表锚定

**为什么错**：12:15 把 H3/H4/H6 锚到 `ruling/<id>/<n>`，S1 也要签一条 `ruling/_probe/1`。
但 3.13 是 R1 前置、S1 之前必须冻结的那一节，三处还停在旧名单：

- §3.13.2 A 档：「只存 `confirm/*`、`frozen/*`、`policy/*`」——没有 `ruling/*`
- §3.11 权威事件：「`frozen/*`、`confirm/*`」——同样漏
- §3.13.4 示意图：「`round-status.py` 判 H1/H5」「`ls-remote … confirm/<id>`」

另外两个命名未定义，R1 脚本会对不上：

1. **T2 单独的 H2**（与 H1 分开签）叫什么？现在只写了 T1 的 `H1+H2` 共用 `frozen/<id>`。
2. **组合 tag**（§3.3「一条 tag 携带多个 transition」，如 `H2+H3`）落在哪个前缀？
   查 `ruling/<id>/<n>` 的脚本看不见 `frozen/<id>` 里带着的 H3，会把已签裁定判成不存在。

**应当是什么**：3.13.2 的允许前缀改成四条：`confirm/*`、`frozen/*`、`policy/*`、`ruling/*`。
补一张名字表，冻结进 3.13（S1 按这张表打 probe）：

| 行 | tag 名 | 组合时 |
| --- | --- | --- |
| H1 / T1 的 H1+H2 | `frozen/<id>` | 主名跟「集合里字典序最后的前缀」；**每个被携带的 transition 另打一条同对象的轻量 ref**（同一 tag 对象、多个名字），保证按行查找不漏 |
| T2 的 H2 | `start/<id>` 或并入 `frozen/<id>`（二选一，冻结时定） | 同上 |
| H3 / H4 / H6 | `ruling/<id>/<n>` | 同上 |
| H5 | `confirm/<id>` | `H5+H3`（waive）必须能被 H3 查找见到 |

S1 的「两条测试 tag」改成覆盖 `confirm/*` 与 `ruling/*` 各一条，与上表一致（正文 S1 行已有 `ruling/_probe/1`，3.13.2 要跟上）。

**证据**：`refact-fable.md` §3.3 H3 回执列；§3.13.2 A 档「只存」三前缀；§3.3「压缩次数的正道是一条 tag 多个 transition」；§6 S1 行。

---

## R1 起草策略时必守（可随本文改一句，或进 `policy/1` 验收）

### F3：示例包 `doc-typo` 的 `paths` 宽于 `covers`，权威层会被卷进 T0

**为什么错**：§3.6 把 `covers` 定为「人读、不做字面匹配」，机械门只剩 `paths` + `gates`。这是对的。
但示例：

```toml
paths  = ["sunmoonai/docs/**/*.md"]
covers = "仅改文档笔误与链接，不改约束、协议、脚本行为"
```

`sunmoonai/docs/**/*.md` 含 `constraints.md`、`round-protocol.md`、`working/request-lifecycle.md`、
`lifecycle.md`（将来）、本方案自己。这些改动命中 T2 判据「权威层 / 不可逆」。
agent 引用 `doc-typo` → H2 自动放行 → `doc-gate.py` 绿 → H5 对两条门禁写 `pass`。
`covers` 挡不住，因为它不是判据。C2 从「自拼门禁」缩成了「自选一个过宽的包」。

**应当是什么**：3.6 加一条包纪律（进 L0，改策略按 T2）：

**`paths` 必须窄到不需要靠 `covers` 挡权威层。** 权威层路径（`constraints.md`、`round-protocol.md`、
`request-lifecycle.md`、`authority.md`、`policies/**`、本协议自身）不得出现在任何 T0 包的 `paths` 里。
示例改为 `sunmoonai/docs/ai-dev-readiness/**/*.md` 或更窄的白名单，不要 `docs/**`。

R1 验收已有「diff 越出 paths 被拒」，再加一条：伪造 T0 工单改 `constraints.md`、引用 `doc-typo`，脚本拒绝。

**证据**：`refact-fable.md` §3.6 示例与「不做 covers 字面匹配」；`protocol-v2` 档位判据「权威层」；§8 第 5 条只查包名与 paths，不查 covers。

---

## 文字（随冻结一并改，不挡结构）

### F4：四处还停在「只锚 H1/H5」或「四词」

| 位置 | 现在 | 应对 |
| --- | --- | --- |
| §3.4 收件箱 | 只给 H1/H5 加 `target_commit` / `diff_stat` | H3/H4/H6 同样必备（target = 新增裁定行的 commit） |
| §3.13.3 `waived` | 「同时要求 `rulings.md` 有对应行」 | 按统一规则：对应行 + `ruling/<id>/<n>` tag（或 H5 组合 tag 能被 H3 查到） |
| §3.13.1 / 3.13.4 | 「不得作为 H1/H5 的判据」「判 H1/H5」 | 改为所有 `auto_policy = 无` 的行（H7 除外） |
| §5.2 粗映射 | 「由 3.9 **四词**与 3.10 对照表替代」 | 五词 |

---

## 已知残留（不挡冻结，登记即可）

1. **中途 H3/H4/H6 与内核「有一路可推进则 Task 保持 RUNNING」**（`request-lifecycle.md` WAITING 节）。
   3.1.1 把中途等人写成 Task `WAITING(APPROVAL)`，等于暂停所有 Attempt。若这是有意的，加半句：
   「命中权力表的中途 H 视为全 Task 暂停，在跑 Attempt 进 `WAITING`」。否则应按内核把 Interaction 挂在 Attempt 上。
2. **§7.12**：R0 补「机器可读块」算不算改协议，仍待所有者裁定。冻结 §8 时一起给一句话即可，不改骨架。
3. **§7.13 可逆出口**：同意本轮不加。弊端写清楚了（worktree 堆积后一次批量 push = 绕过 H5）。

---

## 冻结建议

| 项 | 建议 |
| --- | --- |
| §8 第 1、2、3、4、6、7、8 条 | 可以按原文冻 |
| §8 第 5 条 | **先按 F1 改再冻**，否则「拒绝分发」会按空 diff 实现 |
| 3.13（S1 / R1 前置） | **先按 F2 补 `ruling/*` 与名字表再冻** |
| 3.6 任务类包 | 加 F3 一句 `paths` 纪律；示例收窄 |
| 其余 | F4 四处随改；F5 进 §7 即可 |

改完 F1/F2/F3 字面之后，本文作为提案可以进 §8 冻结，开 `bootstrap`（R0 / S1）。
不再建议为结构问题加轮次。
