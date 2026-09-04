# Refact 轮 · 环节② 互评 · qwen

> 作者：qwen（工作目录 `~/worktrees/qwen/k8s`，分支 `qwen`）
> 日期：2026-09-04
> 规则依据：`round-protocol.md` §4（评审四块 A/B/C/D）；验收标准：`refact-task.md` §12（11 条）
> 评审对象：环节① 四份候选（luna / kimi / cursor / qwen）。opus 那份是一字未改的基座，opus 任裁决与整合方、本轮不参赛，不计入候选、不评。
>
> **利益冲突声明（round-protocol §4 C 要求）**：本评审作者 qwen 同时是四份候选之一（`qwen`）的作者。以下评优**不是独立终审**。凡涉及 qwen 候选处，一律就低不就高、并单列其短板（见 A.5、C.2、D.4）；结论给可复核依据与固定 hash，裁决方（opus）可推翻，但须指出具体标准与证据。
>
> **裁决方法**：事实题用证据裁、不用票数裁（round-protocol §4）。本轮四家的 `file:line` 锚点我逐一抽验约 20 处，**全部命中**（含 luna/cursor 的 SDK 版本 pin、kimi 的可复跑 `grep=0`、cursor 的部署行号）——所以「谁有证据」不是区分点，区分点在**证据可复现性、结构可发布性、内容完整度、§9.3 存续处理**。

---

## A. 自述（关于 qwen 自己的候选）

### A.1 改了基座哪些节、新增哪些节

按 `git diff master qwen` 核对（5 处删除、404 处新增，全部落在非冻结区）：

| 位置 | 改动 |
| --- | --- |
| 头部 | 日期改 2026-09-04；加 3 段引言（执行器架构进本文、两轴分开、supervisor 以 §15.0 消歧为准、不重定义 `request-lifecycle.md` 对象） |
| §0.1 | 共同模型表加一行，声明 `development-lifecycle-human.md` 与本文各自长期自足 |
| §6 | 标题「Agent 作为 supervisor」→「Agent 作为 **Attempt 内协调 supervisor**」；新增 §6.0「两层 supervisor 消歧（先读）」 |
| §11.1 | 生效边界加第 3 条：§15 执行器架构判断非纯开发期内容，删除前须先移出或已被 `development-plan.md` / `constraints.md` 吸收 |
| §11.2 | 删除条件「三个」→「四个」，加第 4 条（同上）；引用清理表保持 |
| §15（新增） | §15.0–§15.9 共 373 行，置于 §14 之后、附录 A 之前（附录仍在全文最末） |

§15 子节：15.0 两轴+两层 supervisor 消歧；15.1 路线转向（租不自建）；15.2 两个 SDK 核实事实与能力不对称；15.3 统一执行 Port + 三态探针；15.4 Harness 门禁 G1–G7 + 未过补法；15.5 双 runtime 部署 + 快照恢复 + 有界恢复；15.6 门禁/凭据/审批；15.7 OpenClaw 借鉴不转向；15.8 F-EXEC/F-INTERACT 双腿映射（12 行）；15.9 专用 Agent 构建判据（不写字段表）+ 下游线前置。

### A.2 与基座的分歧

1. **§6 标题改名**。基座叫「Agent 作为 supervisor」，我加限定词「Attempt 内协调 supervisor」。这与 kimi/cursor 不同——他们**保留 §6 原标题不动**、只加一段说明；cursor 还显式声明「未加限定的 supervisor 在冻结章节（§5/§6/§7/§12）里一律指 Attempt 内的 AgentSupervisor」。就 criterion 5 的安全性而言，**保留原标题 + 显式声明冻结章节用法**（cursor 的做法）比我改标题更稳，因为冻结区里仍有裸「supervisor」，改标题会让裸词与新限定词并存。这是我处理得不如 cursor 的一处。
2. **§11 存续**。基座说「本文开发结束后可能删除」。我选的路径是**保留开发期性质、给删除条件加第 4 条**（§15 须先被吸收才可删）。kimi/cursor 选**改判存续性质**（拆成两级/混合：§0–§14 开发期可删、§15/§15–§22 架构判断长期）。cursor 更进一步，**显式点出**「人那份头部仍写 agent 那份开发结束后会删除，吸收完成前那句与本文不一致」并登记进清理清单。我的第 4 条达到了类似效果，但没有 cursor 那样把「与人稿头部的矛盾」挑明——cursor 更彻底。

