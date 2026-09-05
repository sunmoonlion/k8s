参与方：cursor｜worktree：/home/zym/worktrees/cursor/k8s｜HEAD：e3d24f1d

# 评审：轮次 runtime ① 候选集

> 利益冲突：评优方即 `cursor` 候选作者。这不是独立终审。把自己排第几都按同一套证据裁。
> 协议四块齐：A 自述 / B 冻结 / C 评优 / D 吸收。
> 取件一律 `git show <commit>:sunmoonai/docs/dev-plan/runtime-architecture.md`，不看工作区。

---

## A. 自述（cursor 候选 `13f3d52b`）

基座：无，新建文件。相对 `7e8464c2` 只新增共享最终路径同名文件，只读两份未改。

新增：P1（`DEV_ROUND` + 五家 Agent Profile + 拆除四条件）/ 等效两层 S·R + 投影 Π / P2 四值 `approve|reject|amend|replace` 且渲染出内核 / P3 三档 `tool|process|session` + R2 当身份粒度 / 必答 Q / OP 表态 / 同名物四点。

⚠ 未验证（候选 §9 已标）：R 层样例是重建；本轮回执强度为零；`session` 档看不见派发；cursor/fable 共用 harness 程度未知。

与基座无分歧（无基座）。

**故意没写、现在看是漏的**：

- 没把「人替 `dispatch=manual` 粘指令」收成可数行（fable 的 H0）。我把它写成「orchestrator 欠账，不进权力表」——分类对，但 Q3/Q4 因此少一个计数器。
- 没给轨迹条目加来源等级。只写了「重建 ⚠」，没有 fable 那种 `attested/reported/inferred` 计数，§8-3 的样例说服力薄一档。
- 没拆 `tool.reported`（执行者自报的工具流）。三档够机械判，细了才能处理 `codex exec --json`。
- 没写财务 Task Profile 字段、文件树、R0–R5（`task.md` §4 不受理，仍放弃）。

---

## B. 候选集冻结

路径一律 `sunmoonai/docs/dev-plan/runtime-architecture.md`。commit 用 ② 通知钉死的那笔（其后各分支只合入了通知，文件哈希未变）。

| 家 | worktree | 候选 commit | 行 | 字节 | sha256 | sha256[:16] |
| --- | --- | --- | --- | --- | --- | --- |
| luna | `/home/zym/worktrees/luna/k8s` | `1ddff5c2` | 544 | 32955 | `03785aabb3a631f68a3cd499eefdeb44b5a479b67a5fff38e9b88c4123fb49bf` | `03785aabb3a631f6` |
| kimi | `/home/zym/worktrees/kimi/k8s` | `29b4f804` | 538 | 39376 | `f0226bffd75170854c364f26dde68791d7d31bb33693dd0aca8d0ec075dc4544` | `f0226bffd7517085` |
| cursor | `/home/zym/worktrees/cursor/k8s` | `13f3d52b` | 586 | 38613 | `5ba7ce8b14775aeb60da7af146dc8f2ff1ce2436dfded5cd18e62b216ea8be76` | `5ba7ce8b14775aeb` |
| fable | `/home/zym/worktrees/fable/k8s` | `f053bd84` | 646 | 59897 | `b9bd7800cdcbcb059967abd2e43fdf97e7954249fe5e2c1e89db344279a30276` | `b9bd7800cdcbcb05` |
| qwen | `/home/zym/worktrees/qwen/k8s` | `1ae5b420` | 441 | 21202 | `49380ab0427d8ad8904fc47522c8a1f8e2528912a8d82fa22cffd2c911ff2291` | `49380ab0427d8ad8` |

复跑：`git show <commit>:sunmoonai/docs/dev-plan/runtime-architecture.md | sha256sum`。
与 `runtime-call-②.md`「对象事实」表逐列一致。五份首行身份自证均与目录名一致。

禁词机械扫（`开发 Profile|产品 Profile|Profile A|Profile B|两个 Profile|kind\s*=\s*"human"`）五份皆零命中。

---

## C. 评优

### C.0 独立性观察（cursor × fable）

`task.md` §6.2.1：两组按 `runtime` 字面分开，同厂相关性未验证。本轮要取值。

**同构（不只是题目逼出来的五家公约）**：

| 切分 | cursor `13f3d52b` | fable `f053bd84` |
| --- | --- | --- |
| OP-1 | S/R 两层 + 投影 Π；手工轨迹是重建不能当机械验收 | 轨迹条目加 `provenance`；等效只在最低来源等级上宣称 |
| P3 第三档 | `session`：无 argv / 无退出码 / 只见 fs 前后差 | `fs-only`：同一句话 |
| Q4 | 账本看不见绕过，另找采样面并声明覆盖 | 账本看不见，对账底座（git） |
| R2 | 与 `process` 自报同类，author 不采信 | principal 也有粒度，`channel_grade=shared-credential` |

