# 开发框架的历史记录

> ADR 依据 / 审计记录｜S2/S4/S6 回溯。按证据对象分历史取值、旧路线、吸收审计和旧版上下文；当前禁令已在 TLD，通用覆盖义务在验证规程，没有随记录一起退役。
>
> 2026-09-14 按 [dev-plan-architecture.md](../dev-plan-architecture.md) 第八节从 `1d0adde3` 迁入。每节前的 `<!-- Ixx-xxx -->` 是安置表 ID，冻结原文用 architecture 的 `show` 取。
>
> 本文件是冻结记录，只追加更正、不改原文。正文里未注文件名的 `§N` 指冻结基线 `baa28858` 时 `agent-dev-guide.md` 的节号，今天的位置查 architecture 第八节。

## 历史取值与实例

五家登记、实际介入及轨迹原读数带日期保留；重构不把旧实验改成新实验。

<!-- I02-027 -->
### 五家 Agent Profile 的历史取值示例

⚠ **本表是「登记表长什么样」的实例，不是可自动路由的名单**（§2.3 已立：静态登记集合与
自动路由候选集分开）。带 ⚠ 的格是**未核值**，不得据它反推能力。

```text
[ap.luna]
harness = "codex-cli"    provider = "openai"     model = "gpt-5.6"   model_pinned = false  # ⚠ argv 未钉 --model
dispatch = "argv"        observability = "process"     # 可升 tool.reported：codex exec --json
enforcement = "outer-only"   sandbox = "self"    workspace_isolation = "convention"
roles_allowed = ["proposer","reviewer","objector","acceptor"]   supports = ["dev.change/1"]

[ap.kimi]
harness = "codex-cli"    provider = "moonshot"   model = "kimi-k3"   model_pinned = false  # ⚠ 同上
dispatch = "argv"        observability = "process"   enforcement = "outer-only"   sandbox = "self"
workspace_isolation = "convention"

[ap.cursor]
harness = "cursor-agent" provider = "xai"        model = "cursor-grok-4.6-high"   model_pinned = true
dispatch = "argv"        observability = "process"   enforcement = "outer-only"   sandbox = "self"

[ap.fable]
harness = "cursor-app"   provider = "anthropic"  model = "claude-fable-5.1"  model_pinned = false  # ⚠ GUI 内选择，不可机械核验
dispatch = "manual"      # 无 argv；分发由人代行，记 dispatch_event 而非权力表行
observability = "fs-only"    enforcement = "outer-only"   sandbox = "self"
roles_allowed = ["proposer","reviewer","objector"]      # 不得任 acceptor

[ap.qwen]
harness = "qoder"        provider = ""           model = ""   model_pinned = false  # ⚠ 留空：来源表该栏为「—」，推断不得进登记表取值
dispatch = "argv"        observability = "process"   enforcement = "outer-only"   sandbox = "self"

[ap.opus]                # 裁决方，不参赛
harness = "claude-code"  provider = "anthropic"  dispatch = "argv"   observability = "process"
enforcement = "outer-only"   sandbox = "self"    roles_allowed = ["arbiter","publisher"]

[principal.owner]        # 人：不是执行者，无 harness / dispatch / observability
channel = "inbox+commit"          channel_grade = "shared-credential"   # 与 agent 同机同身份，证据强度零
```

**读数三条：**

1. 四家 `process`（可升 `tool.reported`），**fable 为 `fs-only`**——`dispatch = manual`，
   没有进程句柄就没有 stdio；
2. **六家 `enforcement` 全为 `outer-only`，`sandbox` 全为 `self`，`workspace_isolation` 全为
   `convention`**；
3. ⚠ **目前没有一家是 `tool.enforced`**——那是 SDK 腿建成之后才会出现的取值（§2.9）。

⚠ **登记表的机械非空不等于填对。**真实案例：一份候选把 fable 填成 `process`，
而同一份的正文又写「看不到 argv / stdio」——**机械判「无空缺」会通过，事实是填错的**。
校验规则：`dispatch = manual` 的执行者，`observability` **只能**是 `fs-only`，脚本不许填高。

⚠ `[principal.owner]` 的 `channel_grade = shared-credential` 是 §4.4 那句
「人类确认只能标 `reported`」在登记表上的落点——**通道换掉之前，
轨迹里所有 `power_row ≠ —` 的条目 `response_grade` 一律 `reported`**。

**`codex exec --json` 的可升级依据**（本文复跑于 Codex `7d6f808b`）：
`codex-rs/exec/src/cli.rs:58-64` 的 `--json` 参数注释为 “Print events to stdout as JSONL”；
`codex-rs/exec/src/exec_events.rs:115` `CommandExecution(CommandExecutionItem)`、
`:118` `FileChange(FileChangeItem)`（结构体在 `:161` 与 `:186`）。
⚠ **可见性到工具调用级，但吐的是执行者自报**——运行时既拦不住（拦截点在进程内）也验不了，
**强制点仍在进程外**。所以它只能升到 `tool.reported`，升不到 `tool.enforced`（§5.1）。

<!-- I02-062 -->
### 本轮已发生介入的实例级清单

⚠ **类型级权力表（§4.2）不能代替实例级清单。**这一条是上一轮 ⑤ 验收 `C-1` 明确抓出来的
缺项——**没有实例，就无法验证权力表是否真的被用过、被正确地用过**。

下表是 `runtime` 轮实际发生的介入，逐条对应唯一状态机的边与权力表的行：

| # | 介入（可复核出处） | 状态机的边 | 权力行 |
| --- | --- | --- | --- |
| 1 | 所有者提出四条推翻性判断 | **不是任何边**：前一 Task 已 `SUCCEEDED`，终态不可转出 → 建新 Task 并记 `supersedes` | —（内核规则，非权力） |
| 2 | 解冻上一轮三处冻结物 | `WAITING(APPROVAL) → VALIDATING` | **H6** |
| 3 | 冻结本轮验收十条并签发 | `WAITING(APPROVAL) → VALIDATING → QUEUED` | **H1** ⚠ 与 H2 合并于一次触点，与「T2 = 2 个触点」不符，登记为观察值 |
| 4 | 裁定本轮协议版本 | `WAITING(INPUT) → VALIDATING` | **H8**（approve option） |
| 5 | 接受零强度回执形态，继续 bootstrap 例外 | 同上 | **H3**（更省事方向） |
| 6 | 固定投喂指令加指路补丁 | 同上 | **H8** |
| 7 | 判别命令硬化、删除产品映射句 | **不占权力行**：中性偏严谨，裁决方自裁 | —（记裁定行） |
| 8 | 裁定某条从属于另一条并签发 | `WAITING(APPROVAL) → QUEUED` | **H6** |
| 9 | ①②④⑤ 对四家 CLI 的手工投喂 | 各家 Attempt `CREATED → RUNNING`；Task `QUEUED → RUNNING` | —（`dispatch_event{mode=manual}` ×N） |
| 10 | 对 `dispatch = manual` 执行者的手工投喂 | 同上 | —（`dispatch_event`，`observability = fs-only`） |
| 11 | 所有者执行发布脚本把环节产物写入主线（本轮 5 次） | Side Effect：写共享路径 | ⚠ **未经 H5 门**——见下 |
| 12 | ⑥ 确认 | `WAITING(APPROVAL) → QUEUED` → publisher `RUNNING → COMPLETED` → Task `RUNNING → SUCCEEDED` | **H5** |

⚠ **第 1 行「没有边」是正确答案，不是缺项**——它恰好说明「推翻一个已完成的 Task」
在内核里的落点是 `supersedes` 建新 Task，**不是 Interaction**。

⚠ **第 11 行是一个真缺口，如实登记。**五次执行发布脚本、把环节产物写入主线，
都是**写共享路径的 Side Effect**，按权力表属 H5 管辖，但实际未经 H5 门——
它们被当作常规动作处理了。**原因是 H5 只对准「⑦ 发布最终稿」，没有区分最终稿发布与
轮内产物发布**。两者不可逆性不同（后者可 revert，前者进交付面），但**都写主线**。
处置见 §7.4 第 4 行（`H5-final` / `H5-round` 拆分），**本文不擅自改权力表行数**。

<!-- I02-076 -->
### 轨迹实测：23 条里 2 条 attested

§5.3 引用过这个读数，**这里是支撑它的表**——⚠ **只留读数不留表，就是「结论在、证据不在」**。

数据来源可复跑（⚠ **必须钉 commit**：不钉 ref 时会在包含后续发布点的分支上多出一行）：

```bash
git log <round-commit> --format='%h %ad %an' --date=iso -- <最终稿路径> <该轮目录>
git ls-tree -r --name-only <round-commit> -- <该轮目录>
```

| seq | 层 | 边 | actor | 权力行 | provenance |
| --- | --- | --- | --- | --- | --- |
| 1 | task | — → `RECEIVED` | owner | — | reported（无工单文件） |
| 2 | task | `RECEIVED → VALIDATING → QUEUED` | orchestrator | **H1/H2 缺** | **inferred**（无工单、无冻结验收条） |
| 3 | task | `QUEUED → RUNNING` | 执行者 | —（`dispatch_event`） | reported |
| 4 | attempt | A1 `CREATED → RUNNING → COMPLETED` | 执行者 | — | reported（产出 v0，**无 commit**） |
| 5,8,13,16,19,21 | artifact | v0→v1→…→v6 | claimed / **attested none** | — | reported（六个版本**零 commit**） |
| 6,7 | attempt | A2/A3 reviewer `COMPLETED` | — | — | reported（**产物未归档**） |
| 9,14,17 | attempt | A4–A6、A7–A11 `COMPLETED` | — | — | **inferred**（由文件存在性推出） |
| 10,11,15,18 | interaction | request → approve / **reject** | owner | **H8** | reported（同 commit、同身份） |
| 12 | task | `RUNNING → WAITING(INPUT) → QUEUED → RUNNING` | orchestrator | H8 | **inferred**（账本无边） |
| 20 | attempt | A12 `COMPLETED` | — | — | reported（**无产物**） |
| 22 | interaction | R1 冻结 → approve | owner | **H1** | **attested**（存在）/ reported（身份） |
| 23 | task | `RUNNING → WAITING(APPROVAL) → QUEUED → RUNNING → SUCCEEDED` | publisher | H1+H5 | **attested**（终态）/ inferred（中间边） |

**读数**：23 条里 `attested` **2** 条（且身份都不 attested），`reported` 15 条，`inferred` 6 条；
Artifact 六个版本**零 commit**；两个 reviewer Attempt **有事件无产物**；
H1 与 H5 由同一 commit 承担，**账本分不开**；`VALIDATING` 阶段**没有任何契约产物**。

这条轨迹与「按 `dev.change/1` 跑一遍 T2」的目标轨迹**在边上对得上**，
但**只能在 `reported` 等级上宣称等效**（§5.3 规则 4）。
这就是「手工模式看起来在跑、实际没有可搬运的形状」的账本版。

**对照组**：另一轮的整合分支有 **28 条**逐主张提交，③④⑤ 每条处置各占一个 commit——
同一 Task Profile、同一 orchestrator 实现，`attested` 条目**数量级不同**。
⚠ **差别不在载体，在纪律是否落成动作。**

**样例的引用纪律（两条，对应两种真实失败形态，防法不同、不可互相替代）：**

1. ⚠ **每个引用对象须先核验其属于所声明的那一轮。**引用真实存在、哈希可验、
   但**属于另一轮**的对象，叫**张冠李戴**——只查「对象是否存在」抓不到，
   必须查「**属于哪一轮**」；
2. ⚠ **无 ⚠ 声明的样例条目一律按「已核验」读，因此凭空构造即为假证据。**
   另一种失败是**把本轮形状倒灌进历史**——写出账本上根本不存在的对象
   （如「五份并行候选」「验收产物」）而不作任何声明。前一条防法查不到它：
   **对象压根不存在，「属于哪一轮」无从查起**，只能靠「**无声明即假**」。

## 旧路线及当时进度

现行 guide 不采用为现行路线的 R0–R5/S1 表与当时进度一起保存；不删除取证、不推断所有技术任务都已完成。

<!-- I07-005 -->
### 阶段〇 · 开发框架自身的实施路线（R0–R5）

> 迁自 `refact-fable.md @ 7e8464c2` §6。**每轮一个工单，前置不可跳**；档位按 `round-protocol.md` 判据自判。
> 进度与卡点见 [`handoff.md`](../handoff.md)（分工：状态叙述不写在本文件）。
> ⚠ 取证给 S1 加了一条本表未写的前置：**所有者需要一个 agent 够不着的本地 shell**（Cursor / Qoder 均 Remote 连入 VM）。
> ⚠ H5 未区分「最终稿发布」与「轮内产物发布」，见 `rounds/runtime/runtime-disposition.md` §L.1。

每轮一个工单，前置不可跳。档位按 round-protocol 判据自判，**本路线不含任何降档**。

