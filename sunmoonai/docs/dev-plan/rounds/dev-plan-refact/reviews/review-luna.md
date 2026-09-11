luna

# ② 互评：dev-plan-refact 第二次尝试

评审结论：建议以 **luna 为整合基座**，完整排序为 **luna → cursor → kimi → opus → qwen**。
五家 M1–M4 均通过；没有一家应当凭这四项直接作为可发布终稿。下文逐项给出理由与修订要求。

**利益冲突：我同时是 luna 候选作者和本次评优者，本稿不是独立终审。**评的是②通知冻结的五家十份，
不以本人候选最新工作区、其他评审的意见或起草者偏好替代冻结对象。本稿不修改任何①候选。
任务书中的六个开放问题按各自论证判断；采用 PRD/ADR/TLD 名称、接受或反对某种目录划分本身均不加分。

## A 自述：我的候选做了什么，以及没有做什么

①a 以一个可验收的需求增量为主线，划分受理、需求验收合同、设计决策、施工就绪、实现与独立验证、
发布、运行验收七阶段。拆分依据是不同的退出问题和失败回路：明确需求不等于设计可行，设计可行不等于
环境可开工，候选通过不等于获准发布，部署成功不等于用户结果满足合同。每阶段列产物、位置、退出门与退路。
DoR 要求当前单元所需前置实际成立；调查可以按自己的窄合同开工。DoD 区分候选、发布和需求完成三个对象。

①b 从阶段消费的问题推导 PRD、TLD/SDD、SDP、证据和接续记录，形成十四份目标正文预览。
现行 guide 的组件、执行器、授权、证据接口与日常操作分别组织；跨文件的同类内容按共同问题排列。
内核、constraints、protocol 两份保持原路径及全部字节；现行禁令保留在设计规范，历史读数与吸收收据保留来源。
260 行映射同时有源正文范围、摘要、目标文件和栏目，可用内置工具取原文、渲染目标及核验。

刻意没有做的内容及理由：

- 没有代替 U1 选型、补造业务任务或更改产品状态边；这些改变结论，超出本轮组织重构。
- 没有拆产品内核；领域对象、状态与 AT 共同使需求可判，保持字节又能直接保全行号。
- 没有把“实现了检查脚本”写成“检查已经接线并覆盖语义”；完整 DEV 门聚合器仍标未实现。
- 没有逐句去重。完整源节组合能保留反例和限制，但相邻重复与跨文件引用仍需编辑审查；这是明确欠账。
- 没有直接替换现行文档、删除 archive、迁移已归档 rulings 或改产品仓。①交的是候选架构，正式切换需要本轮裁定。
- 没有把九源逐字节保全扩写成 archive 全部来源均已独立语义验收。共同清单和旧稿吸收清单是两个集合。

⚠ 未验证：当前外部 SDK 能力、产品仓实际部署、授权强制、业务数据和金标准均未在本次候选或②重新实测；
候选引用的历史读数只保有原作者、原版本、原环境的意义。十四份预览尚未完成正式链接切换，不能当成已上线文档。
本次②重新运行了 luna 的 verify、十四个 render 和 runtime-refact/R7 检索；这证明取件与搬运行为，不能证明分组合理。
原①声明的十例正文抽查和负例试验，不能据此扩大成这次②已对所有分组独立验收。

**自己最需改进的三处：**①机器清单一条超长 JSON，不利于人逐项复核；②正文预览仍保留源节号和相对链接，
发布前需生成实际可阅读的章节与链接；③ handoff 待办仍留在状态文档、入口重建的具体正文未给出，均未充分收敛到自己的边界判据。
这些缺陷在 C 中照样扣判断项，不能用工具绿色抵消。

## B 候选集冻结

通知取自主线 `call-②.md`，规则入口取自主线 `GO.md`；读取通知时的主线记录提交为 `ceb9bf05`。
以下是按 commit 取出的事实，路径是作者归属路径，**取件依据是 commit，不读取该路径上后来改动的文件**。
行数按换行符计，字节按原始 blob 计，sha256 为完整值。十份均与通知的行数、字节数及摘要前缀一致。