**不同（密度与独有主张，不是措辞）**：fable 有 H0/H8、`tool.reported`、`harness` 改名、23 行带计数的样例、出向 `options[]`/`evidence_grade`、现场 uid_map 取证。cursor 有 `replace` 第四值、渲染出内核进 Delivery、边必须进状态序列字段（D1 类漏检）。

结论：**论证切分平行，产物密度不平行。**不足以证明共用 harness 内核——luna/kimi 同 `codex-cli`，稿子纹理差得比 cursor/fable 更大（E 阶形式系统 vs 协议改写规则）。观察值记：同厂这对在「怎么改写 OP-1/Q4/第三档」上的相关度，高于「同 harness」的 luna–kimi。`auto` 若把 CLI 路由到 Claude 族，这条观察仍成立、独立性归零的风险另计。

### C.1 逐家：§8 / 可复核指摘 / OP / Q2

#### luna `1ddff5c2`

| §8 | 判 | 位置 |
| --- | --- | --- |
| 1 一个运行时 | 过 | `dev.change`；五家在 4.2 |
| 2 人非执行者 | 过 | 1.3 `AUTH-*` 表，每行有边 |
| 3 等效+样例 | 过，有瑕 | 2.1 schema + 2.2；状态 ⊆ 内核；H1 恢复边见下 |
| 4 Interaction | 过 | 3.1–3.3；显式内核修订 |
| 5 粒度 | 过 | `tool_call\|process\|artifact_delta`；五家填完 |
| 6 必答 Q | 过 | 5.2 两则反例 |
| 7 OP | 过 | 三项皆「改写」+理由 |
| 8 锚定 | 过，有一处滑 | 见指摘 |
| 9 只读 | 过 | 文首声明；本评审未对 `7e8464c2` 做这两文件的 diff（候选分支相对基线应无改） |
| 10 身份 | 过 | 首行 |

**可复核指摘 1（边）**：样例 seq5 `WAITING`（H1）→ seq6 `QUEUED`（luna:214-215）。H1 冻的是工单契约，属验证阶段；内核「WAITING 与 Interaction」写验证阶段等待回 `VALIDATING`（`request-lifecycle.md@70a7dd50:269`）。`WAITING → QUEUED` 是执行阶段边。luna 自己 1.3 的 `AUTH-CONTRACT` 用对了 `WAITING → VALIDATING`，样例没用。只查状态词集合抓不到（与上一轮 D1 同形）。

**可复核指摘 2（引用）**：luna:218「相邻边全部属于 `:205-209` 的合法边」。`:205-209` 是状态机 ASCII 图的头几行，合法转换列表在 `:222-228`。可复跑：`git show 70a7dd50:sunmoonai/docs/dev-plan/working/request-lifecycle.md | sed -n '205,228p'`。

**强项**：`TraceEnvelope`（契约/策略/副作用摘要）挡住「同形越权」假等效，这是 OP-1 改写里最干净的一条。E0–E4 采信算法可执行。`AUTH-EFFECT` 明确不得直达成功终态。2.2 评审文件的 sha16 抽查成立：`review-refact-fable-cursor.md` → `77df40f4c8aa1622` / 274 行 / 17607 字节，与表一致。拆除七条可点名。`UNVERIFIED` 身份写进 Interaction 样例，不粉饰。

**OP**：三项改写都有独立理由（信封、载荷进 Artifact、Q4 独立 sink）。加分。

**Q2**：报错术语（不落盘）+ formatter 已覆盖的空白。成立；第二条把「不该叫 agent」和「不该走运行时」叠在一起，略混，但不至于未答。

#### kimi `29b4f804`

| §8 | 判 | 位置 |
| --- | --- | --- |
| 1 | 过 | `DEV`；名单 1.3，表在 §6 |
| 2 | 过 | 7.2 七行边+行 |
| 3 | **伤** | 1.6 样例锚错轮，见指摘 |
| 4 | 过 | 2.2–2.4；内核修订 |
| 5 | 过 | 三档含 `fs_diff_only`；五家填完 |
| 6 | 过 | 4.2 两则反例 |
| 7 | 过 | 改写 / 改写含反对 / 采纳但改预设 |
| 8 | 伤一处 | `:388` 指错 |
| 9 | 过 | |
| 10 | 过 | |

