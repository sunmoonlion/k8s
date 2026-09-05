参与方：opus（裁决方）｜worktree：/home/zym/worktrees/opus/k8s｜环节：③ 裁决

# 处置记录：轮次 runtime ③

> 裁决方 opus。本文记录逐家处置、三处对立的裁决、裁决方自身的错误，以及必须由所有者裁的一条。
> **裁决稿另落共享最终路径** `sunmoonai/docs/dev-plan/runtime-architecture.md`（opus 分支）。
>
> 取件锚：五份候选与五份评审均按 `runtime-call-②.md` 所钉 commit 读取，未读工作区。

---

## A. 五家排序与共识

| 评审方 | 1 | 2 | 3 | 4 | 5 | 基座建议 |
| --- | --- | --- | --- | --- | --- | --- |
| luna | **luna** | fable | cursor | kimi | qwen | luna |
| kimi | **fable** | luna | cursor | kimi | qwen | fable |
| cursor | **fable** | luna | cursor | kimi | qwen | fable |
| fable | **fable** | cursor | luna | kimi | qwen | fable |
| qwen | **fable** | cursor | kimi | luna | qwen | fable |

**收敛点**：五家一致把 qwen 排末位、kimi 排第四；四家推 fable 为基座。
**自评纪律**：cursor 自排第 3、kimi 自排第 4、qwen 自排第 5，三家自评低于他评或持平；
luna 与 fable 自排第一，两家均写了利益申报并给出「按另一口径应是谁」（luna→fable / fable→cursor）。
上一轮所有者指出的「评优时没评自己」已补上，且未出现自抬。

### A.1 独立性观察值（本轮要取的那个）

`task.md` §6.2.1 的 ⚠：cursor 与 fable 同厂，共用多少 harness 内核未知，「两组」是上界。三家各自测了：

| 测法 | 结果 |
| --- | --- |
| 裁决方词汇 Jaccard | cursor↔fable = 0.087，**低于九对中位数 0.089**，远低于最高的 kimi↔qwen 0.108 |
| luna 精确公共非空行 | 17 行（去重后 13），分母 438 / 501 |
| cursor 逐点对照 | 「论证切分平行，产物密度不平行」；并指出 luna–kimi（**同 harness**）的纹理差异大于 cursor–fable |
| kimi 逐点对照 | 对同一问题给出**相反**答案（三值 vs 四值；render 留内核 vs 踢出内核）；「共用 harness 内核不应出现系统性反向」 |

**裁定 D-OBS**：本轮数据**不支持**把 cursor 与 fable 折并为同一独立信号。但也要如实说：
词汇相似度是弱代理——裁决方据它先下过「实质趋同」的错判，被结构对照推翻（见 E-4）。
分组键 `runtime`（应改名 `harness`，见 D-4）在本轮维持字面两组；`(runtime, model_family)` 的问题**未解决**，
本轮只提供了一个反向证据点：**同 harness 的 luna–kimi 差异大于同厂不同 harness 的 cursor–fable**——
若成立，分组键应按 `model_family` 而非 `harness`。⚠ 单轮单题，不足以定论，登记为观察值。

---

## B. 基座裁定

**基座 = fable `f053bd84`。**

⚠ 协议「③ 裁决」规定「**票数不是依据**，多数推荐不构成选它的理由；理由必须是可复核的差异」。
本记录初稿把「四家推荐」写在理由之前，是错的（裁决方 E-7）。选择的依据是且只是下列三条可复核差异；
§A 的排序表是评优环节的产物与观察值，**不是基座选择的依据**。三条：

1. **§8-3 是唯一被量化的。**23 行 trace 逐条标 `attested / reported / inferred`，读数 2/15/6，
   并给出「等效只能在两条轨迹的最低来源等级上宣称」。这直接证明了 OP-1 原文的缺陷：
   一条几乎全是自报的轨迹会被判「全等」。其余四家：luna 标 GAP（次强）、cursor / kimi 标「重建」、
   qwen 未标且对象不实（见 C.5）。