| 家 | 归属路径 | commit | 行 | 字节 | sha256 |
| --- | --- | --- | --- | --- | --- |
| opus | `/home/zym/worktrees/opus/k8s/sunmoonai/docs/dev-plan/pipeline.md` | `4810fa62ad55ac6218ab45b760cbb881db3272b1` | 387 | 23711 | `bc29ce3619cba2625dc5a486d433837bed80694b9cbb92d6dcc9ee265d700bf8` |
| opus | `/home/zym/worktrees/opus/k8s/sunmoonai/docs/dev-plan/dev-plan-architecture.md` | `4810fa62ad55ac6218ab45b760cbb881db3272b1` | 801 | 68136 | `f8b67fb2eb5ba6977275bad1708d3f05220f379e437e52feadc72fe98e27791f` |
| luna | `/home/zym/worktrees/luna/k8s/sunmoonai/docs/dev-plan/pipeline.md` | `9a2b999ce86882bd14a168c3c21d981274d4c7c6` | 213 | 22635 | `781dcc882b9fd80e159e65abdb11bc34dc2ae826e9162e60d9371c01a933856a` |
| luna | `/home/zym/worktrees/luna/k8s/sunmoonai/docs/dev-plan/dev-plan-architecture.md` | `9a2b999ce86882bd14a168c3c21d981274d4c7c6` | 733 | 183574 | `4d4349400d971a6e1ae1a0409e1760f239ee780b085d1a8063d1148f111a1aa8` |
| kimi | `/home/zym/worktrees/kimi/k8s/sunmoonai/docs/dev-plan/pipeline.md` | `492458d2a67f0c8ff58ef266e7cc8c23e01e0b00` | 181 | 14810 | `1201d96a81155434bcde9e10c89adf98b7a1d1b3e12b10eb8e7b8454e5537ee0` |
| kimi | `/home/zym/worktrees/kimi/k8s/sunmoonai/docs/dev-plan/dev-plan-architecture.md` | `492458d2a67f0c8ff58ef266e7cc8c23e01e0b00` | 569 | 37516 | `71d337c83d269f10937dd6237b051b1cf060e5983423a43d81ad6d2490fa8252` |
| cursor | `/home/zym/worktrees/cursor/k8s/sunmoonai/docs/dev-plan/pipeline.md` | `8ed6348b68687f921492b9ffbcdfc4657a883731` | 426 | 28959 | `cb3020aff05936246edf013189cb5786967facfacac2c0af76e463dd30d605a6` |
| cursor | `/home/zym/worktrees/cursor/k8s/sunmoonai/docs/dev-plan/dev-plan-architecture.md` | `8ed6348b68687f921492b9ffbcdfc4657a883731` | 526 | 70939 | `e6833fa8541a502f423f76a6f21adbd0130922d29f21bf341fd090b980383ae4` |
| qwen | `/home/zym/worktrees/qwen/k8s/sunmoonai/docs/dev-plan/pipeline.md` | `a7b0f10430d5753bf11ee2e364ab3b2e7b4aee71` | 173 | 11837 | `ff32c64fdb1f700646b44a93f460ad70040eaf1123a888fd0c5334695e8335dd` |
| qwen | `/home/zym/worktrees/qwen/k8s/sunmoonai/docs/dev-plan/dev-plan-architecture.md` | `a7b0f10430d5753bf11ee2e364ab3b2e7b4aee71` | 465 | 29098 | `49fbbfccee9fed8a520e6bfc3fdd56aa52f40b799d665388db21a41716df8518` |

九份共同输入在这五个候选提交上均与 `baa2885847d5c236dc5cdf5d2273bf55286c775c` 逐字节相同。
因此各候选正文中基线短名不同，不构成本次输入内容不一致；评审没有重新定基线。

## C 逐项评优

### C1 判断口径与机械结果

下文 P 指该作者冻结的 `pipeline.md`，A 指其 `dev-plan-architecture.md`；“L”是冻结文件行号。
例如 `git -C /home/zym/worktrees/luna/k8s show 4810fa62:sunmoonai/docs/dev-plan/dev-plan-architecture.md`
可复核 opus 的 A。共同源文简称 guide、内核时，固定指 `baa28858` 下的相应源文件，不指改写后的预览。

| 家 | M1：逐项覆盖 inventory | M2：落点非空 | M3：冻结索引 doc-gate --all | M4：两个精确路径 |
| --- | --- | --- | --- | --- |
| opus | 260/260；唯一源键 260，无漏项/重复 | 260 行非空 | 退出 0，212 份通过 | 两份均存在于冻结 commit |
| luna | 260/260；唯一源键 260，无漏项/重复 | 260 行非空 | 退出 0，212 份通过 | 两份均存在于冻结 commit |
| kimi | 260/260；唯一源键 260，无漏项/重复 | 260 行非空 | 退出 0，212 份通过 | 两份均存在于冻结 commit |
| cursor | 260/260；唯一源键 260，无漏项/重复 | 260 行非空 | 退出 0，212 份通过 | 两份均存在于冻结 commit |
| qwen | 260/260；唯一源键 260，无漏项/重复 | 260 行非空 | 退出 0，212 份通过 | 两份均存在于冻结 commit |

