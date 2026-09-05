参与方：fable｜worktree：/home/zym/worktrees/fable/k8s｜HEAD：f513cf33

# 轮次 runtime ② 互评（fable）

> 身份：`r=$(git rev-parse --show-toplevel 2>/dev/null) && basename "$(dirname "$r")" || echo "不在仓内"` → `fable`。
> 产品名 / 模型名 / 界面不是身份证据（`R5`）。
>
> **利益冲突**：我是本轮候选作者，也是被本轮前提推翻的 `refact-fable.md` 起草者。把自己排第一是允许的，
> 下面用与评别家同一套可复核依据；基座建议若只看「推翻 OP 的力度」会落到 cursor，见 C 节。

---

## A. 自述

**改了基座哪些节 / 新增哪些节**：无基座，新建。候选 `f053bd84` 覆盖 P1 `dev.change` + 五家 Agent Profile、
P2 内核修订单元、P3 四档粒度、必答 Q、OP 表态。

**未验证、标了 ⚠ 的**：登记表里 luna/kimi 实际模型、cursor/qwen 的 stream-json 是否含工具事件、
fable GUI 模型（不可机械核验）、Attempt 产出 typed Artifact 是否算内核扩充。

**与基座的分歧**：无基座。与上一轮终稿的分歧写在候选第 1 节：A/B 分层用错了 Profile 这个词。

**故意没写**：文件树、R0–R5 重排、`protocol-v2` 五条待决、财务 Task Profile 的具体契约。

**本环节多出来的一条观测**（所有者投喂里点名的 `--ff-only` 失败）：分支已分叉时拒绝快进、明说原因，
而不是悄悄 merge。这与本轮 `R4`/`R5`、协议「判据自身的质量」是同一条纪律——
`all({})` 报完成、判别命令吐点、消歧句当证据，三次都是「给个假答案让下游接着推」。
响亮失败的代价是多跑一步，收益是没有一次静默的错误合并。评各家 Q4 时我把「允许结论为 UNKNOWN /
不得把没查到写成零绕过」算优点，依据就是这条。

---

## B. 候选集冻结

对象路径一律 `sunmoonai/docs/dev-plan/runtime-architecture.md`。
核对命令：`git show <commit>:<路径> | sha256sum | cut -c1-16`（与 ② 通知一致，五份全对）。

| 家 | worktree | 分支 | commit | 行 | 字节 | sha256[:16] | 身份行 `<名>` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| luna | `/home/zym/worktrees/luna/k8s` | `luna` | `1ddff5c2` | 544 | 32955 | `03785aabb3a631f6` | luna |
| kimi | `/home/zym/worktrees/kimi/k8s` | `kimi` | `29b4f804` | 538 | 39376 | `f0226bffd7517085` | kimi |
| cursor | `/home/zym/worktrees/cursor/k8s` | `cursor` | `13f3d52b` | 586 | 38613 | `5ba7ce8b14775aeb` | cursor |
| fable | `/home/zym/worktrees/fable/k8s` | `fable` | `f053bd84` | 646 | 59897 | `b9bd7800cdcbcb05` | fable |
| qwen | `/home/zym/worktrees/qwen/k8s` | `qwen` | `1ae5b420` | 441 | 21202 | `49380ab0427d8ad8` | qwen |

五份相对 `7e8464c2`，`refact-fable.md` 与 `working/request-lifecycle.md` 的 diff 字节数均为 0。
禁用词组与 `kind = "human"` 五份 `rg` 均为零命中。

---

## C. 评优

### C.0 独立性：cursor 与 fable 不是同一份论证换封面

`task.md` §6.2.1 要的观察值。两份都被迫回答同一张题，结构同形（P1/P2/P3/Q/OP）不算雷同。
实质差异：

| | cursor `13f3d52b` | fable `f053bd84` |
| --- | --- | --- |
| Task Profile id | `DEV_ROUND` | `dev.change` |
| fable 粒度词 | `session` | `fs-only`，且多一档 `tool.reported` |
| 权力表 | `P-*`；明文「粘贴投喂不是权力」 | `H0`–`H8`；把欠账收进表以便可数 |
| OP-1 | S 层 / R 层 + 投影 Π | 四要素加 `provenance` 与 `power_row` |
| OP-2 | 四值 `replace`，渲染出内核 | 三值 + `options[]` + `evidence_grade`，渲染留在绑定 |
| 轨迹 | 自标重建，证明 S 层装得下 | 23 行带来源等级，2 条 attested |
| Q2 | 一例：已签包内笔误 | 三例，第三例是 `dispatch = manual` 本身 |