2. **P3 分解最精确。**把 `task.md` 那张两列表绑死的三件事拆开：能看多细（`observability`）、
   能在哪拦（`enforcement`）、沙箱谁提供（`sandbox`）；并用 `~/repo/codex` 源码锚点立第三档
   `tool.reported`。该锚点由 kimi 实跑 sed 复核通过（cursor 声明未核）。
3. **§8-2 是唯一的历史事实表。**11 行覆盖本轮 I-01/I-02/H0 与上一轮 R3–R8，逐条落到边 + 行；
   并顺手登记一个真观察值：本轮 H1+H2 实发 1 次触点，与 `refact-fable.md` §8 第 5 条「T2 = 2」不符。

**不选 luna 的理由**（luna 自荐且理据充分，此处说明为何仍不选）：luna 的形式化（TraceEnvelope、
E0–E4、迁移细案）质量最高且最工程化，但它们是**可并入基座的模块**；而 fable 的 `provenance`
是**基座结构**——把它并进 luna 需要重写 trace schema 与拆除条件。按「改动量小者为基座」，选 fable。
luna 的三块整体并入（见 G）。

---

## C. 逐家处置

判定口径：`满足` / `部分` / `不满足`。仅记有争议或不满足的条。

### C.1 fable `f053bd84`（基座）

| 条 | 判定 | 处置 |
| --- | --- | --- |
| §8-2 | 满足，但 **H0 行须移出权力表** | 四家（luna / kimi / cursor / qwen）独立指出同一点：`task.md` §7 第 2 条要求「每行 `enforcement_point` 非空」，H0 的该栏为「无」；作者自陈「它不是权力，是欠账」。**采纳移出**：H0 改为 `dispatch_event{mode = manual}`，可数目标由事件计数达成，不占权力表行。权力表回到 H1–H8 八行 |
| §8-5 | 满足 | `ap.qwen` 的 `provider = "alibaba"` 是推断（cursor / kimi 同时指出）。**改为留空标 ⚠**——`task.md` §6.2.1 该栏为「—」，推断不得进登记表取值 |
| §8-4 | 满足 | 迁移条「旧响应视为 `decision = approve`」**驳回**，改用 luna 的 `legacy_resume`：旧 token 只证明 consumed，不证明 approve（同一缺陷见 cursor `:281`、qwen `:231-236`，三家一并改） |
| Q2 | 部分 | 「fable 在现状下**任何**任务走运行时都比手工贵」是全称断言，luna 指出固定一次 H0 不会压过任意大的续接/并行收益。**收窄为 M0/T0 类**，反例本身成立且保留 |
| 其他 | — | `orch.manual = 人 + 脚本` 踩了 kimi 指出的同名物（作者自认）。**统一改口**：orchestrator = 确定性代码，人是触发通道 |

### C.2 luna `1ddff5c2`（第二，三块整体并入）

| 条 | 判定 | 处置 |
| --- | --- | --- |
| §8-2 | **部分** | 作者自评已认：权力表缺「冻结题目与验收标准」这一行（`AUTH-FREEZE`），`AUTH-CANCEL` 未展开为具体源状态边。并入时**补 `AUTH-FREEZE`**，并把 `AUTH-BUDGET` 的「授权范围」收窄为「冻结授权范围内的预算/资源额度」（改授权范围按内核 `:292-301` 应建新 Task） |
| §8-3 | 满足，一处边错 | cursor 与 fable 各自独立指出：样例 seq5 `WAITING`(H1) → seq6 `QUEUED`，而 H1 冻的是契约、属**验证阶段**，内核 `:269` 规定回 `VALIDATING`。luna 自己 §1.3 的 `AUTH-CONTRACT` 用对了边，样例没用。**采纳更正** |
| §8-8 | 一处引用错 | luna:218「相邻边全部属于 `:205-209`」——已复核：`:205-209` 是状态机 ASCII 图，合法转换列表在 `:222-228`。**更正** |
| OP-2 | 表态成立但**框定夸大** | kimi 指出 luna 反对的「把任意 amend blob 塞进 Interaction 行」并非 OP-2 主张——OP-2 原文即写「该内容成为一个新 Artifact 版本」。**裁定：这一条的「反对」降级为「细化」**，细化内容（引用 + digest + renderer registry）仍全额采纳 |
| §1.4 拆除条件 5 | 驳回一处 | 「无命令入口者……要么从可路由集合移除」与 `task.md` §6.4 要求处理的「存在但不可自动分发」相悖。**按 fable 的可数欠账方案** |