M1 按“源文件 + inventory 起行”做集合与重数比对，没有拿总行数冒充覆盖；部分候选缩写了标题，身份仍可由起行确定。
M2 的机械口径只要求非空，所以 `rules/ 或 constraints.md`、`寄居；目标迁出` 也通过；其是否充分确定另在 J4 判断。
M3 使用各冻结树的独立临时 Git 索引，不切他家分支、不改真实暂存区。五家 doc-gate 脚本相同，
sha256 为 `0844b27ddb6e8000d0646916d314280196d7184dc59d7c3902a3724e19307e08`。
门禁所证明的是当时索引的文档检查通过，**不包括候选所建议但尚未实施的文件迁移**。

五家都有流程、类型推导及归属判据，均非只有导航表；没有因命名、文档数量或未提前执行物理迁移而适用否决。
当前证据足以在 J 项指出不完整和错误，但不足以断言某家曾先分类再倒写流程的实际创作顺序。

### C2 J1：六方面逐家检查

“有答案”与“答案足以执行”分别判断，不能看到六张表就报完整通过。

| 家 | 阶段 | 开工/完工门 | 类型 | 生命周期 | 机器/纪律归属 | AI 前提与 J1 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| opus | P 2.2 九阶段；发布/反馈有产物却以 `—` 填位置 | P 3：前置就绪或登记阻塞；完工清单止于发布前抽检 | P 4.1 十一类 | P 4.3 明列，但 WU“不保留、不进仓”与 A 的版本化计划冲突 | P 2.2 把 DoR、“红的原因正确”直接交机器，未给对应非平凡命令；与 P 3.3 自定规则冲突 | 人注意力轴明确，但“实现几乎免费”属未经本轮验证的概括；**六项均触及，执行闭环不完整** |
| luna | P 一：S0–S6 各有产物、位置、门、退路；实际运行接收独立 | P 三：阻断项不能带入实现；区分 G4/G5/G6；文档任务有适用口径 | P 五由阶段产物推出 | P 五及 A 三明确修改、审批、取代和历史 | P 二分局部机器、AI 纪律、人判断，声明聚合器未建 | AI 做技术工作，人定意图/取舍/批准/接收；冷启动与窄调查有落点；**六项较完整，仍是需实用验证的规范** |
| kimi | P 1 六阶段终点为吸收归档与主线 commit；实际部署及运行验收的产物/门未展开 | P 2 DoD 位于 S5，S6 尚未吸收；DoR 允许登记阻塞代替就绪 | P 3 十一类 | P 4 列全修改者、取代、旧版 | P 5 把工单字段齐全和落点齐全归给 round-status，超出所引脚本能力 | 冷启动可续接、独立验证明确；“人只在两端”与 S2/S3 的人动作不完全一致；**六项有答案，发布和机器门需补实** |
| cursor | P 2 提出到发布交接九阶段；发布对象偏主线 commit/gitlink，未给运行观察的具体完成条件 | P 3 两门清楚，但 G2.6 仅“若宣称发布”；不能据此认定产品需求已上线 | P 4 十二类，逐类说明缺了哪个过关物 | P 5 对决定、设计、任务、状态区分较好 | P 6 对已建/待建/纪律分得较清楚；P 2.8 却说人确认是唯一不可命令判的环节，与自身纪律列相冲突 | Change 与产品 Task 明确分开；**六项较完整，产品发布终点及两处措辞需修** |
| qwen | P 1 实现、验证、发布、运行反馈分开，是强项 | P 2 DoD 允许候选冻结结束，未包含 S6/S7 完成证据；D6“记录或授权”留下越权通过的口子 | P 3 十类 | P 4 覆盖修改者、旧版；引入“约束委员会”未说明其角色 | P 5 明说 CI/make check 待建，但 P 2 多处字段存在/文件同 commit 被写成充分机器判据 | 角色独立与冷启动写出；**六项均触及，授权与完工门存在实质缺陷** |

上述完工批评针对候选对“一条需求从提出到上线”的总承诺。允许工作单元先于产品上线完成，
但必须像 luna 那样明确“哪一个对象完成”，并给外层需求接收门；不能让一个无对象的 DoD 代替整条需求闭环。

### C3 J2–J7：全部五家逐项比较