**可复核指摘（§8-3 / §8-8）**：1.6 把 `refact/*` 标签当 `refact-fable` 的 Attempt 产物：

```text
output_artifacts: ["refact/luna @ e41e646a"]   # kimi:191
evidence: "五家候选 tags refact/{luna,kimi,cursor,qwen,...}"  # kimi:187
```

可复跑：`git for-each-ref 'refs/tags/refact/*' --format='%(refname:short) %(objectname:short) %(creatordate:short)'`
→ `refact/luna e41e646a 2026-09-04`，是**上一轮 `refact`** 的标签，不是 `7e8464c2` 上的 `rounds/refact-fable/`。
`refact-fable` 没有五家并行候选 tag。样例因此不是「用该轮真实产物导出」。

另：kimi:271「`input_artifact_versions` 在 `:388` 区域」。该字段在 Attempt 记录块 `:326`；`:388` 是 `F-EXEC-08`（Plan 不得为过 `PLANNED` 造空计划）。

**强项**：OP-1 四条比对规则（白名单、取较粗腿并声明未比对、两边声明权威源、权限归因 bootstrap-zero 单列）是五家里最能落地成脚本的。`editable_scope` 作**入向拒收约束**而不是展示提示（5.2），比 OP-2 原文硬，成立。`response_state_version` 防 stale amend。orchestrator 同名物（task.md「人+脚本」vs 必须是代码）指得准。

**OP**：三条改写都有机制级理由。加分。锚错轮把 §8-3 从「可执行」降成「规则对、样例错」。

**Q2**：一次性提问（6 个落盘 vs 0）+ 目标未定的探索。成立；探索那则还点出 `:297` 会堆短命 Task，比「贵」多走一步。

#### cursor `13f3d52b`（自己）

| §8 | 判 | 位置 |
| --- | --- | --- |
| 1 | 过 | `DEV_ROUND`；1.3 五家 |
| 2 | 过 | 3.5 表；粘贴指令不进权力表 |
| 3 | 过，薄 | §4 重建样例；状态 ⊆ 内核；明示非观测 |
| 4 | 过 | 2.2 四值 + 2.5 修订单元 |
| 5 | 过 | 三档；五家填完 |
| 6 | 过 | 5.2 笔误反例 |
| 7 | 过 | 改写 / 改写 / 部分反对 |
| 8 | 过 | 内核行号多数对 |
| 9 | 过 | |
| 10 | 过 | |

**可复核指摘（对自己，与评别家同强度）**：

1. §4 在 11:30–12:40 标「`VALIDATING`/`RUNNING` 含糊」（cursor:424-427）。这是诚实，也是 §8-3 没做完：同一段历史 fable 用 23 行拆开了，luna 用 GAP 标了，我停在含糊。机械上状态词仍 ⊆ 内核，质量上样例弱于前两家。
2. 与 fable 的 OP-1/P3/Q4 切分平行（C.0）。① 隔离下各自写成，但作为观察值必须记——评优时不能把「同一刀」数两次。
3. 放弃了 H0。3.5 把手工投喂排除出权力表是对的（不是批准），但因此 T0 上界数不到「打开 GUI + 跑身份 + 粘指令」。fable 5.2 反例 3 证明这条计数漏了会漏掉一类结构性更贵。

**强项（按评别家的尺子）**：`replace` 与 `amend` 对下一 Attempt 输入不同，R3「第四种」在我的样例里标成 `replace` 而不是硬塞进 `amend`——这和 fable「血缘表达替代、不加第四值」是真分歧，不是措辞。渲染形式出内核（`:140` `client_context` 已在）避免 UI 改动变规范修订。D1 教训写进轨迹字段（每步是边不是点）。

**OP**：三项有理由改写。加分口径与别家同；不因「也改写了」加第二分。

**Q2**：T0 包内改笔误。成立，与 qwen/fable 第一则同类。没有第二则，也没有「manual 执行者任何任务都更贵」。

#### fable `f053bd84`

| §8 | 判 | 位置 |
| --- | --- | --- |
| 1 | 过 | `dev.change`；2.3 五家（+ opus 不参赛） |
| 2 | 过 | 2.4 两张表；H0 声明「不是权力」 |
| 3 | 过，最厚 | 2.7–2.8；23 行；读数 2/15/6 |
| 4 | 过 | 3.2–3.5；`options[]`、鉴别响应者 |
| 5 | 过 | 四档；五家填完；现场取证 |
| 6 | 过 | 5.2 三则反例 |
| 7 | 过 | 改写 / 改写 / 部分采纳 |
| 8 | 过 | inbox / rulings / 内核行；codex 源码锚见下 |
| 9 | 过 | |
| 10 | 过 | |