不是 find-replace。按分组键它们仍是两组；本轮这两份稿的差异支持「不要只按厂商合并」。

### C.1 排序与基座

**排序：fable > cursor > luna > kimi > qwen。**

基座选 **fable `f053bd84`**。不是因为自评手松，是三条可复核差异：

1. **§8-3 样例是「真实产物」而不是示意。** 五家都声明用了 `refact-fable` / `7e8464c2`。
   qwen 列出 `candidate-luna@v1` 五份——那一轮没有这五份候选文件（`7e8464c2` 的 `rounds/refact-fable/reviews/`
   只有 kimi/qoder/cursor 三份首轮评审 + 五份终审，主稿一份）。
   kimi / cursor 是重建投影（他们自己标了）。luna 带 GAP 且复核了评审 hash
   （`review-refact-fable-kimi.md` → `77a286adac5131d9`，与 `git show 7e8464c2:… | sha256sum` 一致）。
   fable 把 23 行逐条标了 `attested / reported / inferred`，并写明只能在 `reported` 上宣称等效。
   这正是 cursor 反对「把 OP-1 当本轮核心机械验收」的理由——fable 的样例把这个理由做成了数字。
2. **P3 对 fable 这条腿填对了档。** qwen 登记表写 `observability_granularity = process`（`:87`），
   同文 §3.5 又说看不到 argv/stdio。四家都把 fable 单列更粗的一档；qwen 机械有值、事实填错。
3. **§8-2 有历史介入表，不只是权力类型表。** cursor 的 H3/H4 写「不改边」（`:368-369`），
   与「每一次介入 → 一条边」字面冲突。fable 把本轮 I-01/I-02/H0 和上一轮 R3–R8 逐条落到边+行。

若裁决方只按「有理由推翻 OP 计分」，**cursor 应排第一**：S/R 分层、`replace`、Q4 问法不成立，
三处都比「同意框架」远。我仍不把它当基座，只因为上面第 2、3 条在 §8 机械口径上比它硬。
吸收清单把 cursor 的这三刀放在最前。

### C.2 五份逐家

下列「§8」只写不满足或勉强；未列出的条按满足。每家至少一条可复跑指摘。

#### luna `1ddff5c2`

| 条 | 判 |
| --- | --- |
| 1 | 过。`profile_id: dev.change`；五家 `*.cli.v1` / `fable.gui.v1` |
| 2 | 过（类型表）。`AUTH-*` 七行，人是 principal。不是本轮已发生介入的历史表 |
| 3 | 过，且诚实。状态 ⊆ 内核；边声明合法；作者写成 `owner-claimed-unverified` |
| 4 | 过。出向三样 + 三值；amend 物化为 Artifact；修订单元 3.3 |
| 5 | 过。`tool_call / process / artifact_delta`；五家有值；自报不采信 |
| 6 | 过。§5.2 两例 |
| 7 | 过。三项皆「改写」 |
| 8–10 | 过 |

**可复核指摘**：Task 序列 seq 5–6 为 `WAITING → QUEUED`（luna `:215` 一带，H1 类冻结）。
内核 `request-lifecycle.md:269`：验证阶段等待回 `VALIDATING`，不是 `QUEUED`。
H1 冻的是契约，属验证期。luna 自己写了「恢复不能从等待直达成功」，但恢复边仍写成了执行期的那条。

**OP**：OP-1 加 TraceEnvelope（契约 / 策略 / 副作用摘要）——「同形但越权」反例成立，这是五家里对 OP-1
最干净的一条补充。OP-2 反对把 amend blob 塞进 Interaction 行、改存 Artifact 引用，成立。
OP-3 改写 Q4 为独立 sink + 允许 `UNKNOWN`，成立。不是附和。