### C.3 cursor `13f3d52b`（第三）

| 条 | 判定 | 处置 |
| --- | --- | --- |
| §8-4 | **见 F-1，裁决方不单独裁** | 字面上冲撞冻结条款（移出 render、入向四值）。但这与 §8-7「有理由地推翻 OP-2 按加分记」直接矛盾——**矛盾在冻结的判据本身，不在候选**。提请所有者 H6 |
| §8-2 | **部分** | H3/H4/H6 写「不改边」（`:368-369`），与 §8-2「每次介入 → 一条边」字面不合。fable / kimi 均把这类放在 `WAITING(APPROVAL) → QUEUED`。**采纳 fable/kimi 的边** |
| §8-3 | 部分 | qwen 指出：`:399-410` 把 11:30–12:40 标 `VALIDATING`，属解释性推断却未标 `inferred`——cursor 自己在 §1.5 写过「重建是解释」。**并入时按基座的 `provenance` 标 `inferred`** |
| Q1 | **驳回一处** | 分类规则用 `tier ∈ {T1,T2}` 判「走运行时更便宜」——kimi 指出档位由风险判据定、不由成本定，用档位反推成本是循环，判的是代理变量。luna 另指出新增布尔缺省 `false` 会 fail-open。**两处均采纳，规则改用基座 M1–M4 + luna 的布尔特征集** |
| §8-8 | 轻微 | 首行 HEAD 用短 sha（其余四家全 40 位）；取件自证写「`rulings.md @ opus` 20 行」，现为 30 行——**后者是裁决方的过程瑕疵，不计 cursor**，见 E-3 |

### C.4 kimi `29b4f804`（第四）

| 条 | 判定 | 处置 |
| --- | --- | --- |
| §8-3 | **不满足** | 三家独立指出并经裁决方复核：§1.6 声明对象是 `refact-fable` 轮，却引用 `refact/luna @ e41e646a`、`refact/kimi @ e33fac68`、`refact/integration @ 36bfa5c2`——这三个标签属于**上上轮 `refact`**（`git for-each-ref 'refs/tags/refact/*'` 可复跑），而 `refact-fable` 轮的归档里候选文件为 **0 个**。**样例的 Attempt 段不采用**；其 Task 状态段与 Artifact 版本段来源正确，保留 |
| §8-8 | 两处锚点错 | (a) `:271` 把 `input_artifact_versions` 锚在 `:388`，实际在 `:326`（`:388` 是 `F-EXEC-08`）；(b) `refact-fable.md:238` 指「RUNNING 判不了」，实际在 `:220`。**(b) 的责任在裁决方**——`task.md:214` 就是这么写的，kimi 照抄，见 E-1 |
| §8-2 | 部分 | 把 INPUT 类澄清与 amend 排除在权力表外（`:523-526`），而上一轮 R3–R8 六次所有者裁决正属此类。**按 fable 的 H8 补行** |
| OP / 比对规则 | **全额采纳** | 四条比对规则（白名单、取较粗腿并声明未比对、两边声明权威源、权限归因单列）是五份中最能落成脚本的；`editable_scope` 作入向拒收约束、`response_state_version` 防 stale、`supersedes` 链，三条全收 |
| 同名物 | **加分** | 指出 `task.md` §3.1「今天的 orchestrator 是人 + shell 脚本」与 `refact-fable.md` §3.9「orchestrator 必须是代码」冲突，是把欠账重命名为组件。**裁决方认错，见 E-2** |

**说明**：kimi 的 §8-3 硬失败与其 OP 攻击质量并存。排序第四取决于前者；但其比对规则的采纳量在五家中仅次于基座。

### C.5 qwen `1ae5b420`（第五）

