# Refact 评审 · kimi

> 环节 ② 互评，2026-09-04。对象：四份候选 `working/development-lifecycle-agent.md`
> （luna / kimi / cursor / qwen）。流程见 [`../round-protocol.md`](../round-protocol.md) §4，
> 验收标准见 [`../refact-task.md`](../refact-task.md) §12。
>
> **利益冲突声明**：我是 kimi 份的作者，本评审同时给自家候选排名与缺陷。裁决方可推翻
> 我的排序，但请指出具体标准与证据。事实题我按证据裁：凡他家锚点我抽查过的，注明
> 「抽核属实」；没核的不替他背书。
>
> **评审盲区自陈**：四份候选我逐字读了 diff 全文，但各家锚点我只抽查了 5 处
> （见 C 块），未逐行复核全部 `file:line`；各家候选在 doc-gate 下是否通过我未重跑
> （commit 钩子在各家提交时已跑过一次）。luna 的 OpenClaw 源码锚点我只抽核了
> `resolve-route.ts` 一处，`selection.ts` 未核。

## A. 自述（kimi 份）

**改了基座哪些节**：头部（日期 + §15 指引段）；新增 §0.5（supervisor 消歧：Router /
执行 supervisor）；§6.1 末尾加一段（内层三不得）；§11.1/§11.2 重写（两存续级 +
删除条件四 + 连带引用评估表）；新增 §15.0–§15.10（七块内容 + 双腿映射表 + 留判）。
冻结节（§5、§7、§12、§13、§14、附录 A/B）一字未动，可用
`git diff master kimi -- <路径>` 复核：删除行仅 6 行（日期、§11.1 引言 2 行、
§11.2「三个条件」句、§11.2 结尾 2 行）。

**标了 ⚠ 的未验证断言**：§15.1 三条硬条件（spike 退出标准）；§15.3 Codex 沙箱
「限写不限读」（无官方锚点，只论断）；§15.5 `submit_result` 引擎自觉性；
§15.6 KIND 不 enforce NetworkPolicy 的验证陷阱；§15.7 推理代理未建；
§15.3 dsh wheel 内网 PyPI 可装性。

**与基座的分歧**：仅 §11 存续性质——基座写「开发结束后可能删除」，我改判为
两存续级（§0–§14 开发期 / §15 架构判断须先移交）。这是 refact-task §9.3 要求的
显式处理，不是静默改动。

**放弃了哪些本可以写但故意没写的**：

1. **外部仓取证 commit 钉版**。我核了锚点但没记录核时 commit。luna 与 cursor 都钉了
   （Codex `7d6f808b`、dsh `dd6322d6`、OpenClaw `173f41d6`）。这是我没想到位的，
   不是判断后的放弃——如实登记为缺陷。
2. **OpenClaw 源码级锚点**。我只核到文档层（why-openclaw.md 等），判断源码核实
   成本高。luna 核到了 `src/routing/resolve-route.ts` 与 `src/agents/harness/selection.ts`，
   证明可核且更硬。这是我取证深度不足。
3. **dsh 进程内机制的细节**（`ctx.tools.guard` 单调 deny、`user-approval` fail-closed、
   `subagent-codex`）。我知道这些包存在，但只写了一句「审批接缝」，没展开为证据。
   qwen 展开了，且由此把 F-EXEC-01 dsh 腿判为「已支持（进程内）」，比我的粗判更有据。
4. **「熟路编排权留在我们手里」这条边界**。我 09-02 旧稿有（静态图骨架不换），候选
   里丢了；cursor §15.2 硬条件 2 写明了。该吸收。
5. **具体 Profile 字段表、下游专业 agent 建几个**——refact-task §10 明令不写，
   这是守规矩不是遗漏。

## B. 候选集冻结

枚举形状 `~/worktrees/*/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md`
命中 5 份；opus 份经核与 master 逐字相同（`git diff master opus -- <路径>` 为空，
SHA-256 与 master 一致：`a9533a45…`），是未改基座，不计入、不评审。以下快照均按
`git show <分支>:<路径>` 取件，不取工作区文件：

