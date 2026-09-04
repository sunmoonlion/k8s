# Refact 环节②评审 · cursor

> 作者：cursor（提案方兼评优方）  
> 日期：2026-09-04  
> 候选已冻结，本文件不改候选。  
> 取件方式：`git show <分支>:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md`，不从工作区文件取。  
> 枚举形状：`~/worktrees/*/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md`（5 条路径，有效候选 4 份；opus 是一字未改的基座，不参赛、不评分）。

**利益冲突声明。**评优方同时是 cursor 候选作者。这不是独立终审。下面的比较依据和 hash 可复核；裁决方（opus）可以推翻结论，但须指出具体标准与证据。本文**不选自己当基座**。

**本评审的盲区。**未把四家每一个 `file:line` 对着 `~/repo/codex` / `~/repo/deepseek-harness` / `~/repo/openclaw` 的当前 HEAD 重跑一遍；SDK 锚点以各家文内钉版（luna/cursor 写了 commit）互核，部署侧四条硬阻断和 `test_dormant_capabilities.py` 行号本轮对过工作区副本。未实跑两个 SDK，也未把 OpenClaw 联进 investment-app。对「Port 字段名」「Router 叫什么」这类设计题给的是比较，不是唯一解。

---

## A. 自述（cursor 候选）

冻结点：分支 `cursor`，commit `65cd113a4c82991fa45c81233f91c01a631c694f`，
SHA-256 `98da6c5bceedc9ddef9191a6f34af44a49dc34a8e77ee0556bdcf6f2aefc780b`。
此后未改候选。

### 改了基座哪些节、新增哪些节

相对 opus 基座（`70a7dd50` 上的 1161 行稿）是**追加为主、少量改写**：

| 位置 | 动作 |
| --- | --- |
| 文首 | 日期改为 2026-09-04；加两段：本文不是 `request-lifecycle.md` 的投影；两层协调者消歧指针 |
| §0.1 文档表 | 追加一行，指向 §15–§23 |
| §0.5 | **新增**：TaskRouter / AgentSupervisor 定名与关系 |
| §1.1 FastAPI 段 | 改写：FastAPI ≠ AgentSupervisor；与 TaskRouter 分工 |
| §6 开头 | 追加四行，钉死本节 supervisor = AgentSupervisor |
| §6.9 | **新增**（接在 §6.8 后）：内层不得改路由、换执行器、扩权 |
| §9 末 | 追加三行指针，指向 §20，并重申 AgentSupervisor 不获六行表任何一项 |
| §11.1 / §11.2 | **重写存续**：混合存续；删除条件从三条改为四条 |
| 附录 B 之后 | **新增 §15–§23**（路线、双 SDK、Port、门禁、部署、审批、OpenClaw、映射表、清理清单与 ⚠） |

不许动的清单（任务书 §7：§5、§7、§12、§13、§14、附录 A、附录 B）正文与 opus **逐字相同**。附录 B 后多一个换行，是因为 §15 接在附录后面，不是改附录内容。

### 哪些断言未验证、标了 ⚠

候选 §23.4 集中列出，文内亦有分散标记（候选 ⚠ 共 9 处，含基座原有的子仓不推、机械门禁未完成）：

- 未对 investment-app 实跑 `openai-codex` / `deepseek-harness-sdk` 端到端回合
- dsh wheel 能否从内网 PyPI 装到 worker 镜像（供应链，不是架构）
- 未把 OpenClaw 联调进本产品；OpenClaw 判断来自文档与代码结构
- 未对本轮生产库做 `\dt` 复核；业务表为 0 的判断来自 Alembic 链
- §20.4 代理与短 TTL 令牌尚未实现
- KIND 默认不 enforce NetworkPolicy（沿用 `constraints.md` 环境事实）
- 未评估问数准确率；未设计多租户配额产品语义

### 与基座的分歧