| 条 | 判定 | 处置 |
| --- | --- | --- |
| §8-3 | **不满足** | 四家 + 裁决方独立复核一致：§1.5.1 列出 `candidate-luna@v1` 等五份候选，并声称有 H2 开工确认与 ⑤ 验收后的 H5。复核结果：`rounds/refact-fable/` 下**候选文件 0 个、验收产物 0 个**，`rulings.md` 中「H2」「⑤验收」「acceptance」命中各 **0 次**。这不是「重建」而是**把本轮形状倒灌进历史**，且未作任何 ⚠ 声明。**不采用** |
| §8-5 | **不满足** | 登记表 `:87` 给 fable 填 `process`，同文 §3.5 又写「看不到 argv / stdin / stdout」——按其 §3.1 自己的定义即非 `process`。机械判「无空缺」通过，事实错误。**不采用** |
| §8-2 | **不满足** | §6.2 只有「全部映射到 H1–H7」的声明，无权力表、无逐条清单。**声明不是可判产物** |
| 其他 | 违反冻结任务书 | 登记表给 fable 填 `roles_allowed = proposer, acceptor`，而 `task.md` §9 明写「fable 不得担任验收」。**不采用** |
| OP-2 | **加分，采纳** | `interaction_class`：重载荷只绑 `APPROVAL_WITH_ARTIFACT`，轻量 INPUT 保持轻 schema，锚在内核 `:180-181`「只有歧义实质改变结果/权限/成本/风险时才澄清」。**这是五家唯一正面处理该纪律的**，四家评审一致建议吸收 |
| OP-1 | 不计分 | 「采纳但须补充静态检查」——静态检查本就是本轮 §8，不构成对 OP-1 的攻击。按 §5 纪律附和不计分 |
| §8-8 | 复核通过 | 12 处锚点裁决方逐条复核，**全部成立**，含 `constraints.md` A1/A3 逐字正确。上一轮的假证据问题本轮未复发，且是唯一把方案接回既有约束册的 |

---

## D. 三处对立的裁决

评审明确留给裁决方的对立，逐条裁：

### D-1 「以自己的方案替代」：cursor 的 `replace` 第四值 vs fable 的 `amend + base_version` 血缘

**裁定：保留三值，但 `replace` 必须是机械可判的一等字段。**

理由：所有者原话是三件事（全部否定 / 部分否定 / 以自己的方案替代），但「部分否定」与「整份替代」的
差别在**血缘**上——前者 `base_version` = 被审的 agent 版本，后者不接 agent 版本。fable 的方案
信息量更大（血缘图可判），cursor 的顾虑（三值会丢「人重写了整份」）也成立。
折中按 cursor 自己在评审 D8 提的方案：**不加第四枚举值，但 `amend.mode ∈ {patch, replace}` 必须落字段**，
且轨迹能机械区分。cursor 的 R3 样例（所有者采纳「第四种」）按 `mode = replace` 标，不得标成普通 approve。

### D-2 render 的位置：cursor（Delivery / `client_context`）vs fable / luna / kimi（内核绑定）

**裁定：采纳 cursor。**内核绑定只留 `subject_artifact_ref` 与 `amend_schema`；
`render` 降为 Delivery 侧投影，按 `audience` 的 `client_context`（内核 `:140` 已有）选择。
理由：cursor 的论证——**把渲染放进内核会让每次 UI 改动都变成规范修订**——没有被任何一家反驳，
kimi 明确认领此批评（其评审 A 块自评 3）。
但 fable 的 `evidence_grade`（人在批之前先看到这是几级证据）**独立于 render 位置，保留在出向绑定**：
它不是展示形式，是被展示对象的属性。此点采纳 kimi 的意见。

### D-3 H0：进权力表（fable）vs 不进（cursor / luna / kimi / qwen）

**裁定：不进权力表。**权力表的不变量是「每行 `enforcement_point` 非空」（`task.md` §7 第 2 条，上一轮
§8 第 2 条幸存且变强）；H0 该栏为「无」，进表即破坏「行 = 批准」。
但 fable 的目标（**必须可数**，否则 Q3/Q4 数不到「打开 GUI + 跑身份 + 粘指令」）成立且重要——
cursor 自评已承认放弃 H0 导致自己的 T0 上界漏计。**改为 `dispatch_event{mode = manual}` 事件，进 Q3 的计数口径。**

