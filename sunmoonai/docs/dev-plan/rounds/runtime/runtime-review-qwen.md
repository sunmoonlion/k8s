参与方：qwen｜worktree：/home/zym/worktrees/qwen/k8s｜HEAD：3ff2fad7cdcc2ad2c0b6a559370b4bf333f007d2

# runtime 轮互评 —— qwen

> 身份已校验：`basename "$(git rev-parse --show-toplevel | xargs dirname)"` → `qwen`。
> 五份候选均从对应分支取出并校验 sha256[:16]，与 `runtime-call-②.md` 一致。
> 本文按 `task.md` §8 十条、OP-1/2/3、必答 Q 第 2 问逐份评。

## 方法论

- §8 十条中，第 1、2、5、6、7、9、10 条按机械可判口径；第 3、4、8 条按字段/锚点/可复跑命令检查。
- 「不满足」会给出条号、位置与可复核命令；「部分满足」给出缺口。
- 对 OP-1/2/3 的处理：仅「有理由地推翻/改写」加分，单纯附和不得分；此处只记是否成立。
- Q2 反例：按「给不出反例按未回答处理」的硬口径；只列小标题不算，必须有「贵在哪一步」的具体成本点。

---

## 一、luna (`dev.change.v1`)

### 1. §8 十条满足情况

| 条 | 判定 | 说明 |
| --- | --- | --- |
| 1 | 满足 | `profile_id = dev.change`（§1.2），五个 Agent Profile 在 §4.2（`luna.cli.v1` 等）。全文无禁用词组。 |
| 2 | 部分满足 | 人无 `kind`，作为 `principal` 处理（§1.3）。但 §1.3 的权力表用 `AUTH-*` 七行，未逐条列出本轮/上一轮每一次人的介入；缺少类似 fable §2.4 第二张表的「事件 → 边 → 行」无缺项清单。 |
| 3 | 满足 | §2.1 给出四序列字段定义；§2.2 从 `7e8464c2` 导出 trace，状态 ⊆ 内核，并诚实标 `evidence=GAP`。 |
| 4 | 满足 | §3.1/3.2  outbound 含 artifact/version/render/editable，inbound 含 `approve/reject/amend` 及 response Artifact；§3.3 给出内核修订边界、影响、迁移。 |
| 5 | 满足 | §4.1 Agent Profile 有 `observation_granularity`（`tool_call|process|artifact_delta`）；§4.2 五家逐条填；§4.3 给出证据等级 E0–E4 及「自报不采信」推论。 |
| 6 | 满足 | §5.1 分类规则，§5.2 两个反例（解释报错术语、formatter 单文件空白修复），§5.3 T0 上界，§5.4 绕过可观测性。 |
| 7 | 满足 | §6 对 OP-1/2/3 均为「改写」并附理由。 |
| 8 | 满足 | 现状断言附 `request-lifecycle.md@70a7dd50:xxx` 等锚点；可复跑命令如 §2.2 的 `git show --stat 7e8464c2`。 |
| 9 | 满足 | 头部声明未改只读输入。 |
| 10 | 满足 | 首行身份自证；`<名>` = `luna`。 |

### 2. 可复核指摘

**Agent Profile ID 与登记表形状不一致，机械枚举时会漏认。**
luna 把五家登记为 `luna.cli.v1`、`kimi.cli.v1` 等，而 `task.md` §6.1 的登记表事实以参与方名（`luna`、`kimi`…）为键。这不是禁用问题，但会让「五家 Agent Profile 名单」这一机械判点需要额外映射。见 `runtime-luna.md:224-230`、§4.2 表。

### 3. OP-1/2/3 处理

- **OP-1 改写**：加 `TraceEnvelope` 防「同形越权」，理由成立（§2.1）。
- **OP-2 改写**：amend  payload 物化为 Artifact 版本而非内嵌大 blob，成立（§3.1/3.2）。
- **OP-3 改写**：Q4 要求独立 sink 并声明 `UNKNOWN`，成立（§5.4）。

### 4. Q2 反例

两个反例均成立，且都指出「贵在额外阶段/无复用价值」：解释报错术语（§5.2）、formatter 单文件空白修复（§5.2）。

---

## 二、kimi (`DEV`)

### 1. §8 十条满足情况