| # | 轮 | 档 | 产物 | 前置 | 机械验收判据 |
| --- | --- | --- | --- | --- | --- |
| R0 | 修 `protocol-v2` 的脚本↔协议不一致（命名、`--stage`、退出码）——**只改脚本，不改协议正文**。**由 opus 直接修，不走轮次** | **bootstrap** | 合并 `protocol-v2` | 无 | 新建空 `rounds/_smoke/` 按协议字面写 `round.md`，`round-status.py` 能解析且判 ① 未开始 |
| R0′ | 往 `round-protocol.md` 补「机器可读块」一节（`round.md` 的 toml 块进协议）。**所有者裁定 2026-09-05：这是改协议，按 T2 开轮**（§7-12 已决） | **T2** | `round-protocol.md` 一节 | R0 | 协议正文与 `round.md` 字段表一一对应；`round-status.py` 解析规则以协议为准，脚本单测覆盖每个字段 |
| S1 | **边界 spike**（`runtime-architecture.md` §4.4「三道边界」与 §4.6「principal 通道」）：① 建回执仓、建候选仓；② VM 换三把 key（候选仓读写、主仓只读、回执仓只读），撤销原 `id_rsa`；③ 所有者在 Windows 提交两份测试回执（`[H5]` 含 `acceptance`、`[H3]` 含 `ruling_sha256`），用带口令 key 推；④ 首版 `check-no-owner-creds.sh`；⑤ 按 `runtime-architecture.md` §4.7「取证纪律与当前事实」在宿主 shell 重跑取证 | **bootstrap**（可逆、可丢弃） | `rounds/_spike-sign/` 留痕 | **§8 判据已冻结**（冻结判据 ≠ 判据已满足——qoder C3 的循环不存在；`runtime-architecture.md` §4.4 随之冻结） | ⓪ 回执仓与候选仓建成，VM 身份对**主仓与回执仓** `git push --dry-run` 均被拒（配置导出留痕）；VM 身份对候选仓 push 成功；两份测试回执 `round-status.py` 判成立（签名 ∈ 在线公钥集、schema 合法、`acceptance` 集合完整 / `ruling_sha256` 匹配）；用 VM 上未登记的 key 签一份回执推候选仓再伪装路径，判不成立；`check-no-owner-creds.sh` 零命中；断网重跑判未确认且退出码为「查询失败」；取证栏每行附 `hostname; id; cat /proc/self/uid_map` 输出 |
| R1 | 权力表全表回执仓锚定 + 收件箱字段分级 + 回执内容门；`round-status.py` 读回执仓 yaml 并在线验签、状态推导输出边并按 `state-machine.toml` 校验；T0 两道门；`check-policy.py`；orchestrator 写 `events.jsonl` | **T2**（权威层、不可逆） | `authority.md`、`policies/tier-defaults.toml` 首版（所有者签 `policy/1`）、`policies/state-machine.toml`、`scripts/check-policy.py`、`scripts/gates/`、脚本改动 | R0、S1、原文 §3.1.1 映射表（已由 `runtime-architecture.md` §2.5 取代）冻结 | `round-status.py --round refact` 对历史轮次输出唯一状态机的词与合法边；对 S1 测试回执判 H5 / H3 成立、对缺 `acceptance` 或签名不在公钥集的回执判不成立；无回执的 `rulings.md` 裁定行被判不存在；伪造 T0 工单四种（包名不存在 / 自拼门禁列表 / 完工 diff 越出 paths / 引用一个 paths 覆盖 `constraints.md` 的包）各被拒绝，其中第四种在 `check-policy.py` 层就拒绝签策略；`intake_author` 兼 proposer 的配置被拒发 |
| R2 | 执行架构迁出（含 `human` kind 一小节，3.2） | T1（大搬家但方向无争议） | `executor-architecture.md`；agent 文相应节改为指针 | R0（**不依赖 R1**：S1/R1 受阻不阻塞本轮） | `doc-gate` 通过；§11.3 八条逐条可寻 |
| R3 | 登记表加 `principal` / `provider` / `runtime` / `model_family` / `roles_allowed`；判定前机械拦角色冲突（含 `intake_author`）；独立性折算首版进 `authority.md` | T1 | 各轮 `round.md`、`round-status.py`（原列 `agents.toml`、`round-dispatch.py`，均已于 2026-09-10 删除；登记改由各轮 `round.md` 承担，角色检查在 `role_checks()`） | R1 | 故意配置「裁决方兼提案方」，判定拒绝并给 reason；正常配置放行；折算表存在且 3.2 的示例（1 家独立带证 vs 3 家同 runtime 无证）按表算出前者胜；luna 与 kimi 按表落同一组 |
| R4 | 工单一般化为 Artifact + T0/T1 guard 表与必需产物表 + 三值路由 + `status` 改推导 | **T2** | `round-protocol.md` 改版、`policies/tier-defaults.toml`、脚本读 tier | R1、R3 | 用一个**可丢弃的小题目**（`automation-roadmap.md` §4.1 要求）分别跑一次 T0、T1；每次 H2 都有落账；脚本输出无一处非唯一状态机的词 |
| R5 | 两份 lifecycle 合并为 `lifecycle.md`；`request-lifecycle.md` 边界声明修订；13 文件引用清理；`doc-gate.py` 配置 | **T2** | `lifecycle.md`、`migration-map.md`、删两份旧文 | R1–R4 | 5.3 五条全部通过 |

> 本表的调整说明与 `bootstrap` 档的效力来源属架构论证，见 `runtime-architecture.md`
> 与 `rounds/refact-fable/rulings.md`；按 `README.md` 分工不写在本文件。
---

<!-- I08-011 -->
### 开发框架自身（R0–R5 路线）的进度

> 路线表在 [`implementation-plan.md`](../implementation-plan.md)「阶段〇」；本节只记**状态**。
> 最后更新：2026-09-05。

| 轮 | 状态 |
| --- | --- |
| R0 修脚本↔协议不一致 + 合并 `protocol-v2` | **已做**（2026-09-06）。主线 `round-protocol.md` = 七环节版；三个脚本进主线；四处脚本↔协议不一致已修（产物路径、调用方式、退出码、已完成轮次被判成刚开始）。判据与结果见 `rounds/_r0/criteria.md`。产出方 = 验收方（所有者 2026-09-06 裁定不追加外部复验：判据 C1–C9 全是可复跑命令） |
| R0′ 协议补机器可读块 | 未开（所有者已裁定按 T2） |
| **S1 边界 spike** | **进行中**。④ `check-no-owner-creds.sh` 与 ⑤ 宿主取证已完成（`rounds/_spike-sign/forensics.md`）；①②③ 待所有者 |
| R1–R5 | 未开 |

**S1 的两条卡点**：

1. ⚠ **一条路线表未写的前置**：所有者需要**一个 agent 够不着的本地 shell**。
   Cursor 与 Qoder 均 Remote 连入本 VM，其中的终端就是 VM 的 shell——
   在那里签名等于把私钥放在 agent 能 `sudo` 读到的地方。见 `rounds/runtime/rulings.md` `R2`。
2. ⚠ 宿主取证发现 `zym` 有免密 sudo 且在 docker 组，**本机一切本地强制点对 agent 无效**；
   只有托管方的 key 作用域有效。这使 S1 的 ② 成为唯一真正有效力的一步。

<!-- I08-012 -->
### 已完成的轮次

| 轮 | 结果 |
| --- | --- |
| `refact` | 已发布，最终稿 `archive/development-lifecycle-agent.md`（2026-09-07 归档）。其 118 节已于 2026-09-07 吸收进 `agent-dev-guide.md` §10。⚠ `refact-fable` §5.2 承诺的逐节映射表 `migration-map.md` **从未产出**，该欠账至今只清到标题级 |
| `refact-fable` | 已发布；其架构结论（两个 Profile）后被 `runtime` 轮推翻，原文已迁出并删除，内容在 `7e8464c2` 与 `rounds/refact-fable/` |
| `runtime` | 已发布，最终稿曾为 `runtime-architecture.md`；其 33 节已由 `runtime-refact` 轮全部落点到 `agent-dev-guide.md` §10，原文 2026-09-07 归档至 [`archive/`](../archive/)。裁决方自陈错误十二条，六条由参与方抓出、三条由所有者抓出 |
| `_fixups` | 进行中：追认 `runtime` 发布后四次未走流程的改动，验收方 cursor |

## 吸收审计与旧源收据

原作者核了什么、补了什么及完整 294 行映射；摘要不能替代语义审计。未核的通用规程经 I02-097 取件。

<!-- I02-095 -->
### 覆盖声明

**§9.1–§9.4 保留的是底稿作者在各轮的取证与补写历史。**其中的源稿数量、章节落点和行数
按成文时理解，不作为本补充版的现行覆盖结论；本次范围见 §9.5，当前索引见 §10。
这也适用于 §8.1 和 §12 原有案例中的第一人称或“本轮已实测”措辞。

<!-- I02-096 -->
### 查了什么

- 按 `ed0b5136` 逐行读取 `refact-fable.md`（31 个 `##`/`###` 标题）与
  `runtime-architecture.md`（33 个 `##`/`###` 标题），§10 共 64 行。
- 读取产品内核全文；读取 constraints、development-plan、implementation-plan、handoff；读取
  round-protocol 与本轮工单/通知；读取 S1 forensics 和 runtime 处置记录中与六项核查、H5、证据错误有关的部分。
- 在 luna 的 `investment-app`（`investment-backend` commit `18d88c7`）复跑中断、恢复、thread_id、
  checkpointer 的代码搜索与锚点读取。
- 在宿主复跑 `sudo -n -l`、`git ls-remote --heads origin`、`git ls-remote --tags origin`；在工作树复跑
  branch/upstream、tag 和 worktree 枚举。
- 未读取其他参与方 worktree 或本轮候选；未读取任务书禁止的参考融合稿。

<!-- I02-098 -->
### 自增内容及理由（`runtime-refact` 轮）

本稿新增三点：第一，把 K1/K2 直接收敛为“产品 Interaction → LangGraph 原语”的最小绑定，理由是已有代码
足以表达中断恢复；第二，把安全设计改成“逐动作画真实路径再设服务端强制点”，理由是 K3–K6 证明旁路
不经过待保护动作；第三，把原 R0–R5 改成 G0–G5 的证据依赖顺序，先做原语 spike 与身份强制，再做服务态
等效。三点都有 §4.3、§4.4、§8.1 的代码或命令证据，不以通用最佳实践作为依据。

<!-- I02-099 -->
### 两份 lifecycle 的吸收轮（2026-09-07）

**作者与时间与 §9.1–§9.3 不同，故单列，不混入上面的声明。**
执行者 opus；所有者指令：「你逐节对照，把两份 lifecycle 吸收进 `agent-dev-guide.md`」。

**查了：**

- 逐节读取 `archive/development-lifecycle-agent.md`（73 个 `##`/`###`）与
  `archive/development-lifecycle-human.md`（45 个），§10 新增 118 行；
- **复跑了吸收进来的外部仓锚点**，三个仓都在源稿钉的提交上（Codex `7d6f808b`、
  Harness `dd6322d6`、OpenClaw `173f41d6`）。逐字复核过的关键两条：
  `codex/sdk/python/src/openai_codex/client.py:773-779` 的 `_default_approval_handler`
  对 `commandExecution` 与 `fileChange` **一律返回 `{"decision": "accept"}`**；
  `deepseek-harness/packages/sdk/protocol/README.md:116`「**Server→client requests are a
  dead capability** — the transport supports them, but the server never sends one」，
  同文件 `:115` 无 cancel/session-close、`:52` `messageId` 不标识 turn 结束；
- 用 `difflib` 实测两份 lifecycle 的重复率（≥8 行的节，重合度 ≥0.55 者 222/563 = 39%），
  重复节在 §10 注明同源与重合度。

**没查（本次新增的盲区）：**

| 类别 | 内容 | 性质 |
| --- | --- | --- |
| 外部仓 | §2.7 表里**其余各行**的锚点（preset README、adding-a-tool、model-provider-info、async_client、openclaw 各文档）**只核了行号可达，未逐字复核内容** | 可当场复跑，只是没跑完 |
| 部署 | §2.10 四条硬阻断的 bundle 行号**未复跑**，转录自源稿 | 可复跑 |
| 休眠登记 | §2.6 的 `test_dormant_capabilities.py` 四个行锚**未复跑** | 可复跑 |
| ~~判定口径~~ | ~~只比对标题与存在性，未逐行比对正文~~ | **已于同日补做，见下** |

**正文级抽查（2026-09-07，同日补做）**

⚠ **上面那条盲区不是假设——抽出来 13 处真缺，其中 1 处是落点判错。**

抽查范围：118 行按风险分流为「本次新写 32 行」「判落在既有章节 79 行」「故意不要 7 行」，
**对 79 行中内容最实的约 20 行逐节读源稿正文并回读本文对应节**。