### D-4 命名：分组键 `runtime` 一词三义

**裁定：采纳 fable，改名 `harness`。**依据是 `refact-fable.md:253` 该字段注释本来就写「执行 harness」，
证据自洽、零成本。「运行时」此后只指产品运行时；内核「Agent runtime」在修订单元里注一句同义。
**这是任务书自造的同名物，责任在裁决方**（见 E-5）。

### D-5 Task Profile 的 id：`dev.change` / `DEV` / `DEV_ROUND` / `DEVELOPMENT` 四个并存

**裁定：用基座的 `dev.change`，其余三个登记为别名一行，不并存四个真源。**（采纳 cursor 评审 D 节末条。）

---

## E. 裁决方自身的错误（登记，不辩解）

本轮五家指出或裁决方自查发现的、**属于裁决方**的错误：

| # | 错误 | 发现者 | 后果 | 处置 |
| --- | --- | --- | --- | --- |
| E-1 | `task.md:214` 把「`RUNNING` 目前判不了」锚成 `refact-fable.md:238`，实际在 `:220` | fable（裁决方复核确认） | **kimi 两处照抄了这个错锚**（其 `:22` / `:329`）——错误锚点被下游继承 | 任务书已冻结不得改；裁决稿使用 `:220`，本记录留档。kimi 该处不计其失 |
| E-2 | `task.md` §3.1 写「今天的 orchestrator 是人 + shell 脚本」，与 `refact-fable.md` §3.9「orchestrator 必须是代码，不得是 agent 角色；人运行脚本是欠账不是角色」冲突 | kimi、cursor（独立） | 把欠账重命名为组件，下一轮会有人对着这个名字设计接口 | 裁决稿统一为「orchestrator = 确定性代码，人是触发通道」。按 §5 加分记两家 |
| E-3 | ① 期间追加 R4/R5，`rulings.md` 从 20 行变 30 行 | cursor（其取件自证对不上现状） | 各家引用了不同版本的同一份产物，「取件按 commit」在本轮被裁决方自己破坏 | 承认。今后轮次内产物变更须新开条目并在环节通知里公告版本 |
| E-4 | 裁决方用词汇 Jaccard 先判「cursor 与 fable 实质趋同」 | 裁决方自查（被三家的结构对照推翻） | 代理指标选错，差点把独立性观察值判反 | 本记录 A.1 已按结构对照重述；Jaccard 降为参考 |
| E-5 | `task.md` 中 `runtime` 一词三义（产品运行时 / 内核 Agent runtime / 登记表分组键） | fable | 与上一轮 supervisor 三套同名物同形——**本轮任务书自己犯了它要治的病** | 见 D-4 |
| E-6 | **§8-4 与 §8-7 自相矛盾** | 裁决方自查（由 cursor 的候选触发） | §8-4 把 OP-2 的内容冻成通过/不通过条件，§8-7 却邀请推翻 OP-2 并加分——成功攻击 OP-2 的候选会自动挂在 §8-4 上 | **不可由裁决方单方解决**，见 F-1 |

| E-7 | 本记录初稿把「四家推荐」写在基座理由之前 | 裁决方自查 | 协议「③ 裁决」明写「**票数不是依据**，多数推荐不构成选它的理由」——把票数放在最前正是它禁止的框定 | §B 已更正：依据只是三条可复核差异；排序表降为评优产物与观察值 |
| E-8 | 本记录初稿**没有协议要求的机器可读处置表** | 裁决方自查 | 协议「③ 裁决」规定 `disposition.md` 必须含三列固定表（`出处家 \| 条目 \| 裁定`，裁定取三值），**验收方由它算出**。初稿的 §G 用自由文本（「全额并入」「基座保留」），验收方算不出来——③ 实质未完成 | §H 已补表，§I 给出验收方计算并独立复算 |