| 家 | J2：类型由阶段推导 | J3：判据先于结果 |
| --- | --- | --- |
| opus | P 2→4 有明示推导，采用参考也说明理由，不能按照抄直接否决；但阶段9制品/复盘没有明确类型/位置，WU 在 A 又变成入仓计划 | A 2 先给三问/规则/例外，形式成立；将主观语义称“机械算出”过强，且生命周期规则与实际映射不一致 |
| luna | P 一→五、A 一→二按阶段的不同交接问题推出文件，关系成立；十四份物理文件并非十四套流程 | A 一先定内容被哪一道门消费，再列目标与260行；对当前禁令/历史记录有明确排除条件 |
| kimi | P 1→3 有推导；但 A 的十一槽新增原始需求和目录入口，将 P 的决定/取证合并、上下文包消失，缺逐类转换解释 | A 1 的正反条件与投影/自描/轮属在映射之前；成立，但 P-自描与 P-轮属冲突时优先级不够明确 |
| cursor | P 2→4 每类列“缺它哪个阶段不过”和不能并的理由，五家中易于直接审阅的一份；跨阶段类型有交代 | A 1 先定正反条件和阶段判据，成立；具体结果有按原章统一套规则的问题 |
| qwen | P 1→3 有阶段来源，基本成立；S7产生长期约束而 DoR已经依赖它，缺首次产生/跨阶段复用说明；证据/发布产物类型较薄 | A 0.1 A–I 判据先行，形式成立；遇 A/B、F/G 混合主要在备注处并列，未定拆分优先规则 |

| 家 | J4：内部组织与真正归属 | J5：拆并代价 |
| --- | --- | --- |
| opus | **不满足核心部分。**A 6.2、F-10 明说章内重组不属本轮，把任务点名的问题留到以后；2–7章批量落 product/design/，缺目标逐份栏目；混合规范误归档见 O1 | A 5 有检索收益和通读变差，优点应保留；但“只拆一份，其余八份不拆”与同稿 guide/实施计划多向拆分冲突，成本账不完整 |
| luna | **部分满足且完成度最高。**十四份目标有问题、顺序、源正文，guide 22个执行小节按动作/失败回路重新分组；但完整节拼接仍有重复，旧号/链接未切换，入口和待办归属欠账见 L1–L3 | A 四具体写出入链、源码坐标、维护与多入口代价，并解释四份原位保全；欠正式引用清单和完成后的可读编辑稿 |
| kimi | **部分满足。**A 5逐文档论证，guide对子节增长和投影有解释，较单纯沿用进了一步；但仍以章统一归类，8.3现行禁令被放进旧轮，五百多行历史说明留作自描，取舍边界不稳 | A 3明确列引用方、多一跳和待办迁移；“拆内核收益为零、代价 prohibitive”没有读者实测，不能当事实；断链门禁承诺也需修正 |
| cursor | **部分满足。**A 2重审出设计/证据/收据/状态等混合面；但目标多处“独立TLD或任务栏”“constraints或手册”，未收敛到新文档内部组织；整章5实测也归硬约束，见 C1 | A 3对引用、冷启动、稳定路径代价清楚；只标寄居不搬移可以作为过渡，但不能据此把最终安置成本视为已经解决 |
| qwen | **不满足核心部分。**A 1–9主要给类型编号；只有guide 2和开发计划架构部分有较明确拆分论证，其余目标内部栏目为何成立没有逐份展开；同名目标冲突见 Q2 | A 10列三类主要拆分的读者代价；没有为guide 4/7/8/10等其它多向去处给完整引用和维护成本；未来锚转发仍是概念方案 |

| 家 | J6：内核锚点保全可执行性 | J7：六问逐项答案与异议举证 |
| --- | --- | --- |
| opus | **当前方案不通过。**A 5.3把旧 L450 指向 WAITING 小节，源 L450 实为 I3 当前授权；投影页又不保留原行区间，错误指向不能算保全。统计少量裸锚的有益区分，不能替代逐条语义核对 | Q1/Q2/Q3/Q6有说法及一定理由；Q8只用DEC接人的决定，没有安置无决定的轮外实验/测试；Q9迁裁定正文与 A“rounds本轮不动”冲突。整体部分满足 |
| luna | **本轮方案可执行且已复跑。**verify核工作区、索引、冻结源及完整重建；内核正文/路径不变，任意原区间均保留。未来迁移仍需另验，不能外推本轮绿色 | Q1整份PRD；Q2原轮决定及完整证据包；Q3 SDP引用的执行附件；Q6阶段产物及分文件理由；Q8轮外records/work与原产品evidence；Q9全局键及可运行检索。六问均有实质答案，检索冻结性局限见L3 |
| kimi | **本轮原位不改方案可执行。**A 4不移动不拆；但把稳定ID纪律推广到章节冻结不能保全任意插行后的裸行锚，未来迁移仍需逐条核；doc-gate不能承担其宣称的全部互指检查 | Q1/Q2/Q3/Q6均作答，Q3有生命周期/读者/内容理由；Q8有evidence槽但未厘清本仓/产品仓、T1轮次与轮外的区别；Q9有前缀索引，检查仅索引→正文，缺源决定→索引的完整性方向 |
| cursor | **本轮原位逐行不改方案可执行。**A 4明确连吸收阶段也不编辑内核；未来必须交迁移图和引用更新。其“拆文件会造三个真源”的论据不成立，单一权威取决于条款归属，并非文件数量 | Q1保合同、Q2区分决定/证据、Q3常驻协议给替代论证、Q6十二类、Q8分轮次/本仓轮外/产品仓、Q9前缀索引均明确；Q9为后续方案，未把取件程序交出 |
| qwen | **本轮不物理拆分可保全；未来方案未证。**A 10.1留内核、设计只引用；“稳定ID转发页”不能自动保留旧行号语义，正式改页前需增逐条迁移核验 | Q1/Q2/Q6有答案；Q3仅以内容不同反对“计划的一部分”，未充分排除附件关系；Q8 HANDBOOK+STATUS不提供证据存放位置；Q9编号消歧有用，但历史稿索引不等于决定索引，不能满足可检索全体决定 |