1. **存续。**基座 §11.1「开发结束后可能删除」。候选改判为混合存续：§0–§14 仍可按原条件删，§15–§22 必须先被 `development-plan.md`（或独立架构文档）吸收。这是任务书 §9.3 要求的显式处理，不是静默留着自相矛盾的句子。
2. **「supervisor」所指。**冻结章节正文未改字；用 §0.5 + 文首阅读规则 + §6.9 把未加限定的 supervisor 钉成 AgentSupervisor。基座没有控制面调度器这个角色。
3. **结构。**新内容放在附录 B **之后**，基座的阅读顺序是「正文 → 附录结束」。这是为了让 §5/§7 等冻结节的 `git diff` 干净，代价是成品不像一份读得完的指南——见下条「放弃」。

### 放弃了哪些本可以写但故意没写的内容，以及理由

1. **不把七块织进 §4。**本可以像 luna 那样接在物化门禁后面写执行层。故意追加在文末，理由当时是：冻结节哈希不被插入打散、评审方 `git diff master` 一眼能看见「只在尾巴」。现在看，这个取舍错在阅读顺序：附录之后又出现 §15–§23，不像可发布正文。**不建议最终稿沿用这个落点。**
2. **不改写冻结节里的 `supervisor` 用词。**本可以把 §6 标题改成 AgentSupervisor。故意不改，理由是任务书「一字不许改写」虽未列入 §6，但 §6 与冻结的 §5/§7 共用同一套称呼；改标题会让冻结节读起来像另一份文件。用阅读规则 + §6.9 消歧。
3. **不写任何具体 Profile 字段表、工具清单、金标准题量、行数上限。**任务书 §10；`request-lifecycle.md` §7.2 要求真实输入确认字段；业务表为 0。
4. **不裁决「首版一个窄 Profile vs preset 三角色」。**只留判据和前置（数据源 + Gate 0）。
5. **不把 OpenClaw 当控制面，也不写 ACP 联邦总线、Control UI、配对码。**借鉴切分，不转向。
6. **不把 Port 字段名写成已冻结 API。**§17.1 写明形状是开发合同，实施用契约测试钉死。故意不假装已经 `wired`。
7. **不把 AT-05…AT-21 逐条铺进映射表。**当时觉得 §22 按 `F-EXEC-*` / `F-INTERACT-*` 已经满足任务书 §9.2，AT 矩阵是产品契约的事。这是本候选相对 luna 的真实缺口（见 C.3），不是「AT 不重要」。
8. **不写 dsh `subagent-codex`、不写 Celery 12 进程 OOM 史、不引 `test_dormant_capabilities.py`。**当时用「生产引用数为 0」和 bundle 开关，认为够用。qwen 这三处更硬，评审时承认该吸收，提案期没写是为了控制篇幅，不是认为它们错。
9. **不把「更好」写成三条可证伪的 spike 退出标准。**写了三层判断和「当且仅当」条件，但没有 kimi §15.1 那种「不成立就退回自研 LangGraph / 退回 Codex 单腿」的证伪句。故意偏合同、少实验设计。
10. **不重编附录 A。**新术语只活在 §0.5 / §15。附录 A 在不许动清单里，只允许其后追加；我把追加用在了 §15，没给词汇表加行。

---

## B. 候选集冻结

枚举命令命中 5 个路径。下表 **4 份有效候选**均来自 `git show <分支>:…`，行数/字节/SHA-256 对 `git show` 的 stdout 计算（`wc -l` / `wc -c` / `sha256sum`），所在 commit 为该分支上该文件的最新提交。工作区 hash 本轮碰巧与提交一致，**仍以提交为准**。

| 作者 | worktree 路径 | 行 | 字节 | SHA-256 | 所在 commit |
| --- | --- | ---: | ---: | --- | --- |
| luna | `/home/zym/worktrees/luna/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1439 | 96181 | `3749a0c00bfe6258525f809ec7cc4cb396e4b9c7cc6877d88abfc10f27a5e3e2` | `f8bc48e3b4bc24fc0aec13065c3f7f9f4303c7ff` |
| kimi | `/home/zym/worktrees/kimi/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1605 | 107909 | `83f1d8f8caa346a3688724b2bdb5ad7c96dd8a5b85a629699ededf9044c0c99e` | `9fe438089ff11e52edd1f2101a880b845524534a` |
| cursor | `/home/zym/worktrees/cursor/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1649 | 113596 | `98da6c5bceedc9ddef9191a6f34af44a49dc34a8e77ee0556bdcf6f2aefc780b` | `65cd113a4c82991fa45c81233f91c01a631c694f` |
| qwen | `/home/zym/worktrees/qwen/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1560 | 105425 | `ea2bb7abf2d96047b4a203c24a2c0467107919c21d92fbfa2938e155468675fd` | `0c6f0fc362d1a61dd6ec39bdebc1b5def0304ff5` |