**元观察**：本轮 `observations-opus.md` §G 记过「裁决方犯的错多于执行者」。②之后这条仍然成立：
E-1…E-8 八条全部是裁决方的，而五家候选的实质缺陷主要集中在 qwen 与 kimi 的两处样例。
差别在于——**这一次，六条里有四条是被参与方抓出来的**，不是裁决方自查。竞争评比在框架内的作用由此再获一个数据点。

---

## F. 必须由所有者裁的（H6）

### F-1 §8-4 与 §8-7 的矛盾

**事实**：`task.md` §8 第 4 条（已 H1 冻结）要求候选「出向**必含**展示哪个 Artifact 的哪个版本 /
渲染形式 / 人可编辑范围，入向**必含**三值 + amend 载荷」。
`task.md` §8 第 7 条同时要求对 OP-1/2/3 表态，§5 规定「**有理由地推翻，按加分记**」。
而 §8-4 的内容**就是 OP-2 的内容**。

**后果**：cursor 有理由地推翻了 OP-2（把 render 移出内核、入向四值），按 §8-7 应加分；
按 §8-4 字面则不满足。同一份候选在两条冻结判据下得到相反判定。

**裁决方的判断**：矛盾在冻结的判据本身，不在候选。且裁决方已在 D-2 采纳 cursor 的 render 主张——
即裁决稿本身也将不满足 §8-4 的字面。

**请所有者裁**（三选一，或另裁）：

| 选项 | 内容 | 方向 |
| --- | --- | --- |
| **F-1a（裁决方建议）** | 判定 §8-4 的「必含」约束**从属于** §8-7：给出等价或更强的结构化字段表 + 内核修订工作单元即算满足；render 的具体归属不在冻结范围 | 朝省事（放宽已冻结条件）——**须人确认** |
| F-1b | 维持 §8-4 字面：cursor 该条不满足，裁决稿也须把 render 放回内核绑定 | 朝严谨 |
| F-1c | 判定 §8-4 与 §8-7 均无效、本轮该维度不判 | 朝省事，且损失一条机械判据，裁决方不建议 |

**在 F-1 裁定之前，裁决稿的 D-2 部分标为「待定」，不进 ④ 异议的可争范围。**

---

## G. 吸收清单（并入基座 fable 的具体条目）