**可复核指摘**：

1. H0 进权力表又写「无强制点、不是权力」（fable:180）。表的纪律是「没有强制点的行不许进」（`refact-fable.md` 3.3）。H0 作为**可数欠账**成立，放进权力表会让「行 = 批准」这条坏掉。应另立 `dispatch_event`，不占 H 行。九行仍 ≤10，形状能过，概念混。
2. 2.3 `ap.qwen` `provider = "alibaba"` 标了推断。`task.md` §6.2.1 该栏是「—」。推断不该进登记表取值，应留空。⚠ 有标，未装成能力。
3. `~/repo/codex/codex-rs/exec/src/cli.rs:60`（fable:40,416）——本评审在 cursor worktree **未打开该文件核对行号**（仓外路径，本评审覆盖声明：没复跑）。当作「声称可达」而非已验。即使行号对，它证明的是 CLI 能吐 JSONL，fable 自己说了这是自报（`tool.reported`），没有拿休眠代码当 `tool.enforced`。

**强项**：2.8 是唯一把「手工看起来在跑」量化的样例——`attested` 只有终态 commit 与 R1 行，且身份仍 `reported`。这直接支撑 OP-1 改写，也支撑拆除条件「服务态 attested 计数 ≥ 手工态」。H8 把上一轮 R3–R8 从「对话里的点头」收回 Interaction，inbox-owner.md:13 / :41 对得上。`tool.enforced` vs `tool.reported` 解开 task.md 表把「能看 / 能拦 / 谁供沙箱」绑死的一列。`harness` 改名（6.4）是本任务书自造同名物里最干净的一刀。反例 3（对 `dispatch=manual` 的任何分发）是五家唯一的结构性反例，不只是「小任务」。利益申报（§1）让「幸存清单」可折算。

**OP**：改写密度最高。`replace` 用血缘不第四值——与 cursor 真对立，见 D。加分。

**Q2**：三则都成立；第 3 则最强。

#### qwen `1ae5b420`

| §8 | 判 | 位置 |
| --- | --- | --- |
| 1 | 过 | `DEVELOPMENT`；1.3 五家 |
| 2 | **薄** | 6.2 一句「映射到 H1–H7」，无逐条表（§8-2「逐条列表」） |
| 3 | **伤** | 1.5.1 是模板，且套错轮的形状 |
| 4 | 过 | 2.2–2.5；有修订单元 |
| 5 | **伤** | 表内 fable=`process`，与 3.5「连 argv 都没有」自相矛盾 |
| 6 | 过 | 4.2 README 笔误 |
| 7 | 过 | 采纳补充 / **反对** / 改写第 3 问 |
| 8 | 过得过 | 有 `file:line`；样例本身无产物哈希 |
| 9 | 过 | |
| 10 | 过 | |

**可复核指摘 1（§8-3）**：1.5.1 写出 `candidate-luna@v1` … `candidate-qwen@v1` 五份并行候选，当作 `refact-fable` 的轨迹。`7e8464c2` 上 `rounds/refact-fable/` 只有一份方案 + 九份评审 + rulings，没有五家候选。五家并行是 `refact` 轮（`refact/*` 标签，2026-09-04）。可复跑：`git ls-tree --name-only 7e8464c2 -- sunmoonai/docs/dev-plan/rounds/refact-fable/`。

**可复核指摘 2（§8-5）**：登记表（qwen:87）`fable … observability_granularity = process`，同时 3.5 写「看不到 argv / stdin/stdout」。`task.md:360` 把「连 argv 都没有」单列为一类。表填了（机械非空），填错了。同表 `roles_allowed` 含 `acceptor`，与 `task.md` §9「fable 不得担任验收」冲突。

**强项**：OP-2 **反对**是五家唯一把「重载荷加给全部 Interaction」打回去的——引用内核 `:180-181`「只有歧义实质改变结果才澄清」，建议 `interaction_class`，重 schema 限 `APPROVAL_WITH_ARTIFACT`。这条有理由，按加分记。稿子短、覆盖题面，不注水。

**Q2**：README 笔误。成立，与多家同类；贵在供给 + H5，说得清。

**OP-1** 几乎原样采纳（「须补充静态检查」不是对四要素的攻击）。不计优点。

### C.2 排序与基座

**fable > luna > cursor > kimi > qwen**