**反例**：解释报错术语（不落盘）+ 已被 formatter 覆盖的空白修复。第二例比「都叫助手」更狠：
连模型都不必调。成立。

**强项**：E0–E4 取 `min` 不取平均；独立 sink 作绕过分母；历史评审 hash 可复跑；R2 写成
`identity_authority=UNVERIFIED`，commit 存在 ≠ 作者成立。
**缺陷**：权力表是类型不是本轮事实；H1 恢复边见上。

#### kimi `29b4f804`

| 条 | 判 |
| --- | --- |
| 1 | 过。`profile_id = "DEV"`；五家 `agent/*` |
| 2 | 过（类型表）。H1–H7；amend / INPUT 声明「不是新行，走 Interaction 恢复边」 |
| 3 | 过，偏粗。状态词合法；大量中间 WAITING 被压掉 |
| 4 | 过。`editable_scope` 作入向拒收约束；有修订单元 |
| 5 | 过。三档；fable = `fs_diff_only` |
| 6 | 过。两例 |
| 7 | 过。改写 / 改写含反对 / 改写过强预设 |
| 8 | **有一处锚点指错**，见下 |
| 9–10 | 过 |

**可复核指摘**：kimi `:271` 写 amend 进入下次 Attempt 输入时，把 `input_artifact_versions`
锚在 `request-lifecycle.md:388`。该行是 `F-EXEC-08`（Plan 是可选 Artifact）。
字段在 `:326`。可复跑：`git show 7e8464c2:sunmoonai/docs/dev-plan/working/request-lifecycle.md | nl -ba | sed -n '321,330p;388p'`。
另：`refact-fable.md:238` 被用来指「RUNNING 判不了」（kimi `:22`）；
`:238` 实际是「内核按 commit 引用」。RUNNING 段在 `:220`。task.md 自己也写过 `:238`，kimi 抄了任务书的错锚。

**OP**：比对规则三条（粗腿粒度、声明未比对、权限项 `bootstrap-zero` 单列）是对 OP-1 的真改写。
`editable_scope` 必须能拒收，是对 OP-2 的真反对。Q4「完全可观测不可达」成立。
另：指出任务书把「人 + 脚本」叫做 orchestrator，与上一轮「orchestrator 必须是代码」冲突
（kimi `:116-122`）——这是任务书自造同名物，按加分记。

**反例**：一次性正则提问；目标未定的探索对话。成立。第二例点出「修改目标还得建新 Task」，
比「贵在建单」多一跳。

**强项**：比对卫生；orchestrator 正名；T0 开工前动作 = 0。
**缺陷**：锚点两处错；轨迹把 ①–⑤ 收成一个 `RUNNING`，H5 没有独立 WAITING。

#### cursor `13f3d52b`

| 条 | 判 |
| --- | --- |
| 1 | 过。`DEV_ROUND`；五家 + `kind` 只取执行形态 |
| 2 | **H3/H4 写「不改边」**（`:368-369`），与 §8-2「一条边 + 一行」字面不合。H1/H2/H5/H7/I* 有边 |
| 3 | 过，自标重建。边进字段（D1 教训）；明确没有 `WAITING → SUCCEEDED` |
| 4 | 过。四值 + `amend_schema`；渲染进 Delivery；修订单元 2.5 |
| 5 | 过。三档；fable = `session` |
| 6 | 过。一例，成立 |
| 7 | 过。三项皆有理由的改写 / 部分反对 |
| 8 | 取件自证写 `rulings.md @ opus 20 行`（cursor `:10`）；`git show opus:…/rulings.md \| wc -l` 现为 30。起草时可能更短，按现标签对不上 |
| 9–10 | 过 |

**可复核指摘**：§8-2 见上。H3 省事裁定若「不改边」，它在状态机上没有落点，与「未记录的裁定无效」
也能兼容——但验收条要的是边，不是「裁定行生效」。fable 把这类放在 `WAITING(APPROVAL) → QUEUED`（H3），
kimi 同。cursor 这里松了。