| 条 | 判定 | 说明 |
| --- | --- | --- |
| 1 | 满足 | `profile_id = "DEV"`（§1.2），五个 Agent Profile 在 §1.3 与 §6。无禁用词组。 |
| 2 | 部分满足 | 人无 `kind`（§1.3）。§7.1 权力表 H1–H7，§7.2 给出 7 条人的介入映射。但 §7.2 后文声明「另外两类人的动作不是权力表行」——INPUT 类澄清与 amend 被排除在表外。这与 §8-2「每一次介入都能指到一条边 + 一行」存在张力；amend 作为人的内容改动，至少应落在某行（如 fable 的 H8）。 |
| 3 | 满足 | §1.5 给出轨迹四要素字段定义与四条比对规则；§1.6 给出 `refact-fable` 样例，并声明「重建，不是观测」。 |
| 4 | 满足 | §2.2  outbound/inbound 字段齐全；§2.4 给出规范修订工作单元的边界、影响、迁移。 |
| 5 | 满足 | §3.1 三档 `per_tool_call|process_only|fs_diff_only`；§6 表五家逐条填；§3.2 给出「自报不采信」推论。 |
| 6 | 满足 | §4.1–4.4 四问全答；§4.2 两个反例。 |
| 7 | 满足 | §5 对 OP-1/2/3 均有「改写」或「采纳但改写」并给理由。 |
| 8 | 满足 | 锚点与可复跑命令 abundant。 |
| 9 | 满足 | 头部声明。 |
| 10 | 满足 | 首行身份自证；`<名>` = `kimi`。 |

### 2. 可复核指摘

**权力表缺少 H8/INPUT 行，§8-2 的「无缺项」不成立。**
`runtime-kimi.md:523-526` 明确说「INPUT 类澄清……不是权力表行」、「amend ……不是新的介入类型」。但 §8-2 要求「人的每一次介入都能指到唯一状态机的**一条边** + 权力表的**一行**，逐条列表（脚本判：无缺项）」。本轮 I-01/I-02 及 R3–R8 中大量「人在选项间裁」的介入，若不算权力表行，则脚本扫描会报缺项。

### 3. OP-1/2/3 处理

- **OP-1 改写**：加「比对粒度取较粗一腿」「权威源声明」「bootstrap-zero 单列」，成立（§5.1）。
- **OP-2 改写（含反对）**：反对把 `editable_scope` 当展示字段，主张其为入向约束；补充 `response_state_version` 与 `supersedes`，成立（§5.2）。
- **OP-3 采纳但改写**：Q4 前提「绕过可观测」改为先声明限度，成立（§5.3）。

### 4. Q2 反例

两个反例成立：一次性提问、目标未定探索性对话，均指出贵在 `VALIDATING` 与短命 Task（§4.2）。

---

## 三、cursor (`DEV_ROUND`)

### 1. §8 十条满足情况

| 条 | 判定 | 说明 |
| --- | --- | --- |
| 1 | 满足 | `profile_id = "DEV_ROUND"`（§1.2），五个 Agent Profile 在 §1.3 表。无禁用词组。 |
| 2 | 满足 | 人无 `kind`；§3.5 权力表 P-FREEZE 至 P-DECIDE 共 8 行，覆盖冻结、开工、裁定、扩权、发布、推翻、取消、回答 Interaction。 |
| 3 | 满足 | §1.5 拆 S 层/R 层，给出投影 Π 与字段定义；§4 给出 `refact-fable` 重建样例。 |
| 4 | 满足 | §2.2  inbound 四值 `approve/reject/amend/replace`， outbound `subject_artifact_id`/`amend_schema`；§2.5 修订工作单元边界/影响/迁移。 |
| 5 | 满足 | §3.1 三档 `tool|process|session`；§1.3 表五家逐条填（fable 为 `session`）；§3.2 给出证据权威性推论。 |
| 6 | 满足 | §5.1–5.4 四问全答；§5.2 给出反例。 |
| 7 | 满足 | §6 对 OP-1/2/3 分别「改写/改写/部分反对」并给理由。 |
| 8 | 满足 | 锚点 abundant；样例声明「重建，不是观测」。 |
| 9 | 满足 | 头部声明。 |
| 10 | 满足 | 首行身份自证；`<名>` = `cursor`。 |

### 2. 可复核指摘

**S 层/R 层拆分在口头上成立，但 R 层样例仍混入了不可比字段。**
`runtime-cursor.md:399-410` 的 Task 状态序列中，把「11:30–12:40 多轮改稿」标为 `VALIDATING`，理由是「并行 Attempt 在推进」。该推断把 Artifact 修订活动等同于 Task 状态；若严格按 R 层「只比边」的纪律，这一段应标为 `UNKNOWN` 或拆成 Attempt 级事件，否则 R 层比对会被这条「解释性状态」污染。cursor 自己在 §1.5 警告过「重建是解释」，此处却未把解释标为 `inferred`。