### A.3 标了 ⚠ 的未验证断言（7 处）

两个 SDK 未在本项目端到端实跑；dsh 的 wheel 能否从内网 PyPI 镜像装到（供应链，非架构）；部署四条硬阻断（worker 无模型 egress、只读根文件系统、768Mi 内存、模型凭据未进 bundle）当前未解；出口代理与 Attempt 级短 TTL 令牌尚未实现；业务数据源为 0（未对生产库做 `\dt` 复核）；OpenClaw 未联调进本产品；「用 dsh 建几个专业 agent、角色怎么分」为下游未决。

### A.4 故意没写、但本可以写的内容及理由

| 放弃的内容 | 理由 |
| --- | --- |
| 任何具体 Profile 的字段表（如 `investment-finance-analysis-v1` 的工具清单、`financial_query` 行数上限、金标准题量） | `refact-task.md` §10 明令不写；且 `request-lifecycle.md` §7.2 要求首项工作用真实输入确认字段，而业务数据现为 0 张表，写了等于把未验证设计固化成纪律 |
| 「用 dsh 建几个专业 agent、每个装什么、角色怎么分」的决定 | §10 要求本轮只留判据、不做决定；这是下游另一条线的题，前置是财务数据源与 Gate 0 spike |
| Port 的完整代码签名（`class ExecutionPort(Protocol)` 一类） | **当时的取舍**：本轮是架构判断稿，Port 的字段名属实施期用契约测试钉死的东西，过早写死会与 §10「不写实例字段」的精神相悖；我用散文 + 三态表描述 Port 边界。**但须诚实承认**：§8 block3 字面要求「签名」，luna/kimi/cursor 都给了签名（且都注明「形状是开发合同、字段实施时钉死、不是 Profile 实例」，规避了 §10），比我更贴合 block3。这是取舍偏保守，见 A.5 |
| 重编号 / 移动冻结章节 | doc-gate L2 要求 §N 引用在本文件有对应标题，冻结区内部大量 §N 交叉引用；重编号会牵动全篇且违反「冻结区一字不改」。故 §15 只追加、不重排 |

### A.5 自陈：qwen 候选的三个具体短板（非故意，是欠交付）

用可复跑的计数对照四家（`git show <branch>:<path>` 后 grep）：

1. **没有把新增内容锚到具体 `AT-*`。** criterion 3 明列 `AT-*` 为必需锚点之一。我的全文只有头部一处「AT-01…AT-22 一律以那份为准」的**范围引用**，没有把 F-EXEC/F-INTERACT 逐条映射到具体验收测试。**luna 用了 11 个不同 AT-\*（AT-05/06/07/09/11/12/13/14/15/20/21）、kimi 用了 4 个（AT-09/10/13/15）**；cursor 与我一样只有范围引用。这一条 luna 明显最强，我明显欠交付。
2. **没写 Port 代码签名。** 见 A.4——luna/kimi/cursor 都写了 Protocol/形状，我没写。
3. **没钉 SDK/repo 版本 commit。** 我给了 66 处 `file:line`（四家最多），但没 pin codex/dsh/openclaw 的 HEAD commit。**luna 与 cursor 都 pin 了三个仓的 commit**（codex `7d6f808b`、dsh `dd6322d6`、openclaw `173f41d6`），并写「升级钉版必须重跑锚点」——repo 一旦移动，我的行号锚点会漂，他们的 commit pin 不会。可复现性上我弱于 luna/cursor。

qwen 的相对强项（客观陈述，交裁决方判断，不自评高下）：`file:line` 锚点密度最高（66）；§9.2 映射表用了 §12 要求的精确图例（已支持/当前缺失/需补法，9/6/11 次）；两轴表 + 两层 supervisor 表 + 「Dispatcher 必须确定性代码」三理由齐备（§15.0）；结构上附录留在全文最末（单 §15，无需搬迁）。

---

## B. 候选集冻结

**取件方式**：一律按各家分支的 commit 取，不从工作区文件取（`round-protocol.md` §3：工作区会变、提交不会）。命令 `git show <分支>:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md`。下表 行数/字节/SHA-256 均对该 committed blob 计算。