| # | 源节 | 原判 | 实际 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | agent 源节 4.4 物化门禁 | §3.2 复用前置判据 | §3.2 只有 3 条复用判据，**十条门禁全缺** | 补 §3.10 |
| 2 | agent 源节 5.1 冷启动核对 | §1.3、§3.2 | 两处均无；**「写入前门禁五条（一票否决）」整段缺失** | 补 §3.10 |
| 3 | agent 源节 4.3 塞入材料 | §3.2 | manifest 字段表与「材料可见 ≠ 使用授权」缺 | 补 §3.10 |
| 4 | agent 源节 5.2 上下文路由 | §2.5 | §2.5 是**路由成本字段**，与「改哪一面要读什么」不是同一件事 | 补 §5.8 |
| 5 | agent 源节 5.3 共同纪律 | §3.5、§11 | §11 只有反面形式，**无正面纪律** | 补 §1.5 |
| 6 | agent 源节 6.9 三条硬禁令 | §4.5、§2.2 | 缺；含「忘了传 handler 与故意自动批准在代码里长得一样」 | 补 §4.9 |
| 7 | agent 源节 7.4 候选状态机 | §3.3 末段 | 末段只有一句「Artifact 有版本属性」，**八态状态机全缺** | 补 §3.11 |
| 8 | agent 源节 12 完成判据 | §5.5、§3.5 | 十三条与「缺项只能称…」全缺 | 补 §3.12 |
| 9 | agent 源节 2.3 Task 契约 | §2.4 | §2.4 字段表**缺一半**；「硬门禁/质量偏好/待定项必须分开」缺 | 补入 §2.4 |
| 10 | agent 源节 3.1/源节 3.2 简单与复杂 | §3.4 T0/T2 行 | ⚠ **落点判错**：简单/复杂是**载体轴**，T0/T2 是**风险轴**，两轴正交 | 改落 §3.4 载体轴段 |
| 11 | agent 源节 0.1 | §0.1 | 跨机同步与「子仓要自己推」缺 | 补入 §3.2 |
| 12 | agent 源节 0.2 | §1.2、§5.2 | `request-baseline`「只解释来源，不覆盖现行合同」缺 | 补入 §0.1 |
| 13 | agent 源节 5.4 单路实施 | §3.4 T1 | 「作者自检不能代替独立验收」缺 | 补入 §5.5 L1 |

⚠ **第 10 条最值得记**：把载体轴写成风险轴，与 §2.5 自己警告的「风险档位不能反过来充当
成本证据」是同一种循环——**我在做落点时犯了本文正文明写禁止的那个错**。

修补后本文由 1659 增至 1858 行，新增 §1.5、§3.10–§3.12、§4.9、§5.8，20 行落点更正。

**第二轮（同日，抽完剩余 65 行）：又出 16 处，累计 29 处。**

| # | 源节 | 原判 | 实际 | 处置 |
| --- | --- | --- | --- | --- |
| 14 | agent 源节 6.1 展开条件 | §6.1 | ⚠ **落点判错**：guide §6.1 是「机械分类」（运行时值不值得用），与 fan-out 形态无关；五形态含「胜者改进」全缺 | 补 §3.13 |
| 15 | agent 源节 6.2 Work Unit 契约 | §2.4 | §2.4 是工单（整个 Task），**派工契约是另一层**；三字段派工纪律全缺 | 补 §2.11 |
| 16 | agent 源节 6.3 建立 worktree | §3.2 | 十条里缺 4 条（同分支不可双检出、只隔离写入不阻读、凭据不得进分支、删 worktree ≠ 删证据） | 补 §3.14 |
| 17 | agent 源节 6.4 候选隔离 | §2.2 | **「隔离靠纪律不靠机制、无法事后证明某轮真独立」缺**——这是诚实性条款 | 补 §2.11 |
| 18 | agent 源节 6.6 评审裁决 | §2.2 | 事实裁决表（证实/证伪/未决）、两阶段评审、「不合格候选不进偏好评分」全缺 | 补 §5.10 |
| 19 | agent 源节 6.7 整合 | §3.5、§5.5 | 「一条独立主张一个提交」「候选的绿不证明整合正确」缺 | 补 §5.10 |
| 20 | agent 源节 6.8 停止规则 | §2.4 budget | 六条全缺 | 补 §3.13 |
| 21 | agent 源节 7.5 载体语义 | §3.9、§5.4 | §5.4 只有散文，**七载体对照表缺**；「reflog 里还在不是保留策略」缺 | 补 §5.9 |
| 22 | agent 源节 7.7 发布协议 | §3.5、§5.4 | candidate/publication/published **三路径区分缺**；「只要草案时 target 是候选集合」缺 | 补 §3.15 |
| 23 | agent 源节 7.9 保留与 GC | §3.5 | 六档表、「GC 是显式阶段不是退出副作用」、删除前六项验证全缺 | 补 §3.16 |
| 24 | agent 源节 11.3 未验证清单 | §7.4、§9.2 | 八条全缺；**「清单为空前一律按 `defined` 对待」缺**——这条管着怎么读 §2.6–§2.10 | 补 §7.6 |
| 25 | human 源节 2 人的三个角色 | §4.1 | 提出者/执行者/principal 三分缺 | 补 §2.11 |
| 26 | human 源节 7 人的义务 | §4.1、§4.5 | 六条全缺，含**「盲区声明是自愿的，只要说了就受罚，很快就没人说了」** | 补 §4.10 |
| 27 | human 源节 8.3 委派 | §3.4 | 「委派转移执行，不转移最终责任」缺 | 补 §4.10 |
| 28 | human 源节 14 成本与停止 | §6 | 「交叉阅读是二次复杂度」「未经事实验证要标注」「失败/超时/缺席也进记录」缺 | 补 §3.13 |
| 29 | 本文自身 | — | ⚠ **§4.7 写了「登记 §7.4 未决」，而 §7.4 里没有这条**——我自己犯了正在批的「承诺不进验收」 | 补 §7.4 第 20b 行 |

⚠ **第 14 条是第二次落点判错**（第一次是把载体轴写成风险轴）。两次都是**把源节挂到一个
名字相近、实质不同的节上**——这正是标题级验证抓不到、只有读正文才能抓到的错法。

⚠ **第 29 条是本文自己身上的**：我在 §4.7 承诺登记到 §7.4 却没登记。
与 `refact-fable.md` §5.2 承诺 `migration-map.md` 从未产出，是同一个形状。

**反向覆盖检查**：全文 `§N` 自引用扫描，指向不存在章节的 10 处**全部位于 §10 落点表
第三列的「同 agent 文 §X」中，指的是源稿节号**，非本文缺节；已统一改写为「同 agent 文 §X」
以免误读。除此之外未发现本文写入源稿所无的规范性主张（编辑性串联除外，如 §2.9 末尾
指出 Harness 腿与 §4.3 LangGraph 腿恢复语义不同——这是两个源之间的连接，不是新主张）。

**第三轮（同日，抽 `refact-fable` 31 行 + 兑现 `runtime-architecture` 33 行的旧账）：
再出 21 处，累计 50 处。**

`runtime-architecture` 的 33 行本已在同日一份独立审计里做过正文级对照，查出 15 处——
⚠ **但只记录、未修补**。⚠ 那份审计一度被放进 `rounds/dev-plan-refact/`，
**等于宣告那一轮是做审计的**；现已撤销，内容并入本节（该文件不再存在）。
本轮兑现其中 14 处
（第 11 项 `audit_after` 已由 §4.6 顺带补上）：

| 源节 | 缺的是什么 | 补到 |
| --- | --- | --- |
| §2.3 | **五家登记表本体**（36 行取值 + `channel_grade`）——§2.3 只说「至少登记这些字段」，无取值 | §2.12 |
| §2.4 | **本轮已发生介入的实例级清单 12 行**——⚠ 正是上一轮 ⑤ 验收 `C-1` 抓出的缺项，**连丢两轮** | §4.11 |
| §2.8 | **23 条轨迹表本体** + 对照组 + 引用纪律两条——§5.3 只留读数，**结论在、证据不在** | §5.11 |
| §4.2 | 读数三条 + 「机械非空不等于填对」的实例 | §2.12 |
| §4.5 | **数据网关 / 不得给裸库凭据**（硬约束） | §3.2 |
| §4.7 | 三行现状事实：无 GPG 密钥、`id_rsa` 对主仓可写、Windows 侧亦跑本地 agent | §4.4 |
| §2.2 | 别名登记、`privacy`(NO ZDR)、观察窗中位数、`freshness` | §2.4 |
| §2.7 | `author_claimed` / `author_attested` 拆分 | §5.3 |
| §4.1 | `codex exec --json` 锚点（本次复跑于 `7d6f808b`） | §2.12 |

`refact-fable` 的 31 行**此前只抽过 3 处**，本轮补抽，出 7 处：

| 源节 | 缺的是什么 | 补到 |
| --- | --- | --- |
| §2 | **六条设计原则 P0–P5**；尤其 **P5「凡能落成代码/测试/门禁的纪律必须落成」**，与推论**「一个只能靠人转述的环节等于没有环节」**——整段无落点 | §1.6 |
| §2 | P0 的适用层级：**对象的小生命周期不是第二套状态机** | §1.6 |
| §3.10 | **内核对象 ↔ 开发载体对照表**——§3.3 是状态投影表，与它不是同一张 | §3.17 |
| §3.8 | 状态脚本硬要求：**推导值 ≠ 声明值即报错**、**边不在合法表即报错退出**、分发前角色冲突拒绝 | §3.18 |
| §3.12 | acceptor「既得利益最小、由处置表算出」；L3「抽样规则写进工单」 | §5.5 |
| §3.5 | 「分类节点只给四条判据的命中证据，**不给 tier**」 | §2.1 |

⚠ **`runtime-architecture` 那 15 处是「查出来了没修」**——审计写完之后
在一份独立文件里躺了几个小时，没有回到被审对象上。
**这与 `refact-fable.md` §5.2「承诺产出但不进验收」是同一个形状的第三次出现**：
第一次是 `migration-map.md` 从未产出，第二次是我在 §4.7 承诺登记到 §7.4 而没登记，
第三次是这份审计只记不修。**记录不等于修补，审计不等于验收。**

**查过但确认「不是缺」的，一并记下，免得下次重查：**

| 曾疑 | 实际 |
| --- | --- |
| 合法转换全集（五行状态表） | 本文**故意不重写**——§0.1 边界写明「不重写对象定义、合法边」，改为按 commit 引用内核。**这是对的** |
| git 的两个角色（载体永久 / 账本要拆） | §5.4 有，措辞不同 |
| `runtime-architecture` §2.5 产物→状态机 16 行 | §3.3 有 13 行 + 散文补 3 行，且**多一行**「同一执行从 checkpoint 续跑」——是 K1/K2 的新发现 |
| `H5-final` / `H5-round` 拆分 | §7.4 风险 4 有 |
| 三道边界的**机制** | §3.2 有（撤销的是「组合成安全架构」这个结论，不是机制本身） |
| §2.7 六条比对规则 / `TraceEnvelope` | §5.3 全有；`TraceEnvelope` 明说不沿用该名但保留字段，并给了理由 |
| `lifecycle-agent` §5.4「作者自检不能代替独立验收」 | 已补入 §5.5 L1 |

**四份源稿 182 行全部抽到正文级，本轮抽查完成。**
累计 50 处真缺、2 处落点判错，本文 827 → 2352 行。

<!-- I02-100 -->
### GPT-6 再吸收记录（2026-09-08）

**用户目标：以保留的 guide 为基座，再吸收 archive 中相容而有用的内容，生成独立的
`agent-dev-guide-gpt6.md`，他人的文档不改。**本次不是重判 runtime-refact，
也不是执行另一轮的开轮/分发/发布任务。

输入固定于 k8s `d9f827f810be6b645b9ef2c1339009328bca02f5`：
底稿 2402 行，archive 五份历史正文和 README；另读现行产品合同、约束和协作协议核边界。
旧谱系为两 lifecycle → refact-fable → runtime-architecture，随后分叉为独立的
agent-dev-refact 与 runtime-refact 的 guide；两 lifecycle 在 9 月 7 日又直接补入 guide。
本次把兄弟分叉里的相容增量接回，并再查前四源的正文落点；不把共同祖先重合误称为全部已处置。