### 3. OP-1/2/3 处理

- **OP-1 改写**：S/R 层拆分、边必须进字段、权力表是 S 层，成立（§6）。
- **OP-2 改写**：增加 `replace` 区分「部分否定」与「整份替代」，并把渲染移出内核，理由成立（§6/§2.2）。
- **OP-3 部分反对**：反对 Q4 预设「账本可观测绕过」，主张外部采样面 + 覆盖声明，成立（§6）。

### 4. Q2 反例

反例成立：改文档笔误落在 T0 包内，指出贵在「建工单 + 供给 worktree + H5 发布」（§5.2）。

---

## 四、fable (`dev.change`)

### 1. §8 十条满足情况

| 条 | 判定 | 说明 |
| --- | --- | --- |
| 1 | 满足 | `profile_id = dev.change`（§2.2），五个 Agent Profile `ap.luna` 等列于 §2.3。无禁用词组。 |
| 2 | 满足 | 人无 `kind`，登记为 `[principal.owner]`（§2.3）。§2.4 权力表 H0–H8，并给出 11 条历史介入 → 边 → 行的无缺项清单（含本轮与上一轮）。 |
| 3 | 满足 | §2.7 带 `provenance`/`power_row` 的 trace_entry 字段；§2.8 给出 23 行 `refact-fable` 真实产物 trace，逐行标 `attested/reported/inferred`。 |
| 4 | 满足 | §3.2 outbound/inbound 字段齐全（含 `options[]`、`evidence_grade`）；§3.3 amend 路径；§3.5 内核修订边界/影响/迁移。 |
| 5 | 满足 | §4.1 把粒度拆为 `observability/enforcement/sandbox` 三个字段、四档；§2.3/§4.2 五家逐条填；§4.3 给出证据权威性规则。 |
| 6 | 满足 | §5.1–5.4 四问全答；§5.2 三个反例。 |
| 7 | 满足 | §6 对 OP-1/2/3 均为「改写/部分采纳」并给理由。 |
| 8 | 满足 | 锚点 abundant；头部还给出沙箱身份取证（`uid_map` 切换）。 |
| 9 | 满足 | 头部声明，§9 自检再次确认。 |
| 10 | 满足 | 首行身份自证；`<名>` = `fable`。 |

### 2. 可复核指摘

**权力表 H0 的定性模糊，可能让脚本把「欠账」误判为权力行。**
`runtime-fable.md:180` 把 H0 定义为「代行 orchestrator 的传输动作」，并写明「无（它不是权力，是欠账；进表是为了可数）」。但 §8-2 的机械判是「登记表中不出现 `kind = 'human'`」与「每次介入 → 边 + 行」；H0 的 `eligible_principal = owner` 且 `enforcement_point = 无`，会让脚本在数「行」时把它算作权力行，而其本质是 orchestrator 欠账。fable 本可在表外单独建「orchestrator 欠账清单」，避免混淆权力模型与实现欠账。

### 3. OP-1/2/3 处理

- **OP-1 改写**：加 `provenance`、`power_row`、作者拆 `claimed/attested`、等效只在最低等级宣称，理由最充分（§6.1/§2.7）。
- **OP-2 改写**：`editable` 机械可判、加 `evidence_grade`/`options[]`、responder 由运行时鉴别，成立（§6.2/§3.2）。
- **OP-3 部分采纳**：指出四问把开销当成任务属性，实应为 `(任务, orchestrator 实现)` 属性；正确观察面是底座 git 而非账本，成立（§6.3/§5）。

### 4. Q2 反例

三个反例均成立：单文件笔误、一次性提问/探索性阅读、对 `dispatch=manual` 执行者的分发，分别指出贵在 worktree 供给、`VALIDATING` 契约化、H0 身份核对（§5.2）。第三个反例是本轮独有的强观察值。

---

## 五、qwen 自己 (`DEVELOPMENT`)

### 1. §8 十条满足情况