### C4 会影响整合的正文反例与具体修订

#### O1–O3：opus

**O1，归档边界及 J4。**A L332–342 将 guide 原 L2178–2553 全部当轮次产物；
共同源 guide L2178–2234 明说本节用来防止被证伪设计复活，L2215 起又明确旧 R0–R5/S1 不采用为现行路线。
guide L2253–2282 则是“查了/没查/不能排除”和三类未知的通用报告义务。它们并非仅对旧轮有意义。
要迁历史取证，必须同时给这些仍生效约束的规范落点；“回 rounds/”没有完成这一步。
A L638、L762 进一步把章内重组排除，与任务书 J4 的明确要求相反。这个缺口不能靠登记 F-10 豁免。

**O2，锚点保全。**A L588 建议把 readiness 中指向内核 L450 的锚改为 `#4.2-WAITING-与-Interaction`。
在本次共同源中 L450 是 I3“每次读取、工具调用和写入重新校验当前授权”，WAITING 在 L247起。
两个位置语义不同，且没有证明新投影页实际提供这个 fragment。
不采用“只剩两处所以拆分容易”的结论；需要完整枚举、解析上下文及新目标正文。
这里不裁决任务书71与作者58哪个统计总数更权威，单独的错向反例已足以否定现有迁移表。

**O3，记录与生命周期。**P L109/L230 规定 WU 不进仓、不保留，A却将计划与任务模板落进
`plan/implementation-plan.md`；为 handoff 另设ENTRY例外不能解决计划本体冲突。
P L315又要求现有rulings正文迁出、原文件只留索引，A却声明既有rounds不动。
应选定一种本轮可执行处置：原记录保留，以索引补检索，并补齐轮外实验/验证记录的位置。

#### L1–L3：luna（本人）

**L1，预览不等于完成编辑。**A“七、主动暴露的争议”和RUNNER的render把原正文逐节接入栏目，
每块保留旧标题、旧相对链接。尤其 guide 预览仍有原第3/4/7等编号与新动作栏并列，
人读时必须频繁判断当前引用用的是哪个源坐标。我的摘要检查证明没丢字，不能证明这些段落已写成顺畅的最终手册。
整合必须去除失效的自指、统一正式标题和交叉链接，并对拟删重复段逐条核等价；不能只交生成器。

**L2，自己的边界也有未收敛处。**A 将 I08-009“文档面待办”仍放 handoff，却定义handoff只写状态。
原源 handoff L80–92 的 D1/D2 含工作对象与验收要求；其中任务本体应进入计划，handoff留进度和阻塞投影。
此外 README两个源节都迁历史，目标十四份没有新README正文；虽然 P 是拟议流程入口，正式切换仍须补根入口指针。
这不是 M1 缺失，是 J4 的目标完成度不足。

**L3，证明工具的使用和范围。**A L554 把大清单压成单行，183574字节的架构稿中机器数据占去很大篇幅；
评审者难以逐项比较，正文优点不能抵消这个负担。应把可读映射作为审阅面，机器清单可分行展示或在正式实现阶段生成。
内置decisions检索锁在四份冻结rulings，现有28条可查，不能自动发现之后的新轮外决定；命中返回整份rulings也不等于
已经算出各条今天的效力。最终索引必须保留正文更正，并补增量枚举、源记录→索引的完整性检查。

#### K1–K3：kimi

**K1，门禁说法超出实现。**P L127、L131称 round-status 可判工单字段齐全/落点齐全。
共同源脚本的parse_round、stage_table与verify分别做配置解析、产物存在性、冻结区/处置/锚点等检查，
没有对普通任务“目标/实施/测试/验收/回滚”逐字段完整性或本轮260行逐项安置的验证。
A L62 又称 doc-gate 会抓 guide 失效的节8引用；冻结doc-gate的SELF_CONTAINED只有产品内核，
L329的调用条件不会对guide执行章节引用检查。补一条未来可执行检查或诚实改标纪律，不能只再写脚本名。