**OP**：五家里推翻最狠。OP-1 拆 S/R、权力表不进四要素、边必须进序列——对，且用上一轮 D1 作证据。
OP-2 四值 `replace` 对准所有者原话第三项「以自己的方案替代」，三值会丢血缘。
渲染出内核、进 Delivery，理由是 UI 改动不该变规范修订——成立。
OP-3 部分反对 Q4 前提：账本内没有观测点。成立，不是附和。

**反例**：已签 T0 包 `paths` 内的文档笔误。贵在建单+供给+派发+回收。成立。
只举一例，比 luna/kimi/fable 窄，但卡在上一轮 §8 第 5 条「只管审批不管总开销」上，力度够。

**强项**：架构刀口最清楚；手工必须先仪器化，否则 R 层永远在重建；投喂不是权力。
**缺陷**：§8-2 两行无边；轨迹时间线与别家不同（11:30–12:40 标 VALIDATING），已标 ⚠，不算假证据。

#### fable `f053bd84`（自己）

| 条 | 判 |
| --- | --- |
| 1–7、9–10 | 过。机械项见候选 §9 自检；禁用词 / kind / 只读 diff / 身份行本环节重跑仍过 |
| 8 | 候选提交前改过修订记录行号；`:220` / `:242` / `:651` 已核。仍有解释性归属（I-01 算 H6、H1+H2 合并） |

**可复核指摘（对自己与评别家同一强度）**：

1. **H0 进权力表，又写「它不是权力」**（候选 `:178`）。cursor `:361-362` 更干净：粘贴是 orchestrator 欠账，
   不进表。我为了让 Q3/Q4 可数把它收进去，代价是权力表语义被稀释。吸收时应把 H0 移出权力表、
   单列 `dispatch = manual` 事件。
2. **`orch.manual = 人 + 脚本`**（候选 `:27`）踩了 kimi 指出的同名物。应改口：orchestrator 是代码，
   人是触发通道。
3. **没有 `replace`。** 用 `amend.base_version` 空或指向上一人类版本来表达「替代」。
   能工作，但所有者原话是三件不同的事；cursor 的四值更贴。财务计划被整份重写时，三值要靠血缘注释才能读出来。

**OP**：改写 / 改写 / 部分采纳。provenance 与 `power_row` 是真改写；Q 是 `(任务, orchestrator)` 的函数
也是真改写。力度低于 cursor 的 S/R 与 `replace`，高于 qwen 对 OP-1 的「采纳但补充」。

**反例**：笔误、一次性提问、对 `dispatch = manual` 执行者的任何分发。第三例成立，且是本轮特有——
贵在派发与身份核对，与任务大小无关。不接受「都值得走」。

**强项**：四档（`tool.reported` 有 `~/repo/codex/codex-rs/exec/src/cli.rs:60`）；历史介入表；
R2 写成拆除条件而不是脚注。
**缺陷**：上列三条。另：646 行，裁决吸收成本高于 cursor / luna。

#### qwen `1ae5b420`

| 条 | 判 |
| --- | --- |
| 1 | 过。`DEVELOPMENT`；五家有名单 |
| 2 | **弱**。§6.2 说「映射到 H1–H7」，没有逐条「介入 → 边 + 行」表。脚本若扫表，缺项 |
| 3 | **样例不是真实产物**。`:154-158` 五份 `candidate-<家>@v1` 在 `7e8464c2` 的 `rounds/refact-fable/` 不存在。状态词 ⊆ 内核，但导出源不对 |
| 4 | 过（字段齐）。修订单元比另四家薄 |
| 5 | **登记值与正文矛盾**。表 `:87` fable = `process`；§3.5 说无 argv/stdio。机械「无空缺」过，事实错。`roles_allowed` 含 `acceptor`，与 `task.md` §9「fable 不得担任验收」冲突 |
| 6 | 过。README 笔误，成立 |
| 7 | 过。OP-2 反对有内核句子；OP-1 接近「同意框架」 |
| 8 | 多用章节号（`:3.2`、`:3.7`）。协议：「引用按标题不按章节号」 |
| 9–10 | 过 |

**可复核指摘**：

```text
# 1) 验证期 H1 的恢复边
qwen :136-137：WAITING(APPROVAL) # H1 → QUEUED
内核 :269：验证阶段等待回 VALIDATING
# 2) 登记表
qwen :87：fable … process … proposer, acceptor
```