| 本次吸收/修正的内容 | 原来源 | 实际正文落点 |
| --- | --- | --- |
| 单份指南阅读路线、缺失词汇 | agent-dev-refact 阅读入口；human 自足目标 | §0.3、§13 |
| P6、检验真实动作路径与控制面自身 | agent-dev-refact 设计原则、元观察 | §1.6–§1.7 |
| 执行路线三层判断、Gate 0 三项、确定性熟路 | lifecycle-agent 执行层路线 | §2.6 |
| 通用 DTO 与 Adapter 职责禁区 | lifecycle-agent 执行 Port | §2.8 |
| 人贡献内容不等于产品执行器 | human 三角色与 agent-dev-refact 人的位置 | §2.11、§4.3 |
| T0 窄包理由、触点和两道门的时序 | refact-fable/runtime/agent-dev-refact 工单 | §3.1 |
| 状态投影的拒绝与取消 | 多稿状态表；现行产品合法边 | §3.3 |
| 清理失败不污染终态、失败现场保留 | lifecycle-agent sandbox 清理 | §3.5、§3.16 |
| 七环节、角色算法、产物取件、通知与超时 | agent-dev-refact 流程导读；现行协议校准 | §3.18–§3.22 |
| 私有 Git 元数据可写性与代提交 | agent-dev-refact 工作区实验；现行协议代提交纪律 | §3.20 |
| 问询分层、三类威胁、具体批准对象与默认分级 | refact-fable/runtime 人的通道与威胁；agent-dev-refact 中断 | §4.3–§4.4、§4.12 |
| 可信受理、附件校验、原值与默认值留痕 | lifecycle-agent 前端与受理 | §3.1 |
| 网关令牌、环境洗白名单与跨腿委派禁令 | lifecycle-agent 审批/凭据边界 | §4.13 |
| 门禁自身质量与七类假答案 | agent-dev-refact 判据与实测汇总；README 正文抽查教训 | §5.12、§12.1 |
| 历史证据的版本/环境/作者边界 | 各稿的取证声明、未验证清单 | §5.13、§9 |
| 对账观察面的覆盖、未归因与追认限制 | agent-dev-refact 绕过观察 | §6.3 |
| 分组件迁移门、五源删除条件、完整 checkpoint | agent-dev-refact 脚手架；lifecycle-agent 恢复和删除清单 | §7.2–§7.5 |
| 内核修订工作单元与保留旧语义 | agent-dev-refact 内核修订；runtime 迁移纪律 | §7.7 |
| 竞争评审的共同盲区和输入偏置 | agent-dev-refact 评比边界与元观察 | §12.2 |
| 全部源标题与明确冲突处置 | 五份历史正文及 README | §8.3、§10 |

**本次验证的范围**：源标题枚举与逐项处置一致；检查新增正文确有对应内容；
校验表格、相对链接、本文章节引用及完整源文件摘要；检查本文件不依赖 archive 的现行相对链接。
索引使用统一的一至四级标题口径：五稿 284 行，README 10 行，不再混用 182、197、76 的不同分母。

**本次没有做的验证**：没有复跑 SDK/模型、部署、权限、生产数据库或旧轮评审实验；
没有宣称已经获得独立验收，也没有宣称残余语义遗漏为零。
§9.1–§9.4 的旧测试结果仍属原作者、原环境、原版本。
源稿权限及 Git 布局实验保留为历史线索；“已有凭据即批准”“当前无需边界”等冲突不进入执行规则。

**完成内容迁移不等于完成删除门**：本次没有清理其他文档的旧引用，没有跑真实 T0/T1 开发任务，
也没有删除源稿。日常指南不再以 archive 为操作依赖；要删除历史源文件仍按 §7.3 单独处理。

**输入文件 SHA-256（内容摘要，不是身份签名）：**

| 源路径（相对 dev-plan） | SHA-256 |
| --- | --- |
| `agent-dev-guide.md` | `00065c06361e0097e56ac7f0a343b451001e253a2d636d37654e52cc98628e32` |
| `archive/README.md` | `bb67f49c8563ca6dde81a9e81edc5dd70822342b9fbdff17a1af324b50805c1d` |
| `archive/agent-dev-refact.md` | `888d8b1f6ec9a9d202fba6d3465b7e2e562219527b4a0812560655b00fb1b9a1` |
| `archive/development-lifecycle-agent.md` | `70295ecf6ac887ecbc4346af6e2ac71c1ae659e0d8d79efb68631c6b28b9ffc9` |
| `archive/development-lifecycle-human.md` | `33d0ba965734f4608d9519bed83947c09cb1c35e0f537647a2425d5441ad47d0` |
| `archive/refact-fable.md` | `e318d5cede2d61e7b38a218cef0132bc240154ff42ec357912aaa182893958c2` |
| `archive/runtime-architecture.md` | `9d8428d629d7fa52f925ff9e28f4b0bc8ed19c37601238f82b734f7628449741` |

<!-- I02-101 -->
### 取代前 opus 做的核验（2026-09-08）

⚠ **这一节是 opus 写的，不是本版作者写的。**它记的是「凭什么敢用它换掉上一版」，
以及**核验到哪一步为止**。

**核了：**

| # | 核了什么 | 结果 |
| --- | --- | --- |
| 1 | §9.5 钉的输入 commit `d9f827f8` 是否可达、底稿是否 2402 行 | ✓ 均对 |
| 2 | §9.5 给的**六个输入文件 SHA-256** | ✓ **逐字节全部吻合** |
| 3 | §10 落点表行数与源节数是否一致 | ✓ **294 = 284 + 10**，**零空落点** |
| 4 | 是否覆盖了此前一直未落点的 `agent-dev-refact.md` | ✓ **76 节全部有落点**（上一版完全没有） |
| 5 | 随机抽 6 条 `agent-dev-refact` 落点，其中 3 条**回读落点正文** | ✓ 关键词均在，**未抽到伪取证** |
| 6 | 相对链接是否随改名失效 | ✓ 全部指向兄弟文档，不受影响 |

**它纠正了上一版三处，逐条复核属实：**

| # | 上一版的问题 | 本版的处理 |
| --- | --- | --- |
| 1 | ⚠ **分母混用**：§10 表用 `##`/`###`（182 行），正文却写「197 节」（一至四级口径） | 统一为一至四级，**五稿 284**。⚠ 而 `dev-plan-refact` 任务书 §8 **正是 opus 自己立的「计法固定为排除代码块后的 `^#{1,4} `」——立了规矩没照做** |
| 2 | §2.12 标题写「**实测**取值」，而那些值来自上一轮 | 改为「**历史**取值示例」 |
| 3 | 「身份只能来自目录名」把两件事混了 | §3.20 改为「目录名是**本地归属线索**，**不是经鉴别的 principal 身份**」 |

⚠⚠ **没核的（比核了的更要紧）：**

| # | 没核 | 为什么这条重要 |
| --- | --- | --- |
| 1 | ⚠ **294 条落点只抽了 6 条、正文级只验了 3 条** | opus 上一次对 85 行做正文级抽查，**查出 50 处真缺、2 处落点判错**。按同一命中率，本表**很可能仍有数十处**。**「比上一版好」已证；「正确」未证** |
| 2 | 新增 17 节的**反向覆盖**——有没有写进源稿里没有的东西 | 一条未查 |
| 3 | 与本轮只读输入的一致性 | 见下 |
| 4 | 全部继承自源稿的实测读数 | §9.5 已声明「仍属原作者、原环境、原版本」，opus **未复跑任何一条** |

⚠ **对 `dev-plan-refact` 轮的影响，如实登记：**

本版**晚于该轮冻结基线 `f1d5f8f4`**。五家参赛方钉在基线上，**看到的仍是 2402 行那版**，
本次替换**不改变该轮的只读输入**——这正是冻结基线的用处。但由此产生两条待处置：

1. 该轮任务书 §3 记的「`agent-dev-guide.md` 2388 行 92 节」与 master 现状不符——
   ⚠ **相对基线是对的，相对 master 是旧的**。本轮结束前不改任务书（`B1`）；
2. ⚠ 该轮 `B8` 要求「把 `agent-dev-refact.md` 76 节并入」——**本版已经做了**。
   该轮候选若重做，做的是**基线上那版**的并入。**这个重叠须由所有者在 ③ 处置**。

⚠ **opus 的利益申报**：opus 是本轮参赛方，且在写本节前**读了本版全文**。
按 `call-①`「提案冻结前不得读其他候选」，虽然本版不是该轮候选（路径不同），
但它是**同一主题、同一底稿、更新的融合稿**。**opus 的候选独立性已受影响，供 ③ 折算。**

<!-- I02-102 -->
### 五份历史正文及目录说明的逐节处置

这张表回答“源段内容在哪里，或为什么不保留”，不是日常执行步骤。
**唯一性的单位是“源文件 + 标题层级 + 标题文本”**；源文件固定为
k8s `d9f827f810be6b645b9ef2c1339009328bca02f5` 下 `sunmoonai/docs/dev-plan/archive/`。
源标题按脚本枚举，不把代码块里的样例标题算进正文。左列只是来源定位，右列的 § 均指本文。

| 源文件 | 旧表口径：二/三级标题 | 本次口径：一至四级标题 |
| --- | --- | --- |
| development-lifecycle-agent.md | 73 | 74 |
| development-lifecycle-human.md | 45 | 47 |
| refact-fable.md | 31 | 40 |
| runtime-architecture.md | 33 | 47 |
| agent-dev-refact.md | 未入旧表 | 76 |
| 合计历史正文 | 182（仅前四稿） | **284** |
| README.md（另计） | 未入旧表 | **10** |

**覆盖索引不等于语义无缺。**本次在旧 182 行上增加原来未枚举的一级/四级标题、第五稿与
目录说明；对发现的落点错误重定位置。第一至第四稿已有行保留其来源处置语义，
其中“抽查发现原缺”等字样记录的是底稿吸收历史，不能误读成本次仍未补。
“不采用”并非漏迁：与底稿冲突的设计、失效文件拆分计划和无法成立的事实外推明确排除。

如将来发现右列正文不能支持对应处置，以实际正文和证据为准，登记修补；
不能用“表已全”驳回发现。历史源文件可用于审计复核，但开发动作不以读取它们为前置。