**K2，体系衔接与归档。**P十一类包含决定记录、上下文包；A十一槽以目录入口、原始需求替换/合并后，
没有解释类型到槽的转换。A 表2把guide原 L2215 的8.3送入 `rounds/runtime-refact/`，
却未给当前禁令在活规范中的保留形态；不同来源的后续补吸收也不能仅按相邻章节归同一旧轮。
反过来9.4–9.6整段吸收历史又因“自描”保留，需解释为什么同样的收据有不同待遇。

**K3，流程终点与实际读者。**六阶段足以描述文档评优交卷，但应补部署、失败回退、实际运行验收的产物和门。
DoR“前置就绪或登记阻塞”需限定为阻塞不影响当前单元，否则登记缺数据库也能开实现任务。
A对D1/D2的迁移是值得吸收的独立改进；不因上述缺陷一并丢弃。

#### C1–C3：cursor

**C1，分类有规则但仍缺正文细分。**A表第118行（A L384）把guide的“轨迹实测：23条里2条attested”
整节归跨Change硬约束，理由与邻近所有第5章小节相同。实测事实、由实测支持的采信限制和回归方法需分清，
不能让一次读数随硬约束生命周期成为长期保证。A第136行同样把guide8.3当前禁令当旧轮决定收据。
A L255坦陈未逐节读guide 2–14正文，诚实披露有价值，但并不免去此类落点的语义复核。

**C2，最终归属仍多选。**A L100–101、L190在独立TLD/任务计划、constraints/手册之间保留多个目标。
这可以说明迁移阶段，却不能直接导出每份目标文档的栏目和边界。应先定正式展开处，再保留其它位置的投影。
不要求①马上移动文件；要求的是①b能指导整合者无需重做一次架构选择。

**C3，总流程表述需收紧。**P 2.9与G2.6主要以Git发布纪律收尾，产品上线还需目标环境和运行接收证据。
P 2.8的“能分则分”不能作为独立验收的可选豁免；该文G2.4又要求独立验收，应统一为现行协议下限。
P 6的机器/待建/纪律三分，以及产品Task与开发Change的区分，则可直接作为最终稿的简洁说明形式。

#### Q1–Q3：qwen

**Q1，授权不能用记账替代。**P L83 的D6是“不可逆副作用已记录或已获授权”。
这允许未授权动作只因留了记录而算完成，与共同源guide权力表和8.3“技术可写不等于动作获批”的现行结论冲突。
P 5同时要求有权主体审批，不能消除DoD中这个“或”的漏洞。应明确执行前授权、执行后如实记账，两者不能替代。
本轮仅记录此缺陷供整合，不修改源设计。

**Q2，目标编号没有形成唯一组织。**A中内核3.2备注指向TLD-01.2，而guide2.2内容角色的落点也是TLD-01.2；
guide7.1/7.2落IMPL-02.1/02.2，development-plan中的前后端阶段/agent阶段也使用这两个编号。
如果它们打算合在同一栏目，需要给合并理由和排列；如果不是同一栏目，需要不同标识和明确文件。
现稿没有完成这层结构。A还将有意留白标“待办项”，而原文明确是有意不先建设的方向取舍，不能经重排变成新任务。

**Q3，证据袋与历史来源。**A L449的Q8只回答HANDBOOK+STATUS，没有回答证据放在哪个持久载体，
且STATUS按P生命周期会覆盖。A L450把历史稿索引用来回答决定检索，二者对象不同。
A第2节还说guide8裁定“已在 rounds/dev-plan-refact/”，而共同源的8.1与后续8.3有各自历史来源，
没有提供该目标中的同一正文证据。应分别给现行禁令、历史审议、轮外测试记录和决定索引的实际落点。

### C5 排序、基座与题面争议

1. **luna**：J1的需求到实际接收闭环、J2的阶段推导、J4的具体目标栏目与全文预览、J6的字节保全和J7的可运行检索组合最完整。
   选择它作整合起点；L1–L3仍须处理，尤其不能把预览直接发布。排名不是对本人候选的独立验收通过。
2. **cursor**：阶段→过关物→类型的推导最易审阅，机器与纪律边界较诚实，轮外取证和决定前缀具体。
   弱在最终归属多选、正文分类按章套用，以及产品上线闭环。推荐吸收其表达和投影判据，不沿用未定落点。
3. **kimi**：逐文档的内部论证比单纯类型标号扎实，待办迁移、投影/自描规则有用。
   与cursor相比，机器能力的几处错误承诺和①a→①b类型转换缺口更重，发布终点也待补。