| 条 | 判定 | 说明 |
| --- | --- | --- |
| 1 | 满足 | `profile_id = "DEVELOPMENT"`（§1.2），五个 Agent Profile 在 §1.3。无禁用词组。 |
| 2 | **不满足** | §6.2 只说「权力表引用 `principal = 'owner'` ……人的介入全部映射到唯一状态机的一条边和权力表的一行（H1-H7）」，但**未给出权力表本身**，也未逐条列出本轮/上一轮每一次人的介入。脚本无法判「无缺项」。 |
| 3 | 部分满足 | §1.5 给出轨迹四要素定义；§1.5.1 给出 `refact-fable` 样例，但样例是文本块而非字段化记录，且未像 fable/cursor 那样逐行标 `provenance` 或声明「重建」。 |
| 4 | 满足 | §2.2 outbound/inbound 字段齐全；§2.3 amend 路径；§2.5 内核修订边界/影响/迁移。 |
| 5 | **不满足** | §3.1 表只列 `tool_call|process` 两档；§1.3 表把五家（含 fable）全部填为 `process`。fable 作为 GUI/无 argv 执行者，应落在比 `process` 更粗的粒度（如 `fs_diff_only`/`session`）；§3.5 虽称 fable 是「process 粒度的极端」，但未在登记表中修正，导致 §8-5「五家逐条填该字段」存在事实错误。 |
| 6 | 满足 | §4.1–4.4 四问全答；§4.2 给出反例。 |
| 7 | 满足 | §5 对 OP-1/2/3 分别「采纳但补充/反对/采纳但改写」并给理由。 |
| 8 | 满足 | §6.4 锚定列表丰富。 |
| 9 | 满足 | §6.3 声明未改只读输入。 |
| 10 | 满足 | 首行身份自证；`<名>` = `qwen`。 |

### 2. 可复核指摘

**fable 的可观测粒度被错误登记为 `process`，与自身 P3 分析矛盾。**
`runtime-qwen.md:87` 的 Agent Profile 表把 fable 的 `observability_granularity` 填为 `process`；同文件 §3.5 又说 fable「看不到 argv、看不到 stdin/stdout、只能看到文件系统前后差异」。按后者，fable 应是 `fs_diff_only` 或 `session` 档，而非 `process`。该矛盾可通过复跑以下命令确认原文：

```bash
ref=$(printf '%s' 'qwen'); ref="${ref}:sunmoonai/docs/dev-plan/runtime-architecture.md"
git cat-file -p "$ref" | sed -n '82,93p'
git cat-file -p "$ref" | sed -n '278,287p'
```

### 3. OP-1/2/3 处理

- **OP-1 采纳但补充**：主张除动态轨迹外还需静态结构检查，成立（§5.1）。
- **OP-2 反对**：主张加 `interaction_class` 把重型载荷限定在 `APPROVAL_WITH_ARTIFACT`，理由成立（§5.2）。
- **OP-3 采纳但改写**：把 T0 上界从单数改为复合向量，成立（§5.3）。

### 4. Q2 反例

反例成立：改 README 笔误，逐条列出运行时 11 步 vs 手工 4 步，指出贵在工作区供给与 H5 确认（§4.2）。

---

## 优劣排序与依据

**fable > cursor > kimi > luna > qwen**

1. **fable**：唯一同时做到 (a) trace 样例逐行带 `provenance` 与 `power_row`；(b) 权力表给出本轮+上一轮 11 条历史介入的无缺项清单；(c) 把可观测粒度拆成 `observability/enforcement/sandbox` 三个字段；(d) Q2 给出三个具体反例且第三个切中本轮 fable 自身的 `dispatch=manual` 痛点。缺点是 H0 作为「欠账」混入权力表，略显冗余。

2. **cursor**：S/R 层拆分最清晰，把「边」显式放进状态序列字段，避免 OP-1「只比状态点」的漏洞；`replace` 决策值与 `amend_schema` 对 OP-2 的改写有实质贡献；fable 的 `session` 粒度登记准确。缺点是 R 层样例中仍把解释性推断写入 Task 状态序列，未全部标 `inferred`。

3. **kimi**：T0 上界与绕过可观测性的分层回答扎实；OP-2 改写中把 `editable_scope` 明确定位为入向约束是亮点。缺点是 §8-2 把 INPUT/amend 排除在权力表外，与「每一次介入 → 一行」的要求冲突。

4. **luna**：证据等级 E0–E4 与 `TraceEnvelope` 概念有新意，但权力表抽象为 `AUTH-*` 后缺少历史事件清单；Agent Profile ID 使用 `*.cli.v1` 后缀，与任务书以参与方名为键的登记事实存在间接映射。

5. **qwen（本稿）**：存在两个实质缺口——未给出权力表/历史介入清单，以及 fable 粒度误标为 `process`。OP 表态与 Q2 反例尚可，但 §8-2 与 §8-5 的机械判点不通过，故排末位。