| 候选 | worktree 路径 | 行数 | 字节 | SHA-256 | 所在 commit |
| --- | --- | --- | --- | --- | --- |
| luna | `~/worktrees/luna/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1439 | 96181 | `3749a0c00bfe6258525f809ec7cc4cb396e4b9c7cc6877d88abfc10f27a5e3e2` | `f8bc48e3b4bc24fc0aec13065c3f7f9f4303c7ff` |
| kimi | `~/worktrees/kimi/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1605 | 107909 | `83f1d8f8caa346a3688724b2bdb5ad7c96dd8a5b85a629699ededf9044c0c99e` | `9fe438089ff11e52edd1f2101a880b845524534a` |
| cursor | `~/worktrees/cursor/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1649 | 113596 | `98da6c5bceedc9ddef9191a6f34af44a49dc34a8e77ee0556bdcf6f2aefc780b` | `65cd113a4c82991fa45c81233f91c01a631c694f` |
| qwen | `~/worktrees/qwen/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1560 | 105425 | `ea2bb7abf2d96047b4a203c24a2c0467107919c21d92fbfa2938e155468675fd` | `0c6f0fc362d1a61dd6ec39bdebc1b5def0304ff5` |

**opus 排除留痕**（不计入候选、不评，仅证明「5 路径命中、有效候选 4 份」）：`~/worktrees/opus/k8s/...development-lifecycle-agent.md` 的 committed blob（commit `e7e37486897b843ba678d68d15ae832f9090132d`，1161 行，71204 字节）SHA-256 = `a9533a45c6c19ba65aaab5e2146e93ffe6a3d6958f587ff1d3e9a916f121f2e5`，与 `~/master/k8s` 基座文件逐字节相同——确系一字未改的基座。

四份候选 SHA-256 互不相同，且都与基座不同，确认四家都实质改写了基座。**少一份评分作废**（round-protocol §3 的 2026-09-02 事故）——本表 4 份齐全。

---

## C. 评优

### C.1 逐条对照 `refact-task.md` §12 的 11 条验收标准

四家都过了硬门槛（criterion 1/2/4/5/6/7/8/9/10/11 全部成立，见下）；**真正拉开差距的是 criterion 3 的 `AT-*` 维度、证据可复现性、结构可发布性、§9.3 处理深度**。表内 ✓=达标、◎=该维度最强、△=达标但有欠交付。

| §12 标准 | luna | kimi | cursor | qwen |
| --- | --- | --- | --- | --- |
| 1 冻结区逐字未改 | ✓ | ✓ | ✓ | ✓ |
| 2 七块到位+file:line/可复跑锚点 | ◎ pin+rg | ✓ grep=0 | ◎ pin+rg | △ 无pin/无可复跑命令 |
| 3 F-*/I*/**AT-**/A-D-I-T-R 锚定 | ◎ AT×11 | ✓ AT×4 | △ AT仅范围 | △ AT仅范围 |
| 4 §9.2 两条腿映射表 | ✓ 三态标签 | ◎ 精确图例 | ◎ 图例+映射三态 | ✓ 精确图例 |
| 5 supervisor 消歧无残留歧义 | △ 改名致冻结区裸词 | ✓ 保留+声明 | ◎ 三层消歧+点名冻结区 | ✓ 改名+§6.0 |
| 6 §9.3 存续显式处理+清理清单 | △ 整篇长期(与人稿冲突) | ✓ 两级拆分 | ◎ 混合+挑明人稿矛盾+行号清单 | ✓ 加第4条 |
| 7 无具体 Profile 字段表 | ✓ | ✓ | ✓ | ✓ |
| 8 不重定义契约对象 | ✓ | ✓ | ◎ 头部显式声明 | ✓ |
| 9 无「dsh 需系统 Node」正面断言 | ✓ | ✓ | ✓ | ✓ |
| 10 两轴分开表述 | ✓ | ◎ | ✓ | ◎ 两轴表 |
| 11 未验证标 ⚠ | △ ⚠×5 | ◎ ⚠×9+可证伪条件 | ◎ ⚠×9+专节 | ✓ ⚠×7 |

criterion 1 复核方式：对四家 `git diff --unified=0 master <branch>` 的 hunk 落点逐一核对，**冻结区（§5:325-453、§7:573-796、§12:980-1000、§13:1001-1037、§14:1038-1077、附录A:1078-1102、附录B:1103-1161）内部零删除**，所有落在冻结区边界的 hunk 都是 0-删除的纯追加。四家都守住了「一字不改、只在其后追加」。

### C.2 各家强项与缺陷