4. **opus**：独立测试先行、锚点区分、真实列出通读成本值得保留；但明确排除章内重组、WU生命周期冲突、
   当前禁令误归档和具体错误锚迁移，使其不能作为本轮直接整合基座。
5. **qwen**：七阶段包含发布与运行反馈是优点；但DoD授权漏洞、Q8未提供位置、目标编号冲突与逐文档内部论证不足，
   需要重做的关键部分最多。短小本身不扣分，上述缺失才是排序依据。

**关于题面是否偏向opus：**任务书1.1直接写protocol“不是实施计划的一部分”、内核“三份焊在一起”，
确有把起草者判断写成事实的诱导；而1.2又承认所有者映射为起点并允许有证据的异议。
我按后者处理：不把“拆内核”“独立protocol”当标准答案。逻辑上的实施附件与物理独立文件可同时成立，
仅证明协议与任务条目不是同一种内容，不足以推翻附件关系。现有证据不能据此认定整份任务书为opus量身定题，
但最终裁决应避免把这些叙述性偏好计成分数。

### C6 复跑与覆盖边界

本次已读四家八份候选全文，并重新检视本人两份；共同源重点复核guide的现行禁令/未知报告义务、
内核授权不变量、handoff待办、实施计划及门禁实现。没有读取其他②评审或本轮整合倾向。
没有登录外部服务、运行产品部署，未重新审遍rounds全部旧产物及原始需求档案全文。

下面脚本可在有五个冻结commit的本仓复跑M项，仅读Git、在临时目录写独立索引；不切分支、
不修改主线/他家工作区，也不执行候选附带的迁移命令。保存为临时Python文件执行即可。
其中DOC-GATE逐字节比对后使用自己仓中的同版本脚本；不将主线后来变化引入候选结果。

```python
import collections, hashlib, json, os, pathlib, re, subprocess, tempfile

ROOT = pathlib.Path('/home/zym/worktrees/luna/k8s')
temporary = tempfile.TemporaryDirectory(prefix='luna-review-')
SCRATCH = pathlib.Path(temporary.name)
PREFIX = 'sunmoonai/docs/dev-plan/'
BASE = 'baa2885847d5c236dc5cdf5d2273bf55286c775c'
review = ROOT / PREFIX / 'rounds/dev-plan-refact/reviews/review-luna.md'
manifest = []
for line in review.read_text().splitlines():
    cells = [x.strip().strip('`') for x in line.split('|')[1:-1]]
    if len(cells) == 6 and cells[0] in {'opus', 'luna', 'kimi', 'cursor', 'qwen'} and len(cells[2]) == 40:
        author, path, commit, lines, size, sha = cells
        manifest.append(dict(author=author, path=path.split('/k8s/', 1)[1], commit=commit, lines=int(lines), bytes=int(size), sha256=sha))
assert len(manifest) == 10
def git(*args, env=None):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=env)
inventory = git('show', BASE + ':' + PREFIX + 'rounds/dev-plan-refact/inventory.md').decode()
expected, source = [], None
for line in inventory.splitlines():
    m = re.match(r'^## \d+\. `([^`]+)`', line)
    if m: source = m[1]
    m = re.match(r'^\| (\d+) \| (#{1,4}) \| (.*) \|$', line)
    if m and source: expected.append((source, int(m[1])))
assert len(expected) == 260 and len(set(expected)) == 260
results = {}
for item in manifest:
    raw = git('show', item['commit'] + ':' + item['path'])
    assert raw.count(b'\n') == item['lines'] and len(raw) == item['bytes']
    assert hashlib.sha256(raw).hexdigest() == item['sha256']
    if not item['path'].endswith('dev-plan-architecture.md'): continue
    author, commit = item['author'], item['commit']
    body = raw.decode()
    mapped, destinations, source = [], [], None
    for line in body.splitlines():
        if author in {'opus', 'kimi', 'qwen'}:
            m = re.match(r'^###? (?:表 )?\d+(?:\.\d+)?[ .]*`([^`]+\.md)`', line)
            if m: source = m[1]
            cells = [x.strip() for x in line.split('|')[1:-1]]
            if source and cells and cells[0].isdigit():
                mapped.append((source, int(cells[0])))
                destinations.append(cells[4 if author == 'opus' else 2 if author == 'kimi' else 3])
        elif author == 'cursor':
            cells = [x.strip() for x in line.split('|')[1:-1]]
            if len(cells) == 9 and cells[0].isdigit() and cells[2].isdigit():
                mapped.append((cells[1], int(cells[2])))
                destinations.append(cells[6])
        else:
            m = re.match(r'^\| I\d+-\d+ \| (.*?) L(\d+) \| .*? \| .*? \| (.*?) \|$', line)
            if m:
                mapped.append((m[1], int(m[2])))
                destinations.append(m[3])
    assert collections.Counter(mapped) == collections.Counter(expected), (author, len(mapped), set(expected)-set(mapped), set(mapped)-set(expected))
    assert all(destinations)
    for path in {p for p, n in expected}:
        assert git('show', commit + ':' + PREFIX + path) == git('show', BASE + ':' + PREFIX + path)
    gate = git('show', commit + ':' + PREFIX + 'doc-gate.py')
    assert gate == (ROOT / PREFIX / 'doc-gate.py').read_bytes()
    env = dict(os.environ, GIT_INDEX_FILE=str(SCRATCH / (author + '.index')))
    git('read-tree', commit, env=env)
    run = subprocess.run(['python3', str(ROOT / PREFIX / 'doc-gate.py'), '--all'], cwd=ROOT, env=env, capture_output=True, text=True)
    results[author] = {'commit': commit, 'rows':len(mapped), 'unique':len(set(mapped)), 'empty':sum(not x for x in destinations), 'gate_code':run.returncode, 'gate_output':run.stdout + run.stderr, 'gate_sha256':hashlib.sha256(gate).hexdigest(), 'nine_sources_unchanged':True}
    print(author, json.dumps(results[author], ensure_ascii=False), flush=True)