| # | 出自 | 主张 | 处置 |
| --- | --- | --- | --- |
| G-1 | luna | `TraceEnvelope`：契约 digest / 策略版本 / 身份 / 副作用摘要作为比较上下文；「同形但越权」反例 | **全额并入**。与基座 `provenance` 互补：provenance 管「这条边是否真发生」，信封管「发生时的授权上下文」 |
| G-2 | luna | E0–E4 证据等级 + `min(可见上限, 隔离强度, 验收独立性, 覆盖)`，任一未知即降级不取平均 | **全额并入**。与 `provenance` 统一：E0 = reported/inferred，E1–E4 = attested 的子档 |
| G-3 | luna | `legacy_resume`：历史 token 只证明 consumed，不得回填 approve | **全额并入**，替换 fable / cursor / qwen 三家的 synthetic approve 迁移 |
| G-4 | luna | Interaction v2 的 additive + version gate 迁移细案（双读期分指标、v1 活动归零后下线） | **全额并入**，五份中最工程化 |
| G-5 | luna | `editable_scope` 用 JSON Pointer / path glob 的机械表示 | **全额并入**，优于基座与 OP-2 的自然语言写法 |
| G-6 | luna | `AUTH-EFFECT` 不得直达成功终态 | 并入权力表行（与上一轮 D1 同构，写进行比写在叙述里稳） |
| G-7 | luna | bypass 分母取**外部 sink**，不能把未归因变更反向补造成正常 Task；允许 `UNKNOWN` | **并入为 Q4 主方案**；基座的 git 对账降为其中一个有覆盖边界的 sink |
| G-8 | cursor | S 层（schema）/ R 层（run）+ 投影 Π；权力表是 S 层不进轨迹四要素；**边必须进状态序列字段** | **全额并入**。这是对 OP-1 最精确的一处纠正：裁决方把静态约束塞进了动态轨迹 |
| G-9 | cursor | `amend.mode ∈ {patch, replace}` 可判字段（D-1 的落点） | 并入 |
| G-10 | cursor | render 归 Delivery / `client_context` | **待 F-1 裁定** |
| G-11 | cursor | 「轨迹不是内核对象」「绕过不是内核对象」防膨胀警告 | 并入。等效判据与绕过观测都必须声明自己是投影 / 观察事件 |
| G-12 | kimi | 比对规则四条：白名单制、取较粗一腿并**声明未比对项**、两边声明权威源、权限归因 `bootstrap-zero` 单列 | **全额并入**。与 G-8 合起来构成 OP-1 的可执行改写 |
| G-13 | kimi | `editable_scope` 是**入向拒收约束**，越界不消费令牌（落 `AT-07` 异键类），不是出向展示提示 | **全额并入** |
| G-14 | kimi | `response_state_version` 防 stale amend；amend 版本必须带 `supersedes` 链 | **全额并入** |
| G-15 | kimi | orchestrator = 确定性代码，人是触发通道 | **全额并入**（E-2 的落点） |
| G-16 | qwen | `interaction_class`：重载荷只绑 `APPROVAL_WITH_ARTIFACT`，轻量 INPUT 保持轻 schema | **全额并入**。五家唯一守住内核 `:180-181` 澄清纪律的 |
| G-17 | qwen | T0 开销用复合向量（任一维超标即不标 T0） | 并入，替换单数上界 |
| G-18 | fable | `provenance` 三值 + `power_row` 进轨迹条目；等效只在最低来源等级宣称；`attested` 计数进拆除条件 | **基座保留** |
| G-19 | fable | 粒度三字段四档；`tool.reported` 只作索引不作证据 | **基座保留** |
| G-20 | fable | H8 行（INPUT 类应答权与 amend 权限） | **基座保留**——补上上一轮 R3–R8 六次裁决无账本落点的洞 |
| G-21 | fable | 反例 3：`dispatch = manual` 执行者对运行时是净负担，与任务大小无关 | **基座保留**，四家评审一致认为是本轮最强反例 |

**不吸收**：qwen 的 §1.5.1 示意轨迹、fable = `process`、fable 可任 acceptor；kimi 样例中引自 `refact/*` 的
Attempt 段；cursor 的 H3/H4「不改边」；fable 的 H0 权力行；任何把「同意 OP 框架」当优点的表述。

---

## H. 机器可读处置表（协议「③ 裁决」要求；验收方由此算出）

三列固定，`裁定` ∈ {`接受`, `部分接受`, `拒绝`}。