| 源 | 源标题（层级照原稿） | 本文落点或不采用的理由 |
| --- | --- | --- |
| lifecycle-agent | # 开发生命周期 · Agent | §0–§7、§11–§14；整体承接执行纪律与架构，不保留“两条路径”的独立规范身份。 |
| lifecycle-agent | ## 0. 边界和共同模型 | §0.1 |
| lifecycle-agent | ### 0.1 本文负责什么 | §0.1；跨机同步与「子仓要自己推」补入 §3.2（**抽查发现原缺**） |
| lifecycle-agent | ### 0.2 事实、目标和执行记录分开 | §1.2、§5.2、**§1.5 第 3 条**；`request-baseline` 的地位补入 §0.1（**抽查发现原缺**） |
| lifecycle-agent | ### 0.3 两层监督职责与等位原则 | **故意不要**：§0.0 第 2 条判定「supervisor 一词三义」；由 §2.1 五个组件词与 §2.2 内容角色替代，「等位原则」不再需要单独声明 |
| lifecycle-agent | ### 0.4 产出物的根本原则：私有地产生，单写者发布 | §3.6 |
| lifecycle-agent | ## 1. 两条同构路径 | **故意不要**：§0.0 第 1 条——两条路径的差异只剩「谁按了回车」，撑不起两份文档 |
| lifecycle-agent | ### 1.1 Agent 路径 | 部分保留：§3.1–§3.3 的受理、物化、执行；不保留相对于 Human 的独立状态链。 |
| lifecycle-agent | ### 1.2 Human 路径 | 部分保留：§3.1、§4.1 的人工入口和 principal 职责；不另立 Human 运行时。 |
| lifecycle-agent | ## 2. Submission 与 FastAPI 受理 | §3.1 |
| lifecycle-agent | ### 2.1 前端提交 | §3.1；补原话/附件/输出/幂等键与前端不得自报可信身份、扩权的边界。 |
| lifecycle-agent | ### 2.2 FastAPI 建立开发 Task | §3.1；补认证上下文、附件校验、版本化策略、首 Event 持久化与规范化留痕；不把框架名当规范。 |
| lifecycle-agent | ### 2.3 Task 契约 | §2.4；⚠ **抽查发现原落点缺一半字段**，已补「硬门禁/质量偏好/待定项必须分开」与 8 个字段 |
| lifecycle-agent | ## 3. 简单与复杂任务 | 部分保留：§3.4 的载体判据；不以该二分取代 T0/T1/T2 风险档位。 |
| lifecycle-agent | ### 3.1 简单 Task | §3.4 **载体轴段**；⚠ **原落点判错**——简单/复杂是载体轴，T0/T2 是风险轴，两轴正交，混写即 §2.5 警告的循环 |
| lifecycle-agent | ### 3.2 复杂 Task | §3.4 载体轴段；同上 |
| lifecycle-agent | ## 4. sandbox、Git 物化与执行器接入架构 | §3.2、§2.6 |
| lifecycle-agent | ### 4.1 谁建立什么 | §3.2 |
| lifecycle-agent | ### 4.2 物化步骤 | §3.2 |
| lifecycle-agent | ### 4.3 按 Task 塞入材料 | **§3.10** manifest 字段表 + 「材料可见 ≠ 使用授权」（**抽查发现原缺**） |
| lifecycle-agent | ### 4.4 物化门禁 | **§3.10** 物化门禁十条；⚠ **原落点 §3.2 只有 3 条复用判据，十条全缺**（抽查发现） |
| lifecycle-agent | ### 4.5 执行层路线：租用 loop，自建业务控制面 | §2.6；补 Gate 0 三条条件、三层成熟度与确定性熟路，均保留待验身份。 |
| lifecycle-agent | ### 4.6 两个官方 SDK：两个轴、非对称能力 | §2.7 |
| lifecycle-agent | ### 4.7 统一执行 Port 与三态能力探针 | §2.8；补通用 DTO、Adapter 不拥有授权/验收/四本账/Task 终态的边界。 |
| lifecycle-agent | ### 4.8 Harness SDK 前置门禁与过渡补法 | §2.9 |
| lifecycle-agent | ### 4.9 双 runtime 的部署、进程与恢复 | §2.10 |
| lifecycle-agent | ### 4.10 专用 Agent 的构建方法，不冻结具体 Profile | §2.6；方法、dry-plan/query、submit_result 与暂不冻结财务具体契约均保留。 |
| lifecycle-agent | ### 4.11 OpenClaw Gateway：借机制，不转向 | §2.6；保留机制取舍与实际依赖边界，非 §3.2 工作区供给。 |
| lifecycle-agent | ## 5. Agent 执行内核 | §3 |
| lifecycle-agent | ### 5.1 冷启动核对 | **§3.10** 冷启动七条 + **写入前门禁五条（一票否决）**；⚠ **原落点两处均无此内容**（抽查发现） |
| lifecycle-agent | ### 5.2 上下文路由 | **§5.8** 八个改动面 + 能力四级词典；⚠ **原落点 §2.5 是路由成本字段，不是同一件事**（抽查发现） |
| lifecycle-agent | ### 5.3 共同纪律 | **§1.5** 八条（**抽查发现原缺**；§11 只有反面形式，无正面纪律） |
| lifecycle-agent | ### 5.4 单路实施 | §3.4 T1 行；「作者自检不能代替独立验收」补入 §5.5 L1（**抽查发现原缺**） |
| lifecycle-agent | ### 5.5 Checkpoint 与恢复 | §2.10、§4.3、§7.5；补完整 checkpoint 字段及恢复前权限/租约/基线/副作用复验。 |
| lifecycle-agent | ### 5.6 失败、澄清与改判 | §1.5、§4.8、§5.13；失败、关键歧义、追加改判与目标转事实前取证。 |
| lifecycle-agent | ## 6. Attempt 内的执行监督 Agent | **部分故意不要**：「执行监督 Agent」是 §0.0 第 2 条判掉的同名物；其纪律落 §2.2 与 round-protocol，不保留该角色名 |
| lifecycle-agent | ### 6.1 展开条件 | **§3.13** 五种执行形态；⚠ **原落点判错**——guide §6.1 是「机械分类」（运行时值不值得用），与 fan-out 形态无关（抽查发现） |
| lifecycle-agent | ### 6.2 Work Unit 契约 | **§2.11**；⚠ 原落点 §2.4 是工单（整个 Task），派工契约是另一层，三字段派工纪律全缺（抽查发现） |
| lifecycle-agent | ### 6.3 建立 worktree | **§3.14** 十条细则（**抽查发现原缺** 4 条：同分支不可双检出、只隔离写入、凭据不得进分支、删 worktree ≠ 删证据） |
| lifecycle-agent | ### 6.4 候选隔离 | §2.2、**§2.11**；⚠ 「隔离靠纪律不靠机制、无法事后证明独立」**原缺**（抽查发现） |
| lifecycle-agent | ### 6.5 角色分离 | §2.2 |
| lifecycle-agent | ### 6.6 评审、裁决和选优 | **§5.10** 事实裁决表 + 两阶段评审 + 「不合格候选不进偏好评分」（**抽查发现原缺**） |
| lifecycle-agent | ### 6.7 改进、整合和回归 | **§5.10** 整合纪律；⚠ 「一条独立主张一个提交」与「候选的绿不证明整合正确」**原缺**（抽查发现） |
| lifecycle-agent | ### 6.8 停止规则 | **§3.13** 六条（**抽查发现原缺**） |
| lifecycle-agent | ### 6.9 内层的三条硬禁令 | **§4.9**（**抽查发现原缺**）；含「忘了传 handler 与故意自动批准在代码里长得一样」 |
| lifecycle-agent | ## 7. 产出物与 commit 的全生命周期 | §3.6–§3.9 |
| lifecycle-agent | ### 7.1 先确定身份、所有权和发布权 | §3.6 |
| lifecycle-agent | ### 7.2 命名空间 | §3.6 |
| lifecycle-agent | ### 7.3 产出物分类与载体 | §3.3 末段 Artifact 版本属性 |
| lifecycle-agent | ### 7.4 候选状态机 | **§3.11** 八态 + 七条纪律；⚠ **原落点只有一句「Artifact 有版本属性」，状态机全缺**（抽查发现） |
| lifecycle-agent | ### 7.5 未提交文件、commit、分支与 worktree 的不同语义 | **§5.9** 七载体对照表 + 「reflog 里还在不是保留策略」；⚠ 原落点 §5.4 只有散文，无对照表（抽查发现） |
| lifecycle-agent | ### 7.6 各种并发场景的处置 | §3.7 |
| lifecycle-agent | ### 7.7 最终路径的发布协议 | **§3.15** 三路径 + compare-and-swap + 「只要草案时 target 是候选集合」（**抽查发现原缺**） |
| lifecycle-agent | ### 7.8 覆盖或来源不明时的事故处理 | §3.8 |
| lifecycle-agent | ### 7.9 保留与垃圾回收 | **§3.16** 六档表 + 「GC 是显式阶段不是退出副作用」+ 删除前六项验证（**抽查发现原缺**） |
| lifecycle-agent | ## 8. 冻结、迟到结果与取消 | §3.9 |
| lifecycle-agent | ### 8.1 `F-EXEC-*` / `F-INTERACT-*` 双腿落地矩阵 | §5.6 |
| lifecycle-agent | ## 9. 权限、预算与副作用 | §4.5、§4.13；权限交集、父预算、稳定幂等键及副作用意图/回执/补偿。 |
| lifecycle-agent | ### 9.1 三道正交门与工具不可见原则 | §4.6 |
| lifecycle-agent | ### 9.2 四档审批、哈希绑定与凭据边界 | §4.7、§4.13；四档/哈希/超时已在，补 egress 短令牌、环境白名单、跨腿委派禁令与副作用账。 |
| lifecycle-agent | ## 10. 证据、验收、交付和清理 | §5、§3.5 |
| lifecycle-agent | ### 10.1 最小证据账 | §5.7 |
| lifecycle-agent | ### 10.2 最终验收 | §5.5 L1/L3、**§3.12** 十三条（抽查：七条中六条已在 §3.12，「声称完成/全返回不算成功」在 §3.12 与 §11） |
| lifecycle-agent | ### 10.3 Delivery | §3.5 |
| lifecycle-agent | ### 10.4 sandbox 清理 | §3.5、§3.16；补敏感缓存销毁、失败现场责任/期限、清理失败独立告警。 |
| lifecycle-agent | ## 11. Human 与 Agent 对照 | **故意不要**：§0.0 第 1 条；两路径合一后无对照对象 |
| lifecycle-agent | ### 11.1 本文的生效边界 | §0.1 |
| lifecycle-agent | ### 11.2 本文的删除条件与清理清单 | §7.3；保留长期落点、可执行纪律与入口清理要求；不保留两路径/两文并存前提。 |
| lifecycle-agent | ### 11.3 本轮未验证清单 | **§7.6** 八条 + 「清单为空前一律按 `defined` 对待」；⚠ **原落点两处均无此八条**（抽查发现） |
| lifecycle-agent | ## 12. 完成判据 | **§3.12** 十三条 + 「缺项只能称已受理…不能笼统宣称完成」（**抽查发现原缺**） |
| lifecycle-agent | ## 13. 反模式 | §11 |
| lifecycle-agent | ## 14. 常见失败方式与项目实例 | §12 |
| lifecycle-agent | ## 附录 A：词汇对照 | §13 |
| lifecycle-agent | ## 附录 B：开发 Task 持久记录模板 | §14 |
| lifecycle-human | # 开发生命周期 · 人 | §4、§3、§7.5；人的权力/义务与共同执行纪律进入同一指南。 |
| lifecycle-human | ## 1. 为什么要单独一份 | 部分保留：§0.3 的单份指南自足目标；不保留 Human 独立流程文档的存在理由。 |
| lifecycle-human | ### 1.1 为什么本文必须自足 | §0.3、§3.19–§3.22；保留执行者无需回到将删源稿拼规则的阅读要求，不维持两份同构规范。 |
| lifecycle-human | ### 1.2 两条路径的差异总表 | 部分保留：§4.1、§4.5 的人的权力与责任；不保留两条开发路径对照。 |
| lifecycle-human | ## 2. 人的三个角色 | §2.11、§4.1；保留提出、内容贡献、持权职责；人贡献内容不登记为 Agent Profile。 |
| lifecycle-human | ## 3. 人独有的权力，及其义务 | §4.5 |
| lifecycle-human | ## 4. 跨会话续接：靠文档，不靠记忆 | §7.5 |
| lifecycle-human | ## 5. 小请求的裁量权 | §4.8 |
| lifecycle-human | ## 6. 改判三要素 | §4.8 |
| lifecycle-human | ## 7. 人与 agent 协作时，人的义务 | **§4.10** 六条 + 「盲区声明是自愿的，说了就受罚就没人说」（**抽查发现原缺**） |
| lifecycle-human | ## 8. 提出与委派一项开发工作 | §3.1 |
| lifecycle-human | ### 8.1 冻结工作单元 | §3.1、§2.4 |
| lifecycle-human | ### 8.2 工作区从哪来 | §3.2 |
| lifecycle-human | ### 8.3 委派 | §3.4、**§4.10**「委派转移执行不转移责任」（**抽查发现原缺**） |
| lifecycle-human | ## 9. 终审与责任归属 | §4.5 责任归属表 |
| lifecycle-human | # 共同内核 | §3–§5；共同内核并入统一执行路径，不作为第二个独立文档。 |
| lifecycle-human | ## 10. 执行内核 | §3（与 agent 文 源节 5 同源，重合度 0.4–0.85） |
| lifecycle-human | ### 10.1 动手前的核对与写入前门禁 | **§3.10**（同 agent 文 源节 5.1，重合 0.66；随该行一并更正） |
| lifecycle-human | ### 10.2 上下文路由与范围门禁 | **§5.8**（同 agent 文 源节 5.2，重合 0.84；随该行一并更正） |
| lifecycle-human | ### 10.3 共同纪律 | **§1.5**（同 agent 文 源节 5.3，重合 0.85；随该行一并更正） |
| lifecycle-human | ### 10.4 单路实施与定向审核 | §3.4 T1、§5.5 L1（同 agent 文 源节 5.4） |
| lifecycle-human | ### 10.5 冻结、迟到与取消 | §3.9（同 agent 文 源节 8） |
| lifecycle-human | ## 11. 人作为协调者：fan-out | §2.2、§3.4 |
| lifecycle-human | ### 11.1 展开条件 | **§3.13**（同 agent 文 源节 6.1；随该行一并更正） |
| lifecycle-human | ### 11.2 派工契约 | **§2.11**（同 agent 文 源节 6.2；随该行一并更正） |
| lifecycle-human | ### 11.3 建立 worktree | §3.2、**§3.14**（同 agent 文 源节 6.3） |
| lifecycle-human | ### 11.4 候选隔离 | §2.2、**§2.11**（同 agent 文 源节 6.4，重合 0.76） |
| lifecycle-human | ### 11.5 角色分离 | §2.2（同 agent 文 源节 6.5，重合 0.70） |
| lifecycle-human | ### 11.6 评审、裁决和选优 | **§5.10**（同 agent 文 源节 6.6，重合 0.57） |
| lifecycle-human | ### 11.7 改进、整合和回归 | **§5.10**（同 agent 文 源节 6.7） |
| lifecycle-human | ### 11.8 停止规则 | **§3.13**（同 agent 文 源节 6.8） |
| lifecycle-human | ## 12. 产出物与 commit 的落地纪律 | §3.6–§3.9（与 agent 文 源节 7 同源） |
| lifecycle-human | ### 12.1 根本原则：私有地产生，单写者发布 | §3.6（同 agent 文 源节 0.4，重合 0.64） |
| lifecycle-human | ### 12.2 本仓的具体落点 | §3.6 本仓落点表 |
| lifecycle-human | ### 12.3 未提交文件、commit、分支与 worktree 的不同语义 | **§5.9**（同 agent 文 源节 7.5，重合 0.84） |
| lifecycle-human | ### 12.4 产出物分类 | §3.3、**§3.11**（同 agent 文 源节 7.3/源节 7.4） |
| lifecycle-human | ### 12.5 各种场景的处置 | §3.7（同 agent 文 源节 7.6） |
| lifecycle-human | ### 12.6 覆盖或来源不明时的事故处理 | §3.8（同 agent 文 源节 7.8，重合 0.88） |
| lifecycle-human | ### 12.7 最终路径的发布协议 | **§3.15**（同 agent 文 源节 7.7） |
| lifecycle-human | ### 12.8 保留与清理 | **§3.16**（同 agent 文 源节 7.9） |
| lifecycle-human | ## 13. 证据账 | §5.7 |
| lifecycle-human | ## 14. 成本与停止规则 | **§3.13** 成本纪律四条；⚠ 「交叉阅读是二次复杂度」「未经事实验证要标注」「失败/超时/缺席也进记录」**原缺**（抽查发现） |
| lifecycle-human | ## 15. 完成判据 | **§3.12**（同 agent 文 源节 12；随该行一并更正） |
| lifecycle-human | ## 16. 反模式 | §11 |
| lifecycle-human | ## 17. 常见失败方式与项目实例 | §12 |
| lifecycle-human | ## 18. 边界 | §0.1、§0.3；保留单份开发指南自足与产品真源分工，不保留对另一条生命周期的依赖。 |
| lifecycle-human | ## 附录 词汇对照 | §13 |
| refact-fable | # 重构方案：开发框架从「两条路径 + 多重 supervisor」改为「一套状态机、多个 Profile、一张权力表」 | §0.0、§1–§7、§8；保留诊断与纪律，架构以底稿后继裁定为准。 |
| refact-fable | ## 0. 一页摘要 | §0、§8.2 |
| refact-fable | ## 1. 诊断：现状的六个结构问题 | §0.1、§2、§3.4、§7.3 |
| refact-fable | ### 1.1 「两条路径」是假分叉 | §0、§3；统一为一条开发 Task 链 |
| refact-fable | ### 1.2 supervisor 已有三套同名物，第三套还有一个未定义的别名 | §2.1、§2.2；组件与内容角色分名 |
| refact-fable | ### 1.3 权力与流程混写 | §4.2；权力表从执行顺序中独立 |
| refact-fable | ### 1.4 一个环节判不了 | §4.4、§5.2；把身份强度与未知显式化 |
| refact-fable | ### 1.5 执行架构与开发流程装在同一份文件里 | §0.1、§2 与 §3 分开 |
| refact-fable | ### 1.6 档位只有 T2 有正文 | §3.4；补齐三档执行形态 |
| refact-fable | ## 2. 设计原则 | **§1.6** P0–P5 + 两条推论；⚠ **抽查发现原缺**：P5「凡能落成代码的纪律必须落成」与「只能靠人转述的环节等于没有环节」整段无落点 |
| refact-fable | ## 3. 目标架构 | §2–§5 |
| refact-fable | ### 3.1 一套状态机，两个 Profile | §1.1、§2.3；撤销部署形态分层，保留内核两种契约对象 |
| refact-fable | #### 3.1.1 开发 Profile → 唯一状态机 的映射 | §3.3；对象/状态投影与合法边，取消两种部署 Profile 的命名。 |
| refact-fable | ### 3.2 执行者模型：三种 kind，一张登记表 | §2.3、§4.1；纠正人为 principal 而非 executor |
| refact-fable | ### 3.3 权力表：驱动 APPROVAL 类 interrupt 的唯一来源 | §4.2 |
| refact-fable | ### 3.4 人的通道：收件箱 + 回执 | §4.12；补对象展示、字段分级、决定持久化与触点观测；身份强制依 §4.4，不恢复旧签名拓扑。 |
| refact-fable | ### 3.5 路由：三值决策，模型只建议 | §2.1、§2.5；「分类节点只给四条判据的命中证据，不给 tier」补入 §2.1（**抽查发现原缺**） |
| refact-fable | ### 3.6 工单：一个冻结的 Artifact，一次确认 | §2.4、§3.1 |
| refact-fable | ### 3.7 工作区供给：纯函数，判据是独占与干净 | §3.2 |
| refact-fable | ### 3.8 状态判定与分发：一般化现有脚本 | **§3.18** 六条硬要求；⚠ **抽查发现原缺**「推导值 ≠ 声明值即报错」「边不在合法表即报错退出」「分发前角色冲突拒绝」 |
| refact-fable | ### 3.9 角色：supervisor 解体为五个各有定义的词 | §2.1、§2.2 |
| refact-fable | ### 3.10 开发 Profile ↔ 内核对象对照 | **§3.17** 对照表本体（**抽查发现原缺**：§3.3 是状态投影表，与「对象↔载体」不是同一张） |
| refact-fable | ### 3.11 git 载体的语义映射：什么是权威、什么是投影、什么验不了 | §5.4 |
| refact-fable | ### 3.12 验证分层：谁判什么 | §5.5；acceptor「既得利益最小、由处置表算出」与 L3「抽样规则写进工单」补入（**抽查发现原缺**） |
| refact-fable | ### 3.13 签名回执的威胁模型与密钥分布 | §4.4、§4.12、§5.13、§8.1；保留三类威胁、误签边界、环境取证，撤销旁路拓扑。 |
| refact-fable | #### 3.13.0 取证声明（先于事实） | §5.13；取证环境先于权限结论。 |
| refact-fable | #### 3.13.1 现状事实（2026-09-05；宿主身份由 opus / luna 复核，S1 前须按 3.13.0 重跑） | §4.4；同期凭据域与机器事实作为历史证据，开发前重核。 |
| refact-fable | #### 3.13.2 三道边界都要放在 agent 的 credential domain 之外 | 部分保留：§4.4、§8.1；保留凭据域外强制原则，拒绝组合旁路设施作为安全架构。 |
| refact-fable | #### 3.13.3 回执仓的对象模型：回执是仓内自己的签名 commit，不是跨仓 tag | 不采用：§8.1 K3–K6；特定签名存储对象模型不在真实动作路径上。 |
| refact-fable | #### 3.13.4 回执 schema | 部分保留：§4.12；批准对象/版本/验收内容保留，不继承特定回执 YAML schema。 |
| refact-fable | #### 3.13.5 两台机器的身份与凭据分布 | §4.4；保留人机共享凭据与工作站代做风险，不恢复已撤销 key 拓扑。 |
| refact-fable | #### 3.13.6 剩余风险（如实登记） | §4.4、§4.12、§5.13；保留误签、端点不可达、权限漂移与取证限制，丢弃绑定旧设施的操作步骤。 |
| refact-fable | ## 4. 对原建议的处置 | §8.2 |
| refact-fable | ## 5. 文档重构 | §0.1、§7.3、§10 |
| refact-fable | ### 5.1 目标文件树 | §0.1、§7.2；用真源职责取代一次性树形蓝图 |
| refact-fable | ### 5.2 旧 → 新映射：按旧文全部标题，脚本检查零缺口 | §10 |
| refact-fable | ### 5.3 删除条件 | §3.5、§7.3 |
| refact-fable | ## 6. 实施路线 | §7.1；按本轮核查重排为 G0–G5 |
| refact-fable | ## 7. 风险与未决 | §7.4、§9.2 |
| refact-fable | ## 8. 本方案自身的验收标准（供开轮时冻结） | §5、§7.3、§9、§10 |
| runtime-architecture | # 运行时架构：只有一个运行时，开发是它的第一个 Task Profile | §0、§1–§7；唯一运行时保留，被后继推翻的设计在 §8 明确隔离。 |
| runtime-architecture | ## 0. 一页摘要 | §0、§8.2 |
| runtime-architecture | ## 1. 本稿与上一轮的关系 | §8.2、§10 |
| runtime-architecture | ## 2. P1 — 一个运行时、唯一状态机、`dev.change`、五个 Agent Profile | §1.1、§2.3、§3 |
| runtime-architecture | ### 2.1 运行时 = 内核对象的唯一写入面 + 四个确定性组件 + 两个适配层 | §1.2、§2.1 |
| runtime-architecture | ### 2.2 Task Profile `dev.change` 版本 1 | §2.3、§2.4、§3；别名登记、`privacy`(NO ZDR)、观察窗中位数、`freshness` 四项补入 §2.4（**抽查发现原缺**） |
| runtime-architecture | #### 2.2.1 工单：一个冻结的 Artifact，一次确认 | §2.4、§3.1；冻结工单、窄包与两道门已在正文。 |
| runtime-architecture | ### 2.3 五个 Agent Profile：登记表 | **§2.12** 登记表本体 + `channel_grade`；⚠ **抽查发现原缺**（§2.3 只说「至少登记这些字段」，无取值） |
| runtime-architecture | ### 2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行 | §4.1、§4.2、**§4.11** 实例级清单；⚠ **抽查发现原缺**——而实例级清单正是上一轮 ⑤ 验收 `C-1` 抓出的缺项，**连丢两轮** |
| runtime-architecture | #### 2.4.1 本轮（`runtime`）已发生介入的逐条清单 | §4.11；12 次介入逐项清单，历史边归属不改作当前运行轨迹。 |
| runtime-architecture | ### 2.5 `dev.change` 的产物 → 唯一状态机 | §3.3 |
| runtime-architecture | ### 2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现 | §5.4、§7.2 |
| runtime-architecture | ### 2.7 等效判据：两层 + 投影 + 来源等级 + 比较上下文 | §5.3；`author_claimed` / `author_attested` 拆分补入（**抽查发现原缺**） |
| runtime-architecture | #### 2.7.1 S 层与 R 层 | §5.3；S/R 两层及静态权力约束。 |
| runtime-architecture | #### 2.7.2 R 层的轨迹条目 | §5.3；轨迹字段、双作者与来源等级。 |
| runtime-architecture | #### 2.7.3 `TraceEnvelope`（比较上下文，不是第五条序列） | §5.3；比较上下文字段完整保留，不另立 TraceEnvelope 内核对象。 |
| runtime-architecture | #### 2.7.4 比对规则（六条） | §5.3；六条比对规则与白名单、较粗粒度、最低来源上限。 |
| runtime-architecture | ### 2.8 trace 样例：`refact-fable` 轮的真实产物 | **§5.11** 轨迹表本体 + 对照组 + 引用纪律两条；⚠ **抽查发现原缺**——§5.3 只留了「23 条里 2 条」的读数，**结论在、证据不在** |
| runtime-architecture | ## 3. P2 — Interaction 双向带载荷：一个内核修订工作单元 | §4.3、§8.1 K1–K2；核查后不启动该修订 |
| runtime-architecture | ### 3.1 缺口 | §4.3；故意不要原缺口判断，因为现有自由 resume 原语已覆盖所述形状 |
| runtime-architecture | ### 3.2 扩展后的绑定字段表 | §4.3；故意不要自造字段表，缺少真实消费者与拒收用例 |
| runtime-architecture | ### 3.3 `amend` 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task | §3.3、§4.3；故意不要另开 Attempt，checkpoint 应原地恢复 |
| runtime-architecture | ### 3.4 与权力表的对应 | §4.2–§4.3；只保留实际 Interaction 与权力动作绑定 |
| runtime-architecture | ### 3.5 修订工作单元（按 `request-lifecycle.md:627` 修订纪律） | §1.1、§4.3；故意不要该单元，因其前提已被代码证伪 |
| runtime-architecture | ## 4. P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果 | §5.1–§5.2 |
| runtime-architecture | ### 4.1 粒度是三个字段，不是一个；至少四档 | §5.1；`codex exec --json` 的锚点取证补入 §2.12（**抽查发现原缺**，本次已复跑于 `7d6f808b`） |
| runtime-architecture | ### 4.2 五家的取值 | **§2.12** 读数三条 + 「机械非空不等于填对」的实例（**抽查发现原缺**） |
| runtime-architecture | ### 4.3 证据权威性：由粒度推导，不由执行者声明 | §5.2 |
| runtime-architecture | ### 4.4 三道边界是架构组件，不随脚手架拆 | §4.4、§8.1 K3–K6；故意不要组合设计，真实动作未经过这些设施 |
| runtime-architecture | #### 4.4.1 三道边界的具体形态 | 不采用：§8.1 K3–K6；保留 §4.4 真实强制点要求，不恢复三道旁路拓扑。 |
| runtime-architecture | #### 4.4.2 回执仓的对象模型：回执是仓内自己的签名 commit，不是跨仓 tag | 不采用：§8.1 K3–K6；不恢复特定签名存储对象模型。 |
| runtime-architecture | #### 4.4.3 回执 schema | 部分保留：§4.12；保留批准的内容与版本绑定，不恢复旧 YAML schema。 |
| runtime-architecture | ### 4.5 独占工作区在 CLI / GUI 腿是约定，不是隔离 | §3.2；「涉及第二租户或真实财务数据前必须经数据网关、不得给裸库凭据」补入（**抽查发现原缺**） |
| runtime-architecture | #### 4.5.1 工作区供给：纯函数，判据是独占与干净 | §3.2、§3.20；独占/干净/基线、工作区数量与实际提交能力。 |
| runtime-architecture | ### 4.6 R2：principal 通道也有粒度 | §4.4、§4.12、§5.2、§7.2；保留 channel_grade、不可预填批准与服务化身份前置。 |
| runtime-architecture | #### 4.6.1 人的通道：收件箱 + 回执 | §4.12；收件箱与持久决定、默认分级、触点观测；不恢复旧人执行器登记。 |
| runtime-architecture | #### 4.6.2 两台机器的身份与凭据分布 | §4.4、§5.13；机器/身份事实限定历史范围，批准强制不靠旧密钥分布。 |
| runtime-architecture | #### 4.6.3 剩余风险（如实登记） | §4.4、§4.12；误签、配置漂移、端点失败及工作站代理风险，排除旧设施专属补丁。 |
| runtime-architecture | ### 4.7 取证纪律与当前事实 | §4.4（含新补的三行现状事实：无 GPG 密钥、`id_rsa` 对主仓可写、Windows 侧亦跑本地 agent）、§8.1、§9 |
| runtime-architecture | ## 5. 必答 Q：运行时相对手工直接调用助手的开销盈亏线 | §6 |
| runtime-architecture | ### 5.1 分类规则（机械可判，全部由工单字段直接判） | §2.5、§6.1 |
| runtime-architecture | ### 5.2 反例（三类走运行时反而更贵的任务） | §6.2 |
| runtime-architecture | ### 5.3 T0 开销上界（复合向量，任一维超标即不标 T0） | §6.2 |
| runtime-architecture | ### 5.4 绕过的可观测性 | §6.3 |
| runtime-architecture | ## 6. 对 OP-1 / OP-2 / OP-3 的裁定 | §5.3、§6、§8.2；保留 OP-1/OP-3，按 K1/K2 撤销 OP-2 |
| runtime-architecture | ## 7. 覆盖声明、盲区与未验证项 | §7.4、§9 |
| runtime-architecture | ## 8. 自检：对照 `task.md` §8 十条 | §1.3、§8、§9、§10 |
| agent-dev-refact | # AI 助手开发框架 | §0、§0.3、§13；保留面向新参与者的单文入口，不继承历史稿的优先效力声明。 |
| agent-dev-refact | ## 0. 读这份文档之前 | §0.1、§0.3、§13；阅读路径与术语已在正文。 |
| agent-dev-refact | ### 0.1 它管什么，不管什么 | §0.1；保持架构、规则、任务、进度的职责分工。 |
| agent-dev-refact | ### 0.2 前置阅读 | §0.3、§5.8；开发操作无需 archive，具体代码改动仍核现行合同和硬约束。 |
| agent-dev-refact | ### 0.3 二十二个词，一句话一个 | §13；补七对象及 Profile、来源等级、等效、登记/路由两集合；不复刻第二套内核定义。 |
| agent-dev-refact | ### 0.4 编号索引 | §0.3、§13；H/T/E 编号索引保留，废弃路线编号改用 §7.1 G0–G5。 |
| agent-dev-refact | ## 1. 我们在建什么 | §0、§1、§2；保留一个产品运行时与开发投影。 |
| agent-dev-refact | ### 1.1 三层：什么租、什么建 | §2.6、§2.8；纪律自建、编排用库、执行 loop 租用。 |
| agent-dev-refact | ### 1.2 六条设计原则 | §1.6–§1.7；补 P6 与控制面可被复核的要求。 |
| agent-dev-refact | ### 1.3 先看六条已经被证伪的设计 | §8.1、§8.3；保留六项证伪教训，不采用“凭据即批准”“当前无需边界”的推论。 |
| agent-dev-refact | ## 2. 系统：一个运行时 | §2；结构总览已有正文。 |
| agent-dev-refact | ### 2.1 只有一个运行时，开发是它的第一个 Task Profile | §0、§1.1、§3.3；不将场景性的 Attempt 完成判断提升为全产品充要条件（§8.3）。 |
| agent-dev-refact | #### 运行时由什么组成 | §2.1；四组件与两适配层，不让 orchestrator 变为自由 Agent。 |
| agent-dev-refact | #### 路由：模型只建议，规则表才决定 | §2.1、§2.5；模型只提供证据、三值路由、命中理由/策略落账。 |
| agent-dev-refact | ### 2.2 开发 Task Profile：`dev.change` | §2.3–§2.4；保留开发契约字段，采用 dev.change/1，隐私不直接写“无”。 |
| agent-dev-refact | #### 2.2.1 工单：一个冻结的 Artifact，一次确认 | §2.4、§3.1；冻结 Artifact、proposal/effective/delta、开工触点分档。 |
| agent-dev-refact | #### 2.2.2 T0 怎么做到「开工前零触点」而不是把关卡默认掉 | §3.1；窄包、两道门、无自然语言假门禁；不采用已批准包可以免 H5 的外推。 |
| agent-dev-refact | #### 2.2.3 产物 → 状态机：每个内核状态都有落点 | §3.3；保留 Artifact 与状态分离及终态语义，按内核补拒绝/取消，不照抄错误简写边。 |
| agent-dev-refact | ### 2.3 执行者：Agent Profile | §2.3、§2.12、§3.20；能力登记和路由集分开，补身份命令失败处理；旧表仅历史示例。 |
| agent-dev-refact | ### 2.4 可观测粒度：三个字段，四档 | §5.1；三个正交字段、四档观测，不把自报事件变为强制证据。 |
| agent-dev-refact | ### 2.5 证据等级：能看多细，决定能不能信 | §5.2、§5.12；最低来源上限、重算和空集合 UNKNOWN。 |
| agent-dev-refact | ### 2.6 人：principal 与八条权力 | §4.1–§4.2；人是 requester/principal，持权不能由执行能力推导。 |
| agent-dev-refact | #### 人不是执行者 | §2.11、§4.1、§4.3；人的内容以 Artifact/响应进入，不登记为产品执行器。 |
| agent-dev-refact | #### 权力表 | §4.2、§4.4；H1–H8 与强制点保留；不继承“所有者动作本身就足够可信”的简化。 |
| agent-dev-refact | #### 推翻一件已经做完的事，落点是新 Task，不是问询 | §1.1、§4.3；终态不可重开，推翻终态结果建 supersedes 新 Task。 |
| agent-dev-refact | #### 无默认的字段不得预填 | §4.12；批准对象、字段分级、通知/收件箱分离；proposal 可展示，未决定 effective 为空。 |
| agent-dev-refact | #### 当前最尖锐的矛盾：这道关卡的证据强度是零 | §4.4、§5.2、§7.2；共享身份记录仅 reported，服务化不自动提升身份归因。 |
| agent-dev-refact | ### 2.7 中断与恢复：用库的原语，不自造协议 | §4.3；补按问询类型分层、人写 Artifact 的归属；不采用按作者类型强制换 Attempt。 |
| agent-dev-refact | ### 2.8 工作区供给 | §3.2、§3.10、§3.20；独占/干净/基线、多仓与人的未提交改动。 |
| agent-dev-refact | #### 工作区形态决定执行者能不能自己落账（2026-09-07 实测） | §3.20；保留私有 clone 与 Git 可写根的双条件实验及代提交退路，标历史未复跑。 |
| agent-dev-refact | ### 2.9 边界：哪些强制点是真的 | §4.4、§8.3；保留真实动作路径原则，排除无边界与授权即批准结论。 |
| agent-dev-refact | #### 一条实测结论 | §4.4、§5.13；宿主提权/凭据域是历史环境观测，不泛化当前全部进程。 |
| agent-dev-refact | #### 但当前不需要建任何边界 | 不采用：§8.3；未经过某套边界只证该方案无效，不证 H5 或安全边界不需要。 |
| agent-dev-refact | #### 真正的风险不是伪造，是只有一份 | 部分保留：§3.16、§7.4 风险 21；单机丢失风险须重核，不能据此自动 push 或压过授权风险。 |
| agent-dev-refact | #### 什么时候边界才需要建 | 部分保留：§4.4、§7.2；服务化、多主体、外部审计需要复核边界，不能当成此前免除边界的条件。 |
| agent-dev-refact | #### 但威胁模型要留着，因为它是对的 | §4.4、§4.12；伪造肯定、绕过副作用、工作站 agent 代批三种威胁与误签残余。 |
| agent-dev-refact | #### 取证纪律：取证工具自己也有边界 | §5.13；主机/身份/namespace、同实际环境复核；卫生检查不是强制点。 |
| agent-dev-refact | ### 2.10 角色：五个各有定义的词 | §2.1–§2.2；职责与角色分开；登记 roles_allowed 由分发门执行。 |
| agent-dev-refact | #### 为什么一直在长同名物 | §0.0、§1.7；用动作、权力、强制点回答问题，不靠再造 supervisor 名称。 |
| agent-dev-refact | ## 3. 流程：一轮怎么走 | §3；操作路径进入现行正文。 |
| agent-dev-refact | ### 3.1 档位：这件事该走多重的流程 | §2.5、§3.4；沿用基座风险判据，不采用以“问题已定”自行给权威文件降档。 |
| agent-dev-refact | ### 3.2 任何档位都不能省的三条 | §3.1、§3.4、§5.5；冻结标准、独立验收、不可逆批准三条不因档位消失。 |
| agent-dev-refact | ### 3.3 裁量权与方向不对称 | §1.6、§4.8；裁量保留理由、方向与改判记录。 |
| agent-dev-refact | #### 不可裁量的下限 | §1.7、§3.1、§4.2；设计核前提与不可单方放松底线。 |
| agent-dev-refact | #### 方向不对称 | §1.6–§1.7、§3.22；升严谨不突破预算，省事方向须批准。 |
| agent-dev-refact | #### 裁量是规则的孵化器 | §1.7、§7.4 风险 15；重复裁量反馈规则，不能静默覆盖政策。 |
| agent-dev-refact | ### 3.4 七个环节（T2 专用） | §3.19；七环节、来源异议、验收算法与人确认；按现行协议补齐并列处理。 |
| agent-dev-refact | ### 3.5 产物、路径与命名 | §3.19；按当前协议统一 reviews 子目录，不恢复旧稿平铺路径。 |
| agent-dev-refact | #### 环节通知：组织者的产物，不是发起人的话术 | §3.21；通知含取件、对象事实、范围、交付与截止，不在阶段中偷偷换输入。 |
| agent-dev-refact | ### 3.6 取件与检视面 | §3.21；冻结 commit 取件，分支只定位，不用可变分支头当对象。 |
| agent-dev-refact | #### 检视面：需要人读时开临时 worktree | §3.21；确认前准备实际可读的冻结对象，临时 worktree 有归属与清理条件。 |
| agent-dev-refact | ### 3.7 环节判定与判据自身的质量 | §3.18、§5.12；产物反推及判据覆盖声明。 |
| agent-dev-refact | #### 判据自身的质量：覆盖不全比没有更危险 | §5.12、§12.1；UNKNOWN、空集、空标题、吞退出码与窄覆盖假通过。 |
| agent-dev-refact | ### 3.8 逐环节的规则 | §3.19、§4.12；互评四块、处置表、异议与持久确认；不把执行者填“是”升为可信身份。 |
| agent-dev-refact | ### 3.9 停止、超时与回退 | §3.22；三处回退与次数上限，观察窗不足不可硬判。 |
| agent-dev-refact | ### 3.10 清理与发布 | §3.15–§3.16、§3.19；按现行保留条件先存证再清理发布，不一律按旧稿删/归档。 |
| agent-dev-refact | ### 3.11 验证分层：谁判什么，顺序不可换 | §5.5、§3.19；保留 L0–L3 分工，明确 L2 来源异议先于⑤的 L1，数字不是时序。 |
| agent-dev-refact | ### 3.12 状态判定与分发脚本的设计要点 | §3.18；补执行事件、人工桥接与“生成命令不等于执行”。 |
| agent-dev-refact | ### 3.13 文档的删除条件 | §7.3；升级为五稿正文覆盖与可读性条件，不把仅五条旧门当完整删除授权。 |
| agent-dev-refact | ## 4. 什么时候不该走这套流程 | §6；成本与风险分开，承认绕过观察不完备。 |
| agent-dev-refact | ### 4.1 机械可判的分类 | §6.1；只从可判字段判断收益，不从 tier 倒推成本。 |
| agent-dev-refact | ### 4.2 三类走流程反而更贵的活 | §6.2；三类成本反例保留，manual 的结论限定小任务。 |
| agent-dev-refact | ### 4.3 最轻档位的开销上界 | §6.2；四维上界与人的实际动作数，不隐去敲命令/传输成本。 |
| agent-dev-refact | ### 4.4 绕过看得见吗 | §6.3；补各 sink 覆盖与不可见面，追认仍须核 I1，不能伪造事前批准。 |
| agent-dev-refact | ## 5. 实测记录 | §5.11、§12.1–§12.2；保留历史失败机制，不把旧稿“全是实测”搬成本次证明。 |
| agent-dev-refact | ### 5.1 手工模式看起来在跑，轨迹却基本不可复原 | §5.11、§4.12；23 条轨迹与对照已在；人的决定须有独立对象/来源，不只让被决定方转述。 |
| agent-dev-refact | ### 5.2 判据给假答案：七次 | §12.1、§5.12；七类假答案完整进入正文，历史次数不当当前统计。 |
| agent-dev-refact | ### 5.3 未经现状核查的设计：六条 | §8.1、§1.7、§12.2；先验真实前提，不只验方案自洽性。 |
| agent-dev-refact | ### 5.4 并行竞争评比的边界 | §12.2、§1.7；外部对照与必要性检查保留，不预定至少删一项；缺列输入不能事后扣分。 |
| agent-dev-refact | ### 5.5 一条元观察 | §1.7、§12.2；控制面也需留痕、复算与被推翻；不移植未经本次核对的责任计数。 |
| agent-dev-refact | ## 6. 实施路线 | 部分保留：§7.1–§7.2、§7.7；以 G0–G5 替代旧 R/S 排期，不改当前进度。 |
| agent-dev-refact | #### 脚手架什么时候可以拆 | §7.2；补组件级等效、三轮验收对照、每路 Attempt 与身份前置；不把 Git 当事务/租约证明。 |
| agent-dev-refact | #### 等效判据：拿什么证明「换了实现，还是同一套东西」 | §5.3；S/R、投影、来源、上下文和差异白名单已完整。 |
| agent-dev-refact | #### 要改内核时，工作单元长什么样 | §7.7；补修订工作单元及不将 consumed 回填为 approved 的迁移纪律。 |
| agent-dev-refact | ### 6.1 已登记的未决项 | §7.4；相容风险保留并补单机副本/库 API 范围；不保留立即 push 等未授权动作建议。 |
| agent-dev-refact | ## 7. 覆盖声明、盲区与未验证 | §9.5、§5.13、§7.6；原作者核验范围保留其历史身份，不成为本次已运行验证。 |
| archive-README | # `archive/` —— 一条谱系的历史稿 | §0 的版本声明、§9.5、§10；保留一条谱系的来源身份，不是第二套开发规范。 |
| archive-README | ## 演变轨迹 | §9.5；两 lifecycle→refact-fable→runtime→兄弟分叉，之后直接补吸收；不再要求读图才能执行。 |
| archive-README | ## 两格：已结清 / 待结清 | §10；已落点与待处置转换为每标题明确处置，不继续沿用旧甲乙格状态。 |
| archive-README | ### 甲、已结清 —— 有逐节落点收据 | §10；四稿旧 182 行扩为完整层级索引，正文仍须复核。 |
| archive-README | ### 乙、待结清 —— **无收据，剩 76 节** | §10 的 agent-dev-refact 76 行；本次已逐节处置，不把“待吸收”保留成现状。 |
| archive-README | ## 一处欠账：承诺过的映射表从未产出 | §5.12、§7.3、§9.5；保留“映射承诺未进验收导致丢内容”的教训；不把历史缺表说成本次仍缺表。 |
| archive-README | ## 本目录不能删 —— 这是一条可判的条件，不是态度 | §7.3；未验正文不能删与可证伪性保留；日常内容必须有无需翻历史的落点。 |
| archive-README | ## 现在可以删了吗 | §7.3、§9.5；本次只移入相容内容，不声明其他删除门已过，也不实施删除。 |
| archive-README | ## 归档件怎么用 | §0.1、§5.13；历史无规范效力、注明来源与版本；不修改他人历史文件。 |
| archive-README | ## 引用它们的锚点 | §5.12–§5.13、§7.3；Markdown 与裸行号锚分别检查，历史软判不等于已验证。 |