**luna**（1439 行，308 增/30 删，整合式：内容织进 §4.5–§4.11 + §8.1 + §9.1/§9.2）
- 强项：① **证据可复现性最佳**——pin 了 codex/dsh/openclaw 三个 commit，并给可复跑 `rg` 零命中证明（`ipBlock`、`AGENT_PILOT_LLM_`）；② **AT-\* 锚定最强**（11 个），把 F-EXEC/F-INTERACT 逐条挂到验收测试；③ 独有洞见：Codex async 客户端实为 `_call_sync` 包装到 worker thread（`async_client.py:161-183`，我已复核属实），故「不能由 async 关键字推断并发/teardown 安全」；④ 三态探针用得最密（27 次）；⑤ 整合式结构让执行器内容紧邻相关基座材料（§4 物化、§9 权限）。
- 缺陷：① **§9.3 处理最弱**——把整篇改判「长期开发指南」，与 `development-lifecycle-human.md` 头部「agent 那份开发结束后会删除」直接冲突，且 luna 未挑明这处矛盾；② **删除最多（30 行）**，对非冻结基座文本改写最激进，回归风险最高；③ 把 184 行执行器架构塞进 §4「sandbox 与 Git 物化」，撑大了 §4 原有范围；④ 映射表用三态标签而非 §9.2 点名的「已支持/当前缺失/需补法」（语义等价，措辞不符）；⑤ 把内层改名「执行监督 Agent」后，冻结区残留的裸「supervisor」未显式映射；⑥ ⚠ 最少（5）。

**kimi**（1605 行，450 增/6 删，单 §15.1–§15.10 置于附录 A 前）
- 强项：① **认识论纪律最佳**——§15 开篇即「当前生产事实（2026-09-04 亲核，可复跑）：生产环境没有任何 agent 在跑」，逐个对象按 §5.2 四级词典判为 `defined`（不是 `wired`），全节立足可核实现状；② **可证伪硬条件**——把「更好」写成三条 Gate 0 spike 退出标准并标「⚠ 三条都未经实证……不是既成事实」（"防止自我说服"），最贴 criterion 11；③ **supervisor 消歧最省扰动**——保留「supervisor」=内层（§0.3/§6 全文用法不变），只给上层新名 Router，冻结区裸词天然一致；④ 能力不对称表带「Port 侧处置」列（"处置不允许是当它们一样"）；⑤ 可复跑 `grep -rli "portfolio\|holding\|ticker\|instrument" …/alembic/versions/ | wc -l` = 0（我已复跑=0），坐实「不写 Profile 字段表」；⑥ §9.2 精确图例（已支持10/当前缺失4/需补法8）；⑦ ⚠ 最多（9）；⑧ 独有洞见：租 SDK 把「机制与模型的 co-design」一起租来。
- 缺陷：① **没 pin SDK/repo 版本 commit**（可复现性弱于 luna/cursor）；② AT-* 只 4 个（优于 cursor/qwen，远逊 luna）；③ 三态词用得最少（9 次）；④ 内容完整度略逊 cursor（无 Fake-worker 可测性论证、无三层 supervisor 消歧）。

**cursor**（1649 行，498 增/10 删，§15–§23 九个顶层节置于**附录 B 之后**）
- 强项：① **内容最完整**——九个顶层节覆盖全部七块且最细；② **§9.3 处理最佳**——「混合存续」（§0–§14 开发期可删 / §15–§22 架构判断须先移入 `development-plan.md` 才可删），并**显式挑明**「人那份头部仍写 agent 那份会删除，吸收前那句与本文不一致」，登记进带行号的清理清单（AGENTS.md:22、human.md 约 8-10/792、request-lifecycle.md 19/27/49）；③ **独有洞见：Port 的存在理由是「纪律层能用 Fake worker 测」**（否则每次测试都要真起 runtime+凭据）——比「将来可能换」更硬；④ supervisor **三层消歧**（TaskRouter 控制面 / AgentSupervisor Attempt 内 / 产品子 Task 编排属 `request-lifecycle.md`，"三套名字不要再混"），并新增 §6.9「内层不得改路由/换执行器/扩权」；⑤ 头部显式声明「本文不是 `request-lifecycle.md` 的投影……I1–I15、AT-01…AT-22 一律以那份为准，不重新定义」（criterion 8 最稳）；⑥ pin 三仓 commit；⑦ §19.1 ⚠「KIND 默认不 enforce NetworkPolicy，包级验证须另起 Calico」——环境事实级 caveat；⑧ §20「超时 fail-closed 独立成态，不折成 auto-deny 以免污染审计」；⑨ §21.2 把 OpenClaw「Admission 先于执行」映射到我方 `create_run` 入闸语义（F-DISPATCH-*，"HTTP 200 ≠ 模型已跑完"）；⑩ 四级词典用得最密（16）、⚠ 专节（§23.4）。
- 缺陷：① **结构可发布性最差**——§15–§23 放在附录 A/附录 B **之后**，编号节出现在附录后，违反「附录居末」的出版惯例，作为可直接发布稿需先搬迁；② 九个顶层节使顶层目录碎片化（§22 等仅一节无子节）；③ AT-* 只有范围引用（无逐条映射，与 qwen 同缺）；④ `file:line` 密度最低（25）；⑤ §17.1 列了 WorkerStart/WorkerHandle 具体字段名，最贴实施（虽注明「不是 Profile 实例、字段实施时钉死」而合规 §10，但对判断稿偏重）。