| 名次 | 家 | 一句话 |
| --- | --- | --- |
| 1 | fable | §8-3 样例变成了可计数的缺口清单；P3 有现场与第四档；H8/H0（计数）补上真实漏项 |
| 2 | luna | 形式最能直接变成 schema/算法；信封与 E 阶独立成立；H1 恢复边与 `:205-209` 引用要修 |
| 3 | cursor | 四值与「渲染出内核」是真分歧；样例薄；与基座候选切分平行，不能靠同一刀排前 |
| 4 | kimi | 比对规则优于我的 Π 散文，但样例锚到错误轮次，§8-3 实质未完成 |
| 5 | qwen | 题面覆盖 + OP-2 反对值得留；表与样例两处事实错，§8-2 缺逐条 |

**基座选 fable。**理由不是篇幅，是它单独证明了 OP-1 原文会把一条几乎全是 `reported` 的轨迹判「全等」——这是本轮等效判据能不能用的先决条件。luna 的信封补在 fable 的来源等级旁边，不替代。

不选自己：样例薄、H0 计数缺、与基座切分平行。把自己排第一会是「同一把刀数两次」。

---

## D. 值得吸收（基座 = fable，下列全部来自他家或与基座的对立项）

1. **luna / TraceEnvelope**（luna 2.1）：四序列相同仍可能越权发布。基座的 `provenance` 管「这条边是不是真的发生过」，信封管「发生时的契约/策略/副作用」。两件，都要。
2. **luna / E0–E4**（luna 4.3）：基座 `attested|reported|inferred` 是来源；E 阶是采信上限。合成：`grade = min(来源, AgentProfile 可见上限, isolation 实值)`。
3. **luna / AUTH-EFFECT 不得直达 SUCCEEDED**（luna 1.3）：与 D1 同构，写进权力表行比只写在叙述里稳。
4. **kimi / 比对取较粗腿 + 声明未比对**（kimi 1.5 规则 2）：基座「最低来源等级」管真伪，这条管粒度差被误读成行为差。脚本先投影再比。
5. **kimi / editable_scope 入向拒收**（kimi 5.2）：基座已要求 `amend.target ⊆ editable`。吸收「越界 = 不消费令牌，落 AT-07 异键类」，不要只当展示字段。
6. **kimi / response_state_version stale**（kimi 2.2）：amend 到达时 Task 已前进则拒。基座有 `expected_state_version`，缺「响应侧再钉一次」的显式。
7. **kimi / orchestrator 同名物**（kimi 1.4）：「人+脚本」不得叫 orchestrator。与基座 2.1「必须是代码」合并，改 task.md 用语的那句写进修订单元（不改冻结任务书，写处置）。
8. **cursor / `replace` vs 血缘**（cursor 2.2 ↔ fable 3.3）：真对立。建议基座保留三值，但 `amend.base_version` 空/不接 agent 版必须是一等公民（fable 已有），并在轨迹里能机械区分「补丁」与「整份替代」——不必第四枚举，必须有可判字段。cursor 的 R3 样例（采纳第四种）应用这个字段标，不能标成普通 `approve`。
9. **cursor / 渲染出内核**（cursor 2.2）：`render` 放 Delivery / `client_context`。基座 3.2 把 `render` 放在 Interaction 绑定。吸收：绑定只留 `artifact_ref`；`render` 降为投影，改 UI 不改内核版本。
10. **qwen / `interaction_class`**（qwen 5.2）：重载荷限 `APPROVAL_WITH_ARTIFACT`（及带 Artifact 的 INPUT）。否则问一个缺失参数也要走版本+amend。这是五家唯一成立的「反对 OP-2 通用扩展」。基座 3.2 的全字段表按类切成必填/可空。
11. **qwen 不吸收**：1.5.1 模板、fable=`process`、fable 可任 acceptor。

不吸收：INTAKE 叙事重复、各家 Task Profile 的不同 id 字符串（`dev.change` / `DEV` / `DEV_ROUND` / `DEVELOPMENT`）——基座用 `dev.change`，其余作别名登记一行即可，不要并存四个真源。

---

## 覆盖与盲区

**查了**：五份候选全文（通知所钉 commit）；`70a7dd50` 状态机与 Interaction 段；`7e8464c2` 的 `rounds/refact-fable/` 目录与一份评审哈希；`refact/*` 标签日期；本轮 `inbox-owner.md` 行 13/41；禁词扫。

**没查**：`~/repo/codex` 行号；各家候选分支相对 `7e8464c2` 的完整 diff（只核了只读两文件在通知承诺下不应被改）；fable 是否在 ① 读过他家——信其自陈。

**盲区**：我是 cursor 作者，C.1 对自己的「强项」可能偏短、对平行切分可能偏长。基座没选自己。kimi 的规则我评为优于自己的 Π，但因锚错轮排后——若裁决方认为「规则对、样例可另补」可以上调 kimi，不应上调我。