## 旧版入口与组织上下文

旧标题前言、原章节理由/阅读路线及 README 旧计数是迁移证据；不作为新 pipeline 的操作指令。

<!-- I02-001 -->
### Agent 开发指导：一个产品运行时，一套开发纪律

> **底稿**：`runtime-refact` 轮定稿（基座作者 luna，2026-09-06）｜ 裁决方 opus 吸收 11 条
> **扩充一**：2026-09-07 opus 吸收两份 lifecycle 共 118 节，并逐节抽查出 50 处真缺、2 处落点判错
> **扩充二**：2026-09-08 **luna** 再吸收，以上一版 2402 行（k8s `d9f827f8`）为底稿，
> 对照同一快照下 `archive/` 五份历史正文与 README 补入相容内容，**并把 `agent-dev-refact.md`
> 的 76 节首次落点**。§10 由 182 行扩为 **294 行**（284 源节 + 10 README）。
>
> ⚠ **2026-09-08 由所有者裁定，本版取代前一版**（原文件名 `agent-dev-guide-gpt6.md`，
> 已改名为 `agent-dev-guide.md`）。取代前 opus 做的核验、以及**没做**的部分，见 §9.6。
> ⚠ **本文写作时的自述「不替换原 guide」已被该裁定取代**——保留此注是为了让
> §9.5 的记录仍可按成文时状态读。
>
> **阅读目标：日常开发不必再回 archive 拼接规则。**新增内容进入相应正文；
> §10 保存五稿 284 个标题与 README 10 个标题的处置索引，查沿革时才需阅读。
> 产品合同、代码硬约束和协作协议仍各有权威来源（§0.1）；本文提供开发操作入口，
> 不以历史稿覆盖它们，也不把旧稿里与底稿抵触的判断带回来。
>
> **证据时间边界：**继承的 SDK、部署、权限、测试与事故读数是各源作者在其钉定版本下的记录，
> 不是本次重新实测的结果。正文的“当前”“已核对”“本轮”须连同原版本和 §9 的作者/时间读；
> 用于新开发决策时按 §5.13 重新核验。此次文档补写的范围、取舍与验证见 §9.5。