**qwen（本评审作者，就低自评）**
- 强项：`file:line` 密度最高（66）；§9.2 精确图例；两轴表 + 两层 supervisor 表 + 三理由齐备；单 §15 结构、附录居末、无需搬迁；冻结区逐字未改。
- 缺陷（见 A.5）：**无具体 AT-\* 映射、无 Port 签名、无版本 pin**——criterion 3 的 AT-* 维度、§8 block3 的「签名」、证据可复现性三处欠交付，且这三处分别被 luna（AT×11、pin）、cursor（pin、签名）、kimi（签名）覆盖得更好。§6 改标题不如 cursor 保留+声明稳；§9.3 未挑明与人稿头部的矛盾，不如 cursor 彻底。

### C.3 结论：四份排序 + 该选谁当基座

**利益冲突声明正是为据证自评而设**（`round-protocol.md` §4-C「指出每份候选的强项与缺陷」）：评优覆盖全部 4 份、包括 qwen 自己那份，不因我是作者就回避排序。综合 §12 逐条 + 证据可复现性 + 结构可发布性 + §9.3 深度，四份排序如下（可复核、可推翻）：

| 排序 | 候选 | 依据（强项 → 主要缺陷） |
| --- | --- | --- |
| 1 | kimi | as-delivered 即可发布（单 §15、附录居末、supervisor 保留=内层故冻结区零扰动）+ 认识论纪律最佳（生产=defined）+ 可证伪硬条件 + 精确图例 + 可复跑 grep=0 → 无版本 pin、AT-* 仅 4、完整度略逊 cursor |
| 2 | cursor | 内容最完整 + §9.3 最佳（混合存续+挑明人稿矛盾+行号清理）+ Fake-worker 可测性论证 + 三层消歧 + §6.9 + 版本 pin → 结构缺陷（§15–§23 在附录后须搬迁）、AT-* 仅范围引用 |
| 3 | luna | 证据可复现性最佳（pin 三仓 commit + 可复跑 rg 零命中）+ AT-* 最强（11 个）+ 独有 async=worker-thread 洞见 + 整合式附录居末 → §9.3 最弱（整篇长期与人稿头部冲突且未挑明）、删除最多（30 行、回归风险最高）、§4 范围撑大、⚠ 最少 |
| 4 | qwen（本评审作者） | file:line 密度最高（66）+ 精确图例 + 两轴/两层/三理由齐备 + 单 §15 结构干净 → 三处欠交付：无具体 AT-* 映射（criterion 3）、无 Port 签名（block3）、无版本 pin（可复现性）；且 §6 改标题不如 cursor/kimi 稳、§9.3 未挑明人稿矛盾、独有洞见最少 |

**该选谁当基座：kimi（排序第 1）。** 基座是裁决方据以吸收的骨架，结构可发布性优先于内容深度——深度可从别家吸收，结构缺陷要动手术。kimi 是唯一 as-delivered 无需搬迁者；其短板（无 pin、AT-* 少、深度）恰是可从 luna/cursor 吸收的加性缺口。cursor 内容最深、§9.3 最佳，但 §15–§23 在附录之后须整体搬迁 + 合并九节，列第 2；若裁决方更重内容完整度并愿承担一次结构手术，cursor 是合理替代。luna 整合式虽附录居末，但 30 行删除 + §4 撑大 + §9.3 与人稿冲突，回归面最大，列第 3。

**qwen 自评第 4，缺陷明确如下（不因自评而回避，也不因自谦而虚报）：**