**不计入候选（基座，opus 本轮不参赛）：**

| 作者 | worktree 路径 | 行 | 字节 | SHA-256 | 文件所在 commit / 分支 HEAD |
| --- | --- | ---: | ---: | --- | --- |
| opus | `/home/zym/worktrees/opus/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1161 | 71204 | `a9533a45c6c19ba65aaab5e2146e93ffe6a3d6958f587ff1d3e9a916f121f2e5` | 文件停在 `70a7dd50a326f63fac7a7488a8f6a66414d6c643`；分支 HEAD `e7e37486897b843ba678d68d15ae832f9090132d`（后续提交未改此文件） |

相对基座的改动量（`difflib` 对 `git show` 文本）：luna +311/−33；kimi +450/−6；cursor +499/−11；qwen +404/−5。luna 对既有节改写最多（§0.3、§6 标题与开篇、§11、§4 插入），其余三家以追加为主。

---

## C. 评优（按 `refact-task.md` §12 逐条）

图例：通过 / 部分 / 缺口。比较依据写到节号或表，不靠票数。

### C.1 基座 §7 保留部分逐字未改；不许动清单全部成立

对 opus 文本按标题切块，§5 / §7 / §12 / §13 / §14 / 附录 A / 附录 B **四家与基座逐字相同**（cursor 仅附录 B 后多 1 个换行，因 §15 接在附录后）。

§6 不在不许动清单。luna 改了 §6 标题并把「拆 Task」写成「拆 Work Unit」；qwen 改标题并加 §6.0；cursor 加 §6.9；kimi 在 §6 内加了四行阅读规则。这些都不构成 C.1 失败。

**结论：四家通过。** luna 对非冻结节的改写更重，diff 噪音大，但冻结节守住了。

### C.2 §8 七块全部到位，核心断言带 `file:line` 或可复跑命令

七块在四家都有对应段落（luna 织进 §4.5–§4.11 / §8.1 / §9.1–§9.2；其余三家集中在 §15 起）。

锚点密度（粗计路径`:*数字*`）：luna 26 / kimi 47 / cursor 25 / qwen 66。密度不是质量。抽查部署四条硬阻断（investment bundle，本轮复核）：

| 阻断 | 工作区事实 | 四家 |
| --- | --- | --- |
| worker egress 无 `ipBlock` | `30-network-policies.yaml` 零命中 | 四家都写了；luna/kimi/qwen 给出行号或 `grep -c` |
| `readOnlyRootFilesystem: true` | `20-runtime.yaml:363`（worker） | 四家都写了；cursor/qwen 精确到 `:363` |
| 内存 768Mi | `20-runtime.yaml:360` | 四家都写了 |
| `AGENT_PILOT_LLM_*` 未配 | bundle 无此键；`:111-112` 只有 `AGENT_V4_TRAFFIC_ENABLED` / `AGENT_PILOT_ENABLED` = false | 四家都写了 |

SDK 侧四家都落到了任务书已查实的硬点：Codex `client.py:773-779` 默认 accept；`lib.rs:57` 去掉 chat wire；dsh protocol 三方法 + `:115` 无 cancel + `:116` server never sends；`sdk-runtime/README.md:5` 不需要系统 Node。luna 与 cursor 额外钉了核对提交（Codex `7d6f808b97…`、dsh `dd6322d604…`、OpenClaw `173f41d682b…`），升级必须重跑锚点——这比「只写文件名」可复验。

OpenClaw「两层路由都不是语义分类」：luna 给了 `src/routing/resolve-route.ts:57-80,745-793` 与 `src/agents/harness/selection.ts:102-124,221-260`；kimi/qwen/cursor 主要引 docs。**源码锚点赢文档转述。**

**结论：四家七块都在。证据质量 kimi/qwen/luna 优于 cursor 的「附录后长文」；luna 的 OpenClaw 源码锚点与「钉版重跑」最好。** cursor 的七块最像任务书目录，但落点差。

### C.3 新增内容用 `F-*` / `I*` / `AT-*` / `constraints.md` A/C/D/I/T/R 锚定，不许写成散文

这是 2026-09-03 失败整合栽过的那条，权重高于文风。

| 作者 | `F-EXEC-01…08` | `F-INTERACT-01/02` | `AT-*` 出现的编号 | constraints 风格 |
| --- | --- | --- | --- | --- |
| luna | 全 | 全 | AT-05/06/07/09/11/12/13/14/15/20/21 | A1–A5、C1/C2、D1/D4、T2/T3；部署表写「constraints I8、产品 I12」——**两套 I 编号分开写了** |
| kimi | 全 | 全 | AT-09/10/13/15 | A1/A3–A5、D1/D2/D4、T3；但把四条部署阻断标成 **D-1…D-4**，与 constraints D1–D4 撞号 |
| cursor | 全 | 全 | **只有 AT-01、AT-22**（文首声明那两头，映射表几乎不引 AT） | A1/A3–A5、C5、D4、T3；I 编号未标明来自哪份文档 |
| qwen | 全 | 全 | **只有 AT-01、AT-22** | A/C/D/T/R 最密（含 D8/D9、R2）；但 §15.6 把 `request-lifecycle.md` 的 I12 写成了 **`constraints.md` I12**——constraints 身份规则只到 I8，**这条引用是错的** |

luna 还把 `F-DISPATCH-*` / `F-ACCEPT-*` / `F-DELIVERY-*` 拉进执行层叙述。`F-DISPATCH-03` 原文是租户公平/优先级/并发/deadline，用来锚定「Profile→执行腿路由」是轻度越用；不构成 C.3 失败，整合时应改挂更贴的 ID 或写明「调度策略的开发投影」。

**结论：luna 明显领先。** cursor/qwen 的 AT 锚定不足，按本条不能当「已门禁化」。kimi 中等，但 D-1…D-4 必须改名。qwen 的 `constraints.md` I12 必须改回产品 I12。

### C.4 交出 §9.2 的两条腿映射表

四家都有全表（luna §8.1，kimi §15.9，cursor §22，qwen §15.8）。任务书要的词汇是「已支持 / 当前缺失 / 需补法」。luna 另用三态探针填表，信息量更高，但和任务书用词不完全同形。

**事实分歧（用证据裁，不用票数）：**

1. **dsh × F-EXEC-02（工具 I/O、版本、证据关联到 Attempt）。**  
   共同锚点：`packages/sdk/protocol/README.md:52`，`messageId` 只标识入队用户消息，不标识 assistant/turn 结束。  
   - luna：`explicit_unsupported`  
   - cursor / qwen：当前缺失，靠 `submit_result` 补  
   - kimi：**已支持（设计）**，理由是 `session.event` 全量可采，另标 ⚠ 词汇表投影未实证  
   **裁断：**F-EXEC-02 要的是关联到 Attempt，不是「有任何事件流就行」。无 turn 结束标识就不能保真绑定工具 I/O。kimi 自己的门禁表 G2 已承认逐 Turn 归属缺失，却在总表写成已支持——自相矛盾。判 **当前缺失 / explicit_unsupported**。kimi 这条输给带同一 `file:line` 但读对义务的三家。

2. **Codex × F-EXEC-03（每次高风险动作前重新校验）。**  
   共同锚点：`client.py:773-779` 默认对命令执行与文件改动 `accept`。  
   - qwen：标 **已支持**（有 `approval_mode` / handler）  
   - cursor / kimi：需补法（必须覆盖默认）  
   - luna：`available`（SDK 能接回调）但写明默认实现不可用  
   **裁断：**headless 生产不覆盖 handler = 无人在场自动放行，不满足 F-EXEC-03。qwen 的「已支持」过宽。luna 的三态最精确；任务书用词下应写 **需补法**。

3. **Codex × F-EXEC-05。**  
   luna：`implicit_fallback`（`thread_resume` 存在，本地 rollout 不是业务 checkpoint）。cursor/qwen：已支持。kimi：需补法。  
   **裁断：**产品 checkpoint 在 PostgreSQL / 对象存储（基座 §5.5、A3）。SDK resume 是必要非充分。luna/kimi 更贴义务；cursor 用「已支持」再补一句「仍须写 Postgres」容易被读成门禁已过。

**结论：表都交了。luna 的三态表最好用；kimi F-EXEC-02、qwen F-EXEC-03 Codex 过宽，整合时按上面裁断改，不要平均。**

### C.5 supervisor 消歧完成，不存在未说明的两层同名

四家都定了两层名字，并写了「内层只在上层路由完、权限收窄之后存在」：

| 作者 | 上层 | 内层 | 阅读规则 |
| --- | --- | --- | --- |
| luna | 调度监督器（dispatch supervisor） | 执行监督 Agent | 冻结节未加前缀的 supervisor = 内层；上层必须写全称 |
| kimi | Router | 执行 supervisor | 全文「supervisor」一律内层 |
| cursor | TaskRouter | AgentSupervisor | 冻结节未加限定 = AgentSupervisor |
| qwen | Dispatcher | Attempt 内协调 supervisor | §6.0 + §15.0 两处；§6 标题已改 |

qwen 把上层挂到 `F-DISPATCH-*`：责任投影里 `F-DISPATCH-*` 是后端队列/公平性，不是 Profile→执行腿路由器。名字能用，锚点要改。luna 允许「无工具、固定 schema、低预算的受限分类节点」在调度监督器给出的合法候选里选——这与「必须是确定性代码」并置，整合时要写清：分类器若存在，不能拥有队列、权限或终态（luna 已写），且分类调用必须入预算账（kimi/cursor 写了 I10 / `RunBudget` 未接线）。

cursor §6.9 把「不能改路由/换执行器/扩权」写成内层三条硬规则，是四处里最可执行的落点。luna 改了 §0.3 整节，阅读时不必跳到文末，消歧最不容易漏。

**结论：四家通过。** 最终稿建议：上层用一个英文标识（Router / TaskRouter / Dispatcher 三选一，不要再造第四个）+ 中文全称；冻结节保持 `supervisor` = 内层（luna/kimi/cursor 的阅读规则）；吸收 cursor §6.9。

### C.6 §9.3 存续声明已显式处理，并附引用清理清单

四家都加了第四个删除条件（架构判断先移走或被吸收），并列了 `AGENTS.md` / human 文 / `request-lifecycle.md`。

差别：

- **luna** 改写了 §11.1 开句：「现在是长期开发指南，不再以 Agent 路径开发结束作为删除理由」，清理表加了 `development-plan.md` 与实现矩阵。最干净。
- **kimi** 分两个存续级（§0–§14 vs §15），并评估三处引用「暂不改 / 不必改」——比「删除时再改」更可操作。
- **cursor** 开句改成混合存续，细节放到 §23.1 / §23.3，§11.2 与 §23 有重复。
- **qwen** §11.1 **仍保留基座开句「开发结束后可能删除」**，再用第 3 条把 §15 除外。任务做了，但开句与第 3 条对打，验收时容易被读成没处理。

**结论：luna / kimi / cursor 通过；qwen 算显式处理但开句未改，最终稿不要保留那句原文。**

### C.7 没有任何具体 Profile 的字段表

四家都只写方法（Profile/patch + 插件、dry-plan/query、显式提交、凭据互斥），并声明不写工具表/金标准题量。qwen 提到 `analyst / checker / awaiter` 是作为「下游对立主张、本轮不裁决」，不是字段表。

**结论：四家通过。**

### C.8 不重新定义 `request-lifecycle.md` 已定义的对象

四家都声明只引用。无人重列 I1–I15 定义表或 AT 矩阵。luna 对 §6 用词从「拆 Task」改为「拆 Work Unit」，是在纠正基座可能的产品/开发层混淆，不是重定义 Task。

**结论：四家通过。**

### C.9 「dsh 需要系统 Node」不得出现（已推翻的说法）

四家都写了 SDK 不需要系统 Node，并指向 `python/sdk-runtime/README.md:5` 与 `runtime/node/` 不被自动选择。无人把缺 Node 当阻断。

**结论：四家通过。**

### C.10 「能不能构建专业 agent」与「能不能接进生产控制面」分开表述

四家都有独立两轴。qwen §15.0 还点名 09-03 失败整合的那句「专业路线进入实施前」会被读成「专业 agent 建不了」——对最终稿有用。cursor §15.4 表格最不容易混。luna 写在 §4.6 末段，位置对（紧挨 SDK 事实）。

**结论：四家通过。**

### C.11 未验证的结论标注清楚；做不成的老实标 ⚠

| 作者 | ⚠ 次数（含基座原有） | 特点 |
| --- | --- | --- |
| luna | 5 | 成熟度「尚未更好」、内网 PyPI、具体 Profile 表是假设 |
| kimi | 9 | 三硬条件未经实证、KIND 陷阱、代理未建、F-EXEC-02 投影保真度 |
| cursor | 9 | §23.4 集中清单 |
| qwen | 7 | 补法未 runtime-verified、§15.9 整节停在 `defined` |

luna 的新 ⚠ 偏少：生产无 agent、OpenClaw 未联调、KIND 不 enforce，写进了正文但没都打 ⚠。不构成假装已门禁化，但不如 cursor/kimi 显眼。

kimi/cursor/qwen 都用基座 §5.2 四级词典把新内容标成 `defined` 而非 `wired`。luna 部署表也写了「`defined` 以下的现状」。

**结论：四家通过。** cursor/kimi 的集中 ⚠ 清单值得并进最终稿。

### 各家强项与缺陷（总览）

**luna**  
强：阅读顺序（物化之后立刻谈执行层，权限公式之后立刻谈三道门）；C.3 锚定（尤其 AT-* 与「constraints I vs 产品 I」分写）；映射表用三态；OpenClaw 源码 `file:line`；钉 SDK commit；§11 开句一次性改完。  
缺：对既有节改写多（§0.3/§6/对照表），与「尽量不动基座」的直觉相冲，但不犯 C.1；`F-DISPATCH-03` 轻度越用；生产代码（`ToolExecutionPort` / 休眠测试）取证不如另外三家；新 ⚠ 偏少；附录 A 未收新词。

**kimi**  
强：对基座几乎只追加；§0.5 消歧早；生产现状带 backend `file:line`；「更好」三条可证伪硬条件；Router 职责「做什么 / 不做什么」清楚；KIND 陷阱写进部署表。  
缺：F-EXEC-02 dsh 标已支持，与自己的 G2 打架；部署阻断 D-1…D-4 撞 constraints 编号；AT 覆盖窄于 luna；OpenClaw 偏文档。

**cursor（本家）**  
强：七块目录与任务书 §8 一一对应；§6.9 可执行；「熟路问数主链编排权不交给聊天循环」是别人没有的分层；Port 签名含 `submit_result` / `probe`；审批四档含 `auto-deny`；§23.4 ⚠ 清单；钉 SDK commit。  
缺：**附录后追加章节，不适合当发布基座**；AT-* 几乎缺席（C.3 明显弱于 luna）；映射表「已支持」有时过宽（F-EXEC-05 Codex）；constraints 与产品 I 编号未分写。

**qwen**  
强：`file:line` 最多；`test_dormant_capabilities.py:154/:182/:208` 比「引用数为 0」可复跑；Celery prefork OOM → 并发显式为 2 的血泪锚点；dsh `subagent-codex`；`grep` 零命中证明无 cancel；两轴开篇防 09-03 措辞陷阱。  
缺：§11.1 开句未改，与第 3 条对打；`constraints.md` I12 引用错误，且 I3/I5 在产品不变量与 constraints 身份规则之间切换时未始终加前缀；F-EXEC-03 Codex 过宽；Dispatcher↔`F-DISPATCH-*` 范畴不完全贴；AT 与 cursor 同样稀。

### 该选谁当基座，以及理由

**选 luna。**

不是因为「织进 §4 好看」，而是验收标准里**上次栽过的那条（C.3）luna 独到**，且七块落在生命周期正文该在的位置（物化之后、执行内核之前、权限公式之后），整合方不必先把一篇附录后论文搬回目录。冻结节逐字保留成立。映射表的三态与 C.4 的证据裁断一致。存续开句没有自相矛盾。

不选 cursor：利益冲突之外，结构落点不合格，AT 锚定不合格。  
不选 kimi：对基座最礼貌，但 F-EXEC-02 过宽是事实错误，编号撞车会把下一轮整合再次写成散文。  
不选 qwen：取证往往最硬，但错误引用 `constraints.md` I12、存续开句未改、F-EXEC-03 过宽，当基座会把这些缺陷变成正文默认。

luna 当基座之后，**必须**按 D 节吸收另外三家，否则会重演 09-03「弄丢落选稿里的锚点」。

---

## D. 值得吸收的点（无论基座是谁）

每条：出自谁、在哪一节、为什么值得。裁决方请逐条给接受 / 部分接受 / 拒绝。默认基座 = luna；下列是 luna **没有或明显更弱**、应从落选稿并入的主张。

1. **出自 kimi §15.1：「更好」的三条可证伪硬条件（事件投影保真 / 金标准不劣于 Codex 单腿 / worker 进程稳定），不成立则退回指定备选。** luna 有三层判断，但没有「证伪就换腿」的退出句。防止自我说服。标 ⚠：三条都未经实证。

2. **出自 kimi §15 引言 + cursor §16.3 + qwen §15.2 事实⑥：生产无 agent 的代码锚点。** 至少并入 `ToolExecutionPort`（`tools.py:40`）、`RunBudget` / `SandboxPort` / `CancelRunCommand` 定义但未接线、`AGENT_V4_TRAFFIC_ENABLED: 'false'`（`00-prerequisites.yaml:111`）。luna 写了成熟度 ⚠，没有这些 `file:line`。

3. **出自 qwen §15.2 事实⑥：用 `test_dormant_capabilities.py:154`（RunBudget）、`:182`（Attempt 未落库）、`:208`（CancelRunCommand 无 HTTP）代替「引用数为 0」。** 本轮复核行号属实。比 grep 计数稳定——测试就是登记表。

4. **出自 qwen §15.5：Celery 继承节点 CPU、默认 12 个 prefork 打爆 768Mi，模板已把并发钉成 2（`00-prerequisites.yaml:109`，历史见 architecture-v2 证据稿）。** 这把「prefork 后创建 SDK、不跨 fork 共享」从纪律变成有死者的纪律。luna 写了 prefork 规则，没写这次事故。

5. **出自 qwen §15.2 事实①：dsh 自带 `subagent-codex`，能把真实 Codex 子会话当专业腿下级。** 影响 Port / 凭据互斥：专业腿若再 spawn Codex，通用凭据边界必须写进 Adapter 禁令，否则「两条腿凭据互斥」被内部委派打穿。luna 未写。

6. **出自 qwen §15.2 事实②：`grep -rnE "interrupt|cancel|steer|abort" python/sdk/src/` = 0。** 与 protocol README 互补：README 说没有，grep 证明 Python 门面也没有。门禁 G1 应用双锚点。

7. **出自 qwen §15.0：禁止把门禁写成「专业路线进入实施前」。** 这是 09-03 的原话陷阱。luna 已经分了两轴，最终稿应保留这句禁令，避免下一轮整合再踩。

8. **出自 cursor §15.1 / §15.2：熟路（已能画边的问数主链）编排权留在控制面，不交给聊天循环；租用的是通用/生路循环。** luna 的假二分表没有「熟路 vs 生路」。没有这条，租用容易被读成「所有执行都进 Codex/dsh」。

9. **出自 cursor §6.9：内层三条硬规则（不能改路由 / 不能换执行器 / 不能扩权），`worker_kind` 在 Attempt 创建时钉死。** luna 散写在 §0.3 / §6 开篇。收成内层清单，冻结的 §6 不必改字。

10. **出自 cursor §17.1：Port 上的 `submit_result` 与三态 `probe` 是签名的一部分，不是 Adapter 私货。** luna 的 Port 有 `start/resume/cancel/events/inspect/close` 和独立 `capabilities()`，没有把「未提交不算完成」做成方法。dsh 补法依赖它，应进签名或进 Adapter 必选契约。

11. **出自 cursor §20.3：审批超时独立成态，不折成 `auto-deny`，以免污染审计。** luna §9.2 已有更完整的四档（`auto-deny` / `auto-allow` / `llm-review` / `human-approval`）和超时 fail-closed，但没把「超时」从「拒绝」里拆开。最终稿用 luna 的档名，吸收 cursor 的超时分态。

12. **出自 cursor §23.4：文末集中 ⚠ 清单。** luna 的 ⚠ 散在表里。最终稿在存续/附录前保留一节「本轮未验证」，避免读者以为七块都已 runtime-verified。

13. **出自 kimi §15.7：spawn 前环境清洗——harness 子进程只放白名单变量，DB/Redis 凭据不下发。** 理由：沙箱限写不限读，继承全量环境 = 把凭据递给模型（I12）。luna §9.2 写了真 key 不下发到推理代理，没写 spawn 环境白名单。

14. **出自 kimi §11.2 连带引用清单：三处引用「暂不改 / 不必改」的评估，而不是只给删除时处置。** 本轮不改那些文件；luna 的清理表偏「删除时才动」。两表应并存：现在怎么读、将来怎么删。

15. **出自 kimi §15.2：Router 的「不做」清单——不拆 Work Unit、不收候选、不选优；v1 不做 LLM 动态编排。** luna 的调度监督器职责偏「能做什么」。最终稿需要负向清单，避免上层长成第三个 agent。

16. **出自 kimi §15.6 部署表 ⚠：KIND 默认不执行 NetworkPolicy，D-1/B1 的包级验证必须另起 Calico。** luna 写了「Calico 环境实际验证」，kimi/cursor 把它标成 ⚠ 陷阱。应保留 ⚠。

17. **出自 cursor §0.5：附录 A 已有的「产品 supervisor 拆子 Task」是第三套名字，既不是 TaskRouter 也不是 AgentSupervisor。** luna 消歧了两层，没点名这第三套。三套并列可防下一轮再撞。

18. **出自 qwen §15.4 补法表：dsh teardown 的 `client.py:94/:117/:124`（close → terminate → kill）。** luna 写了梯子，没有 dsh 客户端行号。两腿梯子应分别锚到 SDK。

19. **出自 luna 自己、但另外三家没有、基座最终稿必须保住的点（防 09-03 再丢）：**  
    - 映射表用三态而不是「已支持（设计）」；  
    - OpenClaw `resolve-route.ts` / `selection.ts` 源码锚点；  
    - 钉 Codex/dsh/OpenClaw commit，升级重跑；  
    - AT-05…AT-21 进门禁与恢复段落；  
    - 「constraints I8 vs 产品 I12」这种分写，禁止再出现 qwen 那种 `constraints.md` I12。

20. **命名吸收（设计题，不是事实题）：** 上层标识建议采用 kimi 的 **Router** 或 cursor 的 **TaskRouter**（短、可进代码符号），中文保留 luna 的「调度监督器」作全称。不建议采用 qwen 的 Dispatcher 作为唯一名，以免与 `F-DISPATCH-*` 绑死。内层保持基座用词 `supervisor`，luna 的「执行监督 Agent」可作解释性全称。不要在最终稿并存四个上层名字。

---

## 本评审自检

- A/B/C/D 四块齐全。  
- 候选 4 份，未把 opus 算进评分。  
- 利益冲突已声明，且结论未选本家。  
- 事实分歧（F-EXEC-02 dsh、F-EXEC-03 Codex）按锚点裁，不按「几家这么写」。  
- 候选文件本轮未改。