(SCRATCH / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
```

本人预览工具的复核方法：按B表的luna提交取A，先读末尾RUNNER；
依其“六、决定检索与抽查方法”执行verify和render，分别核十四个目标有正文。
检索 `round:runtime-refact:R7` 要取得带表外更正的全文；该命令仅对冻结记录有效。
本次实跑结果为九源5320行逐字节重建、260唯一落点、十四份非空预览、四份原位全文相同；
旧三轮26条加本轮2条决定可枚举。该结果不能替代 C4 的语义判断。

## D 值得从其他候选吸收的具体主张

以下均是准备供③处理的建议，不回写任何冻结①候选。即使最终不选luna，仍建议逐条取舍并留处置。

| 来源与位置 | 具体吸收点 | 为什么值得；如何落地 |
| --- | --- | --- |
| cursor P 4 类型推导表 | 每类增加“缺它哪个阶段没有过关物”“为什么不能并入邻居”两列 | 比笼统命名说明更便于发现无消费者的文件；用于压缩并检验luna十四目标的必要性，不另造一套分类 |
| cursor P 6 | 按“机器已能判 / 当前纪律且目标机器 / 只能纪律”分层展示 | 把待建能力与现行事实放在读者第一眼能分开的地方；与luna逐门表合并成一致口径，补每条具体命令范围 |
| cursor P 9及A 3.4 | 轮次、本仓轮外、产品仓证据分别有固定取件入口 | luna已有轮外记录槽，可吸收这一张三行载体表，统一正文中的changes与records/work交叉指针，避免重复证据袋 |
| cursor A 2.6 | “有意留白”作为已经决定的范围边界，与待决/欠账分开 | 防qwen式迁移把不建设改成建设任务；在路线图保留结论投影及ADR出处，不只留旧记录 |
| kimi A 3.3及5.7 | handoff中的D1/D2任务本体迁实施计划，状态页只留游标和阻塞 | 这是luna未做好的具体边界；迁移时保留任务原结论、验收与来源，不因它在待办表里就自动授权施工 |
| kimi A 1的P-自描、P-投影 | 文档适用范围/修订规则随本体；跨页投影必须有权威指针 | 防机械分类把规范自己的边界也抽走；但需加优先级：历史取证不是全都自描，当前禁令不能随轮次归档失去读点 |
| opus P 2.2阶段5及2.3 | 实现前由分离角色给关键失败用例，明确“红应因哪条缺失而红” | 可补luna S1/S4的验证计划。采用与变更相关的关键反例，不把所有文档小修都强制新增测试；“原因正确”仍需独立判断 |
| opus A 5.2–5.4 | 分开统计钉commit锚、当前裸行锚、冻结历史记录，并明确拆分损失了通读便利 | 这是有用的迁移成本维度；只吸收分类和成本呈现，不吸收尚有错向的两条迁移表，也不以软判减少语义核验 |
| qwen P 1的S6/S7及P 4 CONTRACT行 | 发布后有运行反馈；契约旧版留到consumer升级完成 | 把运行接收与下次需求衔接写成可取证退出物；契约维护补provider/consumer并行版本条件，具体规则仍服从现有合同，不在本轮另改设计 |

整合的收口条件应同时包含：阶段与过门对象不歧义、机器能力不夸大、每份目标内部结构确定、
现行约束有日常读点、历史证据可回取、正式链接按语义验证，以及对所有吸收/不吸收建议留下处置理由。
这份评审只提出比较结论和修订输入，不授予发布、删除历史或改变已冻结设计结论的权限。