1. **criterion 3 的 AT-\* 维度欠交付**：全文只有头部一处「AT-01…AT-22」范围引用，没把 F-EXEC/F-INTERACT 逐条挂到具体验收测试。§12 criterion 3 明列 AT-*，且括注「上一次整合栽在这里」——luna（11 个）、kimi（4 个）都补上了，我没补。
2. **§8 block3 的「签名」欠交付**：block3 字面要求「统一执行 Port：签名、通用 DTO、Adapter 边界、三态探针」，我只写散文 + 三态表，没给 Port 签名；luna/kimi/cursor 都给了（且注明「形状是合同、字段实施时钉死、非 Profile 实例」以合规 §10）。
3. **证据可复现性最弱**：66 处 file:line 是四家最多，但没 pin 任何 commit；repo 一移动行号就漂。luna/cursor 都 pin 了 codex/dsh/openclaw 三仓 commit。密度高 ≠ 可复现。
4. **次要**：§6 改标题（而非 cursor/kimi 的保留原标题 + 声明）使冻结区裸「supervisor」的映射不如 cursor 显式；§9.3 未像 cursor 那样挑明与人稿头部的矛盾；无 Fake-worker 论证、无「生产=defined」地基、无三层消歧——独有洞见少于另三家。

第 3（luna）与第 4（qwen）接近：qwen 胜在结构干净、删除少（5 vs 30）、file:line 密、§9.3 比 luna 安全；luna 胜在 AT-*（criterion 3 最重维度、且是上次整合的翻车点）、版本 pin、Port 签名、独有 async 洞见。tie-break 落在 §12 最强调的 ID 锚定（含 AT-*）与证据可复现性上，故 luna 第 3、qwen 第 4。

（原「回避声明」撤销：`round-protocol.md` §4-C 的利益冲突声明是为**据证自评**而设，不是为回避排序而设。以上第 4 名及其缺陷即为自评结果；裁决方可推翻，但须指出具体标准与证据。）

---

## D. 值得吸收的点（不管选谁当基座，逐条列其他候选里值得并进最终稿的主张）

每条注明：出自谁 / 在哪一节 / 为什么值得。这是裁决阶段最有用的输入（round-protocol §4 D）。

### D.1 出自 luna

1. **三个参照仓的 commit pin + 「升级钉版必须重跑锚点」**（§4.6、§4.11）：codex `7d6f808b97e424da80271be8cc539e8c5437a229`、dsh `dd6322d604e00eec1ba5e0c8541159906a21094a`、openclaw `173f41d682b0d4a05674820a3d390d934da8b066`（我已 `rev-parse` 复核：codex/dsh 与当前 HEAD 逐字符相同）。**为什么值得**：`file:line` 会随 repo 移动而漂，commit pin 不会；这是把「事实核到某版」变成可复现纪律的唯一办法。最终稿所有外部锚点都应挂 commit。
2. **Codex「async」实为同步调用包装到 worker thread**（§4.9，锚 `~/repo/codex/sdk/python/src/openai_codex/async_client.py:161-183,293-295`，我已复核：`thread_start/resume/list/read` 皆走 `self._call_sync(...)`）→「并发与 teardown 必须做负载/故障注入，不能由 `async` 关键字推断安全」。**为什么值得**：这是四家里唯一指出「async 门面不等于真异步安全」的，直接决定 worker 并发模型与 teardown 的测试要求。
3. **可复跑 `rg` 零命中证明**（§4.9 部署四阻断）：`rg -n 'ipBlock' …/30-network-policies.yaml` 零命中、`rg -n 'AGENT_PILOT_LLM_' …/bundle` 零命中。**为什么值得**：把「没有出口/没有模型凭据」从断言变成读者可自证的命令，证据等级高于单纯 `file:line`。
4. **AT-\* 逐条映射**（§8.1 映射表「需补法与验收」列）：F-EXEC-01→AT-05、F-EXEC-04→AT-13/21、F-EXEC-05→AT-09/12/15/20 等 11 个。**为什么值得**：criterion 3 明列 AT-*；有了它，「门禁过不过」落到具体验收测试而非定性。最终稿的映射表应补齐 luna 这套 AT-* 列。
5. **OpenClaw 两层路由的源码级区分**（§4.11，锚 `src/routing/resolve-route.ts:57-80,745-793` 与 `src/agents/harness/selection.ts:102-124,221-260`）：channel binding 与 provider/model route 选择「两层都不读取用户语义来决定专业领域」。**为什么值得**：用 TS 源码而非仅文档坐实「OpenClaw 路由非语义」，是「借鉴不转向」最硬的证据。