<!-- I02-005 -->
### 为什么分成这些章

| 章 | 独立存在的理由 |
| --- | --- |
| §1 契约与边界 | 属权威约束，变更门槛高于实现结构，不能埋进组件说明 |
| §2 运行时结构 | 回答“谁负责什么”，不掺一次 Task 的时间顺序 |
| §3 开发执行 | 回答“一次请求怎样走”，可直接给开发者照做 |
| §4 人介入与权限 | 涉及身份和不可逆动作，必须从普通控制流中单列审计 |
| §5 证据与等效 | 决定哪些事实能信，不能与“流程跑完”混为一谈 |
| §6 成本与绕过 | 决定何时值得进入运行时，指标与正确性判据不同 |
| §7 演进路线 | 只写依赖顺序和退出条件，避免现状污染目标结构 |
| §8 核查裁定 | 保存本轮推翻旧设计的证据，防止同一错误复活 |
| §9 覆盖声明 | 让读者知道本文证据边界，不能散在各章脚注里 |
| §10 逐节落点 | 五份历史正文及目录说明的处置索引；标题齐全仍须结合正文核实 |
| §11 反模式 | 机制描述，与 §8「已被推翻的设计」不同：前者是任何项目都会踩的做法 |
| §12 失败实例 | 本项目**实际**踩过的，按证据强度分三级；与 §11 分开，防止把「机制上必然」写成「此处已核对」 |
| §13 词汇对照 | 内核对象名与本文用语的映射，独立成表才能被机械核 |
| §14 Task 模板 | 持久记录的最小字段集；空栏必须写「不适用」及理由 |