| 出处家 | 条目 | 裁定 |
| --- | --- | --- |
| fable | 基座结构（对象层 / `dev.change` / 登记表 / 映射表 / 拆除条件） | 接受 |
| fable | 轨迹条目加 `provenance` + `power_row`；等效只在最低来源等级宣称 | 接受 |
| fable | 粒度三字段四档；`tool.reported` 只作索引 | 接受 |
| fable | 权力表 H8（INPUT 类应答权与 amend 权限） | 接受 |
| fable | 必答 Q 反例 3（`dispatch = manual` 执行者是净负担） | 部分接受 |
| fable | 权力表 H0 行 | 拒绝 |
| fable | 迁移「旧响应视为 `decision = approve`」 | 拒绝 |
| fable | 登记表 `ap.qwen` 的 `provider = "alibaba"`（推断值） | 拒绝 |
| fable | `orch.manual = 人 + 脚本` 的命名 | 拒绝 |
| luna | `TraceEnvelope`（契约 / 策略 / 身份 / 副作用摘要） | 接受 |
| luna | 证据等级 E0–E4 + `min()` 采信算法 | 接受 |
| luna | `legacy_resume`：历史 token 不得回填 approve | 接受 |
| luna | Interaction v2 的 additive + version gate 迁移细案 | 接受 |
| luna | `editable_scope` 用 JSON Pointer / path glob | 接受 |
| luna | `AUTH-EFFECT` 不得直达成功终态 | 接受 |
| luna | bypass 分母取外部 sink；允许 `UNKNOWN` | 接受 |
| luna | 对 OP-2 的「反对」框定 | 部分接受 |
| luna | 拆除条件 5「无命令入口者从可路由集合移除」 | 拒绝 |
| cursor | S 层 / R 层 + 投影 Π；权力表归 S 层；边进状态序列字段 | 接受 |
| cursor | `amend.mode ∈ {patch, replace}` 机械可判 | 接受 |
| cursor | `render` 归 Delivery / `client_context` | 接受 |
| cursor | 「轨迹 / 绕过 不是内核对象」防膨胀警告 | 接受 |
| cursor | 入向第四值 `replace` | 部分接受 |
| cursor | 权力表 H3/H4/H6「不改边」 | 拒绝 |
| cursor | Q1 用 `tier ∈ {T1,T2}` 作成本判据 | 拒绝 |
| cursor | Q1 新增布尔缺省 `false` | 拒绝 |
| kimi | 比对规则四条（白名单 / 取较粗腿并声明未比对 / 声明权威源 / 权限项单列） | 接受 |
| kimi | `editable_scope` 是入向拒收约束 | 接受 |
| kimi | `response_state_version` 防 stale；`supersedes` 链 | 接受 |
| kimi | orchestrator = 确定性代码，人是触发通道 | 接受 |
| kimi | §1.6 trace 样例（引用 `refact/*` 标签） | 拒绝 |
| kimi | 把 INPUT 类澄清与 amend 排除在权力表外 | 拒绝 |
| qwen | `interaction_class`：重载荷只绑 `APPROVAL_WITH_ARTIFACT` | 接受 |
| qwen | T0 开销复合向量（任一维超标即不标 T0） | 接受 |
| qwen | §1.5.1 轨迹样例（五份候选与 H2/⑤验收在账本上不存在） | 拒绝 |
| qwen | 登记表 fable = `process` | 拒绝 |
| qwen | 登记表 fable `roles_allowed` 含 `acceptor` | 拒绝 |
| qwen | §6.2 无权力表、无逐条介入清单 | 拒绝 |
| qwen | OP-1「采纳但补充静态检查」 | 拒绝 |

## I. 验收方的计算（协议「⑤ 验收 与 ⑥ 确认」）

规则依次适用，**名次与验收资格无关，判据是既得利益不是质量**：

| 步 | 规则 | 结果 |
| --- | --- | --- |
| 1 | 不得是裁决方 | 排除 `opus`（本轮亦不参赛） |
| 2 | 不得是基座作者 | 排除 `fable` |
| 3 | 剩下的家里取处置表中 `接受` + `部分接受` 条数最少的一家 | 见下表 |

| 家 | 接受 | 部分接受 | 拒绝 | **接受 + 部分接受** |
| --- | ---: | ---: | ---: | ---: |
| fable（基座，排除） | 4 | 1 | 4 | 5 |
| luna | 7 | 1 | 1 | 8 |
| cursor | 4 | 1 | 3 | 5 |
| kimi | 4 | 0 | 2 | 4 |
| **qwen** | **2** | **0** | **5** | **2** |

**验收方 = `qwen`**（2 条，唯一最小值，无并列，第 4 步不适用）。

复跑：本记录 §H 表按 `出处家` 分组计数即可。
**本指定不得事后更换**（协议同节）。

⚠ 值得点明：qwen 在评优中五家一致排末位，却因**既得利益最小**而成为验收方——
这正是协议「名次与验收资格无关」那句话的用意。它对这份裁决稿通过与否的动机最弱，
而它 ① 中被复核为全部成立的 12 处锚点，说明它有做取证核对的能力。

## J. ④ 异议的范围

被处置到的各家可就本记录提异议，落 `rounds/runtime/runtime-objection-<名>.md`。
**不受理**：F-1 待所有者裁的部分；已由三家以上独立复核且裁决方复跑确认的事实认定
（kimi 的 `refact/*` 锚轮、qwen 的候选虚构与 fable 粒度矛盾）——除非能给出**新的可复跑证据**。