### D.2 出自 kimi

6. **「当前生产事实：没有任何 agent 在跑，按 §5.2 四级词典全部 `defined`」**（§15 引言，锚 `tools.py:40`/`sandbox.py`/`commands.py`/`first_m1_graph.py`/`config.py:134`/`00-prerequisites.yaml:111`）。**为什么值得**：给整个执行器章节一个可核实的认识论地基——所有主张都是「设计落点」而非「已接线」，杜绝把目标态写成现状。最终稿应把这句现状判断放在 §15 之首。
7. **可证伪硬条件 + 「⚠ 是 Gate 0 spike 退出标准、不是既成事实」**（§15.1）：双腿事件流忠实投影（否则退回自研 LangGraph 重估）、dsh `submit_result`+preset 在金标准上不劣于「Codex 单腿+`output_schema`」对照组（否则专业腿改回 Codex）、harness 进程模型在 worker 里稳定。**为什么值得**：把「更好」写成能被证伪的条款，"防止自我说服"，是 criterion 11 的模范写法。
8. **能力不对称表的「Port 侧处置」列**（§15.3）：每条不对称都给出 Port 侧处置，且「处置不允许是当它们一样」。**为什么值得**：block2 要求「能力不对称必须写进 Port」，kimi 把它做成可执行的处置列，而非只列差异。
9. **可复跑 `grep … alembic/versions/ | wc -l` = 0**（§15.10，我已复跑=0）坐实业务数据为 0。**为什么值得**：这是「不写 Profile 字段表」的事实依据，用命令而非断言给出。
10. **「租 SDK 把机制与模型的 co-design 一起租来」**（§15.1 租用理由）。**为什么值得**：给「执行层租用」补了一条比「省成本」更本质的理由——可靠性复利在长尾（重试/断点/预算/compaction），且这些与模型是协同设计的。
11. **OpenClaw 文档反证 Router 形态**（§15.8，锚 `docs/channels/channel-routing.md:11`「the model does not choose a channel」、`docs/agent-runtime-architecture.md:44-48`「auto 是确定性解析」，我已复核属实）。**为什么值得**：用外部项目独立佐证「路由=确定性配置解析、不是模型判断」，与 §9.1「Supervisor 必须确定性代码」互为印证。

### D.3 出自 cursor

12. **Port 的存在理由是「纪律层能用 Fake worker 测」**（§17，三份实现 `FakeAgentWorker`/`CodexAgentWorker`/`HarnessAgentWorker`）。**为什么值得**：这是四家里唯一把 Port 从「将来可能换」提升到「否则每次测试都要真起 runtime+凭据」的可测性论证——直接决定测试策略，应并入最终稿的 Port 节。
13. **supervisor 三层消歧**（§0.5）：TaskRouter（控制面）/ AgentSupervisor（Attempt 内）/ 产品子 Task 编排（属 `request-lifecycle.md`），「三套名字不要再混」；并显式声明「未加限定的 supervisor 在冻结章节 §5/§6/§7/§12 一律指 AgentSupervisor」。**为什么值得**：criterion 5 要求「新版内不存在两处 supervisor 指代不同层而未说明」，cursor 是唯一连冻结区裸词与产品层子 Task 都点名区分的，消歧最彻底。
14. **新增 §6.9「内层不得改路由、换执行器、扩权」**（`worker_kind` 创建时钉死；不得为「这个子任务更像财务」临时 `new DeepSeekHarness()`；不得把 deny 工具重注册或把 human-review 降成 Codex 默认 accept）。**为什么值得**：把 §9.1「内层在上层收窄后才存在」落成基座 §6 里可执行的三条禁令，比抽象声明更抗误用。
15. **§9.3 混合存续 + 挑明与人稿头部的矛盾 + 带行号清理清单**（§23.1/§23.3）。**为什么值得**：criterion 6 要求「显式处理、不能沉默留着自相矛盾的存续声明」；cursor 是唯一把「人那份头部说本文会删除、与本文不一致」这处矛盾**挑明并登记**的，且清理清单给到 AGENTS.md:22、human.md 约 8-10/792、request-lifecycle.md 19/27/49 的行号——最可执行。
16. **头部「本文不是 `request-lifecycle.md` 的投影……I1–I15、AT-01…AT-22 一律以那份为准，不重新定义」**（criterion 8）。**为什么值得**：把「不重定义契约对象」写成开篇声明，比散落各处更醒目，参照 `development-lifecycle-human.md` 头部写法。
17. **§19.1 ⚠「KIND 默认不 enforce NetworkPolicy，包级验证须另起 Calico」**。**为什么值得**：这是环境事实级 caveat——开发环境（KIND）里 NetworkPolicy 不生效，「worker 无 egress」的阻断只在生产 Calico 下成立；不写清会让人在 KIND 里误以为出口已通。
18. **§20「超时 fail-closed 独立成态，不折成 auto-deny 以免污染审计」+ §21.2「Admission 先于执行 → `create_run` 只表示入闸（F-DISPATCH-*），HTTP 200 ≠ 模型已跑完」。** **为什么值得**：前者是审计账的精确性（超时既非拒也非批），后者把 OpenClaw 机制精确映射到我方 F-DISPATCH-* 语义，防止把「受理成功」误读成「执行完成」。
19. **§16.1「Codex 子 thread（`thread_fork`）不宜作产品 TaskRouter：产品身份/预算/SSE 会落到 Codex 会话文件上，违反 A3 与 I13；Codex 只宜当 worker」。** **为什么值得**：堵住一条诱人但违约的捷径（用 Codex 内部 fan-out 当产品级调度）。