<!-- I02-006 -->
### 按工作阶段阅读，不按历史版本阅读

第一次读，先看本章的一条执行链、§1 的约束与 §13 的词汇。随后按下表定位，
不必先读迁移过程和历史稿。**默认只运行本次任务已授权且适用的动作；本文介绍并行轮次，
不代表每个开发请求都要开轮或自动增加参与方。**

| 你现在要做什么 | 本文入口 | 动作结束时应留下什么 |
| --- | --- | --- |
| 接任务、定边界 | §2.4、§3.1、§3.4、§14 | 原话、冻结工单、风险档位、独立验收要求 |
| 确定架构或接执行器 | §1.7、§2.6–§2.10 | 真实前提、SDK 能力三态、部署门禁与退路 |
| 开始写文件 | §3.2、§3.10、§3.20 | 独占工作区、基线、manifest、明确的 Git 写入权限 |
| 单路实施或组织并行 | §2.11、§3.13、§3.19–§3.22 | 每个 Work Unit 的结果、冻结对象与处置记录 |
| 等人、暂停、取消或恢复 | §4、§7.5 | 绑定具体对象的 Interaction、checkpoint、副作用账 |
| 验收、发布与清理 | §3.12、§3.15–§3.16、§5.5 | 最终固定版本的证据、批准、可重取交付与清理记录 |
| 遇到规则冲突或准备删旧稿 | §7.3、§7.7、§8、§10 | 冲突裁定、迁移落点和仍未验证的事项 |

一次性探索阅读按 §6 判断流程成本；没有文件产出时，不为形式统一造空仓。
涉及具体产品字段、生产现状、契约测试时，仍须回读对应代码与现行合同（§5.8）；
“只读一份开发指南”不等于“只读指南就能证明代码正确”。

<!-- I09-001 -->
### dev-plan — 代码要符合什么、接下来建什么

> 最后更新：2026-08-29

本目录管**开发**。判据是：**改了这里的东西，代码要跟着改。**

项目现在长什么样在 [`../project-guide/`](../../project-guide/)（那里改了，
只说明代码先变了）；我们怎么共事在 [`working/`](../working/)（那里改了，
代码不用动）。

| 文件 | 内容 | 什么时候读 |
| --- | --- | --- |
| [`constraints.md`](../constraints.md) | **代码必须符合的规则**，39 条按数据/契约/身份/拓扑/发布/智能体分组，每条标注谁在执行 | **动代码前** |
| [`development-plan.md`](../development-plan.md) | 要建什么、为什么这么建：起点、智能体通用/专用两分、四本账、执行层租用、三个阶段 | 想知道方向时 |
| [`implementation-plan.md`](../implementation-plan.md) | **任务本体**：每件事怎么做、怎么算做完。条目格式、测试层次、交付规则 | 要动手时 |
| [`handoff.md`](../handoff.md) | **状态与交接**：当前阶段、已就位的、未决项 U1–U5、不能倒退的输入 | 接手时先读 |
| `~/codex-reference-archive/` | **各助手的历史调研材料**（仓外，按助手分目录：`cursor/` `kimi/` `luna/` `opus/` `qwen3.8/`）：Codex 机制、SQLBot、WrenAI、沙箱、现状诊断。**已归档，可直接读**——不再是提案期的独立材料，引用时注明是谁的稿 | 定 U1–U5 时 |
| [`agent-dev-guide.md`](../agent-dev-guide.md) | **现行开发规范，这条谱系唯一的活文档**：不可变契约、运行时结构与**执行层/SDK 适配**、Task 执行与**并发处置**、人介入/权力表/**三道门与四档审批**、证据与等效、成本与绕过、演进路线、**反模式与失败实例**、词汇对照、Task 模板。§10 是四份源稿的逐节落点表（182 行） | 想知道系统怎么搭、怎么干活时 |
| [`archive/`](../archive/) | **一条谱系的历史稿**：两份 lifecycle → `refact-fable` → `runtime-architecture` → 分叉为 `agent-dev-refact` 与现行的 `agent-dev-guide`。分两格——甲格已有逐节落点收据，乙格 197 节**还没有**，待 `dev-plan-refact` 轮并入。无规范效力 | 追溯来龙去脉时；`archive/README.md` 有轨迹图 |
| [`protocol/`](../protocol/) | **流程规范 + 它的实现，放在一起**：`round-protocol.md`（七环节、档位 T0/T1/T2、裁量权与方向不对称、产物落点、环节判定、立判据的人怎么约束自己）与 `round-status.py` | 开一轮多家并行出稿前；跑流程脚本前 |
| [`anchor-gate.py`](../anchor-gate.py) | **锚点门禁**：`doc-gate` 只查 markdown 链接，查不到 `` `文件.md:行` `` 这类纯文本锚点——实测删掉被引文件后 `doc-gate --all` 仍报通过。本脚本补这一类：钉 commit 的锚在该 commit 内解析、裸路径锚对当前索引与外部取证仓解析、`rounds/**` 按归档软判 | 删或改被引用的文档前 |
| [`scripts/check-no-owner-creds.sh`](../scripts/check-no-owner-creds.sh) | **凭据卫生检查**（不是边界——本机 agent 可 `sudo`，能改它）：扫明文凭据、无口令 key、主仓是否对本机可写、提权面 | 边界变更前后 |
| [`doc-gate.py`](../doc-gate.py) | **文档不变量门禁**：仓内链接、章节引用、表格列数。由 `.githooks/pre-commit` 自动触发，不需要谁记得跑；`--survey` 巡检全仓、`--selfcheck` 查是否已安装 | 不用主动读；提交文档时它自己会说话 |

<!-- I09-002 -->
### 各文档的分工，别混写

| | 写什么 | 不写什么 |
| --- | --- | --- |
| `constraints.md` | 必须遵守的 | 现状、计划 |
| `agent-dev-guide.md` | **架构与开发纪律：怎么搭、怎么干、为什么** | 任务清单、进度 |
| `development-plan.md` | 目标与理由 | 进度、任务 |
| `implementation-plan.md` | 任务：怎么做、怎么算做完 | 状态叙述、架构论证 |
| `handoff.md` | **状态**：做到哪、卡在哪、什么不能倒退 | 论证与实施步骤 |

混写的后果是具体的：论证和状态放一起，读计划的被状态打断，查进度的要翻过论证；
规则和计划放一起，两边都不好用。