**OP**：OP-1「采纳但补充」——补充是「还要做 §8 静态检查」。静态检查本就是本轮验收，
不算对 OP-1 的推翻，**不按加分记**。
OP-2 反对把重载荷做成所有 Interaction 的通用扩展，引 `request-lifecycle.md:180-181`
「只有歧义才澄清」。锚点对。`interaction_class` 把重 schema 限在 `APPROVAL_WITH_ARTIFACT`，
这是五家里唯一把「不要膨胀简单 INPUT」写成字段的，**按加分记**。
OP-3 改写 Q3 为向量，理由「单项容易被 gaming」弱：三数任一超标与「三项各有上界」在判定上等价。

**反例**：README 笔误。成立。贵在供给工作区与 H5。与 cursor / fable 第一例同形，没有新信息。

**强项**：最短仍覆盖三块；OP-2 的 class 分割值得吸收。
**缺陷**：轨迹源不对、fable 档填错、§8-2 未列表、OP-1 近乎附和。

---

## D. 值得吸收的点

不管基座是谁，终稿应并进这些主张。出自别家的才列（自家已在基座里的不重复）。

| # | 出自 | 位置 | 主张 | 为什么值得 |
| --- | --- | --- | --- | --- |
| D1 | cursor | §1.5 | 等效分 S 层 / R 层，中间投影 Π；权力表在 S 层，不进一次 run 的四要素 | 治「看起来机械、手工侧其实在重建」。与 fable 的 provenance 互补：provenance 标等级，S/R 标何时可判 |
| D2 | cursor | §2.2 | 入向四值，`replace` ≠ `amend`；渲染进 Delivery | 对准所有者第三项；UI 改动不该变内核 |
| D3 | cursor | §1.3 / §3.5 | 粘贴投喂是 `dispatch = manual`，不是权力表行 | 修正 fable H0。Q3 另计 H0 事件，不把它叫权力 |
| D4 | luna | §2.1 | TraceEnvelope：契约 digest、策略版本、副作用摘要。四序列同形但越权 → 不等价 | fable / OP-1 都漏了「同形越权」 |
| D5 | luna | §4.3 | 证据等级取 `min(可见上限, 隔离, 独立性, 覆盖)`，未知即降，不取平均 | 比「自报不采信」可执行 |
| D6 | luna | §5.4 | 绕过分母取外部 sink；不能把未归因变更反向补成正常 Task | 防 Q4 诱发 Bypass 状态（cursor §7 第 3 点同旨） |
| D7 | kimi | §1.4 | orchestrator = 确定性代码；人是触发通道。任务书「人 + 脚本 = orchestrator」是同名物 | 改 fable `orch.manual` 的命名 |
| D8 | kimi | §1.5 规则 2–4 | 比对取较粗一腿并声明未比对；两边声明权威源；权限项 `bootstrap-zero` 单列 | 与 D1 一起构成 OP-1 的可执行改写 |
| D9 | kimi | §5.2 | `editable_scope` 是入向拒收约束，不是出向展示 | 否则三值退回「布尔 + 全文替换」 |
| D10 | qwen | §5.2 | `interaction_class`：重载荷只绑 `APPROVAL_WITH_ARTIFACT`，简单 INPUT 保持轻 schema | 与内核「不要为填栏目而追问」一致；防 P2 把所有等待做重 |
| D11 | cursor / luna / kimi | Q4 | 允许结论 `UNKNOWN`；零命中不能写成「没有绕过」 | 与 `--ff-only` 响亮失败同一纪律 |

**不吸收**：qwen 把 fable 标 `process` 且给 `acceptor`；qwen 示意轨迹里的五份「候选」；
cursor 的 H3/H4「不改边」；任何把「同意 OP 框架」当优点的句子。

---

## E. 盲区

- 未逐字节重读五份里每一条 `file:line`（抽核了 luna 两处评审 hash、kimi `:388`、qwen `:180-181` / `:87`、
  cursor `:368-369`、fable 候选已核过的 `:220` 等）。
- 未读 ② 之后各家工作区未提交改动——按协议只看通知里的 commit。
- 排序含自评。请按 C.0 / C.1 的表复核，不要只看名次。