### D.4 出自 qwen（本评审作者，主动回避自评高下；仅列客观独有项供裁决方取用）

20. **两轴表 + 两层 supervisor 表 + 「Dispatcher 必须确定性代码」三理由集中于 §15.0**，且三理由严格对齐 §9.1（代价不对称 / 不可解释违 I15 / 分类调用要预算而 `RunBudget` 生产休眠）。裁决方若采纳，宜与 kimi §0.5、cursor §0.5 合并取最省扰动的命名（保留「supervisor」=内层）。
21. **`file:line` 锚点密度最高（66 处）**：若最终稿需要把某条断言落到行号，qwen 候选可作锚点检索源——但须按 D.1 第 1 条补 commit pin 后才可复现。

---

## E. 本评审的盲区自陈（round-protocol §9：评审同样是产出，同样要自陈盲区）

1. **未独立实跑**：我未实跑任何 SDK、未起部署、未对生产库 `\dt`。对「生产没有 agent 在跑」的确认依赖四家一致 + kimi 的可复跑 `grep=0` + 我在环节① 读过的 `test_dormant_capabilities.py`，非独立运行证据。所有判断与四家一样处于 `defined` 层。
2. **锚点抽验非全量**：我逐一复核了约 20 处 distinctive 锚点（luna 的 SDK pin/`async_client`/`00-prerequisites`/`config-tools.md`、kimi 的 `client.py:252`/`config_toml.rs:270`/`protocol:113-116`/`preset:12`/`channel-routing.md:11`/`agent-runtime-architecture.md:44-48`/`why-openclaw.md:87`/`sandboxing.md:23`/`grep=0`、cursor 的 `protocol:114`/`20-runtime.yaml:178,283-284,360,363`/`00-prerequisites:109`/`exec.md:66,81`/`VISION.md:129`/`constraints C5`），**全部命中**；但四家合计约 160 处 `file:line`，未抽到的若有误，不在本评审覆盖内。
3. **AT-\* 语义未逐条核对**：我确认了 luna/kimi 引用的 AT 编号存在于 `request-lifecycle.md`，但未逐条核对 AT-05/07/09… 的验收内容是否与其所映射的 F-EXEC **精确对应**（需通读 `request-lifecycle.md` §11 全文）。若某家 AT 映射语义错位，本评审未逮住。
4. **未读其他评审**：luna、cursor 已提交各自 `refact-review-*.md`，kimi 尚未。为保持互评独立（避免 herding、符合「证据裁不票数裁」），我**只读四份候选的 committed blob，未读任何其他评审**。代价：可能漏掉他们指认、而我没注意到的候选缺陷或优点。
5. **结构判断的前提**：我判 cursor「§15–§23 在附录之后」为可发布性缺陷，前提是「附录应居编号节之末」的出版惯例。若本项目另有惯例（附录可居中），此判断需裁决方复核。
6. **利益冲突**：我是 qwen 作者。对 qwen 的三处短板（A.5）力求诚实自贬、对 kimi 的推荐力求据证，但自评难免有偏；裁决方（opus）应以证据独立复核，本评审结论可被推翻。