| 作者 | worktree 路径 | 行数 | 字节数 | SHA-256 | commit |
| --- | --- | --- | --- | --- | --- |
| luna | `~/worktrees/luna/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1439 | 96181 | `3749a0c00bfe6258525f809ec7cc4cb396e4b9c7cc6877d88abfc10f27a5e3e2` | `f8bc48e3b4bc24fc0aec13065c3f7f9f4303c7ff` |
| kimi | `~/worktrees/kimi/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1605 | 107909 | `83f1d8f8caa346a3688724b2bdb5ad7c96dd8a5b85a629699ededf9044c0c99e` | `9fe438089ff11e52edd1f2101a880b845524534a` |
| cursor | `~/worktrees/cursor/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1649 | 113596 | `98da6c5bceedc9ddef9191a6f34af44a49dc34a8e77ee0556bdcf6f2aefc780b` | `65cd113a4c82991fa45c81233f91c01a631c694f` |
| qwen | `~/worktrees/qwen/k8s/sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md` | 1560 | 105425 | `ea2bb7abf2d96047b4a203c24a2c0467107919c21d92fbfa2938e155468675fd` | `0c6f0fc362d1a61dd6ec39bdebc1b5def0304ff5` |

## C. 评优（四份全覆盖，含排序与自评缺陷）

逐条对照 refact-task §12 的 11 条验收标准。

**标准 1（冻结节逐字未改）**：四家均通过。luna 改了 §0.3/§6 标题/§11 对照表，
cursor 改了 §1.1 FastAPI 段与 §6 引言，qwen 改了 §6 标题、§0.1 表一行，我改了
§0.5/§6.1/§11——全部在允许改动的节内，冻结节（§5、§7、§12、§13、§14、附录 A/B）
四家均未触碰。cursor 头部把「冻结章节」写成（§5、§6、§7、§12），§6 实际不在任务书
冻结清单里且它自己改了 §6——小瑕疵，不影响合规。

**标准 2（七块全部到位、核心断言带锚点）**：四家都齐了七块。luna 落在 §4.5–§4.11 +
§8.1 + §9.1–9.2；cursor 落在 §15–§21；qwen 落在 §15.1–§15.7；我落在 §15.1–§15.8。
锚点质量分层明显：**luna 最硬**（三仓取证 commit 钉版；OpenClaw 核到
`src/routing/resolve-route.ts:57-80,745-793` 与 `src/agents/harness/selection.ts:102-124`
源码层；Codex async client 的 worker-thread 包装 `async_client.py:161-183`）。
**qwen 次之**（生产未接线用 dormant 登记表 `test_dormant_capabilities.py:154/182/208`——
抽核属实；prefork OOM 教训锚到 `evidence/R4-investment-result.md:21-22` + 模板提交
`7f2942c`；dsh teardown ladder 锚到 `client.py:94/117/124`——抽核属实；
`ApprovalMode` 只有两档 `_approval_mode.py:13-17`——抽核属实）。**cursor 再次之**
（api.py 行号锚点抽核 `:737-739` interrupt 属实；但「默认 12 进程打爆 768Mi」无锚点，
qwen 恰恰有这个锚点）。**我最薄**（未钉 commit；OpenClaw 只有文档层锚点）。

**标准 3（新增内容用 F-*/I*/AT-*/A-R 编号锚定）**：四家都达标，密度 luna、cursor
略高（几乎每个论断挂编号），qwen 与我相当。

**标准 4（双腿映射表）**：四家都交了（luna §8.1、kimi §15.9、cursor §22、qwen §15.8）。
判定的锋利度不同：**F-EXEC-02 在 dsh 腿**，luna 判 `explicit_unsupported`（事件全
runtime 未过滤 + messageId 非 turn id），cursor/qwen 判「当前缺失」，**我判了
「已支持（设计）」——判轻了，是我的缺陷**：F-EXEC-02 的义务是工具 IO 关联到
Attempt，逐 Turn 归属缺失时这条义务在 dsh 腿就是落不了地，事件流存在不等于归属
存在。luna 的判法让门禁更可判定。**F-EXEC-01 在 dsh 腿**，qwen 判「已支持（进程内）」
并给出 `profiles.py:36-41` permits_tool 与 `adding-a-tool.md:59` `ctx.tools.guard()`
单调 deny 的进程内证据，纠正了「dsh 全缺」的一风吹，值得注意。**F-EXEC-05 在
Codex 腿**，cursor/qwen 判「已支持（thread_resume）」，luna 判 `implicit_fallback`
（rollout 不是业务 checkpoint）——luna 的表述更贴合 F-EXEC-05 的原义。

**标准 5（supervisor 消歧）**：luna 最深（重写 §0.3 本体 + §11 对照表同步改，上层
「调度监督器」锚到 F-DISPATCH-03/I10/A2-A4，并给模型留了「无工具、固定 schema、
低预算、只能选不能创」的受限分类节点位置）；cursor 最广（§0.5 + §1.1 + §6 引言 +
§6.9 三不得 + 附录 A 第三套名字提醒）；qwen（§6.0 + §15.0 完整定名表）与我
（§0.5 + §6.1 + §15.2）居中；qwen 的 §0.3 原文未动且没有「全文 supervisor 一律指
内层」的全局声明，靠 §15.0 兜，略弱于三家的显性处理，但 §6.0/§15.0 已说明，判通过。

**标准 6（存续声明显式处理 + 引用清理清单）**：**cursor 最完整**（§23.1 混合存续
改判 + §23.3 清理清单含 human 那份措辞不一致的提醒、development-plan/constraints
吸收建议、AGENTS.md 分情形处置）。**luna 最果断**（直接改判「长期开发指南」，清理表
扩了 development-plan.md 指针行与实现矩阵行，防双真源）。**我做了**两存续级 +
条件四 + 三处措辞评估表（均判暂不改，理由写明）。**qwen 最薄**：§11.1 加第 3 条、
§11.2 加条件四，但清理表原样保留，**没有按任务书 §9.3 要求评估那三处措辞是否要
跟着改**——其条件四成立时，旧表「改指 human 那份即可」的处置是不够的，这一处
他家（luna）明确改写了处置、cursor 与我各自补了评估。

**标准 7（无具体 Profile 字段表）**：四家均守。qwen 与我写了可复跑的 0 表证据
（grep alembic versions）；luna 锚到 development-plan.md:110-122；cursor 注明
「未对生产库 \dt 复核」标 ⚠，诚实度加分。

**标准 8（不重新定义产品对象）**：四家均显式声明。cursor 与我把它写进头部，位置
最好。

**标准 9（Node 误判不得出现）**：四家均正确处理且给了 sdk-runtime README 锚点，
qwen 另给 `platforms.json:2-4` 行号。

**标准 10（两轴分开）**：四家都设了专节。cursor §15.4 的表述（「不得写成 dsh 还不能
用或已经能上生产」）与 qwen §15.0（直接点 09-03 失败整合的措辞坑）最准。

**标准 11（未验证标 ⚠）**：**cursor 最佳**（§23.4 集中清单六条，含「未设计多租户
配额产品语义」这种自曝）；luna、qwen、我散标各节，齐全但不如集中清单好查。

**排序与理由**：**luna > cursor > qwen > kimi**。

1. **luna**：证据最硬（commit 钉版 + 源码级锚点 +  dormant 级生产事实），结构最贴合
   基座（内容按主题进 §4/§8/§9/§11 而不是孤立附录），映射表判定最锋利（F-EXEC-02、
   F-EXEC-05 的三态判法让门禁真正可判定），消歧与存续处理都到位。缺陷：§4 一节塞进
   约 190 行，七块散在多个大节里，按「七块清单」核查时不如单节集中好查；头部日期
   误写 2026-09-03。这些是查读性问题，不是内容问题。
2. **cursor**：11 条全过，消歧最完整，§23.4 未验证清单是标准 11 的最佳形态，§6.9
   三不得最可执行。缺陷：§15–§23 整体追加在附录 B 之后——编号大节落在附录后面，
   违反文档阅读习惯，且自家 §0.1 表、头部都要靠指引才能找到；「12 进程打爆 768Mi」
   无锚点（qwen 有）；F-EXEC-04 Codex 行「thread/goal token 预算是辅闸」一句我未核到
   出处，存疑；「熔断」只覆盖版本漂移，没覆盖连续崩溃循环（luna 的
   failure_fingerprint 阈值三元组才完整）。
3. **qwen**：锚点单兵最强（dormant 登记表、OOM 教训、dsh 进程内机制），F-EXEC-01
   dsh 腿的「已支持（进程内）」是四家里唯一给进程内证据的判法。缺陷：标准 6 的
   附带要求（三处措辞评估）没做；G1 门禁把 cancel 对应到 F-EXEC-07 不如对应
   F-INTERACT-01/I14 顺（luna 对应 F-EXEC-03 也更顺）；「13 张表」沿用转述未自核
   （cursor 都标了 ⚠）；§0.3 消歧无全局声明。
4. **kimi（自家）**：11 条形式上全过，但证据厚度垫底，且有实质判轻：
   F-EXEC-02 dsh 腿判「已支持（设计）」与三家相反且经不起推（见标准 4）；
   「RunBudget 生产引用数为 0」不精确（`first_m1_graph.py` 有内存消费，qwen 的
   dormant 锚点才是正解）；未钉 commit；OpenClaw 只有文档锚点；Codex 沙箱
   「限写不限读」标了 ⚠ 但无锚点。结构（单节 §15 集中在附录前）与 cursor 的
   散节后挂、qwen 的单节集中各有取舍，这不是开脱证据薄弱的理由。

事实题复核记录：luna 的 `resolve-route.ts`（matchedBy/EvaluatedBinding 在 `:57-80`
附近属实）、qwen 的 dormant `:154`（RunBudget 休眠条目属实）、`_approval_mode.py:13-17`
（确为两档）、dsh `client.py:94/117/124`（close/terminate/kill 属实）、cursor 的
`api.py:737-739`（interrupt 属实）——五处抽核全部属实，未发现虚构锚点。

## D. 值得吸收的点（不论谁当基座）

**出自 luna**：

1. §4.6 引言：三仓取证 commit 钉版（Codex `7d6f808b`、dsh `dd6322d6`、OpenClaw
   `173f41d6`）+「升级钉版时必须重跑锚点，不能沿用本表结论」——锚点的保鲜纪律，
   四家里独一份。
2. §8.1：F-EXEC-02 在 dsh 腿判 `explicit_unsupported`（事件全 runtime 未过滤 +
   messageId 非 turn id）+ 上游补法写成「turn correlation 与 filtered cursor」——
   比我与 cursor 的判法更可判定，直接修正我候选的最大缺陷。
3. §0.3：受限分类节点的具体形态——「无工具、固定 schema、低预算，只能在调度监督器
   给出的合法候选中选择，不能拥有队列、权限或终态」，比「闭集分类器」可操作。
4. §4.9：Codex async client 把同步调用包装进 worker thread（`async_client.py:161-183,
   293-295`）→ 并发与 teardown 必须做负载/故障注入，「不能由 async 关键字推断安全」。
5. §4.9：恢复熔断用 `failure_fingerprint + profile_version + runtime_version` 三元组
   阈值——比「连续 N 次崩」可判定。
6. §4.11：OpenClaw 源码级锚点（`resolve-route.ts:57-80,745-793` binding 返回
   `matchedBy`/`sessionKey`；`selection.ts:102-124,221-260` 显式 plugin runtime 默认
   fail-closed）——把「两层路由都不是语义分类」从文档论断坐实到代码。
7. §11.2：清理表新增 development-plan.md 指针行与实现矩阵行——吸收时的防双真源
   检查项。

**出自 cursor**：

1. §6.9：内层三不得写成独立小节，落到「`worker_kind` 在 Attempt 创建时钉死」「不得为
   子任务临时 `new DeepSeekHarness()`」——最可执行的消歧落地。
2. §23.4：本轮未验证集中清单——标准 11 的最佳形态，最终稿应保留这个栏目。
3. §20.3：审批超时单独成态，不折成 `auto-deny` 以免污染审计——四家里唯一把超时
   从 fail-closed 里再分出来的精确处理。
4. §19.2：`CELERY_WORKER_CONCURRENCY: '2'`（`00-prerequisites.yaml:109`）与
   `20-runtime.yaml:283-284` 的 prefork 池锚点——进程纪律接上当前 bundle 实际值。
5. §17.1：`WorkerHandle` 可序列化存 Postgres（SDK id 不是 Task 真源，I13）、
   `CODEX_HOME`/`DSH_HOME` 互斥写进 Port DTO。
6. §15.2 硬条件 2：「已能画边的熟路（问数主链）编排权仍在我们，不交给聊天循环」——
   我候选丢掉的边界，应补回。

**出自 qwen**：

1. §15.2 事实⑥：生产未接线的权威锚点改用 dormant 登记表
   （`test_dormant_capabilities.py:154/182/208`）——与基座 §5.2 自己的指针同源，
   比「引用数为 0」严谨，直接修正我的不精确表述。
2. §15.5：prefork/OOM 教训锚到 `evidence/R4-investment-result.md:21-22` + 模板提交
   `7f2942c`——把 SDK 进程纪律从设计原则变成项目已付学费（12 个 prefork 子进程
   打爆 768Mi），比 cursor 的无锚转述硬。
3. §15.8：F-EXEC-01 在 dsh 腿判「已支持（进程内）」，证据 `profiles.py:36-41`
   `permits_tool` + `adding-a-tool.md:59` `ctx.tools.guard()` 单调 deny——提醒最终稿
   别把 dsh 写成「全缺」，进程内工具门已经存在。
4. §15.2 事实⑤：`ApprovalMode` 只有 `deny_all`/`auto_review` 两档
   （`_approval_mode.py:13-17`），auto_review ≠ deny——对「必须覆盖默认 handler」的
   最精确表述。
5. §15.4/§15.5：teardown ladder 的具体方法锚点（dsh `client.py:94/117/124`）。
6. §15.6：OpenClaw `delegate-architecture.md:96`「即使被指示绕过，Gateway 也挡」——
   双层工具门的原文级证据。
7. §15.2 事实①：`subagent-codex` 佐证（dsh 能把真实 Codex 会话当专业腿下级委派，
   permissionMode 映射到 thread approval/sandbox）——双腿互嵌的现成路径，值得留在
   最终稿当脚注。
