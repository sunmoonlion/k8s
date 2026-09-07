luna

# 开发文档架构候选：按维护责任分源，按任务装配阅读

本候选主张五类内容：系统规范 N、工作规程 P、工作账 W、历史记录 R、生成视图 V。
判别依据是**谁对哪种变更负责、什么事实会使它失效**，不是文件名，也不是作者或读者。
把现有 guide 的运行时、权限、证据契约归 N，把一次任务的受理、执行、评审、交付归 P，
把未决、现行实施顺序与进度归 W，把吸收审计、旧路线和历史实测归 R。日常仍从一份生成的
`agent-dev-guide.md` 开始：它装配 N/P 的必要正文，不能单独修改出第二份规则。

这是①独立提案，**不是已生效的重构**。本文件交付架构、260 行安置表、按目标文档分组的
260 份完整正文单元，以及直接运行的查件/核验工具。目标路径是候选内已装配的文档包；
本轮未把它们写成正式文件，未删除或替换九份输入。源节并非仅链接回旧文：正文在后半部，
可按任意单元 ID 直接读出；无需阅读 archive 才能核对该次搬运。

输入冻结在 `78ccbf106d3189afabb3ce1a622b406516fa9ed2`（本人开始写候选前的 HEAD）。
与 `c4b60abb` 比较，九份输入逐字节相同；差异只有 GO、①通知、round 三份控制文件。
按本次 GO 的 HEAD 规则冻结，不把候选提交后的 HEAD 再当输入；通知的基线缺陷已修复。
有效范围为 9 份、5320 行、260 节；任务书已明确退役 Part 一和 B8，旧 320/399 节文字
作为历史残留解释，不能增加本轮分母。

利益与覆盖申报：本人参与过此次换版之前的再吸收，现行 guide 含本人文字；不能把熟悉程度
当作验收证据。未读取其他四家本轮候选；读过任务要求的 findings 格式和 F-1/F-2 局部，
这些未决建议不作为本方案的既定设计结论。全部新增组织判断在下文论证；继承的 SDK、
部署、身份与生产读数只是冻结输入原有断言，本轮没有复跑，也不由摘要升级为已验证。

## 架构：先定内容归属，再定文件

### 五类及其互斥判据

分类单位是**具有一个修改责任的内容单元**。旧文件是混合容器，不能把其标题冒充每段的属性。
新建内容先填写 `effect`，再按下表唯一归类；填写不实是评审错误，程序不声称能理解自然语言。
若一段同时给出了两个不同的修改触发条件，先拆成有源区间的两个单元，再分类；不准多选。
本轮对旧文采用标题单元搬运，局部混合段保留上下文并显式列为争议，不能借分类偷偷删断言。

| effect 的唯一值 | 类别 | 准入测试：什么变化使它需要修改 | 排除项 | 维护与生命周期 |
| --- | --- | --- | --- | --- |
| system | N 系统规范 | 产品实现即使尚未达到，也必须以此作为实现或验收目标；或解释一个现行设计边界 | 本次交付日期、一次实验结果、只约束协作的步骤 | 工作单元提案；现行协议定档，权威变更走 T2；按已有批准程序生效。有效版本可被新版本取代，旧 commit 与条款 ID 永留，禁止因实现落后反改目标 |
| work-rule | P 工作规程 | 同类工作下次发生时，不随具体 Task 变化仍须执行这套规则、表单或步骤 | 产品状态机本体、某次分发记录、任务进度 | 规程维护者随对应工具修改，独立评审；协议及权力规则的修改遵循现行 T2 门槛；普通使用不改规程。旧版本可追溯，已冻结工作单元继续绑定原版 |
| work-instance | W 工作账 | 某项待完成工作的目标、依赖、负责人、状态、阻塞或验收证据发生变化 | 已生效的通用规则、不可覆写的决定与原始证据 | 指派执行者追加进度与证据；范围/验收变更按已定程序批准，不能用进度更新改规范。完成后冻结为记录，未决不得因换会话消失，旧版本留 Git |
| record | R 历史记录 | 描述特定对象、版本、环境、时刻下发生或决定了什么，后来的变化不能抹掉它 | 今天要执行的全局规则、可以随意回填覆盖的进度 | 原提交作者在冻结前编辑；冻结后追加更正、替代或撤回记录，保留原文。决定的有效性仍按原协议/回执判断；归档不自动变成已批准或可信签名 |
| generated | V 生成视图 | 可由带版本的 N/P/W/R 完整重建，没有独立事实写入权 | 手写规则、唯一存在于导读里的例外、手填的“最新状态” | 只改生成配方和源，构建产生内容/来源摘要；允许覆盖重建。发布绑定同一源 commit；手改生成物拒收；视图失效回到对应源，不反写源 |

五类不能继续合并：N/P 的变更分别改变产品合约与工作方式；P/W 的差别是下一次任务能否
无修改复用；W/R 的差别是未完成状态能否继续更新；R/V 的差别是能否无损重建。
不另设 PRD、领域模型、验收、ADR、FAQ、SDK 等生命周期类别，它们是主题或记录子型。

**归属的可复核方法**：任取安置表一行，先读正文找出主语与修改触发条件，再查其目标文档
的准入条件和排除条件，最后看前后两组能否组成一个读者动作。不同意可提交“源单元 ID +
原句 + 所违反的准入条件 + 更合适的唯一落点”，无需重读 260 节。摘要只核字节，不核这一步。
旧文中的理由、反例和限定条件跟随所解释的规则一起走；不得把“不利的限定”单独放到历史区。

### 权威关系和目录

N 中产品合同约束架构；平台 constraints 约束各实现；架构把它们落实到组件责任。
P 引用 N 中的状态、对象和权限，不另造产品状态机。W 引用 N/P 的版本制定实施增量。
R 保存决定、实验与验收依据；**R 的一个“是”不覆盖另一条规范**，还须检查其对象、范围、
生效证据与替代关系。V 只组合来源。冲突不能靠目录深浅或文件修改时间自动决胜。

```text
dev-plan/
  constraints.md                        N，原路径/全文保留
  working/request-lifecycle.md           N，原路径/全文保留，产品合约整体
  working/request-baseline/              R，15 份原始需求，路径固定
  specs/{foundation,runtime,executor,authority,evidence}.md   N
  playbooks/{intake,execution,review,delivery,maintenance}.md  P
  protocol/round-protocol.md             P，原路径/全文保留
  protocol/README.md                     P，规程与脚本接口契约，原路径/全文保留
  protocol/*.py / agents.toml            原有实现，仍与规程共处
  work/{roadmap,delivery,status,questions}.md                 W
  records/{migration-context,guide-audit,guide-history}.md     R
  records/work/<work-id>/                R，轮外工作取证和验收
  rounds/<round-id>/                     R，轮次完整产物，原地保留
  archive/                              R，已退役规范的历史原件
  agent-dev-guide.md                     V，完整日常阅读装配
  README.md / handoff.md                 V，入口与当前工作快照
  development-plan.md / implementation-plan.md  V，兼容旧入口
```

这里的新增文件数服务于责任边界，不要求每个主题再建目录。五份 N 分别回答边界、组件、
执行适配、授权、证据，五份 P 分别对应开工到维护的读者动作，四份 W 分开产品顺序、
具体任务、观察状态与尚不能下结论的问题。R 的三个现有迁移包避免历史作者口吻侵入新规程。
以后一次工作一个记录目录，不能按作者新开一套活规范。`working/` 不更名、不整体搬空：
合同是 N 的受保护路径例外，原始需求是 R 的固定存储例外，目录不是类别本身。
该目录另有一份 TEMPLATE（P 表单），与 15 份原始档案一起原地保护，共 16 个文件。

### 每份文档为什么这样组织

后面的“文档包”表列出每份目标文档的内部栏目、顺序、准入/排除条件与实际来源。这里给出
必须先于分配的共同原则：N 按实现依赖次序排列“边界 → 责任 → 接口 → 约束/验证”；
P 按动作排列“前置 → 输入 → 动作 → 成功 → 失败/退出”；W 按依赖和状态查询，不能混进
一般性说理；R 按证据对象与发生次序，保留作者、未核项与反对意见，不能只留下结论。

产品合同保持完整有特定理由：需求 F、对象、状态、不变量 I 和验收 AT 共同界定同一个
Submission 到 Delivery 的合约。拆成三个规范会令对象改动必须跨三文件同时改，且引入
71 个行号锚的迁移。当前保留“边界/全景 → 对象/信封 → 状态/七阶段 → 不变量/扩展 →
责任/反例/验收 → 修订”的链条：读者先知道名词，再判合法行为，再找验收；每层以后一层
核前一层。需求视图可按 F/AT/I 生成，但不能成为第二规范。**本候选不改变其中任何字节。**

constraints 的“数据/契约/身份/拓扑/发布/智能体”沿用，因为实施影响面可在改动前选定，
规则 ID 与执行载体就在同组，数据迁移和发布步骤是各组规则的验证上下文，拆掉会割断
“要求—怎样核”的关系。最后的门禁边界保留，防止读者把检查通过当作规则全落实。

round-protocol 也保留现有章节：开头定位/定档是进入条件，裁量/角色是决策权，七环节和
工单给完整行动链，取件/判定/隔离/各环节细则解决执行，停止/清理/纪律解决退出。
虽然还能重排得更短，本轮不以另一份 playbook 改写其七环节规范。guide 中的七环节
摘要是被明确标注的操作解释，保留原文限定，权威仍在 protocol。protocol README 的
约束与脚本说明随接口共同演进，因此是 P，不假装为可任意重建的纯索引。

### 拆并收益、代价和旧引用

| 变更 | 必须解决的具体问题 | 新的读取/修改路径 | 成本与保全 |
| --- | --- | --- | --- |
| guide 结构拆开 | 原执行章混入发布、GC、状态模型、Git 权限、评优步骤；同一动作的前提散落别章 | 受理先读 intake；跑任务读 execution；批准/评审读 review 与 authority；发布读 delivery | 旧 guide 节号/相对链接会变；迁移单元 ID 永留，旧完整版本由冻结 commit 取件；正式切换前逐条建立旧标题到新 ID 的兼容锚，不能只让链接“存在” |
| dev-plan 的架构段与 guide 融合 | 产品顺序与 SDK/四账设计同页，改路线时可能改掉架构依据 | 架构写 specs；三个阶段写 roadmap；任务条目与通用表单分开 | 不擅自合并相似但版本不等价的断言；同主题原文放在相邻块，明确源日期及待复核项；冲突须 B3 另行裁定 |
| handoff 与实施表分解 | 已就位读数、未决、不可倒退结论、任务进度混排 | status 只记录观察；questions 保留 U/风险依赖；delivery 保留任务；handoff 从它们生成 | 原文状态只代表所写日期；生成器不能把日期变成今天。固定 ID 避免某次交接重新编号 U1 |
| 审计和历史读数迁 R | 每次接任务被数百行落点收据打断，历史已核项被误看成今天验证 | 普通开发 guide 不装配 guide-audit；查迁移用同一 ID 查记录包 | 审计不删除；G-097 中查/未查/不能排除的通用规则进 review，连同原例证保留；G-091–094 的禁止复活旧设计条款留 foundation。执行器未验证清单进 questions |
| 规程摘要与 protocol 共处 | 同一流程的摘要易成为第二修改面 | 操作手册保留任务尺度串联；逐条指明 protocol 是步骤规则源 | 未来文字去重必须经过逐句等价检查。本候选保留原文，不以标题同名声称已经完成语义去重 |

正式落地次序是：先落唯一单元目录及来源映射 → 校验九源可原样重建 → 装配新文档与旧入口
兼容视图 → 扫全部入链及裸锚 → 在同一提交切换权威声明 → 独立抽查 → 按既有发布程序生效。
旧稿删除是独立动作，本候选不授权。内核、constraints、protocol 两文件以及原始需求与
轮次归档原位保留，降低切换面。其它旧路径至少保留可用兼容入口；**行号引用只能钉旧
commit，不承诺重排后保留原行号**。若找不到来源 commit，该裸锚在正式切换前必须阻断。

候选内的源文本用 HTML pre 保存为审阅胶囊：解码得到完整 Markdown，内部相对路径与
节号按元数据的源路径/源 commit 解释，不冒充目标文件下已经改好的新链接。正式生成
可读视图须把这些引用解析到稳定单元 ID 或冻结源地址；工具的 show 是现在即可用的
无歧义查件方式。此处声明了待实施的链接重写，**未声称目标目录已部署或链接迁移已验收**。

### 决定记录：查全，再判断适用性

全局键为 `round/<round-id>/R<n>`，轮外为 `work/<work-id>/D<n>`。不得用裸 `R1`
做引用；原文件和编号不改。本文件从三个输入 rulings 的表行机械抽出 26 条，附完整行、
来源路径、行号、commit、摘要，并保留三份源文件的全文，连表外补充说明也可检索。
尤其 runtime-refact/R7 的后文推翻了“只换 clone 即可”的解释，只查表行会漏掉这个变化。

查件命令在后文，`decisions 关键词` 对表行和表外正文搜索：命中表外时显式返回
`CONTEXT` 及全部候选 R 键，要求连同正文核，不把最近一次提到的 R 号臆认成唯一归属。
它返回“记录过什么”，**不自动宣布哪条今天生效**。已有 supersedes 的原文保留，
尚未结构化的替代关系显示“待人工判适用”，不能以排序最后一条代表有效结论。
这比只搜 26 个事由更完整，也比为 26 条手填一份新的裁定摘要少一个写入面。

今后的决定条目：ID、对象、范围、依据、处置、方向、确认回执引用、替代 ID 必填；
未确认/证据不足显式标明。索引每次从源生成，唯一 ID 与源摘要由 CI 核；已冻结记录改字
应拒绝、只能追加替代。**这是拟议文档维护规则，不是假称已部署新回执系统。**
既有可编辑记录以本次冻结快照为起点保护，不倒写历史为“从来不可修改”。

### 新文档归属与十份现有文件抽查

可运行的 `route` 命令接受五个 effect 值之一；空值、多值和未知值拒绝。这是强制申报，
不是按文件名猜测。三个新案例：新的 Executor Adapter 接口合同 `system → N/specs/executor`；
一次 SDK spike 的去敏日志 `record → R/records/work/<id>`；一个修复任务及依赖
`work-instance → W/work/delivery`。具体运行 `route system executor`、
`route record sdk-spike-001`、`route work-instance delivery` 得到唯一文件/目录，
未知主题明确拒绝。若 spike 同时提出接口规范，必须拆成带来源关联的两件。

下表给出旧文件作为完整容器的主职责，并列明迁出部分；迁出后这些部分只有一个写入面。
主职责不赋予旧容器中每句话相同效力。J2 的十件抽查可在右列目标上实施，目标类别唯一。

| 现有文件 | 整体主职责 | 重构后可唯一抽查的对象及类别 |
| --- | --- | --- |
| working/request-lifecycle.md | 产品合同 | 同路径 N，42 节完整 |
| constraints.md | 平台限制 | 同路径 N，15 节完整 |
| protocol/round-protocol.md | 重复执行的规程 | 同路径 P，57 节完整 |
| protocol/README.md | 工具与规范共改契约 | 同路径 P，4 节完整 |
| agent-dev-guide.md | 架构与执行的混合活规范 | foundation N 等正文单元各自唯一；旧路径改 V，历史审计 R |
| development-plan.md | 产品路线 | roadmap W；架构段明确迁 N，原路径 V |
| implementation-plan.md | 具体任务计划 | delivery W；通用条目/测试/交付规则迁 P，原路径 V |
| handoff.md | 当前任务状态 | status W；待办/未决迁 questions W，原路径 V |
| README.md | 入口 | V；旧说明原文作为 migration-context R 保留 |
| rounds/runtime/rulings.md | 一轮的决定和更正 | 原路径 R，完整保留，不并成新规范 |

### Q1–Q8 与邻接边界

| 问题 | 立场与论证 |
| --- | --- |
| Q1 产品合同是否 PRD | 有需求血统但不能只叫 PRD；以产品合约命名，包含对象/状态/不变量/AT 的闭合验证关系。本轮不拆，理由及锚保护见前文；按 F/I/AT 提供索引不能让索引成为另一规范 |
| Q2 rounds 是否 ADR | 只有裁定部分近似 ADR，完整过程还含工单、输入、提案、互评、异议、验收和处置。原目录完整留 R；生成决定索引，不能把其余内容当 ADR 的“噪音”删掉 |
| Q3 protocol 是否实施计划 | 不是。协议约束下一次和这一次工作怎样完成；实施计划每完成一项就改变状态。两者不同生命周期，P 与 W 分开，通过工作单元引用版本连接 |
| Q4 agent-dev-refact 地位 | 依任务书本次更新，轮外吸收已完成，历史稿无现行规范效力；本轮不再跑已退役的旧对照任务。294 行落点全保留为审计对象，未经正文抽查的条目仍未证正确，不凭哈希升级 |
| Q5 request-baseline | 原路径 15 份保留；名分是原始需求 R，合约 N 引用它们，不能修改原话来迎合后来实现 |
| Q6 类别数量 | 五类对应五种修改/取代方式；主题不额外造生命周期。generated 单列防止投影手写漂移，W 单列防止进度被当规范，R 单列保护历史 |
| Q7 标准名 | 不生搬 PRD/ADR/TLD；可在入口解释对照，正式名称按实际合同/规程/任务/记录/视图。架构规范近似技术设计，但其批准和替代仍按本项目协议，不凭缩写带入外部流程 |
| Q8 轮外取证 | 新工作进 records/work/<work-id>，注明指令、输入版本、产物、检查、未核项、确认及证据强度。产品仓原有 docs/evidence/<task-id> 不迁，本目录只引用仓+commit；现有 _r0/_spike-sign 等既定路径原位保留，不批量改名 |

`project-guide/` 继续承担当前实现的说明；N 是要求而非“已实现”证明，W/R 中具体读数
均带日期和来源，不能无证同步成 project-guide 现状。`ai-dev-readiness/` 本轮不动，
其取证只通过有版本引用进入 R，不能覆盖产品规范。未审其内部组织，不替它设新目录。

### 主动列出的争议、未完成验证和反例

1. 本轮以标题单元搬运，某些单元同时含设计准则与一次实验；如执行 SDK 比较、成本反例、
   环境强制点。它们在对应 N/P 中保留完整限定，不能把历史数值读成今天的认证。
   按段彻底分离会更纯粹，但在“不改结论”轮次容易切掉限定；这里选择可审阅的完整单元。
2. 同主题来源相邻融合、不同工作动作拆开，确实改变内部结构；尚未逐句证明重复表述
   等价，因此保留带出处的相邻原文，不把“同主题”冒充“可以删副本”。未来去重另开
   明确的等价验收任务；这也是本方案相对精炼重写稿的体积代价。
3. 一份日常 guide 的生成可减少入口数，但增加装配和链接解析的维护成本；源头维护者
   必须从单元 ID 进入唯一正文。生成方案若没有摘要校验就不能切换，不能先宣布单一真源。
4. 本候选未对 archive 的 294 行重新做全量语义审计；原表和原未核声明一起保存。
   它证明本次 260 节输入搬运无损，不证明上一次吸收无遗漏。
5. 输入 README 仍写 182 行/乙格未清，guide 的换版审计尾部仍描述更早冻结情形；
   状态文字不能充当本轮控制规则。已在本人分支 findings 追加有来源的发现，原句保留。
   G-094 已明确“不采用为现行路线”的旧 R0–R5/S1 计划及其当时进度完整留 R；G-084/085
   的 G0–G5 留 W。这执行输入里已有的规范效力区分，不裁定旧路线中的每件技术任务是否
   已经完成。实施计划仍呈现旧路线的冲突另登记，不能在重排中把它重新发成当前计划。

以下十处在本次生成后回读了完整正文，供随机抽查方法的示例；不声称代表其它 250 节的语义验收：

| 单元 | 正文中实际核到的约束 | 安置判据及边界 |
| --- | --- | --- |
| G-021 | Gate 0 三项、失败退路及仍待验声明 | executor 的租用/准入；没有移成已经验证的选型报告 |
| G-024 | 原 Attempt 保真恢复不能满足时 explicit_unsupported，过渡补法有成本 | executor 的 Port 前置，不能放通用 Task 状态机里改语义 |
| G-036 | 四步事故入口及升级八步，来源不能确认不得进 final | execution 的并发失败处理，不能仅列进常见错误 |
| G-039 | 候选状态是 Artifact 属性，不是 Task/Attempt | runtime 的状态投影，限定与状态图一起保留 |
| G-058 | 审批超时单独记 reason，四档与权力表正交 | authority 的动作门，不能并表抹去两轴 |
| G-071 | 三态与双腿矩阵、补法不冒充已支持、升级两表同验 | executor 的落地矩阵，与能力/Port 相接而不孤立放证据附录 |
| G-077 | 空集合、命令失败、正文和证据两层检查 | review 的判据质量，脚本不代替语义判定 |
| G-086 | 删除七门、真实 T0/T1 留痕、人的确认 | maintenance 的可复用迁移规程，不因搬完就宣布能删 |
| G-097 | 不能排除不同于没查，未知分三类，不因如实披露而处罚 | review 的覆盖声明；因此没有整节藏入 R |
| H-006 | RunBudget 是内存态，载体要换且生产接线材料有时点 | questions 的 U3 决策输入，不升级为今天复跑结论 |

## 核验与查件：可以任取一节复核

后半部的安置表、源元数据、文档包和决定快照由内置工具按冻结 commit 机械校验。
260 单元的定义是排除三反引号代码块后每个一至四级标题起、到下一标题前止；包含标题
后的全部原文，标题前的前言计入首单元。各单元一次且仅一次落入目标包，按源序拼回
必须与九份 Git blob 逐字节相同。正文不是摘要，标题级覆盖与字节级保存分别检查。

在 k8s 仓根执行下面任一条；工具直接从本候选中抽取代码，不依赖临时脚本或额外安装：

```bash
python3 -c 'import pathlib,sys; p=pathlib.Path("sunmoonai/docs/dev-plan/dev-plan-architecture.md"); s=p.read_text(); exec(s.split("<!-- TOOL BEGIN -->\n```python\n",1)[1].split("\n```\n<!-- TOOL END -->",1)[0])' verify
python3 -c 'import pathlib,sys; p=pathlib.Path("sunmoonai/docs/dev-plan/dev-plan-architecture.md"); s=p.read_text(); exec(s.split("<!-- TOOL BEGIN -->\n```python\n",1)[1].split("\n```\n<!-- TOOL END -->",1)[0])' show G-040
python3 -c 'import pathlib,sys; p=pathlib.Path("sunmoonai/docs/dev-plan/dev-plan-architecture.md"); s=p.read_text(); exec(s.split("<!-- TOOL BEGIN -->\n```python\n",1)[1].split("\n```\n<!-- TOOL END -->",1)[0])' decisions 回执
python3 -c 'import pathlib,sys; p=pathlib.Path("sunmoonai/docs/dev-plan/dev-plan-architecture.md"); s=p.read_text(); exec(s.split("<!-- TOOL BEGIN -->\n```python\n",1)[1].split("\n```\n<!-- TOOL END -->",1)[0])' route record
```

`show` 也接受目标路径，按栏目输出整份已装配正文；将末尾参数改为 `map` 可重新生成
260 行安置表，改为 `view guide` 可实际装配单份日常指南。装配顺序为基础边界 →
产品合约/平台约束 → 运行时/执行器/授权/证据 → 受理/执行/评审 → 轮次规程及工具接口 →
交付/维护。每个 N/P 源文档只装配一次，W/R 不装入；原有历史例证的限制随正文保留。
这份完整视图可能仍长，但修改责任与一次任务的阅读顺序已分离，不再让审计收据占据规程正文。
README 只列 N/P/W/R 入口及生成版本；handoff 装配 status/questions；development-plan
装配 roadmap 并指向 N；implementation-plan 装配 delivery 并指向通用表单。后三个兼容
视图的链接生成是正式切换工作，当前工具只实现完整 guide，以验证单源装配可行。

`verify` 核源摘要、260 个标题边界、
源文本、唯一落点、表格与正文对应、26 条裁定和受保护文件全文。随机抽查可以任挑 ID，
不必相信作者选的十例。代码不替人判语义；它只把可判和不可判分开。

基线检查：`doc-gate.py --all` 为 207 份通过；`anchor-gate.py` 硬判通过，29 个钉 commit
锚、189 个裸路径行号锚，另有 217 处章节软判、14 处既有归档不可解析软判。
这些软判不是本候选修好的问题。提交前对含候选的索引再跑两门，结果写在提交说明。
没有运行 SDK、网络、生产、外部身份验证，也没有改 gate 豁免范围。

本候选工具已实跑：verify 通过；三个确定归属案例和未知值拒绝通过；全局 R7 查询
能连同表外“独立 clone”更正取回，关键词“回执”覆盖三轮，未命中返回非成功；
map 重生 260 行，view guide 装配全部 N/P 且含覆盖声明与旧设计禁令。
另在内存副本分别删除单元、伪造目标、改动正文，三种负例均被拒绝，未修改冻结源。

## 安置表（由脚本枚举，不与架构论证混写）

表中编号是本次冻结输入的稳定单元 ID；`目标 / 栏目` 是后面已有完整正文的实际落点。
每个目标栏目有前置准入判据。没有故意丢弃项。历史标题壳保留在迁移上下文，防止它们的
旧阅读顺序冒充新架构；空正文标题仍有完整原始标题可取，不以其不含正文为由漏计。

| 单元 | 冻结源路径与起行 | 原标题 | 目标 / 栏目 |
| --- | --- | --- | --- |
| K-001 | working/request-lifecycle.md L1 | Request Lifecycle：产品请求生命周期合同 | working/request-lifecycle.md / 合约全文 |
| K-002 | working/request-lifecycle.md L13 | 0. 规范边界与条款筛选 | working/request-lifecycle.md / 合约全文 |
| K-003 | working/request-lifecycle.md L15 | 0.1 只收产品要求 | working/request-lifecycle.md / 合约全文 |
| K-004 | working/request-lifecycle.md L29 | 0.2 本文负责什么 | working/request-lifecycle.md / 合约全文 |
| K-005 | working/request-lifecycle.md L52 | 0.3 规范用语 | working/request-lifecycle.md / 合约全文 |
| K-006 | working/request-lifecycle.md L58 | 1. 生命周期全景 | working/request-lifecycle.md / 合约全文 |
| K-007 | working/request-lifecycle.md L92 | 2. 核心对象 | working/request-lifecycle.md / 合约全文 |
| K-008 | working/request-lifecycle.md L106 | 2.1 Task 不等于 Attempt | working/request-lifecycle.md / 合约全文 |
| K-009 | working/request-lifecycle.md L120 | 2.2 Submission 不一定产生 Task | working/request-lifecycle.md / 合约全文 |
| K-010 | working/request-lifecycle.md L127 | 3. Task 契约 | working/request-lifecycle.md / 合约全文 |
| K-011 | working/request-lifecycle.md L129 | 3.1 提交信封 | working/request-lifecycle.md / 合约全文 |
| K-012 | working/request-lifecycle.md L147 | 3.2 持久化主档 | working/request-lifecycle.md / 合约全文 |
| K-013 | working/request-lifecycle.md L166 | 3.3 解释、边界与完成契约 | working/request-lifecycle.md / 合约全文 |
| K-014 | working/request-lifecycle.md L183 | 3.4 最终结果信封 | working/request-lifecycle.md / 合约全文 |
| K-015 | working/request-lifecycle.md L203 | 4. 两层状态机 | working/request-lifecycle.md / 合约全文 |
| K-016 | working/request-lifecycle.md L205 | 4.1 Task 状态机 | working/request-lifecycle.md / 合约全文 |
| K-017 | working/request-lifecycle.md L247 | 4.2 WAITING 与 Interaction | working/request-lifecycle.md / 合约全文 |
| K-018 | working/request-lifecycle.md L279 | 4.3 取消意图与终态 | working/request-lifecycle.md / 合约全文 |
| K-019 | working/request-lifecycle.md L292 | 4.4 终态、刷新与重新处理 | working/request-lifecycle.md / 合约全文 |
| K-020 | working/request-lifecycle.md L304 | 4.5 Attempt / Run 状态机 | working/request-lifecycle.md / 合约全文 |
| K-021 | working/request-lifecycle.md L346 | 5. 七阶段产品功能 | working/request-lifecycle.md / 合约全文 |
| K-022 | working/request-lifecycle.md L351 | 5.1 提交（前端） | working/request-lifecycle.md / 合约全文 |
| K-023 | working/request-lifecycle.md L360 | 5.2 受理与校验（后端） | working/request-lifecycle.md / 合约全文 |
| K-024 | working/request-lifecycle.md L369 | 5.3 排队与可靠投递 | working/request-lifecycle.md / 合约全文 |
| K-025 | working/request-lifecycle.md L377 | 5.4 Agent 执行 | working/request-lifecycle.md / 合约全文 |
| K-026 | working/request-lifecycle.md L391 | 5.5 中断、批准与恢复 | working/request-lifecycle.md / 合约全文 |
| K-027 | working/request-lifecycle.md L398 | 5.6 验收与完成提交 | working/request-lifecycle.md / 合约全文 |
| K-028 | working/request-lifecycle.md L413 | 5.7 返回前端、失败与重试 | working/request-lifecycle.md / 合约全文 |
| K-029 | working/request-lifecycle.md L442 | 6. 跨进程纪律与持久化账 | working/request-lifecycle.md / 合约全文 |
| K-030 | working/request-lifecycle.md L444 | 6.1 全程不变量 | working/request-lifecycle.md / 合约全文 |
| K-031 | working/request-lifecycle.md L467 | 6.2 持久化记录 | working/request-lifecycle.md / 合约全文 |
| K-032 | working/request-lifecycle.md L485 | 7. Profile、Artifact 与扩展 | working/request-lifecycle.md / 合约全文 |
| K-033 | working/request-lifecycle.md L487 | 7.1 Task Profile 与 Agent Profile | working/request-lifecycle.md / 合约全文 |
| K-034 | working/request-lifecycle.md L508 | 7.2 Profile 示例 | working/request-lifecycle.md / 合约全文 |
| K-035 | working/request-lifecycle.md L520 | 8. 子 Task 与依赖编排 | working/request-lifecycle.md / 合约全文 |
| K-036 | working/request-lifecycle.md L550 | 9. 前端、后端与 Agent 责任投影 | working/request-lifecycle.md / 合约全文 |
| K-037 | working/request-lifecycle.md L566 | 10. 反模式 | working/request-lifecycle.md / 合约全文 |
| K-038 | working/request-lifecycle.md L586 | 11. 产品验收矩阵 | working/request-lifecycle.md / 合约全文 |
| K-039 | working/request-lifecycle.md L623 | 12. 修订、落地与参考材料 | working/request-lifecycle.md / 合约全文 |
| K-040 | working/request-lifecycle.md L625 | 12.1 修订纪律 | working/request-lifecycle.md / 合约全文 |
| K-041 | working/request-lifecycle.md L637 | 12.2 参考材料边界 | working/request-lifecycle.md / 合约全文 |
| K-042 | working/request-lifecycle.md L643 | 12.3 生效边界 | working/request-lifecycle.md / 合约全文 |
| G-001 | agent-dev-guide.md L1 | Agent 开发指导：一个产品运行时，一套开发纪律 | records/migration-context.md / 旧 guide 结构上下文 |
| G-002 | agent-dev-guide.md L23 | 0. 先读结论 | specs/foundation.md / 边界与原则 |
| G-003 | agent-dev-guide.md L52 | 0.0 原来是什么样，为什么非改不可 | specs/foundation.md / 边界与原则 |
| G-004 | agent-dev-guide.md L70 | 0.1 文档边界 | specs/foundation.md / 边界与原则 |
| G-005 | agent-dev-guide.md L87 | 0.2 为什么分成这些章 | records/migration-context.md / 旧 guide 结构上下文 |
| G-006 | agent-dev-guide.md L106 | 0.3 按工作阶段阅读，不按历史版本阅读 | records/migration-context.md / 旧 guide 结构上下文 |
| G-007 | agent-dev-guide.md L126 | 1. 不可变的契约与边界 | specs/foundation.md / 边界与原则 |
| G-008 | agent-dev-guide.md L128 | 1.1 唯一产品内核 | specs/foundation.md / 边界与原则 |
| G-009 | agent-dev-guide.md L143 | 1.2 四本账与单一权威写入面 | specs/runtime.md / 持久责任与组件 |
| G-010 | agent-dev-guide.md L151 | 1.3 Agent 硬约束自检 | playbooks/intake.md / 自检与受理 |
| G-011 | agent-dev-guide.md L164 | 1.4 开发验收不可外推 | specs/foundation.md / 边界与原则 |
| G-012 | agent-dev-guide.md L171 | 1.5 执行者的共同纪律 | playbooks/intake.md / 自检与受理 |
| G-013 | agent-dev-guide.md L187 | 1.6 七条设计原则 | specs/foundation.md / 边界与原则 |
| G-014 | agent-dev-guide.md L213 | 1.7 先核前提，也核控制面 | playbooks/review.md / 检查的反例与复核 |
| G-015 | agent-dev-guide.md L235 | 2. 一个运行时的结构 | records/migration-context.md / 旧 guide 结构上下文 |
| G-016 | agent-dev-guide.md L237 | 2.1 确定性组件与适配层 | specs/runtime.md / 持久责任与组件 |
| G-017 | agent-dev-guide.md L255 | 2.2 内容角色 | specs/runtime.md / 角色与派工契约 |
| G-018 | agent-dev-guide.md L269 | 2.3 Task Profile 与 Agent Profile | specs/runtime.md / 角色与派工契约 |
| G-019 | agent-dev-guide.md L293 | 2.4 dev.change/1 工单 | specs/runtime.md / 角色与派工契约 |
| G-020 | agent-dev-guide.md L347 | 2.5 路由只读可判字段 | specs/runtime.md / 角色与派工契约 |
| G-021 | agent-dev-guide.md L354 | 2.6 执行层：租用什么、自建什么 | specs/executor.md / 租用边界与能力 |
| G-022 | agent-dev-guide.md L408 | 2.7 两个官方 SDK：两个轴、非对称能力 | specs/executor.md / 租用边界与能力 |
| G-023 | agent-dev-guide.md L433 | 2.8 统一执行 Port 与三态能力探针 | specs/executor.md / Port 与适配门 |
| G-024 | agent-dev-guide.md L483 | 2.9 Harness 腿的前置门禁与过渡补法 | specs/executor.md / Port 与适配门 |
| G-025 | agent-dev-guide.md L511 | 2.10 双 runtime 的部署、进程与恢复 | specs/executor.md / 两腿恢复与部署 |
| G-026 | agent-dev-guide.md L548 | 2.11 派工契约、角色补充与隔离的诚实边界 | specs/runtime.md / 角色与派工契约 |
| G-027 | agent-dev-guide.md L587 | 2.12 五家 Agent Profile 的历史取值示例 | records/guide-history.md / 历史实测与实例 |
| G-028 | agent-dev-guide.md L649 | 3. 一次开发 Task 怎样执行 | records/migration-context.md / 旧 guide 结构上下文 |
| G-029 | agent-dev-guide.md L651 | 3.1 受理与冻结 | playbooks/intake.md / 自检与受理 |
| G-030 | agent-dev-guide.md L682 | 3.2 工作区供给 | playbooks/execution.md / 工作区准备 |
| G-031 | agent-dev-guide.md L704 | 3.3 Attempt 与状态投影 | specs/runtime.md / 状态和载体投影 |
| G-032 | agent-dev-guide.md L741 | 3.4 T0/T1/T2 不是三套状态机 | specs/runtime.md / 状态和载体投影 |
| G-033 | agent-dev-guide.md L767 | 3.5 交付、清理和恢复 | playbooks/delivery.md / 发布与保留 |
| G-034 | agent-dev-guide.md L782 | 3.6 私有地产生，单写者发布 | playbooks/execution.md / 写入与并发 |
| G-035 | agent-dev-guide.md L822 | 3.7 并发场景处置表 | playbooks/execution.md / 写入与并发 |
| G-036 | agent-dev-guide.md L863 | 3.8 覆盖或来源不明时的事故规程 | playbooks/execution.md / 写入与并发 |
| G-037 | agent-dev-guide.md L893 | 3.9 冻结、迟到与取消 | playbooks/execution.md / 停止与恢复入口 |
| G-038 | agent-dev-guide.md L914 | 3.10 物化门禁与写入前门禁 | playbooks/execution.md / 写入与并发 |
| G-039 | agent-dev-guide.md L969 | 3.11 候选状态机 | specs/runtime.md / 状态和载体投影 |
| G-040 | agent-dev-guide.md L988 | 3.12 完成判据 | playbooks/delivery.md / 完成与证据包 |
| G-041 | agent-dev-guide.md L1009 | 3.13 执行形态、停止规则与成本 | playbooks/execution.md / 停止与恢复入口 |
| G-042 | agent-dev-guide.md L1042 | 3.14 建立 worktree 的细则 | playbooks/execution.md / 工作区准备 |
| G-043 | agent-dev-guide.md L1055 | 3.15 发布协议：三个路径不是一个 | playbooks/delivery.md / 发布与保留 |
| G-044 | agent-dev-guide.md L1078 | 3.16 保留与垃圾回收 | playbooks/delivery.md / 发布与保留 |
| G-045 | agent-dev-guide.md L1093 | 3.17 内核对象 ↔ 开发载体对照 | specs/runtime.md / 状态和载体投影 |
| G-046 | agent-dev-guide.md L1114 | 3.18 状态脚本的硬要求 | specs/runtime.md / 状态和载体投影 |
| G-047 | agent-dev-guide.md L1131 | 3.19 T2 七环节的操作闭环 | playbooks/review.md / 七环节操作接口 |
| G-048 | agent-dev-guide.md L1169 | 3.20 工作区能写，不代表 Git 能提交 | playbooks/execution.md / 工作区准备 |
| G-049 | agent-dev-guide.md L1199 | 3.21 通知、取件与人的检视面 | playbooks/review.md / 七环节操作接口 |
| G-050 | agent-dev-guide.md L1224 | 3.22 停止、超时与回退不能省略 | playbooks/execution.md / 停止与恢复入口 |
| G-051 | agent-dev-guide.md L1247 | 4. 人介入、Interaction 与权力 | records/migration-context.md / 旧 guide 结构上下文 |
| G-052 | agent-dev-guide.md L1249 | 4.1 人的位置 | specs/authority.md / 主体与权力 |
| G-053 | agent-dev-guide.md L1261 | 4.2 权力表 | specs/authority.md / 主体与权力 |
| G-054 | agent-dev-guide.md L1284 | 4.3 直接沿用实际中断/恢复原语 | specs/executor.md / 两腿恢复与部署 |
| G-055 | agent-dev-guide.md L1347 | 4.4 身份、批准与强制点 | specs/authority.md / 边界与动作门 |
| G-056 | agent-dev-guide.md L1383 | 4.5 权限公式与只有 principal 能做的动作 | specs/authority.md / 主体与权力 |
| G-057 | agent-dev-guide.md L1430 | 4.6 三道正交门 | specs/authority.md / 边界与动作门 |
| G-058 | agent-dev-guide.md L1452 | 4.7 四档审批 | specs/authority.md / 边界与动作门 |
| G-059 | agent-dev-guide.md L1481 | 4.8 principal 的裁量权与改判纪律 | playbooks/review.md / 批准对象与人的动作 |
| G-060 | agent-dev-guide.md L1509 | 4.9 Attempt 内的三条硬禁令 | specs/authority.md / 执行中禁止与凭据传播 |
| G-061 | agent-dev-guide.md L1528 | 4.10 人这一侧的义务 | playbooks/review.md / 批准对象与人的动作 |
| G-062 | agent-dev-guide.md L1549 | 4.11 本轮已发生介入的实例级清单 | records/guide-history.md / 历史实测与实例 |
| G-063 | agent-dev-guide.md L1580 | 4.12 人的收件箱：让批准具体、可读、可重取 | playbooks/review.md / 批准对象与人的动作 |
| G-064 | agent-dev-guide.md L1605 | 4.13 执行器凭据、子进程与跨腿委派 | specs/authority.md / 执行中禁止与凭据传播 |
| G-065 | agent-dev-guide.md L1629 | 5. 可观测性、证据与等效 | records/migration-context.md / 旧 guide 结构上下文 |
| G-066 | agent-dev-guide.md L1631 | 5.1 三个粒度字段 | specs/evidence.md / 观测及采信 |
| G-067 | agent-dev-guide.md L1659 | 5.2 证据等级与采信规则 | specs/evidence.md / 观测及采信 |
| G-068 | agent-dev-guide.md L1674 | 5.3 手工态与服务态的等效判据 | specs/evidence.md / 载体与等效 |
| G-069 | agent-dev-guide.md L1699 | 5.4 Git 载体能与不能证明什么 | specs/evidence.md / 载体与等效 |
| G-070 | agent-dev-guide.md L1709 | 5.5 四层验证 | playbooks/review.md / 验收与整合 |
| G-071 | agent-dev-guide.md L1721 | 5.6 F-EXEC-* / F-INTERACT-* 双腿落地矩阵 | specs/executor.md / 两腿恢复与部署 |
| G-072 | agent-dev-guide.md L1747 | 5.7 证据账按流程分级 | playbooks/review.md / 验收与整合 |
| G-073 | agent-dev-guide.md L1774 | 5.8 上下文路由与能力四级词典 | specs/evidence.md / 观测及采信 |
| G-074 | agent-dev-guide.md L1804 | 5.9 七种载体各能证明什么 | specs/evidence.md / 载体与等效 |
| G-075 | agent-dev-guide.md L1827 | 5.10 事实裁决表与整合纪律 | playbooks/review.md / 验收与整合 |
| G-076 | agent-dev-guide.md L1851 | 5.11 轨迹实测：23 条里 2 条 attested | records/guide-history.md / 历史实测与实例 |
| G-077 | agent-dev-guide.md L1899 | 5.12 检查本身也必须接受检查 | playbooks/review.md / 检查的反例与复核 |
| G-078 | agent-dev-guide.md L1916 | 5.13 历史取证怎样用于今天的开发 | specs/evidence.md / 观测及采信 |
| G-079 | agent-dev-guide.md L1930 | 6. 什么时候运行时值得用 | records/migration-context.md / 旧 guide 结构上下文 |
| G-080 | agent-dev-guide.md L1932 | 6.1 机械分类 | specs/evidence.md / 成本和观察上界 |
| G-081 | agent-dev-guide.md L1947 | 6.2 三类反例与 T0 上界 | specs/evidence.md / 成本和观察上界 |
| G-082 | agent-dev-guide.md L1963 | 6.3 绕过只能部分可观测 | specs/evidence.md / 成本和观察上界 |
| G-083 | agent-dev-guide.md L1986 | 7. 演进与退出脚手架 | records/migration-context.md / 旧 guide 结构上下文 |
| G-084 | agent-dev-guide.md L1988 | 7.1 依赖顺序 | work/roadmap.md / 运行时迁移顺序 |
| G-085 | agent-dev-guide.md L2002 | 7.2 从手工态拆到服务态 | work/roadmap.md / 运行时迁移顺序 |
| G-086 | agent-dev-guide.md L2038 | 7.3 删除与迁移门 | playbooks/maintenance.md / 迁移与修订 |
| G-087 | agent-dev-guide.md L2073 | 7.4 风险和未决 | work/questions.md / 风险与验证债 |
| G-088 | agent-dev-guide.md L2104 | 7.5 跨会话续接 | playbooks/maintenance.md / 续接 |
| G-089 | agent-dev-guide.md L2140 | 7.6 执行器架构的未验证清单 | work/questions.md / 风险与验证债 |
| G-090 | agent-dev-guide.md L2159 | 7.7 需要改内核时，提交明确的修订工作单元 | playbooks/maintenance.md / 迁移与修订 |
| G-091 | agent-dev-guide.md L2178 | 8. 本轮核查裁定 | specs/foundation.md / 已裁定的设计边界 |
| G-092 | agent-dev-guide.md L2189 | 8.1 六项逐条处置 | specs/foundation.md / 已裁定的设计边界 |
| G-093 | agent-dev-guide.md L2206 | 8.2 保留与撤销 | specs/foundation.md / 已裁定的设计边界 |
| G-094 | agent-dev-guide.md L2215 | 8.3 本次补吸收明确不采用的旧主张 | specs/foundation.md / 已裁定的设计边界 |
| G-095 | agent-dev-guide.md L2235 | 9. 覆盖声明 | records/guide-audit.md / 核验声明与补吸收 |
| G-096 | agent-dev-guide.md L2241 | 9.1 查了什么 | records/guide-audit.md / 核验声明与补吸收 |
| G-097 | agent-dev-guide.md L2253 | 9.2 没查什么 | playbooks/review.md / 覆盖声明的写法 |
| G-098 | agent-dev-guide.md L2299 | 9.3 自增内容及理由（runtime-refact 轮） | records/guide-audit.md / 核验声明与补吸收 |
| G-099 | agent-dev-guide.md L2306 | 9.4 两份 lifecycle 的吸收轮（2026-09-07） | records/guide-audit.md / 核验声明与补吸收 |
| G-100 | agent-dev-guide.md L2448 | 9.5 GPT-6 再吸收记录（2026-09-08） | records/guide-audit.md / 核验声明与补吸收 |
| G-101 | agent-dev-guide.md L2507 | 9.6 取代前 opus 做的核验（2026-09-08） | records/guide-audit.md / 核验声明与补吸收 |
| G-102 | agent-dev-guide.md L2554 | 10. 五份历史正文及目录说明的逐节处置 | records/guide-audit.md / 历史源落点收据 |
| G-103 | agent-dev-guide.md L2876 | 11. 反模式 | specs/foundation.md / 名词与反例 |
| G-104 | agent-dev-guide.md L2924 | 12. 常见失败方式与项目实例 | playbooks/review.md / 检查的反例与复核 |
| G-105 | agent-dev-guide.md L2965 | 12.1 七种“检查给出假答案”的回归线索 | playbooks/review.md / 检查的反例与复核 |
| G-106 | agent-dev-guide.md L2984 | 12.2 并行评审的收益与盲区 | playbooks/review.md / 检查的反例与复核 |
| G-107 | agent-dev-guide.md L3004 | 13. 词汇对照 | specs/foundation.md / 名词与反例 |
| G-108 | agent-dev-guide.md L3038 | 14. 开发 Task 持久记录模板 | playbooks/intake.md / 记录表单 |
| P-001 | protocol/round-protocol.md L1 | 并行评优轮：流程 | protocol/round-protocol.md / 完整轮次规程 |
| P-002 | protocol/round-protocol.md L22 | 0. 收到「继续」时怎么办 | protocol/round-protocol.md / 完整轮次规程 |
| P-003 | protocol/round-protocol.md L52 | 1. 流程档位：这件事该走多重的流程 | protocol/round-protocol.md / 完整轮次规程 |
| P-004 | protocol/round-protocol.md L64 | 1.0 一套流程，靠参数覆盖三种协作形态 | protocol/round-protocol.md / 完整轮次规程 |
| P-005 | protocol/round-protocol.md L85 | 1.1 判据：命中任一条即 T2 | protocol/round-protocol.md / 完整轮次规程 |
| P-006 | protocol/round-protocol.md L99 | 1.2 升档随意，降档要理由——这条不对称是有意的 | protocol/round-protocol.md / 完整轮次规程 |
| P-007 | protocol/round-protocol.md L111 | 1.3 任何档位都不能省的三条 | protocol/round-protocol.md / 完整轮次规程 |
| P-008 | protocol/round-protocol.md L120 | 2. 裁量权：supervisor 可以临机决定什么 | protocol/round-protocol.md / 完整轮次规程 |
| P-009 | protocol/round-protocol.md L127 | 2.1 不可裁量的下限 | protocol/round-protocol.md / 完整轮次规程 |
| P-010 | protocol/round-protocol.md L138 | 2.2 可裁量的事项 | protocol/round-protocol.md / 完整轮次规程 |
| P-011 | protocol/round-protocol.md L143 | 2.3 方向不对称：这是本协议的统一原则 | protocol/round-protocol.md / 完整轮次规程 |
| P-012 | protocol/round-protocol.md L159 | 2.4 裁定记录：未记录的裁定无效 | protocol/round-protocol.md / 完整轮次规程 |
| P-013 | protocol/round-protocol.md L171 | 2.5 推翻 | protocol/round-protocol.md / 完整轮次规程 |
| P-014 | protocol/round-protocol.md L179 | 2.6 裁量是规则的孵化器 | protocol/round-protocol.md / 完整轮次规程 |
| P-015 | protocol/round-protocol.md L191 | 3. 执行者与触发方式：两个轴，不要混 | protocol/round-protocol.md / 完整轮次规程 |
| P-016 | protocol/round-protocol.md L197 | 3.1 两个轴 | protocol/round-protocol.md / 完整轮次规程 |
| P-017 | protocol/round-protocol.md L209 | 3.2 全部动作的归属 | protocol/round-protocol.md / 完整轮次规程 |
| P-018 | protocol/round-protocol.md L226 | 3.3 两类「人做」不可互相顶替 | protocol/round-protocol.md / 完整轮次规程 |
| P-019 | protocol/round-protocol.md L236 | 4. 七个环节（T2 专用） | protocol/round-protocol.md / 完整轮次规程 |
| P-020 | protocol/round-protocol.md L263 | 5. 本轮定义：round.md | protocol/round-protocol.md / 完整轮次规程 |
| P-021 | protocol/round-protocol.md L291 | 6. 产物、路径与命名 | protocol/round-protocol.md / 完整轮次规程 |
| P-022 | protocol/round-protocol.md L323 | 6.1 环节通知：组织者的产物，不是发起人的话术 | protocol/round-protocol.md / 完整轮次规程 |
| P-023 | protocol/round-protocol.md L344 | 7. 取件与检视面 | protocol/round-protocol.md / 完整轮次规程 |
| P-024 | protocol/round-protocol.md L349 | 7.1 取件：一律按 commit，不看工作区 | protocol/round-protocol.md / 完整轮次规程 |
| P-025 | protocol/round-protocol.md L365 | 7.2 检视面：需要人读时开临时 worktree | protocol/round-protocol.md / 完整轮次规程 |
| P-026 | protocol/round-protocol.md L382 | 7.3 每个需要人读的环节都必须先有检视面 | protocol/round-protocol.md / 完整轮次规程 |
| P-027 | protocol/round-protocol.md L391 | 8. 环节判定：命令即判据 | protocol/round-protocol.md / 完整轮次规程 |
| P-028 | protocol/round-protocol.md L427 | 8.1 判据自身的质量：覆盖不全比没有更危险 | protocol/round-protocol.md / 完整轮次规程 |
| P-029 | protocol/round-protocol.md L465 | 8.2 立判据的人怎么约束自己 | protocol/round-protocol.md / 完整轮次规程 |
| P-030 | protocol/round-protocol.md L472 | 只写判据，不写答案 | protocol/round-protocol.md / 完整轮次规程 |
| P-031 | protocol/round-protocol.md L484 | 立据人的四条自我约束 | protocol/round-protocol.md / 完整轮次规程 |
| P-032 | protocol/round-protocol.md L492 | 难点清单：记下来是为了检验发起方 | protocol/round-protocol.md / 完整轮次规程 |
| P-033 | protocol/round-protocol.md L501 | 三条通用扣分规则 | protocol/round-protocol.md / 完整轮次规程 |
| P-034 | protocol/round-protocol.md L507 | 起草人回避 | protocol/round-protocol.md / 完整轮次规程 |
| P-035 | protocol/round-protocol.md L516 | 判据自身的失效条件 | protocol/round-protocol.md / 完整轮次规程 |
| P-036 | protocol/round-protocol.md L529 | 一票否决项要事先列 | protocol/round-protocol.md / 完整轮次规程 |
| P-037 | protocol/round-protocol.md L534 | 8b. 两个脚本怎么调 | protocol/round-protocol.md / 完整轮次规程 |
| P-038 | protocol/round-protocol.md L553 | 退出码 | protocol/round-protocol.md / 完整轮次规程 |
| P-039 | protocol/round-protocol.md L564 | 声明与计算对不上时 | protocol/round-protocol.md / 完整轮次规程 |
| P-040 | protocol/round-protocol.md L576 | 8c. 组织者的两条纪律 | protocol/round-protocol.md / 完整轮次规程 |
| P-041 | protocol/round-protocol.md L581 | 8c.1 环节进行中，组织者不得写入参与方的工作区 | protocol/round-protocol.md / 完整轮次规程 |
| P-042 | protocol/round-protocol.md L604 | 8c.2 代提交必须用 --author，且必须登记为欠账 | protocol/round-protocol.md / 完整轮次规程 |
| P-043 | protocol/round-protocol.md L619 | 9. ① 提案：隔离与冻结 | protocol/round-protocol.md / 完整轮次规程 |
| P-044 | protocol/round-protocol.md L624 | 9.1 隔离为什么是硬要求 | protocol/round-protocol.md / 完整轮次规程 |
| P-045 | protocol/round-protocol.md L644 | 9.2 工单发什么、不发什么 | protocol/round-protocol.md / 完整轮次规程 |
| P-046 | protocol/round-protocol.md L675 | 9.3 机制化隔离：曾经有过，已经删掉 | protocol/round-protocol.md / 完整轮次规程 |
| P-047 | protocol/round-protocol.md L690 | 10. ② 互评：评审文件写什么 | protocol/round-protocol.md / 完整轮次规程 |
| P-048 | protocol/round-protocol.md L713 | 11. ③ 裁决：定基座与吸收 | protocol/round-protocol.md / 完整轮次规程 |
| P-049 | protocol/round-protocol.md L724 | 12. ④ 异议：对整合权的唯一制衡 | protocol/round-protocol.md / 完整轮次规程 |
| P-050 | protocol/round-protocol.md L741 | 13. ⑤ 验收 与 ⑥ 确认 | protocol/round-protocol.md / 完整轮次规程 |
| P-051 | protocol/round-protocol.md L760 | 13.1 定向审核分两阶段，防止被产出方锚定 | protocol/round-protocol.md / 完整轮次规程 |
| P-052 | protocol/round-protocol.md L780 | 13.2 验收通过意味着什么，不意味着什么 | protocol/round-protocol.md / 完整轮次规程 |
| P-053 | protocol/round-protocol.md L789 | 14. 停止、超时与回退 | protocol/round-protocol.md / 完整轮次规程 |
| P-054 | protocol/round-protocol.md L803 | 14.1 参与方不可用：逾期、弃权与换人 | protocol/round-protocol.md / 完整轮次规程 |
| P-055 | protocol/round-protocol.md L883 | 15. 角色不分会怎样 | protocol/round-protocol.md / 完整轮次规程 |
| P-056 | protocol/round-protocol.md L902 | 16. ⑦ 清理与发布 | protocol/round-protocol.md / 完整轮次规程 |
| P-057 | protocol/round-protocol.md L917 | 17. 通用纪律 | protocol/round-protocol.md / 完整轮次规程 |
| T-001 | protocol/README.md L1 | protocol/ —— 流程规范与它的实现 | protocol/README.md / 脚本接口及实现约束 |
| T-002 | protocol/README.md L23 | 三条设计约束，改这里的代码前先读 | protocol/README.md / 脚本接口及实现约束 |
| T-003 | protocol/README.md L33 | 单一真源 | protocol/README.md / 脚本接口及实现约束 |
| T-004 | protocol/README.md L39 | 已知不做的事 | protocol/README.md / 脚本接口及实现约束 |
| C-001 | constraints.md L1 | 开发必须遵守的规则 | constraints.md / 约束与执行载体 |
| C-002 | constraints.md L13 | 怎么用 | constraints.md / 约束与执行载体 |
| C-003 | constraints.md L40 | 数据 | constraints.md / 约束与执行载体 |
| C-004 | constraints.md L54 | 做数据迁移时 | constraints.md / 约束与执行载体 |
| C-005 | constraints.md L71 | 契约 | constraints.md / 约束与执行载体 |
| C-006 | constraints.md L82 | 身份 | constraints.md / 约束与执行载体 |
| C-007 | constraints.md L95 | 拓扑 | constraints.md / 约束与执行载体 |
| C-008 | constraints.md L105 | 什么时候才拆出专用 Worker | constraints.md / 约束与执行载体 |
| C-009 | constraints.md L116 | 发布 | constraints.md / 约束与执行载体 |
| C-010 | constraints.md L128 | 改模板、同步实例时 | constraints.md / 约束与执行载体 |
| C-011 | constraints.md L137 | 清理镜像时 | constraints.md / 约束与执行载体 |
| C-012 | constraints.md L144 | 一条环境事实 | constraints.md / 约束与执行载体 |
| C-013 | constraints.md L149 | 智能体 | constraints.md / 约束与执行载体 |
| C-014 | constraints.md L161 | 保证这些被遵守的三层 | constraints.md / 约束与执行载体 |
| C-015 | constraints.md L181 | doc-gate.py 为什么不是第三个被删的脚本 | constraints.md / 约束与执行载体 |
| D-001 | development-plan.md L1 | 开发计划 | records/migration-context.md / 旧入口上下文 |
| D-002 | development-plan.md L10 | 起点：不延续 v5 | specs/foundation.md / 产品取舍 |
| D-003 | development-plan.md L24 | 智能体分两部分 | specs/runtime.md / 持久责任与组件 |
| D-004 | development-plan.md L36 | 四本账是两部分共用的地基 | specs/runtime.md / 持久责任与组件 |
| D-005 | development-plan.md L44 | 执行层租用，不自建 | specs/executor.md / 租用边界与能力 |
| D-006 | development-plan.md L64 | 三个阶段 | work/roadmap.md / 产品建设阶段 |
| D-007 | development-plan.md L68 | 一 · 前后端对接 | work/roadmap.md / 产品建设阶段 |
| D-008 | development-plan.md L97 | 二 · agent 开发 | work/roadmap.md / 产品建设阶段 |
| D-009 | development-plan.md L110 | 三 · 结构化数据问答（后期） | work/roadmap.md / 产品建设阶段 |
| D-010 | development-plan.md L134 | 有意留白的两处 | specs/foundation.md / 产品取舍 |
| I-001 | implementation-plan.md L1 | 实施计划 | records/migration-context.md / 旧入口上下文 |
| I-002 | implementation-plan.md L11 | 任务条目格式 | playbooks/intake.md / 记录表单 |
| I-003 | implementation-plan.md L27 | 测试层次 | playbooks/review.md / 验收与整合 |
| I-004 | implementation-plan.md L38 | 交付规则 | playbooks/delivery.md / 完成与证据包 |
| I-005 | implementation-plan.md L53 | 阶段〇 · 开发框架自身的实施路线（R0–R5） | records/guide-history.md / 旧路线及当时进度 |
| I-006 | implementation-plan.md L77 | 阶段一 · 前后端对接 | work/delivery.md / 产品任务 |
| I-007 | implementation-plan.md L79 | 任务清单 | work/delivery.md / 产品任务 |
| I-008 | implementation-plan.md L86 | 阶段二 · agent 开发 | work/delivery.md / 产品任务 |
| I-009 | implementation-plan.md L90 | 阶段三 · 结构化数据问答 | work/delivery.md / 产品任务 |
| H-001 | handoff.md L1 | 交接 | records/migration-context.md / 旧入口上下文 |
| H-002 | handoff.md L14 | 当前阶段 | work/status.md / 产品状态 |
| H-003 | handoff.md L21 | 已经就位的（不用再做） | work/status.md / 产品状态 |
| H-004 | handoff.md L30 | 未决项 | work/questions.md / 未决输入 |
| H-005 | handoff.md L42 | U1 的已知输入 | work/questions.md / 未决输入 |
| H-006 | handoff.md L51 | U3 的已知输入 | work/questions.md / 未决输入 |
| H-007 | handoff.md L59 | U4 的已知输入 | work/questions.md / 未决输入 |
| H-008 | handoff.md L68 | 不能倒退的输入 | specs/foundation.md / 产品取舍 |
| H-009 | handoff.md L80 | 文档面待办 | work/questions.md / 风险与验证债 |
| H-010 | handoff.md L93 | 任务游标 | work/status.md / 产品状态 |
| H-011 | handoff.md L98 | 开发框架自身（R0–R5 路线）的进度 | records/guide-history.md / 旧路线及当时进度 |
| H-012 | handoff.md L118 | 已完成的轮次 | records/guide-history.md / 旧路线及当时进度 |
| H-013 | handoff.md L127 | 不能倒退的两条（本轮新增） | work/questions.md / 风险与验证债 |
| M-001 | README.md L1 | dev-plan — 代码要符合什么、接下来建什么 | records/migration-context.md / 旧入口上下文 |
| M-002 | README.md L25 | 各文档的分工，别混写 | records/migration-context.md / 旧入口上下文 |

## 文档包：内部结构、归属理由与已安置全文

每个胶囊的文本按原路径/冻结版本解释。show 命令输出解码后的 Markdown；不是只有摘要的落点。

### working/request-lifecycle.md（N）

完整的产品合约闭环；对象、状态、要求与验收共享版本，保留原章节及所有行号。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 合约全文 | 只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。 | K-001, K-002, K-003, K-004, K-005, K-006, K-007, K-008, K-009, K-010, K-011, K-012, K-013, K-014, K-015, K-016, K-017, K-018, K-019, K-020, K-021, K-022, K-023, K-024, K-025, K-026, K-027, K-028, K-029, K-030, K-031, K-032, K-033, K-034, K-035, K-036, K-037, K-038, K-039, K-040, K-041, K-042 |

#### 合约全文

**K-001** · 源 working/request-lifecycle.md，L1–L12；SHA-256 e84e95c3e15e6a0008a8b3f207579f0f49f8e3349c3238eed22f4da6acec9485

<pre data-unit="K-001"># Request Lifecycle：产品请求生命周期合同

&gt; 最后更新：2026-08-31
&gt;
&gt; **本文是产品目标合同，不是当前能力清单，也不是开发协作流程。**它定义 investment-app 中“前端用户提交 Task，后端受理并
&gt; 调度 Agent，Agent 完成后，结果可靠返回前端用户”的完整生命周期。后续开发，尤其产品
&gt; Agent/runtime 能力开发，必须实现本文规定的功能并遵守本文规定的纪律。
&gt;
&gt; 当前实现事实以代码、迁移、测试、运行结果及
&gt; &#91;&#96;../project-guide/repos/investment-app.md&#96;](../../project-guide/repos/investment-app.md) 为准；发现实现与本文
&gt; 不符时，应建立开发工作单元修代码，或按程序修订本文，不得把目标要求静默降级成当前实现。

</pre>

**K-002** · 源 working/request-lifecycle.md，L13–L14；SHA-256 5cfe419678951f3901640af7eaa1582ed8a0f4c514a49b3b529ada8be10d7de6

<pre data-unit="K-002">## 0. 规范边界与条款筛选

</pre>

**K-003** · 源 working/request-lifecycle.md，L15–L28；SHA-256 211072c0ddfc924c17d9948d62738dd9b1b2e3f92b99129e47b38bbb05a3f16f

<pre data-unit="K-003">### 0.1 只收产品要求

本文只约束产品中的 Submission → Task → Attempt → Delivery，以及实现该链路的六方：前端、后端、
Agent runtime、Profile/验收器、运维、测试与维护者。开发 Agent 与人的工作流程分别由
&#91;&#96;development-lifecycle-agent.md&#96;](../archive/development-lifecycle-agent.md) 和
&#96;development-lifecycle-human.md&#96; 规定。

一条要求能否进入产品正文，用下面的问题裁决：

&gt; **它是否必须落实为前端协议、后端持久化、Agent 执行纪律、运维控制或自动验收？**

答案为“否”的内容不得冒充产品要求。仓库、commit、L1–L7 测试层次、Markdown 栏目、worktree
选优等开发字段，只能进入开发 Profile 或 &#91;&#96;development-lifecycle-agent.md&#96;](../archive/development-lifecycle-agent.md)。

</pre>

**K-004** · 源 working/request-lifecycle.md，L29–L51；SHA-256 958c766beb0890138ae1612e0e1940414ad5f7b472b0a2f3d9915e66561db657

<pre data-unit="K-004">### 0.2 本文负责什么

本文负责：

- Task 的身份、契约、状态和终态语义；
- Task 与 Attempt/Run、Interaction、Artifact、Event、Side Effect、Delivery 的关系；
- 从提交、受理、调度、执行、中断到结果交付的产品闭环；
- 幂等、授权、预算、副作用、证据、恢复、取消、重试和审计纪律；
- Profile、子 Task 和依赖编排的扩展规则；
- 前端、后端、Agent 的实现责任与验收矩阵。

本文不负责：

- 当前代码已经实现到哪里；
- 具体模型、prompt、SDK、图节点或队列产品选型；
- Git、远端、子模块和跨机操作；
- 开发助手或人怎样提出、实施、评审、批准和交付一项开发工作；
- 某个业务 Profile 的完整业务算法。

这些分别属于 project-guide、具体开发工作单元、
&#91;&#96;development-lifecycle-agent.md&#96;](../archive/development-lifecycle-agent.md)、
&#96;development-lifecycle-human.md&#96; 和相应 Profile 规范。

</pre>

**K-005** · 源 working/request-lifecycle.md，L52–L57；SHA-256 1af8de7a5036db3453fa433cd82dd811336de189a640438bd05fa8f5c493bf94

<pre data-unit="K-005">### 0.3 规范用语

- **必须**：缺失即不符合本文；
- **应该**：默认要求，偏离时必须记录理由、风险和等价控制；
- **可以**：合法选项，不构成统一实现要求。

</pre>

**K-006** · 源 working/request-lifecycle.md，L58–L91；SHA-256 e5a930a2a455430976e0620e2518d5774a027c797b0e7b8d32a15e22b63e5c76

<pre data-unit="K-006">## 1. 生命周期全景

&#96;&#96;&#96;text
前端用户
   │ ① 提交 Task
   ▼
前端 ──→ ② 后端受理 / 校验 / 授权 / 幂等
                  │
                  ▼
          ③ 持久化 Task / 排队 / 可靠投递
                  │
                  ▼
          ④ Agent Attempt ──→ 工具 / 数据 / 子 Task / 外部动作
                  │                         │
                  ├── ⑤ 澄清 / 批准 ──────┤
                  │       ▲ 前端用户响应    │
                  │       └─────────────────┘
                  ▼
          ⑥ 验收 / 结果与证据持久化 / Task 终态
                  │
                  ▼
          ⑦ 事件回放 / 结果获取 / 通知
                  │
                  ▼
               前端用户
&#96;&#96;&#96;

生命周期的终点不是“模型返回了文字”，也不是“一条 SSE 消息发送成功”，而是：

1. 最终结果、验收、证据和副作用状态已经可靠持久化；
2. Task 已以唯一合法终态提交；
3. 有权用户可以在断线、刷新或换设备后重新取得结果；
4. 通知失败可以独立重试，不改变 Task 结果。

</pre>

**K-007** · 源 working/request-lifecycle.md，L92–L105；SHA-256 f6b8bb799c601ff50ed905cac5289a6d8959768314d95f86c9f698db0fbbd21b

<pre data-unit="K-007">## 2. 核心对象

&#124; 对象 &#124; 定义 &#124; 必须保持的边界 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **Task** &#124; 用户提交并等待业务结果的持久请求；本文中的 request &#124; 跨连接、进程和多次 Attempt 存在 &#124;
&#124; **Attempt / Run** &#124; Agent 为完成一个 Task 发起的一次执行 &#124; 一个 Task 可以有零到多次 Attempt &#124;
&#124; **Interaction** &#124; Agent 向用户/审批者请求输入，以及对方的响应 &#124; 绑定 Task、一次性恢复、不可串请求 &#124;
&#124; **Artifact** &#124; 输入、Plan、中间结果、查询、报告、最终结果等稳定产物 &#124; 有类型、版本、所有者和来源 &#124;
&#124; **Event** &#124; Task/Attempt 已发生事实的追加记录 &#124; 只追加；状态与进度由它投影 &#124;
&#124; **Side Effect** &#124; 对数据库、外部系统、消息、交易或文件的写动作 &#124; 幂等、可审计、必要时可补偿 &#124;
&#124; **Delivery** &#124; 向前端呈现状态、事件和持久化结果 &#124; 可重放；失败不污染 Task 终态 &#124;
&#124; **Task Profile** &#124; 某类用户 Task 的输入、输出、验收、证据和策略契约 &#124; 可版本化；不另造状态机 &#124;
&#124; **Agent Profile** &#124; 执行某类 Task 的能力、工具、权限和 memory 策略 &#124; Attempt 固定所用版本；不是 Task 契约本身 &#124;

</pre>

**K-008** · 源 working/request-lifecycle.md，L106–L119；SHA-256 68de355f80a0ee318a752de42963b3a0bc9afdbbdc8077837195633d4b608ebb

<pre data-unit="K-008">### 2.1 Task 不等于 Attempt

&#96;&#96;&#96;text
Task T1
├── Attempt A1 → FAILED(retryable)
├── Attempt A2 → BUDGET_EXCEEDED
└── Attempt A3 → COMPLETED → acceptance passed → Task SUCCEEDED
&#96;&#96;&#96;

一次投递失败、worker 崩溃、模型超时或验收不通过，只结束对应 Attempt。只有不存在获准的成功路径、
重试策略耗尽，或完成契约已不可能满足时，Task 才进入 &#96;FAILED&#96;。

不得为迁就当前 run 表而合并两者。当前 run 状态机可以作为 Attempt 实现输入，但不能独自定义目标 Task。

</pre>

**K-009** · 源 working/request-lifecycle.md，L120–L126；SHA-256 040aaf38d70c36e15992845d5b0b18a52c14f5245c537afce91fe5aaebd965d1

<pre data-unit="K-009">### 2.2 Submission 不一定产生 Task

未认证、无法解析或在 Task 身份分配前即被协议层拒绝的提交，只产生安全的协议错误，不进入 Task
生命周期。后端一旦分配 &#96;task_id&#96; 并提交首个事件，后续业务/政策拒绝必须形成可审计的 &#96;REJECTED&#96; Task。

这样既避免把攻击流量和无效载荷强制持久化，也保证已经受理的用户请求不会无痕消失。

</pre>

**K-010** · 源 working/request-lifecycle.md，L127–L128；SHA-256 1a565d2cc3e920158817173d07771fa43d7724c583271465ed1771c114f6bd45

<pre data-unit="K-010">## 3. Task 契约

</pre>

**K-011** · 源 working/request-lifecycle.md，L129–L146；SHA-256 5cf8054fd131bf1557cbbe45a539773ea9eae1cfe1448717bead75bb3460a6ab

<pre data-unit="K-011">### 3.1 提交信封

前端提交至少包含：

&#96;&#96;&#96;text
idempotency_key       调用者作用域内稳定
profile_id            Task Profile 标识
profile_version       可请求；最终版本由后端固定
original_input        用户原始文本与结构化输入
attachments&#91;]         稳定引用、媒体类型、大小、校验值
client_context        locale、timezone、展示能力等非授权上下文
requested_deadline    可选
&#96;&#96;&#96;

后端必须从认证上下文确定 &#96;requester&#96;、&#96;tenant&#96;、角色和数据作用域，不能信任前端自报身份。
幂等唯一性至少包含 &#96;tenant + requester + profile + idempotency_key&#96;。同一键重复且请求摘要相同时返回
原 &#96;task_id&#96;；同一键携带不同摘要时必须返回幂等冲突，不能静默复用或另建 Task。

</pre>

**K-012** · 源 working/request-lifecycle.md，L147–L165；SHA-256 28d65894c67ce592d5baa1cbef11a9b3109242e55276427df331f039393fb0e1

<pre data-unit="K-012">### 3.2 持久化主档

Task 至少持久化：

&#96;&#96;&#96;text
task_id, requester, tenant, idempotency_key, request_digest
task_profile_id, task_profile_version
original_input_ref, normalized_goal
state, state_version, created_at, updated_at
acceptance_contract, execution_policy
active_attempt_ids, terminal_result_ref
parent_task_id, coordination_task_id
retry_of, refresh_of, supersedes
waiting_reason, active_interaction_id
cancel_requested_at, cancel_requested_by
&#96;&#96;&#96;

&#96;state&#96; 是事件流的受约束投影；&#96;state_version&#96; 用于比较交换，防止两个入口同时完成、取消或恢复 Task。

</pre>

**K-013** · 源 working/request-lifecycle.md，L166–L182；SHA-256 e58e503a626c389a71c638addcb011e59c973f734b77618e1c550076091de786

<pre data-unit="K-013">### 3.3 解释、边界与完成契约

Task 进入 &#96;QUEUED&#96; 前必须固定：

- 归一化目标：用户真正要什么结果；
- 包含什么、不包含什么、不包含部分由谁处理；
- 输出 schema、允许的空值和前端 renderer 契约；
- 可判定的 acceptance 条目；
- 新鲜度、质量、证据和引用要求；
- 预算、deadline、重试、停止和取消策略；
- 允许的能力、数据源和外部副作用；
- 必须由用户或授权角色批准的动作；
- 不确定性、降级和部分结果是否允许。

简单 Task 可以从固定 Profile 自动生成契约。只有歧义会实质改变结果、权限、成本或风险时才请求澄清，
不得为填满形式化栏目而反复追问用户。

</pre>

**K-014** · 源 working/request-lifecycle.md，L183–L202；SHA-256 d99e32c277a9a4a7a1fcb4b44003f96b00caf194079ba0ce4b21ec180fcbe11b

<pre data-unit="K-014">### 3.4 最终结果信封

成功结果至少包含：

&#96;&#96;&#96;text
task_id, task_profile_id, task_profile_version
result_id, result_version, result_type
structured_result, human_summary
evidence&#91;] / citations&#91;]
limitations&#91;] / uncertainty
data_as_of
artifacts&#91;]
side_effect_summary&#91;]
accepted_attempt_id
completed_at
&#96;&#96;&#96;

失败、拒绝或取消结果至少包含稳定错误码、用户可理解说明、是否允许重新提交、已发生副作用及其状态，
以及仅供内部诊断的受限引用。前端文案不能泄露内部异常、路径、凭据或其他租户信息。

</pre>

**K-015** · 源 working/request-lifecycle.md，L203–L204；SHA-256 f27a898b5d4f1d89c7f6c176050863d939c622b63f850e5e476b02a177598213

<pre data-unit="K-015">## 4. 两层状态机

</pre>

**K-016** · 源 working/request-lifecycle.md，L205–L246；SHA-256 68ddaa272beefc3c2096e2ea006d0ab584daceb15abe57f8cc9b7975e0d63b4f

<pre data-unit="K-016">### 4.1 Task 状态机

&#96;&#96;&#96;text
RECEIVED → VALIDATING → QUEUED → RUNNING ──────────────→ SUCCEEDED ●
               │          ▲        │
               │          │        ├→ QUEUED       可重试 Attempt 结束
               │          │        ├→ WAITING
               │          │        ├→ FAILED ●
               │          │        └→ CANCELLED ●
               │          │
               ├→ WAITING ┘
               └→ REJECTED ●

非终态收到取消意图后，经安全收敛进入 CANCELLED ●
● = Task 终态，不可转出
&#96;&#96;&#96;

合法转换只有：

- &#96;RECEIVED → VALIDATING &#124; CANCELLED&#96;
- &#96;VALIDATING → QUEUED &#124; WAITING &#124; REJECTED &#124; CANCELLED&#96;
- &#96;QUEUED → RUNNING &#124; WAITING &#124; FAILED &#124; CANCELLED&#96;
- &#96;RUNNING → QUEUED &#124; WAITING &#124; SUCCEEDED &#124; FAILED &#124; CANCELLED&#96;
- &#96;WAITING → VALIDATING &#124; QUEUED &#124; FAILED &#124; CANCELLED&#96;

任何入口——API、worker、调度器、超时扫描器和人工运维——都必须调用同一转换规则。

&#124; 状态 &#124; 产品语义 &#124; 进入门禁 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;RECEIVED&#96; &#124; 后端已可靠建单 &#124; 身份、原始输入、幂等记录和首事件已提交 &#124;
&#124; &#96;VALIDATING&#96; &#124; 正在解释目标并检查契约、权限和政策 &#124; Profile 候选与授权上下文存在 &#124;
&#124; &#96;QUEUED&#96; &#124; 已可执行，等待资源或可靠投递 &#124; 完成契约、执行策略、预算已持久化 &#124;
&#124; &#96;RUNNING&#96; &#124; 至少一个有效 Attempt 正在推进 &#124; Attempt 持有效租约，输入版本固定 &#124;
&#124; &#96;WAITING&#96; &#124; 当前没有 Attempt 能推进，等待已知条件 &#124; reason、问题/条件、恢复方式、超时策略 &#124;
&#124; &#96;SUCCEEDED&#96; &#124; 用户结果完成并可重新获取 &#124; 结果先持久化；acceptance 逐条通过；证据合规 &#124;
&#124; &#96;REJECTED&#96; &#124; 已建单但不予执行 &#124; 安全的政策、范围、能力或业务理由已记录 &#124;
&#124; &#96;FAILED&#96; &#124; 已无获准的成功路径 &#124; 失败码、重试判定、Attempt 和副作用记录完整 &#124;
&#124; &#96;CANCELLED&#96; &#124; 有权主体已终止 Task &#124; 取消意图、fencing、Attempt 处置和副作用状态完整 &#124;

&#96;VALIDATING&#96; 与 &#96;QUEUED&#96; 是否直接展示给用户由前端投影决定，但持久化语义不得合并到无法判断
“尚未形成契约”和“已经可执行但未获资源”的程度。

</pre>

**K-017** · 源 working/request-lifecycle.md，L247–L278；SHA-256 f0db7217254c0abd6ef8fc3f4b43dc2e8df48014e230fc3b31a07068c848446c

<pre data-unit="K-017">### 4.2 WAITING 与 Interaction

等待原因使用结构化码，不为每种等待另造状态：

- &#96;INPUT&#96;：等待用户补充关键输入；
- &#96;APPROVAL&#96;：等待授权角色批准高风险动作；
- &#96;DEPENDENCY&#96;：等待另一 Task 或依赖条件；
- &#96;RESOURCE&#96;：等待配额、容量、锁或计划时间；
- &#96;EXTERNAL&#96;：等待外部系统或现实事件。

Interaction 必须绑定：

&#96;&#96;&#96;text
task_id, interaction_id, expected_state_version
question_or_action, audience, expires_at
resume_token_hash, idempotency_key, consumed_at
resume_target
&#96;&#96;&#96;

恢复令牌必须在同一并发控制边界内完成：校验主体与 Task、校验当前等待动作、检查过期与 stale action、
按幂等键判断重复、原子标记消费、安排后续投递。重复、过期、异键、跨用户或跨 Task 的恢复必须拒绝。

验证阶段等待输入后回 &#96;VALIDATING&#96;；执行阶段等待后先回 &#96;QUEUED&#96;，只有 Attempt 获得有效租约才重新进入
&#96;RUNNING&#96;。Attempt 若从 checkpoint 原地恢复，可在自己的状态机内 &#96;WAITING → RUNNING&#96;。

Interaction 到期不得无事件消失。Task Profile 必须规定超时后关闭该 Interaction，并使 Task 进入
&#96;FAILED&#96;、重新 &#96;QUEUED&#96;、回 &#96;VALIDATING&#96; 或按已批准政策 &#96;CANCELLED&#96;；任何自动选择都必须追加事件并
保留超时原因。

只有没有任何 Attempt 能继续推进时，Task 才进入 &#96;WAITING&#96;；并行 Attempt 仍有一路可推进时，Task 保持
&#96;RUNNING&#96;，等待记录在对应 Attempt。

</pre>

**K-018** · 源 working/request-lifecycle.md，L279–L291；SHA-256 432df1f5f733fbed31794061894e9fcdf0b90dfc041c80b74804a930ad120862

<pre data-unit="K-018">### 4.3 取消意图与终态

用户点击取消时，后端必须先持久化取消意图，而不是无条件直接写 &#96;CANCELLED&#96;：

1. 校验主体、Task 版本和当前状态；
2. 写入取消意图并阻止新 Attempt；
3. 撤销租约或提高 fencing，拒绝旧 worker 的迟到写入；
4. 停止执行，检查已发生副作用，执行约定的补偿或登记不可补偿结果；
5. 以比较交换提交唯一 &#96;CANCELLED&#96; 终态。

完成与取消并发时，只能有一个终态提交成功。前端可将已记录取消意图投影为“正在取消”，但这不是
第二套 Task 状态。

</pre>

**K-019** · 源 working/request-lifecycle.md，L292–L303；SHA-256 d8bdcd4d224aac927a6237d32bae6ce2962d58153cb9bc9a433d23031343a417

<pre data-unit="K-019">### 4.4 终态、刷新与重新处理

&#96;SUCCEEDED / REJECTED / FAILED / CANCELLED&#96; 终态不可转出。以下情况建立新 Task：

- 刷新到新的数据时点；
- 修改目标、口径、授权范围或 Profile 版本；
- 重新处理失败、取消或拒绝的 Task；
- 推翻旧决定或要求另一个方案。

新 Task 用 &#96;retry_of&#96;、&#96;refresh_of&#96; 或 &#96;supersedes&#96; 连接旧 Task；旧结果继续保持当时输入、数据时点、
策略和 Profile 版本下的语义。

</pre>

**K-020** · 源 working/request-lifecycle.md，L304–L345；SHA-256 808297a3b02fda24da5af6cc6c790b3ed1faf33d05472b1e6a6c783da802fea1

<pre data-unit="K-020">### 4.5 Attempt / Run 状态机

**Task 层与 Attempt 层是目标实现中必须拆开的两层。**当前 &#96;run&#96; 表和状态词只能作为迁移输入，不能
继续同时承担用户 Task 与单次执行两个角色。跨层引用必须使用 &#96;task.state&#96; 与 &#96;attempt.status&#96;；事件
schema 分字段携带两者，日志和前端投影不得只写一个无层限定的 &#96;status&#96;。

Attempt 可以尽量沿用当前运行时词汇：

&#96;&#96;&#96;text
CREATED → RUNNING ⇄ WAITING
   │         │
   │         ├→ COMPLETED ●
   ├─────────┼→ FAILED ●
   └─────────┼→ CANCELLED ●
             └→ BUDGET_EXCEEDED ●
&#96;&#96;&#96;

Attempt 至少记录：

&#96;&#96;&#96;text
attempt_id, task_id, executor_id, runtime_version
task_profile_version, agent_profile_id, agent_profile_version
input_artifact_versions
lease_owner, lease_expires_at, fencing_token
status, started_at, ended_at
budget_allocated, budget_consumed
failure_code, retryable
checkpoint_ref, output_artifacts
tool_calls, side_effect_refs, evidence_refs
&#96;&#96;&#96;

必须满足：

1. worker 只有持有效租约和 fencing token 才能写入；过期 worker 的迟到结果被拒绝；
2. Attempt 终态不可重开；重试创建新 Attempt；
3. 同一 Task 是否允许并行 Attempt 由执行策略明确；
4. 首个通过验收的结果胜出后，其余 Attempt 停止或降为无副作用只读探索；
5. &#96;COMPLETED&#96; 只表示 Attempt 产出了候选结果，不自动使 Task &#96;SUCCEEDED&#96;；
6. checkpoint 恢复不得重复已经记账的外部副作用；
7. &#96;BUDGET_EXCEEDED&#96; 是 Attempt 终态。Task 随后按契约进入 &#96;WAITING(APPROVAL)&#96;、重新 &#96;QUEUED&#96; 或
   &#96;FAILED&#96;，不把当前实现的 run 终态无条件提升成用户 Task 终态。

</pre>

**K-021** · 源 working/request-lifecycle.md，L346–L350；SHA-256 6658f2ea1355a2f23da8ddc6dbe5315c88af64c5c37ed404617e9e55133bcb05

<pre data-unit="K-021">## 5. 七阶段产品功能

本节为可独立实现和验收的功能义务分配稳定 ID。ID 一经发布不得复用或因章节移动而重排；废止要求
保留 ID 并记录替代项。&#167;9 只投影这些 ID 的所有者，不再复制第二套要求。

</pre>

**K-022** · 源 working/request-lifecycle.md，L351–L359；SHA-256 a75d9646a3af809389cc715f170ab52b7a46e07e924382494843c7d9ffe04310

<pre data-unit="K-022">### 5.1 提交（前端）

前端必须：

- **F-INTAKE-01**：生成并在重试时复用幂等键；
- **F-INTAKE-02**：校验可在客户端安全校验的输入，但不冒充后端授权；
- **F-INTAKE-03**：保存 &#96;task_id&#96; 和最后确认的 event cursor；
- **F-INTAKE-04**：对网络失败使用稳定、可判定的错误类型，只投影后端事实，不创造后端不存在的状态。

</pre>

**K-023** · 源 working/request-lifecycle.md，L360–L368；SHA-256 df392b9e69a88a2f9a77f914965bd314d8fbc7a51a43e252cc7c0429b162a670

<pre data-unit="K-023">### 5.2 受理与校验（后端）

- **F-ADMIT-01**：后端必须在可靠边界内完成认证身份绑定、幂等占位、Task 建单和首事件写入；
- **F-ADMIT-02**：附件必须检查大小、媒体类型、恶意内容和授权；
- **F-ADMIT-03**：输入不合规不得“尽量执行”；Task 建单后的拒绝进入 &#96;REJECTED&#96;，协议层拒绝按
  &#167;2.2 处理；
- **F-ADMIT-04**：浏览器入口与受信服务入口必须共享同一个 application use case，只在接口层解析
  身份。浏览器身份来自登录会话，服务入口使用服务身份和受信委托上下文，不得复制 Task 状态或业务逻辑。

</pre>

**K-024** · 源 working/request-lifecycle.md，L369–L376；SHA-256 66603ad94db307e83aca7dd419564da869113934d365c3a637968d7419e5ffe0

<pre data-unit="K-024">### 5.3 排队与可靠投递

- **F-DISPATCH-01**：Task 进入 &#96;QUEUED&#96; 与 worker 收到消息之间不得有不可恢复丢失窗口；实现必须
  使用事务 outbox、可证明等价的队列事务或未投递 Task 扫描；
- **F-DISPATCH-02**：重复消息按 &#96;task_id + attempt_id&#96; 幂等处理；
- **F-DISPATCH-03**：调度策略必须明确租户公平性、优先级、并发上限、资源配额和 deadline，防止一个
  长 Task 饿死其他用户。

</pre>

**K-025** · 源 working/request-lifecycle.md，L377–L390；SHA-256 d9cd4a2113f1d16cff949e6468b336d43e02692d2418b9042920e021d775aeb5

<pre data-unit="K-025">### 5.4 Agent 执行

Agent 必须：

- **F-EXEC-01**：只使用执行策略和 Agent Profile 允许的能力、数据源与工具；
- **F-EXEC-02**：将工具输入输出、模型/工具版本和证据关联到 Attempt；
- **F-EXEC-03**：每次高风险动作前重新校验授权和批准；
- **F-EXEC-04**：持续扣减 Task 总预算，在越限前停止；
- **F-EXEC-05**：将可恢复进度写 checkpoint，不依赖进程内记忆；
- **F-EXEC-06**：区分事实、推断、假设、缺失和不确定性；
- **F-EXEC-07**：无法满足完成契约时请求输入或明确失败，不伪造完整结果；
- **F-EXEC-08**：Plan 只能作为可选 Artifact。复杂 Task 可以要求 Plan 先经批准；简单问数不得为了
  经过 &#96;PLANNED&#96; 状态而制造空计划。

</pre>

**K-026** · 源 working/request-lifecycle.md，L391–L397；SHA-256 576c123269044622ed1529a8d7f6270461de4f6091cce9a463c37947f76d5526

<pre data-unit="K-026">### 5.5 中断、批准与恢复

- **F-INTERACT-01**：后端必须把等待问题具体化为可直接回答的输入或可明确批准的动作，向正确受众
  投影 Interaction，并按 &#167;4.2 原子恢复；
- **F-INTERACT-02**：消费恢复令牌后若后续投递失败，系统必须留下可恢复记录或进入合法失败路径，
  不得悬空。

</pre>

**K-027** · 源 working/request-lifecycle.md，L398–L412；SHA-256 1b26545b3839a16d0c9022c1076e4dd5fee7a7168b92e753835521e66396cd80

<pre data-unit="K-027">### 5.6 验收与完成提交

- **F-ACCEPT-01**：Agent 输出不等于 Task 完成；验收器必须按固定 Task Profile 版本检查：

  - 输出 schema 与未声明字段；
  - 每条 acceptance；
  - 证据、来源、新鲜度和权限；
  - 副作用及批准条件；
  - 部分结果和不确定性是否符合契约。

- **F-ACCEPT-02**：验收失败可以在预算和策略允许时产生新 Attempt；禁止静默删改验收标准以换取通过；

- **F-ACCEPT-03**：提交 &#96;SUCCEEDED&#96; 时，最终结果、引用、Artifact 关系、验收判定、预算结算和终态
  事件必须原子提交，或采用可证明不会向前端暴露半成品的等价协议。

</pre>

**K-028** · 源 working/request-lifecycle.md，L413–L441；SHA-256 7992ed7e8881770b5e3df18484ceaa605c8b5f957d66a0207adf3019353cae47

<pre data-unit="K-028">### 5.7 返回前端、失败与重试

结果交付采用“**持久化后通知**”：

- **F-DELIVERY-01**：前端可按 &#96;task_id&#96; 获取当前状态和稳定版本的最终结果；
- **F-DELIVERY-02**：每个事件有稳定 &#96;event_id&#96;、Task 内单调 &#96;sequence_no&#96;、
  &#96;payload_schema_version&#96;、时间、主体和可见级别；
- **F-DELIVERY-03**：服务端先持久化事件再推送；
- **F-DELIVERY-04**：流式连接使用 cursor 续传，重复事件对客户端幂等；
- **F-DELIVERY-05**：客户端采用“先建立订阅，再读取快照/历史并按 sequence 去重”或可证明无丢失
  窗口的等价握手；
- **F-DELIVERY-06**：SSE/WebSocket 只是低延迟通知，不是结果唯一载体；流式 token 和未验收草稿只
  属于 Delivery 或中间 Artifact，不能单独构成 &#96;SUCCEEDED&#96;；
- **F-DELIVERY-07**：终态和失败原因可以机械判定，不靠自然语言暗示；
- **F-DELIVERY-08**：用户可见失败包含可行动分类，不能只显示“出错了”；
- **F-DELIVERY-09**：每次读取状态、事件和结果都重新校验用户、租户和授权；
- **F-DELIVERY-10**：通知失败进入 Delivery 记录或重试，不修改 Task 终态。

失败至少分类为：

&#124; 类别 &#124; 例子 &#124; 默认处置 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;ADMISSION&#96; &#124; 已建单后发现业务/政策不可受理 &#124; &#96;REJECTED&#96;，安全说明 &#124;
&#124; &#96;DISPATCH&#96; &#124; 投递失败、无执行器 &#124; 可重试；策略耗尽后 &#96;FAILED&#96; &#124;
&#124; &#96;EXECUTION&#96; &#124; worker、模型、工具或外部系统失败 &#124; 先查副作用，再决定重试 &#124;
&#124; &#96;VALIDATION&#96; &#124; 输出 schema、验收或证据不通过 &#124; 修实现/新 Attempt；不得原样盲重试 &#124;
&#124; &#96;BUDGET&#96; &#124; Attempt 预算耗尽 &#124; 按契约追加批准、换策略或失败 &#124;
&#124; &#96;CANCEL&#96; &#124; 用户或系统取消 &#124; 安全收敛后 &#96;CANCELLED&#96; &#124;

</pre>

**K-029** · 源 working/request-lifecycle.md，L442–L443；SHA-256 60fe9f1ac3243ca03b5401a6e5039bd5945982e455b0ca126a44e6fa5c7a24d1

<pre data-unit="K-029">## 6. 跨进程纪律与持久化账

</pre>

**K-030** · 源 working/request-lifecycle.md，L444–L466；SHA-256 692226447cb805ee82829f6a302186067620042cd98b25210674fa2db9dd1a33

<pre data-unit="K-030">### 6.1 全程不变量

&#124; ID &#124; 必须成立 &#124; 防止的失败 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; I1 &#124; 原始输入、调用者、租户、受理时间和 Profile 版本可追溯，不被后续解释覆盖 &#124; 意图漂白 &#124;
&#124; I2 &#124; 相同幂等作用域、键和摘要只对应一个 Task；异摘要冲突 &#124; 重复建单或误复用 &#124;
&#124; I3 &#124; 每次读取、工具调用和写入重新校验当前授权 &#124; 撤权后继续访问、跨租户泄漏 &#124;
&#124; I4 &#124; 状态转换集中校验，事件只追加；状态与进度是事件投影 &#124; 状态多头、覆写历史 &#124;
&#124; I5 &#124; Task 与 Attempt 终态不可转出；重新处理建立新实体 &#124; 终态失真 &#124;
&#124; I6 &#124; Task 成功前结果和验收证据已持久化且可重新获取 &#124; 完成即丢失 &#124;
&#124; I7 &#124; 通知与连接失败不改变 Task 业务终态 &#124; 把交付故障误判成业务失败 &#124;
&#124; I8 &#124; Attempt 失败不自动等于 Task 失败 &#124; 过早终结用户任务 &#124;
&#124; I9 &#124; 每个外部副作用有稳定幂等键、状态、回执和补偿信息 &#124; 恢复或重试时重复动作 &#124;
&#124; I10 &#124; 预算覆盖 Task 的全部 Attempt、子 Task 和工具调用 &#124; fan-out 放大无限额 &#124;
&#124; I11 &#124; 结论和数值按 Profile 关联来源、时点、转换与执行者 &#124; 证据幻觉、口径漂移 &#124;
&#124; I12 &#124; 敏感信息、凭据和越权原文不进入普通事件、日志和前端投影 &#124; 泄密 &#124;
&#124; I13 &#124; 一个可变事实只有一个权威写入面，其他视图均可重建 &#124; 副本漂移 &#124;
&#124; I14 &#124; worker 失去租约或 fencing 后不能提交结果或副作用 &#124; 迟到写入覆盖新结果 &#124;
&#124; I15 &#124; 每项可独立实现的义务有稳定 ID、所有者、代码位置和自动测试；未实现项显式登记 &#124; 规范成为口号 &#124;

这些纪律必须由事务、唯一约束、状态版本、租约、fencing、持久化账和常规自动测试保证，不能只依赖
prompt、执行者自律或“记得运行”的临时脚本。

</pre>

**K-031** · 源 working/request-lifecycle.md，L467–L484；SHA-256 0e4ffe87700ecc51d4a2edde73176bfd2b84644b6dd013917d898ac931fa1b83

<pre data-unit="K-031">### 6.2 持久化记录

传统“四本账”必须保留，并与 Task/Event、Attempt、Interaction、Delivery 主记录组合：

&#124; 记录 &#124; 最低内容 &#124;
&#124; --- &#124; --- &#124;
&#124; Task / Event &#124; 身份、契约、状态事件、因果/关联 ID、主体、时间、schema 版本 &#124;
&#124; Attempt &#124; 执行者、Profile/运行时版本、租约、输入输出、失败码、消耗 &#124;
&#124; 幂等账 &#124; 作用域、键、请求摘要、Task、首次/重复响应 &#124;
&#124; 预算账 &#124; Task 总额、预留、已用、释放、追加批准和拒绝原因 &#124;
&#124; 副作用账 &#124; 动作幂等键、目标、意图、执行状态、回执、补偿状态 &#124;
&#124; 证据账 &#124; 主张、来源、时点、转换、生成者、Attempt 和验收者 &#124;
&#124; Interaction &#124; 等待问题/动作、受众、令牌、状态版本、消费结果 &#124;
&#124; Delivery &#124; 目标用户/通道、cursor、尝试、确认或失败；不保存第二份结果正文 &#124;

所有要求“进程被杀后仍正确”的事实必须由持久化与并发控制承担。可以采用不同表或事件投影实现，
但不能把这些事实仅保存在 worker 内存或外部执行 harness 中。

</pre>

**K-032** · 源 working/request-lifecycle.md，L485–L486；SHA-256 802122c57f45437e8ec585ed0377e810dc6cf45e54314dffc77e83fcc28a102f

<pre data-unit="K-032">## 7. Profile、Artifact 与扩展

</pre>

**K-033** · 源 working/request-lifecycle.md，L487–L507；SHA-256 5f5ba765e84074b57d255760a180633bf7f7a32e5e178f9ac7fd131461176b81

<pre data-unit="K-033">### 7.1 Task Profile 与 Agent Profile

Task Profile 是版本化产品契约：

&#96;&#96;&#96;text
profile_id + version
input_schema / output_schema / frontend_renderer_contract
normalization_rules
required_context / artifacts
acceptance / evidence / freshness rules
allowed_capabilities / data sources
default budget / retry / approval / privacy policy
&#96;&#96;&#96;

Agent Profile 声明执行能力：模型、prompt、工具绑定、权限边界、memory policy 和支持的 Task Profile。
Task 固定 Task Profile 版本；每次 Attempt 记录所选 Agent Profile 与运行时版本。升级任一 Profile 不得
静默改变已受理 Task 的解释或历史结果。

新增领域应新增 Task Profile 和相容 Agent Profile，不修改通用状态语义。确需改变通用骨架时，必须先
通过一个有证据和迁移方案的规范修订工作单元；不能由领域 Profile 倒逼核心分叉。

</pre>

**K-034** · 源 working/request-lifecycle.md，L508–L519；SHA-256 a33d66afd49cccd4a1de0cbb8a90848a0cd8f264ce5316d3feee855b0f0aee8f

<pre data-unit="K-034">### 7.2 Profile 示例

&#124; Profile &#124; 至少固定 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;DATA_QUERY&#96; &#124; 对象范围、指标口径、单位/币种/复权、时间区间/频率/时区/截至时点、授权数据源、缺失规则、结果形态、查询/转换链和引用 &#124;
&#124; &#96;RESEARCH&#96; &#124; 研究问题、来源范围、时间边界、证据等级、反证、覆盖要求、不确定性和引用格式 &#124;
&#124; &#96;ACTION&#96; &#124; 目标系统、授权主体、预期副作用、动作幂等键、批准点、回执、补偿和不可逆声明 &#124;

这些是设计示例，不是已经冻结的业务契约；每个 Profile 的第一项开发工作单元 必须用真实输入、输出、前端
renderer 和验收用例确认字段，之后才发布其首个版本。Plan 是可选 Artifact，不是状态。复杂 Profile
可以要求 Plan 版本化并先经批准；简单问数可直接执行。

</pre>

**K-035** · 源 working/request-lifecycle.md，L520–L549；SHA-256 2deff7b7ad65de9a4b2c0ff16414a8edac15399e9ad25e6970235ffc4c47b752

<pre data-unit="K-035">## 8. 子 Task 与依赖编排

Agent 可以派生子 Task，但必须满足：

- 父 Task 的完成标准仍是用户业务目标，不能以“已经拆出子 Task”冒充完成；
- 父级预算覆盖全部子 Task，子级预算是预留而不是凭空新增；
- 子 Task 的授权只能收窄；扩大权限必须重新批准；
- 子 Task 各自有 Task Profile、Attempt、结果和验收；
- 父 Task 汇总结果时保留来源和子 Task 血缘。

多个 Task 的依赖图由一个有边界的 &#96;COORDINATION&#96; Task 管理：

&#96;&#96;&#96;text
managed_task_ids&#91;]
edges&#91;] = from → to + 依据 + 可判定满足条件
parallel_groups&#91;]
ownership&#91;]
graph_version
&#96;&#96;&#96;

协调 Task 是边的唯一权威；被协调 Task 只保存 &#96;coordination_task_id&#96;，不复制具体边。同时只能有一个
现行协调视图。协调 Task 验收：节点存在、每条边有依据与解除条件、阻塞图无环、工作有责任归属、
同一事实无第二写入面。

**协调 Task 不等待被协调 Task 全部完成。**图建立并验收后即 &#96;SUCCEEDED&#96;。依赖实质变化时建立
&#96;supersedes&#96; 旧图的新协调 Task，避免一个永不结束的“总管 Task”成为中央计划。

对子结果的等待发生在依赖这些节点的业务 Task：该 Task 进入 &#96;WAITING(DEPENDENCY)&#96;，等待条件满足后
按 &#167;4.2 恢复。协调 Task 只维护并验收依赖边，不替业务 Task 等结果。

</pre>

**K-036** · 源 working/request-lifecycle.md，L550–L565；SHA-256 1a2b24b6d0621edee2a82cca7e27f441709cd424ff74eb0749f1b8e93a43e17e

<pre data-unit="K-036">## 9. 前端、后端与 Agent 责任投影

本节是所有者索引，不产生第二套规范。实现矩阵以 &#167;5 的稳定功能 ID、&#167;6 的不变量 ID 和 &#167;11 的验收
ID 为键；此处只说明谁对它们负责。

&#124; 所有者 &#124; 负责的要求 &#124;
&#124; --- &#124; --- &#124;
&#124; 前端 &#124; &#96;F-INTAKE-*&#96;、&#96;F-INTERACT-*&#96; 的用户操作、&#96;F-DELIVERY-*&#96; 的订阅/回放/展示侧，以及相应 &#96;AT-*&#96; &#124;
&#124; 后端 &#124; &#96;F-ADMIT-*&#96;、&#96;F-DISPATCH-*&#96;、Interaction 原子消费、Task/Attempt 状态与结果提交、&#96;I1&#96;–&#96;I15&#96; 的存储和并发载体 &#124;
&#124; Agent / runtime &#124; &#96;F-EXEC-*&#96;、候选结果生成、checkpoint、工具/证据/副作用纪律，以及 &#96;F-ACCEPT-*&#96; 的 Agent 侧输入 &#124;
&#124; 验收器 / Profile &#124; &#96;F-ACCEPT-*&#96;、Profile schema 与版本、结果 renderer 契约 &#124;
&#124; 运维 &#124; 非终态 Task、过期租约、悬空投递和失败 Delivery 的扫描/告警，以及租户、Profile、失败码、Attempt 和预算可观测性 &#124;
&#124; 测试与维护者 &#124; &#96;AT-*&#96;、实现矩阵、无法自动验证条款的人工门禁及其理由 &#124;

当前覆盖状态只记录在实现矩阵或 project-guide，不写回本文形成易腐快照。

</pre>

**K-037** · 源 working/request-lifecycle.md，L566–L585；SHA-256 098396ef21c4153239f1f6eb31195cb4ee962e56a36d8d839f97f28630bb6d20

<pre data-unit="K-037">## 10. 反模式

&#124; 反模式 &#124; 失败方式 &#124;
&#124; --- &#124; --- &#124;
&#124; Task 与 Attempt 合并 &#124; 一次执行失败过早终结用户请求，或被迫重开终态 &#124;
&#124; 先推送后落库 &#124; 用户看见无法回放的幽灵事件 &#124;
&#124; SSE 是唯一结果载体 &#124; 断线或刷新后结果永久丢失 &#124;
&#124; 直接写 &#96;CANCELLED&#96; &#124; 与正在完成的 worker 竞争，副作用未收敛 &#124;
&#124; 无 fencing 的租约 &#124; 过期 worker 用迟到结果覆盖新执行 &#124;
&#124; 同幂等键异载荷静默复用 &#124; 用户得到另一请求的结果 &#124;
&#124; 盲目重试执行中失败 &#124; 已发生的外部动作被重复执行 &#124;
&#124; 每个子 Task 各自维护依赖边 &#124; 图变化时多头漂移 &#124;
&#124; 协调 Task 等所有子 Task 完成 &#124; 重新制造永不结束的中央计划 &#124;
&#124; 父 Task 以“已拆子 Task”宣布完成 &#124; 内部动作冒充用户结果 &#124;
&#124; Profile 修改通用状态机 &#124; 新领域产生第二套生命周期 &#124;
&#124; 开发字段进入产品骨架 &#124; 问数等 Task 被迫穿开发流程的外衣 &#124;
&#124; 当前实现快照写进目标规范 &#124; 规范随代码变化腐烂，目标与事实混淆 &#124;
&#124; 通知失败改写业务终态 &#124; Delivery 故障污染 Task 结果 &#124;
&#124; 规范只有文字没有测试映射 &#124; “必须”无法执行，最终退化为口号 &#124;

</pre>

**K-038** · 源 working/request-lifecycle.md，L586–L622；SHA-256 fd899413db5cbb36b02437390e664ed32c9068be790f9323b545b4681af7c82f

<pre data-unit="K-038">## 11. 产品验收矩阵

宣布本文某项能力已经实现前，至少提供以下自动化或可复现实验：

&#124; ID &#124; 场景 &#124; 必须证明 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;AT-01&#96; &#124; 幂等重复提交 &#124; 同作用域、同键、同摘要只创建一个 Task &#124;
&#124; &#96;AT-02&#96; &#124; 幂等异载荷 &#124; 同键异摘要明确冲突，不误复用、不另建 &#124;
&#124; &#96;AT-03&#96; &#124; 协议拒绝 &#124; 未认证/畸形提交不创建业务 Task，不泄露信息 &#124;
&#124; &#96;AT-04&#96; &#124; 受理拒绝 &#124; 已建单 Task 可进入 &#96;REJECTED&#96; 并返回安全理由 &#124;
&#124; &#96;AT-05&#96; &#124; 越权访问 &#124; 不能读取、订阅、恢复、批准或取消其他用户/租户 Task &#124;
&#124; &#96;AT-06&#96; &#124; 简单问数 &#124; 提交到结构化结果、口径、数据时点和引用完整闭环 &#124;
&#124; &#96;AT-07&#96; &#124; 澄清恢复 &#124; 令牌原子消费；重复、过期、异键、跨 Task 响应被拒绝 &#124;
&#124; &#96;AT-08&#96; &#124; 投递窗口 &#124; 建单后投递失败可恢复，不形成永久悬空 Task &#124;
&#124; &#96;AT-09&#96; &#124; worker 崩溃 &#124; 租约到期后可恢复，迟到 worker 不能写入 &#124;
&#124; &#96;AT-10&#96; &#124; Attempt 重试 &#124; 可重试失败产生新 Attempt，Task 不被过早终结 &#124;
&#124; &#96;AT-11&#96; &#124; 验收失败 &#124; 不合格输出不能使 Task 成功；允许按策略产生新 Attempt &#124;
&#124; &#96;AT-12&#96; &#124; 副作用后崩溃 &#124; 恢复不重复动作，回执与补偿状态可审计 &#124;
&#124; &#96;AT-13&#96; &#124; 预算耗尽 &#124; Attempt 明确终态；Task 按契约等待、重排或失败 &#124;
&#124; &#96;AT-14&#96; &#124; 取消竞争 &#124; 取消意图先持久化；完成与取消只有一个终态胜出 &#124;
&#124; &#96;AT-15&#96; &#124; 服务重启 &#124; 可重建所有非终态 Task、Attempt 和等待 Interaction &#124;
&#124; &#96;AT-16&#96; &#124; 前端断线 &#124; 按 cursor 回放无缺口，重复事件被去重 &#124;
&#124; &#96;AT-17&#96; &#124; 页面刷新 &#124; 有权用户仍可取得稳定版本结果 &#124;
&#124; &#96;AT-18&#96; &#124; 通知失败 &#124; Task 终态不变，Delivery 独立重试 &#124;
&#124; &#96;AT-19&#96; &#124; 事件升级 &#124; 旧客户端可按 &#96;payload_schema_version&#96; 兼容或明确拒绝 &#124;
&#124; &#96;AT-20&#96; &#124; Profile 升级 &#124; 历史 Task 仍按固定版本解释和复现 &#124;
&#124; &#96;AT-21&#96; &#124; 子 Task &#124; 预算不被放大、权限不扩张、血缘和证据可追溯 &#124;
&#124; &#96;AT-22&#96; &#124; 协调 Task &#124; 图通过后关闭，不等待全部子 Task 完成 &#124;

此外必须满足：

1. Task/Attempt 状态迁移、API schema、事件 schema、Profile schema 和错误码有机器可检查版本；
2. 每个 &#96;F-* / I*&#96; 登记实现所有者、代码位置、自动测试和当前覆盖状态；
3. 无法自动化的条款登记人工门禁、理由和复核证据；
4. 至少一个真实前端 Task 跑通提交、澄清、Attempt 失败重试、结果持久化、断线重放和重取；
5. 项目事实与目标规范分开，未实现能力不写成已有。

</pre>

**K-039** · 源 working/request-lifecycle.md，L623–L624；SHA-256 8520f5ac1c4f79c848be2656f631947b928c7ce687bcda7df75b5309c34a426b

<pre data-unit="K-039">## 12. 修订、落地与参考材料

</pre>

**K-040** · 源 working/request-lifecycle.md，L625–L636；SHA-256 1d9f99c71d9a8c53368a3c9bed88406ee6d174f20b28d55c5e9aba56a9ae830d

<pre data-unit="K-040">### 12.1 修订纪律

修改本文必须通过一个有原始请求、边界、影响分析、迁移方案和验收的规范修订工作单元。修改状态语义、
Profile 协议或终态时，必须说明历史数据和客户端兼容策略。修订记录必须保留旧语义、变更原因和迁移
边界；不得为整洁而让曾经生效的合同无痕消失。

功能缺失应建立独立开发工作单元；已实现代码违反本文应按缺陷处理。每项工作独立闭环，不用中央计划维护第二份
状态。当前覆盖以代码、测试与
&#91;&#96;../project-guide/repos/investment-app.md&#96;](../../project-guide/repos/investment-app.md) 为准；建立唯一实现矩阵时，
它必须记录 &#96;要求 ID → 所有者 → 代码位置 → 自动测试 → 当前状态&#96;、迁移映射和待实施工作。&#96;handoff.md&#96;
只投影当前阻塞与下一动作，其他计划文档不得复制覆盖状态；当前缺口和接线状态不进入本文。

</pre>

**K-041** · 源 working/request-lifecycle.md，L637–L642；SHA-256 941c9fc4553fef1ba75500df8ce50b82aada812bde19ee9a3f66f847beec05c8

<pre data-unit="K-041">### 12.2 参考材料边界

形成本文的候选、评审、历史设计和实现快照只保留在版本历史或相应研究记录中，不在产品合同内维护作者
清单或方案评分。它们可以解释某条要求的来源，但不能覆盖本文，也不能把可替换技术、开发流程或易腐现状
重新带回产品合同。需要改变本文时按 &#167;12.1 修订，而不是引用某份候选绕过现行语义。

</pre>

**K-042** · 源 working/request-lifecycle.md，L643–L647；SHA-256 33c436a4ad278c3a5e92f891732e405bf0bff846399df438eeaf9b132271df4d

<pre data-unit="K-042">### 12.3 生效边界

本文写入 &#96;dev-plan/&#96;，因为改变它意味着代码必须跟着改变。它成为后续实现与验收的目标合同，但不因
文件存在就自动证明能力已经落地。矩阵中尚无对应实现或处于 &#96;NOT_ASSESSED / GAP&#96; 的场景，是规范先于
实现的正常状态，不构成合同缺陷；只有 &#167;11 对应证据完成后，相关能力才可宣称已实现。
</pre>

### constraints.md（N）

按改动影响面自检；规则 ID、验证载体、操作例证与门禁盲区留在同一文件，防止只看禁令不看效力。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 约束与执行载体 | 以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。 | C-001, C-002, C-003, C-004, C-005, C-006, C-007, C-008, C-009, C-010, C-011, C-012, C-013, C-014, C-015 |

#### 约束与执行载体

**C-001** · 源 constraints.md，L1–L12；SHA-256 9896de6b95a2017f8b6e0666375be90be732eec1a04471c976c77de7bd85e652

<pre data-unit="C-001"># 开发必须遵守的规则

&gt; 最后更新：2026-08-29
&gt;
&gt; **动代码前先读这里。**违反其中任一条的方案**不进入讨论**——不是&quot;不推荐&quot;，
&gt; 是不提出。
&gt;
&gt; 项目现在长什么样，见 &#91;&#96;../project-guide/&#96;](../project-guide/)；
&gt; 要建什么见 &#91;&#96;development-plan.md&#96;](development-plan.md)，
&gt; 具体任务见 &#91;&#96;implementation-plan.md&#96;](implementation-plan.md)，
&gt; 当前状态见 &#91;&#96;handoff.md&#96;](handoff.md)。

</pre>

**C-002** · 源 constraints.md，L13–L39；SHA-256 4674596147384aca6c50d62ce32677ea582b7707e2b68001a7bb3d62a952a0f0

<pre data-unit="C-002">## 怎么用

不必每次通读。按**你要动什么**取对应的组，把相关条目和结论写出来：

&#124; 你要动 &#124; 读哪节 &#124;
&#124; --- &#124; --- &#124;
&#124; 表、迁移、存储 &#124; &#91;数据](#数据) &#124;
&#124; 跨 App 接口、契约 &#124; &#91;契约](#契约) &#124;
&#124; 登录、权限、服务间调用 &#124; &#91;身份](#身份) &#124;
&#124; 仓库、组件、运行角色 &#124; &#91;拓扑](#拓扑) &#124;
&#124; 部署、发版、镜像 &#124; &#91;发布](#发布) &#124;
&#124; 智能体 &#124; &#91;智能体](#智能体) + &#91;&#96;round-protocol.md&#96;](protocol/round-protocol.md) &#124;

对照结果就是一张小表，两三行即可：

&#124; 规则 &#124; 结论 &#124;
&#124; --- &#124; --- &#124;
&#124; 接口分面共享 application 用例 &#124; ✅ 共享 &#96;PilotService&#96;，只在 interfaces 层分身份 &#124;
&#124; 单一主档 &#124; ✅ 不新增状态 &#124;

**不相关的不必列；相关的漏列一条，方案就得重提。**

**「谁在执行」那一栏是重点。**标 ⚠ 的没有自动载体——它只是约定，会漂，
只能靠这个自检和评审守住。

---

</pre>

**C-003** · 源 constraints.md，L40–L53；SHA-256 9ce9f390bc6ef3568ea6539869d836ba133e441d6d949e0f3ab7ed8448976e29

<pre data-unit="C-003">## 数据

&#124; # &#124; 规则 &#124; 谁在执行 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; D1 &#124; **每类业务数据只有一个权威主档**，其余存储只保存引用、快照或可重建副本 &#124; ⚠ 自检 &#124;
&#124; D2 &#124; 每个 App 收敛**一个逻辑数据库、一条迁移链**；禁止跨 App 合并数据库或直接读表 &#124; ⚠ 自检 &#124;
&#124; D3 &#124; 物理资源可共享（同一 PostgreSQL 集群），但必须独立逻辑库、角色、Secret &#124; 部署清单 &#124;
&#124; D4 &#124; 对象存储按领域拥有：Bucket、凭据、生命周期必须隔离；**不以共享宿主机目录作交换协议** &#124; ⚠ 自检 &#124;
&#124; D5 &#124; **RAGFlow 是可重建的派生系统**，不保存唯一原文 &#124; ⚠ 自检 &#124;
&#124; D6 &#124; 迁移链单链线性，恰好一个 &#96;down_revision = None&#96; &#124; &#96;test_kernel_invariants.py&#96; &#124;
&#124; D7 &#124; 改迁移**必须同步改** &#96;test_kernel_invariants.py&#96; 里那份文件名清单 &#124; 该测试逐字比对 &#124;
&#124; D8 &#124; 迁移由**独立 Job** 执行，API / Worker / Scheduler 启动**不得**隐式升级数据库 &#124; ⚠ 自检 &#124;
&#124; D9 &#124; 前端**不得**持有后端或数据库凭据 &#124; &#96;core/config.py&#96; 启动期校验 &#124;

</pre>

**C-004** · 源 constraints.md，L54–L70；SHA-256 d5afc083b2be89498be9d25320c8f3a3a58e9f2b33164ef3d241555bb65e72cc

<pre data-unit="C-004">### 做数据迁移时

&#96;&#96;&#96;
expand → backfill → reconcile → switch read → switch write → observe → contract
&#96;&#96;&#96;

- 迁移前先出清单：表、约束、索引、revision、数据量、所有者、Secret、备份、消费者
- **旧写路径切换必须 fail-closed**，不得无期限双写
- 必要的双写必须有事务 Outbox、幂等、版本与对账，且有明确截止任务
- 回滚窗结束前保留旧库备份、旧角色定义与恢复演练证据

六条验收，缺一不可：可恢复备份 + 实际恢复演练 · 回填计数与业务不变量对账 ·
新旧读路径结果对比 · 旧凭据在切换后被拒绝 · &#96;migration current&#96; 只有一个 head ·
回滚与重新前滚均通过。

**这一整节 ⚠ 无自动载体**——是程序，静态查不出来。

</pre>

**C-005** · 源 constraints.md，L71–L81；SHA-256 15e0860aff2327e677f3dc0dfdb09b2c36f3ef8564646d10d7b152830c420839

<pre data-unit="C-005">## 契约

&#124; # &#124; 规则 &#124; 谁在执行 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; C1 &#124; 即时查询走**版本化同步 API**，长耗时走事件；事件经 Transactional Outbox 发布 &#124; ⚠ 自检 &#124;
&#124; C2 &#124; 接 Outbox 的消费者必须实现**幂等、死信、重放、周期性对账**——四项缺一，Outbox 只是个表 &#124; ⚠ 自检 &#124;
&#124; C3 &#124; schema 真源在 **provider** 仓，consumer 只持锁文件。两处都改会产生第二真源 &#124; 双端 &#96;test_provider_contract_lock_matches_authoritative_schemas&#96; &#124;
&#124; C4 &#124; 改契约必须**双端一起测**——单仓 CI 只跑自己那半，provider 改了、consumer 锁没跟，两边各自都绿 &#124; 双端契约测试（跑 investment 常规套件即带上） &#124;
&#124; C5 &#124; 契约 DTO &#96;extra=forbid&#96;，未声明字段一律拒收 &#124; Pydantic 模型 &#124;
&#124; C6 &#124; citation &#96;source_href&#96; 全平台同形 &#96;/api/web/v1/citations/{id}/source&#96;，共七处，改一处必须七处一起改 &#124; 双端路由表比对测试 &#124;

</pre>

**C-006** · 源 constraints.md，L82–L94；SHA-256 97feffd0ab17a883c57b4514578ce27b3b37b3b4927569e191992c19e62d9621

<pre data-unit="C-006">## 身份

&#124; # &#124; 规则 &#124; 谁在执行 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; I1 &#124; **Admin / Web / Internal 是接口分面，不是三套应用层**——分面在 interfaces 层，共享 application 用例 &#124; ⚠ 自检 &#124;
&#124; I2 &#124; Internal API 按**提供方能力**命名（&#96;ingestions&#96;、&#96;retrievals&#96;、&#96;citations&#96;），**不按调用方命名** &#124; ⚠ 自检 &#124;
&#124; I3 &#124; 浏览器身份与服务身份**互不通用**；浏览器、服务、数据库凭据**禁止复用** &#124; ⚠ 自检 &#124;
&#124; I4 &#124; Next.js **可以**承担浏览器同源 BFF / session 边界，但**不得成为领域数据所有者** &#124; ⚠ 自检 &#124;
&#124; I5 &#124; session / BFF 与 FastAPI 的授权分工**必须有显式契约**；Backend 必须自行复核资源所有权、Origin/CSRF、租户与工具权限——**不信任任何上游声明的身份** &#124; ⚠ 自检 &#124;
&#124; I6 &#124; 非安全方法必须**同时**满足 &#96;Origin ∈ frontend_origins&#96; **且** CSRF token 匹配 &#124; 中间件 &#124;
&#124; I7 &#124; 服务令牌 subject 必须命中 &#96;service_auth_subject_bindings&#96; 的精确键；下游调用路径必须命中 allowlist 前缀 &#124; &#96;core/config.py&#96; + 依赖 &#124;
&#124; I8 &#124; 生产期约 35 处配置硬校验：**配错则进程起不来**，不是运行期降级 &#124; &#96;core/config.py&#96; &#124;

</pre>

**C-007** · 源 constraints.md，L95–L104；SHA-256 19a7f1038693761aaf218e36e0b7561034f6e13c26f2336d31a49b161592b6d6

<pre data-unit="C-007">## 拓扑

&#124; # &#124; 规则 &#124; 谁在执行 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; T1 &#124; 按**长期业务领域**划分 App，不按页面或部署组件划分 &#124; ⚠ 自检 &#124;
&#124; T2 &#124; **每个领域 App 只有一个规范 Backend** &#124; ⚠ 自检 &#124;
&#124; T3 &#124; **一个 Backend 代码库按运行角色部署**（API / Worker / Scheduler / Migration）；模板组件不定义领域边界，运行角色不等于领域服务 &#124; ⚠ 自检 &#124;
&#124; T4 &#124; 父仓**不得出现悬空 gitlink**——子仓提交没推，别人克隆父仓会拉不到 &#124; &#96;~/five-repos-sync/sync-five-repos.sh&#96;：它同步五个父仓，拉取侧自动 &#96;submodule update --init --recursive&#96;，子仓提交没推会**当场报错**。⚠ 但它只推父仓不推子仓，子仓的提交仍须自己推 &#124;
&#124; T5 &#124; 跨仓改动宣称&quot;已完成&quot;时，**必须带「仓 + 提交号」**——k8s 与四个 App 是并列独立仓，只写提交信息的话，评审方只能猜取证对象，会得出&quot;改动不存在&quot;的结论 &#124; ⚠ 自检 &#124;

</pre>

**C-008** · 源 constraints.md，L105–L115；SHA-256 066c8c3a6899c9c7a9c7ac4385aba08e97da672ee5a5f796243a0abe3f5fd07c

<pre data-unit="C-008">### 什么时候才拆出专用 Worker

默认每个 App **只有一个通用 Worker**。满足下列任一条才拆，且要有证据
（队列延迟、运行时长、资源、失败率、权限证据），不是预感：

1. 浏览器、GPU、沙箱等依赖**显著扩大攻击面或镜像体积**
2. 任务时长、重试或取消语义**显著不同**
3. 需要**独立网络 / 服务身份**
4. 有**持续容量指标**支持独立扩缩容
5. 故障隔离**无法**通过队列和 Pod 边界实现

</pre>

**C-009** · 源 constraints.md，L116–L127；SHA-256 846b2fd4655535a1369550d87d33331bb8f7797456ab94e8c03fdb7acabafc46

<pre data-unit="C-009">## 发布

&#124; # &#124; 规则 &#124; 谁在执行 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; R1 &#124; 源码、镜像、部署与数据基线**共同发布**；仅靠 Git 标签不能恢复运行环境 &#124; ⚠ 自检 &#124;
&#124; R2 &#124; bundle 只允许 &#96;repo@sha256:&lt;64hex&gt;&#96;，**不允许可变 tag** &#124; 部署门禁正则 &#124;
&#124; R3 &#124; 部署 bundle 的 digest 必须与发布清单一致——晋级靠打别名，**禁止重新构建** &#124; ⚠ 自检（R7 清单与 bundle 手工比对） &#124;
&#124; R4 &#124; &#96;.conf&#96; **不得覆盖** bundle 里的镜像、副本、origin，值须与 &#96;release.json&#96; 完全一致 &#124; &#96;ConfigError&#96; &#124;
&#124; R5 &#124; &#96;1.0.0&#96; / &#96;2.0.0&#96; 是发布 tag，本地构建脚本**不得**推上去 &#124; &#96;build-push-app-images.sh&#96; 的 &#96;PROTECTED_TAGS&#96; &#124;
&#124; R6 &#124; **模板优先**：公共能力先进模板过门禁，再完整同步实例；**不得先改实例** &#124; ⚠ 自检 &#124;
&#124; R7 &#124; 源码版本（&#96;pyproject.toml&#96; + &#96;uv.lock&#96;、&#96;package.json&#96;）必须与发布版本一致 &#124; &#96;test_package_version_matches_the_formal_release&#96; &#124;

</pre>

**C-010** · 源 constraints.md，L128–L136；SHA-256 e36bcc43b96db28190f13ff1a1c60064d0d973e5a52b755ab7501aae175e0375

<pre data-unit="C-010">### 改模板、同步实例时

- 同步顺序**串行固定**：Info → Knowledge → Investment。**一个实例失败不得推进下一个**
- 「完整同步」包含：工程、认证、授权、错误、日志、审计、配置、任务、存储、UI 通用能力
- **实例领域代码用显式 extension point / overlay 保留，禁止清空覆盖**
- 每个实例出**模板对齐报告**，差异分四类：领域扩展 · 配置 · 暂时兼容 · **违规漂移**
- 每个实例独立完成静态、单元、契约、配对、KIND、身份与回滚测试
- 父仓 gitlink 与 release manifest 必须一致

</pre>

**C-011** · 源 constraints.md，L137–L143；SHA-256 f76c3eab37fae20a0a28f1fccbe4497c573ef38d2699200bd630eac29996ece3

<pre data-unit="C-011">### 清理镜像时

- 删除保护 release、live、evidence、rollback 及其 OCI 引用闭包
- 删除前**重新采集**工作负载现状，执行 **dry-run** 并做**人工审计**；删除后才 GC
- 本地镜像只有在 Harbor 按 digest 可恢复、且 KIND 不再依赖本地候选后才能清理
- **旧架构资产在观察窗结束前不得删除**

</pre>

**C-012** · 源 constraints.md，L144–L148；SHA-256 532207857c4c9aeedeb33b812199c41cffb2d0cb13fd3541c9bc4884a66f65b4

<pre data-unit="C-012">### 一条环境事实

**KIND 默认不执行 NetworkPolicy**（kindnet 不 enforce）。包级验证必须另起
Calico 集群，否则&quot;测过了&quot;是假的。

</pre>

**C-013** · 源 constraints.md，L149–L160；SHA-256 db4c3025e20d3f9d3fba7bc9152e62bdf7b02ab6d89202e1394275ae4e3d9613

<pre data-unit="C-013">## 智能体

&#124; # &#124; 规则 &#124; 谁在执行 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; A1 &#124; 分**通用**（执行编排）与**专用**（领域），新增业务智能体优先是新增一份 Profile，不是 fork 一套代码 &#124; ⚠ 自检 &#124;
&#124; A2 &#124; **两边都要有纪律**，不存在&quot;通用部分不需要约束&quot; &#124; &#91;&#96;round-protocol.md&#96;](protocol/round-protocol.md) &#124;
&#124; A3 &#124; 四本账（预算 / 幂等 / 副作用 / 证据）**必须落 PostgreSQL**——跨 run、跨进程死亡仍须正确的不变量，必须由存储承担 &#124; ⚠ 自检 &#124;
&#124; A4 &#124; 执行层**租用不自建**，依赖边界严格限定在 SDK，不得直接依赖裸协议 &#124; ⚠ 自检 &#124;
&#124; A5 &#124; 领域概念**不得进入 Port 签名**（&#96;run(sql, limit)&#96; 可以，&#96;run_portfolio_query(持仓ID)&#96; 不可以） &#124; ⚠ 自检 &#124;

---

</pre>

**C-014** · 源 constraints.md，L161–L180；SHA-256 fdef054a43d01c8040bb9d016de53ae44d0567422bd015324a302ad5b9d5ed09

<pre data-unit="C-014">## 保证这些被遵守的三层

&#124; 层 &#124; 覆盖 &#124; 在哪 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **随测试自动跑** &#124; 标了测试载体的那些 &#124; 四仓 &#96;tests/test_kernel_invariants.py&#96;、&#96;tests/test_dormant_capabilities.py&#96;、双端契约测试——**跑 &#96;uv run pytest&#96; 就带上，不需要谁记得** &#124;
&#124; **随提交自动跑** &#124; 本仓文档的三项机械不变量 &#124; &#91;&#96;doc-gate.py&#96;](doc-gate.py) 经版本化的 &#96;.githooks/pre-commit&#96; 触发——**提交就带上**。装一次 &#96;git config core.hooksPath .githooks&#96; 对全部 worktree 生效（共享同一个 &#96;.git&#96;），装没装用 &#96;doc-gate.py --selfcheck&#96; 判定 &#124;
&#124; **指针** &#124; 全部 &#124; 五仓根 &#96;AGENTS.md&#96;、&#96;.cursor/rules/&#96;、八个组件 &#96;CLAUDE.md&#96;（**进目录自动注入**） &#124;
&#124; **自检** &#124; 全部 &#124; 上面「怎么用」那节 &#124;

**只有第一层不依赖人。**后两层是纪律，纪律会被忘——这份文件本身就出过两次
&quot;规则在眼前却没回头对照&quot;：一次提出了违反 D1 与 I1 的方案，一次把 I4 说反了
（断言不能用 BFF，实际是可以用、只是不能拥有数据）。

**曾经有过两个独立检查脚本，已删。**理由不是它们没用，而是**要人记得跑的检查
和写在文档里的规矩没有本质区别**——它们自己就落在&quot;纪律&quot;那层。更糟的是其中一条
路径检查的结论取决于工作区状态：同一份文档在三台机器上分别报 0 / 4 / 95 条失败
（子模块是否初始化）。**看起来在把关，其实不牢。**

规则要有载体，就做成**跟着测试跑**的；做不成的，老实标 ⚠。

</pre>

**C-015** · 源 constraints.md，L181–L214；SHA-256 53c976a3d820eb42176bf01def590c0d22a5de4626ea2f88cc169c80666450b6

<pre data-unit="C-015">### &#96;doc-gate.py&#96; 为什么不是第三个被删的脚本

它正面避开了那两个坑，且两条都可验证：

- **不靠人记得跑**：由 &#96;.githooks/pre-commit&#96; 触发，不是&quot;记得执行一下&quot;。
- **结论不取决于工作区状态**：链接一律对照 **git 索引**解析，不看文件系统。未跟踪的
  草稿、未初始化的子模块、本机临时文件都不影响判定；本仓无子模块，且它只看本仓、
  不跨仓——跨仓正是被删那条的失败点。

它只查三件确定性的事：仓内链接目标存在、&#96;&#167;N&#96; 引用有对应标题（含**跨文档**解析：
同一处点到哪份文档就查哪份）、表格列数与表头一致。

**规矩是先清零再扩范围。**一个在合法内容上大面积报错的检查不是门禁，是噪音——上线
当天所有人就会 &#96;--no-verify&#96;，又退回纪律层。首版只管 &#96;dev-plan/working/&#96;；2026-09-02
把全仓 117 份文档的存量问题清完后，&#96;GATED&#96; 已扩到整个 &#96;sunmoonai/docs/&#96;。范围外（若
将来再有）用 &#96;doc-gate.py --survey&#96; 巡检，只报告不拦截。

**试过但撤掉的一条：**「反引号链接文字必须与 href 指向同一文件」。它确实能堵
4d7942c0 记的那个盲区，但一跑就报 16 处，其中多数是合法的显示约定——文字写可读的
&#96;project-guide/repos/investment-app.md&#96;，href 写 &#96;../../&#96; 实走法。**这正是本仓付过
学费的坑，差一点原样重犯。**该盲区仍标 ⚠：改了 href 忘改显示文字，机械检查抓不到。

**试过又撤掉的一条：主线独有文档的删除保护。**曾把 human 那份从各助手分支删掉
（「助手用不到」），随即发现它与「分支要合回主线」天生冲突：git 里删掉分支上主线也有
的文件，合并回去就连主线一起删。当时的解法是加门禁去挡合并——**方向错了**。合回主线
是正常工作方式，不该为一个「目录清爽」的偏好让每次合并都要处理一次。已改为让各分支
保留该文件，门禁随之撤除。**真正该清的是只存在于自己分支的东西**（本轮各家的候选稿与
评审）——那些主线从来没有，删掉不传播任何影响。判据是一句话：**这份东西主线有没有？
主线也有，就别在分支上删。**

**它抓不到什么（老实标 ⚠）**：章节引用**指向存在但语义错误**的那一节。文件还在、
链接还通、编号也解析得到，只是重编号后指的内容全变了。2026-09-02 重写后
&#96;development-lifecycle-human.md&#96; 的四处引用正是这一类，只能靠人比对标题发现。
经实测注入验证：同一批 bug 中它抓到了死链和表格列数，**漏掉了这一条**。
</pre>

### specs/foundation.md（N）

先建立适用边界及设计取舍，再统一名词和反例；实现不同模块时有共同判定基础。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 边界与原则 | 回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。 | G-002, G-003, G-004, G-007, G-008, G-013, G-011 |
| 产品取舍 | 回答功能为什么做或暂不做；保持原阶段和观察日期限定，不把状态当作目标。 | D-002, D-010, H-008 |
| 名词与反例 | 定义跨组件共同词义和禁止形态；单次失败的完整事件移历史/质量组。 | G-107, G-103 |
| 已裁定的设计边界 | 明确哪些旧设计不得复活，独立观察与处置必须相邻；不能因其叫历史裁定就移出日常规范。 | G-091, G-092, G-093, G-094 |

#### 边界与原则

**G-002** · 源 agent-dev-guide.md，L23–L51；SHA-256 44a84cbd2de2a8ada67fd38f0ec3e737f5bcf12145e561cc190e83ce1421c122

<pre data-unit="G-002">## 0. 先读结论

平台只建设一个产品运行时。它以
&#91;&#96;request-lifecycle.md&#96;](working/request-lifecycle.md) 定义的 Task、Attempt、Interaction、Artifact、
Event、Side Effect、Delivery 为唯一产品内核；&#96;dev.change/1&#96; 是首个开发类 Task Profile，
五家助手分别登记为 Agent Profile。Task Profile 定义“这类请求怎样算完成”，Agent Profile 定义
“某个执行器能怎样做”，二者不是两套运行时，也不得改变内核状态词。

人在模型里是 &#96;requester&#96; 和持权 &#96;principal&#96;，不是执行者。人提出目标、回答 Interaction、批准
不可逆动作并承担交付责任；实际执行者是受 Agent Profile 约束的 adapter 或确定性组件。

以后做开发类请求，按这一条链走：

&#96;&#96;&#96;text
Submission
  → router 形成 RouteDecision
  → 冻结 dev.change 工单
  → provision 独占工作区
  → orchestrator 创建并推进 Attempt
  → executor adapter 执行
  → validator + 独立 acceptor 验收
  → principal 批准不可逆 Side Effect
  → publisher 发布，Delivery 可重取
&#96;&#96;&#96;

当前的 Git 轮次是这条链的手工实现，也是验证对象形状和协作纪律的脚手架；它不能证明数据库事务、
租约、fencing 或执行器内部行为。产品能力是否存在，只认代码、迁移、测试和可复跑运行证据，
不因本文写了目标形状就宣称已经实现。

</pre>

**G-003** · 源 agent-dev-guide.md，L52–L69；SHA-256 9946601352fc880ddf484049f1d74847d851a79ff5df073f881374e94579713e

<pre data-unit="G-003">### 0.0 原来是什么样，为什么非改不可

**新读者先读这一节。**只看目标形状会觉得「本来就该这样」，
从而在下一次设计时把同样的坑再挖一遍。六个结构问题都是**在既有文档里能自证**的，
不是外部批评：

&#124; # &#124; 原来的问题 &#124; 为什么它不是小毛病 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; 开发被写成**两条平行路径**（一条由服务建仓、一条由人建仓），再声明「后半段同构」 &#124; 两条路径的差异最后只剩「**谁按了回车**」，撑不起两份文档，却制造了两份会各自漂移的真源 &#124;
&#124; 2 &#124; 「supervisor」一个词同时指**三套不同的东西**，第三套还有个从没定义过职责边界的别名 &#124; **每加一层就加一个名字，说明抽象层级选错了**。稳定的概念不是「谁监督谁」，是「这个状态转换由谁执行、需要什么权力、在哪里强制」 &#124;
&#124; 3 &#124; 人的权力与流程步骤**混写**在上千行叙述里，另一份文档又抄一遍 &#124; 那样的权力表是**第二份说明书，不是机制**——它不驱动任何东西，只能靠人记得读 &#124;
&#124; 4 &#124; 有**一个环节命令判不了**（人的确认），只能靠人声明 &#124; 与「状态从产物反推、不从声明读取」直接冲突，而**全自动化正好卡在这个洞上** &#124;
&#124; 5 &#124; 产品**执行层架构**与开发流程装在同一份文件里，约五百行 &#124; 两拨读者被迫读对方的东西；改一处要担心影响另一处 &#124;
&#124; 6 &#124; 档位只有最重的那一档有正文，轻的两档各一行 &#124; 没有可执行形态的档位**等于不存在**，日常任务只能绕过整套纪律 &#124;

**本文的形状是这六条的答案**：一个运行时（对 1、5）、五个各有定义的角色词（对 2）、
一张驱动流程的权力表（对 3）、人的确认也落成可判的产物（对 4）、三档都有正文（对 6）。

</pre>

**G-004** · 源 agent-dev-guide.md，L70–L86；SHA-256 e5e1ab2117c5ec746ab76e0f545fefe1e8477e1ad31647dc514df88c4eae6d4e

<pre data-unit="G-004">### 0.1 文档边界

&#124; 真源 &#124; 本文怎样使用 &#124; 本文不做什么 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#91;&#96;request-lifecycle.md&#96;](working/request-lifecycle.md) &#124; 引用七对象、Task/Attempt 状态机、&#96;I1&#96;–&#96;I15&#96;、&#96;F-*&#96;、&#96;AT-*&#96; &#124; 不重写对象定义、合法边或产品验收矩阵 &#124;
&#124; &#91;&#96;round-protocol.md&#96;](protocol/round-protocol.md) &#124; &#167;3.19–&#167;3.22 汇总执行所需的阶段、取件、超时规则 &#124; 不另立协议版本；协议改变时同步修订本导读 &#124;
&#124; &#91;&#96;constraints.md&#96;](constraints.md) &#124; 开工前自检硬约束，尤其 A1–A5 &#124; 不把自检改成建议 &#124;
&#124; &#91;&#96;development-plan.md&#96;](development-plan.md) &#124; 解释通用执行编排与领域能力的分工 &#124; 不记录进度 &#124;
&#124; &#91;&#96;implementation-plan.md&#96;](implementation-plan.md) &#124; 记录可实施工作单元、依赖、测试和回滚 &#124; 不承担架构真源 &#124;
&#124; &#91;&#96;handoff.md&#96;](handoff.md) &#124; 只读当前游标、阻塞和不能倒退的结论 &#124; 不从状态反推目标规范 &#124;
&#124; &#91;&#96;working/request-baseline/&#96;](working/request-baseline/) &#124; **所有者的原始需求档案**：只解释来源，**不覆盖现行合同，也不证明当前能力**（&#96;I1&#96; 在本仓的实物） &#124; 不据它断言现状 &#124;
&#124; 历史 archive 五稿及 README &#124; 相容内容在本文正文，取舍与来源见 &#167;10；只用于历史复核 &#124; 不作为开发前置阅读；被撤销主张集中在 &#167;8，不恢复其规范效力 &#124;

内核的对象和状态以 &#96;request-lifecycle.md @ ed0b5136:92-343&#96; 为准；协作阶段以
&#96;round-protocol.md @ ed0b5136:52-706&#96; 的标题为准。本文出现的表都是开发投影或实现要求，
不是第二份产品定义。

</pre>

**G-007** · 源 agent-dev-guide.md，L126–L127；SHA-256 fd773b00e856a9a6579a9674695912ee15f55fa2b63ef60651f821afc3a98db7

<pre data-unit="G-007">## 1. 不可变的契约与边界

</pre>

**G-008** · 源 agent-dev-guide.md，L128–L142；SHA-256 be7a7922e6be129918031ead9897db037299d4c4fbc5b8e6408c82c1c0c48003

<pre data-unit="G-008">### 1.1 唯一产品内核

&#96;request-lifecycle.md&#96; 是下列事实的唯一写入面：

- Task 与 Attempt 是两层；一次执行失败不自动终结用户请求；
- Task 只走其“Task 状态机”列出的边，Attempt 只走其“Attempt / Run 状态机”列出的边；
- &#96;WAITING&#96; 用结构化 reason 表示等待输入、批准、依赖、资源或外部条件，不为每种等待发明状态；
- Task 和 Attempt 终态不可重开，重试、刷新、改目标或推翻旧结果建立新实体并保留血缘；
- 结果、验收、证据与终态先可靠持久化，Delivery 再通知前端。

这些要求分别可回到 &#96;request-lifecycle.md @ ed0b5136:106-119&#96;、
&#96;request-lifecycle.md @ ed0b5136:203-343&#96; 和 &#96;request-lifecycle.md @ ed0b5136:398-440&#96;。
实现若需要新增状态或合法边，不得在 &#96;dev.change/1&#96; 里偷加；按该文“修订纪律”
建立带原始请求、影响、迁移和验收的规范修订工作单元。

</pre>

**G-013** · 源 agent-dev-guide.md，L187–L212；SHA-256 ffb90d1095ec3ca2b57817132bfc84e073f058c662deca4cd6e60385a7fda406

<pre data-unit="G-013">### 1.6 七条设计原则

全文的取舍都回到这七条。它们不是新主张，是把本仓已成文的判断当成设计约束用到底：

&#124; # &#124; 原则 &#124;
&#124; --- &#124; --- &#124;
&#124; **P0** &#124; **只有一套状态机（Task / Attempt）**，场景差异只体现在 Profile 的 guard、必需产物与 interrupt 策略；**任何场景不得新增状态词** &#124;
&#124; **P1** &#124; **同一事实只有一个权威写入面**；两份同构文档即两个真源（&#96;I13&#96;，&#167;1.2） &#124;
&#124; **P2** &#124; **状态从产物反推，不从声明读取**——人的动作也不例外 &#124;
&#124; **P3** &#124; **方向不对称**：朝严谨可自裁，朝省事须人确认；⚠ **默认值属于省事方向** &#124;
&#124; **P4** &#124; **判据必须声明覆盖范围**；⚠ **覆盖不全比没有更危险**（&#167;5.2） &#124;
&#124; **P5** &#124; ⚠ **凡能落成代码、测试或门禁的纪律必须落成**；文字只描述意图，不构成机制 &#124;
&#124; **P6** &#124; **设计机制前，先核实它要处理的动作实际发生在哪里、由谁执行、经过什么路径**；未核前提只能标假设，验证办法见 &#167;1.7 &#124;

**两条推论：**

⚠ **一个只能靠人转述的环节等于没有环节**（P2 + P5）。这条决定了本文对人介入的全部设计：
&#167;4.2 的每一行都要有 &#96;enforcement_point&#96;，&#167;4.4 要求强制点落在执行者够不着的地方，
理由都在这里。

⚠ **P0 的适用层级是 Task 与 Attempt。**Artifact、Interaction 等对象各有自己的小生命周期
（&#167;3.11 的 &#96;DRAFT → FROZEN → … → PUBLISHED&#96;、内核的 &#96;consumed_at&#96;）——
**那些不是「第二套状态机」，而是对象属性**，并且同样跨场景共用、不得按场景另造。
把对象属性误认成状态机，会导致每个场景各造一套；把状态机误认成对象属性，
会导致状态词失控增长。**两边都错，方向相反。**

</pre>

**G-011** · 源 agent-dev-guide.md，L164–L170；SHA-256 754904ef311d2d718d779665de7298d987cc6829b2c50e9957afb254d84f2f7b

<pre data-unit="G-011">### 1.4 开发验收不可外推

开发变更常可用测试、门禁和 diff 机械复算，成本低；财务分析的判断、新鲜度与口径验收昂贵。
&#96;dev.change/1&#96; 跑通只证明开发场景的对象形状、转换和证据链，**没有解决判断且昂贵的那一半**。
财务 Task Profile 必须以真实输入、输出、renderer 与验收用例重新证明，不能复制本章的便宜验收器。
这一边界与业务 Task Profile 首版要求相符（&#96;request-lifecycle.md @ ed0b5136:487-518&#96;）。

</pre>

#### 产品取舍

**D-002** · 源 development-plan.md，L10–L23；SHA-256 0d5bffad5c99a490a12a8e3847eab5a709de2b4242ebad50c2002aac2c087b26

<pre data-unit="D-002">## 起点：不延续 v5

&#96;mooc-manus-langgraph-longterm-plan-v5.md&#96; 及其实施计划降级为**历史设计输入**。

理由是它的重心不对：主体是前后端对接（&#167;10 消息/事件/投影/流式 200 行，
而 &#167;14 多智能体架构只有 23 行；实施计划 17 个前端任务对 14 个 Runtime 任务，
多智能体只有一个&quot;薄切&quot;且 &#96;NOT_STARTED&#96;）。

**它的前后端对接部分仍然有效且详尽**，做那一阶段时逐节引用。
但它不是智能体架构的依据。

不做版本号延续——叫 v6 会隐含继承那个以前端为重心的框架，
而我们恰恰要摆脱它。

</pre>

**D-010** · 源 development-plan.md，L134–L142；SHA-256 bb2f1663c7d5fe79bc33f4375c4872b18993976f10c98140e5962554819afef9

<pre data-unit="D-010">## 有意留白的两处

模板提供了原语但实例没接，这是**决定**，不是欠账。投影只能证明&quot;零调用&quot;，
证明不了&quot;有意&quot;——所以理由和重新审视的触发条件写在这里。

&#124; 项 &#124; 为什么现在不接 &#124; 什么时候重新审视 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 共享 Outbox / Inbox &#124; 没有业务需要之前接上去，等于凭空加一块要维护、要监控、要排障的面 &#124; **第一个跨 App 异步事件落地时**，届时一并定投递语义与去重键 &#124;
&#124; Celery &#96;beat_schedule&#96; &#124; 同上 &#124; **第一个定时任务落地时**，届时须解决 beat 的多副本重复触发 &#124;
</pre>

**H-008** · 源 handoff.md，L68–L79；SHA-256 aabd59897abbb06a7029bfc096f791351356e4ef40599a0522e285ab8940797c

<pre data-unit="H-008">## 不能倒退的输入

以下已经定了，接手时**不要重新讨论**：

&#124; &#124; 结论 &#124; 定于 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 施工顺序 &#124; 前后端对接 → agent 开发 → 问数 &#124; 2026-08-29 &#124;
&#124; 问数的位置 &#124; 专用智能体的一个实例（加一份 Profile + 一个工具），不是另一套架构 &#124; 2026-08-29 &#124;
&#124; SQLBot / WrenAI &#124; **参考资料，不是选型候选** &#124; 2026-08-29 &#124;
&#124; v5 的地位 &#124; 历史设计输入；其 &#167;10 前后端对接仍有效且详尽，做阶段一时逐节引用 &#124; 2026-08-29 &#124;
&#124; 四本账 &#124; 幂等、副作用已接线；缺预算与证据 &#124; 取证于 2026-08-29 &#124;

</pre>

#### 名词与反例

**G-107** · 源 agent-dev-guide.md，L3004–L3037；SHA-256 242917fd32677a5e94f62168fa7756e13ddad8e0ae3e69d0f95813e251850e75

<pre data-unit="G-107">## 13. 词汇对照

本表是阅读辅助；产品对象的精确定义与合法边仍归现行合同，**不另立一套产品状态机**。
读流程时尤其区分：Attempt 完成表示执行结束，Task 成功还要求冻结验收与交付条件成立。

&#124; 内核用语 &#124; 本文对应物 &#124;
&#124; --- &#124; --- &#124;
&#124; Submission &#124; 原始请求来源；人直接提出时由人冻结请求与验收（&#167;3.1） &#124;
&#124; Task &#124; 一件有边界的开发工作及其冻结契约（&#167;2.4） &#124;
&#124; Attempt &#124; 一次实施、候选或修复轮次（&#167;3.3） &#124;
&#124; Work Unit &#124; 派出的子工作单元；**不是产品子 Task** &#124;
&#124; Artifact &#124; 代码、补丁、报告、测试输出、证据（&#167;3.6） &#124;
&#124; Interaction &#124; 向 principal 的澄清或批准请求（&#167;4.3） &#124;
&#124; Event &#124; 只追加的事实记录，状态由其投影；可包含改判与证据引用（&#167;5.7） &#124;
&#124; Side Effect &#124; 对外部世界产生作用的动作及其持久意图/回执/补偿；不可逆部分受 H5 控制（&#167;4.5） &#124;
&#124; Task Profile &#124; 这类任务的输入、输出、验收、证据和策略契约，如 dev.change/1（&#167;2.3） &#124;
&#124; Agent Profile &#124; 执行器的能力、调用方式、粒度与边界；不是业务主档（&#167;2.3） &#124;
&#124; principal / requester &#124; 持有某项决定权的主体 / 提出请求的主体；身份与执行器分开（&#167;4.1） &#124;
&#124; harness / executor adapter &#124; 执行外壳（程序、提示词、工具）/ 将其公开 SDK 接到统一 Port 的适配层（&#167;2.6–&#167;2.8） &#124;
&#124; router / orchestrator &#124; 确定性路由 / 状态推进、派发、收集与停止组件，不是自由 Agent 角色（&#167;2.1） &#124;
&#124; provenance &#124; attested 为可实证归因、reported 为自报、inferred 为推断；具体采信还受覆盖与隔离限制（&#167;5.2） &#124;
&#124; S / R / 投影 Π &#124; 结构等效 / 轨迹等效 / 比较前只丢弃约定私有事件与时间戳（&#167;5.3） &#124;
&#124; 登记集合 / 自动路由候选集 &#124; 知道某执行器存在 / 已具备获准自动调用与审计能力的子集（&#167;2.3） &#124;
&#124; 未归因效应 &#124; 外部观察到但找不到对应账目的变更；只记录，不伪造事前 Task（&#167;6.3） &#124;
&#124; H1–H8 / T0–T2 / E0–E4 &#124; 权力行 / 风险流程档位 / 证据等级，三个不同维度（&#167;4.2、&#167;3.4、&#167;5.2） &#124;
&#124; Delivery &#124; 最终回复与可重取产物（&#167;3.5） &#124;
&#124; Handoff &#124; &#91;&#96;handoff.md&#96;](handoff.md)；**单写者面**（&#167;7.5） &#124;
&#124; 工作区 / worktree &#124; 每个可写执行者的并行隔离工作区（&#167;3.2、&#167;3.6） &#124;
&#124; 命名分支 &#124; 一执行者一分支；commit 的**运输通道，不是评审对象**（&#167;3.9） &#124;
&#124; 未提交工作区文件 &#124; 仅本地草稿；**同一工作区同一路径后写覆盖先写**（&#167;3.7） &#124;
&#124; 人的主 checkout &#124; 如 &#96;~/master/&lt;仓&gt;&#96;；**只读参照，不是投稿箱**（&#167;3.6） &#124;
&#124; Attempt 租约 / fencing &#124; **产品侧机制**，语义见内核；**开发侧无等价运行时**，迟到判定靠冻结 commit 与整合方核对（&#167;3.9） &#124;
&#124; &#96;dispatch_event&#96; &#124; 人代运行时执行的一次传输动作；**不是权力，是可计数的欠账**（&#167;5.1） &#124;

</pre>

**G-103** · 源 agent-dev-guide.md，L2876–L2923；SHA-256 5c4f84af05095fe4b15c3812f5f9d28c0c62eb85dd66fe4c4b064c86fb6f79da

<pre data-unit="G-103">## 11. 反模式

**这一节是机制描述，不是训诫。**每行左边是做法，右边是它**怎样失败**——
没有失败方式的条目不该进表。与 &#167;8 的区别：&#167;8 是本项目**已被推翻的设计**，
本节是**任何项目都会踩的做法**。

&#124; 反模式 &#124; 失败方式 &#124;
&#124; --- &#124; --- &#124;
&#124; 只保存整理稿，不保存原话 &#124; 原始意图不可追溯（违 &#96;I1&#96;） &#124;
&#124; Task 未落库就建仓或调度 &#124; 无主 sandbox、不可恢复执行 &#124;
&#124; 把所有资料塞进工作区 &#124; 越权、泄密、上下文污染 &#124;
&#124; 执行者猜仓库、分支或目录 &#124; 修改落错可写面 &#124;
&#124; 在获准工作区之外另建仓 &#124; 绕过供给、授权和回收 &#124;
&#124; **会话隔离当作文件隔离** &#124; 多个执行者仍写同一物理文件，**最后保存者覆盖前者** &#124;
&#124; **用 &#96;-new&#96; / 时间戳 / 执行者名当隔离** &#124; **文件名不是工作区。**共享路径上照样后写覆盖先写，且制造虚假安全感——以为改了名就安全，于是继续都写同一个目录 &#124;
&#124; 把人的主 checkout 当文档原件投放点 &#124; 既覆盖人的未提交改动，也覆盖其他执行者的草稿；**被覆盖方无痕消失** &#124;
&#124; 未提交就让别人到「同一路径」接盘 &#124; 拷走的是没有归属的污染源，**接盘者不再是独立候选** &#124;
&#124; 交卷报路径不报 commit &#124; 路径会漂移、会被覆盖，**评审对象丢失** &#124;
&#124; 每个执行者都写共享 &#96;handoff.md&#96; &#124; 单写者面被互相覆盖，交接游标失真 &#124;
&#124; 所有候选直接写用户指定的最终路径 &#124; **路径成为竞态，选优在写入时被偷偷决定** &#124;
&#124; 多个执行者直接改 master/main &#124; 未经整合的草稿互相覆盖并污染发布面 &#124;
&#124; 发布时不校验目标 HEAD/version &#124; 新结果静默覆盖别人的更新，或旧结果覆盖新结果 &#124;
&#124; non-fast-forward 后 force-push &#124; **用运输命令抹掉并发历史和已评审对象** &#124;
&#124; 用 mtime 判断作者或采用版本 &#124; 时钟和后续复制会误导溯源，provenance 丢失 &#124;
&#124; 未跟踪文件作为唯一交付 &#124; 无 commit/digest，覆盖后难以恢复和归因 &#124;
&#124; 并行单元共用工作树 &#124; 相互覆盖、无法归因 &#124;
&#124; 候选读取其他候选 &#124; **独立信号退化成改写** &#124;
&#124; 候选阶段偷看发起方倾向 &#124; 同上；候选向倾向收敛，选优失效 &#124;
&#124; 作者自评自收、自我批准 &#124; 同一判断链为缺陷背书 &#124;
&#124; 候选人互投制造独立性 &#124; 被审方兼任判定方，**独立性是假的** &#124;
&#124; 多数票覆盖失败测试 &#124; 偏好压过事实 &#124;
&#124; 全体一致的共同盲区 &#124; 多个相似模型可能共享盲区，一致不等于正确 &#124;
&#124; 只固定分支名 &#124; 评审对象漂移 &#124;
&#124; 冻结后原地替换，或把迟到 commit 算进本轮 &#124; 比较对象漂移，无法复核 &#124;
&#124; final commit 不回归 &#124; 整合缺陷未被发现 &#124;
&#124; 大补丁混合多条主张 &#124; 无法逐条处置，接受与拒绝被绑在一起 &#124;
&#124; 把会话记忆或人脑当状态账 &#124; 接手者无法恢复现场，决定无痕丢失 &#124;
&#124; 只靠自律执行纪律 &#124; **换人或换会话后纪律蒸发** &#124;
&#124; Git 充当授权、预算或副作用账 &#124; 恢复后越权或重复动作 &#124;
&#124; 删除分支/worktree 前不建立持久 ref &#124; commit 变成不可达对象，可能被回收 &#124;
&#124; 复制文件代替整合记录 &#124; 内容存在但来源、取舍和验证对象不明 &#124;
&#124; 「已派工」或「全部返回」当作完成 &#124; **内部动作冒充用户结果** &#124;
&#124; 成功后立即删工作区 &#124; commit 和证据丢失 &#124;
&#124; 静默扩大范围 &#124; 越权副作用无人批准 &#124;
&#124; 伪造完整结果掩盖缺口 &#124; 验收被污染，缺口被当成已完成 &#124;
&#124; 通知失败改写终态 &#124; Delivery 故障污染结果 &#124;
&#124; 人当协调者就跳过隔离与角色分离 &#124; 独立信号退化成改写——**协调者身份不豁免纪律** &#124;

</pre>

#### 已裁定的设计边界

**G-091** · 源 agent-dev-guide.md，L2178–L2188；SHA-256 e2f855ae31e1f4ccc2ddf1a82ceeda920cd1861fd84b6d3729a3d43e5364e209

<pre data-unit="G-091">## 8. 本轮核查裁定

**这一节是隔离区，不是设计菜单。**它存在的唯一理由是**防止再犯**——
一个被推翻的设计如果只是悄悄消失，下一个人会照着同样的推理再走一遍。
所以两条形状规矩：

- **被证伪设计的裁定集中在本节，执行规则不得复活它们**（&#96;amend_schema&#96;、回执仓、候选仓、三道边界一类）。
  &#167;9 的历史取证记录与 &#167;10 的源标题只作来源辨认，不产生执行效力；词面检查须区分规范与历史引用；
- 本节每条必须**「独立观察」与「结论与落点」相邻**——
  只写结论不写观察，读者无从复核；只写观察不写落点，读者不知道它改变了什么。

</pre>

**G-092** · 源 agent-dev-guide.md，L2189–L2205；SHA-256 2d6f60a73d9fa434c12fa77176735cff452c77745e972642470ef776596553a6

<pre data-unit="G-092">### 8.1 六项逐条处置

以下命令均在 luna 自己的 worktree 或兄弟 &#96;investment-app&#96; 运行；不以任务书结论代替复核。

&#124; # &#124; 独立观察 &#124; 结论与落点 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; K1 &#124; &#96;rg &#x27;interrupt\(&#124;Command\(resume=&#x27; investment-backend/app/app&#96;；实际锚见 &#167;4.3 &#124; 出向和入向原语都接受业务值；删去平台自造的固定修订 schema，直接绑定产品 Interaction &#124;
&#124; K2 &#124; 同一 &#96;session_id → thread_id&#96;，同一 checkpointer 上 &#96;Command(resume=value)&#96; &#124; 原地恢复同一 Attempt；只有旧 Attempt 终态、重试或另一次执行才新建 Attempt &#124;
&#124; K3 &#124; 宿主 &#96;sudo -n -l&#96; 返回 &#96;NOPASSWD: ALL&#96;；历史取证还记录 docker 与可写 remote &#124; 同凭据域里的额外签名存储不能鉴别人和 agent；批准证据必须来自执行域外身份/服务 &#124;
&#124; K4 &#124; &#96;git branch -vv&#96; 仅 master 有 upstream；全部参与分支是本地 worktree &#124; Agent 产物以本地 commit 冻结和取件，不设计额外 push 中转作为前提 &#124;
&#124; K5 &#124; &#96;git ls-remote --tags origin&#96; 只有 &#96;2.0.0&#96; 与 &#96;pre-architecture-v2-final-20260813&#96;，本地另有轮次标签 &#124; 当前轮次发布/冻结不依赖远端 tag；换网络 key 不能控制本地 merge 或工作区写入 &#124;
&#124; K6 &#124; K3–K5 显示待保护动作没有经过所设网络路径 &#124; 撤销把三项旁路设施组合成安全架构的结论；逐条动作沿真实路径设置服务端强制点 &#124;

远端 heads 在复核时为 &#96;cursor/kimi/luna/master/opus/qwen&#96; 六个同 SHA 分支；该事实只说明远端形状，
不证明任何身份或发布授权。&#96;sudo&#96; 与远端命令在受限沙箱内最初分别因 no-new-privileges 和 DNS 失败，
随后在宿主只读复核成功；两组结果不能混写成同一执行环境。

</pre>

**G-093** · 源 agent-dev-guide.md，L2206–L2214；SHA-256 e68500042c8476049eec294a651105974524e838be014b011c8265ae51584372

<pre data-unit="G-093">### 8.2 保留与撤销

保留：唯一内核、&#96;dev.change/1&#96;、五家 Agent Profile、确定性 router/orchestrator、权力表的“动作 + principal +
强制点”形状、工单、独占/干净/基线供给、Task/Attempt 投影、S/R 等效、比较上下文字段（不另立对象）、三维粒度、
E0–E4 证据等级、T0 成本上界、绕过的覆盖边界、四层验证、逐节迁移与删除门。

撤销：把人登记为执行器；把部署形态误命名成另一类 Profile；把自由 resume 原语扩成平台级编辑协议；
人介入后默认新开 Attempt；以及任何没有位于真实动作路径、却被宣称能强制授权或发布的旁路设计。

</pre>

**G-094** · 源 agent-dev-guide.md，L2215–L2234；SHA-256 bbcf6fd91a65e2bfe3494eba4b007a61f5152e8061e10e2df8cfb34d7f6a0b39

<pre data-unit="G-094">### 8.3 本次补吸收明确不采用的旧主张

冲突以底稿为准；只吸收成立的机制与证据纪律，不把相邻的旧结论一并恢复。

&#124; 旧主张 &#124; 本文处置与依据 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;agent-dev-refact&#96;：已有凭据即批准、当前不用建任何边界、单 principal 无需区分 &#124; **不采用**。技术可写不等于动作获批；&#167;4.2 H5、&#167;4.4 的身份与实际写路径强制仍成立 &#124;
&#124; 人自己写下一版就必须换 Attempt &#124; **不采用这个触发条件**。人的内容归属保留；执行是否延续按 &#167;4.3 checkpoint 和终态判，不按作者类型判 &#124;
&#124; 旧稿的固定编辑字段表与协议、介入后默认另开执行 &#124; **不采用**。自由中断/恢复原语与产品 Interaction 已有绑定；未经真实需求不另造内核语义 &#124;
&#124; 把两种部署形式登记成两套 Profile；把人登记为执行器 &#124; **不采用**。唯一产品运行时、Task Profile/Agent Profile 正交；人是 requester/principal 或内容贡献者 &#124;
&#124; 旧表把 H5 当作直接从等待写成功的边 &#124; **不采用**。批准具体 Side Effect，再经合法排队、执行、验收和终态提交 &#124;
&#124; 旧表将取证/脚本/调用命令的存在当作当前已运行能力 &#124; **不采用**。保留历史版本与未验证范围；现状按 &#167;5.8 与 &#167;5.13 重核 &#124;
&#124; 旧 R0–R5/S1 排期以及迁出多个目标文件的蓝图 &#124; **不采用为现行路线**。目标顺序保留 &#167;7.1 G0–G5；只保留相容的迁移、等效和删除条件 &#124;
&#124; 强制每个方案必须删掉至少一部分，不接受“都需要” &#124; **部分采用**。保留“应检验必要性、允许更少机制”的问题，不预定必有可删项；必要性也须凭证据判 &#124;
&#124; “没有 Attempt 完成就绝不可能 Task 成功”的概括 &#124; **不提升为内核不变量**。本文只约束开发链路候选须验收，不能从场景样例推全产品的充要条件 &#124;
&#124; 旧稿的历史状态、provider/model 表、经验计数可直接当今天事实 &#124; **不采用**。作为指定版本的记录保存，不自动升为本次实测或当前路由配置 &#124;

原稿各自“以本文为准”的页眉、独立文档存在理由、已过期归档状态也不继承其规范效力；
相容的背景、风险与方法已进正文，历史措辞只在来源索引中辨认。

</pre>

### specs/runtime.md（N）

依次给持久责任、角色/Profile、工单/路由、内核到开发载体的映射；控制面依赖由前到后。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 持久责任与组件 | 跨进程仍须成立的四账、组件责任及通用/专用界线在此；SDK 私有细节排除。 | G-009, G-016, D-003, D-004 |
| 角色与派工契约 | 输入是任务类型、执行能力及角色关系；批准权本体另见 authority，历史五家取值留记录。 | G-017, G-018, G-026, G-019, G-020 |
| 状态和载体投影 | 解释现有内核对象如何映射开发载体，不能修改内核状态或以阶段名再造状态机。 | G-031, G-032, G-039, G-045, G-046 |

#### 持久责任与组件

**G-009** · 源 agent-dev-guide.md，L143–L150；SHA-256 c57080db28748eafe1fd3fa8127ac9691474ca808ca05f6480008961b0581d44

<pre data-unit="G-009">### 1.2 四本账与单一权威写入面

预算、幂等、副作用和证据必须跨 run、跨进程死亡仍然正确，因此权威记录落 PostgreSQL；
外部 harness 的内存、Git 文件或日志只能是输入、Artifact 或可重建投影。产品 &#96;I13&#96; 要求一个
可变事实只有一个权威写入面，产品 &#96;I4&#96; 要求状态集中校验、事件只追加；出处为
&#96;request-lifecycle.md @ ed0b5136:444-483&#96;。当前实现已有幂等与副作用，预算与证据仍缺，
这只是 &#96;development-plan.md @ ed0b5136:97-108&#96; 的现状，不得写成目标已完成。

</pre>

**G-016** · 源 agent-dev-guide.md，L237–L254；SHA-256 66e651c3a757505f7fbca46df9264324092db8bdc0601cc2c7b8af2e650efcf1

<pre data-unit="G-016">### 2.1 确定性组件与适配层

&#124; 名称 &#124; 性质 &#124; 唯一职责 &#124; 不得做什么 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;router&#96; &#124; 确定性代码 &#124; 由持久化字段与版本化策略产生 &#96;decide / ask / refuse&#96; 和 RouteDecision &#124; 不让模型直接选路线 &#124;
&#124; &#96;orchestrator&#96; &#124; 确定性代码 &#124; 合法推进状态、派发、收集、观测、回退和停止 &#124; 不评稿、不裁决内容 &#124;
&#124; &#96;interaction service&#96; &#124; application service &#124; 绑定 Task/状态版本/受众，鉴别响应者，一次性恢复 &#124; 不自造另一套任务状态 &#124;
&#124; &#96;validator&#96; &#124; 确定性代码 &#124; 按冻结 Task Profile 跑机械验收并声明覆盖 &#124; 不把判不了写成通过 &#124;
&#124; &#96;executor adapter&#96; &#124; 适配层 &#124; 调用某 Agent Profile 对应的 SDK/CLI，收集该粒度能得到的事件 &#124; 不扩大能力、预算或数据面 &#124;
&#124; &#96;principal channel&#96; &#124; 适配层 &#124; 把 Interaction 送达正确人并取得经鉴别响应 &#124; 不把通知送达当批准成立 &#124;

router 和 orchestrator 都不是 agent 角色；过渡期由人运行脚本只是传输欠账。
模型若参与分类，只能输出固定 schema、无工具、低预算的建议和证据；
⚠ **分类节点的产出形状是「&#167;2.5 那四条风险判据各自命中与否 + 证据」**，
由确定性规则表据此判 tier——**模型不给 tier，只给四条的命中证据**；确定性规则不能唯一落一条合法路线时，
结果必须是 &#96;ask&#96; 或 &#96;refuse&#96;，不得默认落“通用”。这延续产品 &#96;F-DISPATCH-03&#96; 与 constraints A2–A4，
并避免路由自身成为第三个自由 Agent。

</pre>

**D-003** · 源 development-plan.md，L24–L35；SHA-256 1f3498e3a3dea5e5681b639d5280bcb6f285065b60e2dc28db95af55dc9a296a

<pre data-unit="D-003">## 智能体分两部分

&#124; &#124; 通用部分 &#124; 专用部分 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 内容 &#124; 执行编排：轮次、隔离、中断恢复、审批、工具协议 &#124; 领域：提示、工具绑定、权限、memory policy、领域约束 &#124;
&#124; 载体 &#124; 执行运行时 + &#91;&#96;round-protocol.md&#96;](protocol/round-protocol.md) &#124; &#96;AgentProfile&#96; &#124;
&#124; 纪律 &#124; 隔离、三阶段、提案包构造、评审协议、重叠分歧判据 &#124; 零证据即失败、citation 只回同源、结论可复现 &#124;

**两部分都必须有纪律**，不存在&quot;通用部分不需要约束&quot;。

新增一个业务智能体，**优先是新增一份 Profile，而不是 fork 一套代码**。

</pre>

**D-004** · 源 development-plan.md，L36–L43；SHA-256 ddf38efb8dd6ffa95ee3ee232c72b2c394395dfb8cee0a4ffc5d225a28332b1e

<pre data-unit="D-004">### 四本账是两部分共用的地基

预算、幂等、副作用、证据四本账**不属于任何一侧，且必须落 PostgreSQL**。

判据：**跨 run、或跨进程死亡仍须正确的不变量，必须由存储承担。**
任何把账放在执行进程本地的方案（含外部 harness 自带的存储）都不满足——
投资研究跑在多 worker 上，进程可被杀。

</pre>

#### 角色与派工契约

**G-017** · 源 agent-dev-guide.md，L255–L268；SHA-256 d4fd6175d2bbb992c417d5469299a867e549d69d044e656acf8e23899a4e37b3

<pre data-unit="G-017">### 2.2 内容角色

&#124; 角色 &#124; 职责 &#124; 冲突限制 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;proposer&#96; &#124; 独立产出候选 &#124; 提案冻结前不可见其他候选 &#124;
&#124; &#96;reviewer&#96; &#124; 按冻结标准比较全部候选 &#124; 必须声明自己也是候选作者的利益冲突 &#124;
&#124; &#96;arbiter&#96; &#124; 定基座、逐条吸收、处置异议 &#124; 不兼 orchestrator；票数不是事实依据 &#124;
&#124; &#96;objector&#96; &#124; 只核自己主张是否被误读 &#124; 不代替 acceptor 评整稿 &#124;
&#124; &#96;acceptor&#96; &#124; 按冻结标准独立验收 &#124; 不得是 arbiter 或基座作者 &#124;
&#124; &#96;publisher&#96; &#124; 在批准后执行发布 Attempt &#124; 不能自己授予发布权限 &#124;

角色分离以 round-protocol“⑤ 验收 与 ⑥ 确认”为准，本文 &#167;3.19 给出操作算法。
这些角色在产品运行时里是 Attempt 的 &#96;kind&#96; 或 principal 行为，不新增内核对象。

</pre>

**G-018** · 源 agent-dev-guide.md，L269–L292；SHA-256 f4efd211f757caa6f9109cacc574d9a29844baf1c45a725016dfaad31253d346

<pre data-unit="G-018">### 2.3 Task Profile 与 Agent Profile

&#96;dev.change/1&#96; 至少固定：目标、允许路径、基线 commit、带版本锚的只读输入、tier、执行者集合、
逐条 acceptance、最终路径、能力与副作用边界、预算和停止策略。它决定输入/输出/验收的契约。

Agent Profile 至少登记：&#96;harness&#96;、&#96;provider&#96;、&#96;model&#96; 与是否钉定、&#96;dispatch&#96;、
&#96;observability&#96;、&#96;enforcement&#96;、&#96;sandbox&#96;、&#96;workspace_isolation&#96;、&#96;roles_allowed&#96;、支持的 Task Profile。
它决定某次 Attempt 能被怎样调用、观察和限制。人登记在 principal 表，只有 channel 与授权关系，
没有 harness、执行粒度或执行角色。

Agent Profile 的字段值必须有探针或配置证据。字段非空只证明“填了”，不证明填对；未知值留空并标 ⚠，
不得从产品名或界面推断模型。静态登记集合与自动路由候选集分开：&#96;dispatch = manual&#96; 的执行器可以登记，
但没有审计桥接时不得被自动路由选中。

**独立性折算不得用单一 vendor 标签。**同一个厂牌下可以是不同 harness、不同模型；
不同厂牌也可能共用同一内核。所以分组要看 &#96;(provider, harness, model)&#96; 三者，
而不是「几家公司」——把四个执行者数成「四路独立信号」，是本项目已经踩过的形状：
其中两家同厂不同产品，共用多少 harness 内核**至今未知**。

⚠ 按处置记录，本条**只作观察值，不作硬规则**：单轮数据不足以定权重。
可以据它**降低**对「多家一致」的采信，**不得**据它给出一个折算系数当判据。
**「多家说法一致」不等于「多路独立信号」**——这一句现在就成立，
与折算算法是否成熟无关。

</pre>

**G-026** · 源 agent-dev-guide.md，L548–L586；SHA-256 ca702ff8bddc29ee4b0b3395a511fbafbf969db20d212866bac3c82993c58ee4

<pre data-unit="G-026">### 2.11 派工契约、角色补充与隔离的诚实边界

**派工契约（Work Unit）与工单（&#167;2.4）是两层**：工单冻结整个 Task，派工契约冻结**一个执行者
那一份**。至少固定：

&#96;&#96;&#96;text
work_unit_id, parent_task_id, owner        objective, included_scope, excluded_scope
input_refs, baseline_commits, allowed_context
expected_output, acceptance, evidence      permissions, budget, deadline, stop_condition
dependencies                               checkpoint_location
workspace_path, exclusive_branch, forbidden_write_paths
output_namespace, publication_target, integrator            result_status
&#96;&#96;&#96;

⚠ **&#96;workspace_path&#96;、&#96;exclusive_branch&#96;、&#96;forbidden_write_paths&#96; 必须在派工时写死，
且对每个执行者唯一。**&#96;forbidden_write_paths&#96; 至少包括：人的主 checkout、其他执行者的
worktree、共享发布面，以及非协调者不得写的单写者文件（如 &#96;handoff.md&#96;）。
**这三个字段不是描述性说明，是 &#167;3.10 写入前门禁的判定输入——派工时缺任一字段，
执行者不得开始写。**

派工**只能收窄**父 Task。父预算覆盖所有 Work Unit、Attempt、工具、评审和改进。
多个 Work Unit **不得同时权威写同一可变事实**；先划分所有权，无法划分则串行。

**人在这套模型里有三个角色，不可互相替代：**

1. **请求提出者**——提出有边界的工作，给原始意图、范围和验收期望；
2. **内容贡献者**——亲自实施部分工作，与助手交替推进；内容以本人署名的 Artifact 或 Interaction 响应进入系统，**不据此把人登记为 Agent Profile 或产品 Attempt 执行器**；
3. **principal**——批准、取消、追加成本和终审验收的最终权力。**第三种助手不能替代。**

⚠ 助手不得自我批准；**人也不得把终审责任外包给助手后不再复核**（&#167;4.5 责任归属表）。

⚠ **候选隔离目前靠纪律，不靠机制。**候选冻结前只读同一任务包、基线和各自获准上下文，
不得读其他候选、**发起方偏好**或预设解法；看到已有答案之后产出的内容属于评审或改进，
**不再是独立候选**。但——

&gt; **脚本化产生候选目前没有可用工具**（曾有的 &#96;parallel-proposals.py&#96; 已于 2026-09-06 删除：
&gt; 三轮一次没用过、真实模型调用从未验证、只覆盖 codex 系执行者）。在此之前，
&gt; **隔离靠纪律，而且无法事后证明某一轮真的独立。不得据此声称隔离由机制保证。**

</pre>

**G-019** · 源 agent-dev-guide.md，L293–L346；SHA-256 c5358a52d7cd89d987be6c449a662d99f28ecbd9734ff00504690cfbf9fc7590

<pre data-unit="G-019">### 2.4 &#96;dev.change/1&#96; 工单

工单是 Artifact，不是 Task 状态。推荐形状：

&#96;&#96;&#96;toml
&#91;order]
id = &quot;...&quot;
tier = &quot;T0&#124;T1&#124;T2&quot;
artifact_state = &quot;DRAFT&#124;FROZEN&quot;
goal = &quot;...&quot;
paths = &#91;&quot;...&quot;]
baseline_commit = &quot;...&quot;
read_only_inputs = &#91;&quot;path@commit&quot;]
final_paths = &#91;&quot;...&quot;]
acceptance = &#91;&quot;A1 ...&quot;]
route_proposal = &quot;...&quot;
route_effective = &quot;...&quot;
route_delta = &quot;...&quot;

&#91;executors]
intake_author = &quot;...&quot;
proposers = &#91;&quot;...&quot;]
arbiter = &quot;...&quot;
acceptor = &quot;...&quot;

&#91;workspace]
write_actors = 1
review_needed = true
submodule_plan = &quot;...&quot;

&#91;budget]
observation_window_rule = &quot;...&quot;
max_rollbacks = 2
&#96;&#96;&#96;

**别名登记（不并存多个真源）**：&#96;DEV&#96;、&#96;DEV_ROUND&#96;、&#96;DEVELOPMENT&#96;、&#96;dev.change.v1&#96;
**均为 &#96;dev.change&#96; 的别名**，正式 id 取 &#96;dev.change&#96;。⚠ 不登记别名，下一轮就会有人
对着别名设计接口。

工单还须固定两项常被漏掉的：&#96;privacy&#96;——⚠ **财务数据任务在 NO ZDR 核实前不得跑**；
&#96;budget.observation_window_rule&#96;——观察窗 &#96;W&#96; 取**已交付各家用时的中位数**，
不取最长也不取平均；&#96;freshness&#96;——&#96;baseline_commit&#96; 固定，**基线移动即新 Task**。

⚠ **&#96;acceptance&#96; 里的硬门禁、质量偏好和待定项必须分开列，不得混成一串。**
硬门禁不过就是不过；质量偏好只用于同分决胜；待定项要么在冻结前定掉，要么显式标为不判。
三者混写会让「偏好没满足」被当成「门禁没过」，或者反过来。
工单还应固定 &#96;tenant&#96;、&#96;agent_profile&#96; 或其选择策略、&#96;approval_points&#96;、&#96;deadline&#96;、
&#96;stop_condition&#96;、&#96;writable_roots&#96;、&#96;output_namespace&#96;、&#96;publication_target&#96; 与 &#96;integrator_id&#96;
——最后四项是 &#167;3.6 命名空间纪律在工单上的落点。

&#96;intake_author&#96; 若替请求者起草意图与验收，同票不得再任 proposer、arbiter 或 acceptor；请求者直接给出并
冻结验收时可记 requester。&#96;route_proposal&#96; 保存建议与证据，&#96;route_effective&#96; 保存实际决定，
&#96;route_delta&#96; 保存人改了什么，三者不可合成一段自然语言。

</pre>

**G-020** · 源 agent-dev-guide.md，L347–L353；SHA-256 eab2e84cad7e5a721a9da65844b5be76eb9afdfbc9562dfaa00636b879785532

<pre data-unit="G-020">### 2.5 路由只读可判字段

路由成本判断不读题目散文，至少从以下字段提取 &#96;matched_features&#96;：写者数、提案者数、只读输入是否钉版本、
是否依赖/续接、是否触及权威路径、是否有副作用、是否要求审计。风险档位则严格按 round-protocol：
不可逆、权威层、已知对立、判据未定任一命中就是 T2；多文件或多仓且方向无争议为 T1；其余才可能 T0。
风险档位不能反过来充当成本证据，否则是循环论证。

</pre>

#### 状态和载体投影

**G-031** · 源 agent-dev-guide.md，L704–L740；SHA-256 6af778ffbd07bed1ddfebcc113999de3e1a6bfcef77f35c09dc6d895b5989fa3

<pre data-unit="G-031">### 3.3 Attempt 与状态投影

开发产物只投影到内核，不造新状态：

&#124; 开发事实 &#124; Task 投影 &#124; Attempt 投影 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 工单可靠创建 &#124; &#96;RECEIVED → VALIDATING&#96; &#124; — &#124;
&#124; 路由需关键输入 &#124; &#96;VALIDATING → WAITING → VALIDATING&#96; &#124; — &#124;
&#124; 受理后发现不可执行或越权 &#124; &#96;VALIDATING → REJECTED&#96; &#124; 不创建执行 &#124;
&#124; 有效取消请求使非终态安全收敛 &#124; 按内核允许边进入 &#96;CANCELLED&#96; &#124; 在途 Attempt 撤权、盘点副作用后进入 &#96;CANCELLED&#96;；未创建则无 Attempt &#124;
&#124; 契约冻结且可执行 &#124; &#96;VALIDATING → QUEUED&#96; &#124; &#96;CREATED&#96; &#124;
&#124; 首个执行取得有效租约 &#124; &#96;QUEUED → RUNNING&#96; &#124; &#96;CREATED → RUNNING&#96; &#124;
&#124; 某家提交候选 &#124; 保持 &#96;RUNNING&#96; &#124; &#96;RUNNING → COMPLETED&#96;；只表示有候选 &#124;
&#124; 某家逾期 &#124; 仍有路可走则保持 &#96;RUNNING&#96; &#124; &#96;→ FAILED(timeout)&#96; &#124;
&#124; Attempt 预算耗尽 &#124; 按契约等待、重排或失败 &#124; &#96;→ BUDGET_EXCEEDED&#96; &#124;
&#124; 执行中等待输入 &#124; 无其他路可走才 &#96;RUNNING → WAITING&#96; &#124; 可 &#96;RUNNING → WAITING&#96; &#124;
&#124; 同一执行从 checkpoint 续跑 &#124; Task 先按内核合法回边 &#124; 同一 Attempt &#96;WAITING → RUNNING&#96; &#124;
&#124; 评审/异议/验收打回 &#124; 保持 &#96;RUNNING&#96; 或回 &#96;QUEUED&#96; &#124; 新 Attempt；旧终态不重开 &#124;
&#124; 不可逆发布待批 &#124; &#96;RUNNING → WAITING(APPROVAL)&#96; &#124; publisher &#96;CREATED&#96; &#124;
&#124; 批准后发布完成 &#124; &#96;WAITING → QUEUED → RUNNING → SUCCEEDED&#96; &#124; publisher &#96;→ RUNNING → COMPLETED&#96; &#124;
&#124; 已无获准成功路径 &#124; &#96;→ FAILED&#96; &#124; 相关 Attempt 均终态 &#124;

**这张表不是说明，是判据。**「只投影不造新状态」要成立，必须**三件同时满足**，
缺一条这个主张就没被证明：

1. **没有一个新状态词**——表右两列出现的词全部来自内核合法转换表；
2. **没有一条内核之外的边**——每一格的转换都能在内核那张表里找到；
3. **内核的每个状态都有落点**——反过来查：内核有而本表没出现的状态，
   要么说明流程还没覆盖到，要么说明表漏了。

⚠ **第 3 条最容易被跳过**，因为前两条查「本表有没有越界」是顺着看，
第 3 条查「内核有没有被漏」要倒着看。**只做前两条会得到一个自洽但不完整的映射。**

Artifact 可以有草稿、冻结、陈旧、被替代等版本属性；这些不是 Task/Attempt 状态。
评审、裁决、异议和验收均可作为 typed Artifact，由 Attempt 的 &#96;output_artifacts&#96; 引用；若要把它写入
内核合同，须先按规范修订程序确认这是类型细化而不是对象扩充。

</pre>

**G-032** · 源 agent-dev-guide.md，L741–L766；SHA-256 c2f804993f3cafd33dd851db0a0e9804a0e9cc70a2e0ab01eff2c002e0d1d23e

<pre data-unit="G-032">### 3.4 T0/T1/T2 不是三套状态机

三档共享同一工单 schema、状态机和发布门，只改变 guard、必需 Artifact 和 Attempt 组：

&#124; tier &#124; 执行形态 &#124; 独立信号 &#124; 人工门 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; T0 &#124; 做 → 独立验收 → 确认 &#124; 一个产出、一个独立验收 &#124; 开工可由已批准窄包自动决定；不可逆发布仍由人确认 &#124;
&#124; T1 &#124; 单稿 → 独立评审 → 验收 → 确认 &#124; 一稿、一评、一验 &#124; 工单冻结与开工可合成一次明确确认 &#124;
&#124; T2 &#124; round-protocol 七环节 &#124; N 份隔离候选、互评、裁决、异议、独立验收 &#124; 题目/判据冻结与参与方/路线确认分开 &#124;

产物命名、候选冻结、处置表和验收方算法见 &#167;3.19–&#167;3.22，来源为现行 round-protocol。状态脚本从 commit 反推，工作区
不参与判定；空参与方不是“完成”；脚本首次增加判据时先与人工结论对照，并列出未检查范围。

⚠ **档位是风险轴，「建不建 Git 工作区」是载体轴，两者正交，不可互相推导。**
载体判据是另一组：不改持久文件、单 Attempt 单会话可完成、不需要 worktree/回滚/diff/固定源码版本、
外部副作用为零或已有独立副作用账、验收可直接针对结构化结果完成——**全部满足才可不建工作区**；
多文件改动、跨步骤跨会话跨执行者跨仓、需要 checkpoint/回滚/diff/固定候选、需要 fan-out、
以代码或可复现实验交付、错误代价要求独立评审——**任一命中就要建**。

⚠ **「不建工作区」只决定载体，不降低授权、证据、预算或验收。**
载体判定必须可审计：**不能为省供给成本把复杂任务塞进无状态 Attempt，也不能为形式统一
给一次只读问数建立空仓库**。执行中发现判据不成立时，停止当前 Attempt 并保存 checkpoint 后升级，
**执行者不得私自在获准工作区之外建仓**。

⚠ 把载体轴写成档位轴，与 &#167;2.5「风险档位不能反过来充当成本证据」是同一种循环。

</pre>

**G-039** · 源 agent-dev-guide.md，L969–L987；SHA-256 e5748c8ace2b65e23a294b63ccaa5585ff25a9746847ab6a454914cf0d6bb484

<pre data-unit="G-039">### 3.11 候选状态机

&#96;&#96;&#96;text
DRAFT → FROZEN(commit/digest) → SUBMITTED
      → {SELECTED &#124; REJECTED &#124; STALE &#124; SUPERSEDED}
      → INTEGRATED（仅被采用部分） → VERIFIED(final commit)
      → PUBLISHED → RETAINED / GARBAGE_COLLECTED
&#96;&#96;&#96;

⚠ **这些是 Artifact 的版本属性，不是 Task/Attempt 状态**（&#167;3.3 末段）。七条纪律：

- &#96;DRAFT&#96; 可改，但只存在于 owner 可写面，**不能被称为候选完成**；
- &#96;FROZEN&#96; 后**不得原地替换**，修订产生新 commit/digest 并用 &#96;supersedes&#96; 关联；
- &#96;SELECTED&#96; 只表示进入整合，**不表示已发布**；
- &#96;INTEGRATED&#96; 必须记录**实际吸收的 commit/patch/Artifact**，不能只写「已吸收」；
- &#96;VERIFIED&#96; 只针对 final commit；
- &#96;PUBLISHED&#96; 必须记录发布目标、发布者、版本和时间；
- 清理前必须证明**所需对象仍有可达 ref 或已进入持久 Artifact**。

</pre>

**G-045** · 源 agent-dev-guide.md，L1093–L1113；SHA-256 7f63cbae59d6107cdc55039fc16ebd21c00dbe48abd56b1fbb33e0bc08316df6

<pre data-unit="G-045">### 3.17 内核对象 ↔ 开发载体对照

⚠ **「只有一套状态机」不是口号，这张表是它的证明**：开发侧每个产物都对应一个内核对象，
且 Task 状态**一律推导**，不另立。

&#124; 内核对象 &#124; 开发侧载体（手工态） &#124; 产品侧载体（服务态） &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; Task &#124; 工单所属的那件事 &#124; &#96;task&#96; 行 &#124;
&#124; **Task 状态** &#124; ⚠ **纯推导**：由 Attempt 产物、裁定记录、受保护 tag 反推（&#167;3.3） &#124; &#96;state&#96;（Event 投影） &#124;
&#124; Attempt &#124; 一家在一个环节的一次交付（一个 commit） &#124; &#96;attempt&#96; 行 &#124;
&#124; Interaction &#124; 收件箱条目 + 落盘回执 &#124; &#96;interaction&#96; 行 + &#96;resume_token&#96; &#124;
&#124; Artifact &#124; 工单、候选、评审、裁决稿、异议、验收稿（按 commit 冻结） &#124; 对象存储 + &#96;artifact&#96; 行 &#124;
&#124; Event &#124; git 提交历史 + 裁定记录（只追加） &#124; &#96;event&#96; 行（只追加） &#124;
&#124; Side Effect &#124; 写共享最终路径、push 主线（&#167;4.2 H5 门） &#124; 副作用账 &#124;
&#124; Delivery &#124; 主线上的最终稿 + 检视 worktree &#124; &#96;F-DELIVERY-*&#96; &#124;
&#124; RouteDecision &#124; 工单 &#96;route_effective&#96; &#124; &#96;route_decision&#96; 行 &#124;
&#124; 预算 &#124; 观察窗规则、轮次上限、回退上限 &#124; 预算账（&#96;I10&#96;） &#124;

⚠ **左右两列换的是载体，不是语义。**&#167;5.3 的等效判据就是在这张表上做的：
S 层比对象与边，R 层比一次执行的序列。

</pre>

**G-046** · 源 agent-dev-guide.md，L1114–L1130；SHA-256 4f2f1aded33af1984c612bcbe9e4a0e87e5b1a087a8394dde07bea17a53f4085

<pre data-unit="G-046">### 3.18 状态脚本的硬要求

脚本「从产物反推、判据即命令、只生成不执行」这三条是对的，要补的是**判错时必须停**：

&#124; 要求 &#124; 违反会怎样 &#124;
&#124; --- &#124; --- &#124;
&#124; 输出 **Task 状态（内核状态词）+ 当前环节 + 各 Attempt 状态**；⚠ **环节是投影，状态是判据** &#124; 只输出「当前环节」，就把投影当成了真源 &#124;
&#124; 工单里若有 &#96;status&#96; 声明字段，**降为人读缓存并由脚本校验**：⚠ **推导值 ≠ 声明值即报错退出** &#124; 声明与产物漂移，而没有人会发现 &#124;
&#124; 每次状态推导**同时输出「上一状态 → 本状态」**；⚠ **边不在内核合法转换表内即报错退出** &#124; 只校验状态点会漏掉非法边——这是真实抓到过的漏检形态（&#167;5.3 规则 6） &#124;
&#124; 分发前对照 &#96;roles_allowed&#96; 与角色分离禁令，**冲突即拒绝并给 reason** &#124; 角色冲突要到验收时才暴露，那时已经晚了 &#124;
&#124; ⚠ **每条判定声明覆盖范围**（P4）：输出里「查了什么、没查什么」与结论并列；**零命中要能区分「真的没有」与「没查到」** &#124; 门禁在边界上给假答案，而它看起来是绿的 &#124;
&#124; 按工单 &#96;tier&#96; 读取对应 guard 表与必需产物表，**不写死某一档** &#124; 轻档位没有可执行形态，等于不存在（&#167;0.0 第 6 条） &#124;

状态推导还须读取 orchestrator 单写的执行事件：产物未出现只能说明“尚无交付”，
不能区分未派发、执行中、崩溃、失联或超时。无法程序分发的执行器应输出明确投喂说明，
并记录实际的 &#96;dispatch_event&#96;；生成了一条命令不等于该命令已经执行。

</pre>

### specs/executor.md（N）

先定租用边界，再比能力和 Port，再连接两腿恢复/部署与可验证接口；把 guide 原先分处两章的执行和中断放在一起。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 租用边界与能力 | 执行原语的租/建选择、SDK 范围和版本限定；历史读数不据此升格为今天实测。 | G-021, G-022, D-005 |
| Port 与适配门 | 签名、能力探针和前置条件必须相邻；不收领域业务签名或具体派工进度。 | G-023, G-024 |
| 两腿恢复与部署 | 同一执行器在进程生命周期中的恢复差异和接口落实矩阵；批准权限公式由 authority 持有。 | G-025, G-054, G-071 |

#### 租用边界与能力

**G-021** · 源 agent-dev-guide.md，L354–L407；SHA-256 560a93f2d895995d98c5d1459b5ad15a61cadff793bf8561e9cd19a0be8f934b

<pre data-unit="G-021">### 2.6 执行层：租用什么、自建什么

constraints A4 是「执行层租用不自建」。它的准确含义不是「什么都用现成的」，而是：
**租 agent loop，自建业务控制面。**loop（模型调用、工具循环、会话推进）用官方 SDK；
Task/Attempt/四本账/验收/授权是本平台的，不 fork runtime、不改 agent loop、
不复制协议类型、不 deep import 内部包、不维护私有 wire fork。

⚠ **先钉现状：生产环境里现在没有任何 agent 在跑。**本节结论一律处于 &#96;defined&#96;，
不是 &#96;wired&#96;，更不是 &#96;runtime-verified&#96;。可复核的休眠登记表在
&#96;investment-backend/app/tests/test_dormant_capabilities.py&#96;——它按
「锚点还在吗 + 还休眠着吗」两个方向立判据，**比 grep 计数稳**：
&#96;:154&#96; &#96;RunBudget&#96; 生产未接线、&#96;:182&#96; Attempt/Invocation 未落库、
&#96;:208&#96; &#96;CancelRunCommand&#96; 无 HTTP 端点、&#96;:240&#96; &#96;AgentProfile&#96; 只被记录不被执行。
开关 &#96;AGENT_V4_TRAFFIC_ENABLED&#96; 与 &#96;AGENT_PILOT_ENABLED&#96; 在 bundle 里都是 &#96;&#x27;false&#x27;&#96;。
**读本节任何一条都要带着这个前提，不得把目标态写成现状**——这正是 &#167;5.2 推论 2
「拿休眠代码当能力证据」那个错误的机制来源。

**专用 Agent 的构建方法固定，具体 Profile 不冻结**：Profile/patch + 插件组合；
每个工具逐条声明输入/输出 schema 与数据、副作用边界；dry-plan 只产生可审计 Plan
Artifact，query 才执行；结果经显式 &#96;submit_result&#96; 提交，未提交不算 Attempt 完成，
提交只产生候选，validator 过 &#96;F-ACCEPT-*&#96; 后 Task 才可成功；两条 worker 凭据互斥。
**不冻结某个财务 Profile 的字段、工具清单、数据集或金标准**——内核要求首项工作以真实
输入确认契约，而当前业务数据源仍为空；未有真实数据和评测前，任何具体表都是 ⚠ 假设。

**OpenClaw：借机制，不转向。**它的 Gateway 是渠道接入与控制面，两层「路由」都不读用户
语义——channel/account/peer binding 是确定性映射并返回 &#96;matchedBy&#96;；provider/model route
选 runtime 且显式 plugin runtime 默认 fail-closed。可借的机制与本项目落点：确定性 binding +
命中规则 + 拒绝 reason code 存进 RouteDecision；agent/session/runtime/model 四者正交；
capability 支持与显式路线 fail-closed；host 先备好上下文、runtime 只跑 loop；来源路由与
回复交付分离。**不整体转向**：它「一 Gateway 一信任域」、多租户靠每租户一个仍属实验性的
cell，主档是 SQLite 不是共享 PostgreSQL，本身是 TypeScript/Node CLI；引入会重复现有控制面。
**其危险默认更不能继承**：sandbox 默认关闭、&#96;tools.profile: full&#96; 等于无限制、
&#96;/elevated full&#96; 可跳过 exec approval。明确不借：Gateway 当业务主档、channel binding 冒充
语义路由、本地会话存储取代 PostgreSQL、默认 host 执行、那三个逃生门、运行中静默跨 runtime
重放，以及把 Gateway 放进 BFF 与 FastAPI 之间。

**哪些路不该交给模型自己找。**输入输出与失败形态已经明确的确定性步骤，编排权留在
控制面；租用 loop 处理确实需要模型探索工具与方案的部分。把已知流程改成聊天循环，
不自动增加能力，却会降低可解释性。应用编排可以用 LangGraph 原语实现，
“执行层租用”不等于“不自建业务编排”，也不等于“重定义库的协议”。

**执行路线是否更好，分三层判断**：架构分工合理、当前生产成熟、目标门禁通过，是三种结论。
第一种不能替后两种背书。执行器接入的 Gate 0 至少须逐条验证下面三项；
这是执行器 spike，**不是 &#167;7.1 的 G0 协议修复步骤**。

&#124; Gate 0 条件 &#124; 验收与证据 &#124; 失败后的退路 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 两条腿的事件能忠实投影到 Event/timeline &#124; 事件映射不丢 Task/Attempt/turn 的关键归属，覆盖 &#96;I4&#96;、&#96;F-EXEC-02&#96; &#124; 该腿不接产品链路；补公开 SDK 或由上层换腿 &#124;
&#124; 专业腿确有质量收益或至少不劣 &#124; 同一真实输入和金标准，对照 Codex 单腿结构化输出；标准、预算与样本先冻结 &#124; 不维持没有收益的专业路线；上层改用通过门禁的路线，Port 不变 &#124;
&#124; worker 内进程模型稳定 &#124; 启动失败率、常驻/峰值内存、僵尸进程达到预先约定阈值 &#124; 不塞入现有通用 worker；满足 constraints 的拆分条件才拆同一 Backend 下的专业运行角色，否则不接入 &#124;

⚠ **三项都仍是待验条件，本次没有运行 SDK、模型或部署实验。**阈值和金标准未冻结时，
结论为不可判，不填“通过”。失败退路是公开 SDK 路线或约束修订，不是恢复自研通用 loop。

</pre>

**G-022** · 源 agent-dev-guide.md，L408–L432；SHA-256 d6e35274097f62492a8b7df4084d45cae005e0e45659c381e3d143a56dcc0c48

<pre data-unit="G-022">### 2.7 两个官方 SDK：两个轴、非对称能力

**专业构建能力与生产控制能力是两个独立轴，不能合成一个「谁更强」。**

事实钉在 Codex &#96;7d6f808b&#96;、DeepSeek Harness &#96;dd6322d6&#96;。
**升级钉版必须重跑锚点，不得沿用本表结论。**

&#124; 轴 / 能力 &#124; Codex Python SDK &#124; DeepSeek Harness Python SDK &#124; 对本平台的结论 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; 专业 Agent 组装 &#124; 进程级配置为主，无 preset 一等概念 &#124; preset 是一目录一 &#96;agent.cordis.yml&#96;，按会话组合 tools/prompt/skills/persona，一进程可跑多种 agent（&#96;packages/preset/README.md:12&#96;） &#124; Harness 适合专用 Agent；**这不表示其生产控制面已合格** &#124;
&#124; 生命周期 &#124; thread start/resume/list/read/fork/archive、turn interrupt（&#96;sdk/python/src/openai_codex/client.py:430-469&#96;、&#96;:641-646&#96;） &#124; wire 只有 initialize、session/prompt、shutdown；事件对 runtime 全量且未过滤 &#124; Port 必须**表达缺失**，锚 &#96;F-EXEC-02/05&#96;、&#96;F-INTERACT-*&#96; &#124;
&#124; 逐 Turn 结果 &#124; run/turn 有 turn id、流与 &#96;output_schema&#96; &#124; &#96;SessionPromptResult.messageId&#96; 只标识**入队的用户消息**，「does not identify a later assistant message, turn ending, or prompt result」（&#96;packages/sdk/protocol/README.md:52&#96;） &#124; Harness 缺完成归属，**不能伪装 &#96;COMPLETED&#96;** &#124;
&#124; 取消 / 关闭 &#124; 有 turn interrupt；thread 可 archive &#124; 「**No cancel or session-close methods** — a client abandons a turn by closing the runtime process」（同上 &#96;:115&#96;） &#124; 只能用进程级补法，**代价写入 Attempt** &#124;
&#124; 交互批准 &#124; 可接 approval handler，**但默认自动接受**：&#96;_default_approval_handler&#96; 对 &#96;commandExecution&#96; 与 &#96;fileChange&#96; 一律返回 &#96;{&quot;decision&quot;: &quot;accept&quot;}&#96;（&#96;client.py:773-779&#96;） &#124; 「**Server→client requests are a dead capability** — the transport supports them, but the server never sends one」（同上 &#96;:116&#96;） &#124; **Codex headless 必须覆盖默认 handler；Harness 不得声称原生 HITL** &#124;
&#124; provider 协议 &#124; 已钉死 Responses API，&#96;wire_api=&quot;chat&quot;&#96; 明确报错（&#96;codex-rs/model-provider-info/src/lib.rs:57-88&#96;） &#124; 面向 DeepSeek 等自身 adapter 路线 &#124; DeepSeek Chat Completions 经 Codex 需另建翻译代理，**是真实阻抗，不是无成本替代** &#124;
&#124; 系统 Node &#124; 不适用 &#124; wheel 携闭包，SDK 不需系统 Node &#124; ⚠ 内网 PyPI 能否取得 wheel 未验证；**不得复活「缺 Node 阻断」** &#124;

⚠ **这张表是「投喂 vs SDK」问题的证据底座。**它说明两件事：其一，CLI 投喂路径答不了审批
请求不是配置问题——Codex 侧默认就是自动接受，Harness 侧根本收不到请求；其二，
换 SDK 不等于自动获得 HITL，Harness 腿的审批要靠**平台工具网关**，不能靠 runtime 自批。

工具可通过插件注册，参数/输出校验与 policy hook 见
&#96;~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md:7-59&#96;；这支持「不 fork agent loop」，
**不证明多租户授权、取消和恢复已接线**。

</pre>

**D-005** · 源 development-plan.md，L44–L63；SHA-256 cd79e37cec9704b2717f43cfe493ab5666b161c151e4d28a6fc56e8a00a88628

<pre data-unit="D-005">### 执行层租用，不自建

通用部分的执行层采用 Codex 的 Python SDK（&#96;openai-codex&#96;，Apache 2.0）：
不自建轮次生命周期、隔离进程、中断恢复、审批协议、工具与沙箱。

**依赖边界严格限定在 SDK，不得直接依赖其 app-server 裸协议。**依据实测：

&#124; 层 &#124; 近 3 个月提交 &#124; 破坏性变更 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;app-server-protocol&#96;（裸协议） &#124; 280 次 &#124; 12 处 &#124;
&#124; &#96;sdk/python&#96;（门面） &#124; **10 次** &#124; **0** &#124;

执行层须通过 Port 隔离——理由不是&quot;将来可能要换&quot;，而是：有该接口才能用 fake
执行器测试纪律层（隔离是否生效、吸收有没有留处置记录），否则每次测试都要真起
harness 并需凭据。

**harness 只给执行原语，不给运作纪律**：N 路隔离、轮次、中断恢复、审批、工具、
沙箱它有；三阶段可见性、提案包构造、评审协议、吸收处置记录、重叠分歧判据——
这些在 &#91;&#96;round-protocol.md&#96;](protocol/round-protocol.md)，必须自建。

</pre>

#### Port 与适配门

**G-023** · 源 agent-dev-guide.md，L433–L482；SHA-256 39308e39f9835449230564aaf4c73abe64c0e169185e88a853e08b16e1fb2abe

<pre data-unit="G-023">### 2.8 统一执行 Port 与三态能力探针

application 层只依赖中性 Port；签名里不得出现 ticker、portfolio、财报等领域词（A4/A5）：

&#96;&#96;&#96;python
class AgentExecutorPort(Protocol):
    async def capabilities(self) -&gt; ExecutorCapabilities: ...
    async def start(self, request: ExecutionRequest) -&gt; ExecutionBinding: ...
    async def resume(self, binding: ExecutionBinding, value: ExecutionInput) -&gt; None: ...
    async def cancel(self, binding: ExecutionBinding, reason: CancelReason) -&gt; CancelReceipt: ...
    async def events(self, binding: ExecutionBinding,
                     cursor: ExecutionCursor &#124; None) -&gt; AsyncIterator&#91;ExecutionEvent]: ...
    async def inspect(self, binding: ExecutionBinding) -&gt; ExecutionSnapshot: ...
    async def close(self, binding: ExecutionBinding) -&gt; None: ...
    async def submit_result(self, binding: ExecutionBinding,
                            payload: ResultEnvelope) -&gt; SubmissionReceipt: ...
&#96;&#96;&#96;

**&#96;submit_result&#96; 在签名里，不是 Adapter 私货。**结果必须经一个显式提交动作进入平台，
未提交不算 Attempt 完成，提交成功也**只产生候选**——validator 说了才算。放进 Adapter 内部
会让两条腿在「什么算完成」上出现两套语义。⚠ **Harness SDK 当前不存在这个方法**，
它是我们自建的约定，不是租来的能力。

**Port 存在的第一理由是可测性，不是「将来可能换执行器」。**有了它，纪律层可以用
&#96;FakeAgentWorker&#96; 跑完整状态机、超时、取消与恢复路径，不必每次真起 runtime、真发凭据、
真花模型钱。「将来可能换」是**收益**，可测性是**现在就成立**的理由——本仓
&#96;ToolExecutionPort&#96; 生产引用为 0，正说明没有可测载体时 Port 会停在 &#96;defined&#96;。

&#96;ExecutionBinding&#96; 必须可序列化并落 PostgreSQL：**SDK 侧的 thread/session id 不是 Task 的
真源**（&#96;I13&#96;），进程重启后要能只读持久载体接着做。

**能力探针是三态，不是布尔：**

&#124; 状态 &#124; 含义 &#124; 调度规则 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;available&#96; &#124; 钉版 SDK 与 runtime 已证明原生保真支持 &#124; 仍须过 Attempt 准入 &#124;
&#124; &#96;explicit_unsupported&#96; &#124; SDK 明确不支持且不得降级 &#124; **fail-closed**；换路线必须新建 RouteDecision/Attempt &#124;
&#124; &#96;implicit_fallback&#96; &#124; 有替代语义但会损失能力或改变边界 &#124; 只有冻结政策明确允许且**代价落账**才可用；不得静默 &#124;

⚠ **布尔 &#96;true/false&#96; 会把「明确不支持」和「悄悄降级」压成同一种事实**，
于是 &#96;AT-09&#96;、&#96;AT-14&#96;、&#96;AT-20&#96; 无法证明。探针必须带 runtime/SDK 版本、证据与探测时间；
dispatch 以所需能力集合做**硬过滤**，不能等 Adapter 内部临场降级。

**Port 的 DTO 和 Adapter 边界。**通用 DTO 只承载 &#96;attempt_id&#96;、版本化 &#96;profile_ref&#96;、
workspace/input Artifact 引用、完成合同引用、预算预留引用、trusted security context 引用、
deadline，以及 opaque provider session/turn identity；实际字段由实施时的契约测试钉定。
Adapter 只做公开 SDK 映射、binding 持久化、事件与错误码归一、teardown。
它不路由、不授权、不验收，不拥有四本账或 Task 终态；thread/session 不能升成业务主档。
纪律层用 Fake 执行器验证状态与失败路径，真实 SDK 只在集成及运行门禁中验证。

</pre>

**G-024** · 源 agent-dev-guide.md，L483–L510；SHA-256 dc29499e912b2ba60f17e3978fb0580b29e7f05b06f6f0ea8cb8d564a9b23443

<pre data-unit="G-024">### 2.9 Harness 腿的前置门禁与过渡补法

门禁卡的是「本平台的状态机能否管住 Harness」，**不是「能否用 Harness 建专业 Agent」**。
专业腿进入自动路由前，必须由上游在正式 SDK 同步实现并测试以下公开合同：

- session start/resume/read/close，按 cursor 读取 session events；
- turn start/read/steer/cancel，stable turn id，**逐 Turn completion correlation**；
- per-session preset 选择与逐 Turn 结构化输出合同；
- **模型不可见、不可改的 trusted context**：Task/Attempt、tenant/actor、授权策略版本、
  允许能力、数据集绑定、证据策略、deadline；
- async 且已证明不阻塞的 Python 面、cancel durable end、crash/restart/malformed-wire 测试、
  版本化 capability query。

门禁未过时**只允许显式、受限的过渡路线**，四条，且代价必须落账：

1. 取消时先持久化意图并 revoke Attempt 网关令牌，再按 teardown ladder 杀 runtime 进程；
2. 每个专业 Profile 必须提供显式 &#96;submit_result&#96; 工具；未调用不算 &#96;COMPLETED&#96;，
   调用成功只产生候选，仍由独立 validator 判 &#96;F-ACCEPT-*&#96;；
3. 高风险工具**不交给 runtime 自批**，全部经平台工具网关按审批分层决定；
4. 等待/恢复**创建新 Attempt**，从持久 Artifact 和现场快照恢复，不伪造原 Session 续跑。

代价：进程级取消粒度粗、上下文重建耗时、可能丢失未提交中间推理、重复计算增加预算、
不能原地 resume。相关项探针标 &#96;implicit_fallback&#96;，**不得标 &#96;available&#96;**。
若完成合同需要保真的原 Attempt 恢复或逐 Turn HITL，该路线保持 &#96;explicit_unsupported&#96;。

⚠ **注意这条与 &#167;4.3 的关系**：&#96;dev.change&#96; 走的是 LangGraph checkpointer，**原地 resume 可用**
（&#167;4.3 已实测）。本节说的是 Harness 腿——**两条腿的恢复语义不同，不可互相外推**。

</pre>

#### 两腿恢复与部署

**G-025** · 源 agent-dev-guide.md，L511–L547；SHA-256 08de66f97522bb15be6b6b4575bd75f686ef307b75515c51da6553a05757265f

<pre data-unit="G-025">### 2.10 双 runtime 的部署、进程与恢复

先按运行角色分 API、通用执行 worker、专业执行 worker。两类 worker 使用**互斥的服务身份、
队列、网络与凭据**，不能在同一进程里把两套 key 都做成环境变量。

当前部署有四条硬阻断，都是现状不是建议：

&#124; 阻断 &#124; 可复跑锚点 &#124; 必须补的门禁 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; worker 无模型 API egress &#124; &#96;deployment/bundle/30-network-policies.yaml:221-268&#96; 只放 PostgreSQL/Redis/RabbitMQ、Casdoor、Knowledge；&#96;rg -n &#x27;ipBlock&#x27; 该文件&#96; 零命中 &#124; 精确目的地/代理 egress，**在 Calico 环境实际验证**，锚 &#96;I3/I12&#96;、&#96;AT-05&#96; &#124;
&#124; root filesystem 只读 &#124; &#96;deployment/bundle/20-runtime.yaml:361-373&#96; &#124; &#96;CODEX_HOME&#96;、&#96;DSH_HOME&#96;、workspace、snapshot staging 分离到有配额的可写卷 &#124;
&#124; worker 内存上限 768Mi &#124; &#96;deployment/bundle/20-runtime.yaml:354-373&#96; &#124; 双 runtime 峰值与 prefork 并发实测后定 requests/limits &#124;
&#124; 模型配置/凭据未进 bundle &#124; &#96;deployment/bundle/00-prerequisites.yaml:106-119&#96;；&#96;rg -n &#x27;AGENT_PILOT_LLM_&#x27; bundle&#96; 零命中 &#124; 代理 endpoint、短 TTL token issuer、Secret/ServiceAccount、启动 fail-closed &#124;

⚠ **KIND 默认不执行 NetworkPolicy。**第一条阻断的「包级验证」只在生产 Calico 下成立；
开发用的 KIND 集群里策略写了也不生效，**会让人误以为出口已经封死**。

⚠ **这条进程纪律有死者，不是设计洁癖。**Celery worker 默认 prefork 数继承节点 CPU，
本仓曾因此起了 12 个子进程直接打爆 768Mi；模板已把并发钉成
&#96;CELERY_WORKER_CONCURRENCY: &#x27;2&#x27;&#96;。**在这个内存上限下再往每个子进程里塞一个 SDK runtime，
是同一个坑的第二次。**

SDK 进程纪律：Celery prefork **之后**按 Attempt 或受控槽创建 SDK client/runtime；
不得在 parent 初始化后跨 fork 共享 fd、锁、event loop 或子进程句柄；owner 记 PID/进程组与
binding。关闭按 &#96;stop intake → revoke token → SDK cancel/close → 限时 TERM 进程组 →
限时 KILL → reap → 核对副作用账&#96;，每步写证据。
⚠ Codex async 客户端内部把同步调用包到 worker thread（&#96;async_client.py:161-183,293-295&#96;），
**并发与 teardown 必须做负载/故障注入，不能由 &#96;async&#96; 关键字推断安全**。

可恢复执行现场按 &#96;attempt_id + runtime_version + profile_version + digest&#96; 内容寻址写对象
存储；PostgreSQL 只存引用与摘要。restore 在新可写面校验摘要、授权、fencing、
runtime/Profile 兼容性后继续，**不把 executor 本地目录当真源**。

**恢复必须有界**：Profile 固定 &#96;max_attempts&#96;；同一
&#96;failure_fingerprint + profile_version + runtime_version&#96; 连续失败达阈值就**熔断该版本路线**，
停止自动恢复并转 Interaction。Profile 升级**不得替历史 Task 静默解锁**。

</pre>

**G-054** · 源 agent-dev-guide.md，L1284–L1346；SHA-256 b8cc0007eee3c2a3672220541b65890fcf00bbe140cf2195b9c991b7a727e133

<pre data-unit="G-054">### 4.3 直接沿用实际中断/恢复原语

当前基座已经提供足够原语：

- &#96;investment-backend/app/app/infrastructure/graph/pilot_graph.py:59-66&#96; 调用
  &#96;interrupt({...})&#96;，出向值就是任意字典；
- &#96;investment-backend/app/app/infrastructure/graph/langgraph_runtime.py:14-21&#96; 用
  &#96;Command(resume=user_input)&#96; 接收任意恢复值；
- &#96;investment-backend/app/app/application/agent/graph_runtime_service.py:14-23&#96; 将同一 &#96;session_id&#96;
  映射为同一 &#96;thread_id&#96;；
- &#96;investment-backend/app/app/tasks/agent_graph.py:106-128&#96; 在同一 thread 配置和 PostgreSQL
  checkpointer 上首次执行或恢复。

**中断恢复在本项目已经端到端跑通**，不只是「库有原语」：

&#124; 层 &#124; 状态 &#124; 取证 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 抽象基类 &#96;GraphRuntimeService.resume&#96; &#124; &#96;raise NotImplementedError(...)&#96; &#124; &#96;graph_runtime_service.py:26-31&#96;——这是**抽象方法的正确写法**，不是功能缺失 &#124;
&#124; 适配器 &#96;LangGraphRuntimeService.resume&#96; &#124; **已实现**：&#96;Command(resume=…)&#96; + 同 &#96;thread_id&#96; &#124; &#96;langgraph_runtime.py:13-21&#96; &#124;
&#124; 端到端 &#124; **通过**：中断 → &#96;resume&#96; → 原地续跑并产生副作用 &#124; &#96;test_graph_runtime_service.py:18-35&#96;，&#96;uv run pytest&#96; → **2 passed** &#124;

⚠ **这一段曾经写反过，教训比结论有用。**先前据抽象基类那行 &#96;NotImplementedError&#96;
断定「端到端未接线」——**错在只读了基类 18 行就停**，没搜谁继承、没搜谁调用、没跑测试。
把「留给实现方的空位」（**接口契约**）读成了「功能缺失」。

&gt; **「打开文件自验」也会失败**：验了，但**验的范围是自己划的**，而范围划错了。
&gt; 这与「没验就下结论」是两种错，**后者好防，前者难防**。

因此实现应把产品 Interaction 的 &#96;question_or_action / audience / expires_at / resume_token_hash /
idempotency_key / consumed_at / resume_target&#96; 绑定到这些原语，字段真源仍是
&#96;request-lifecycle.md @ ed0b5136:247-277&#96;。中断节点返回业务需要的 dict；恢复端鉴别主体、校验
Task 与状态版本、原子消费令牌，然后把经验证的响应作为 &#96;Command(resume=value)&#96; 送回同一 thread。
checkpoint 原地续跑时是同一 Attempt 的 &#96;WAITING → RUNNING&#96;，不因“人给了内容”另开 Attempt。

**&#96;dev.change&#96; 的 H8 具体这样接**（五步，缺一步就会长回自造协议）：

1. 需要人时，adapter 调库的 &#96;interrupt(payload)&#96;；**payload 的形状由 Task Profile 的入向约定声明**，
   不写进内核绑定字段——形状归 Profile，字段归内核，这样扩展不必动内核；
2. 人的答复经 **principal channel** 到达后，adapter 调 &#96;Command(resume=答复)&#96;，
   **同一 &#96;thread_id&#96; 原地续跑**；
3. **这不是新 Attempt，也不建新 Task。**内核 Attempt 状态机走 &#96;WAITING → RUNNING&#96;；
4. **只有**当答复实质改变了目标、口径、授权范围或 Profile 版本，才按内核建带 &#96;supersedes&#96;
   的新 Task——**四个条件之外的答复一律回原 Task**；
5. 过期、异键、跨 Task 的恢复**由库与内核既有校验拒绝**，不在 Profile 层再造一套。

⚠ **「需要载荷」这个需求，是被「恢复必须开新 Attempt」自己造出来的。**
库的恢复不换 Attempt，载荷就是 &#96;resume&#96; 的那个值。取消掉那个不该有的执行边界，
围绕它长出来的一整支设计（载荷、schema、过期校验、Task 级暂停）就一并消失。

若未来业务确需结构化编辑，先拿一个真实 Task Profile 的前端 payload、拒收用例和迁移数据立规范修订；
不要从自由 &#96;resume&#96; 值反推一套平台级 patch/replace 协议。修改目标、授权范围或 Profile 版本仍按产品
“终态、刷新与重新处理”建立新 Task；普通澄清只恢复原 Task。

**按问询类型展示信息，避免轻问题背重合同。**补缺失参数只展示具体问题与必要上下文；
批准某个产物则展示其版本、证据等级、允许改动范围和各选项后果；依赖/资源/外部事件按已有合同。
业务内容放在 Profile 的 payload 内，不另造内核字段。

人指出错误、由 agent 继续修订时，把反馈作为恢复值交回同一执行；
人亲自提供新 Artifact 版本时，保存人的作者归属并把引用绑定到经验证的响应。
**谁写下一版不决定是否新开 Attempt**：可原地续跑就仍是原 Attempt；旧执行已终态、
需重试或换执行器才新开；目标/授权/Profile 改变则按合同新建 Task。
这保留“人可以贡献内容”，排除旧稿“人写新版本必然换 Attempt”的额外执行边界。

</pre>

**G-071** · 源 agent-dev-guide.md，L1721–L1746；SHA-256 0e36721939b612bf5fd1379cb29e6761e0d6d5e3c5898d0d86283ef88f7dc718

<pre data-unit="G-071">### 5.6 &#96;F-EXEC-*&#96; / &#96;F-INTERACT-*&#96; 双腿落地矩阵

状态按 &#167;2.8 的三态探针标注。⚠ **探针词与「已支持 / 需补法 / 当前缺失」的对应固定如下，
读表一律按右列判定，不得只看探针词：**

&#124; 探针状态 &#124; 三档判定 &#124; 含义 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;available&#96; &#124; **已支持** &#124; SDK 原语直接满足该条义务；平台仍需归一并记账 &#124;
&#124; &#96;implicit_fallback&#96; &#124; **需补法** &#124; SDK 有近似原语但不满足义务，平台/Adapter 必须补齐 &#124;
&#124; &#96;explicit_unsupported&#96; &#124; **当前缺失** &#124; 协议显式否定该能力，须走上游门禁或过渡补法 &#124;

⚠ **不得把 SDK 原语冒充产品能力**：把 &#96;implicit_fallback&#96; 读成「已支持」是一次真实的措辞坑。
矩阵只投影内核的稳定 ID，不重新定义其义务；证据锚点一律注明出自哪个仓——
⚠ **不得拿本仓自己的代码当租用 SDK 的能力证据**（真实案例：某候选以本仓休眠的
&#96;AgentProfile.permits_tool&#96; 佐证 Harness 腿工具门）。

&#124; 功能 ID &#124; Codex 腿 &#124; Harness 腿 &#124; 需补法与验收 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;F-EXEC-01&#96; &#124; &#96;available&#96;：sandbox/approval/tool 面可配置；**但 headless 默认 approval handler 会自动 accept** &#124; &#96;implicit_fallback&#96;：**进程内**工具门是真的（&#96;adding-a-tool.md:59&#96; 的单调 deny，preset 按会话组合 tools/prompt/skills）；但 wire 无可信逐 Task context，也无 per-session preset 选择 &#124; Attempt 准入取 Task/Profile/当前批准的交集；**Codex 必须覆盖默认 handler**；Harness 工具网关逐次验权。&#96;AT-05&#96; &#124;
&#124; &#96;F-EXEC-02&#96; &#124; &#96;available&#96;：thread/turn/event 可关联，仍需归一并写平台账 &#124; &#96;implicit_fallback&#96;：&#96;sessionId&#96; 可作 Attempt 级关联的**输入**，但只是来源标签，不自动完成唯一 binding、全 runtime 事件过滤、子 session 递归归属与证据持久化 &#124; 平台强制 binding、过滤、递归登记、补齐版本并持久化。⚠ **逐 Turn completion correlation 另属上游门禁**（&#96;SessionPromptResult.messageId&#96; 不标识 turn 结束或结果，&#96;protocol/README.md:52&#96;）；需要逐 Turn 保真的路线**在 dispatch 前 fail-closed** &#124;
&#124; &#96;F-EXEC-03&#96; &#124; &#96;available&#96;：approval callback 可逐动作接平台复核，**默认实现不可用** &#124; &#96;explicit_unsupported&#96;：**server→client request 不发生**（&#96;protocol/README.md:116&#96;） &#124; 高风险动作**只经工具网关**；审批绑定动作/产物哈希并落账。&#96;AT-05/07/12&#96; &#124;

⚠ **这张矩阵是 &#167;2.7 那张表在内核功能 ID 上的投影。**两张表口径必须一致：
&#96;F-EXEC-03&#96; 的 Harness 腿判 &#96;explicit_unsupported&#96;，依据就是 &#167;2.7「交互批准」那一行。
**升级钉版时两张表必须同时重跑。**

</pre>

### specs/authority.md（N）

从主体和权力到强制点，再到动作门和凭据传播；读者能逐层检查具体动作是否越权。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 主体与权力 | 谁有权做什么、权限怎样相交；谁何时点击按钮是 review 的步骤。 | G-052, G-053, G-056 |
| 边界与动作门 | 身份鉴别、强制点、三门与审批档位必须在同一信任模型中解释；不得把约定写成强制机制。 | G-055, G-057, G-058 |
| 执行中禁止与凭据传播 | Attempt 内限制及子进程/跨腿令牌不得绕过前述边界；工具调用具体步骤留 execution。 | G-060, G-064 |

#### 主体与权力

**G-052** · 源 agent-dev-guide.md，L1249–L1260；SHA-256 fec09b54a2a0f8d403d0b028016a720abc1af1951a26076d2c68ea508e120ad6

<pre data-unit="G-052">### 4.1 人的位置

人可以同时是 requester 与某些权力的 principal，但不因此获得执行角色。人的稳定职责是：

- 给出或确认目标、边界与验收；
- 回答绑定到自己身份的 Interaction；
- 批准省事方向裁定、预算/资源变化和不可逆 Side Effect；
- 对最终交付负责并可推翻先前裁定。

“由人触发脚本”不等于“人是 orchestrator”；“由人把固定指令粘到 GUI”是尚未自动化的传输动作，
应记 &#96;dispatch_event&#96; 并计成本，不新增权力行。

</pre>

**G-053** · 源 agent-dev-guide.md，L1261–L1283；SHA-256 53723c879ad30a6265dd629513785c7793745cea111c149863b9bf85e3f15548

<pre data-unit="G-053">### 4.2 权力表

&#124; 行 &#124; 受控动作或合法边 &#124; principal &#124; 默认 &#124; 强制要求 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; H1 &#124; 工单 Artifact 冻结；验证期 &#96;WAITING → VALIDATING&#96; &#124; owner &#124; 无；T0 由已批准任务类包承担 &#124; validator 对照冻结 digest &#124;
&#124; H2 &#124; &#96;VALIDATING → QUEUED&#96; 开工 &#124; owner &#124; 仅 T0 且 router &#96;decide&#96; &#124; orchestrator 无有效决定不分发 &#124;
&#124; H3 &#124; 降档、跳环节、缩窗或免除参与方后恢复 &#124; owner &#124; 无 &#124; 裁定追加留痕，批准与目标版本绑定 &#124;
&#124; H4 &#124; 冻结授权内追加预算或资源后恢复 &#124; owner &#124; 无 &#124; 超出授权范围必须新建 Task，不在原 Task 扩权 &#124;
&#124; H5 &#124; 不可逆 Side Effect；最终 &#96;RUNNING → SUCCEEDED&#96; &#124; owner &#124; 无 &#124; 执行动作与批准分离，凭据/服务端校验不可由 executor 绕过 &#124;
&#124; H6 &#124; 推翻裁定或改判冻结标准 &#124; owner &#124; 无 &#124; 追加新记录，不覆盖原判断；标准变更重新验收 &#124;
&#124; H7 &#124; 非终态安全收敛到 &#96;CANCELLED&#96; &#124; owner &#124; 无 &#124; 先落取消意图、提高 fencing、盘点副作用 &#124;
&#124; H8 &#124; 回答本 Task 的 &#96;WAITING(INPUT)&#96; &#124; requester &#124; 无 &#124; interaction service 鉴别主体、Task、状态版本和一次性令牌 &#124;

**H7 是表内唯一不要求仓外锚的行**，这是有意的：取消属**失败安全方向**——
伪造一条「取消」只会让流程停下来等人，不会让任何东西被发布出去。
其余各行朝的是「放行」，伪造即造成不可逆后果，所以强制点必须在 agent 够不着的地方。
⚠ 代价在**恢复**而不在取消本身：不知道已经产生了哪些副作用就不知道要回滚什么，
所以取消必须附**已产生副作用清单**，缺清单的取消不生效。

表外没有未分类的 APPROVAL。&#96;DEPENDENCY / RESOURCE / EXTERNAL&#96; 按产品 WAITING 规则处理；普通 INPUT
只有在歧义实质改变结果、权限、成本或风险时才问。H5 批准的是执行 Side Effect，不是把 Task 直接从
&#96;WAITING&#96; 写成成功；内核没有该捷径。

</pre>

**G-056** · 源 agent-dev-guide.md，L1383–L1429；SHA-256 750d96ef703bfae647e5b78da9dd2bb56333c53afed0926b1aaf9da6b28c0a5f

<pre data-unit="G-056">### 4.5 权限公式与只有 principal 能做的动作

有效权限是交集，不是并集：

&#96;&#96;&#96;text
Attempt 内的执行
  有效权限 = 请求方授权 ∩ Task Profile ∩ Agent Profile
           ∩ sandbox / tool policy ∩ 当前批准 ∩ 有效租约

不在 Attempt 内的开发操作
  有效权限 = principal 授权 ∩ 仓库与环境策略 ∩ 当前批准
&#96;&#96;&#96;

⚠ **租约是条件项，不是无条件交集。**不隶属任何 Attempt 的开发操作没有租约，
**不能因此在公式上算作无权限**。两条路径的差别只在约束来源，不在约束强度。

⚠ **授权不跨场景延续。**在 A 分支批准过推送，不等于 B 分支也可以；Task A 的授权不延续到
Task B；一次批准的破坏性动作**不构成下次的默许**。批准绑定 Task、动作、目标、版本和有效期。

下列动作**只有 principal 能做**，且各有留痕义务。协调职责不带来其中任何一项：

&#124; 动作 &#124; 必须留下 &#124;
&#124; --- &#124; --- &#124;
&#124; 批准高风险或不可逆动作（推送、合并、发布、迁移、删远端资产） &#124; 批准人、动作、目标、版本、有效期 &#124;
&#124; 取消 Task 或中止在途执行 &#124; 取消依据、已产生副作用、需补偿项、需保留对象 &#124;
&#124; 追加预算或提高并行度 &#124; 原上限、新上限、依据 &#124;
&#124; 最终验收终审 &#124; 所验 final commit、逐条判定、门禁原始输出位置 &#124;
&#124; 降档（把完整选优改成最小选优或单路） &#124; 降档依据、被省略的环节、承担的风险 &#124;
&#124; 推翻已有判定或改判冻结标准 &#124; 原判断、错在哪、新判断、原标准与原始失败输出 &#124;

⚠ **「我看着行」不是依据。依据要能被半年后的自己复核。**

**是否简化流程的裁量权在 principal，不在执行者。**执行者不得自行把完整选优降为单路，
也不得通过询问自己派出的 subagent 或取得多数同意来制造批准——**自我批准禁令在任何轮次
都成立**。

责任归属决定了这条禁令的理由：

&#124; &#124; 谁负责 &#124;
&#124; --- &#124; --- &#124;
&#124; 决定做什么、不做什么 &#124; **人** &#124;
&#124; 决定怎么做（在约束内） &#124; 执行者 &#124;
&#124; 产出是否符合验收标准 &#124; 未参与实施的一方；无人时由**人** &#124;
&#124; 上线后出问题 &#124; **人**——agent 不承担后果 &#124;

⚠ **agent 不得自我批准，不是因为不信任它的判断，是因为它不承担后果。**

</pre>

#### 边界与动作门

**G-055** · 源 agent-dev-guide.md，L1347–L1382；SHA-256 d1a10a8971a7dfbfd58fe61a977920a23200ab558577eee75539ee7b771bd5ab

<pre data-unit="G-055">### 4.4 身份、批准与强制点

批准成立必须同时回答：谁、批准哪个 Task/版本、批准哪项动作、何时过期、是否已原子消费。
通知文件或聊天回复只证明“有文本”，不证明身份；executor 可修改的脚本、hook、权限位也不是对它的
安全边界。强制点必须落在 executor 够不着的服务端身份、凭据作用域、工具网关或生产写入口。

⚠ **取证结论的措辞必须限定到「这台宿主、这个身份、这个时刻」。**
下面这些是**单机观测**，不是平台事实：换一台机器、换一个跑 agent 的用户，
结论就可能翻转。写成「agent 有 root 权限」是把一次观测外推成属性；
正确写法是「**在本宿主上、以该用户运行时**，agent 与人共享同一凭据域」。
边界的表述也据此绑定到**凭据域是否共享**，而不绑定到「是不是 root」这个偶然事实。

**同期取证的另外三行现状事实**（同样绑定「这台宿主、这个身份、这个时刻」）：
本机**没有 GPG 密钥**，已有 tag 全部未签名——从零设计，无兼容包袱；
&#96;~/.ssh/id_rsa&#96; 对主仓**有写权限**，即任何 agent 都能以本机身份 push 分支与 tag；
人的第二台机器是 Windows 工作站，**其上也运行本地 agent**，
若凭据管理器缓存了推送凭据，它**不需要口令就能 push**。

基线取证显示宿主用户 &#96;zym&#96; 有免密 sudo，且当时能对两个主 remote 做 push dry-run；见
&#96;forensics.md @ ed0b5136:18-45&#96;。本轮在非沙箱宿主重跑 &#96;sudo -n -l&#96; 仍得到
&#96;(ALL) NOPASSWD: ALL&#96;。所以本机签名、仓内公钥表、本机 hook 与只读文件权限都只能当卫生检查或审计，
不能证明 Agent 无法伪造批准或绕过发布。

目标产品态应优先复用已有认证主体、授权服务、一次性 Interaction 恢复和 Side Effect 网关；若某条写路径
绕过这些组件，就先画出真实动作路径并在路径上设门，不增加旁路存储来制造安全感。当前手工轮次的
人类确认仍是治理记录，证据等级应诚实标为 &#96;reported&#96;，不得声称身份已 &#96;attested&#96;。

**威胁模型要同时覆盖三件事**：伪造肯定的批准；没有批准仍能直接写交付面；
人的设备上另一个 agent 借缓存凭据代做批准。需要防的是共享凭据下的越权代劳，
不以执行者是否“恶意”作为前提。批准证据的鉴别与 Side Effect 入口的强制是两道不同的检查。

拥有凭据只说明有技术能力，不等于批准了某个 Task 的具体动作；只有一位 principal
也不免除 H5。远端保护只管经过远端的写路径，本地发布要在本地动作的可信边界上另作判断。
身份鉴别服务不可达、批准过期或配置漂移时失败关闭，并区分查询失败、未批准与策略拒绝。
边界可以防伪造/绕过，不能证明人读懂了对象；误签仍靠对象展示、独立验收与 L3 抽检降低。

</pre>

**G-057** · 源 agent-dev-guide.md，L1430–L1451；SHA-256 01aa04c2ad66c62165716539bc7ada4b72dd19996e324e9925258f9ec333cbfb

<pre data-unit="G-057">### 4.6 三道正交门

运行时的有效能力必须**同时**通过三道独立门；三者不能互相代替：

&#124; 门 &#124; 决定 &#124; 硬规则 &#124; 合同锚点 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; **Tool Policy** &#124; 哪些工具存在 &#124; deny 优先；allow 非空时未列工具默认拒绝 &#124; &#96;F-EXEC-01/03&#96;、&#96;I3&#96;、A2 &#124;
&#124; **Execution Scope** &#124; 在哪里、对什么资源执行 &#124; workspace/data/network/tenant/actor 逐次收窄，**不能由模型自报** &#124; &#96;F-EXEC-01/03/05&#96;、&#96;I3/I12/I14&#96; &#124;
&#124; **Approval Policy** &#124; 此次具体动作谁可批准 &#124; 批准不能扩出前两门；缺失、过期或漂移一律 fail-closed &#124; &#96;F-EXEC-03&#96;、&#96;I3/I9/I12&#96;、&#96;AT-05/12/14&#96; &#124;

⚠ **Tool Policy 是硬停，不是 prompt 建议。**被拒绝的工具应当**不存在**：会话组装层在发给
模型前从 schema/catalog 移除；工具网关层即使收到伪造名称也再次 deny。前者减少诱导和误调用，
后者防绕过；**任何「工具仍在但描述为禁止」的方案都不满足 &#96;F-EXEC-01&#96;**。
可复核的机制参考：&#96;~/repo/deepseek-harness/docs/cookbook/adding-a-tool.md:57-59&#96; 的
&#96;tools/pre-execute&#96; allow/deny/ask 与 &#96;ctx.tools.guard()&#96; 单调 deny；
&#96;~/repo/openclaw/docs/gateway/config-tools.md&#96; 的 deny-wins 语义。**这里只借机制。**

⚠ **这三道门与 &#167;5.1 的三个粒度字段是不同的轴**：粒度字段说「运行时**能看见/能拦在**哪」，
三道门说「一次动作**要过几关**」。&#96;enforcement = outer-only&#96; 时，Tool Policy 与
Execution Scope 只能落在进程外层，Approval Policy 只能事后审计——**此时必须标 &#96;audit_after&#96;，
不得声称事中拦截**。

</pre>

**G-058** · 源 agent-dev-guide.md，L1452–L1480；SHA-256 fc2ca15040559f54581ea681d9a3e552b9f3fef901a06a8987b82bc984dac8df

<pre data-unit="G-058">### 4.7 四档审批

审批策略固定四档，具体动作由 Task/Profile 风险分类映射：

&#124; 档 &#124; 适用 &#124; 决策者 &#124; 纪律 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;auto-deny&#96; &#124; 未声明、越权、不可满足门禁 &#124; 确定性 policy &#124; 直接拒绝并留 reason code &#124;
&#124; &#96;auto-allow&#96; &#124; 冻结政策明确的低风险、可逆、范围内动作 &#124; 确定性 policy &#124; 仍逐次验权、记预算/副作用 &#124;
&#124; &#96;llm-review&#96; &#124; 只需语义检查且政策明确允许委托的中风险动作 &#124; 独立受限 reviewer &#124; **必须落账**模型/版本/输入摘要/判定/理由；否则等于产出者自我批准 &#124;
&#124; &#96;human-approval&#96; &#124; 高风险、不可逆、发布、扩权、追加预算 &#124; principal 经 Interaction &#124; 一次性、短时、精确绑定，**不可转授** &#124;

每份批准绑定 &#96;task/attempt/action/target/policy_version&#96; 与待执行 canonical payload、
计划/diff/Artifact 的内容哈希；**执行前重算，任一字节、目标、权限或版本漂移即作废**。
批准有短 TTL，超时 fail-closed。

⚠ **不得把 Codex 默认 accept 当任何一档批准**（&#96;client.py:773-779&#96;，见 &#167;2.7），
**也不得让生成候选的同一 Agent 充当 &#96;llm-review&#96;**。

⚠ **超时是独立的审计结果与 reason code，不折成 &#96;auto-deny&#96;。**两者行为后果相同
（都不放行、都 fail-closed），**审计含义不同**：&#96;auto-deny&#96; 是策略作出了拒绝判断，
超时是**没有任何人作出判断**。压成同一个 reason code 会污染审计账——
事后无法区分「策略拒绝率上升」和「审批链路卡死」。落账写 &#96;approval_timeout&#96;，
带等待时长与待审对象哈希。

⚠ **四档与 &#167;4.2 权力表是两条正交的轴，不是一张表的两种写法。**权力表回答
「**哪个 principal** 可以走**哪条合法边**」；四档回答「**一次具体动作**经过**什么样的审批
形态**」。&#96;llm-review&#96; 在权力表里没有行，因为它不是 principal 的权力——
⚠ 它是否可用于任何 &#96;auto_policy = 无&#96; 的行，**本文不裁**，登记 &#167;7.4 未决。

</pre>

#### 执行中禁止与凭据传播

**G-060** · 源 agent-dev-guide.md，L1509–L1527；SHA-256 ac740a5514dccc30da7b603d98de13ef312167097b2500adb386201afc2ea0c9

<pre data-unit="G-060">### 4.9 Attempt 内的三条硬禁令

上层路由完、权限收窄之后，Attempt 内还需要**可执行的边界**——抽象声明容易被绕过。
任一条被突破即为越权，按 &#96;I3&#96;、&#96;I10&#96;、&#96;I15&#96; 与 constraints A2/A4 处理：

&#124; # &#124; 禁令 &#124; 具体形态 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; **不得改路由** &#124; 执行器种类在 Attempt 创建时钉死并落账；不得因为「这个单元更像财务」而在 Attempt 内改投另一条腿 &#124;
&#124; 2 &#124; **不得换执行器** &#124; 不得在 Attempt 内自行构造新的 runtime 客户端实例绕开已固定的 Adapter；换腿只能由上层**新建 Attempt** &#124;
&#124; 3 &#124; **不得扩权** &#124; 不得重新注册已被 deny 的工具，**不得把 &#96;human-approval&#96; 降级为执行器默认的自动批准**，不得追加预算 &#124;

⚠ **第 3 条的现实动因见 &#167;2.7**：Codex Python SDK 的默认审批处理器对命令执行与文件改动
一律返回 &#96;accept&#96;，而**该兜底发生在构造函数里**——

&gt; **「忘了传 handler」与「故意选自动批准」在代码里长得一样。**

所以这条**必须由 Adapter 强制显式传入 handler，不能靠纪律**。这是「机制优于自律」
在本文里最具体的一处落点。

</pre>

**G-064** · 源 agent-dev-guide.md，L1605–L1628；SHA-256 fd5c38c21e39456723fb7a964d49222d46692166e4708c8ce1254232590ad754

<pre data-unit="G-064">### 4.13 执行器凭据、子进程与跨腿委派

模型推理经过平台 egress proxy；真实 provider key 只在代理/Secret 边界，
不下发 Codex 或 Harness 执行器进程。Attempt 只取得短 TTL、可撤销的网关令牌，
绑定 &#96;attempt_id + executor + model_allowlist + tenant/actor + budget + deadline&#96;。
取消、失租、预算耗尽或终态立即 revoke；恢复前重新准入，不复用过期令牌。

工具凭据由 host-side gateway 按实际调用解析，不进入 prompt、普通环境回显、checkpoint、
日志或 Artifact。通用 worker 不持有专业数据凭据，专业 worker 不持有通用 provider 凭据。
这落实 &#167;4.6 的 Scope 与 Policy；**只写“两类 worker 互斥”而不管子进程继承，边界仍会漏**。

**spawn 前洗环境。**执行器子进程只继承明确白名单变量，数据库、Redis、消息队列凭据不下发；
白名单是版本化配置，要落账并由测试断言。限写不等于限读，继承父进程全量环境会把业务凭据
暴露给执行器，即使其工作区是只读也不能消除这个问题。

**Adapter 禁止未经上层路由的跨腿委派。**历史 Harness 调查记录了 &#96;subagent-codex&#96; 这类嵌套入口，
可在专业腿内再启通用执行器；⚠ 本次没有重验该 SDK 能力。无论实际插件叫什么，
不得让内部 spawn 绕过已冻结执行器、预算和凭据互斥。确需换腿或跨腿协作，由上层新建
RouteDecision/Attempt，经过正常能力、权限、预算和数据门，不在现有 Attempt 内偷偷造客户端。

父预算覆盖全部 Attempt、Work Unit、工具、评审与改进。Side Effect 用稳定幂等键进入持久账，
保留意图、目标、状态、回执和补偿引用；重试、恢复或取消前先查账，不能从 Git 或进程退出码
猜某项外部动作是否已发生。这些均是执行器接入门禁，不是本次已完成的部署能力。

</pre>

### specs/evidence.md（N）

先定义观测能看到什么，再定义它能证明什么，最后才谈成本和绕过；防止可见性被当成充分证据。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 观测及采信 | 粒度、等级、四级词典与历史使用条件构成证据契约；单次实测全文不冒充契约。 | G-066, G-067, G-073, G-078 |
| 载体与等效 | Git/其它载体各能证明什么以及 S/R 等效边界；验收动作与判据质量另见 review。 | G-069, G-074, G-068 |
| 成本和观察上界 | 只有先知道观测覆盖，才能判路由成本和绕过；保留反例和未归因限制，不推出绝对零绕过。 | G-080, G-081, G-082 |

#### 观测及采信

**G-066** · 源 agent-dev-guide.md，L1631–L1658；SHA-256 08ea4247069a927b07cc715c5d82e47cdff3f4d2c69d8a42699a9564c38a64c9

<pre data-unit="G-066">### 5.1 三个粒度字段

&#124; 字段 &#124; 取值 &#124; 问的问题 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;observability&#96; &#124; &#96;tool.enforced &gt; tool.reported &gt; process &gt; fs-only&#96; &#124; 最细能看到什么 &#124;
&#124; &#96;enforcement&#96; &#124; &#96;tool-level &#124; outer-only&#96; &#124; 能在动作前拦在哪里 &#124;
&#124; &#96;sandbox&#96; &#124; &#96;runtime &#124; self &#124; none&#96; &#124; 隔离环境由谁提供、策略归谁 &#124;

四档 &#96;observability&#96; 各是什么（**从强到弱**，只给排序不给定义，读者无从判自己那家在哪一档）：

&#124; 档 &#124; 运行时看得见什么 &#124; 能不能拦 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;tool.enforced&#96; &#124; **每一次工具调用**，且调用**先经运行时批准**才发生 &#124; **能**，在动作前 &#124;
&#124; &#96;tool.reported&#96; &#124; 每一次工具调用，但是**执行器事后自报**的 &#124; 不能——看见时已经发生了 &#124;
&#124; &#96;process&#96; &#124; 只看得见**进程起没起、产物出没出** &#124; 不能 &#124;
&#124; &#96;fs-only&#96; &#124; 只看得见**文件系统的最终状态** &#124; 不能 &#124;

⚠ **只有 &#96;tool.enforced&#96; 的事件是证据**；&#96;tool.reported&#96; 是**索引**——
可以据它决定「该去重新推导什么」，不能据它下结论。

&#96;dispatch_event&#96; 指**人代运行时执行的一次传输动作**（把指令送到没有程序入口的执行器、
在正确的工作区打开它的界面）。**它不是权力，是欠账**：不占权力表的行，
但**必须可数**，因为成本上界（&#167;6.2）和绕过口径（&#167;6.3）都要数它。

三者不得合成一个“能力等级”。JSONL 工具事件可能细但仍是执行器自报；外层可以观察 argv/stdio 却不能
拦内部系统调用；自带沙箱也不等于运行时控制。&#96;RUNNING&#96; 能否可靠判断首先是执行器 observability 的问题，
不是把 Git 换成数据库就自动解决。

</pre>

**G-067** · 源 agent-dev-guide.md，L1659–L1673；SHA-256 aa6e6389758187aaa3716d98e2b8b1170dba113db81b58f0eb0669b535986dc5

<pre data-unit="G-067">### 5.2 证据等级与采信规则

&#124; 等级 &#124; 来源 &#124; 可支持的断言 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; E0 &#96;ASSERTED&#96; &#124; executor/principal 自述或事后推断 &#124; 待验证主张 &#124;
&#124; E1 &#96;REDERIVED&#96; &#124; validator 从冻结 Artifact 重算 diff/hash/test &#124; 仅重算覆盖内的结果 &#124;
&#124; E2 &#96;PROCESS_OBSERVED&#96; &#124; 外层 argv/stdio/exit + E1 &#124; 进程被调用及其外部结果 &#124;
&#124; E3 &#96;TOOL_OBSERVED&#96; &#124; 运行时工具网关事件 + E1 &#124; 经网关的调用与策略检查 &#124;
&#124; E4 &#96;EXTERNAL_AUTHORITY&#96; &#124; 执行域外受保护审计/服务端事实 &#124; 指定身份或外部 Side Effect &#124;

采信等级取 &#96;min(来源等级, 可见上限, 隔离强度, 验收独立性, 覆盖)&#96;，任一未知就降级，不取平均。
&#96;tool.reported&#96; 事件是重算索引，不是结论；commit、diff、测试、锚点与远端状态由 validator 独立重算。
覆盖声明必须同时写 checked 与 not_checked；零命中只有在输入集合成功枚举时才能判 pass，否则是
&#96;UNKNOWN&#96;。这落实 round-protocol“判据自身的质量”。

</pre>

**G-073** · 源 agent-dev-guide.md，L1774–L1803；SHA-256 fb7b5f7f72fb837bc160c6d922310b422606825020fd163faef5f4f62a3f4c12

<pre data-unit="G-073">### 5.8 上下文路由与能力四级词典

**改哪一面，就必须连带读哪些东西**——否则断言的是记忆不是现状：

&#124; 改动面 &#124; 必须追加核对 &#124;
&#124; --- &#124; --- &#124;
&#124; 项目总体边界 &#124; 总体架构、&#96;constraints.md&#96; &#124;
&#124; Task/Attempt/Interaction/Delivery &#124; 内核、生产代码与对应测试 &#124;
&#124; Agent runtime、恢复、预算、事件、副作用 &#124; 当前事实文档、生产链代码和测试 &#124;
&#124; 跨 App 契约 &#124; provider schema、consumer lock 和**双端**契约测试 &#124;
&#124; Admin/Web/API &#124; 目标目录 &#96;AGENTS.md&#96;、认证边界和端到端测试 &#124;
&#124; 数据模型或迁移 &#124; 迁移链、数据库约束、前滚/回滚和数据不变量 &#124;
&#124; K8s 或发布 &#124; bundle、release、部署引用与运行门禁 &#124;
&#124; Git、远端或子模块 &#124; 现行协作规范、各仓 HEAD 和 gitlink &#124;

⚠ **历史 baseline、候选和聊天记录只作线索**；当前实现断言必须回到代码、测试或运行结果取证。

**陈述任何能力状态时只用四级词典**，不得自行发明「已实现」的判断口径：

&#124; 级 &#124; 含义 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;defined&#96; &#124; 有类、DTO、迁移或测试夹具**存在** &#124;
&#124; &#96;wired&#96; &#124; 生产链**已接线**，会被真实请求走到 &#124;
&#124; &#96;deployable&#96; &#124; 部署面（bundle、网络、凭据、配额）**已就位** &#124;
&#124; &#96;runtime-verified&#96; &#124; 在目标环境**实跑验证过** &#124;

⚠ **类、DTO、迁移或测试夹具存在，都不等于生产链已经接线。**
这是 &#167;12「拿休眠代码当能力证据」那条失败的词汇层防线；配套的可运行验证动作是
**回跑 dormant 测试**并同时确认「锚点仍在」与「能力仍未接线」两个方向（&#167;2.6）。

</pre>

**G-078** · 源 agent-dev-guide.md，L1916–L1929；SHA-256 96e054592724052db6dbfbca3cc7584e3d0be5caa6101cbe4870f18def5cdd65

<pre data-unit="G-078">### 5.13 历史取证怎样用于今天的开发

使用证据前固定 **仓库/SDK commit、配置或策略版本、主机、OS 身份、沙箱/容器上下文、
命令、退出码、原始输出引用及时间**；敏感字段去敏，不输出凭据本体。
权限实验针对被描述的实际环境；沙箱内观测不能直接外推宿主，受限环境不能代替生产同身份测试。
需要受限操作时走既有授权机制，不为取证绕开权限。

文档的“曾经通过”只说明那个版本的那个用例。版本变化后核代码、消费者、部署与测试，
不能仅验证行号仍可达；原记录不得改成新日期，也不得拿本次文档校验冒充 SDK 或产品运行验证。
返回 UNKNOWN 时写清是未执行、输入不全、环境阻断，还是当前接入方式结构上无法观测。

源作者的事故数、候选排序、权限读数可以作为回归测试的线索，但没有独立重取证据时，
引用为“原作者记录”，不写成本次已核对事实。取证前提与覆盖也能被纠正，不能认为“测量永远不会错”。

</pre>

#### 载体与等效

**G-069** · 源 agent-dev-guide.md，L1699–L1708；SHA-256 e0c63c56a0cfb4078344cca5a5db1c7047b03ddd332998af99356b554a6c60c9

<pre data-unit="G-069">### 5.4 Git 载体能与不能证明什么

Git 永久承担代码/文档 Artifact 的版本载体；手工阶段也可从 commit、裁定记录和执行事件重建投影。
分支是运输通道，工作区是可变草稿，只有钉定 commit 的产物可评审。发布时必须比较目标 ref 是否仍在
预期基线，冲突就新建整合 Attempt。

Git 不能证明产品 &#96;F-ACCEPT-03&#96; 的跨记录事务提交、Attempt 租约或产品 &#96;I14&#96; fencing；也不能证明
CLI 内部发生过哪些工具调用。手工态的价值是先跑通对象形状、合法边、Interaction 和协作纪律，
不是替 PostgreSQL 与工具网关完成并发、安全证明。

</pre>

**G-074** · 源 agent-dev-guide.md，L1804–L1826；SHA-256 b2f98196d60e008adf312582374f6a1a229681178f0848feaf131f0de500b451

<pre data-unit="G-074">### 5.9 七种载体各能证明什么

⚠ **隔离靠 worktree + 命名分支，不靠文件名。**&#96;-new&#96;、时间戳、执行者名写进文件名，
都不能阻止「同一工作区、同一相对路径」被后写覆盖。不同载体的覆盖语义完全不同：

&#124; 载体 &#124; 覆盖会怎样 &#124; 能证明 &#124; **不能**证明 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; **未提交工作区文件** &#124; **后写直接覆盖先写：无冲突、无历史、无警告、无作者归属** &#124; 磁盘此刻的内容 &#124; 谁写的、谁先写完、被覆盖前是什么。**隔离单位是工作区，不是路径字符串** &#124;
&#124; commit &#124; 新 commit 不摧毁旧对象；旧对象**需有 ref 才找得到** &#124; 一组文件内容及父历史不可变 &#124; 谁批准、测试是否通过、外部副作用状态 &#124;
&#124; branch &#124; 指针可被快进、重置、强推；**像标签在移动** &#124; 当前指向哪个 commit，便于运输和续接 &#124; **稳定的评审对象**——分支头会移动 &#124;
&#124; worktree &#124; 一分支只能被一棵 worktree 检出，Git 会拒绝第二处 &#124; 某执行者当前可写目录和所检出分支 &#124; 长期证据；目录可以删除 &#124;
&#124; tag/ref &#124; 可被移动或删除，但所指对象仍在对象库 &#124; 使对象可达并表达冻结点 &#124; **不自动构成验收或发布** &#124;
&#124; patch &#124; 应用到不同基线上结果不同 &#124; 可传输的差异 &#124; 完整父基线、未跟踪文件或外部状态 &#124;
&#124; 共享发布面 &#124; 未授权写入等于闯入他人工作区或发布面 &#124; 只有整合后的 final commit 算交付 &#124; 任何未经整合的内容 &#124;

⚠ **未提交工作区文件不能作为候选，也不能作为交卷物**：没有 commit、没有 digest、
没有作者归属，被覆盖后既难恢复也难归因。**交卷 = 自己分支上的可达 commit。**

候选和评审一律引用**完整 commit ID 与基线**，不能只给分支名。冻结候选后禁止 force-push
改写其可追溯历史；需要 rebase 时形成**新的候选 commit** 并保留旧→新映射。
删除 branch、worktree 或工作区前，必须确认仍需保留的 commit 已由持久 ref、获准远端或
Artifact bundle 保持可达——⚠ **「对象暂时还在 reflog」不是保留策略。**

</pre>

**G-068** · 源 agent-dev-guide.md，L1674–L1698；SHA-256 ee5e4116de60848e35a2d19695f81cc00df499e020501105e18c5e62e7de240c

<pre data-unit="G-068">### 5.3 手工态与服务态的等效判据

等效分两层：

- S 层比较对象集合、状态词、合法边、权力行、Interaction 绑定、Agent Profile 字段；现在就能判；
- R 层比较同一 Task 的状态/Attempt/Interaction/Artifact 序列，经投影丢掉执行器私有事件和时间戳后逐项判。

每个轨迹条目至少含 &#96;seq, layer, subject_id, from, to, actor, power_row, payload_ref,
provenance, evidence_ref&#96;；⚠ **Artifact 的作者要拆成 &#96;author_claimed&#96; 与 &#96;author_attested&#96;
两个字段**——合成一个就没法表达「声称是谁写的」与「能证明是谁写的」之间的差距，
而目前这两者几乎从不相等（&#167;2.12 &#96;channel_grade&#96;）。**比较上下文**（源稿称 &#96;TraceEnvelope&#96;——本文不沿用该名，
因为它只是这一组字段的包装，另起一个名字会让读者以为多了一个对象）另含
Task Profile 版本、验收摘要、策略版本、principal 身份域、
输入摘要、Side Effect 摘要和证据权威摘要。比较规则：

1. 只允许载体、orchestrator 实现、时间和已声明私有事件不同；白名单外差异失败。
2. 比较粒度取较粗一腿，并列出未比对项。
3. 两边都声明权威源与重建规则；Git 工作区文件不作判据。
4. 结论只能在两条轨迹的最低 provenance 上宣称，并报告各类 &#96;attested&#96; 数量。
5. bootstrap 期身份归因强度为零，服务态不得继承成可信先例。
6. 先验证每个状态属于内核状态集、每条相邻边属于合法边，再比较序列。

轨迹只是 Event 投影，不是新内核对象；结构与比较规则已完整列在本节，执行时无需回读历史稿。
历史样例及 23 条里仅 2 条 &#96;attested&#96; 的读数见 &#167;5.11，说明“流程看起来发生过”不等于可搬运证据链。

</pre>

#### 成本和观察上界

**G-080** · 源 agent-dev-guide.md，L1932–L1946；SHA-256 7ed6716aca071042e7ac9c94cf934790e3edfef71a88151660cfcdc91ae043d7

<pre data-unit="G-080">### 6.1 机械分类

开销是 &#96;(Task, orchestrator implementation)&#96; 的函数。以下任一成立，运行时通常更便宜或是硬要求：

&#124; 特征 &#124; 结论 &#124;
&#124; --- &#124; --- &#124;
&#124; proposer ≥ 2 或 write actor ≥ 2 &#124; 并行隔离、收集和整合使运行时更便宜 &#124;
&#124; 有冻结/路线/裁量/预算/输入等人工触点 &#124; 持久 Interaction 比手工传话便宜 &#124;
&#124; 有钉版本只读输入、依赖或 checkpoint 续接 &#124; 运行时避免上下文丢失 &#124;
&#124; 触及约束、内核、协议、策略或门禁 &#124; 必须进入受控流程，与便宜无关 &#124;
&#124; 有副作用、审计要求或重复执行 &#124; 账本和幂等收益超过固定成本 &#124;

全部不命中时，运行时往往更贵，除非仍满足下一节 T0 上界。新增布尔字段必须显式给值；缺省 false 会
把未知静默判成未命中。

</pre>

**G-081** · 源 agent-dev-guide.md，L1947–L1962；SHA-256 c53656f27fcb29a657587cbdf70c8507aa60849f96538cebc0c748362986c640

<pre data-unit="G-081">### 6.2 三类反例与 T0 上界

运行时反而更贵的典型：已批准窄包内的单文件笔误；不落 Artifact 的一次性探索阅读；
必须由人逐次打开 GUI 并传话的执行器。第三类只对 M0/T0 小任务成立，不能否定大型并行或续接任务的收益。

T0 每个任务类包都应实测以下复合上界，任一维超标就升 T1：

&#96;&#96;&#96;text
(human_required_actions, persisted_artifacts, request_to_dispatch_steps, dispatch_events)
        &lt;= (2, 4, 2, 0)
且 human_required_actions &lt;= 同一任务手工模式的动作数
&#96;&#96;&#96;

人的必需动作计经鉴别响应、principal commit/push 和人工 dispatch；通知或敲命令虽不算决策仍计动作。
T0 工单要从请求自动形成，H5 折入人本来就要做的发布动作；否则“小任务更快”会驱动绕过。

</pre>

**G-082** · 源 agent-dev-guide.md，L1963–L1985；SHA-256 d4f05037f230c84881d61b08c7ea0570b534959af2701936568eba3e75ed1881

<pre data-unit="G-082">### 6.3 绕过只能部分可观测

账本看不见账外，“完全可观测”不可达。正确做法是：

1. 让合法 T0 足够便宜，并让未获权产物不能进入交付面。
2. 分母取外部 sink：托管方写入审计、全部 commit 集、工作区脏状态、可获得的进程/会话记录。
3. 每个 sink 同时列覆盖与不覆盖；未归因变更记 &#96;BYPASS_CANDIDATE&#96; 观察 Event，不反向伪造正常 Task。
4. 可以提供 &#96;register --from-commit&#96; 把历史变更登记为带 &#96;retroactive&#96; 标记的新 Task，但先核产品 &#96;I1&#96;。
5. 未提交修改、纯对话和不可见 GUI 会话保持 &#96;UNKNOWN&#96;；零命中只能写“没查到”。

对账的覆盖必须具体到 sink，不能仅写“有审计”：

&#124; 外部观察面 &#124; 能覆盖 &#124; 覆盖不到 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 托管方写入审计/受保护接收入口 &#124; 经过该入口的远端变更及拒绝 &#124; 本地 merge、未推送提交、其他入口 &#124;
&#124; Git 已提交对象与账本 commit 集对比 &#124; 纳入枚举的已提交变更 &#124; 未提交、改了又丢、不可达或未枚举的 ref &#124;
&#124; 工作区脏状态 &#124; 被扫描工作区此刻未归因的写入 &#124; 纯读取、已清掉的修改、未扫描路径 &#124;
&#124; 获准可读的进程/会话记录 &#124; 记录覆盖内的直接调用 &#124; GUI 内部、别机、缺日志或不可访问的历史 &#124;

观察面未取得或枚举失败时不计算“零绕过”。未归因只落观察事件，**不自动建 Task、不自动惩罚**。
追认须由明确动作创建带 retroactive 标记的新记录，保留真实原始来源、发生时间与追认时间，
不得伪造事前批准；其与 I1 的兼容性仍为 &#167;7.4 未决。追认比例是流程成本线索，不自动降低权限。

</pre>

### playbooks/intake.md（P）

把原散在架构、执行、末尾模板和实施计划的开工材料拼成一条前置链：自检 → 受理 → 冻结 → 工单落盘。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 自检与受理 | 提交任务前的相关约束、可信输入、边界和默认值冻结；系统原则引用 foundation，不在此新立。 | G-010, G-012, G-029 |
| 记录表单 | 要求执行者填写的持久记录与任务条目字段；具体任务清单属于 work/delivery。 | I-002, G-108 |

#### 自检与受理

**G-010** · 源 agent-dev-guide.md，L151–L163；SHA-256 d35e3c4f53319ad4f40f6760f0f23b226d37555d675d16915aa98ee19aedd820

<pre data-unit="G-010">### 1.3 Agent 硬约束自检

&#124; 约束 &#124; 本文结论 &#124;
&#124; --- &#124; --- &#124;
&#124; constraints A1：通用执行编排与领域能力分开 &#124; &#96;dev.change/1&#96; 复用运行时；新增业务能力优先新增 Task Profile 与相容 Agent Profile &#124;
&#124; constraints A2：通用部分也要有纪律 &#124; 执行纪律引用 round-protocol，不把 harness 原语当协作纪律 &#124;
&#124; constraints A3：四本账落 PostgreSQL &#124; Git 只作开发 Artifact 载体与手工投影，不作产品账本 &#124;
&#124; constraints A4：执行层租用不自建 &#124; 依赖止于稳定 SDK，经 Port 隔离；不直接绑定裸协议 &#124;
&#124; constraints A5：领域概念不进 Port &#124; Port 接受通用输入、能力与结果；投资组合等词留在领域 Profile &#124;

上述五条见 &#96;constraints.md @ ed0b5136:149-159&#96;。涉及多仓还必须遵守 constraints T4/T5：
父仓不留悬空 gitlink，交付证据写“仓 + commit”，见 &#96;constraints.md @ ed0b5136:95-103&#96;。

</pre>

**G-012** · 源 agent-dev-guide.md，L171–L186；SHA-256 ee67b25ecc07b1e3fc56489cde893d6e61930a1974ae41328446f2cf381a64a6

<pre data-unit="G-012">### 1.5 执行者的共同纪律

不论单路还是并行，不论人还是 agent，八条都成立：

1. **不用计划覆盖原始请求**（&#96;I1&#96;）；
2. 只在范围、工具、数据、预算和副作用边界内行动；
3. **区分事实、推断、假设、缺失和未运行验证的结论**，不可混写；
4. 对可中断工作持久化 checkpoint；
5. 无法满足完成契约时请求输入或**明确失败**，不交半成品；
6. 在**最终固定版本**上运行与风险相称的验证；
7. 报告盲区、副作用和残余风险；
8. 未经授权不推送、合并、发布、删除远端资产或扩大外部影响。

⚠ 第 3 条是 &#167;5.2 采信规则与 &#167;12 三级证据分档的**前提**：分不清事实与推断，
后面两处的分级就无从谈起。

</pre>

**G-029** · 源 agent-dev-guide.md，L651–L681；SHA-256 0e94a304664ff0e9747c90bf5b37844ceda387296036ff36750fc5ef8358bf39

<pre data-unit="G-029">### 3.1 受理与冻结

1. 保存用户原话、身份、幂等键和附件引用，形成 Task；原始输入不可被后续整理覆盖（产品 &#96;I1&#96;）。
2. router 生成 RouteDecision；零命中或多命中产生 &#96;WAITING(INPUT)&#96;，越权或不可受理进入 &#96;REJECTED&#96;。
3. &#96;QUEUED&#96; 前冻结目标、边界、输出、验收、证据、新鲜度、预算、权限与副作用；要求见
   &#96;request-lifecycle.md @ ed0b5136:166-181&#96;。
4. T0 的验收只能引用一份预先批准的窄任务类包；包必须同时固定 &#96;paths + gates + covers&#96;，不得现场拼门禁。
5. T1/T2 的判据先于产出冻结，出题者与验收者分离；省事方向变化由 principal 显式确认。

T0 的任务类包需要两道门：开工门检查包名与 RouteDecision；完工门检查真实 diff 属于允许路径且门禁全过。
策略包不得覆盖权威文档、策略本身、门禁脚本或门禁依赖，否则执行者可以同时改尺子和答案。

**前端提交与可信受理边界。**Submission 应携带原始请求、已知目标仓/系统、附件与来源引用、
输出/验收期望、时间/成本约束、允许副作用和幂等键。前端可提示格式，不能只提交改写后的意图，
也不能靠默认值扩权；身份、租户、角色与数据作用域来自后端认证上下文，不采信前端自报。
网络重试复用同一幂等键，附件及资源引用须持久化、可校验，不能依赖浏览器临时状态。

可信受理端校验正文/附件的类型、大小、资源权限与恶意内容；绑定版本化 Profile、执行与 sandbox
策略，再把范围、验收、权限、预算和输出规范化。**Task 与首条 Event 可靠持久化后才供给/调度**。
局部、可撤销且 Profile 已明定的默认可以应用，但原值、规则版本和转换结果一起保留；
实质改变目标、权限、成本、风险或验收的歧义才发 Interaction，不替用户暗定产品决策。
这些是职责要求，不把受理框架名变成另一种运行时角色。

T0/T1/T2 的**开工前**人工触点分别为 0/1/2：T0 的 H1 已在任务类包批准时完成，
不是把 H1 设成默认；T1 可合并 H1/H2；T2 的题目/验收须先于候选冻结，参与方和路线另行确认。
开工前零触点**不免除 H5**，也不免独立验收。跨任务类包就升档，不把窄包改成万能包。

完工 diff 的范围只能在产出后检查；分发时 diff 还是空集，拿它证明范围合规会恒真。
也不以 &#96;covers&#96; 与需求复述的字面匹配代替语义验收。无法完整表达为批准包的路径和门禁，
就不属于该 T0 包。

</pre>

#### 记录表单

**I-002** · 源 implementation-plan.md，L11–L26；SHA-256 df8f4d171db2e7656dcf23738a203ad88aaca5dc3f1ae8c340680323ca361c56

<pre data-unit="I-002">## 任务条目格式

每条任务固定这几栏，**缺栏视为未定义，不开工**：

&#124; 栏 &#124; 写什么 &#124;
&#124; --- &#124; --- &#124;
&#124; 类型/优先级 &#124; &#96;ARCH&#96; / &#96;FEAT&#96; / &#96;FIX&#96; / &#96;OPS&#96; + &#96;P0&#96;–&#96;P2&#96; &#124;
&#124; 仓库 &#124; 涉及哪几个仓——跨仓任务必须列全，否则漏推 &#124;
&#124; 前置 &#124; 依赖哪些任务或哪条未决项定了才能开工 &#124;
&#124; 目标 &#124; 一句话说清做完之后什么变了 &#124;
&#124; 实施 &#124; 具体动什么。**不写&quot;完善 X&quot;这种没有终点的表述** &#124;
&#124; 测试 &#124; 适用的测试层次（见下），**不能只写&quot;补测试&quot;** &#124;
&#124; 验收 &#124; 可判定的条件。做完能一条条对着勾 &#124;
&#124; 回滚 &#124; 出问题怎么退回去 &#124;
&#124; 状态 &#124; &#96;NOT_STARTED&#96; / &#96;IN_PROGRESS&#96; / &#96;BLOCKED&#96; / &#96;ACCEPTED&#96; + 日期与证据 &#124;

</pre>

**G-108** · 源 agent-dev-guide.md，L3038–L3082；SHA-256 7b5384fbaedbe63defae494e1c7783a8a4e86075a75a49bac60a319eebb7dedd

<pre data-unit="G-108">## 14. 开发 Task 持久记录模板

载体可以是数据库、Issue、PR、事件流或仓库文件，但**不能丢失原始请求、边界、验收、基线、
证据和改判历史**。⚠ **空栏必须写「不适用」及理由——空着与「忘了」无法区分。**

&#96;&#96;&#96;markdown
# DEV-&lt;ID&gt;：&lt;短名&gt;

## ① 原始请求
&lt;用户原话，不改写&gt;

## ② 受理、边界和授权
- 规范化目标：            - 包含：                - 不包含：
- 不包含部分归属：        - 权限与批准点：
- 预算、期限和停止条件：  - run / owner / work unit：
- 可写根与 output namespace：
- publication target / integrator：

## ③ 基线与工作区
- Task / Attempt：        - workspace：           - source refs：
- baseline commit / gitlinks：                    - 适用指令：

## ④ 决策点
&#124; ID &#124; 问题 &#124; 结论与理由 &#124; 证据 &#124;

## ⑤ Work Units 与落地去向
&#124; Work Unit &#124; owner &#124; branch/worktree/namespace &#124; output commit/digest &#124; publication target &#124; status &#124;

## ⑥ 验收标准与证据
&#124; ID &#124; 标准 &#124; 判定 &#124; 证据 &#124;

## ⑦ 依赖、Interaction 与副作用
- 依赖：                  - 澄清/批准：           - 副作用账：

## ⑧ 状态流转与改判
&#124; 时间 &#124; 状态/改判 &#124; 触发 &#124; 原判断错处 &#124; 新判断 &#124;

## ⑨ 交付与清理
- final commit / Artifact：                       - provenance / supersedes：
- published ref / publisher：                     - 未覆盖与残余风险：
- Delivery：                                      - 工作区清理：
&#96;&#96;&#96;

⚠ ⑧ 中的改判字段对应 &#167;4.8 的改判三要素——**「原判断错处」栏写「当时信息不全」不算填**，
要写出具体哪一步推错了。
</pre>

### playbooks/execution.md（P）

把供给、私有写入、并发故障、取消超时串成一次执行闭环；把发布和审批移到各自责任面。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 工作区准备 | 满足开工需要的目录、Git 元数据及可写性验证；权限授予公式不在此改。 | G-030, G-042, G-048 |
| 写入与并发 | 先隔离和单写者，再物化/写前门，最后按冲突场景处置；结果发布步骤另见 delivery。 | G-034, G-038, G-035, G-036 |
| 停止与恢复入口 | 取消、迟到、超时、成本上限和回退共同决定何时停止；跨会话完整记录属于 maintenance。 | G-037, G-041, G-050 |

#### 工作区准备

**G-030** · 源 agent-dev-guide.md，L682–L703；SHA-256 2f6020fca14c794bf0c03ccdfd8a6299d77b952f6c954fde02d8116508056d5a

<pre data-unit="G-030">### 3.2 工作区供给

&#96;&#96;&#96;text
provision(task_id, source, baseline_commit, write_actors, review_needed, submodule_plan)
&#96;&#96;&#96;

复用工作区前，必须同时满足 owner 是本 Task/执行者、&#96;git status --porcelain&#96; 为空、HEAD 等于基线 commit；
任一失败就新建，不 stash 人的修改。零写者只给只读取件；一名写者一棵独占 worktree；N 名写者在同一
基线上建 N 棵独占 worktree，另给 integrator 一棵；人需通读时临时开 review worktree，用完删除。
多仓逐仓钉 commit，并核父仓 gitlink。
⚠ **父仓推送不带子仓提交**：跨机同步脚本推的是父仓，拉取侧自动 &#96;submodule sync/update&#96; 对齐 gitlink，
**子仓的提交仍须自己推**（constraints T4）。只交父仓 gitlink 而子仓对象不可达，等于没交。

独占在 CLI/GUI 腿通常只是约定，因为同 OS 用户可能看见整个文件系统；只有 runtime 提供的 namespace、
文件挂载、凭据裁剪和出网网关才能构成事中限制。&#96;workspace_isolation&#96; 必须登记为 &#96;enforced&#96; 或
&#96;convention&#96;，不能把目录不同写成安全隔离。

⚠ **后果是一条硬约束，不是一句提醒**：&#96;convention&#96; 腿的授权范围声明（&#96;I3&#96;）只能依赖
「事后审计可发现越权读取」，不能依赖「事中读不到」。因此——
**涉及第二租户或真实财务数据之前，CLI 腿的数据源必须经运行时的数据网关，
不得给裸库凭据。**

</pre>

**G-042** · 源 agent-dev-guide.md，L1042–L1054；SHA-256 f1d246f7a14f983e5a815f6f7b8916e60140cfb99fe19cfc872a6e22f3a8f2b9

<pre data-unit="G-042">### 3.14 建立 worktree 的细则

- 每个并行单元**独立分支、独立可写 worktree**；候选从同一冻结 commit 开始；
- ⚠ **同一分支不能被两棵 worktree 同时检出**——Git 会拒绝第二处，这是机制不是约定；
- ⚠ **worktree 只隔离写入，不阻止读取共享 Git 对象**，隔离强度要在登记表里说明（&#167;3.2）；
- 多仓单元固定每仓 commit 和父仓 gitlink；
- ⚠ **租约、凭据和产品状态不得提交进分支**；
- 建立、归属、基线和清理状态进入 manifest（&#167;3.10）；
- ⚠ **删除 worktree 不等于删除证据**——commit 必须仍然可达；
- &#96;master/main&#96; 与其他共享分支**默认不是候选写入面**；
- 即使多个候选修改同一相对文件，也各自在自己的分支/worktree 里改；
- **只有 integrator** 在独占整合 worktree 中写最终路径并形成 final commit。

</pre>

**G-048** · 源 agent-dev-guide.md，L1169–L1198；SHA-256 fcb44fe363672dc1e9c8228a92cbeddcb246739f4c43f474933a84c60a981f56

<pre data-unit="G-048">### 3.20 工作区能写，不代表 Git 能提交

供给阶段同时检查文件写入面和 Git 元数据写入面。先在获准目录只读执行：

&#96;&#96;&#96;bash
git rev-parse --show-toplevel
git rev-parse --git-dir
git rev-parse --git-common-dir
git status --porcelain=v1
&#96;&#96;&#96;

任一身份/仓库判别失败立即报错，不通过吞退出码的管道生成假名字，
也不根据产品、模型或界面猜“我是哪个参与方”。工单中的执行者 id、登记的工作区归属、
实际仓库根应一致；目录名是本地归属线索，**不是经鉴别的 principal 身份**。

历史源稿记录了三个结果：共享 worktree 的 Git 元数据可能位于获准工作区外；
改成独立 clone 后，若沙箱仍把 &#96;.git&#96; 设为只读，同样不能提交；
私有 clone 加明确的私有 Git 元数据写权限才在那次实验中通过。
⚠ **这是原作者在特定沙箱的实验记录，本次未复跑，不能外推所有执行环境。**

因此实际采用什么布局，要由当前权限配置与一次获准的可丢弃提交实验验证。
不能为修一家提交失败而放开全体共享的 objects/refs；若需改变布局或可写根，
由供给方在既有授权内处理，受平台权限限制的操作仍遵循该平台的批准机制。
不得靠反复换工具、偷偷改权限或给整个主仓 &#96;.git&#96; 开写来绕开隔离。

执行者能写文件但不能提交时，保留在其私有工作区，报告内容摘要、基线和阻断原因，
由已获授权的组织者代提交。代提交必须区分 author 与 committer，记录内容作者、
代提交者、原因和 SHA-256，并计入人工传输成本。代提交只改记录方式，
不把可任填的 Git author 升为身份认证，也不把未冻结文件冒充已交卷。

</pre>

#### 写入与并发

**G-034** · 源 agent-dev-guide.md，L782–L821；SHA-256 94ec95396cbb2df8acf50a28e4a32cc6f8ec27f2f2e7ffbbd4395cec98ca2d13

<pre data-unit="G-034">### 3.6 私有地产生，单写者发布

**会话隔离、模型隔离和任务名称不同，都不等于文件系统隔离。**
任何可能并行的执行者都不得把共享路径当自己的草稿纸。

&#96;&#96;&#96;text
private draft → owner candidate → frozen commit / immutable Artifact
              → 选优 → integrator workspace → final commit → 共享分支 / release / Delivery
&#96;&#96;&#96;

共享发布面包括 &#96;master/main&#96;、公共工作树、约定的最终文件路径、共享对象存储键、正式 PR、
release、部署环境和用户可见结果。⚠ **用户要求的最终文件名是发布目标，不是所有候选都可
同时写的路径。**多个候选各自在独立 worktree 里改同一相对路径是安全的；共用一个物理工作树
就必须用 owner namespace，**不能靠「最后再改名」避免覆盖**。

推荐的逻辑命名（实际路径可调，隔离维度不能丢）：

&#96;&#96;&#96;text
branch:    task/&lt;task-id&gt;/&lt;owner-id&gt;/&lt;work-unit-id&gt;
worktree:  &lt;sandbox&gt;/worktrees/&lt;owner-id&gt;/&lt;work-unit-id&gt;/
artifact:  &lt;artifact-store&gt;/&lt;task-id&gt;/&lt;work-unit-id&gt;/&lt;attempt-id&gt;/&lt;name&gt;
evidence:  &lt;artifact-store&gt;/&lt;task-id&gt;/&lt;attempt-id&gt;/evidence/&lt;name&gt;
integrate: task/&lt;task-id&gt;/integrate/&lt;run-id&gt;
&#96;&#96;&#96;

若工具限制导致只能共享一个工作树，草稿必须写进明确的 owner namespace（如
&#96;.work/&lt;task-id&gt;/&lt;owner-id&gt;/...&#96;），共享最终路径保持只读。**共享工作树是降级方案，
不能声称具备 worktree 级隔离。**连 owner namespace 都保证不了，任务必须串行。

**本仓当前落点：**

&#124; &#124; 路径 &#124; 权限 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 人的主 checkout &#124; &#96;~/master/&lt;仓&gt;&#96; &#124; **只读**。可读、可对照，**不是投稿箱**，也不因为「原件在这里」就该写这里 &#124;
&#124; 执行者工作区 &#124; &#96;~/worktrees/&lt;助手&gt;/&lt;仓&gt;&#96; &#124; 该助手唯一可写面；提交到自己的命名分支 &#124;
&#124; 整合面 &#124; 整合方 worktree 上的 &#96;integrate/&lt;run-id&gt;&#96; &#124; 只有 integrator 写；**源是选定 commit，不是任何人的工作区文件** &#124;

「一仓一个默认工作区」不够多执行者用。同一 Task 出现第二名可写执行者时，
必须先建好各自的 worktree 和命名分支再派活，**不往默认工作区加写者**。

</pre>

**G-038** · 源 agent-dev-guide.md，L914–L968；SHA-256 0287133295fd64fc120c868734720e1001ea3b7ef76f0050a210e4514a6d453d

<pre data-unit="G-038">### 3.10 物化门禁与写入前门禁

**两道门，时机不同：物化门禁在第一个 Attempt 启动前，写入前门禁在每次落笔前。**

**物化门禁（首个 Attempt 启动前必须证明）：**

1. Task 契约已可靠持久化；
2. workspace **唯一归属本 Task**，路径、配额和回收策略明确；
3. source ref、Artifact 摘要、commit 和 gitlink 可取得；
4. 初始 &#96;git status&#96; 符合 Profile，预置脏文件均有解释；
5. 指令范围可由目录层级确定；
6. 凭据、越权数据和无关材料未进入版本库；
7. **manifest 与实际文件一致**；
8. 工具、权限和预算不超过 Task 授权；
9. owner、独占可写根、候选产出位置和唯一 integrator 已明确；
10. **共享发布面为只读**，除非当前 Attempt 正是获准的整合 Attempt。

⚠ 失败时**不得把半成品工作区交给执行者「尽量执行」**。重试复用 Task 身份但**建立新
Attempt**，并隔离或安全清理残留 workspace。

**manifest 证明实际给了什么**（Task 决定该给什么，manifest 证明给了什么）：

&#96;&#96;&#96;text
task_id, workspace_id, created_at        run_id, owner_id, work_unit_id, attempt_id
source repository + commit / gitlink     artifact source + digest + destination + access mode
generated task package + profile version effective instruction files and scope
excluded material + reason               secret references (never values)
initial commit                           writable roots + output namespace
publication target + integrator
&#96;&#96;&#96;

⚠ **材料在工作区内可见，不自动构成使用授权。**有效权限仍由 Task、Profile、工具策略和
当前批准共同决定（&#167;4.5 的交集公式）。**上一 Task 的工作区不得在未重新受理、授权和物化的
情况下复用给下一 Task。**

**写入前门禁（一票否决）。**动手写任何文件之前逐条核对，任一不成立则**停，不写任何文件**：

1. &#96;cwd == workspace_path&#96;；
2. 当前分支 &#96;== exclusive_branch&#96;；
3. 目标路径不在禁写集内，且**解析软链、&#96;..&#96; 和挂载别名后的规范路径**仍落在获准的
   writable root 内；
4. 目标路径上**没有他人产物**；若有，不覆盖——先让对方的内容形成可达 commit 或备份；
5. 本次**不是宽泛写入**（批量生成、&#96;&gt;&#96; 重定向、脚本 sweep、先 &#96;rm -rf&#96; 后重建）；
   确需宽泛写入时收窄到明确路径逐个执行。

⚠ **这五条不是建议。宽泛写入和「路径归属不明仍继续写」是覆盖事故的两个主因**，
两者都发生在**写入前**，而事后恢复（&#167;3.8）代价远高于停一次。

**冷启动核对（每次 Attempt 开始时）：**Task/Attempt ID、租约、fencing、预算与停止条件；
原始请求、范围、验收、批准点与预期 Artifact；当前目录、仓库根、分支、HEAD、子模块与
工作树状态；manifest 的输入、摘要、基线与实际文件；生效的 &#96;AGENTS.md&#96; 与目标代码附近测试；
依赖、权限与外部系统是否仍有效；**哪些判断是事实、推断、假设、缺失或尚未验证**。
不匹配会改变结果时**停止并发起 Interaction**——不得在错误仓库、错误分支、过期 commit
或失效租约上继续。

</pre>

**G-035** · 源 agent-dev-guide.md，L822–L862；SHA-256 d978783d7cdd3473f409a694a7bddd1ecfec8fc881d8717e1273f108ced5441f

<pre data-unit="G-035">### 3.7 并发场景处置表

每行四件事：场景、正确落点、禁止做法、**已发生时怎么收**。
恢复列给的是入口动作，统一规程见 &#167;3.8。

&#124; 场景 &#124; 必须怎样做 &#124; 禁止 &#124; 已发生时 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; 多执行者生成同名文档 &#124; 各自在自己 branch/worktree 改同一相对路径，分别 commit &#124; 一起写共享目录同一个 &#96;.md&#96; &#124; **以 commit 认主，不以磁盘最后一版为准**；共享路径上的未提交文件视为污染，移进各自 namespace 后比 digest，声明哪些候选已不独立 &#124;
&#124; 只能共享物理目录 &#124; 用 &#96;owner_id/work_unit_id&#96; namespace，最终路径只读 &#124; 用时间先后或「谁最后保存」定结果 &#124; 停写；分流进各自 namespace；由 integrator 裁决 &#124;
&#124; 单执行者单路任务 &#124; 仍固定 owner、baseline 和 candidate commit &#124; 在脏的共享 master 上直接写未跟踪结果 &#124; 把脏工作区里属本任务的内容迁到自己分支并 commit &#124;
&#124; 人与 agent 混合 &#124; 各有独占 worktree，统一登记 &#124; 默认人的目录可被 agent 写 &#124; 助手改动撤出人的工作区；**人的未提交改动优先保留** &#124;
&#124; 两个单元改同一文件 &#124; 目标不同则各分支独立改由 integrator 解冲突；共同写同一事实则重划所有权或串行 &#124; 同时共享写、事后凭 mtime 猜作者 &#124; 停写；双写内容各自成 commit，交 integrator 判重复/互补/无关 &#124;
&#124; 多仓 / 子模块 &#124; 每仓独立 owner branch/commit；子仓对象先可达再更新父仓 gitlink &#124; 只交父仓 gitlink &#124; 补齐每仓映射；**子仓对象不可达的 gitlink 不进整合** &#124;
&#124; 同一 Task 多 Attempt 重试 &#124; 每次新 attempt/worktree/branch；旧结果标失败或 superseded &#124; 在旧 Attempt 目录原地续写 &#124; **旧目录冻结为失败现场**，新 Attempt 从固定 commit 重开 &#124;
&#124; 候选修订 &#124; 新 commit + &#96;supersedes&#96; &#124; 冻结后改 branch 再沿用旧评审 &#124; 新哈希标为冻结后修订并记 &#96;supersedes&#96;，不进本轮比较 &#124;
&#124; 内容相同的重复候选 &#124; 按 digest 去重，可共享内容对象，**保留各自 provenance** &#124; 删一方记录后声称只有一个来源 &#124; 合并内容对象，两份 provenance 都留 &#124;
&#124; 合并冲突 &#124; integrator 在独占整合 worktree 解析，记冲突双方与裁决依据 &#124; 让候选作者互相覆盖，或按时间自动取新 &#124; 同左；**不按时间自动取新** &#124;
&#124; 一方删除、一方修改同一文件 &#124; 作为语义冲突交 integrator 依 Task 裁决并补回归 &#124; 机械采用 delete/modify 任一侧 &#124; 升给 integrator，不机械取任一侧 &#124;
&#124; 用户工作树已有脏改动 &#124; 视为用户所有；另建 worktree/分支或避开，先记 baseline &#124; **stash、reset、checkout 或覆盖用户文件来「清理」** &#124; 不 stash、不 reset、不 checkout；先记 baseline 再绕开 &#124;
&#124; 执行中发现共享路径又被改 &#124; 立即停写并进 &#167;3.8 &#124; 继续保存，期待自己的内容最后覆盖回去 &#124; 停写转 &#167;3.8；从最新可确认版本建新整合 Attempt &#124;
&#124; formatter/codegen 同时跑 &#124; 只在 owner worktree 执行，生成物归该 owner commit，固定工具版本 &#124; 对共享目录启用后台自动写入 &#124; 关掉共享目录自动写入；受影响文件从 owner commit 重生成 &#124;
&#124; 无 Git 的简单任务 &#124; 每个 Attempt 用独立 Artifact key，以 digest/version 冻结 &#124; 多 Attempt 写同一临时文件或对象键 &#124; 迁到 Artifact + digest；同键多次写入按 provenance 拆开 &#124;
&#124; CI / 并行测试 &#124; 每 job 独立输出目录与 Artifact 名，聚合器只读 &#124; 并行 job 写同一 coverage/报告/缓存真源 &#124; 单槽输出作废，重跑到绑 commit 的独立位置；**不采信被覆盖过的报告** &#124;
&#124; 跨 Task 共享缓存 &#124; 按输入摘要寻址、内容不可变、命中可校验、失败可丢弃重建 &#124; 把可变缓存当结果真源 &#124; 疑似互相覆盖的条目**一律丢弃重建，不尝试修复** &#124;
&#124; 大文件 / 二进制 &#124; 内容寻址存储，Git 记摘要、schema、来源和位置 &#124; 多人向同一路径覆盖上传 &#124; 以 digest 认主；取有 provenance 的那份，其余降为未验证参考 &#124;
&#124; 敏感产出 &#124; 加密/受控存储，最短保留期，日志脱敏 &#124; commit、PR、Artifact 或聊天中保存凭据 &#124; **按泄露处理**：轮换凭据、清理副本与日志、记暴露窗口；**不能靠删文件了事** &#124;
&#124; symlink / 路径别名 &#124; 写前解析规范路径并确认仍在获准 writable root 内 &#124; 利用软链、&#96;..&#96; 或挂载别名写出 owner 空间 &#124; 核对实际写出的规范路径；越界按覆盖事故处理 &#124;
&#124; 外部发布 / 数据库写入 &#124; 唯一 side-effect owner + 幂等键 + fencing + 回执 &#124; 因代码分支隔离就允许多候选同时写生产 &#124; 查副作用账按幂等键判是否重复；需要时补偿，**不靠重跑覆盖** &#124;
&#124; 多执行者推远端 &#124; 各推自己的远端 ref；integrator 独占发布 ref &#124; 共推同名远端分支，non-fast-forward 后 force-push &#124; ⚠ **不要强推回滚**。报告有权主体，由其决定 revert 或冻结该 ref &#124;
&#124; PR 评审后新增 commit &#124; 原评审绑定旧 commit；新 HEAD 重触发受影响门禁与评审 &#124; 沿用旧批准声明新 commit 已通过 &#124; 原批准作废，新 HEAD 重跑 &#124;
&#124; 候选迟到 &#124; 标 &#96;STALE&#96; 只读保留；需要时新开改进单元 &#124; 写入 final path、覆盖已选 commit、再执行副作用 &#124; 同左；**源仍是 commit** &#124;
&#124; 失败 / 取消 &#124; 冻结失败现场和已产出对象，盘点副作用，再按策略回收 &#124; 先删 worktree 导致无法复盘 &#124; 先冻结再回收；已删的现场按证据缺口登记，**不补造** &#124;
&#124; 执行者崩溃 &#124; 新执行者从 manifest/checkpoint 和固定 commit 恢复到新 worktree &#124; 盲接旧进程的半写目录 &#124; 不接管半写目录，重建 &#124;
&#124; 已交卷 commit 需修改 &#124; 新 commit；旧哈希仍报给评审并记 &#96;supersedes&#96; &#124; &#96;commit --amend&#96; 改写已被他人读过或已交卷的提交 &#124; 原 commit 仍可达则继续作评审对象；新哈希标冻结后修订，**不静默替换** &#124;
&#124; 两执行者提交到同一分支 &#124; 不应发生——派工时 &#96;exclusive_branch&#96; 互斥 &#124; 共用 &#96;tmp&#96;/&#96;new&#96; 这类分支名却不拆所有者 &#124; 停写；按作者拆成两条分支，原分支冻结 &#124;
&#124; 从共享目录拷走他人未提交稿 &#124; 不拷。交卷只经收集到的 commit &#124; 把别人的草稿当自己的起点 &#124; **该路不再计作独立候选**；记录污染来源与时间窗口 &#124;
&#124; 整合时误拷工作区文件进共享主仓 &#124; integrator 从**选定 commit** 取内容 &#124; 把任何人的未提交文件复制进共享主仓 &#124; 从主仓撤出，改从 commit cherry-pick/merge；撤出前先确认没覆盖他人内容 &#124;
&#124; 只读探索 &#124; 不写；或只写一次性抛弃分支且不推送 &#124; 探索性改动混进实施分支或共享主仓 &#124; 探索提交不进选优，除非任务包事先允许 &#124;
&#124; 跨机 / 新会话接手 &#124; 只凭分支 + commit 恢复；cwd 必须是自己的 worktree &#124; 凭「上次写在共享目录里」接着写 &#124; 先看 &#96;worktree list&#96; 与 &#96;status&#96;；共享工作区里的未跟踪文件先按覆盖事故处理 &#124;
&#124; master/main 发布 &#124; 仅 integrator 在最终验收并获授权后更新 &#124; 每个候选直接向 master/main 写 &#124; 未经整合的写入撤出发布面，从选定 commit 重走整合与 final gate，**不在发布面上就地修补** &#124;

</pre>

**G-036** · 源 agent-dev-guide.md，L863–L892；SHA-256 ed2f923f74dfcd7b77d60e3d121ea7a3a58b81f3dbedc356ef9d02a27706a26b

<pre data-unit="G-036">### 3.8 覆盖或来源不明时的事故规程

⚠ **后到者赢在任何场景都不成立。**磁盘上的最后一版、时间戳最新的一份、最后推上去的那个
ref，都不因为「在后面」而获得正确性或所有权。**覆盖发生后唯一有效的认主依据是 commit、
digest 和 provenance。**

这是唯一一套事故规程，两档入口。

**四步前门**（单文件被覆盖、来源基本可判、无外部副作用、无发布竞争）：

1. **保全现场**：停止对该路径一切写入，先记录，不删除、不 reset、不 checkout；
2. **恢复归属**：从 Git 对象、reflog、Artifact 或备份取回各版本，各自恢复为归属者的独立
   分支或 owner namespace，交还归属者；
3. **判定关系**：由**非当事方**判定两份是重复、互补还是无关，据此取一、合并或都保留；
4. **留痕**：把覆盖窗口、受影响对象和恢复依据记入证据账。

任一条不成立——来源不明、涉及发布面或远端、已产生外部副作用、同一路径反复被改——
**立即升级为八步，不要在四步里硬撑**。

**八步完整规程**（内容、大小、hash、mtime、HEAD 或作者特征与预期不符时）：
① 停写（含自动格式化/生成任务）② 保全（记路径、stat、hash、&#96;git status&#96;、HEAD、进程）
③ 分流（各版本存进各自 namespace 或不可变 Artifact）④ 溯源（依 commit、checkpoint、
manifest、工具事件和内容特征判断；**mtime 只作线索**）⑤ 恢复（优先从 owner commit、
Git object、Artifact、备份）⑥ 裁决（由 integrator 决定选用/合并/全拒，
**不由最后写入者自动获胜**）⑦ 回归（在新 final commit 重跑门禁）⑧ 记录（覆盖窗口、
受影响对象、恢复依据、防复发控制）。

⚠ 来源无法确认时，**文件不得进入 final**；能恢复内容但不能恢复 provenance 时，
只能作为未验证参考。事故处理中**不得为了「恢复干净」破坏用户或其他执行者的未提交内容**。

</pre>

#### 停止与恢复入口

**G-037** · 源 agent-dev-guide.md，L893–L913；SHA-256 bb61516bfa712e89efdafac5e0308c04c34edfb2e14239bf2b0ba1e24482154f

<pre data-unit="G-037">### 3.9 冻结、迟到与取消

候选、评审、改进、最终结果和验收绑定不可变 commit。冻结后替换必须产生新 commit 并登记。
主线采纳后的在途结果标为 &#96;STALE&#96;，不得覆盖主线、执行副作用或推翻已交付结果。

**迟到判定分两层，机制不同，不要混用：**

&#124; 层 &#124; 判定依据 &#124; 机制在哪 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **产品侧**（Attempt 写回、副作用、终态提交） &#124; Task/Attempt 状态、租约与 fencing token &#124; 内核的目标合同。本文只引用，不重新定义 &#124;
&#124; **开发侧**（候选、评审、改进、整合） &#124; 冻结 commit、候选状态、冻结时间戳 &#124; 本文。⚠ **开发侧没有租约机制**：整合方吸收前必须显式核对四项——候选状态仍有效（非 &#96;STALE&#96;/&#96;SUPERSEDED&#96;/&#96;REJECTED&#96;）、commit 仍可达、提出方未撤回、基线未失效 &#124;

⚠ **核对的对象是 commit 与候选状态，不是分支。**分支是可移动的运输通道，
「commit 还在某分支上」既**不必要**（可达即可核对）也**不充分**（分支可被重置或强推）。
把开发侧迟到写成租约，会让人误以为有一个运行时会自动拒绝迟到写入——没有。

取消：先持久化意图，再停止调度、撤销租约、终止执行、盘点副作用、固定需保留的 commit 和
Artifact，最后回收 worktree/sandbox。**取消与完成只能一个终态胜出。**
产品面的过期写入应由 fencing 拒绝；**开发面（分支、worktree、发布路径）没有等价运行时机制**，
只能靠条件式发布和整合方核对挡住，因此**开发侧的取消必须显式停止执行者，不能只靠标状态**。

</pre>

**G-041** · 源 agent-dev-guide.md，L1009–L1041；SHA-256 16e8e7631c81e3edee54124fdfb72ab85b66a634692ef66dd3ba5ca026814ca7

<pre data-unit="G-041">### 3.13 执行形态、停止规则与成本

档位（&#167;3.4）定 guard，**执行形态**定这一次实际怎么排人：

&#124; 形态 &#124; 适用条件 &#124;
&#124; --- &#124; --- &#124;
&#124; 单路实施 &#124; 解法明确、局部、可被测试充分判定 &#124;
&#124; 定向审核 &#124; 已有唯一产物，只需独立判断 &#124;
&#124; 最小选优 &#124; 需要独立候选，但无需完整评审团 &#124;
&#124; 完整选优 &#124; 解法不明确、跨层/跨仓、错误代价高 &#124;
&#124; **胜者改进** &#124; 主线已选，只吸收独立局部优点 &#124;

⚠ **选形态的人不能顺手改上层决定**：不得改动已落账的 RouteDecision、降低硬门禁、
换执行器、扩大权限或增加总预算（&#167;4.9）。

**停止规则（六条）：**

- 使用**足以产生独立信号的最少候选**；
- 顶层验收满足后，其余在途单元停止、取消或降为**无副作用只读参考**；
- 连续一轮没有关闭阻断问题或新增可验证价值时**停止**；
- 达到轮次上限仍有结构分歧时，**请 principal 裁决或重开 Task**；
- 单元耗尽预算**不得静默借用**；
- 协调者退出前留下可恢复 checkpoint。

⚠ **「已派工」「全部返回」「多数一致」都不等于完成**（&#167;3.12、&#167;11）。

**成本纪律：**

- 资源上限、超时、外部副作用和人工批准点**必须在启动前写入任务包**；
- **完整交叉阅读是二次复杂度**——候选较多时采用平衡分配，但**每个候选获得相同评审覆盖**；
- 无法运行命令的评审保留价值，但**必须标注「未经事实验证」**，且不能替代验收方的运行结果；
- 自动化必须保证**单路失败、超时或缺席也进入记录**，不能由成功路线覆盖。

</pre>

**G-050** · 源 agent-dev-guide.md，L1224–L1246；SHA-256 53cd1d043287258748072df7e549de0286b07184d9b762d50215a8262e23873a

<pre data-unit="G-050">### 3.22 停止、超时与回退不能省略

异议采纳且触及结构、验收失败、principal 打回，都回到③，重新冻结与验证；
同一轮回退超过两次就停止重整合，回到问题和标准本身确认，不无限重试。
预算停止规则仍见 &#167;3.13；不通过向参与方施加模糊时间压力来换取缺证据的半成品。

逾期使用已冻结的可观测判据。观察窗 &#96;W&#96; 由本轮实际交付用时的中位数得出，
不能拿一个临时秒数冒充；数据不足算不出 W 时，记录“不可判”并按已批准的停止规则处理，
不得自行据时钟宣布弃权。

&#124; 观测 &#124; 允许的结论 &#124;
&#124; --- &#124; --- &#124;
&#124; 产物字节或分支提交仍增长 &#124; 正在推进，不因派生时间线到点就宣布逾期 &#124;
&#124; 连续 W 内产物字节与分支无变化 &#124; 可按冻结的停滞判据处理，附两次观测与 HEAD &#124;
&#124; 零产出且 CPU 时间增量、输出增量均为零 &#124; 联合信号可提示卡住；CPU 绝对值为零不能证明未启动，等待网络也可能如此 &#124;
&#124; 没有足够观测或观察窗无依据 &#124; UNKNOWN，不是弃权、超时通过或同意 &#124;

延长观察窗可记录后执行，缩短须 principal 确认。宣布逾期前实际运行判据并保存观测。
各环节后果不同：①不交则候选数减少，降到一家时停轮；②评审不计但候选仍在池中；
④未响应按协议记弃权，**不是认可**；⑤验收方不可用则按同一算法换人；
⑥没有逾期默认，未经确认就不发布。只有冻结协议已允许的缺席处理才能直接执行，
额外免除参与方仍属 H3，不得把“超时处理”用作绕开授权的理由。

</pre>

### playbooks/review.md（P）

先准备可重取的批准对象，再评审证据，最后挑战判据自身；把人义务和评审盲区纳入同一次决定。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 批准对象与人的动作 | 人如何取得对象、履行义务和合法改判；权力表本体在 authority，不能从便利性推出新权限。 | G-063, G-061, G-059 |
| 七环节操作接口 | 任务尺度的流程串联及取件操作；保留 protocol 权威声明，本组不成为另一套七环节规则。 | G-047, G-049 |
| 验收与整合 | 测试层次、证据最小集和事实/选择的区分必须一起读；不存在用票数替代证据的入口。 | I-003, G-070, G-072, G-075 |
| 检查的反例与复核 | 检验前提、控制面和判据本身；历史实例留作反证，不当作今天已复跑的结果。 | G-014, G-077, G-104, G-105, G-106 |
| 覆盖声明的写法 | 区分查了、没查、不能排除以及三类未知；必须进入可复用规程，原作者未核清单只作带日期例证。 | G-097 |

#### 批准对象与人的动作

**G-063** · 源 agent-dev-guide.md，L1580–L1604；SHA-256 563da4808b1ebe3b5370f2b2cb9d728cfb24c754e5bb555645c5553059fa4201

<pre data-unit="G-063">### 4.12 人的收件箱：让批准具体、可读、可重取

收件箱是 Interaction 的人读投影；产品态以持久 Interaction 为真源，手工态以冻结通知和
追加的决定记录承载同一形状。终端、桌面或 IM 通知丢失不应丢失待决事项。

&#124; 展示项 &#124; 必须表达什么 &#124;
&#124; --- &#124; --- &#124;
&#124; 问询定位 &#124; interaction id、Task、适用权力行/合法转换、被询问主体 &#124;
&#124; 待决内容 &#124; 具体要决定什么、选项的后果、当前证据等级和未知项 &#124;
&#124; 决定对象 &#124; 需要批准时展示 target commit/Artifact digest、实际 diff 摘要；H1/H5 附冻结验收条及其结论 &#124;
&#124; 时效 &#124; 到期/失效判据与目标状态版本；过期不等于拒绝或默认同意 &#124;
&#124; 决定记录 &#124; 经鉴别主体、响应、实际生效值、原建议与改动、消费结果；不能只有“已消费”布尔 &#124;

**无默认的决定不得预填为已同意。**验收、档位、参与方可展示 proposal 供人判断，
但 effective 值只能来自明确决定或 H1/H2 明确允许的已批准策略；未作决定仍为空。
这与 &#167;2.4 保存 route_proposal 不冲突：展示建议不等于提前填好批准。
工作区和预算窗等允许预填的项，也同时保留原值和实际采用值。

H1 冻结标准，H5 批准实际动作；同一次人机触点涉及多条权力时逐条绑定，不能只写一个“同意”。
需要批准的对象发生版本变化，旧批准不能自然延续。无法鉴别身份的手工记录仍标 reported，
不因“已落盘”升为 attested。

每次记录响应耗时、相对建议修改项数、各类触点次数，供人判断流程摩擦。
这些是观察值，不自动触发降档、减检查或扩大自动批准范围。

</pre>

**G-061** · 源 agent-dev-guide.md，L1528–L1548；SHA-256 ce0a5dbc876c30cf0becf43ebfc12696912840099a1f68e3db9a117244921002

<pre data-unit="G-061">### 4.10 人这一侧的义务

⚠ **不只是执行者有纪律。人这边同样有，而且被违反时后果更大——因为 agent 会照做。**

&#124; 人的义务 &#124; 违反会怎样 &#124;
&#124; --- &#124; --- &#124;
&#124; 请求写清**边界**：含什么、不含什么、不含的归谁 &#124; 执行者会自行扩大范围，或漏掉本该做的 &#124;
&#124; 给**可判定的验收标准**，不给倾向性结论 &#124; 候选向你的结论收敛，**等于白问** &#124;
&#124; 并行提案时**不泄露其他方案** &#124; 独立信号退化成改写（&#167;2.11） &#124;
&#124; 派活前先建好各自的 worktree 和命名分支 &#124; 多个执行者写同一工作区，后写覆盖先写（&#167;3.6） &#124;
&#124; 收到「我不确定」时**不追问到它给出确定答案** &#124; **逼出的确定性是编的** &#124;
&#124; 执行者说「没查过某处」时**当作真话对待** &#124; 声明盲区的动力被消灭，下次它不说了 &#124;

⚠ **最后一条最容易被忽略：盲区声明是自愿的，只要说了就受罚，很快就没人说了。**
这与 &#167;9.2「如实写『不能排除』不扣分，隐瞒才扣」是同一条规则的两侧——
一侧约束写的人，一侧约束读的人。

**委派转移的是执行，不是最终责任。**派活时必须给出范围、权限、预算、停止条件和可验收
输出；对超范围、追加成本、不可逆动作和规范修改及时批准或拒绝；**亲自验收，或指定未参与
实施的验收方**（&#167;4.5 责任归属表）。

</pre>

**G-059** · 源 agent-dev-guide.md，L1481–L1508；SHA-256 f4d2a4877ae39fb419899e9b99fda4d254fa67b09bca7d8f847c4ed9fea81ba2

<pre data-unit="G-059">### 4.8 principal 的裁量权与改判纪律

人可以判断「这件事不值得走全流程」，执行者不可以。但裁量有底线，**五条不因规模而豁免**：

1. 不篡改原始意图；
2. 不越过权限与范围；
3. 结论有与风险相称的证据；
4. 「完成」可判定；
5. 发生改判时，交代触发与变化。

⚠ 省略任何一步都必须**显式写出「不适用」及理由**——**空着与「忘了」无法区分**。

**什么时候不能简化**：涉及安全边界、数据迁移、跨 App 契约、不可逆外部动作、生产发布——
这几类无论多小都走完整流程（与 &#167;2.5 的 T2 触发条件一致）。

**改判三要素。**人比 agent 更容易改判——信息多、判断在变。
⚠ **改判本身不是问题，装作没改过才是。**每次改判必须写清三件事：

&#124; &#124; &#124;
&#124; --- &#124; --- &#124;
&#124; **触发** &#124; 什么新证据或什么情况变化 &#124;
&#124; **原判断错处** &#124; 当初**哪一句**不再成立——不是「当时信息不全」，是具体哪一步推错了 &#124;
&#124; **新判断** &#124; 现在以什么为准；**能独立成立**，不写「理由见上文」 &#124;

不得装作从未判过，**也不得为了让检查变绿而静默删除旧标准**。修改验收标准时保留原标准、
原始失败输出和改判理由。把结论写进上游文档前**回读代码或实物重新取证**——
⚠ **文字改对了、代码里还是旧的，比不改更糟。**

</pre>

#### 七环节操作接口

**G-047** · 源 agent-dev-guide.md，L1131–L1168；SHA-256 9a75c4f5c2881bf38f7c6be38a7b1d4df0a406c0834a8050f41b68beea14c609

<pre data-unit="G-047">### 3.19 T2 七环节的操作闭环

本节承接历史稿的流程导读，并按本次基线的 round-protocol 校准路径与时序。
只在工单判为 T2 时使用；T0/T1 按 &#167;3.4 执行。协议仍是流程真源，
某轮正式裁定的特例必须随工单明确给出，不能把旧轮特例当通用规则。

&#124; 环节 &#124; 谁做与交付什么 &#124; 进入下一步的条件 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; ① 提案 &#124; 各 proposer 在独占工作区产出候选；冻结自己的 commit、文件摘要和覆盖声明 &#124; 候选冻结前不读他家方案或发起方倾向；全部取件对象可枚举 &#124;
&#124; ② 互评 &#124; reviewer 写自述、候选集冻结、全部候选比较、其他稿值得吸收的具体主张 &#124; 包括自己的候选；利益冲突明示；缺候选不能报全体评分；事实按证据裁 &#124;
&#124; ③ 裁决 &#124; arbiter 从选定 commit 取基座；一条独立主张一个提交，形成处置记录 &#124; 每条接受/部分接受/拒绝均有独立理由；部分接受写清边界 &#124;
&#124; ④ 异议 &#124; 被处置到的来源方核自己主张；提交条目、为什么错、应当是什么、可复跑证据 &#124; 无异议明确记录；异议不是否决权，裁决方须逐条回应；实质改结构回到 ③ &#124;
&#124; ⑤ 验收 &#124; 独立 acceptor 对冻结最终版本逐条验收 &#124; 标准疑似过期则附理由交裁决/请求者处理；不自行改标准；不通过回 ③ &#124;
&#124; ⑥ 确认 &#124; principal 读取可检视的最终对象，批准具体不可逆动作或打回 &#124; 显式批准并绑定版本，不能由“继续”或逾期默认代替；打回回 ③ &#124;
&#124; ⑦ 清理发布 &#124; 指定单写者按 &#167;3.15–&#167;3.16 收存证据、清理本轮私有产物，再发布 &#124; 目标版本比较通过、批准仍有效；只清理获准对象，不清空他家工作区 &#124;

**L0/L1/L2/L3 是验证职责，不是环节编号。**T2 的来源核对 L2 在④发生，必须先于⑤的 L1；
涉及正文改动后重跑 L0，随后独立验收。L1/L2 都完成才请求最终 L3。

处置记录包含固定三列：&#96;出处家 / 条目 / 裁定&#96;，裁定只能为接受、部分接受、拒绝。
验收方按以下顺序计算并记录结果：排除 arbiter 和基座作者；在其余参与方中取
“接受 + 部分接受”条数最少的一家；并列取候选行数最少者；仍并列由 principal 决定；
全部不可用由 principal 验收。若该轮经批准另设 integrator，按工单明确排除实际整合者。
不得因为不满意验收结果换人；因不可用换人按预先宣布的顺位与同一规则留痕。

设 &#96;R = rounds/&lt;round-id&gt;&#96;，路径均相对 &#96;dev-plan/&#96;：

&#124; 产物 &#124; 进行中位置 &#124; 收尾 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 候选 &#124; 各自工作区内与共享最终路径相同的相对路径 &#124; 需要保留时收存为 &#96;R/reviews/candidate-&lt;名&gt;.md&#96;，附原 commit/digest &#124;
&#124; 评审/异议/验收 &#124; &#96;R/reviews/review-&lt;名&gt;.md&#96;、&#96;objection-&lt;名&gt;.md&#96;、&#96;acceptance-&lt;名&gt;.md&#96; &#124; 按本轮保留决定收存，保持稳定取件索引 &#124;
&#124; 裁决稿 &#124; 整合工作区的最终相对路径 &#124; 最终批准后发布 &#124;
&#124; 处置记录 &#124; &#96;R/disposition.md&#96; &#124; 留来源、取舍、异议处置及验证引用 &#124;
&#124; 工单/通知/裁定 &#124; &#96;R/round.md&#96;、&#96;R/call-&lt;环节&gt;.md&#96;、&#96;R/rulings.md&#96; &#124; 工单状态由产物校验，历史裁定不覆盖 &#124;

不沿用旧稿把评审平铺到轮次根目录的命名；已冻结历史产物不为整齐而改名。
协议某处简写“清理”不授权丢掉本轮仍需交付、追溯或正在被引用的对象。

</pre>

**G-049** · 源 agent-dev-guide.md，L1199–L1223；SHA-256 48277b1472368a291220a2328bd092c834e4e957469070a731b5b1a7f363ff58

<pre data-unit="G-049">### 3.21 通知、取件与人的检视面

一个流程只有规定“怎么写”还不完整，必须规定“怎么取得同一版并读到”。
每个阶段的通知至少含：带 commit 的取件方式、对象路径与行数/摘要、范围与门槛、
交付路径，以及截止判据。④起把各方受到的处置公开列在同一份通知中，便于交叉核对。

&#96;&#96;&#96;bash
git show &lt;冻结commit&gt;:&lt;仓内路径&gt;
git diff &lt;基座commit&gt; &lt;整合commit&gt; -- &lt;仓内路径&gt;
git log --oneline &lt;基座commit&gt;..&lt;整合commit&gt;
&#96;&#96;&#96;

分支可作定位线索，实际取件用冻结 commit；跨分支对象写为 &#96;commit:路径&#96;，
不要构造只在其他 checkout 才存在的 Markdown 链接。
通知发布后不在同一阶段偷偷改输入；必须重定对象时记录原版本、理由、受影响方，
按协议重发通知或回退，不把旧评审套到新对象上。

**请求最终确认前，把检视面准备好。**可以直接给当前可读的冻结文件；
需要读另一分支时，由供给方在获准位置创建钉 commit 的临时检视 worktree，
给出绝对路径、最终差异、验收结论与盲区。只有“稿子在某分支”不构成可确认的交付。
检视 worktree 的只读性要靠权限或明确约定，&#96;--detach&#96; 本身并不禁止写入；用完按 manifest 清理。

组织者不得在参与方正写候选时同步或写入其工作区。环节之间经允许同步后，
还须检查命令退出码、&#96;MERGE_HEAD&#96;、未合并索引和各方产物摘要；不能丢弃输出后默认同步成功。

</pre>

#### 验收与整合

**I-003** · 源 implementation-plan.md，L27–L37；SHA-256 4bfef647952fad541626de7a6e3f6136bf69a1b06d31afc04f4af1df28e7105b

<pre data-unit="I-003">## 测试层次

&#96;&#96;&#96;
L1 Unit                    L5 Failure Injection
L2 Component Integration   L6 Evaluation/Quality
L3 Contract                L7 Deployment/Operations
L4 Cross-app E2E
&#96;&#96;&#96;

P0 / P1 任务必须写明适用层次。

</pre>

**G-070** · 源 agent-dev-guide.md，L1709–L1720；SHA-256 faeb607e2b006ad8db680a6ad2e1931de71a29b7427ee0af35584ac891588b97

<pre data-unit="G-070">### 5.5 四层验证

&#124; 层 &#124; 谁 &#124; 判什么 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; L0 &#124; CI / pre-commit / validator &#124; 链接、schema、冻结区、hash、diff、测试、角色冲突等机械条 &#124;
&#124; L1 &#124; 独立 acceptor（⚠ **既得利益最小的一家，由处置表算出**，不由谁指定） &#124; 冻结标准中机器判不了的内容；标准过期须交回裁决。⚠ **作者自检不能代替独立验收**；没有第二个执行者时由独立验收器或人验收，验收方**只能按冻结标准判定，不能为通过而静默改标准** &#124;
&#124; L2 &#124; 被处置主张的原作者 &#124; 是否被误读；异议必须带处置条目与可复跑证据 &#124;
&#124; L3 &#124; principal &#124; 意图是否正确、不可逆项、抽样复算证据真实性。⚠ **不逐行读——抽样规则写进工单**，否则「抽检」会退化成「翻一翻」 &#124;

顺序不可倒：L0 未过不进 L1，L1/L2 未过不请求最终批准。新增机器判据首跑必须与人工结论对照；
锚点存在但不支持断言，比没有锚点更危险。

</pre>

**G-072** · 源 agent-dev-guide.md，L1747–L1773；SHA-256 e6d1a3e5db32cda2fba1238e6706b181a3966981081a9f9e37094eadb12e5df2

<pre data-unit="G-072">### 5.7 证据账按流程分级

⚠ **不能只有「全套」与「零记录」两档。**

&#124; 流程 &#124; 最小留证 &#124;
&#124; --- &#124; --- &#124;
&#124; 单路实施 &#124; 请求记录或 PR 中固定最终 commit、验收方、门禁命令及原始输出位置 &#124;
&#124; 定向审核 &#124; 任务包链接、评审、处置、最终 commit 与验证结果 &#124;
&#124; 最小选优 &#124; 任务包链接、参与者清单、候选 commit 映射、决策、处置与验证结果 &#124;
&#124; 完整选优 &#124; 下列完整记录 &#124;

&#96;&#96;&#96;text
request          # 原始意图、边界、基线、门禁、资源上限
manifest         # 角色、参与者、耗时、状态、异常
candidates       # 匿名编号、commit、覆盖和验证声明
reviews          # 独立审、对照审、逐条主张裁决
decision         # 门禁、偏好评分、决胜与选定 commit
improvements     # 主张 ID、来源、commit、测试与冲突
dispositions     # 接受/部分接受/拒绝及证据
verification     # 最终 commit 上的回归结果
&#96;&#96;&#96;

载体可以分散，但必须由**一个稳定的主记录**串起全部链接，并**能由第三方读取**。
⚠ **任何流程都不得只在聊天中宣称测试通过；另一个人不能恢复和复核的内容视为未持久化。**
候选 commit 必须来自该候选自己的分支——共享工作区里的未提交文件、从别人路径拷来的稿，
**不得写入候选清单**。

</pre>

**G-075** · 源 agent-dev-guide.md，L1827–L1850；SHA-256 618f6398fc223c75f2be431ef82790c5dfdbb544978a7ff9b644d0fce7fab3f5

<pre data-unit="G-075">### 5.10 事实裁决表与整合纪律

**评审分两阶段**：先只读原始请求、匿名 commit 和统一标准**独立审**；冻结后再读候选自评、
盲区和验证记录**对照审**。评审必须写明 commit、覆盖范围、阻断问题、证据，
以及**哪些结论真的运行过**。

**先裁决事实，再谈偏好**：

&#124; 主张 ID &#124; 候选 commit &#124; 证据/命令 &#124; 结论 &#124; 理由 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;&lt;ID&gt;&#96; &#124; &#96;&lt;commit&gt;&#96; &#124; &#96;&lt;位置/输出&gt;&#96; &#124; **证实 / 证伪 / 未决** &#124; &#96;&lt;说明&gt;&#96; &#124;

⚠ 测试失败、违反硬约束或范围、存在阻断风险、commit/证据不可取得、隔离不可恢复的候选，
**不进入偏好评分**。**全体一致不是免检理由**（&#167;12）。只有合格候选之间才比较维护成本、
结构和命名；维度与权重**在候选产出前冻结**，结果称「**本轮选定**」，
**不称「已证明正确」**。

**整合纪律**：选定 commit 冻结为**只读基线**。局部改进从它建新 worktree，
⚠ **一条独立主张一个提交**；整体重写或耦合改动作为**新候选重开**。
整合方逐项记录接受、部分接受或拒绝**及证据**；冲突按原始请求、约束和证据解决，
**不按票数、作者或提交时间覆盖**。

⚠ **所有有效门禁必须在 final commit 重跑——候选的绿色结果不能证明整合结果正确。**

</pre>

#### 检查的反例与复核

**G-014** · 源 agent-dev-guide.md，L213–L234；SHA-256 a76bb2f085b13bbb4d867b4ffbe70d4f34ecefc6712e917127e6840bfdb936c3

<pre data-unit="G-014">### 1.7 先核前提，也核控制面

设计前留下一个可复核的最小记录：**要保护或自动化的动作 → 实际调用者 → 执行路径 →
使用的身份/凭据域 → 写入对象 → 现有库原语 → 缺口和反例**。每项附钉定版本的代码、
配置或运行证据；查不到就标假设，不据此宣布某方案已有效。

三项检查必须在方案比较之前发生：

1. 顺着真实消费者读调用链，核已有库能做什么；不能只读抽象基类、文件名或接口声明。
2. 对新增设施问“待控制的动作是否一定经过这里”；不经过的设施不能算该动作的强制点。
   查询远端 refs 只说明远端形状，不能证明历史上无人 push，也不能证明写权限被拒。
3. 架构题对照相关的已用库或外部实现，并允许提出“不需要新增机制”的答案；
   不把某个解法预写成必须通过的验收条。对照须有相同问题域，不能为了凑数量强塞一个产品。

**控制面不因负责裁决就天然可信。**router、orchestrator、validator 与裁决方的动作同样要
记录输入版本、适用规则、输出、改判和失败原因，并允许受影响方凭证据推翻。
过程控制权不能被内容整合权吞并；通知、截止与角色选择须由冻结工单及规则推导。
只审执行者、不审出题和判定前提，会让一套自洽的流程稳定地产生错误结论（&#167;12.2）。

方向不对称（P3）防的是自动化逐步滑向省事；它**不授权突破既有预算或范围**。
同类裁量反复出现时，记录命中的规则、例外与效果，按协议修订规则，不偷偷改代码默认值。

</pre>

**G-077** · 源 agent-dev-guide.md，L1899–L1915；SHA-256 a166660a821dba3bda24fbe05f896658bd5eb51187f628f8ff9c66f16e8af43a

<pre data-unit="G-077">### 5.12 检查本身也必须接受检查

每个门禁都输出 &#96;PASS / FAIL / UNKNOWN&#96; 的语义及 checked/not_checked。
缺输入、权限不足、枚举失败不能被吸收为 PASS；聚合器先判输入集合是否完整、非空是否为必需，
再聚合结论。**不让 &#96;all(&#91;])&#96;、空 diff、吞退出码或“0 个文件通过”代替完成条件。**

新增或修改门禁时至少核查适用的边界用例：正常通过、真正失败、输入缺失、命令失败、
空集合、引用对象不可达、否定句/历史引用。机器误报应区分解析问题与内容问题，
不能为了消掉一个红字删掉失败标准；假失败的安全方向也不是长期保留误报的理由。

文档复核分四层：链接/锚点可达；标题有对应；对应正文真正承载原主张及其边界；
证据本身支持该主张。**空标题、只有结论没有证据、映射到同名异义段落，都不算吸收。**
&#96;doc-gate&#96; 的链接和表格检查不能替代正文层与证据层；纯文本 &#96;文件:行&#96; 还要单独检查。

机械状态校验从明确的状态表取词与边，不对全文盲搜：历史反例、否定句和 Artifact 属性
不应被误认成产品状态。覆盖声明和不可判输入与结果并列，不让下游把窄范围绿色外推成完整正确。

</pre>

**G-104** · 源 agent-dev-guide.md，L2924–L2964；SHA-256 6c49a2dacc55dda60bb9e1cfe2805bf595d25509bd7a6c3d98a481613e27d312

<pre data-unit="G-104">## 12. 常见失败方式与项目实例

&#167;11 是机制，本节是**本项目实际遇到过的失败**，按**证据强度**分三级。
⚠ **三级不是修辞差别，是能不能独立复核的差别：**

- **已核对事实**：证据当前仍可独立取得并复核（commit、blob、文件存在性、可重跑命令）；
- **事故报告**：确实发生过，但现场已灭失，只能按当事方陈述记录，**不能独立复核**；
- **设计风险**：机制上成立，但本项目尚未实际踩到，或原始证据出处已不可取得。

⚠ **三级不可互相升格。**尤其**不得**把「机制上必然如此」当成「此处已核对」——
这正是 &#167;3.8 第 4 步要求的态度：**能证明的和推断出来的分开写。**

&#124; 失败 &#124; 证据性质 &#124; 控制在哪 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **隔离来自 worktree + 命名分支，不来自文件名** &#124; **已核对事实（2026-09-02）**：三方在各自 worktree 与命名分支上持有**同名且不带后缀**的同一文件，内容互不相同且**全部得以保留**，各自 commit 与 blob 可独立复核。故后缀**非必要**；又因同一工作树内两方写同一带后缀的路径照样互相覆盖，后缀亦**非充分** &#124; &#167;3.6、&#167;11 &#124;
&#124; **未提交的同路径写入没有任何保护** &#124; **已核对事实**：Git 对未跟踪/未提交文件的同路径写入不提供冲突检测、不留历史、不留作者归属。这是 Git 语义，**可随时复现** &#124; &#167;3.6、&#167;3.7 &#124;
&#124; 多执行者写进共享 checkout 造成覆盖 &#124; **事故报告（2026-09-02），现场已灭失**：当事方陈述有产出被后写覆盖。共享路径上的文件事后已被清走，**具体发生过哪一次覆盖、写入顺序和责任人均不可独立复核**，本表不作此断言 &#124; &#167;3.6、&#167;3.8 &#124;
&#124; 以工作区最后一版代替 commit 做交卷或比选 &#124; **已核对事实**：磁盘上的「当前文件」不携带作者归属，也不能证明谁先写完 &#124; &#167;3.7 &#124;
&#124; 只写分支名，不固定 commit &#124; **事故报告（2026-08-27）**：当事方记录评审曾引用旧提交而主方已前进；原始记录可取回，但其中**未找到**对应条目，**故不升为已核对** &#124; &#167;3.9 &#124;
&#124; 评审意见的处置边界由被审方单方划定 &#124; **已核对事实（2026-08-27）**：处置记录逐条由被审方判定采纳或拒绝，其中一条门禁因「三台机器分别报 0 / 4 / 95 条失败」被判为误报并删除。⚠ **「优胜作者拒绝改进」这一更强的说法未获记录支持，不采用** &#124; &#167;2.2、&#167;5.5 &#124;
&#124; 评审给出的验收标准无人回跑 &#124; **已核对事实（2026-08-27）**：处置记录末节自记一份验收标准「**未回跑**」、一份「**待评审方执行**」、一份仅第 3 条通过 &#124; &#167;5.5 L1 &#124;
&#124; 只测一端就宣布跨仓契约完成 &#124; **现行硬规则**（constraints C4）：单仓 CI 只跑自己那半，provider 改了、consumer 锁没跟，两边各自都绿 &#124; &#167;1.3 &#124;
&#124; 拿休眠代码当能力证据 &#124; **已核对事实**：一家以本仓休眠的 &#96;AgentProfile.permits_tool&#96; 佐证租用 SDK 的工具门，**九份评审无一发现** &#124; &#167;2.6、&#167;5.2、&#167;5.6 &#124;
&#124; 取证工具自身有边界而未声明 &#124; **已核对事实**：在助手自带沙箱内跑取证命令，&#96;/proc/self/uid_map&#96; 为 &#96;0 1003 1&#96;，于是沙箱内一切看起来都是 root，据此写出「本机所有进程都是 root」。⚠ **取证栏必须注明主机、执行身份、是否在沙箱内** &#124; &#167;4.4 &#124;
&#124; 把「某载体证不了 X」写成「X 未被证明」 &#124; **已核对事实**：见 &#167;7.2 的更正 &#124; &#167;7.2 &#124;
&#124; 候选提前读取其他方案 &#124; 设计风险：机理清楚，本项目原始记录出处已不可取得 &#124; &#167;2.2 &#124;
&#124; 多数票覆盖失败测试 / 全体一致的共同盲区 &#124; 设计风险：多个相似模型可能共享盲区 &#124; &#167;2.3、&#167;11 &#124;
&#124; 候选人互投决定胜负 &#124; 设计风险：结构上「被审方兼任判定方」已出现过，但候选互投这一具体流程尚未实跑 &#124; &#167;2.2 &#124;
&#124; 大补丁混合多条主张 &#124; 设计风险，尚未实跑 &#124; &#167;11 &#124;
&#124; 整合时拷贝未提交文件进共享主仓 &#124; 设计风险：绕过选定哈希，**主仓变成公共投稿箱** &#124; &#167;3.6、&#167;3.7 &#124;
&#124; 工作区回收后证据不可达 &#124; 设计风险：工作区是临时供给，**不是档案** &#124; &#167;3.5 &#124;
&#124; **完整选优流程本身** &#124; **本项目尚未完整实跑**：独立裁判、匿名随机评审和停止规则目前是制度设计，**不得写成既成能力** &#124; &#167;2.2、&#167;3.4 &#124;

⚠ **本表的分级本身就是纪律的示范。**2026-09-02 那一例被拆成三行：两行是任何人现在都能
复核的事实，一行是现场已灭失的事故报告。**不写「谁覆盖了谁」**——后者虽是当事方陈述且
机制上成立，但现场已被清走，按 &#167;3.8 第 4 步，mtime 与「最后一版」只是线索，不足以单独证明
写入顺序或责任人。

纪律的效力不依赖那次覆盖是否可复核：前两行已核对事实足以支撑 &#167;3.6 的全部要求。
⚠ **用不可复核的叙述去加强一条本来就成立的规则，只会削弱整份文档的证据标准。**

</pre>

**G-105** · 源 agent-dev-guide.md，L2965–L2983；SHA-256 b7f6e4d275133d47944344e5ae8cfa701798e94506a0df83a5e8945928bf59ba

<pre data-unit="G-105">### 12.1 七种“检查给出假答案”的回归线索

以下七例来自历史融合稿的事故汇总，**本次只核其文字与底稿的相容性，未重跑历史现场**。
数字表示七类边界案例，不据此推断全部事故数量。保留失败机制与修复判据，
不把原作者自述冒充本次独立证据。

&#124; 边界案例 &#124; 错误结论怎样产生 &#124; 开发时如何核 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 验收方集合为空 &#124; &#96;all(&#91;])&#96; 为真，被当成完成并跳过验收 &#124; 先验证应有参与方/产物数量，再聚合；未指定不是通过 &#124;
&#124; 身份命令在仓外运行 &#124; 失败被管道吞掉，后续从错误文本生成假目录名 &#124; 每个依赖命令检查退出码；仓库根取不到就停止 &#124;
&#124; 身份判别失败后按产品猜人 &#124; “运行在某产品”被推成“属于某参与方” &#124; 对照已登记工作区和工单身份；产品映射不能充当身份凭据 &#124;
&#124; 机械检查读到否定句 &#124; “内核没有这条边”被误判为声明了一条非法边 &#124; 从规范定义块/schema 取状态；负例与历史说明不混入合法集合 &#124;
&#124; 两层调用各吞一个错误 &#124; 内层失败被外层成功掩盖 &#124; 原始退出码逐层传递；不以 &#96;true&#96; 兜底伪造成功 &#124;
&#124; 文档门禁只查 Markdown 链接 &#124; 被裸 &#96;文件:行&#96; 引用的文件删了，门禁仍绿 &#124; 并查裸路径、钉版锚点和可重取来源；声明两类覆盖差异 &#124;
&#124; 标题保留而正文被切掉 &#124; 空节不产生坏链接，链接门仍绿 &#124; 对照源段的主张、条件、反例与未验证项，不能只数标题 &#124;

假通过会成为下游继续执行的依据，比一次明确的失败更危险；判不了时停在 UNKNOWN。
假失败也要通过解析修复消除，不能长期靠人工忽略门禁。

</pre>

**G-106** · 源 agent-dev-guide.md，L2984–L3003；SHA-256 381fb92de6fa781025d41d6c9ec76cdae078e7115f69a62ccc1df1ebe05c2da9

<pre data-unit="G-106">### 12.2 并行评审的收益与盲区

历史记录显示，评审能发现局部自相矛盾、非法状态边、归属错误和证据不足；
但共同前提错误或被任务书封死的答案空间，可能通过多轮评审仍不被发现。
“必须包含某机制”如果被冻成标准，“其实不需要该机制”就无法作为合格答案提交。
增加候选数不能修复这种出题错误。

因此架构题的输入要包括硬约束和发展方向，给出可复核问题、客观完成判据与完整源集；
对已有库/实现作相关对照，允许用证据质疑机制必要性，不给出题方的倾向性结论。
缺列的源材料不能在验收时突然用来扣分；发现输入边界有误，先留痕并重定工作单元。
需要挑战冻结标准时按 H6 处理，不偷偷让标准迎合候选。

⚠ 历史稿对“休眠代码被几份评审发现”的叙述存在不同口径，本次不拼接成新的精确统计；
可保留的结论是**评审自洽性、行号存在性与生产链接线是三种检查**，缺一不能宣称当前可运行。

来源方异议负责检查整合是否忠实，独立验收负责检查产物是否满足标准，两者不可互代。
定向审核先独立审，再给产出方的自评和盲区对照：既找产出方遗漏，也检查审核方遗漏。
通过只意味着按所述范围完成了一次检视，不能估计未发现缺陷为零。
控制面自身的裁定、冻结、通知和验收也受同一证据纪律约束（&#167;1.7）。

</pre>

#### 覆盖声明的写法

**G-097** · 源 agent-dev-guide.md，L2253–L2298；SHA-256 0a079a71396c458e46c7745662236aa1fa4f374fd341d85f773d6f5d5690e37f

<pre data-unit="G-097">### 9.2 没查什么

⚠ **这一节还要能装下「不确定」**，不是只装「查了」与「没查」两档。
凡出现「**我不能排除**某事发生过」的情形，就如实写进来，
**不要因为它难看就压成「没查」**——两者的含义不同：

&#124; 写法 &#124; 含义 &#124;
&#124; --- &#124; --- &#124;
&#124; 查了 &#124; 有观测，有结论 &#124;
&#124; 没查 &#124; 没有观测，**明知自己不知道** &#124;
&#124; **不能排除** &#124; **有观测但不足以定论**，或存在自己控制不到的路径 &#124;

**「没查」还要按类别分列，不能混成一段。**三类的性质完全不同，混写会让读者
以为环境事实与外部授权是同一种不确定：

&#124; 类别 &#124; 例 &#124; 性质 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **宿主恒等** &#124; &#96;hostname; id; cat /proc/self/uid_map&#96; &#124; **可当场复跑**；没查是因为没跑，跑了就有结论 &#124;
&#124; **远端与授权** &#124; &#96;git ls-remote --heads/--tags&#96;；分支保护、部署 key、账户公钥 &#124; 部分可读、**写授权不可只读验证**（&#96;ls-remote&#96; 是读取，不是 push dry-run） &#124;
&#124; **执行者内部** &#124; GUI 里选的模型、沙箱内的工具调用 &#124; **结构上够不着**，换个接入方式才可能有结论 &#124;

第三类是唯一「不改变接入方式就永远查不了」的。**把它和前两类并排写成「没查」，
会让人以为再跑几条命令就能补上**——不能。

**如实写「不能排除」不扣分，隐瞒才扣。**本项目已有实例：某轮一份产物在覆盖声明里
主动披露「某个规划子代理可能经宽泛搜索见过被禁读的文件，无访问记录」——
它没有把不确定性压成「未读」，因而该条被裁决记为**范本**，而非违规。


- 没有登录 GitHub/Gitee 管理面，未核 deploy key、branch protection、账户公钥或 remote 的实际写授权；
  &#96;ls-remote&#96; 是读取，不是 push dry-run。
- ~~没有读取外部 &#96;codex&#96;、DeepSeek Harness、OpenClaw 仓的具体实现行号；本稿不据它们宣称工具级能力。~~
  ⚠ **该条已于 2026-09-07 被 &#167;9.4 的吸收轮取代**：&#167;2.6–&#167;2.10 与 &#167;5.6 现在**确实**据这三个仓的
  实现行号宣称工具级能力。**本节其余各条仍是 &#96;runtime-refact&#96; 轮成文时的声明，不改写**——
  改写他人的覆盖声明等于伪造取证记录。本次新增的覆盖与盲区一律另列于 &#167;9.4。
- 没有复跑产品数据库迁移、API、SSE、预算账或证据账测试；相关现状只按允许输入引用并标为现状。
- 没有穷读三轮每份候选和评审全文；读取了归档索引、处置/验收结论与本题相关证据。因此本文不重做
  旧轮排序，也不声称旧轮所有来源主张均已重新验证。
- 没有验证 GUI 内模型、内部工具调用或沙箱之外的文件读取；这些保持 ⚠ / &#96;UNKNOWN&#96;。
- 依仓库 &#96;AGENTS.md&#96; 强制入口，在读本轮任务书前读了未列入只读输入的
  &#96;working/development-lifecycle-agent.md&#96;。这是本轮输入边界偏差；本文不把它作为断言锚点，也未据其
  结构起稿。除该项外遵守了任务书的禁止读取和提案隔离。
  ⚠ **2026-09-07 后记**：这条自报是对的，而**真正的错在任务书**——它把该文与
  &#96;development-lifecycle-human.md&#96;、&#96;agent-dev-refact.md&#96; 共 197 节划到只读输入之外，
  于是整合者守规就必然丢内容。&#167;9.4 的吸收轮补的正是这一笔。

</pre>

### playbooks/delivery.md（P）

将完成判据置于写最终路径之前，将发布与 GC 置于其后；交付不是退出进程时顺手清理。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 完成与证据包 | 先证明任务完成和跨仓交付满足条目要求；不以脚本退出码单独证明完成。 | G-040, I-004 |
| 发布与保留 | 三个路径、发布动作、清理失败和 GC 明确顺序；进行中任务停止规程另见 execution。 | G-043, G-033, G-044 |

#### 完成与证据包

**G-040** · 源 agent-dev-guide.md，L988–L1008；SHA-256 4f741d49d296371394e3dab53fdbccc1849ae2f28efd9d77e9b23b68db599a31

<pre data-unit="G-040">### 3.12 完成判据

⚠ **十三条同时满足才叫闭环**，缺一条都不能笼统说「完成」：

1. 受理幂等，原始请求与规范化 Task 可追溯；
2. 载体路由（是否建 Git 工作区）有依据；复杂 Task 的工作区、Git 与 manifest 可复现；
3. 范围、验收、权限、预算、批准点和基线已冻结；
4. 执行者接单核对了工作区、指令、租约和输入（&#167;3.10）；
5. 按风险执行，角色冲突已处理（&#167;2.2）；
6. 每个产出有 owner、namespace、状态、provenance 和**唯一** publication target/integrator；
7. 候选**没有**直接写共享路径或 &#96;master/main&#96;，发布只从独占整合面发生；
8. publication target 通过**预期 HEAD/version 的原子条件更新**，发布竞争没有变成静默覆盖；
9. 并行结果绑定 commit，迟到、失败和取消已处置（&#167;3.9）；
10. final commit 上全部门禁和验收**逐条**通过；
11. 结果、证据、副作用、盲区和风险已持久化；
12. 提交唯一终态，请求方可重取结果；
13. Git 对象和 Artifact 可达、血缘可追溯且无活跃引用后，工作区才清理。

⚠ **缺项时只能称「已受理」「已物化」「候选完成」「本轮选定」「待验收」「交付待重试」
或「清理待处理」——不能笼统宣称完成。**这条对应 &#167;11 的「『已派工』或『全部返回』当作完成」。

</pre>

**I-004** · 源 implementation-plan.md，L38–L52；SHA-256 76c0139479c95502f5a7c9259b4910d46f51f9a97aa4053f9cc09a252c813609

<pre data-unit="I-004">## 交付规则

**分支与提交**——父仓不得出现悬空 gitlink（规则 T4）。五仓同步用
&#96;~/five-repos-sync/sync-five-repos.sh&#96;；它只推父仓，子仓的提交仍须自己推，
否则同步在拉取侧对齐子模块时报错。

**证据**——完成的任务在 &#96;docs/evidence/&lt;task-id&gt;/&#96; 留去敏后的：&#96;result.md&#96;、
测试输出、关键 request/response、migration revision、image digest。
**不得提交 token、Cookie、数据库密码或 API key。**

**单一权威**——架构语义以 &#91;&#96;development-plan.md&#96;](development-plan.md) 为准，
本文件只描述执行增量、依赖与验收；API/Schema 以各仓 &#96;contracts/&#96; 发布物为准，
本文件里的字段只用于解释，不作为机器契约。
**发现重复且可能漂移的定义时，删副本改引用，禁止两处同步维护。**

</pre>

#### 发布与保留

**G-043** · 源 agent-dev-guide.md，L1055–L1077；SHA-256 4f09aeba0065f8045a94dc22065670208adf84af2a6184df0487983daa92334c

<pre data-unit="G-043">### 3.15 发布协议：三个路径不是一个

用户要 &#96;path/to/result.md&#96; 时，必须区分三个东西：

&#96;&#96;&#96;text
candidate path:   每个 owner worktree 内的 path/to/result.md
publication path: integrator worktree 内的 path/to/result.md
published ref:    final commit / PR / release
&#96;&#96;&#96;

候选作者只提交自己的相对路径，**不直接把文件复制到共享 master**。选定或逐项整合后，
由**唯一 integrator** 从冻结 commit 取内容，在独占整合 worktree 写 publication path，
跑 final gate，再形成 final commit。是否推主线仍受 &#167;4.2 H5 约束。

⚠ **发布动作必须带预期版本**：Git 更新校验目标 ref 仍指向 integrator 开始时记录的 commit；
文件或对象存储用版本号、ETag、generation 或等价 compare-and-swap。目标已变化时
**发布失败并创建新的整合 Attempt**：读新基线、重解冲突、重跑受影响门禁，再尝试。
**不得以 force-push、无条件覆盖上传或先删后写绕过竞争。**发布重试用稳定幂等键；
「内容相同」也要保留本次发布回执和 provenance。

⚠ **若请求方明确只要多个可比较草案**，publication target 就是**候选集合及其 manifest**，
不是某个候选抢占正式路径。只有在作出选择之后，才产生单一 final 文件。

</pre>

**G-033** · 源 agent-dev-guide.md，L767–L781；SHA-256 8627c4ddde0c570cfe17bb68388093ac245731bc8910b56be3b3e3b6da6dda53

<pre data-unit="G-033">### 3.5 交付、清理和恢复

validator 先跑机械条，acceptor 再判机器判不了的冻结条；验收失败在预算允许时产生新 Attempt，
不得改窄标准换取通过。不可逆动作由 principal 确认后，publisher 才写共享最终路径或生产面。
结果、验收、预算结算和终态事件必须原子提交或用不暴露半成品的等价协议；Delivery 只在之后通知，
断线可按 cursor 回放并按 Task 重新取得结果（产品 &#96;F-ACCEPT-01&#96;–&#96;03&#96;、&#96;F-DELIVERY-01&#96;–&#96;10&#96;，
&#96;request-lifecycle.md @ ed0b5136:398-440&#96;）。

开发分支清理只删本轮私有产物；主线原有文件不能在候选分支里为“整洁”而删。需要删除旧权威稿时，
先完成逐节迁移、引用清零、门禁、T0/T1 实跑与人工确认；Git 历史可恢复不等于新读者能找到。

清理还须销毁短 TTL 令牌和敏感缓存，按 manifest 回收临时分支、工作区与构建缓存。
需保留的失败现场登记保留期限、权限和责任人；删前确认 commit 可达、摘要可重验、没有活跃引用。
**清理失败单独告警与重试，不能把已成功 Task 改成失败**；Delivery 通知失败也同样处理。

</pre>

**G-044** · 源 agent-dev-guide.md，L1078–L1092；SHA-256 8a8209e1eadd334cc1899b9a6849716663ec3b4dfff7ea2e45545f71e3a60b5e

<pre data-unit="G-044">### 3.16 保留与垃圾回收

&#124; 状态 &#124; 默认保留 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;SELECTED&#96;/&#96;INTEGRATED&#96;/&#96;PUBLISHED&#96; &#124; final commit、来源映射、验收、证据、必要 Artifact &#124;
&#124; &#96;REJECTED&#96; &#124; 候选 commit/digest、拒绝理由和必要证据；可按期限清理工作目录 &#124;
&#124; &#96;STALE&#96;/&#96;SUPERSEDED&#96; &#124; 血缘和摘要；是否留全文按审计/复用价值决定 &#124;
&#124; &#96;FAILED&#96; &#124; 最小复盘证据、副作用状态和可恢复 checkpoint &#124;
&#124; &#96;CANCELLED&#96; &#124; 取消依据、已产生副作用、需补偿项和保留对象 &#124;
&#124; 敏感临时物 &#124; 达到最短业务/审计要求后**尽快安全销毁** &#124;

⚠ **垃圾回收是显式阶段，不是执行者退出的副作用。**删除前必须逐项验证：
发布结果可重取；所需 commit 可达；Artifact 摘要可校验；副作用已收敛；
没有活跃 Attempt 引用；保留期限已满足。清理记录至少含操作者、时间、对象、依据和失败项。

</pre>

### playbooks/maintenance.md（P）

先续接同一个任务，再判断资产是否可迁移，最后用显式修订单处理内核；三者都保护跨会话的连续性。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 续接 | 用于换会话仍可恢复真实任务上下文；不能把聊天摘要变成新的事实源。 | G-088 |
| 迁移与修订 | 可复用删除门及内核修订步骤；G0–G5 的当前实施依赖留 work，不能删掉仍未满足的条件。 | G-086, G-090 |

#### 续接

**G-088** · 源 agent-dev-guide.md，L2104–L2139；SHA-256 fbce68888fc963570a13cafb2503c93bfc0573c2284c556f83d0809a14ba595d

<pre data-unit="G-088">### 7.5 跨会话续接

⚠ **判据只有一句：把今天的记忆抹掉，另一个人只读持久载体能否接着做？不能，就是没落盘。**

- 当前推进哪件事、卡在哪、下一动作，落在 &#91;&#96;handoff.md&#96;](handoff.md)，不落在脑子里；
- **「不能倒退的输入」必须写下来**——已经定过的事下次不重新讨论，这是 &#96;handoff.md&#96;
  最有价值的一节；
- 停下来之前，先让 &#96;handoff.md&#96; 能回答：「接手的人一分钟内要知道什么？」

⚠ **交接投影不是第二真源**，不得在 handoff 里复制整张覆盖矩阵。
checkpoint 是恢复输入，不是第二份代码真源，**也不保存凭据**。

⚠ **&#96;handoff.md&#96; 是单写者面。**多名执行者并行时只有协调者写它，各执行者的进度写在
**自己的 worktree** 里，由协调者投影上去。判据不是「内容重不重要」，而是
「同一事实只能有一个权威写入者」（&#96;I13&#96;，&#167;1.2）——**多人各自往同一份 handoff 追加，
就是在共享路径上并发写**。

同一判据对 agent 与人都成立，只是理由不同：**agent 是记不住，人是记得但传不出去。**

checkpoint 至少保存下面这些恢复输入，可用持久记录中的引用避免重复事实：

&#96;&#96;&#96;text
task_id, attempt_id, work_unit_id, owner_id, workspace_id
current_commit, baseline_commits, runtime_version, profile_version
completed_scope, remaining_scope, decisions + evidence_refs
commands/tests + raw_output_refs, budget_consumed + remaining
side_effects + idempotency_refs
output_namespace, publication_target, integrator
blocker, next_action, facts_to_revalidate
&#96;&#96;&#96;

恢复前重新确认 Task 未终态、当前授权仍有效、租约/fencing 有效、输入/基线/依赖未漂移，
并先查预算与副作用账；失租的执行者不能因拥有 checkpoint 继续写。
现场快照的 digest 与 runtime/Profile 兼容性按 &#167;2.10 校验；只能在新获准可写面恢复，
不可把旧会话的权限、已消费批准或未提交动作直接当成仍有效。

</pre>

#### 迁移与修订

**G-086** · 源 agent-dev-guide.md，L2038–L2072；SHA-256 b9f02e4e94c70458777df570fec495c65ebf87a6d0bdb8ca34e23cfe9862d607

<pre data-unit="G-086">### 7.3 删除与迁移门

源稿或现行生命周期文档删除前必须同时满足：

1. 新文档通过 &#96;doc-gate.py --all&#96; 与 anchor gate；
2. 全仓旧文件名引用零命中，历史归档除外并有说明；
3. **五份**源稿全部非代码块内 &#96;#&#96;–&#96;####&#96; 标题在 &#167;10 恰有一个处置；目录说明亦单列，保留内容有正文落点，未采用内容有理由；
4. **每个落点已验到正文级**——不是「本稿有那么一节」，而是「该节确实承载了源节的内容」，
   且抽查记录可复核；
5. 原未验证清单在新真源逐条可寻且仍标 ⚠；
6. 一条真实 T0 与一条真实 T1 已按新路径留痕；
7. 删除作为不可逆动作经人确认。

⚠ **第 4 条是 2026-09-07 补的，补的是一个真实漏洞。**原第 3 条只要求「恰有一个落点」，
而**一张只验到标题级的表就能满足它**——于是六条可以全绿，同时 &#167;9.4 自报的
「未逐行比对正文」那笔欠账被一起删掉，**再没有人能发现**。

⚠ **这正是 &#96;refact-fable.md&#96; &#167;5.2 当年的形状**：它承诺「按旧文全部标题、脚本检查零缺口」的
映射表，把判据写进了**计划**，没写进**验收条件**，结果 &#96;migration-map.md&#96; 从未产出而
流程照走。**承诺产出但不进验收，等于没承诺。**

**由此得出 &#96;archive/&#96; 的存续条件**：只要 &#167;10 还有任何一行的落点没验到正文级，
&#96;archive/&#96; 下对应的源稿**就不能删**——它是那一行**唯一可抽查的对象**。
&#167;10 的开头写着「核它的办法是抽查落点、以正文为准」；把被抽查的对象删掉，
这张表就从「可证伪」变成「不可证伪」，而不可证伪的覆盖声明比没有更差。
⚠ **git 历史里有，不算数**：&#167;3.5 已立「Git 历史可恢复不等于新读者能找到」。

**本补充版的边界：迁移内容不是删除授权。**日常操作不再依赖 archive，历史源稿可保留供审计。
以后是否删除，要另行完成本节其余门禁，尤其全仓引用、未验证清单、真实 T0/T1 留痕与人的决定；
不能仅凭“标题表全了”删除，也不能只把正文藏进 Git 历史后声称新读者不再需要它。

引用清理至少扫描：AGENTS 入口、request-lifecycle 的旧流程指针、开发/实施计划、handoff、
实现矩阵、部署文档和测试说明；同时扫描 Markdown 链接与裸路径行号。历史引用须标明
版本与可取方式，现行操作说明则改指不会消失的正文。本次不修改这些外部文件。

</pre>

**G-090** · 源 agent-dev-guide.md，L2159–L2177；SHA-256 bae24dbe9f69e1757ae1eed8598e0b17478d672752b18478ebb8d275865d69e4

<pre data-unit="G-090">### 7.7 需要改内核时，提交明确的修订工作单元

开发投影表达不了的能力，先证明是内核缺口，不能在 Profile、Adapter 或文档里偷加语义。
工作单元至少写清：

&#124; 项 &#124; 要交代什么 &#124;
&#124; --- &#124; --- &#124;
&#124; 原始请求与证据 &#124; 谁提的、原话、可复核的缺口或拒收用例，不只写“感觉不够用” &#124;
&#124; 改与不改 &#124; 具体定义块、字段、F/AT/I 编号；状态、合法边、终态、幂等/租约哪些保持不变 &#124;
&#124; 影响 &#124; 前端、后端、执行器、验收器分别要改什么，不改会怎样 &#124;
&#124; 迁移与回滚 &#124; schema 版本、读写兼容、活动对象处理和退出条件 &#124;
&#124; 验收 &#124; 原有用例集、必要新增用例、一条可复现实验 &#124;
&#124; 旧语义的处置 &#124; 原先是什么意思、为何不够、谁依赖它；保留判断被改动的理由 &#124;

新增字段以带 schema 版本的可选字段引入；旧数据标“旧格式”，**不回填为无法证明的新语义**。
例如 &#96;consumed_at&#96; 只证明 Interaction 被消费，不能批量改写成“人已批准”。
新写入方不得回写旧版本语义；双读期按版本分别统计；活动旧对象归零后再退出旧写入方，
历史读取保留到展示和审计需求结束。具体迁移仍由产品合同修订批准，不因本节而自动生效。

</pre>

### protocol/round-protocol.md（P）

定位/定档/裁量 → 工单与七环节 → 取件、判据、隔离 → 分环节细则 → 停止清理；完整保留以保持脚本接口和冻结引用。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 完整轮次规程 | 只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。 | P-001, P-002, P-003, P-004, P-005, P-006, P-007, P-008, P-009, P-010, P-011, P-012, P-013, P-014, P-015, P-016, P-017, P-018, P-019, P-020, P-021, P-022, P-023, P-024, P-025, P-026, P-027, P-028, P-029, P-030, P-031, P-032, P-033, P-034, P-035, P-036, P-037, P-038, P-039, P-040, P-041, P-042, P-043, P-044, P-045, P-046, P-047, P-048, P-049, P-050, P-051, P-052, P-053, P-054, P-055, P-056, P-057 |

#### 完整轮次规程

**P-001** · 源 protocol/round-protocol.md，L1–L21；SHA-256 b2f57cec6aae6e8e9348f9c95f28c419aed60958761f22c63ef71d1edfd4d529

<pre data-unit="P-001"># 并行评优轮：流程

&gt; 最后更新：2026-09-04
&gt;
&gt; **本文定义一轮「多家并行出稿 → 互评 → 裁决 → 异议 → 验收 → 确认 → 清理」怎么走。**
&gt; **它是本项目多助手协作的唯一一套流程。**早先的 &#96;agent-discipline.md&#96; 把协作分成
&gt; 三种「模式」，那个抽象已作废——三者是同一套流程的三组参数取值，见 &#167;1.0。
&gt; 该文的隔离原则（&#167;9.1）、工单发什么不发什么（&#167;9.2）、并行发提案的脚本（&#167;9.3）、
&gt; 定向审核两阶段（&#167;13.1）、验收通过意味着什么（&#167;13.2）已全部并入本文。
&gt;
&gt; **本文只放不随轮次变化的部分。**每一轮的题目、参与方、共享最终路径与验收标准
&gt; 写在该轮自己的 &#96;round.md&#96;（见「本轮定义」）。
&gt;
&gt; **本文的读者既是人也是 agent。**推进一轮的唯一指令是固定的一句话（见「收到『继续』时怎么办」），
&gt; 收到它的执行者靠本文自行定位，不靠发起人逐轮说明。
&gt;
&gt; 规则来自实跑：2026-09-02 的生命周期文档重写（完整流程）、2026-09-03 的一次失败整合
&gt; （失败原因见「角色不分会怎样」）、2026-09-04 的 refact 轮（异议轮缺失被发现，同节）。

---

</pre>

**P-002** · 源 protocol/round-protocol.md，L22–L51；SHA-256 fd49aa897d45299584a463faa4f3565c917a3c0a0fdf2b09c0d28cc5c7d6de82

<pre data-unit="P-002">## 0. 收到「继续」时怎么办

推进一轮的指令固定为一句话，每轮、每环节都一样：

&#96;&#96;&#96;text
按 round-protocol 定位当前环节，做你该做的那一步。
&#96;&#96;&#96;

收到它的第一个动作**不是干活，是定位**。按顺序回答四个问题，答不出就停下问人：

&#124; # &#124; 问题 &#124; 怎么答 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; 我是谁 &#124; 工作目录形如 &#96;~/worktrees/&lt;X&gt;/k8s&#96;，&#96;&lt;X&gt;&#96; 就是你的名字。**若在 &#96;~/master/k8s&#96;，立即停下问人** &#124;
&#124; 2 &#124; 这件事走哪一档 &#124; 见「流程档位」；T0/T1 不走七环节，读到这里就够了 &#124;
&#124; 3 &#124; 现在是哪一轮 &#124; &#96;ls sunmoonai/docs/dev-plan/rounds/&#96; 里 &#96;status: ACTIVE&#96; 的那一个（见「本轮定义」） &#124;
&#124; 4 &#124; 现在是第几环节 &#124; 跑「环节判定」那节的命令，**从产物反推，不看任何人的声明** &#124;
&#124; 5 &#124; 我这一环节做什么 &#124; 读 &#96;rounds/&lt;round-id&gt;/call-&lt;当前环节&gt;.md&#96; 里**属于你的那一节**；它自足，不需要额外指令 &#124;

**最后一问的答案永远在一个路径可推导的文件里，这就是「固定指令」能成立的原因。**
通知靠人逐轮转述，人就必须每轮重写一遍；通知落盘且路径可推导，人只需说「继续」。

**只做当前环节属于你的那一步。**下一环节的活现在做出来一律作废——
提案期写的评审不是评审（看过别人答案了），裁决前写的验收不是验收（对象还没定稿）。

**状态不记在任何声明里。**没有 &#96;state: reviewing&#96; 这种字段可信——
声明会和事实漂移。判据一律是「环节判定」那节的命令，对照 git 提交，不看工作区、不看谁说了什么。
这与 &#91;&#96;doc-gate.py&#96;](../doc-gate.py) 同源：结论不取决于工作区状态。

---

</pre>

**P-003** · 源 protocol/round-protocol.md，L52–L63；SHA-256 3eb7fcb7a80fc9b93cf9ed1d569f941b9dae250e5926a2687f57a31b5ea5b9a3

<pre data-unit="P-003">## 1. 流程档位：这件事该走多重的流程

**不是每件事都值得走完整轮。**完整轮是 N 倍成本，用在不该用的地方是浪费；
但用轻了，代价是不可逆的错误被推到底。所以第一件事是定档，**且定档必须可复核，
不能凭当天的心情**——「相机裁定」指的是按判据裁，不是随意裁。

&#124; 档 &#124; 形态 &#124; 角色 &#124; 典型场景 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; **T0 直做** &#124; 一个执行者做完，无候选、无互评 &#124; 执行者 + 独立验收者 &#124; 可逆、单点、方向无争议 &#124;
&#124; **T1 单稿 + 独立评审** &#124; 一家出稿，另一家按冻结判据评审并验收 &#124; 出稿方 / 评审方 / 人（若不可逆） &#124; 影响面跨多文件或多仓，但方向无争议 &#124;
&#124; **T2 完整并行轮** &#124; 本文全部七环节 &#124; 提案 N / 评优 N / 裁决 / 异议 / 验收 / 确认 &#124; 见下表判据 &#124;

</pre>

**P-004** · 源 protocol/round-protocol.md，L64–L84；SHA-256 16cf91b6d52c1396f8b4df2fd90a7aeef325fa9e296e6d9bab7d34bf07b371ce

<pre data-unit="P-004">### 1.0 一套流程，靠参数覆盖三种协作形态

早先有一份 &#96;agent-discipline.md&#96; 把多助手协作分成三种**模式**：
A 并行提案、B 定向审核、C 评审—吸收循环。**那个抽象已经作废**——
三者不是三套流程，是同一套流程的三组参数取值，靠 &#96;round.md&#96; 的字段就能表达：

&#124; 要做的事 &#124; &#96;proposers&#96; &#124; &#96;baseline&#96; &#124; &#96;skip_stages&#96; &#124; 谁验收 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; **多家各出方案再合并**（原模式 A） &#124; N 家 &#124; 无 &#124; 无 &#124; 按 &#167;13 算出 &#124;
&#124; **让另一家查一份已有产物**（原模式 B） &#124; 空 &#124; 那份产物 &#124; &#96;①②④&#96; &#124; 指定的那一家 &#124;
&#124; **多家评审一份已有产物，主方吸收**（原模式 C） &#124; N 家 &#124; 那份产物 &#124; &#96;①&#96; &#124; 按 &#167;13 算出 &#124;

**已实跑验证**：&#96;rounds/_fixups&#96; 就是第二行——&#96;skip_stages = &#91;&quot;①&quot;,&quot;②&quot;,&quot;④&quot;,&quot;⑥&quot;]&#96;，
只走 ③ 裁决 + ⑤ 验收，验收方 cursor。它没有另起一套流程，也不需要。

这条与「六条被证伪的设计」是同一种错：**为一个可以当参数的东西造了一层抽象。**
判断办法也一样——如果两个「模式」的差别能写成同一张表里的不同取值，它们就不是两个模式。

⚠ **参数变了，不能省的三条不变**（&#167;1.3）。跳过环节要在 &#96;round.md&#96; 明写 &#96;skip_stages&#96;，
**留空字段不算数**（&#167;8）。

</pre>

**P-005** · 源 protocol/round-protocol.md，L85–L98；SHA-256 61e1dddebaa5c80fa3625ca1a8681817e9f3ed6ee59ac8ecf1b847c36dda6205

<pre data-unit="P-005">### 1.1 判据：命中任一条即 T2

&#124; 判据 &#124; 说明 &#124;
&#124; --- &#124; --- &#124;
&#124; **不可逆** &#124; 产物一旦发布，改判代价高：对外契约、编号体系、数据迁移与删除、**流程本身** &#124;
&#124; **权威层** &#124; 会成为其他文档或代码的依据（&#96;constraints.md&#96;、产品契约、本协议自身） &#124;
&#124; **已知对立** &#124; 开工前就存在两个及以上互不相容的主张 &#124;
&#124; **判据未定** &#124; 连「什么算做对」都还没共识——此时并行的价值是探索判据，不是比稿 &#124;

都不命中、但影响面跨多个文件或多个仓的，走 T1；其余 T0。

**裁定要留痕**：写进 &#96;round.md&#96; 的 &#96;tier&#96; 字段，附一句理由与命中的判据。
T0 不必建 &#96;rounds/&#96; 目录，把裁定记在任务条目里即可；T1 建目录，但只有评审与验收两份产物。

</pre>

**P-006** · 源 protocol/round-protocol.md，L99–L110；SHA-256 bf735dfab5d65be082040da79f9cff78d4e1d92601f0915f853aef96ac16339d

<pre data-unit="P-006">### 1.2 升档随意，降档要理由——这条不对称是有意的

**升档不需要理由**（更谨慎不会错），**降档必须写明理由并经人确认**。
理由是：自动化的默认漂移方向永远是省事，若两个方向一样容易，档位会一路滑到 T0。

**中途只能升，不能降。**开工后发现分歧或触及不可逆，随时升档；
已经在跑的重流程**不得因为嫌慢而降档**。

&gt; **2026-09-03 那次失败整合，本质不是没有流程，是中途降了档**——
&gt; 五份材料该走 T2，实际按 T0 处理：整合方即参赛方、无互评、无异议、无独立验收。
&gt; 那五条毛病全部是降档的必然后果，不是执行不力（见「角色不分会怎样」）。

</pre>

**P-007** · 源 protocol/round-protocol.md，L111–L119；SHA-256 88c336a7e0b3da96b03b3442a92f6882fd9c38fefa0a46f3524e8767381f9aaf

<pre data-unit="P-007">### 1.3 任何档位都不能省的三条

档位调节的是**并行度与环节数**，不是**判据**。以下三条在 T0 同样成立，
省掉任何一条，「轻流程」就变成了「无流程」：

1. **验收判据先于产出冻结。**做完再定标准等于自证。
2. **产出方 ≠ 验收方。**出题方与答题方是同一个，验收就不是独立信号。
3. **不可逆动作由人确认。**这一条与档位无关，只与动作性质有关。

</pre>

**P-008** · 源 protocol/round-protocol.md，L120–L126；SHA-256 80b2c1fbb4ff1317071700c470a2fafc8dca7e6bc77bb544a04cea881f6b697f

<pre data-unit="P-008">## 2. 裁量权：supervisor 可以临机决定什么

**流程写死一切是不可能的**——总会有事先没想到的情况。但**无约束的裁量正是
2026-09-03 那次失败的形态**：一个人依自己判断跳过了互评、异议与独立验收。

所以裁量是合法的，条件是四样：**有边界、留痕、可推翻、可升级**。

</pre>

**P-009** · 源 protocol/round-protocol.md，L127–L137；SHA-256 799cffbcd626c3f6d6fffdeb2d51b005400b4abc42e208bbf8f62e2caeb37aa5

<pre data-unit="P-009">### 2.1 不可裁量的下限

以下五条，**无论谁、无论什么理由都不能裁掉**。要改只能改本协议本身，
而改本协议按「流程档位」的判据是 T2（它属于「不可逆」与「权威层」）：

1. **不可逆动作由人确认**——⑥ 确认、写入共享最终路径、删除或迁移已有资产；
2. **出题方 ≠ 答题方**；
3. **验收判据先于产出冻结**；
4. **已冻结的产物不得再改**——候选提交即冻结，冻结区逐字未改；
5. **提案期隔离**。

</pre>

**P-010** · 源 protocol/round-protocol.md，L138–L142；SHA-256 bf525d4b825a32ec150de9cf594ebc485b738d9929c8a9433b2706445c0f7bea

<pre data-unit="P-010">### 2.2 可裁量的事项

档位升降、观察窗长短、环节合并或跳过、换角色、追加或移除参与方、提前终止本轮、
初判某条验收标准「已过期」、对逾期与弃权的认定。

</pre>

**P-011** · 源 protocol/round-protocol.md，L143–L158；SHA-256 976c280c4588abb27dcf7cb7cb7875769c82a468114c828acd10e755ab9aa5ff

<pre data-unit="P-011">### 2.3 方向不对称：这是本协议的统一原则

&gt; **朝更严谨的方向，组织者自行裁量并记录即可；
&gt; 朝更省事的方向，须经人确认。**

&#124; 方向 &#124; 例 &#124; 要求 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **更严谨** &#124; 升档、延长观察窗、增加评审方、要求补取证、回退重做 &#124; 记录即可 &#124;
&#124; **更省事** &#124; 降档、缩短观察窗、跳过环节、免除某家、减少参与方、提前终止 &#124; **人确认** + 记录 &#124;

理由：**自动化的默认漂移方向永远是省事。**两边一样容易时，系统会一路滑向省事，
而省掉的总是最花时间的那些——取证、互评、验收。

这条不对称在本协议里出现三次：升档／降档、延长／缩短观察窗、以及此处。
**它们是同一条原则**，不是三条巧合。

</pre>

**P-012** · 源 protocol/round-protocol.md，L159–L170；SHA-256 40e738ec9f9d718a7a6c2fcab33af94a2a3a0bbb8133e5a53aaa532cdb370160

<pre data-unit="P-012">### 2.4 裁定记录：未记录的裁定无效

每条裁定写进 &#96;rounds/&lt;round-id&gt;/rulings.md&#96;，字段固定：

&#124; 编号 &#124; 事由 &#124; 依据 &#124; 处置 &#124; 方向 &#124; 人确认 &#124; 影响到谁 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;R1&#96; &#124; 触发裁量的具体情况 &#124; 观测值、判据或理由，**须能独立成立** &#124; 决定了什么 &#124; 更严谨／更省事 &#124; 是／否／不适用 &#124; 参与方与环节 &#124;

裁定即时生效，但**未记录的裁定无效**——事后无法复核的决定，与没有决定等价。
「依据」栏不接受「作者判断」；宣布逾期一类的裁定，依据必须是观测值
（字节数、时间戳、分支 HEAD），不是「等太久了」。

</pre>

**P-013** · 源 protocol/round-protocol.md，L171–L178；SHA-256 a89d32d36ea370fb28d3f206afaf11544aa1cbf414a2a3fd3f1b382785cb4e04

<pre data-unit="P-013">### 2.5 推翻

- **人可以推翻任何裁定**；
- **被裁定影响的参与方可以就该裁定提异议**，门槛同「④ 异议」：
  条目 + 为什么错 + 应当是什么 + 可复跑证据；
- 推翻同样记入 &#96;rulings.md&#96;，不覆盖原记录——**作废的判断本身是证据**，
  它记录了当时的信息状态。

</pre>

**P-014** · 源 protocol/round-protocol.md，L179–L190；SHA-256 c366e080a1c9335ad76710a692719e23ce537ca8ddcefdbdc477bba346ee09a6

<pre data-unit="P-014">### 2.6 裁量是规则的孵化器

协议靠这一条自我演化，而不是靠某次重写：

&#124; 观察到 &#124; 处置 &#124;
&#124; --- &#124; --- &#124;
&#124; 同一类裁定在两轮内出现两次以上 &#124; **升级为规则**，写进本协议 &#124;
&#124; 某条规则连续两轮都靠裁量豁免 &#124; **降级为裁量或废除**——它已经不是规则了，只是每次都要绕过的障碍 &#124;

**规则与裁量不是对立的：规则是默认值，裁量是覆盖。**
没有裁定时按规则走；有裁定时按裁定走，且裁定必须说明它覆盖了哪条规则。

</pre>

**P-015** · 源 protocol/round-protocol.md，L191–L196；SHA-256 7cd5a95773b6a64eede39d5054248766a984c7e56391ac17ceb88ad4910512c2

<pre data-unit="P-015">## 3. 执行者与触发方式：两个轴，不要混

协议里「谁做」和「怎么触发」是两件事，混在一起会同时产生两种错误：
**以为全都能自动**（于是把人的确认也顺手代劳了），或**以为全都不能自动**
（于是人永远卡在中间当传声筒）。

</pre>

**P-016** · 源 protocol/round-protocol.md，L197–L208；SHA-256 83f7b3998c1ea69c7647c60efff769e962387c564ee8c921e7e3906439b8d594

<pre data-unit="P-016">### 3.1 两个轴

&#124; 轴 &#124; 取值 &#124;
&#124; --- &#124; --- &#124;
&#124; **执行者** &#124; &#96;agent&#96; / &#96;human&#96; &#124;
&#124; **触发方式**（只对 &#96;human&#96; 的动作有意义） &#124; **可自动** / **手动** &#124;

判据只有一条：

&gt; **动作的内容是常量、只是需要送达 → 可自动**（现在由人做，缺的是传输，不是判断）。
&gt; **动作要在当下做一个不可复算的判断 → 手动**（永远由人做）。

</pre>

**P-017** · 源 protocol/round-protocol.md，L209–L225；SHA-256 e05018cdfa78050de41bd0d5340d7210ff67a79d191a448ec9737b22b36f2ec7

<pre data-unit="P-017">### 3.2 全部动作的归属

&#124; 动作 &#124; 执行者 &#124; 触发 &#124; 说明 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; ①②④⑤ 各环节的产出 &#124; &#96;agent&#96; &#124; — &#124; 各参与方 &#124;
&#124; ③ 裁决与整合 &#124; &#96;agent&#96; &#124; — &#124; 裁决方 &#124;
&#124; 环节通知落盘 &#124; &#96;agent&#96; &#124; — &#124; 组织者的产物，不是发起人的话术 &#124;
&#124; 跑环节判定命令、报状态 &#124; &#96;agent&#96; &#124; — &#124; 从产物反推 &#124;
&#124; 观测与宣布逾期／停滞 &#124; &#96;agent&#96; &#124; — &#124; 依据必须是观测值 &#124;
&#124; 更严谨方向的裁定 &#124; &#96;agent&#96; &#124; — &#124; 记录即可 &#124;
&#124; 开合检视 worktree &#124; &#96;agent&#96; &#124; — &#124; 供人读稿 &#124;
&#124; **把「继续」送到各参与方** &#124; &#96;human&#96; &#124; **可自动** &#124; 内容已是常量（固定指令 + 可推导的通知路径）；**缺的只是可寻址通道** &#124;
&#124; **冻结题目与验收标准** &#124; &#96;human&#96; &#124; **手动** &#124; 标准若由 agent 自己定，等于出题方＝答题方 &#124;
&#124; **⑥ 确认** &#124; &#96;human&#96; &#124; **手动** &#124; 全流程唯一不可逆的一步 &#124;
&#124; **省事方向裁定的确认**（降档、免除某家、缩短观察窗、跳过环节） &#124; &#96;human&#96; &#124; **手动** &#124; 见「裁量权」 &#124;
&#124; **推翻任一裁定** &#124; &#96;human&#96; &#124; **手动** &#124; &#124;

</pre>

**P-018** · 源 protocol/round-protocol.md，L226–L235；SHA-256 5850ef619f25dad9649661b42f25c7cb20fa3f1e51ea2163e51b4663fc4a05d2

<pre data-unit="P-018">### 3.3 两类「人做」不可互相顶替

- **「可自动」项现在由人做，是欠账**，应登记为待自动化项；补上传输通道后即转为 &#96;agent&#96;。
  它长期由人做，人就会变成传声筒，而传声筒会疲劳、会漏、会自己加戏。
- **「手动」项永远由人做**，**不得因为流程自动化而被顺手代劳**。
  它之所以是人，不是因为没人写脚本，而是因为**判断本身不可复算**。

**判断某项属于哪一类，用 3.1 的判据，不用「现在是谁在做」。**
现在是人在做，既可能因为它需要判断，也可能只因为还没人接线——**这两件事必须分开记。**

</pre>

**P-019** · 源 protocol/round-protocol.md，L236–L262；SHA-256 ca0b9ccaaaaa5124110ec7b11b690ee7b5abe178d0d1004d0a8c34cf964e24b8

<pre data-unit="P-019">## 4. 七个环节（T2 专用）

**以下七环节只适用 T2。**T0 只有「做 → 独立验收」，T1 只有「出稿 → 独立评审 → 验收」，
两者都仍受「任何档位都不能省的三条」约束。

&#96;&#96;&#96;text
① 提案   N 家各自写候选，互不可见                     产物：候选
           ↓ 候选提交并冻结（SHA-256），此后不得再改
② 互评   N 家各自读全部候选，评优并写评审              产物：评审
           ↓
③ 裁决   裁决方定基座，逐条吸收                        产物：裁决稿 + 处置记录
           ↓
④ 异议   被处置到的各家只就自己那条主张的处置提异议     产物：异议稿
           ↓ 裁决方逐条处置；触及基座结构的采纳 → 回到 ③
⑤ 验收   验收方按冻结的验收标准逐条判定                产物：验收稿
           ↓ 不通过 → 回到 ③
⑥ 确认   **人**读最终稿，确认或打回                    产物：确认
           ↓ 打回 → 回到 ③
⑦ 清理   删除各分支本轮产物，然后写入共享最终路径       产物：最终稿
&#96;&#96;&#96;

**只有 ⑦ 写共享最终路径。**①②④⑤ 的产物留在各家 worktree，③ 的产物在裁决方的整合分支。
候选分支不合并回主线，所以全程不存在同名文件冲突。

**流程不是只会前进。**④⑤⑥ 三处都可能回到 ③，回退规则见「停止、超时与回退」。
**一路向前是自动化的默认失败形态**——没有回退环节的流程，最终一定会把不合格产物推到底。

</pre>

**P-020** · 源 protocol/round-protocol.md，L263–L290；SHA-256 0a2f73141d51fb9be1712cbfc8c63381a4a4bb032e5f5787f5c72ccd8f229273

<pre data-unit="P-020">## 5. 本轮定义：&#96;round.md&#96;

每轮一个目录，路径固定：

&#96;&#96;&#96;text
sunmoonai/docs/dev-plan/rounds/&lt;round-id&gt;/round.md
&#96;&#96;&#96;

&#96;&lt;round-id&gt;&#96; 用短横线小写短名，全局不复用（例：&#96;refact&#96;、&#96;pipeline&#96;）。
&#96;round.md&#96; 是本轮**唯一**的可变参数来源，字段固定，缺项视为未定义、不开轮：

&#124; 字段 &#124; 内容 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;status&#96; &#124; &#96;ACTIVE&#96; / &#96;DONE&#96; / &#96;ABORTED&#96;。全仓同时只允许一个 &#96;ACTIVE&#96; &#124;
&#124; &#96;tier&#96; &#124; &#96;T0&#96; / &#96;T1&#96; / &#96;T2&#96; + 一句理由 + 命中的判据（见「流程档位」）。**降档还须记人确认** &#124;
&#124; &#96;待自动化&#96; &#124; 本轮中被标为「可自动」但实际由人做的动作（见「执行者与触发方式」）。**空着不等于没有，等于没记** &#124;
&#124; 题目 &#124; 要产出什么，一句话 &#124;
&#124; 共享最终路径 &#124; 仓内相对路径，**候选就写这个同名文件** &#124;
&#124; 基座 &#124; 有基座写 commit，无基座写「无，新建文件」 &#124;
&#124; 参与方 &#124; 提案方名单 &#124;
&#124; 角色 &#124; 裁决方；验收方留空，由「⑤ 验收 与 ⑥ 确认」那节的规则算出 &#124;
&#124; 验收标准 &#124; 逐条编号，**冻结后不得为了让产出通过而修改** &#124;
&#124; 冻结区 &#124; 不许改写的小节清单（如有） &#124;
&#124; 背景与题目细则 &#124; 可另拆 &#96;task.md&#96; 同目录放，&#96;round.md&#96; 只留指针 &#124;

**不变的流程规则不写进 &#96;round.md&#96;**——开工须知、隔离纪律、枚举形状、产物命名、
角色规则、冻结方式全在本文。任务书重复它们只会产生第二份会漂移的真源。

</pre>

**P-021** · 源 protocol/round-protocol.md，L291–L322；SHA-256 1810ea8ba3da1737dce71841407f459af03c710617bb197f61017477ecbb33c8

<pre data-unit="P-021">## 6. 产物、路径与命名

下表的 &#96;R&#96; = &#96;rounds/&lt;round-id&gt;&#96;。

&#124; 环节 &#124; 谁 &#124; 产物 &#124; 落点（进行中） &#124; 落点（归档后） &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; ① &#124; 各提案方 &#124; 候选 &#124; 自己 worktree 的**共享最终路径同名文件** &#124; &#96;R/reviews/candidate-&lt;名&gt;.md&#96; &#124;
&#124; ② &#124; 各提案方 &#124; 评审 &#124; &#96;R/reviews/review-&lt;名&gt;.md&#96; &#124; 同左 &#124;
&#124; ③ &#124; 裁决方 &#124; 裁决稿 + 处置记录 &#124; 裁决稿在共享最终路径；处置记录 &#96;R/disposition.md&#96; &#124; 同左 &#124;
&#124; ④ &#124; 被处置到的各家 &#124; 异议稿 &#124; &#96;R/reviews/objection-&lt;名&gt;.md&#96; &#124; 同左 &#124;
&#124; ⑤ &#124; 验收方 &#124; 验收稿 &#124; &#96;R/reviews/acceptance-&lt;名&gt;.md&#96; &#124; 同左 &#124;
&#124; ⑦ &#124; 裁决方 &#124; 最终稿 &#124; 主线的共享最终路径 &#124; 同左 &#124;
&#124; 每个环节开始时 &#124; 该环节的组织者 &#124; **环节通知** &#124; &#96;R/call-&lt;环节&gt;.md&#96; &#124; 同左 &#124;
&#124; 任何时候 &#124; 组织者 &#124; **裁定记录** &#124; &#96;R/rulings.md&#96;（见「裁量权」） &#124; 同左 &#124;

**归档后**指该轮 ⑦ 收尾、各家分支回收之后。候选是唯一换位置的产物：进行中它必须
占着共享最终路径（&#96;git diff master&#96; 一条命令看清每家改了什么），回收分支前收进 &#96;reviews/&#96;。

&gt; **已存在的两处历史变体**，脚本认，新轮次不要再用：
&gt; &#96;refact-fable&#96;、&#96;runtime&#96; 两轮的 &#96;R/reviews/&#96; 是对的；但这两轮的**处置记录与环节通知**
&gt; 带了 &#96;&lt;round-id&gt;-&#96; 前缀（&#96;runtime-disposition.md&#96;、&#96;runtime-call-①.md&#96;），
&gt; &#96;_fixups&#96; 轮的验收稿则平铺在 &#96;R/&#96; 根下。轮次目录本身已经标明轮次，前缀是冗余。
&gt; 这些文件**不改名**——&#96;rounds/&lt;id&gt;/reviews/&#96; 已被 &#96;runtime-architecture.md @ ceb7291c:454/458/461&#96;
&gt; 与 &#96;refact-fable.md @ ceb7291c:23/29/38/43&#96; 当证据锚引用，改名会让已发布的证据链失效。

**候选用与主线一致的路径和文件名**：&#96;git diff master&#96; 一条命令看清每家改了什么；
路径本身标明作者；枚举形状固定，不会漏。

**其余产物一律 &#96;&lt;环节&gt;-&lt;名&gt;.md&#96;，不得自创文件名。**2026-09-02 出过事故：四家里三家
用一个文件名、一家用了别的名字，评审方按精确文件名枚举，**漏掉一份候选，整轮评分作废重做**。
不合命名的文件不进枚举，等同未交付。

</pre>

**P-022** · 源 protocol/round-protocol.md，L323–L343；SHA-256 057774ecfb3ac4590bec595b0fa8bf173f9be9c6620a26389d5c1240dc1edbb3

<pre data-unit="P-022">### 6.1 环节通知：组织者的产物，不是发起人的话术

**每个环节由一份落盘的通知开启，不由发起人口头转述。**
①② 的通知由发起人写，③ 之后由裁决方写——**通知是组织者的产物，和裁决稿一样要提交、要可复核。**

通知必须自足，含四样：

&#124; 必含 &#124; 说明 &#124;
&#124; --- &#124; --- &#124;
&#124; 取件命令 &#124; 本环节要读的对象怎么取，含分支与 commit &#124;
&#124; 对象事实 &#124; 行数、SHA-256、HEAD，供读者证明自己读的是同一版 &#124;
&#124; 范围与门槛 &#124; 这一环节允许做什么、什么不受理 &#124;
&#124; 交付路径 &#124; 产物写到哪、叫什么、怎么回报 &#124;

**从 ④ 起，通知把各家各自要看的部分写在同一份里，公开可查。**
①② 期间隔离仍然有效，通知不得透露他家内容；但 ③ 之后隔离已无意义
（互评时各家已互相读过全部候选），**公开反而让处置可被交叉检验**：
谁被改判、为什么，别家也看得到。

通知里要写明「只做属于你的那一节」——其余各节是为公开可查而在，不是给读者逐条评论的。

</pre>

**P-023** · 源 protocol/round-protocol.md，L344–L348；SHA-256 8024eaeffd6b4451174e375b5c7d935e9501ae610c465eb402c30e1ca9c479c1

<pre data-unit="P-023">## 7. 取件与检视面

**一个流程如果没规定产物怎么被读到，它只完成了一半。**②④⑤ 都要读别人分支上的东西，
⑥ 是人在编辑器里读——这些都必须有规定的取法，不能临场问。

</pre>

**P-024** · 源 protocol/round-protocol.md，L349–L364；SHA-256 54ee65565f3b4a2e4ec5fcf8dcd85e1a0ff6ce9baa03daaad1658dbfd8527cef

<pre data-unit="P-024">### 7.1 取件：一律按 commit，不看工作区

&#96;&#96;&#96;bash
git show &lt;分支&gt;:&lt;路径&gt;                    # 取某家某个产物
git diff &lt;基座commit&gt; &lt;裁决分支&gt; -- &lt;共享最终路径&gt;   # 看裁决方在基座上改了什么
git log --oneline master..&lt;裁决分支&gt;       # 看逐条主张（一条主张一个提交）
&#96;&#96;&#96;

**工作区文件会变，提交不会。**任何环节引用他人产物，都要同时给出分支与 commit；
只说文件路径的引用不算数。

**跨分支产物不得写成 markdown 链接。**本轮产物散在各家分支上，而
&#91;&#96;doc-gate.py&#96;](../doc-gate.py) 按**当前分支的 git 索引**判定链接目标是否存在——
链到别的分支上的文件必然判失败。写成 &#96;&lt;分支&gt;:&lt;路径&gt;&#96; 的纯文本即可，
这也正好满足上一条「同时给出分支」。

</pre>

**P-025** · 源 protocol/round-protocol.md，L365–L381；SHA-256 49546d85b547722a89f66a6a23e6d7c4073f2ce757cd050d4ab9078c127cb578

<pre data-unit="P-025">### 7.2 检视面：需要人读时开临时 worktree

&#96;git show&#96; 适合取单个文件，不适合人通读或改写。人要读、要改时开检视 worktree：

&#96;&#96;&#96;bash
git worktree add ~/review/&lt;分支名&gt; &lt;分支名&gt;     # 开
git worktree remove ~/review/&lt;分支名&gt;           # 用完删；分支与提交都还在
&#96;&#96;&#96;

三条约束：

&#124; 约束 &#124; 说明 &#124;
&#124; --- &#124; --- &#124;
&#124; **一个分支只能被一棵 worktree 检出** &#124; 要给别人开检视面，持有该分支的一方须先切走（&#96;git checkout &lt;自己的分支&gt;&#96;） &#124;
&#124; **检视面不是产物落点** &#124; 除非人就是要在上面改稿；agent 不得把产物写进检视 worktree &#124;
&#124; **用完删** &#124; 长期挂着的检视 worktree 会被误当成第九个参与方 &#124;

</pre>

**P-026** · 源 protocol/round-protocol.md，L382–L390；SHA-256 05d4775dfaa5efda5cdba56f33eddeaf04c83df93ecaf1ad9c5ef4739cefbc87

<pre data-unit="P-026">### 7.3 每个需要人读的环节都必须先有检视面

**⑥ 确认尤其如此。**它是全流程唯一不可逆的一步，而人不通过 &#96;git show&#96; 逐个文件读稿。
裁决方在请求确认前**必须已经把检视面开好并给出路径**，
「稿子在我分支上」不构成可确认状态。

同理，发起人在任何环节要看产物，按「检视面」那节开临时 worktree 即可，
**不必也不应把在制品复制进 master**——那会与共享最终路径的正本产生第二个真源。

</pre>

**P-027** · 源 protocol/round-protocol.md，L391–L426；SHA-256 c83a4814637e9e52f6204973353633965e9d4daa1d7ed3030bdb80954b4aea9e

<pre data-unit="P-027">## 8. 环节判定：命令即判据

以下命令在任一 worktree 的仓根跑，结果只依赖 git 提交。
&#96;N&#96; = 参与方家数，&#96;R&#96; = &#96;rounds/&lt;round-id&gt;&#96;，&#96;P&#96; = 共享最终路径。

&#124; 判定 &#124; 命令 &#124; 通过条件 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; ① 完成 &#124; 各提案方分支上 &#96;$P&#96; 已提交且与 master 不同；或 &#96;$R/reviews/candidate-&lt;名&gt;.md&#96; 已归档 &#124; &#96;N&#96; 家全部满足其一 &#124;
&#124; ② 完成 &#124; &#96;git show &lt;ref&gt;:$R/reviews/review-&lt;名&gt;.md&#96; &#124; &#96;N&#96; 家全部存在且已提交 &#124;
&#124; ③ 完成 &#124; 裁决方分支（或主线）上 &#96;$P&#96; 与 &#96;$R/disposition.md&#96; 均已提交 &#124; 两者都在 &#124;
&#124; ④ 完成 &#124; 每个**被处置到**的家有 &#96;objection-&lt;名&gt;.md&#96;，或在 &#96;disposition.md&#96; 登记「无异议」 &#124; 无缺口 &#124;
&#124; ⑤ 完成 &#124; &#96;$R/reviews/acceptance-&lt;名&gt;.md&#96; 已提交 &#124; 存在 &#124;
&#124; ⑥ 完成 &#124; &#96;$R/rulings.md&#96; 的「人确认」列**没有一行还是「待」** &#124; 无待确认行 &#124;

&#96;&lt;ref&gt;&#96; 依次试 &#96;&lt;round-id&gt;/&lt;家&gt;&#96; 分支 → **裸的 &#96;&lt;家&gt;&#96; 分支** → 裁决方 ref → &#96;master&#96;。
本节的通知说的是「commit 到你自己的分支」，而各家对此的落法**本来就不一致**：
2026-09-06 实测，两家建了 &#96;&lt;round-id&gt;/&lt;家&gt;&#96;，一家直接提交在 &#96;&lt;家&gt;&#96; 上。
**只认其中一种，会把照指示做的那家判成没交，进而按逾期剔除**——
判据把合规者判出局，比漏判更危险。

**只认参与方分支同样是错的**：
轮次收尾后分支回收，产物归档进主线，判据会把每一轮做完的事都判成没做。
2026-09-06 实测：已发布的 &#96;runtime&#96; 轮被自己的判据报成「当前环节 ①，缺五家」。

⑥ 的**内容**由人判，⑥ 有没有**落盘**由命令判。&#96;rulings.md&#96; 抬头写的是
「回执只认落盘——对话里说『同意』不算」，那一列就是判据。把 ⑥ 整个标成
「不可由命令判定」会让**任何**轮次都到不了 ⑦，于是每轮走完都跟自己的 &#96;status&#96; 打架。

**没有参与方 ≠ 该环节完成。**&#96;all({})&#96; 为真，空集合会让空环节被静默跳过——
那正是「判据自身的质量」点名的形态。要跳过某环节，必须在 &#96;round.md&#96; 明写
&#96;skip_stages = &#91;&quot;①&quot;, &quot;②&quot;, &quot;④&quot;]&#96;；留空字段不算数。

**枚举必须用固定路径形状，不得按印象列文件名。**
命中数与 &#96;N&#96; 不符时**停下问人**，不要自行猜测哪一份该算数——
这正是 09-02 事故的形态。裁决方那份未改的基座会使命中数为 &#96;N+1&#96;，属正常。

</pre>

**P-028** · 源 protocol/round-protocol.md，L427–L464；SHA-256 d3f07470839960a78f99a960f461aa2555d35ef016d2b8cb72d0619df3bd7bde

<pre data-unit="P-028">### 8.1 判据自身的质量：覆盖不全比没有更危险

&gt; **一个覆盖不全的检查，比完全没有检查更危险——因为它会报「通过」。**

没有检查时，人知道这里没被查过；有一个漏检的检查时，人以为查过了。
**它把「未知」伪装成「已验证」。**

本仓在这条上已经栽过多次，形状完全相同：

&#124; 实例 &#124; 漏在哪 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;test_dormant_capabilities.py&#96; 文件头记的坑 &#124; **把「没找到」当成「不存在」** &#124;
&#124; 被删的两个检查脚本 &#124; 结论取决于工作区状态，同一份文档在三台机器上报 0 / 4 / 95 条失败 &#124;
&#124; 2026-09-04 &#96;protocol/round-status.py --verify&#96; 首版 &#124; 锚点正则只认 &#96;~/repo/&#96; 全路径，短路径形式的一大类**一处未验**，却报「17 处全部可达」 &#124;
&#124; 2026-09-04 refact 轮清理扫描 &#124; 正则漏了一类文件名，扫出「0 份残留」，实际还剩一份 &#124;
&#124; 2026-09-07 &#96;doc-gate.py&#96; 自身 &#124; 用 &#96;git ls-files&#96; 读索引，而它默认开 &#96;core.quotepath&#96;，**非 ASCII 文件名被输出成八进制转义**。后果不止「链接判死」——**这类文件名的文档从未进入检查集合**。门一直报「160 份通过」，实际静默跳过 29 份；改用 &#96;-z&#96; 后变 189 份，当场抓到一处存在已久的真死链。⚠ 本项目**全部环节通知都是非 ASCII 文件名**（&#96;call-①.md&#96; 等），即每一份要求参与方照做的通知，从来没被门检查过 &#124;
&#124; 2026-09-06 &#96;runtime-refact&#96; ② 通知的哈希复核 &#124; 复核命令写成 &#96;git show runtime-refact/$w:路径&#96;——**zsh 把 &#96;$w:s…&#96; 当成参数修饰符**，路径被吃掉，&#96;rev-parse&#96; 解析成 commit 而非 blob。四份哈希全部报「不一致」，而表其实是对的 &#124;

后两条发生在**同一天**，都是本协议自己的工具。因此立三条：

1. **判据必须声明覆盖范围**——查了什么、**没查什么**。
   零命中要能区分「真的没有」与「没查到」，否则它就是上面那张表的下一行。
2. **判不了的显式标出**，不许默默不查。判不了不是缺陷，**假装判了才是**。
3. **验证命令本身要先被验证。**上表最后一行的形态最阴险：它报的是**假不一致**，
   若照它「修正」，会把正确的数据改错再发出去——**一个坏掉的检查不只是没查，
   它会指使你去破坏对的东西**。具体到 shell：&#96;ref:path&#96; 一律整体加引号，
   变量后紧跟 &#96;:&#96; 加字母时尤其危险；核对结论前先用第二种写法（如 blob id）交叉验一次。
4. **新判据第一次跑，先与人工结论对照，不得直接当门禁。**
   一个检查第一次运行时，最可能发现的是**它自己判错了**——
   &#96;--verify&#96; 首跑误报 8 项（把环节通知也要求登记进处置记录），
   补全锚点覆盖时又一次暴露三个 bug。**先当参考，对得上了再当门禁。**

这四条同时是「⑤ 验收」把机械部分交给脚本的前提：
机器判掉的项必须能说清它查了什么范围，否则「机器已验」只是换了个地方的自欺。

**本节由裁量升级而来**：同类问题在一天内出现两次，按「裁量权 · 裁量是规则的孵化器」
的规定升级为规则。

</pre>

**P-029** · 源 protocol/round-protocol.md，L465–L471；SHA-256 7d3eb45f752c059b0ff7b585d0cf722c74e2dbc39e150a9679a116abdaec1b80

<pre data-unit="P-029">### 8.2 立判据的人怎么约束自己

&#167;8.1 管的是机器判据的覆盖范围；这一节管的是**人写验收判据**时怎么不作弊。
它由 2026-09-04 refact 轮裁决方的密封判据升级而来——那份文件按其自身规定
应在环节 ③ 与裁决书一并公开，实际拖到 2026-09-06 才拆封，随后并入本节并删除
（原文：&#96;git show e7e37486:sunmoonai/docs/ai-dev-readiness/pipeline-rubric-opus.md&#96;）。

</pre>

**P-030** · 源 protocol/round-protocol.md，L472–L483；SHA-256 3f8655d2e77fd875752df6769304d73ecff533e18308aa5b6e59ca000af78447

<pre data-unit="P-030">#### 只写判据，不写答案

裁决方在参与方开工前先把题趟一遍，能建立判断力——否则容易被结构漂亮但没解决问题的
候选骗过。但裁决方一旦**写出自己的答案**，各份候选在它眼里就自动变成
「离我的方案有多远」，而这把尺子没有人能检验。

&gt; 「必须给出 X 的结论与理由」是**判据**。
&gt; 「X 应该是 Y」是**答案**，不写。

这同时堵住评审最常见的失效方式：**裁决时按最喜欢的那份候选反推判据。**
判据先于答案冻结，这条路就断了。

</pre>

**P-031** · 源 protocol/round-protocol.md，L484–L491；SHA-256 5aca979658125a9feabfc8aba4846ea84a61ee715bfef28c560694b4ac413729

<pre data-unit="P-031">#### 立据人的四条自我约束

1. 判据冻结后**不修改**。裁决中发现判据本身有问题，**在裁决书里追加说明**，不回头改判据。
2. 裁决书**逐条对照**判据表给结论，每条给出理由与候选原文出处。
3. 凡结论超出事先判据的，显式标注「**本条为事后新增判据**」并说明理由。
4. 判据**不得超出任务书已向参与方声明的范围**。
   **凡判据有、任务书没有的要求，一律不得用于扣分，只可用于加分。**

</pre>

**P-032** · 源 protocol/round-protocol.md，L492–L500；SHA-256 07dc0d5d662583a460a3a52197ade4351fae3706d61f140bce50683e1bd40b83

<pre data-unit="P-032">#### 难点清单：记下来是为了检验发起方

事先记下这道题难在哪，**不给解法**。它的用途不是评分，是反查：

&gt; 参与方**都没意识到**某个难点 → 责任在任务书交代不清，**不扣候选的分**，
&gt; 记为发起方的改进项。

意识到而解得不好，比没意识到强。

</pre>

**P-033** · 源 protocol/round-protocol.md，L501–L506；SHA-256 161b2aec1a7554950c86b805e322169a42e941a0c7aa15009d20eb6e2bbd4e00

<pre data-unit="P-033">#### 三条通用扣分规则

- **没有判据的阶段不是阶段，是一段时间。**只给阶段名而无准出判据的格不计分。
- **锚点存在但不支持断言的，比没有锚点扣得更重**——那是伪取证。
- 落点写成「相应目录」「合适的位置」一类不可定位的表述，按缺失计。

</pre>

**P-034** · 源 protocol/round-protocol.md，L507–L515；SHA-256 17eae03fd33f59846021d16bb7401717f548e7f4432681432f487545aa69b72d

<pre data-unit="P-034">#### 起草人回避

裁决方对某个问题已有**公开的既有立场**（例如它起草过背景材料）时：

&gt; 候选与该材料一致，**既不加分也不减分**。判的始终是论证与锚点。
&gt; 冲突且论证扎实的，应当高于一致但无论证的。

并且要在判据里**列出自己拒绝预设立场的问题**——写下来，是为了防止事后假装早有判据。

</pre>

**P-035** · 源 protocol/round-protocol.md，L516–L528；SHA-256 55e27a31479b16af6f785e55fef235521f8ab028b80ba34edd12defc1d0975a9

<pre data-unit="P-035">#### 判据自身的失效条件

判据表也要能在两个方向上失败，否则它只是裁决方意志的转写：

&#124; 情形 &#124; 处理 &#124;
&#124; --- &#124; --- &#124;
&#124; 某条判据下参与方**全部满分或全部零分** &#124; 该条无区分力，**作废、不计入总分**，裁决书说明 &#124;
&#124; 某条判据在各份候选上**都无法判定** &#124; 说明它写得不可判定，**作废**，理由记入裁决书 &#124;
&#124; 出现判据完全没预料到的优秀做法 &#124; 计入加分（设上限），标注「事后新增判据」 &#124;

**加分与扣分不对称是有意的**：事先没想到的好做法应当被奖励，
事先没写的要求不得用来惩罚。这与「方向不对称」（&#167;2.3）是同一条原则的两处应用。

</pre>

**P-036** · 源 protocol/round-protocol.md，L529–L533；SHA-256 a8f477fe4d70b7e594d205814b48902d78c3d4748c0e539d7c0ef0c48b2576c8

<pre data-unit="P-036">#### 一票否决项要事先列

哪些情形下候选**不进入最终整合的主干**（仍可被摘取局部），必须在判据里事先写明，
不得在裁决时临时宣布。

</pre>

**P-037** · 源 protocol/round-protocol.md，L534–L552；SHA-256 2e5a0d4373a142ad468124aa719c967e1fdf5f4e30fa9757495e0cbc486abbc4

<pre data-unit="P-037">## 8b. 两个脚本怎么调

都在 &#96;sunmoonai/docs/dev-plan/protocol/&#96; 下（与本文同一目录）（目录说明见该处 &#96;README.md&#96;）：&#96;round-status.py&#96;（算环节）、
&#96;round-dispatch.py&#96;（生成环节通知，**只生成不执行**）、&#96;agents.toml&#96;（五家登记，不含凭据）。
在仓内任一 worktree 的任意目录跑都可以，路径由脚本自己解析。

&#124; 命令 &#124; 作用 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;protocol/round-status.py&#96; &#124; 自动找唯一 &#96;status=ACTIVE&#96; 的轮次，算当前环节 &#124;
&#124; &#96;protocol/round-status.py --round runtime&#96; &#124; 指定轮次；值是 &#96;rounds/&#96; 下的目录名 &#124;
&#124; &#96;protocol/round-status.py --json&#96; &#124; 机器可读输出，含 &#96;current&#96; 与 &#96;conflict&#96; &#124;
&#124; &#96;protocol/round-status.py --round runtime --verify&#96; &#124; 机械验收：把 ⑤ 里机器能判的判掉，判不了的标「人判」 &#124;
&#124; &#96;protocol/round-dispatch.py&#96; &#124; 当前环节缺谁，打印给谁的命令 &#124;
&#124; &#96;protocol/round-dispatch.py --stage 4&#96; &#124; 指定环节，接 &#96;4&#96; 或 &#96;④&#96;；指不到的环节**报错退 2**，不静默退回当前环节。通知路径按**实际存在的那个**报，不硬编码拼法 &#124;
&#124; &#96;protocol/round-dispatch.py --all&#96; &#124; 不管缺不缺，给全部参与方 &#124;

**&#96;--stage&#96; 只有 &#96;round-dispatch.py&#96; 有。**&#96;round-status.py&#96; 没有这个参数——
它的职责是**算出**在第几环，接受一个「指定环节」等于把结论交回给调用者。

</pre>

**P-038** · 源 protocol/round-protocol.md，L553–L563；SHA-256 0048e80805a07890a31441c3dfd61f3f28a2be41dd091ed0d490d5955a6cea03

<pre data-unit="P-038">### 退出码

&#124; 码 &#124; &#96;round-status.py&#96; &#124; &#96;round-dispatch.py&#96; &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 0 &#124; 正常；&#96;--verify&#96; 时表示机械判定零失败 &#124; 正常输出了命令 &#124;
&#124; 1 &#124; &#96;--verify&#96; 有失败项（标「人判」的不计入） &#124; —— &#124;
&#124; 2 &#124; 用法错误：找不到该轮次、没有 ACTIVE、有多个 ACTIVE、&#96;round.md&#96; 缺字段 &#124; 拒绝分发：轮次不是 ACTIVE，或 &#96;round-status.py&#96; 判定失败 &#124;

**拒绝要有区别于成功的退出码。**&#96;round-dispatch.py&#96; 早先对已完结轮次打印一行说明后
退 0，调用方看不出自己被拒了。

</pre>

**P-039** · 源 protocol/round-protocol.md，L564–L575；SHA-256 389ec90e15acf77ad0d986ec0322a19e22a07cac83ee3a84d83570a0e45d56c2

<pre data-unit="P-039">### 声明与计算对不上时

&#96;round.md&#96; 的 &#96;status&#96; 是**声明**，环节表是从 git 提交**算出来**的。
脚本不拿声明改计算——它存在的理由就是不看任何人的声明——但两者不一致会显式报出来：

&#96;&#96;&#96;
⚠ round.md 声明 DONE，按产物却算到「⑥ 确认」。
&#96;&#96;&#96;

这行出现时，二者必有一错：要么产物没归档到判据找得到的地方，要么这一轮其实没走完。
**不许靠改 &#96;status&#96; 让它消失。**

</pre>

**P-040** · 源 protocol/round-protocol.md，L576–L580；SHA-256 ed7eef2d62055383508e8f0004b5de79f6656c4f6e51dc42dfd4ea2673c26f29

<pre data-unit="P-040">## 8c. 组织者的两条纪律

这两条都是 2026-09-07 实跑撞出来的，写在这里因为它们**跨轮次生效**，
不属于任何一轮的裁定记录。

</pre>

**P-041** · 源 protocol/round-protocol.md，L581–L603；SHA-256 2cbb6c299bb52f5fdf4c6e590bdb04694a109587ff8e5a83fa38a120398e54d7

<pre data-unit="P-041">### 8c.1 环节进行中，组织者不得写入参与方的工作区

包括 &#96;git merge master&#96;。同步只在**环节之间**做，做完再发下一环的通知。

⚠ 实例：某轮 ① 期间，组织者提交一条裁定后照惯例把主线同步进四家 worktree，
而当时有一家正在写候选。**merge 恰好无冲突所以没出事——那是运气不是纪律。**

**8c.1 补：写入之后必须验证写入成功。**

2026-09-07 实例：组织者在**环节之间**（允许的时机）同步主线，命令写成
&#96;git merge master --no-edit &gt;/dev/null 2&gt;&amp;1&#96;——主线已有裁决稿而各家分支有自己的候选，
同路径两边新增产生 &#96;AA&#96; 冲突；**输出被丢弃、退出码没检查**，
四家**全部停在合并中途**，组织者不知情，并在该状态下发出了下一环节的通知。
各家索引里因此躺着组织者的暂存改动，任何一家照常 &#96;git add -A&#96; 都会把整个未完成的合并提交进去。

**是参与方报告的，不是组织者自查发现的**——四家里两家在输出里主动指出。

&gt; **&#96;&gt;/dev/null 2&gt;&amp;1&#96; 加不检查退出码，等于把一次失败的写入当成成功的写入。**
&gt; 同步后必须逐个 worktree 核：&#96;MERGE_HEAD&#96; 不存在、&#96;diff --filter=U&#96; 为空、
&gt; 且各家自己的产物哈希未被改动。

协议此前只禁参与方之间互看，**没禁组织者往里写**。补上。

</pre>

**P-042** · 源 protocol/round-protocol.md，L604–L618；SHA-256 ac3dacaeeda4e3710c71e741740ca0017b07a08c6ebe8bac0682b7dcdca20918

<pre data-unit="P-042">### 8c.2 代提交必须用 &#96;--author&#96;，且必须登记为欠账

执行者写得出产物但跑不了 &#96;git&#96; 时（沙箱不给写 &#96;.git&#96;、或权限档不给 Bash），
由组织者代提交。**两个要求，缺一不可：**

1. **&#96;git commit --author=&quot;&lt;执行者&gt;&quot;&#96;**——git 本来就分 **author（谁写的）** 与
   **committer（谁记的）**，这正是「应用别人的补丁」的标准语义。
   两个字段都写成同一身份，等于白丢可追溯性；
2. commit message 写明**内容作者、代提交者、原因、文件 sha256**，
   并声明其性质**等同 &#96;dispatch_event{mode = manual}&#96;——人代行的动作，
   是欠账不是权力，必须可数**。

⚠ **&#96;author&#96; 字段在本机不构成证据**：无签名、各身份共用同一 git 身份，可随意填。
它只让归属**可读**，不让归属**可信**。两件事不许混。

</pre>

**P-043** · 源 protocol/round-protocol.md，L619–L623；SHA-256 046b7965313a82fc5b688c1662d82f45077e6ccd58267b72210e33a296fe80b2

<pre data-unit="P-043">## 9. ① 提案：隔离与冻结

**候选完成前不得读任何其他 worktree。**看到别人答案之后写的内容属于评审或改进，
不再是独立候选。

</pre>

**P-044** · 源 protocol/round-protocol.md，L624–L643；SHA-256 3f3790ee1ef63d193ce93cfceb8aa0d140865a9a0ce2951c20bee30b8570c42a

<pre data-unit="P-044">### 9.1 隔离为什么是硬要求

**理由不是保密，是信号质量。**B 若看到 A 的方案，产出会向 A 收敛——
拿到的是「对 A 的改写」，不是独立判断。那样问 N 家的成本花了，
**信息量却接近问一家**。

同一条逻辑早有先例：重写投影时「只读代码，禁止读本文档集，
否则产出会退化为对旧文本的改写」。

三个阶段，可见性不同：

&#96;&#96;&#96;
① 提案   各家只见工单 + 只读输入          ← 互相不可见，硬要求
② 互评   把 N 份摆在一起找分歧点          ← 此时解除
③ 裁决   允许读全部候选，产出裁决稿        ← 解除
&#96;&#96;&#96;

③ 允许读别家的候选，但**不得直接拼接**——别人的方案只作「该核对什么」的候选清单，
结论仍须回源取证重写。

</pre>

**P-045** · 源 protocol/round-protocol.md，L644–L674；SHA-256 e52e2b9a38ad023a0c688d96b589a34d2ca301997e2486111c18d3111c807ae2

<pre data-unit="P-045">### 9.2 工单发什么、不发什么

&#124; **必给** &#124; 说明 &#124;
&#124; --- &#124; --- &#124;
&#124; 原始请求 &#124; 所有者原话，一字不改 &#124;
&#124; 验收标准 &#124; 客观、第三方可判定，且**先于产出冻结**（&#167;1.3） &#124;
&#124; 只读输入 &#124; 指向入口文档，让它自己按需深入；**列全**——漏列的材料不得事后用来扣分（&#167;8.2） &#124;
&#124; 边界 &#124; 含什么 / 不含什么 / 不含的归谁 &#124;

&#124; **不给** &#124; 为什么 &#124;
&#124; --- &#124; --- &#124;
&#124; 其他家的候选 &#124; 破坏隔离（&#167;9.1） &#124;
&#124; 发起方自己的倾向或初步结论 &#124; 各家会向它收敛，等于白问 &#124;
&#124; 指定的检查点、「重点看这几处」 &#124; 划定了思考范围，没被点到的地方不会被想到 &#124;

**判断标准**：发出去的东西只描述「要什么」和「怎么算做到了」，
不描述「我觉得该怎么做」。

⚠ 2026-09-05 的 &#96;runtime&#96; 轮违反过这一条：工单 &#167;3.2 把发起方的结论
（「必须是双向且带载荷的」）写成断言并冻结为通过判据，
**使正确答案在判据下不可陈述**。五家全部照着它答，六处过度设计一处未被抓出。
这就是「不给倾向」这条的代价形态。


候选写完即提交，**提交后不得再改**。冻结方式：把候选文件的 SHA-256 与所在 commit 写进
自己的评审文件。**裁决方按 hash 从提交取候选，不从工作区文件取**——工作区会变，提交不会。

⚠ **隔离目前靠纪律，不靠机制。**各 worktree 共享同一个 &#96;.git&#96;，任何人都能
&#96;git show &lt;别家分支&gt;:&lt;路径&gt;&#96;。自动化执行后这条纪律的可靠性会下降，且**无法事后证明
某一轮真的独立**。在有工作区级隔离或读取留痕之前，本条是本协议最大的已知缺口。

</pre>

**P-046** · 源 protocol/round-protocol.md，L675–L689；SHA-256 313d76a7dd3a24271a9a9dd5c483291cab6439fffc39d6cdc11b818ff58fa1fc

<pre data-unit="P-046">### 9.3 机制化隔离：曾经有过，已经删掉

曾有一份 &#96;parallel-proposals.py&#96;，用 N 个独立进程 + 独立 &#96;CODEX_HOME&#96; 让隔离
由机制保证而非自律。2026-09-06 删除，理由三条，都不是「它写坏了」：

- **三轮一次没用过**——三轮的分发全部是所有者手工投喂；
- **核心能力从未验证**——它自己的记录写着「真实模型调用 ✗ 未验证，本机未登录、无可用端点」，
  且依赖的 &#96;openai-codex&#96; 本机未安装；
- **结构上覆盖不全**——只覆盖 codex 系执行者，五家里两家（&#96;cursor-app&#96;、&#96;qoder&#96;）用不了。

所以本节现在的结论是上一节那条 ⚠ 的重申，不是补丁：
**隔离目前靠纪律，不靠机制**，且无法事后证明某一轮真的独立。
重建时不要照抄那份删掉的实现——它按已废除的「模式 A」组织，
且覆盖不全的机制比没有机制更危险（&#167;8.1）：它会让人以为这一轮是隔离的。

</pre>

**P-047** · 源 protocol/round-protocol.md，L690–L712；SHA-256 0333dc6b3f3d835f385223506bc1f567f6ecbe2177b0ed9a378fc90c8f82eb1e

<pre data-unit="P-047">## 10. ② 互评：评审文件写什么

冻结自己的候选之后，读其余各家的候选，写评审。四块，缺一块该评审不计入裁决：

**A. 自述**（关于你自己的候选）：改了基座哪些节、新增哪些节；哪些断言未验证、标了 ⚠；
与基座的分歧；**放弃了哪些本可以写但故意没写的内容及理由**——这项能看出取舍是不是想过。

**B. 候选集冻结**：全部候选的 worktree 路径、行数、字节数、SHA-256、所在 commit。
**少一份，你的评分作废**（「产物、路径与命名」那节记的事故就是这么发生的）。

**C. 评优**：按本轮验收标准逐条给比较依据，**对全部候选（包括你自己那份）**指出强项与缺陷，
给出完整排序及该选谁当基座的理由。

- **利益冲突必须声明**：评优方同时是候选作者，这不是独立终审。把自己排第一是允许的，
  但必须给出与评别家同样标准的比较依据。
- **事实题用证据裁，不用票数裁。**多家说法一致但都没取证，输给一家带 &#96;file:line&#96; 的。

**D. 值得吸收的点**：不管你选谁当基座，逐条列出**其他候选里值得并进最终稿的具体主张**，
每条写明出自谁、在哪一节、为什么值得。

这一块是裁决阶段最有用的输入。**裁决方靠它避免只看整体印象、漏掉落选稿里的好东西**——
2026-09-03 那次失败整合正是这么丢掉了基座候选独有的锚点（见「角色不分会怎样」）。

</pre>

**P-048** · 源 protocol/round-protocol.md，L713–L723；SHA-256 ffefcb865111042c71eec4a1d0d61b6eab0a13429e8d56188a665b86b521e9e4

<pre data-unit="P-048">## 11. ③ 裁决：定基座与吸收

- **一条主张一个提交**，便于事后复核与回退；
- **从选定候选的 commit 取基座，不从任何人的工作区文件取**；
- 逐条处置，每条写明**接受 / 部分接受 / 拒绝**及理由，理由须能独立成立，
  不能只写「已处理」；部分接受要写清接受到哪、为什么止于此；
- **票数不是依据。**多数推荐某份候选，不构成选它的理由；理由必须是可复核的差异。

&#96;disposition.md&#96; 必须含一段**机器可读的处置表**，三列固定：&#96;出处家 &#124; 条目 &#124; 裁定&#96;。
&#96;裁定&#96; 取 &#96;接受&#96; / &#96;部分接受&#96; / &#96;拒绝&#96; 三值之一。验收方由这张表算出，规则见「⑤ 验收 与 ⑥ 确认」。

</pre>

**P-049** · 源 protocol/round-protocol.md，L724–L740；SHA-256 a0e351de21d20e1e5183891df29419b0a15e0d5ba006bf964c0475831c17ad5b

<pre data-unit="P-049">## 12. ④ 异议：对整合权的唯一制衡

**裁决方是全流程唯一既读全部材料、又执笔最终稿的角色。**验收查的是「这份稿子达标了吗」
（标准视角），查不到「某家的主张有没有被误读」（来源视角）——**只有原作者知道自己
原本想说什么**。没有这一环，整合的忠实度不受任何约束。

&#124; 项 &#124; 规定 &#124;
&#124; --- &#124; --- &#124;
&#124; **触发** &#124; 只发给**被处置到的家**：判断被改动、主张被拒绝或被部分接受的 &#124;
&#124; **范围** &#124; 只能就**自己那条主张的处置**提异议。不评稿子整体好坏（那是验收方的事），不替别家喊冤 &#124;
&#124; **门槛** &#124; 一条异议 = 处置条目 + 为什么错 + 应当是什么 + **可复跑证据**。「读起来更好」不受理 &#124;
&#124; **效力** &#124; **不是否决权**。裁决方可以驳回，但必须逐条给理由，连同异议原文写进处置记录 &#124;

- **必须在 ⑤ 验收之前。**验收是按冻结标准判一份定稿；验收之后再来异议，等于验收白做。
- **异议稿必须冻结提交**，不能只在对话里说——否则处置了什么、驳回了什么事后无从复核。
- 没有异议的家要**明确回一句「无异议」**并登记：空回复无法与「还没看」区分。

</pre>

**P-050** · 源 protocol/round-protocol.md，L741–L759；SHA-256 9630ce23cb1f5deb38d45ccc424485be10f7dff28eeb70f6fb36277bcaaa5805

<pre data-unit="P-050">## 13. ⑤ 验收 与 ⑥ 确认

**验收方由「③ 裁决」那节要求的处置表算出，不由裁决方凭印象指定**，规则依次适用：

1. **不得是裁决方**——整合方不能自验，这是分角色的全部意义；
2. **不得是基座作者**——验自己的稿子等于自检，基座作者存量最大；
3. 在剩下的家里，**取处置表中&#96;接受&#96;+&#96;部分接受&#96;条数最少的一家**——它对结果的既得利益最小；
4. 并列时取候选行数最少者；仍并列由项目所有者裁定；
5. 都不可用时，由项目所有者验收。

**名次与验收资格无关**，判据是既得利益不是质量。指定结果与计算过程写进处置记录，
**不得事后更换**。

验收方**只能按冻结的标准判定，不得为通过而静默修改标准**。标准不通过时，先判断是产出
没达标还是标准本身过期——标准也会腐坏；判成后者要写明理由交裁决方处置，不得自行改标准。

**⑥ 确认必须是人的显式动作。**这是全流程唯一不可逆的一步，
**不得由「收到『继续』时怎么办」那句固定指令推进**，也不得由任何 agent 代行。人确认前不得写入共享最终路径。

</pre>

**P-051** · 源 protocol/round-protocol.md，L760–L779；SHA-256 7151fe1820f7034fc6cd7e32943a0577fc180e5332418a90111783fe2d7a3cb1

<pre data-unit="P-051">### 13.1 定向审核分两阶段，防止被产出方锚定

**产出方写的「审核说明」会划定审核范围。**产出方没想到要查的地方，审核方也不会去查——
看起来独立，锚点其实全是产出方给的。**这比「自己验自己」更难察觉**，因为它有独立审核的外形。

因此凡由产出方向审核方交材料的场合（&#167;1.0 第二行的定向审核、以及任何一次 ⑤ 验收），
拆成两阶段：

&#124; 阶段 &#124; 给审核方 &#124; **明确不给** &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **一 · 独立审** &#124; 原始请求 · 产物位置 · 冻结的客观判据 &#124; 产出方的结论、自评、**自陈盲区**、指定的检查点 &#124;
&#124; **二 · 对照** &#124; 这时才给产出方的自陈盲区清单 &#124; —— &#124;

第二阶段的价值是**双向查漏**：

- 审核方发现了产出方没自陈的 → 产出方确有盲区；
- 产出方自陈了审核方没发现的 → **审核方的审核有盲区**。

两边都能被检验。跳过第一阶段直接给全套说明，这个检验就做不成了。

</pre>

**P-052** · 源 protocol/round-protocol.md，L780–L788；SHA-256 3495c7a5d802edc325e35301968efca8e5c970ce06b9b74c2f977c7d50afe989

<pre data-unit="P-052">### 13.2 验收通过意味着什么，不意味着什么

**单靠这套流程无法估计残余缺陷。**验收方找到了产出方漏的，
但**验收方漏了什么，没有任何机制能告诉你**。增加评审家数能改善估计，不能消除该盲区。

所以一轮的产出**不构成「已验证」的背书，只构成「经过一次外部检视」**。
发布说明、处置记录、&#96;handoff.md&#96; 一律照此措辞——
把「经过检视」写成「已验证」，就是 &#167;8.1 那张表的下一行。

</pre>

**P-053** · 源 protocol/round-protocol.md，L789–L802；SHA-256 04e2930c6a7233a513494300f9d42b6acf21e363ae64527b3654138a312dee87

<pre data-unit="P-053">## 14. 停止、超时与回退

**没有这一节的流程只会一路向前。**三种情况必须显式处理：

&#124; 情况 &#124; 处置 &#124;
&#124; --- &#124; --- &#124;
&#124; **某家迟迟不交** &#124; 见下一小节。**不要只说「快点」**——模糊压力下执行者会砍掉它认为最省事的部分（通常是取证与验证），而砍了什么你看不见 &#124;
&#124; **④ 异议被采纳且触及基座结构** &#124; 回到 ③ 重整合；已做的 ⑤ 作废重做 &#124;
&#124; **⑤ 验收不通过** &#124; 回到 ③；若判定为「标准本身过期」，由项目所有者决定改标准还是改产出 &#124;
&#124; **⑥ 人打回** &#124; 回到 ③ &#124;
&#124; **同一轮回退超过两次** &#124; 停下，判断是题目本身有问题还是标准写错了，不要第三次重整合 &#124;

回退不是失败，**把不合格产物推到底才是**。

</pre>

**P-054** · 源 protocol/round-protocol.md，L803–L882；SHA-256 f8fc4be2afeb30883e41a21beef559aada5603fb30f1cac0ca5ef2490f687683

<pre data-unit="P-054">### 14.1 参与方不可用：逾期、弃权与换人

**一个家不产出就卡死全轮，是自动化下最常见的停摆形态。**
所以每个环节的通知**必须给出截止判据**——没有截止的环节等于无限期阻塞。

催的方式固定为：**给明确截止 + 允许「交现状即可，未完成处原地标 ⚠ 写清缺什么」**。

**截止由该环节的组织者（①② 发起人、③ 之后裁决方）设定，写进环节通知。**
但它**不能是一个裸的时钟时间**——那样「几点合适」就变成每轮都要有人拍板的新问题，
且换一个任务规模就得重定。截止必须写成**可观测、可复算的判据**，两种合法形式：

&#124; 形式 &#124; 判据 &#124;
&#124; --- &#124; --- &#124;
&#124; **停滞** &#124; 该家的产物连续一个观察窗内**字节数无变化且分支无新提交** → 视为停止 &#124;
&#124; **未启动** &#124; **一个观察窗 &#96;W&#96;**（不是随手挑的秒数）内，**CPU 时间无增长**（&#96;ps -o etime,time&#96; 采两次取差）**且**输出无增长 → 它挂着，不是在跑 &#124;
&#124; **同侪基准** &#124; 半数参与方交付后开始计时，再等一个观察窗；窗长 &#96;W&#96; = **已交付各家从通知到交付用时的中位数** &#124;

&#96;W&#96; 由本轮自己的数据算出，**不由任何人挑数字**；任务大 &#96;W&#96; 自然大，任务小 &#96;W&#96; 自然小。
时钟时间可以作为派生结果写在通知里方便阅读，但**判据才是依据**。

三条配套：

- **零产出要先分「没起来」还是「在跑」，别急着判逾期。**字节数判据在这里无能——
  「进程没启动」与「启动了但慢」的观测值**完全相同**，都是零。
  **&#96;ps -o etime,time&#96; 的 CPU 时间是缺的那个信号**，但**必须取差、必须与输出联判**：
  2026-09-07 实测，某家进程存活 **17 分 29 秒**、CPU **&#96;00:00:00&#96;**、
  日志停在 39 字节——三条一起才成立（它卡在读 stdin，一步没跑）。
  按字节判据会判成「在推进，不催」，白等一轮。

  ⚠ **CPU 时间的绝对值不是判据。**同日实测：另一次分发起步 14 秒时
  CPU 同样是 &#96;00:00:00&#96;，而日志已 1527 字节且在增长——**等网络的 agent 本来就几乎不耗 CPU**。
  只看绝对值会把正在干活的一家判成挂死。
  **这条规则的初稿就是这么写的，当天就被下一次观测证伪**——留着这句，
  是因为「把一次观测直接升格成判据」是本文档反复点名的形态，而它连本节自己都没放过。

  ⚠ **窗口不许拍脑袋。**同日第三次实测：把间隔设成 **25 秒**，判据当场把一个
  正在正常输出的执行者判成「挂着」——日志 297 KB 且**一秒前还在写**。
  对等模型响应的 agent，二十几秒不动完全正常。
  **本节开头那句「&#96;W&#96; 由本轮数据算出、不由任何人挑数字」对停滞判据同样成立**，
  而我在监视脚本里挑了个数字。判据的**形状**对，**窗口**是拍的——
  形状对而窗口错，结论照样是错的。

  ⚠ 反过来同样不成立：CPU 无增长只证明「这段时间没在算」，
  **不得据此写成「它没启动」**——那是把「没查到」写成「没有」。

  三次修订同一条判据（初稿只看 CPU 绝对值 → 加输出联判 → 窗口须为 &#96;W&#96;），
  **每一次都是被下一次观测证伪的**。留下这段修订史，是因为
  「一次观测直接升格成判据」在本文档里已被点名多次，而它连本条自己都没放过。
- **停滞判据优先于任何时间线。**产物还在长就不算逾期——
  2026-09-04 那次的实例：某家候选在 45 分钟里从 89 KB 长到 99 KB，
  据此判定「在推进，不催」，最终它交出的是四家中体量第二大的完整候选，没有被催成半成品。
- **宣布逾期前必须跑一次判据并把观测值留痕**（字节数、时间戳、分支 HEAD）。
  「到点了」不构成宣布逾期的理由，观测值才是。
- **可延长，不可缩短。**组织者延长观察窗只需记录；**缩短须经人确认**——
  缩短等于更容易把参与方判为弃权，即剥夺一次检查，方向危险。

逾期的后果按环节不同，因为「缺席」在各环节的含义不同：

&#124; 环节 &#124; 逾期后果 &#124;
&#124; --- &#124; --- &#124;
&#124; ① 提案 &#124; 该家不出候选，本轮 &#96;N&#96; 减一，不阻塞其余；&#96;N&#96; 降到 1 时停轮问人 &#124;
&#124; ② 互评 &#124; 该家评审不计入裁决；**其候选仍在池中**，由别家评 &#124;
&#124; ④ 异议 &#124; 视为**弃权**，流程继续 &#124;
&#124; ⑤ 验收 &#124; 验收方视为**不可用**，按同一判据顺位换人（见「⑤ 验收 与 ⑥ 确认」）。顺位须在通知里预先声明 &#124;
&#124; ⑥ 确认 &#124; **不设逾期默认。**人不确认就不发布，没有超时通过这回事 &#124;

**逾期默认的方向必须保守：只有当该环节之后仍有独立检查时，才允许默认放行。**
④ 之后还有 ⑤ 与 ⑥ 两道，所以异议可以默认弃权；⑤ 与 ⑥ 是最后的检查，
**最后一道关卡不设默认通过**——⑤ 逾期换人，⑥ 逾期就等。

**弃权不等于同意。**留痕必须写「未响应」，不得写成「认可」——
事后复盘时，「没人反对」和「没人看过」是两件完全不同的事。

**换角色只有一个合法理由：该家不可用**（不响应、逾期、退出）。

- 换人须记入处置记录：原因、原指定方、新指定方、按同一判据的顺位计算；
- **顺位应在环节开始前就在通知里预先声明**，避免事后裁量；
- **不得以「对结果不满意」换人**——那正是「不得事后更换验收方」禁止的事。
  区别在于：不可用是**该家的状态**，不满意是**裁决方的偏好**。

</pre>

**P-055** · 源 protocol/round-protocol.md，L883–L901；SHA-256 ebd100ea22ee1090a73729b0e7f89a227f22545f0ef14fb4cc0446dda6a59f6b

<pre data-unit="P-055">## 15. 角色不分会怎样

2026-09-03 有一次整合失败，毛病全部源于角色不分，逐条记在这里当反例：

&#124; 毛病 &#124; 后果 &#124;
&#124; --- &#124; --- &#124;
&#124; 整合方同时是参赛方 &#124; 自己裁自己那份，无人复核 &#124;
&#124; 无互评轮 &#124; 各家的独有发现没人指认，只能靠整合方一人扫描 &#124;
&#124; **无异议轮** &#124; 整合是否忠实于来源无人可查——验收按标准判合规，判不到「主张被误读」 &#124;
&#124; 无独立验收 &#124; 下面两条本该被逮住，全部漏网 &#124;
&#124; 与既有权威文档大量重复 &#124; 自编一套不变量与已定稿的编号并存，且遗漏若干条 &#124;
&#124; 弄丢基座的长处 &#124; 基座候选独有的稳定 ID 锚点被抹成散文，全稿此类 ID 出现 0 次 &#124;

**分角色的意义是**：裁决方不提案，所以整合可信；裁决方不验收，所以判定可信；
来源方可提异议，所以整合的忠实度可查。这三条缺一条，这一轮的产物就没有可信来源。

**这份协议自己也漏过一次**：异议轮在 2026-09-02 那轮实际走过，却没被写进环节表，
以致 09-04 的 refact 轮差点跳过它——**流程里没写下来的环节，等于不存在。**

</pre>

**P-056** · 源 protocol/round-protocol.md，L902–L916；SHA-256 d87754dac30c4231ce0b2bec8d2fc2c093617fec19df84bba03b8d3807a38a8c

<pre data-unit="P-056">## 16. ⑦ 清理与发布

**顺序是：人确认 → 清理各分支产物 → 写入共享最终路径。**

&#124; 对象 &#124; 处置 &#124;
&#124; --- &#124; --- &#124;
&#124; 各提案方 worktree 的候选 &#124; 删除。内容在各自分支的提交里，git 历史可取 &#124;
&#124; 裁决方整合分支的裁决稿 &#124; 删除或并入最终稿 &#124;
&#124; 各家评审、异议、验收稿 &#124; 删除；结论已进处置记录。需长期保留的另行决定 &#124;
&#124; 处置记录 &#124; 由人决定保留或压缩为指针 &#124;
&#124; &#96;round.md&#96; &#124; &#96;status&#96; 改 &#96;DONE&#96; &#124;

**先清理再写入**：候选与最终稿同名同路径，不先清理，各分支后续与主线同步时会把候选态
当成本地修改，产生本可避免的冲突。清理后各分支重置到发布点。

</pre>

**P-057** · 源 protocol/round-protocol.md，L917–L929；SHA-256 2900fa181f1b50354db85878410a334942c2eb7896820028a74c7a3492c58be9

<pre data-unit="P-057">## 17. 通用纪律

- **产物只写自己的 worktree**，主线只读，任何人不得在提案期写主线；
- 候选绑定不可变 commit，并声明覆盖/未覆盖范围、假设、盲区、缺陷与关键主张证据；
- 做不成的老实标 ⚠，不假装已完成；未验证的结论标注清楚，不把推断写成事实；
- 评审、异议、验收同样是产出，同样要自陈盲区；
- **任务书冻结后不得中途修改**。已开工的执行者按旧版做，改了会让已完成的部分对不上；
  发现任务书有错，记进处置记录，在下一轮修。
- **引用本协议按标题，不按章节号。**章节会移动，标题不会。本仓已有同源约定：
  REQ 模板要求「引用决策点一律用 ID：&#96;REQ-006 D7&#96;，不带章节号——章节会移动，ID 不会」。
  起草本节时插入一节导致其后章节全部后移，当场就有两处内部引用失效，
  其中一处在移位前就已经指错——**章节号是会静默腐坏的引用方式**，
  机械检查只能验「该章节存在」，验不了「指的是不是那一节」。
</pre>

### protocol/README.md（P）

解释实现与规范必须共改，然后给设计约束、单一真源和已知不做；避免脚本使用者把欠账当能力。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 脚本接口及实现约束 | 可执行接口、状态计算责任及已知限制；不收当轮执行日志。 | T-001, T-002, T-003, T-004 |

#### 脚本接口及实现约束

**T-001** · 源 protocol/README.md，L1–L22；SHA-256 758978d92e753c343ff2c33bdb8f39cf0c342fb2c54237c92f15c287c1c6aefc

<pre data-unit="T-001"># &#96;protocol/&#96; —— 流程规范与它的实现

一个目录装两样东西，**因为它们必须一起改**：

- &#91;&#96;round-protocol.md&#96;](round-protocol.md) —— **规范**，今后开发的指导。流程该怎么走由它说了算。
- 三个可执行文件 —— **目前在用的实现**，同时是将来把这套流程做进运行时的参考。

两者对不上时以规范为准，并按协议 &#167;3 起一个工作单元去改。
**改了脚本的参数名或退出码，必须同步改规范的「8b」一节**——那一节里每条命令都以能实跑为准。

&gt; 目录名是 &#96;protocol/&#96;（单数、无 s），与轮次档案目录 &#91;&#96;../rounds/&#96;](../rounds/) 只差一个字母，
&gt; 别混：&#96;rounds/&#96; 装的是每一轮的产物，本目录装的是流程本身。

&#124; 可执行文件 &#124; 是什么 &#124; 对应协议哪一节 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#91;&#96;round-status.py&#96;](round-status.py) &#124; 从**产物**反推当前环节；&#96;--verify&#96; 把 ⑤ 里机器能判的部分判掉 &#124; &#167;8 环节判定、&#167;8.1 判据自身的质量 &#124;
&#124; &#91;&#96;round-dispatch.py&#96;](round-dispatch.py) &#124; 算出「现在该叫谁、说什么」，**只生成命令不执行** &#124; &#167;6.1 环节通知 &#124;
&#124; &#91;&#96;agents.toml&#96;](agents.toml) &#124; 五家执行者登记：harness、调用方式、可观测粒度。**不含任何凭据** &#124; &#167;2.3 登记集合 &#124;

调用方式与退出码写在协议「8b. 两个脚本怎么调」，那一节里每条命令都以能实跑为准——
**改了参数名必须同步改那一节**。

</pre>

**T-002** · 源 protocol/README.md，L23–L32；SHA-256 8dd0ec495565418d52aa031b0b2914dbc96d21b0195e10af76d984646d3f0091

<pre data-unit="T-002">## 三条设计约束，改这里的代码前先读

1. **结论只依赖 git 提交，不看工作区。**一切判定走 &#96;git ls-tree&#96; / &#96;git show&#96;。
   同一个仓库状态在任何机器上给出同一结论。此前被删掉的两个脚本就是栽在这条上——
   同一份文档在三台机器上报 0 / 4 / 95 条失败。
2. **判不了的显式标出，不许默默不查。**判不了不是缺陷，**假装判了才是**。
   &#96;--verify&#96; 里标 🔶人判 的项一律不计入通过。
3. **空集合不是「全部完成」。**&#96;all({})&#96; 为真。要跳过某个环节，必须在 &#96;round.md&#96;
   明写 &#96;skip_stages&#96;；字段留空不算数。

</pre>

**T-003** · 源 protocol/README.md，L33–L38；SHA-256 9a2e394190bc97aa4962cd6bb0125e79604efbc7b749385b29da7be80132fbcd

<pre data-unit="T-003">## 单一真源

状态不各算各的：&#96;round-dispatch.py&#96; 一律调 &#96;round-status.py --json&#96; 取状态，
不自己重算一遍环节。轮次的全部参数在 &#96;rounds/&lt;round-id&gt;/round.md&#96; 的 &#96;&#96;&#96;toml&#96;&#96;&#96; 块里，
人读正文、机器读那个块——同一份文件，两个读者，不产生第二个会漂移的真源。

</pre>

**T-004** · 源 protocol/README.md，L39–L46；SHA-256 74ae159d70b850782f7c0e691e8cfdc2fdf00c52ae573051a405e69284eb9639

<pre data-unit="T-004">## 已知不做的事

- **不执行分发。**&#96;round-dispatch.py&#96; 只打印命令，粘贴由人做。理由在协议 &#167;8.1 第 3 条：
  一个检查第一次运行时最可能发现的是它自己判错了，而分发脚本判错的代价是几家同时干错一个环节。
- **不覆盖 ⑥ 确认的内容。**它只判人的确认有没有**落盘**（读 &#96;rulings.md&#96; 的「人确认」列），
  内容对不对是人的事。
- **不管文档门禁。**那是 &#91;&#96;../doc-gate.py&#96;](../doc-gate.py)（挂在 pre-commit）
  与 &#91;&#96;../anchor-gate.py&#96;](../anchor-gate.py)（手工跑），与本目录无关。
</pre>

### work/roadmap.md（W）

先列产品阶段及各阶段输入，再列运行时从手工退出的依赖门；不凭时间顺序宣称依赖已满足。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 产品建设阶段 | 要建什么及开工条件；含历史现状的段落按源日期读取，需要最新事实时另取证。 | D-006, D-007, D-008, D-009 |
| 运行时迁移顺序 | G0–G5 依赖及分组件退出门作为待实施路线；通用删除纪律引用 maintenance。 | G-084, G-085 |

#### 产品建设阶段

**D-006** · 源 development-plan.md，L64–L67；SHA-256 50d3034d4b55f0386612c9fbb787f7d91f85521bf8fd90b1b43defcbeb94da7a

<pre data-unit="D-006">## 三个阶段

**一 前后端对接 → 二 agent 开发 → 三 问数。**

</pre>

**D-007** · 源 development-plan.md，L68–L96；SHA-256 e5b2fd6f3530dee79af89b7f91042b0998bf1da6ebbbc63e18aee27e0148deb6

<pre data-unit="D-007">### 一 · 前后端对接

**缺口是确切的：两边路由已经对称，缺中间那个适配器。**

&#96;&#96;&#96;
浏览器 → /api/web/v1/runs …（7 条，已存在）
              ↓
      WebInteractionPort ← 只有两个实现，都不能用于生产
              ↓
      /api/internal/v1/investment/runs …（5 条，已存在，Pilot 链路在跑）
&#96;&#96;&#96;

&#124; 实现 &#124; 状态 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;UnavailableWebInteractionAdapter&#96; &#124; 生产默认，一律 **503** &#124;
&#124; &#96;ReferenceWebInteractionAdapter&#96; &#124; 确定性夹具，**生产配置明令拒绝**（检出 &#96;REFERENCE_INTERACTION_ENABLED&#96; 为真即拒绝启动） &#124;

即：**web 面没有任何生产实现**，四个仓都是这个状态。

前端栈不是缺口：八个前端均 Next.js 16.2.2 + React 19.2.4，与 v5 &#167;10.10 的
目标态一致（唯一差异：v5 要求 Admin 用 Ant Design 6，实际未引入）。

做这一阶段时逐节引用 v5 &#167;10：&#167;10.1 对象边界 · &#167;10.2 事务原则 · &#167;10.3 SSE 对账 ·
&#167;10.4 前端 API 边界 · &#167;10.5 Web 交互状态机 · &#167;10.7 安全与隐私 · &#167;10.9 观测与测试。

**&#167;10.4 的 BFF 问题仍然开放**，别当它已被否决：Next.js 可以承担浏览器同源
BFF / session 边界，但不得成为领域数据所有者；且授权分工必须有显式契约
（规则 I4、I5）。用不用 BFF 是这一阶段要定的事。

</pre>

**D-008** · 源 development-plan.md，L97–L109；SHA-256 36a9c3a4830131f870225ebb9687fef4c6f81192261ba6ce9fb37a787f5cf51e

<pre data-unit="D-008">### 二 · agent 开发

即上面「智能体分两部分」几节。

**四本账已有两本是真的**，不是从零建四张表：

&#124; 账 &#124; 表 &#124; 生产接线 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 幂等 &#124; &#96;idempotency_key&#96; &#124; ✅ 8 个源文件在用 &#124;
&#124; 副作用 &#124; &#96;tool_side_effects&#96; &#124; ✅ &#96;tasks/agent_graph.py&#96; 的 &#96;record_once&#96; &#124;
&#124; **预算** &#124; 无 &#124; ❌ 只有内存 &#96;RunBudget&#96;，跨进程即失 &#124;
&#124; **证据** &#124; 无 &#124; ❌ citation 只在事件流里，不落表 &#124;

</pre>

**D-009** · 源 development-plan.md，L110–L133；SHA-256 66ba02171e4827bee6b9be29a18e7858cbae3125a3343c3f1c4e7ff32dffba06

<pre data-unit="D-009">### 三 · 结构化数据问答（后期）

归**专用部分**——它是专用智能体的一个实例，加一份 Profile 加一个工具，
不是另一套架构。

理由是范围控制，不是能力归属：定位为通用会诱导第一版支持任意数据源与 schema，
在跑通一条真实链路之前先铺抽象。**抽象推迟到第二个领域需要时再做**——
不到第二个用例，不知道通用的边界在哪；提前抽出的&quot;通用&quot;多半是投资的形状
套了通用的名字，比不抽更糟。

**开工前必须先解决一件事：投资仓现在没有任何业务数据表。**13 张表全是运行时
基础设施（agent 运行时 / LangGraph checkpoint / outbox / auth），全仓
&#96;portfolio&#124;holding&#124;ticker&#124;instrument&#96; 命中数为 0。**没有数据就没有问数。**

参考资料在 &#96;~/codex-reference-archive/&#96;（2026-08-29 核）：

&#124; &#124; 现状 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;sqlbot-opus.md&#96; &#124; SQLBot 是**完整问数应用**，SQL 安全防护默认开启 &#124;
&#124; &#96;wrenai-opus.md&#96; &#124; WrenAI **已转型**为&quot;给 agent 用的语义上下文层&quot;，旧 GenBI 应用冻结在 &#96;legacy-v1&#96; 分支 &#124;

两者不再是同类产品的两个选项。**两份调研都未评估准确率**——真要选型时，
那是核心指标。

</pre>

#### 运行时迁移顺序

**G-084** · 源 agent-dev-guide.md，L1988–L2001；SHA-256 e4a5aa5ce8299f752bb5084d60ed536266b4f817106a69a3282d7ea7d44f1224

<pre data-unit="G-084">### 7.1 依赖顺序

&#124; 步 &#124; 产物 &#124; 前置 &#124; 退出条件 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; G0 &#124; 协议、状态脚本与分发脚本一致 &#124; 无 &#124; 历史已完成轮次和空轮次均得到人工一致的状态结果 &#124;
&#124; G1 &#124; Interaction 现状 spike &#124; G0 &#124; 真实中断、同 thread 恢复、stale/重复/跨 Task 拒收有可复现实验 &#124;
&#124; G2 &#124; 服务端 principal channel 与 Side Effect 强制点 &#124; G1 &#124; executor 无权伪造响应或直接写生产，失败关闭；不依赖本机可改门禁 &#124;
&#124; G3 &#124; Agent Profile + executor adapter + 角色冲突门 &#124; G1/G2 &#124; 每个自动候选至少跑通一次 Attempt，字段值有探针证据 &#124;
&#124; G4 &#124; &#96;dev.change/1&#96; 服务态与 T0/T1/T2 execution policy &#124; G2/G3 &#124; 三档真实 Task 与手工历史按 &#167;5.3 等效，证据强度不下降 &#124;
&#124; G5 &#124; 文档与脚手架收口 &#124; G4 &#124; 逐节迁移零缺口、引用清零、门禁全过、旧稿删除经人确认 &#124;

G1 是本轮对旧路线的修正：先验证现有库原语，不先发明字段。G2 的判据针对真实写路径和服务端身份，
不以新增 Git 仓或轮换网络 key 代替产品授权。当前阶段游标仍以 handoff 为准；目标顺序不因现状阻塞而改写。

</pre>

**G-085** · 源 agent-dev-guide.md，L2002–L2037；SHA-256 b2806934c0490b65fb5bfb64d3b87f0c9220124809f721306055abb304f4664f

<pre data-unit="G-085">### 7.2 从手工态拆到服务态

&#124; 手工实现 &#124; 服务实现 &#124; 可拆条件 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;round.md&#96; Task 主档 &#124; Task 表 &#124; 三档至少各一条轨迹等效且 provenance 不下降 &#124;
&#124; commit + rulings + events 投影 &#124; Event 表 &#124; 同一历史轮次输出相同状态序列，新判据已人工对照 &#124;
&#124; 落盘通知与人工投喂 &#124; executor adapter / principal channel &#124; 自动执行器有进程入口；人工执行器有显式审计桥 &#124;
&#124; &#96;round-status.py --verify&#96; &#124; acceptance runner &#124; 对历史轮次逐条判定一致 &#124;
&#124; &#96;git worktree add&#96; &#124; provision service &#124; 独占、干净、基线判据进代码并有测试；worktree 载体可保留 &#124;

事务、租约、fencing 只有服务态验收通过才算实现，不能用轨迹“相似”替代。

⚠ **而服务态那一侧已经验过了，这一栏因此不是「未来才能做的事」。**
产品仓（PostgreSQL 载体）现有测试全部通过，实跑 **156 passed, 2 skipped in 5.13s**：

&#124; 项 &#124; 测试 &#124;
&#124; --- &#124; --- &#124;
&#124; fencing &#124; &#96;test_expected_version_prevents_two_workers_claiming_same_run&#96; &#124;
&#124; 租约 / 并发 &#124; &#96;test_relational_schema_enforces_identity_and_concurrency_constraints&#96;、&#96;test_same_thread_rejects_second_non_terminal_run&#96; &#124;
&#124; 副作用恰好一次 &#124; &#96;test_interrupt_resume_executes_side_effect_once&#96;、&#96;test_retry_after_crash_after_commit_does_not_repeat_effect&#96; &#124;
&#124; 陈旧覆盖被拒 &#124; &#96;test_versioned_reducer_rejects_stale_plan_overwrite&#96; &#124;
&#124; 取消先于副作用 &#124; &#96;test_cancelled_run_stops_before_side_effect_and_releases_thread&#96; &#124;

**所以缺的不是「并发语义没人验」，是「手工态与服务态的等效比对」还没做。**
两句话差别很大：前者指向一件未开工的事，后者指向一件已完成一半的事。

⚠ **这一段也曾写偏过。**「**git 载体**验不了这三样」这句本身成立，
但整份文档只写了这一句，**读起来像「本项目至今没验过」**。
教训：**「某载体证不了 X」与「X 未被证明」是两件事，不许合写。**

拆脚手架按组件逐项判，不因服务部署成功整批宣布完成：Task/Event 要比完整状态序列；
acceptance runner 至少对三轮可取得的历史产物逐条对照；每个拟自动路由的 Agent Profile
实际跑通一次 Attempt；人工桥接仍需记账；Interaction 还须证明响应者身份进入不同于执行者的
受保护凭据域。轨迹各类 attested 数量与最低 provenance 都不能退步。
这些是迁移验收条件，**不表示本次已完成等效实验**。

</pre>

### work/delivery.md（W）

保留产品任务及前置的原始次序，通用表单迁出后本文件只回答做哪项、依赖什么、怎么验收；旧框架路线按现行 guide 明确的处置存历史。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 产品任务 | 阶段一空任务清单及阶段二/三前置完整保留；未决前不开工不能被空表覆盖检查掩盖。 | I-006, I-007, I-008, I-009 |

#### 产品任务

**I-006** · 源 implementation-plan.md，L77–L78；SHA-256 292e785931b999e1f3895dbea75b888f289a6a6090681198c1354e714c7d1f7a

<pre data-unit="I-006">## 阶段一 · 前后端对接

</pre>

**I-007** · 源 implementation-plan.md，L79–L85；SHA-256 48cf99f4ff8bdd38ae24437d3fcd15160e0e1b5c10d261a449bde365acd42ca4

<pre data-unit="I-007">### 任务清单

**空。**U1（web 面生产适配器的形状）未定——薄转发还是自持投影，决定了要写
什么、测什么、有没有迁移。现在列出来的任何任务都会作废。

U1 一定，本节即刻填充。U1 的已知输入见 &#91;&#96;handoff.md&#96;](handoff.md)。

</pre>

**I-008** · 源 implementation-plan.md，L86–L89；SHA-256 828e363521485eb77cab504595f18b9fdce7de18ecf5f8b82c6e4c5114911c3a

<pre data-unit="I-008">## 阶段二 · agent 开发

未开工。见 &#91;&#96;development-plan.md&#96;](development-plan.md)。

</pre>

**I-009** · 源 implementation-plan.md，L90–L93；SHA-256 ae0a101c22b064d01722c78153217cea0fb801e91f28d5d67b9c4858bca463ad

<pre data-unit="I-009">## 阶段三 · 结构化数据问答

未开工，且有一个开工前置：投资仓现在没有任何业务数据表。
见 &#91;&#96;development-plan.md&#96;](development-plan.md)。
</pre>

### work/status.md（W）

按观察日期记录产品阶段、就位能力和游标；更新状态不得顺手更新规范，旧框架路线的进度随旧计划存历史。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 产品状态 | 阶段、已就位能力与任务游标是观察字段；不从没有调用推出不需要调用，也不将八月观察升级为今天现状。 | H-002, H-003, H-010 |

#### 产品状态

**H-002** · 源 handoff.md，L14–L20；SHA-256 a5f226a4399cd6c7405dd15c0132b9a2013b6455fbb1c11e6f012f3f27339c68

<pre data-unit="H-002">## 当前阶段

**一 · 前后端对接。**

阶段二（agent 开发）与阶段三（问数）尚未开工，见
&#91;&#96;development-plan.md&#96;](development-plan.md)。

</pre>

**H-003** · 源 handoff.md，L21–L29；SHA-256 34b79d8a45ed5de8fb9833f1e9ca305e1678642fbd54ff6838e4e8e1cdcabc04

<pre data-unit="H-003">## 已经就位的（不用再做）

&#124; &#124; 状态 &#124; 取证 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; web 面 7 条路由 &#124; 已存在 &#124; &#96;/api/web/v1/runs&#96; &#96;…/{id}&#96; &#96;…/events&#96; &#96;…/actions&#96; &#96;…/cancel&#96; &#96;…/citations/{id}/source&#96; &#96;…/reference/sources/{id}&#96; &#124;
&#124; internal 面 5 条路由 &#124; 已存在，Pilot 链路在跑 &#124; &#96;/api/internal/v1/investment/runs&#96; &#96;…/{id}&#96; &#96;…/commands&#96; &#96;…/events&#96; &#96;…/citations/{id}/source&#96; &#124;
&#124; 前端栈 &#124; 八个前端 Next.js 16.2.2 + React 19.2.4 &#124; &#96;package.json&#96; &#124;
&#124; 四本账之幂等、副作用 &#124; 已落表并接线 &#124; &#96;idempotency_key&#96;、&#96;tool_side_effects&#96; &#124;

</pre>

**H-010** · 源 handoff.md，L93–L97；SHA-256 ec4a33c74a659f5e6141594410ad6bdb102c96a7b0f79d4189c1cc1f50fced27

<pre data-unit="H-010">## 任务游标

**阶段一未开工**——U1 未定，&#91;&#96;implementation-plan.md&#96;](implementation-plan.md)
的任务清单为空。

</pre>

### work/questions.md（W）

先列阻塞产品任务的 U 项及已知输入，再列跨模块风险、未验证与文档待办；每项可被明确证据关闭。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 未决输入 | U1–U5 与其已知事实作为决策材料，不从已知字段推出方案已定。 | H-004, H-005, H-006, H-007 |
| 风险与验证债 | 现有风险和 SDK 未验证清单先于开工；不能把列表存在当作验证完成。 | G-087, G-089, H-013, H-009 |

#### 未决输入

**H-004** · 源 handoff.md，L30–L41；SHA-256 c0ed70dcce404cbadcaaa538c29599dd9dda059055c1807b9c5a2055f77ce9a8

<pre data-unit="H-004">## 未决项

**每项定下来之前不要开工依赖它的部分。**

&#124; # &#124; 未决 &#124; 阶段 &#124; 为什么它卡着别的 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; **U1** &#124; **web 面生产适配器的形状**：薄转发（web → internal 面），还是自己持有会话与投影？ &#124; 一 &#124; 决定 v5 &#167;10.2 事务原则与 &#167;10.3 SSE 对账落在哪一层 &#124;
&#124; U2 &#124; 执行层 Port 的接口形状 &#124; 二 &#124; 决定纪律层怎么被测试。cursor 提案见 &#96;~/codex-reference-archive/cursor/investment-agent-architecture-cursor.md&#96; &#167;3 &#124;
&#124; U3 &#124; **预算账与证据账**落 PG 的表结构与迁移 &#124; 二 &#124; 一切并行工作的前置——没有预算闸门就不能 fan-out &#124;
&#124; U4 &#124; &#96;AgentProfile&#96; 的具体字段 &#124; 二 &#124; 专用部分的载体 &#124;
&#124; U5 &#124; 外部 harness 的部署形态（服务端如何管理其进程与凭据） &#124; 二 &#124; 影响 U2。本分支提案见同一可行性文 &#167;2 / &#167;9 &#124;

</pre>

**H-005** · 源 handoff.md，L42–L50；SHA-256 0ba1033af120563e340701b9d5da301a5ad213fa317abca3be69aa0ec442108b

<pre data-unit="H-005">### U1 的已知输入

- 规则 **I1**：接口分面共享 application 用例，不是三套应用层
- 规则 **I4**：Next.js 可做同源 BFF / session 边界，但不得拥有领域数据
- 规则 **I5**：授权分工必须有显式契约；**不信任任何上游声明的身份**
- 两扇门的身份不同：internal 面认服务令牌 + &#96;X-Delegated-Actor-ID&#96; 头声明的用户；
  web 面**不能信浏览器的声明**，必须从会话取
- 现成参照：&#96;ReferenceWebInteractionAdapter&#96; 的 &#96;_authorize&#96;

</pre>

**H-006** · 源 handoff.md，L51–L58；SHA-256 63e1448c2e8619a3342a049743f491e7982d88b04187c712a0c0db5139dfe4c8

<pre data-unit="H-006">### U3 的已知输入

- 现有 &#96;RunBudget&#96; 在 &#96;domain/agent/runtime.py&#96;，是**内存态 pydantic model**，
  随 graph state 传递，进程一死即失——**载体要换，不是接线**
- 唯一消费者 &#96;first_m1_graph&#96; 只被 &#96;scripts/agent_golden.py&#96; 与一个 golden 测试用到
- 生产链路 &#96;pilot_service&#96; 只有一行 &#96;budget_exceeded → failed&#96; 状态映射
- 字段可沿用：steps / tool_calls / llm_calls / input_tokens 的上限与已用量

</pre>

**H-007** · 源 handoff.md，L59–L67；SHA-256 5512fca05def7601d853e9f3b288074e1b020d3a3e3216051c49bd54f76744c5

<pre data-unit="H-007">### U4 的已知输入

- &#96;AgentProfile&#96; 已存在于 &#96;domain/agent/profiles.py&#96;，已有两个实例
  （&#96;default_research&#96;、&#96;literature_review&#96;）
- **但 Profile 目前不生效**：&#96;RunService.create_run&#96; 解析并把 key/version 写进
  run 行，&#96;dispatch_agent_graph&#96; 只传 run_id / user_input / security_context，
  两条生产图对 &#96;allowed_tools&#96; 等的引用数为 0。**它现在是审计字段，不是约束**
- &#96;mooc-manus-langgraph-longterm-plan-v4.md&#96; &#167;20 有一份 102 行的结构可作输入

</pre>

#### 风险与验证债

**G-087** · 源 agent-dev-guide.md，L2073–L2103；SHA-256 f12187998cf5644e487428aee4d2238cae6034c1cdbde1a527ce9e36ee189e0f

<pre data-unit="G-087">### 7.4 风险和未决

**逐条登记，每条带处置。**只写「有风险」而不写「现在怎么办、什么条件下才动」的清单，
下一轮没人知道该不该碰它。

&#124; # &#124; 事项 &#124; 状态与处置 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; Agent Profile 的实际模型、GUI 内部事件与部分 CLI 工具事件不可机械核验 &#124; ⚠ 未验证；登记表相应字段标 ⚠，**不得用未核值反推能力** &#124;
&#124; 2 &#124; 无进程入口的分发者永久需要人工桥 &#124; 登记为**可计数的欠账**（&#96;dispatch_event{mode=manual}&#96;），**不伪装成自动化** &#124;
&#124; 3 &#124; principal 确认与 agent 共享宿主身份 &#124; 证据只能标 &#96;reported&#96;；身份边界未落地前不得写成 &#96;attested&#96; &#124;
&#124; 4 &#124; **H5-final / H5-round 拆分**：轮内产物写主线的管辖 &#124; 未决；已由前轮登记，**本文不擅自改权力表行数** &#124;
&#124; 5 &#124; **H5 的机制化强制点** &#124; 两个有效方向均需所有者动作；现状登记为「人的显式动作」 &#124;
&#124; 6 &#124; **响应者身份鉴别**（Interaction 服务化的前置） &#124; 未决；**信任域收紧前不拆** &#124;
&#124; 7 &#124; typed review／ruling／acceptance 是否只是 Artifact 类型细化 &#124; 未决；若属对内核 Attempt 定义的扩充，按内核修订纪律另起工作单元 &#124;
&#124; 8 &#124; **结构化修订（部分否定／替代）的规范形状** &#124; 未决；**必须用库原语构造**，不得反推平台级 patch 协议 &#124;
&#124; 9 &#124; &#96;retroactive&#96; 登记与内核 &#96;I1&#96;「原始输入不被后续解释覆盖」的关系 &#124; 未验证；建单时一并核 &#124;
&#124; 10 &#124; 独立性按 &#96;harness&#96; 或 &#96;(harness, model)&#96; 分组 &#124; ⚠ 无跨题数据；**只能作观察值**，由「候选相似度」校验后再定 &#124;
&#124; 11 &#124; **T0 的「可逆出口」**（只落 worktree、免 H5） &#124; 未决；属**省事方向**的新权力表行，须有签名次数数据后再议 &#124;
&#124; 12 &#124; **「命中任一条即 T2」中「权威层」覆盖面过宽** &#124; 判据属流程规范，改它由该规范自己的轮次处理 &#124;
&#124; 13 &#124; **触点疲劳导致盖章化** &#124; 观察值：回执耗时、相对预填的改动项数、每类触点次数；**不设自动动作** &#124;
&#124; 14 &#124; **单 principal 阶段的权力表在多用户场景是否够用** &#124; 表结构已按 principal 设计；capability 列等出现第二个 principal 再加 &#124;
&#124; 15 &#124; **三值路由初期大量 &#96;ask&#96;** &#124; 预期行为；每次 &#96;ask&#96; 的人工选择按「裁量是规则的孵化器」反哺规则表 &#124;
&#124; 16 &#124; 内核演化冲击本文 &#124; 三条：按 commit 引用内核、内核改动按最重档、改后重跑状态词比对 &#124;
&#124; 17 &#124; **&#96;QUEUED&#96; / &#96;RUNNING&#96; 在事件落地前不可判** &#124; 已声明；脚本合并显示并标 ⚠ &#124;
&#124; 18 &#124; **H1 与 H5 落在同一 commit 时账本上的歧义** &#124; 未决（服务态应是两个 Interaction；手工态今天做不到） &#124;
&#124; 19 &#124; 运行时外的绕过天然不完备 &#124; principal 侧指标在共享身份下是 &#96;UNKNOWN&#96;，**不得写成零** &#124;
&#124; 20b &#124; **&#96;llm-review&#96; 能否用于任何 &#96;auto_policy = 无&#96; 的权力表行** &#124; 未决。&#167;4.7 立了四档审批，但 &#96;llm-review&#96; 不是 principal 的权力，在 &#167;4.2 权力表里没有行。⚠ **本文不裁**——它要么是 H 行的一个前置过滤器，要么根本不该出现在需人批准的路径上，两种读法后果不同 &#124;
&#124; 20 &#124; 预算账、证据账与 Agent Profile 生效仍是后续工作 &#124; 见 &#96;handoff.md @ ed0b5136:14-19&#96;、&#96;handoff.md @ ed0b5136:30-66&#96; &#124;
&#124; 21 &#124; 历史产物只在单机的可恢复性 &#124; ⚠ 旧稿报告部分产物/冻结标签只在本机；本次未核当前远端。不外推为“现在仍只有一份”，交付前按 &#167;3.16 核持久 ref/获准副本及重取能力，不以此擅自 push &#124;
&#124; 22 &#124; 库的完整 API 面、多次中断与版本兼容 &#124; ⚠ 历史记录只覆盖若干用法；SDK/库升级前按 &#167;5.13 重核，不把原地恢复样例推广到未经验证的路线 &#124;

</pre>

**G-089** · 源 agent-dev-guide.md，L2140–L2158；SHA-256 40cd8311b3b089eaaeac8de530c1aad4d7a84b8b275707189cdd140db49fbeae

<pre data-unit="G-089">### 7.6 执行器架构的未验证清单

⚠ **&#167;2.6–&#167;2.10 描述的执行层，在本清单清空之前一律按 &#96;defined&#96; 对待**（&#167;5.8 四级词典）。
本节只登记「未验证」；「已知不支持」在 &#167;5.6 矩阵里，两者不可混。

&#124; # &#124; 未验证的事 &#124; 位置 &#124; 验证方式 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; 两条执行腿的部署门禁与 Harness wire 门禁**均无运行证据** &#124; &#167;2.6、&#167;2.9 &#124; Gate 0 spike &#124;
&#124; 2 &#124; 「租用 loop、自建控制面」的硬条件全部未实证 &#124; &#167;2.6 &#124; Gate 0 spike，逐条给退出判定 &#124;
&#124; 3 &#124; Harness sdk-runtime wheel 能否从**内网 PyPI 镜像**取得 &#124; &#167;2.7 系统 Node 行 &#124; 供应链验证，非文档问题 &#124;
&#124; 4 &#124; worker egress 的包级验证**在 KIND 上不成立** &#124; &#167;2.10 &#124; 另起 Calico 环境实测 &#124;
&#124; 5 &#124; 双 runtime 峰值内存与 prefork 并发的**实测值** &#124; &#167;2.10 &#124; 负载测试后再定 requests/limits &#124;
&#124; 6 &#124; Codex async 客户端在并发/teardown 下的行为 &#124; &#167;2.10 &#124; 负载与故障注入，**不得由 &#96;async&#96; 关键字推断** &#124;
&#124; 7 &#124; **未跑过任何 SDK 端到端**、未联调 OpenClaw、未做故障注入 &#124; &#167;2.6–&#167;2.10 全部 &#124; Gate 0 &#124;
&#124; 8 &#124; 多租户配额的产品语义尚未设计 &#124; 本条即登记 &#124; 属产品契约侧 &#124;

⚠ **本清单不是免责声明。**它的用途是：读到 &#167;2.6–&#167;2.10 任何一节时，能立刻判断那一节是
&#96;defined&#96; 还是 &#96;runtime-verified&#96;。**清单为空之前，那五节描述的是目标形状，不是现状。**

</pre>

**H-013** · 源 handoff.md，L127–L131；SHA-256 6a5176405320dce09b6f4ed176cd4eb55f67f07a131bbf9339abe9522969cebf

<pre data-unit="H-013">## 不能倒退的两条（本轮新增）

- **H5 未分层**：所有者五次执行 &#96;publish-*.sh&#96; 写主线，都是 H5 管辖的 Side Effect 但未经 H5 门。
  建议拆 &#96;H5-final&#96; / &#96;H5-round&#96;，见 &#96;rounds/runtime/runtime-disposition.md&#96; &#167;L.1。
- **⑥ 确认的回执强度为零**：全流程唯一不可逆的一步，其回执恰恰最不可验证（&#96;rulings.md&#96; &#96;R2&#96;）。
</pre>

**H-009** · 源 handoff.md，L80–L92；SHA-256 af08f3b4ea5e8f67452d866f53d05d58686a1e2849a4e717b7dd2a76a4f5c783

<pre data-unit="H-009">## 文档面待办

评审吸收后留下的两项。**登记在这里,不在评审目录里**——那种目录用完就删，
写在里面等于没登记。

&#124; # &#124; 事项 &#124; 验收条件 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **D1** &#124; 压缩总览与仓页/主题页的重复：同一事实**只在一处展开**，总览改为结论 + 指针 &#124; 逐项检查总览 &#167;5–&#167;9 与 &#96;repos/&#96; &#96;topics/&#96; 无同型重复；判据用提出方给的：同一事实只在一处展开 &#124;
&#124; **D2** &#124; 给&quot;为什么&quot;类内容独立去向：平台禁令、依赖方向等已进总览 &#167;4.1，但四类&quot;为什么&quot;仍无统一载体 &#124; 明确每类&quot;为什么&quot;落在投影、&#96;development-plan.md&#96; 还是拒绝写入，并各给一条理由 &#124;

来源：luna B7 / B8。本轮判定为**不在本轮做**——总览刚净增 &#167;4.1 / &#167;8.1 / &#167;8.2
三节（都是评审要求补的），此时压缩会与刚吸收的内容打架。

</pre>

### records/guide-history.md（R）

将历史登记、介入实例、轨迹及旧路线按证据对象保存；已裁定设计边界在 foundation 保持现行效力，不在这里隐藏禁令。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 历史实测与实例 | 五家取值、介入清单及轨迹读数各有环境和时点；查询今天能力必须另有当次证据。 | G-027, G-062, G-076 |
| 旧路线及当时进度 | G-094 已明确旧 R0–R5/S1 不作为现行路线；原实施表及旧进度完整保留供追溯，不能再以现在任务名义发出。 | I-005, H-011, H-012 |

#### 历史实测与实例

**G-027** · 源 agent-dev-guide.md，L587–L648；SHA-256 4f5fdc34e7d7d17a078d2e4ce8d54022a735ae0b49e2cf5fe13b8ee36264cfba

<pre data-unit="G-027">### 2.12 五家 Agent Profile 的历史取值示例

⚠ **本表是「登记表长什么样」的实例，不是可自动路由的名单**（&#167;2.3 已立：静态登记集合与
自动路由候选集分开）。带 ⚠ 的格是**未核值**，不得据它反推能力。

&#96;&#96;&#96;text
&#91;ap.luna]
harness = &quot;codex-cli&quot;    provider = &quot;openai&quot;     model = &quot;gpt-5.6&quot;   model_pinned = false  # ⚠ argv 未钉 --model
dispatch = &quot;argv&quot;        observability = &quot;process&quot;     # 可升 tool.reported：codex exec --json
enforcement = &quot;outer-only&quot;   sandbox = &quot;self&quot;    workspace_isolation = &quot;convention&quot;
roles_allowed = &#91;&quot;proposer&quot;,&quot;reviewer&quot;,&quot;objector&quot;,&quot;acceptor&quot;]   supports = &#91;&quot;dev.change/1&quot;]

&#91;ap.kimi]
harness = &quot;codex-cli&quot;    provider = &quot;moonshot&quot;   model = &quot;kimi-k3&quot;   model_pinned = false  # ⚠ 同上
dispatch = &quot;argv&quot;        observability = &quot;process&quot;   enforcement = &quot;outer-only&quot;   sandbox = &quot;self&quot;
workspace_isolation = &quot;convention&quot;

&#91;ap.cursor]
harness = &quot;cursor-agent&quot; provider = &quot;xai&quot;        model = &quot;cursor-grok-4.6-high&quot;   model_pinned = true
dispatch = &quot;argv&quot;        observability = &quot;process&quot;   enforcement = &quot;outer-only&quot;   sandbox = &quot;self&quot;

&#91;ap.fable]
harness = &quot;cursor-app&quot;   provider = &quot;anthropic&quot;  model = &quot;claude-fable-5.1&quot;  model_pinned = false  # ⚠ GUI 内选择，不可机械核验
dispatch = &quot;manual&quot;      # 无 argv；分发由人代行，记 dispatch_event 而非权力表行
observability = &quot;fs-only&quot;    enforcement = &quot;outer-only&quot;   sandbox = &quot;self&quot;
roles_allowed = &#91;&quot;proposer&quot;,&quot;reviewer&quot;,&quot;objector&quot;]      # 不得任 acceptor

&#91;ap.qwen]
harness = &quot;qoder&quot;        provider = &quot;&quot;           model = &quot;&quot;   model_pinned = false  # ⚠ 留空：来源表该栏为「—」，推断不得进登记表取值
dispatch = &quot;argv&quot;        observability = &quot;process&quot;   enforcement = &quot;outer-only&quot;   sandbox = &quot;self&quot;

&#91;ap.opus]                # 裁决方，不参赛
harness = &quot;claude-code&quot;  provider = &quot;anthropic&quot;  dispatch = &quot;argv&quot;   observability = &quot;process&quot;
enforcement = &quot;outer-only&quot;   sandbox = &quot;self&quot;    roles_allowed = &#91;&quot;arbiter&quot;,&quot;publisher&quot;]

&#91;principal.owner]        # 人：不是执行者，无 harness / dispatch / observability
channel = &quot;inbox+commit&quot;          channel_grade = &quot;shared-credential&quot;   # 与 agent 同机同身份，证据强度零
&#96;&#96;&#96;

**读数三条：**

1. 四家 &#96;process&#96;（可升 &#96;tool.reported&#96;），**fable 为 &#96;fs-only&#96;**——&#96;dispatch = manual&#96;，
   没有进程句柄就没有 stdio；
2. **六家 &#96;enforcement&#96; 全为 &#96;outer-only&#96;，&#96;sandbox&#96; 全为 &#96;self&#96;，&#96;workspace_isolation&#96; 全为
   &#96;convention&#96;**；
3. ⚠ **目前没有一家是 &#96;tool.enforced&#96;**——那是 SDK 腿建成之后才会出现的取值（&#167;2.9）。

⚠ **登记表的机械非空不等于填对。**真实案例：一份候选把 fable 填成 &#96;process&#96;，
而同一份的正文又写「看不到 argv / stdio」——**机械判「无空缺」会通过，事实是填错的**。
校验规则：&#96;dispatch = manual&#96; 的执行者，&#96;observability&#96; **只能**是 &#96;fs-only&#96;，脚本不许填高。

⚠ &#96;&#91;principal.owner]&#96; 的 &#96;channel_grade = shared-credential&#96; 是 &#167;4.4 那句
「人类确认只能标 &#96;reported&#96;」在登记表上的落点——**通道换掉之前，
轨迹里所有 &#96;power_row ≠ —&#96; 的条目 &#96;response_grade&#96; 一律 &#96;reported&#96;**。

**&#96;codex exec --json&#96; 的可升级依据**（本文复跑于 Codex &#96;7d6f808b&#96;）：
&#96;codex-rs/exec/src/cli.rs:58-64&#96; 的 &#96;--json&#96; 参数注释为 “Print events to stdout as JSONL”；
&#96;codex-rs/exec/src/exec_events.rs:115&#96; &#96;CommandExecution(CommandExecutionItem)&#96;、
&#96;:118&#96; &#96;FileChange(FileChangeItem)&#96;（结构体在 &#96;:161&#96; 与 &#96;:186&#96;）。
⚠ **可见性到工具调用级，但吐的是执行者自报**——运行时既拦不住（拦截点在进程内）也验不了，
**强制点仍在进程外**。所以它只能升到 &#96;tool.reported&#96;，升不到 &#96;tool.enforced&#96;（&#167;5.1）。

</pre>

**G-062** · 源 agent-dev-guide.md，L1549–L1579；SHA-256 87af901ea8b055c7eb1745d73910dd81cbd375708889d0b8f369934fd259492d

<pre data-unit="G-062">### 4.11 本轮已发生介入的实例级清单

⚠ **类型级权力表（&#167;4.2）不能代替实例级清单。**这一条是上一轮 ⑤ 验收 &#96;C-1&#96; 明确抓出来的
缺项——**没有实例，就无法验证权力表是否真的被用过、被正确地用过**。

下表是 &#96;runtime&#96; 轮实际发生的介入，逐条对应唯一状态机的边与权力表的行：

&#124; # &#124; 介入（可复核出处） &#124; 状态机的边 &#124; 权力行 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; 所有者提出四条推翻性判断 &#124; **不是任何边**：前一 Task 已 &#96;SUCCEEDED&#96;，终态不可转出 → 建新 Task 并记 &#96;supersedes&#96; &#124; —（内核规则，非权力） &#124;
&#124; 2 &#124; 解冻上一轮三处冻结物 &#124; &#96;WAITING(APPROVAL) → VALIDATING&#96; &#124; **H6** &#124;
&#124; 3 &#124; 冻结本轮验收十条并签发 &#124; &#96;WAITING(APPROVAL) → VALIDATING → QUEUED&#96; &#124; **H1** ⚠ 与 H2 合并于一次触点，与「T2 = 2 个触点」不符，登记为观察值 &#124;
&#124; 4 &#124; 裁定本轮协议版本 &#124; &#96;WAITING(INPUT) → VALIDATING&#96; &#124; **H8**（approve option） &#124;
&#124; 5 &#124; 接受零强度回执形态，继续 bootstrap 例外 &#124; 同上 &#124; **H3**（更省事方向） &#124;
&#124; 6 &#124; 固定投喂指令加指路补丁 &#124; 同上 &#124; **H8** &#124;
&#124; 7 &#124; 判别命令硬化、删除产品映射句 &#124; **不占权力行**：中性偏严谨，裁决方自裁 &#124; —（记裁定行） &#124;
&#124; 8 &#124; 裁定某条从属于另一条并签发 &#124; &#96;WAITING(APPROVAL) → QUEUED&#96; &#124; **H6** &#124;
&#124; 9 &#124; ①②④⑤ 对四家 CLI 的手工投喂 &#124; 各家 Attempt &#96;CREATED → RUNNING&#96;；Task &#96;QUEUED → RUNNING&#96; &#124; —（&#96;dispatch_event{mode=manual}&#96; ×N） &#124;
&#124; 10 &#124; 对 &#96;dispatch = manual&#96; 执行者的手工投喂 &#124; 同上 &#124; —（&#96;dispatch_event&#96;，&#96;observability = fs-only&#96;） &#124;
&#124; 11 &#124; 所有者执行发布脚本把环节产物写入主线（本轮 5 次） &#124; Side Effect：写共享路径 &#124; ⚠ **未经 H5 门**——见下 &#124;
&#124; 12 &#124; ⑥ 确认 &#124; &#96;WAITING(APPROVAL) → QUEUED&#96; → publisher &#96;RUNNING → COMPLETED&#96; → Task &#96;RUNNING → SUCCEEDED&#96; &#124; **H5** &#124;

⚠ **第 1 行「没有边」是正确答案，不是缺项**——它恰好说明「推翻一个已完成的 Task」
在内核里的落点是 &#96;supersedes&#96; 建新 Task，**不是 Interaction**。

⚠ **第 11 行是一个真缺口，如实登记。**五次执行发布脚本、把环节产物写入主线，
都是**写共享路径的 Side Effect**，按权力表属 H5 管辖，但实际未经 H5 门——
它们被当作常规动作处理了。**原因是 H5 只对准「⑦ 发布最终稿」，没有区分最终稿发布与
轮内产物发布**。两者不可逆性不同（后者可 revert，前者进交付面），但**都写主线**。
处置见 &#167;7.4 第 4 行（&#96;H5-final&#96; / &#96;H5-round&#96; 拆分），**本文不擅自改权力表行数**。

</pre>

**G-076** · 源 agent-dev-guide.md，L1851–L1898；SHA-256 cc6f48adf2889fce4019719d7b0a141e4d6fbb5076631606701e0ae725d9becd

<pre data-unit="G-076">### 5.11 轨迹实测：23 条里 2 条 attested

&#167;5.3 引用过这个读数，**这里是支撑它的表**——⚠ **只留读数不留表，就是「结论在、证据不在」**。

数据来源可复跑（⚠ **必须钉 commit**：不钉 ref 时会在包含后续发布点的分支上多出一行）：

&#96;&#96;&#96;bash
git log &lt;round-commit&gt; --format=&#x27;%h %ad %an&#x27; --date=iso -- &lt;最终稿路径&gt; &lt;该轮目录&gt;
git ls-tree -r --name-only &lt;round-commit&gt; -- &lt;该轮目录&gt;
&#96;&#96;&#96;

&#124; seq &#124; 层 &#124; 边 &#124; actor &#124; 权力行 &#124; provenance &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; task &#124; — → &#96;RECEIVED&#96; &#124; owner &#124; — &#124; reported（无工单文件） &#124;
&#124; 2 &#124; task &#124; &#96;RECEIVED → VALIDATING → QUEUED&#96; &#124; orchestrator &#124; **H1/H2 缺** &#124; **inferred**（无工单、无冻结验收条） &#124;
&#124; 3 &#124; task &#124; &#96;QUEUED → RUNNING&#96; &#124; 执行者 &#124; —（&#96;dispatch_event&#96;） &#124; reported &#124;
&#124; 4 &#124; attempt &#124; A1 &#96;CREATED → RUNNING → COMPLETED&#96; &#124; 执行者 &#124; — &#124; reported（产出 v0，**无 commit**） &#124;
&#124; 5,8,13,16,19,21 &#124; artifact &#124; v0→v1→…→v6 &#124; claimed / **attested none** &#124; — &#124; reported（六个版本**零 commit**） &#124;
&#124; 6,7 &#124; attempt &#124; A2/A3 reviewer &#96;COMPLETED&#96; &#124; — &#124; — &#124; reported（**产物未归档**） &#124;
&#124; 9,14,17 &#124; attempt &#124; A4–A6、A7–A11 &#96;COMPLETED&#96; &#124; — &#124; — &#124; **inferred**（由文件存在性推出） &#124;
&#124; 10,11,15,18 &#124; interaction &#124; request → approve / **reject** &#124; owner &#124; **H8** &#124; reported（同 commit、同身份） &#124;
&#124; 12 &#124; task &#124; &#96;RUNNING → WAITING(INPUT) → QUEUED → RUNNING&#96; &#124; orchestrator &#124; H8 &#124; **inferred**（账本无边） &#124;
&#124; 20 &#124; attempt &#124; A12 &#96;COMPLETED&#96; &#124; — &#124; — &#124; reported（**无产物**） &#124;
&#124; 22 &#124; interaction &#124; R1 冻结 → approve &#124; owner &#124; **H1** &#124; **attested**（存在）/ reported（身份） &#124;
&#124; 23 &#124; task &#124; &#96;RUNNING → WAITING(APPROVAL) → QUEUED → RUNNING → SUCCEEDED&#96; &#124; publisher &#124; H1+H5 &#124; **attested**（终态）/ inferred（中间边） &#124;

**读数**：23 条里 &#96;attested&#96; **2** 条（且身份都不 attested），&#96;reported&#96; 15 条，&#96;inferred&#96; 6 条；
Artifact 六个版本**零 commit**；两个 reviewer Attempt **有事件无产物**；
H1 与 H5 由同一 commit 承担，**账本分不开**；&#96;VALIDATING&#96; 阶段**没有任何契约产物**。

这条轨迹与「按 &#96;dev.change/1&#96; 跑一遍 T2」的目标轨迹**在边上对得上**，
但**只能在 &#96;reported&#96; 等级上宣称等效**（&#167;5.3 规则 4）。
这就是「手工模式看起来在跑、实际没有可搬运的形状」的账本版。

**对照组**：另一轮的整合分支有 **28 条**逐主张提交，③④⑤ 每条处置各占一个 commit——
同一 Task Profile、同一 orchestrator 实现，&#96;attested&#96; 条目**数量级不同**。
⚠ **差别不在载体，在纪律是否落成动作。**

**样例的引用纪律（两条，对应两种真实失败形态，防法不同、不可互相替代）：**

1. ⚠ **每个引用对象须先核验其属于所声明的那一轮。**引用真实存在、哈希可验、
   但**属于另一轮**的对象，叫**张冠李戴**——只查「对象是否存在」抓不到，
   必须查「**属于哪一轮**」；
2. ⚠ **无 ⚠ 声明的样例条目一律按「已核验」读，因此凭空构造即为假证据。**
   另一种失败是**把本轮形状倒灌进历史**——写出账本上根本不存在的对象
   （如「五份并行候选」「验收产物」）而不作任何声明。前一条防法查不到它：
   **对象压根不存在，「属于哪一轮」无从查起**，只能靠「**无声明即假**」。

</pre>

#### 旧路线及当时进度

**I-005** · 源 implementation-plan.md，L53–L76；SHA-256 6f267053e757d695be8bda0763d4917b9d6d71977cb72b288fae4eb2f532786d

<pre data-unit="I-005">## 阶段〇 · 开发框架自身的实施路线（R0–R5）

&gt; 迁自 &#96;refact-fable.md @ 7e8464c2&#96; &#167;6。**每轮一个工单，前置不可跳**；档位按 &#96;round-protocol.md&#96; 判据自判。
&gt; 进度与卡点见 &#91;&#96;handoff.md&#96;](handoff.md)（分工：状态叙述不写在本文件）。
&gt; ⚠ 取证给 S1 加了一条本表未写的前置：**所有者需要一个 agent 够不着的本地 shell**（Cursor / Qoder 均 Remote 连入 VM）。
&gt; ⚠ H5 未区分「最终稿发布」与「轮内产物发布」，见 &#96;rounds/runtime/runtime-disposition.md&#96; &#167;L.1。

每轮一个工单，前置不可跳。档位按 round-protocol 判据自判，**本路线不含任何降档**。

&#124; # &#124; 轮 &#124; 档 &#124; 产物 &#124; 前置 &#124; 机械验收判据 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; R0 &#124; 修 &#96;protocol-v2&#96; 的脚本↔协议不一致（命名、&#96;--stage&#96;、退出码）——**只改脚本，不改协议正文**。**由 opus 直接修，不走轮次** &#124; **bootstrap** &#124; 合并 &#96;protocol-v2&#96; &#124; 无 &#124; 新建空 &#96;rounds/_smoke/&#96; 按协议字面写 &#96;round.md&#96;，&#96;round-status.py&#96; 能解析且判 ① 未开始 &#124;
&#124; R0′ &#124; 往 &#96;round-protocol.md&#96; 补「机器可读块」一节（&#96;round.md&#96; 的 toml 块进协议）。**所有者裁定 2026-09-05：这是改协议，按 T2 开轮**（&#167;7-12 已决） &#124; **T2** &#124; &#96;round-protocol.md&#96; 一节 &#124; R0 &#124; 协议正文与 &#96;round.md&#96; 字段表一一对应；&#96;round-status.py&#96; 解析规则以协议为准，脚本单测覆盖每个字段 &#124;
&#124; S1 &#124; **边界 spike**（&#96;runtime-architecture.md&#96; &#167;4.4「三道边界」与 &#167;4.6「principal 通道」）：① 建回执仓、建候选仓；② VM 换三把 key（候选仓读写、主仓只读、回执仓只读），撤销原 &#96;id_rsa&#96;；③ 所有者在 Windows 提交两份测试回执（&#96;&#91;H5]&#96; 含 &#96;acceptance&#96;、&#96;&#91;H3]&#96; 含 &#96;ruling_sha256&#96;），用带口令 key 推；④ 首版 &#96;check-no-owner-creds.sh&#96;；⑤ 按 &#96;runtime-architecture.md&#96; &#167;4.7「取证纪律与当前事实」在宿主 shell 重跑取证 &#124; **bootstrap**（可逆、可丢弃） &#124; &#96;rounds/_spike-sign/&#96; 留痕 &#124; **&#167;8 判据已冻结**（冻结判据 ≠ 判据已满足——qoder C3 的循环不存在；&#96;runtime-architecture.md&#96; &#167;4.4 随之冻结） &#124; ⓪ 回执仓与候选仓建成，VM 身份对**主仓与回执仓** &#96;git push --dry-run&#96; 均被拒（配置导出留痕）；VM 身份对候选仓 push 成功；两份测试回执 &#96;round-status.py&#96; 判成立（签名 ∈ 在线公钥集、schema 合法、&#96;acceptance&#96; 集合完整 / &#96;ruling_sha256&#96; 匹配）；用 VM 上未登记的 key 签一份回执推候选仓再伪装路径，判不成立；&#96;check-no-owner-creds.sh&#96; 零命中；断网重跑判未确认且退出码为「查询失败」；取证栏每行附 &#96;hostname; id; cat /proc/self/uid_map&#96; 输出 &#124;
&#124; R1 &#124; 权力表全表回执仓锚定 + 收件箱字段分级 + 回执内容门；&#96;round-status.py&#96; 读回执仓 yaml 并在线验签、状态推导输出边并按 &#96;state-machine.toml&#96; 校验；T0 两道门；&#96;check-policy.py&#96;；orchestrator 写 &#96;events.jsonl&#96; &#124; **T2**（权威层、不可逆） &#124; &#96;authority.md&#96;、&#96;policies/tier-defaults.toml&#96; 首版（所有者签 &#96;policy/1&#96;）、&#96;policies/state-machine.toml&#96;、&#96;scripts/check-policy.py&#96;、&#96;scripts/gates/&#96;、脚本改动 &#124; R0、S1、原文 &#167;3.1.1 映射表（已由 &#96;runtime-architecture.md&#96; &#167;2.5 取代）冻结 &#124; &#96;round-status.py --round refact&#96; 对历史轮次输出唯一状态机的词与合法边；对 S1 测试回执判 H5 / H3 成立、对缺 &#96;acceptance&#96; 或签名不在公钥集的回执判不成立；无回执的 &#96;rulings.md&#96; 裁定行被判不存在；伪造 T0 工单四种（包名不存在 / 自拼门禁列表 / 完工 diff 越出 paths / 引用一个 paths 覆盖 &#96;constraints.md&#96; 的包）各被拒绝，其中第四种在 &#96;check-policy.py&#96; 层就拒绝签策略；&#96;intake_author&#96; 兼 proposer 的配置被拒发 &#124;
&#124; R2 &#124; 执行架构迁出（含 &#96;human&#96; kind 一小节，3.2） &#124; T1（大搬家但方向无争议） &#124; &#96;executor-architecture.md&#96;；agent 文相应节改为指针 &#124; R0（**不依赖 R1**：S1/R1 受阻不阻塞本轮） &#124; &#96;doc-gate&#96; 通过；&#167;11.3 八条逐条可寻 &#124;
&#124; R3 &#124; 登记表加 &#96;principal&#96; / &#96;provider&#96; / &#96;runtime&#96; / &#96;model_family&#96; / &#96;roles_allowed&#96;；分发前机械拦角色冲突（含 &#96;intake_author&#96;）；独立性折算首版进 &#96;authority.md&#96; &#124; T1 &#124; &#96;agents.toml&#96;、&#96;round-dispatch.py&#96; &#124; R1 &#124; 故意配置「裁决方兼提案方」，分发拒绝并给 reason；正常配置放行；折算表存在且 3.2 的示例（1 家独立带证 vs 3 家同 runtime 无证）按表算出前者胜；luna 与 kimi 按表落同一组 &#124;
&#124; R4 &#124; 工单一般化为 Artifact + T0/T1 guard 表与必需产物表 + 三值路由 + &#96;status&#96; 改推导 &#124; **T2** &#124; &#96;round-protocol.md&#96; 改版、&#96;policies/tier-defaults.toml&#96;、脚本读 tier &#124; R1、R3 &#124; 用一个**可丢弃的小题目**（&#96;automation-roadmap.md&#96; &#167;4.1 要求）分别跑一次 T0、T1；每次 H2 都有落账；脚本输出无一处非唯一状态机的词 &#124;
&#124; R5 &#124; 两份 lifecycle 合并为 &#96;lifecycle.md&#96;；&#96;request-lifecycle.md&#96; 边界声明修订；13 文件引用清理；&#96;doc-gate.py&#96; 配置 &#124; **T2** &#124; &#96;lifecycle.md&#96;、&#96;migration-map.md&#96;、删两份旧文 &#124; R1–R4 &#124; 5.3 五条全部通过 &#124;

&gt; 本表的调整说明与 &#96;bootstrap&#96; 档的效力来源属架构论证，见 &#96;runtime-architecture.md&#96;
&gt; 与 &#96;rounds/refact-fable/rulings.md&#96;；按 &#96;README.md&#96; 分工不写在本文件。
---

</pre>

**H-011** · 源 handoff.md，L98–L117；SHA-256 50a2fdbe5c34ee52604e2b5df801f980bd2320a3e89015f5ac336c6f6b085626

<pre data-unit="H-011">## 开发框架自身（R0–R5 路线）的进度

&gt; 路线表在 &#91;&#96;implementation-plan.md&#96;](implementation-plan.md)「阶段〇」；本节只记**状态**。
&gt; 最后更新：2026-09-05。

&#124; 轮 &#124; 状态 &#124;
&#124; --- &#124; --- &#124;
&#124; R0 修脚本↔协议不一致 + 合并 &#96;protocol-v2&#96; &#124; **已做**（2026-09-06）。主线 &#96;round-protocol.md&#96; = 七环节版；三个脚本进主线；四处脚本↔协议不一致已修（产物路径、调用方式、退出码、已完成轮次被判成刚开始）。判据与结果见 &#96;rounds/_r0/criteria.md&#96;。产出方 = 验收方（所有者 2026-09-06 裁定不追加外部复验：判据 C1–C9 全是可复跑命令） &#124;
&#124; R0′ 协议补机器可读块 &#124; 未开（所有者已裁定按 T2） &#124;
&#124; **S1 边界 spike** &#124; **进行中**。④ &#96;check-no-owner-creds.sh&#96; 与 ⑤ 宿主取证已完成（&#96;rounds/_spike-sign/forensics.md&#96;）；①②③ 待所有者 &#124;
&#124; R1–R5 &#124; 未开 &#124;

**S1 的两条卡点**：

1. ⚠ **一条路线表未写的前置**：所有者需要**一个 agent 够不着的本地 shell**。
   Cursor 与 Qoder 均 Remote 连入本 VM，其中的终端就是 VM 的 shell——
   在那里签名等于把私钥放在 agent 能 &#96;sudo&#96; 读到的地方。见 &#96;rounds/runtime/rulings.md&#96; &#96;R2&#96;。
2. ⚠ 宿主取证发现 &#96;zym&#96; 有免密 sudo 且在 docker 组，**本机一切本地强制点对 agent 无效**；
   只有托管方的 key 作用域有效。这使 S1 的 ② 成为唯一真正有效力的一步。

</pre>

**H-012** · 源 handoff.md，L118–L126；SHA-256 d5d442bc498e2a0cdaf7097a976c0524825a4002f3e66e5d3a966fabd5eeee1e

<pre data-unit="H-012">## 已完成的轮次

&#124; 轮 &#124; 结果 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;refact&#96; &#124; 已发布，最终稿 &#96;archive/development-lifecycle-agent.md&#96;（2026-09-07 归档）。其 118 节已于 2026-09-07 吸收进 &#96;agent-dev-guide.md&#96; &#167;10。⚠ &#96;refact-fable&#96; &#167;5.2 承诺的逐节映射表 &#96;migration-map.md&#96; **从未产出**，该欠账至今只清到标题级 &#124;
&#124; &#96;refact-fable&#96; &#124; 已发布；其架构结论（两个 Profile）后被 &#96;runtime&#96; 轮推翻，原文已迁出并删除，内容在 &#96;7e8464c2&#96; 与 &#96;rounds/refact-fable/&#96; &#124;
&#124; &#96;runtime&#96; &#124; 已发布，最终稿曾为 &#96;runtime-architecture.md&#96;；其 33 节已由 &#96;runtime-refact&#96; 轮全部落点到 &#96;agent-dev-guide.md&#96; &#167;10，原文 2026-09-07 归档至 &#91;&#96;archive/&#96;](archive/)。裁决方自陈错误十二条，六条由参与方抓出、三条由所有者抓出 &#124;
&#124; &#96;_fixups&#96; &#124; 进行中：追认 &#96;runtime&#96; 发布后四次未走流程的改动，验收方 cursor &#124;

</pre>

### records/guide-audit.md（R）

按核验发生顺序保存范围、未核项、吸收与采用审计，最后附完整 294 行旧映射；审计的限制必须和通过项相邻。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 核验声明与补吸收 | 原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。 | G-095, G-096, G-098, G-099, G-100, G-101 |
| 历史源落点收据 | 完整保留既有 294 行；它不是本次 260 行的替代分母，也不是全部正文已验的证明。 | G-102 |

#### 核验声明与补吸收

**G-095** · 源 agent-dev-guide.md，L2235–L2240；SHA-256 87edee33cf73b9cb9178b41a811ac7d6a2694f8d0d0bf2f164ecd80371ff8672

<pre data-unit="G-095">## 9. 覆盖声明

**&#167;9.1–&#167;9.4 保留的是底稿作者在各轮的取证与补写历史。**其中的源稿数量、章节落点和行数
按成文时理解，不作为本补充版的现行覆盖结论；本次范围见 &#167;9.5，当前索引见 &#167;10。
这也适用于 &#167;8.1 和 &#167;12 原有案例中的第一人称或“本轮已实测”措辞。

</pre>

**G-096** · 源 agent-dev-guide.md，L2241–L2252；SHA-256 17cff6af355dced4dfce88d8ab8c614e2078428ec8700c2e4a00a0f26c5d8806

<pre data-unit="G-096">### 9.1 查了什么

- 按 &#96;ed0b5136&#96; 逐行读取 &#96;refact-fable.md&#96;（31 个 &#96;##&#96;/&#96;###&#96; 标题）与
  &#96;runtime-architecture.md&#96;（33 个 &#96;##&#96;/&#96;###&#96; 标题），&#167;10 共 64 行。
- 读取产品内核全文；读取 constraints、development-plan、implementation-plan、handoff；读取
  round-protocol 与本轮工单/通知；读取 S1 forensics 和 runtime 处置记录中与六项核查、H5、证据错误有关的部分。
- 在 luna 的 &#96;investment-app&#96;（&#96;investment-backend&#96; commit &#96;18d88c7&#96;）复跑中断、恢复、thread_id、
  checkpointer 的代码搜索与锚点读取。
- 在宿主复跑 &#96;sudo -n -l&#96;、&#96;git ls-remote --heads origin&#96;、&#96;git ls-remote --tags origin&#96;；在工作树复跑
  branch/upstream、tag 和 worktree 枚举。
- 未读取其他参与方 worktree 或本轮候选；未读取任务书禁止的参考融合稿。

</pre>

**G-098** · 源 agent-dev-guide.md，L2299–L2305；SHA-256 f3e02e172af585aa01456a65e30637509182a7ab75a4843aa968d57304fdfb6c

<pre data-unit="G-098">### 9.3 自增内容及理由（&#96;runtime-refact&#96; 轮）

本稿新增三点：第一，把 K1/K2 直接收敛为“产品 Interaction → LangGraph 原语”的最小绑定，理由是已有代码
足以表达中断恢复；第二，把安全设计改成“逐动作画真实路径再设服务端强制点”，理由是 K3–K6 证明旁路
不经过待保护动作；第三，把原 R0–R5 改成 G0–G5 的证据依赖顺序，先做原语 spike 与身份强制，再做服务态
等效。三点都有 &#167;4.3、&#167;4.4、&#167;8.1 的代码或命令证据，不以通用最佳实践作为依据。

</pre>

**G-099** · 源 agent-dev-guide.md，L2306–L2447；SHA-256 407fef5c1d20a360c4793214ba1ee52fae0f7a3ff7fcde852cabe10d8c81d8dc

<pre data-unit="G-099">### 9.4 两份 lifecycle 的吸收轮（2026-09-07）

**作者与时间与 &#167;9.1–&#167;9.3 不同，故单列，不混入上面的声明。**
执行者 opus；所有者指令：「你逐节对照，把两份 lifecycle 吸收进 &#96;agent-dev-guide.md&#96;」。

**查了：**

- 逐节读取 &#96;archive/development-lifecycle-agent.md&#96;（73 个 &#96;##&#96;/&#96;###&#96;）与
  &#96;archive/development-lifecycle-human.md&#96;（45 个），&#167;10 新增 118 行；
- **复跑了吸收进来的外部仓锚点**，三个仓都在源稿钉的提交上（Codex &#96;7d6f808b&#96;、
  Harness &#96;dd6322d6&#96;、OpenClaw &#96;173f41d6&#96;）。逐字复核过的关键两条：
  &#96;codex/sdk/python/src/openai_codex/client.py:773-779&#96; 的 &#96;_default_approval_handler&#96;
  对 &#96;commandExecution&#96; 与 &#96;fileChange&#96; **一律返回 &#96;{&quot;decision&quot;: &quot;accept&quot;}&#96;**；
  &#96;deepseek-harness/packages/sdk/protocol/README.md:116&#96;「**Server→client requests are a
  dead capability** — the transport supports them, but the server never sends one」，
  同文件 &#96;:115&#96; 无 cancel/session-close、&#96;:52&#96; &#96;messageId&#96; 不标识 turn 结束；
- 用 &#96;difflib&#96; 实测两份 lifecycle 的重复率（≥8 行的节，重合度 ≥0.55 者 222/563 = 39%），
  重复节在 &#167;10 注明同源与重合度。

**没查（本次新增的盲区）：**

&#124; 类别 &#124; 内容 &#124; 性质 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 外部仓 &#124; &#167;2.7 表里**其余各行**的锚点（preset README、adding-a-tool、model-provider-info、async_client、openclaw 各文档）**只核了行号可达，未逐字复核内容** &#124; 可当场复跑，只是没跑完 &#124;
&#124; 部署 &#124; &#167;2.10 四条硬阻断的 bundle 行号**未复跑**，转录自源稿 &#124; 可复跑 &#124;
&#124; 休眠登记 &#124; &#167;2.6 的 &#96;test_dormant_capabilities.py&#96; 四个行锚**未复跑** &#124; 可复跑 &#124;
&#124; ~~判定口径~~ &#124; ~~只比对标题与存在性，未逐行比对正文~~ &#124; **已于同日补做，见下** &#124;

**正文级抽查（2026-09-07，同日补做）**

⚠ **上面那条盲区不是假设——抽出来 13 处真缺，其中 1 处是落点判错。**

抽查范围：118 行按风险分流为「本次新写 32 行」「判落在既有章节 79 行」「故意不要 7 行」，
**对 79 行中内容最实的约 20 行逐节读源稿正文并回读本文对应节**。

&#124; # &#124; 源节 &#124; 原判 &#124; 实际 &#124; 处置 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; agent 源节 4.4 物化门禁 &#124; &#167;3.2 复用前置判据 &#124; &#167;3.2 只有 3 条复用判据，**十条门禁全缺** &#124; 补 &#167;3.10 &#124;
&#124; 2 &#124; agent 源节 5.1 冷启动核对 &#124; &#167;1.3、&#167;3.2 &#124; 两处均无；**「写入前门禁五条（一票否决）」整段缺失** &#124; 补 &#167;3.10 &#124;
&#124; 3 &#124; agent 源节 4.3 塞入材料 &#124; &#167;3.2 &#124; manifest 字段表与「材料可见 ≠ 使用授权」缺 &#124; 补 &#167;3.10 &#124;
&#124; 4 &#124; agent 源节 5.2 上下文路由 &#124; &#167;2.5 &#124; &#167;2.5 是**路由成本字段**，与「改哪一面要读什么」不是同一件事 &#124; 补 &#167;5.8 &#124;
&#124; 5 &#124; agent 源节 5.3 共同纪律 &#124; &#167;3.5、&#167;11 &#124; &#167;11 只有反面形式，**无正面纪律** &#124; 补 &#167;1.5 &#124;
&#124; 6 &#124; agent 源节 6.9 三条硬禁令 &#124; &#167;4.5、&#167;2.2 &#124; 缺；含「忘了传 handler 与故意自动批准在代码里长得一样」 &#124; 补 &#167;4.9 &#124;
&#124; 7 &#124; agent 源节 7.4 候选状态机 &#124; &#167;3.3 末段 &#124; 末段只有一句「Artifact 有版本属性」，**八态状态机全缺** &#124; 补 &#167;3.11 &#124;
&#124; 8 &#124; agent 源节 12 完成判据 &#124; &#167;5.5、&#167;3.5 &#124; 十三条与「缺项只能称…」全缺 &#124; 补 &#167;3.12 &#124;
&#124; 9 &#124; agent 源节 2.3 Task 契约 &#124; &#167;2.4 &#124; &#167;2.4 字段表**缺一半**；「硬门禁/质量偏好/待定项必须分开」缺 &#124; 补入 &#167;2.4 &#124;
&#124; 10 &#124; agent 源节 3.1/源节 3.2 简单与复杂 &#124; &#167;3.4 T0/T2 行 &#124; ⚠ **落点判错**：简单/复杂是**载体轴**，T0/T2 是**风险轴**，两轴正交 &#124; 改落 &#167;3.4 载体轴段 &#124;
&#124; 11 &#124; agent 源节 0.1 &#124; &#167;0.1 &#124; 跨机同步与「子仓要自己推」缺 &#124; 补入 &#167;3.2 &#124;
&#124; 12 &#124; agent 源节 0.2 &#124; &#167;1.2、&#167;5.2 &#124; &#96;request-baseline&#96;「只解释来源，不覆盖现行合同」缺 &#124; 补入 &#167;0.1 &#124;
&#124; 13 &#124; agent 源节 5.4 单路实施 &#124; &#167;3.4 T1 &#124; 「作者自检不能代替独立验收」缺 &#124; 补入 &#167;5.5 L1 &#124;

⚠ **第 10 条最值得记**：把载体轴写成风险轴，与 &#167;2.5 自己警告的「风险档位不能反过来充当
成本证据」是同一种循环——**我在做落点时犯了本文正文明写禁止的那个错**。

修补后本文由 1659 增至 1858 行，新增 &#167;1.5、&#167;3.10–&#167;3.12、&#167;4.9、&#167;5.8，20 行落点更正。

**第二轮（同日，抽完剩余 65 行）：又出 16 处，累计 29 处。**

&#124; # &#124; 源节 &#124; 原判 &#124; 实际 &#124; 处置 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; 14 &#124; agent 源节 6.1 展开条件 &#124; &#167;6.1 &#124; ⚠ **落点判错**：guide &#167;6.1 是「机械分类」（运行时值不值得用），与 fan-out 形态无关；五形态含「胜者改进」全缺 &#124; 补 &#167;3.13 &#124;
&#124; 15 &#124; agent 源节 6.2 Work Unit 契约 &#124; &#167;2.4 &#124; &#167;2.4 是工单（整个 Task），**派工契约是另一层**；三字段派工纪律全缺 &#124; 补 &#167;2.11 &#124;
&#124; 16 &#124; agent 源节 6.3 建立 worktree &#124; &#167;3.2 &#124; 十条里缺 4 条（同分支不可双检出、只隔离写入不阻读、凭据不得进分支、删 worktree ≠ 删证据） &#124; 补 &#167;3.14 &#124;
&#124; 17 &#124; agent 源节 6.4 候选隔离 &#124; &#167;2.2 &#124; **「隔离靠纪律不靠机制、无法事后证明某轮真独立」缺**——这是诚实性条款 &#124; 补 &#167;2.11 &#124;
&#124; 18 &#124; agent 源节 6.6 评审裁决 &#124; &#167;2.2 &#124; 事实裁决表（证实/证伪/未决）、两阶段评审、「不合格候选不进偏好评分」全缺 &#124; 补 &#167;5.10 &#124;
&#124; 19 &#124; agent 源节 6.7 整合 &#124; &#167;3.5、&#167;5.5 &#124; 「一条独立主张一个提交」「候选的绿不证明整合正确」缺 &#124; 补 &#167;5.10 &#124;
&#124; 20 &#124; agent 源节 6.8 停止规则 &#124; &#167;2.4 budget &#124; 六条全缺 &#124; 补 &#167;3.13 &#124;
&#124; 21 &#124; agent 源节 7.5 载体语义 &#124; &#167;3.9、&#167;5.4 &#124; &#167;5.4 只有散文，**七载体对照表缺**；「reflog 里还在不是保留策略」缺 &#124; 补 &#167;5.9 &#124;
&#124; 22 &#124; agent 源节 7.7 发布协议 &#124; &#167;3.5、&#167;5.4 &#124; candidate/publication/published **三路径区分缺**；「只要草案时 target 是候选集合」缺 &#124; 补 &#167;3.15 &#124;
&#124; 23 &#124; agent 源节 7.9 保留与 GC &#124; &#167;3.5 &#124; 六档表、「GC 是显式阶段不是退出副作用」、删除前六项验证全缺 &#124; 补 &#167;3.16 &#124;
&#124; 24 &#124; agent 源节 11.3 未验证清单 &#124; &#167;7.4、&#167;9.2 &#124; 八条全缺；**「清单为空前一律按 &#96;defined&#96; 对待」缺**——这条管着怎么读 &#167;2.6–&#167;2.10 &#124; 补 &#167;7.6 &#124;
&#124; 25 &#124; human 源节 2 人的三个角色 &#124; &#167;4.1 &#124; 提出者/执行者/principal 三分缺 &#124; 补 &#167;2.11 &#124;
&#124; 26 &#124; human 源节 7 人的义务 &#124; &#167;4.1、&#167;4.5 &#124; 六条全缺，含**「盲区声明是自愿的，只要说了就受罚，很快就没人说了」** &#124; 补 &#167;4.10 &#124;
&#124; 27 &#124; human 源节 8.3 委派 &#124; &#167;3.4 &#124; 「委派转移执行，不转移最终责任」缺 &#124; 补 &#167;4.10 &#124;
&#124; 28 &#124; human 源节 14 成本与停止 &#124; &#167;6 &#124; 「交叉阅读是二次复杂度」「未经事实验证要标注」「失败/超时/缺席也进记录」缺 &#124; 补 &#167;3.13 &#124;
&#124; 29 &#124; 本文自身 &#124; — &#124; ⚠ **&#167;4.7 写了「登记 &#167;7.4 未决」，而 &#167;7.4 里没有这条**——我自己犯了正在批的「承诺不进验收」 &#124; 补 &#167;7.4 第 20b 行 &#124;

⚠ **第 14 条是第二次落点判错**（第一次是把载体轴写成风险轴）。两次都是**把源节挂到一个
名字相近、实质不同的节上**——这正是标题级验证抓不到、只有读正文才能抓到的错法。

⚠ **第 29 条是本文自己身上的**：我在 &#167;4.7 承诺登记到 &#167;7.4 却没登记。
与 &#96;refact-fable.md&#96; &#167;5.2 承诺 &#96;migration-map.md&#96; 从未产出，是同一个形状。

**反向覆盖检查**：全文 &#96;&#167;N&#96; 自引用扫描，指向不存在章节的 10 处**全部位于 &#167;10 落点表
第三列的「同 agent 文 &#167;X」中，指的是源稿节号**，非本文缺节；已统一改写为「同 agent 文 &#167;X」
以免误读。除此之外未发现本文写入源稿所无的规范性主张（编辑性串联除外，如 &#167;2.9 末尾
指出 Harness 腿与 &#167;4.3 LangGraph 腿恢复语义不同——这是两个源之间的连接，不是新主张）。

**第三轮（同日，抽 &#96;refact-fable&#96; 31 行 + 兑现 &#96;runtime-architecture&#96; 33 行的旧账）：
再出 21 处，累计 50 处。**

&#96;runtime-architecture&#96; 的 33 行本已在同日一份独立审计里做过正文级对照，查出 15 处——
⚠ **但只记录、未修补**。⚠ 那份审计一度被放进 &#96;rounds/dev-plan-refact/&#96;，
**等于宣告那一轮是做审计的**；现已撤销，内容并入本节（该文件不再存在）。
本轮兑现其中 14 处
（第 11 项 &#96;audit_after&#96; 已由 &#167;4.6 顺带补上）：

&#124; 源节 &#124; 缺的是什么 &#124; 补到 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#167;2.3 &#124; **五家登记表本体**（36 行取值 + &#96;channel_grade&#96;）——&#167;2.3 只说「至少登记这些字段」，无取值 &#124; &#167;2.12 &#124;
&#124; &#167;2.4 &#124; **本轮已发生介入的实例级清单 12 行**——⚠ 正是上一轮 ⑤ 验收 &#96;C-1&#96; 抓出的缺项，**连丢两轮** &#124; &#167;4.11 &#124;
&#124; &#167;2.8 &#124; **23 条轨迹表本体** + 对照组 + 引用纪律两条——&#167;5.3 只留读数，**结论在、证据不在** &#124; &#167;5.11 &#124;
&#124; &#167;4.2 &#124; 读数三条 + 「机械非空不等于填对」的实例 &#124; &#167;2.12 &#124;
&#124; &#167;4.5 &#124; **数据网关 / 不得给裸库凭据**（硬约束） &#124; &#167;3.2 &#124;
&#124; &#167;4.7 &#124; 三行现状事实：无 GPG 密钥、&#96;id_rsa&#96; 对主仓可写、Windows 侧亦跑本地 agent &#124; &#167;4.4 &#124;
&#124; &#167;2.2 &#124; 别名登记、&#96;privacy&#96;(NO ZDR)、观察窗中位数、&#96;freshness&#96; &#124; &#167;2.4 &#124;
&#124; &#167;2.7 &#124; &#96;author_claimed&#96; / &#96;author_attested&#96; 拆分 &#124; &#167;5.3 &#124;
&#124; &#167;4.1 &#124; &#96;codex exec --json&#96; 锚点（本次复跑于 &#96;7d6f808b&#96;） &#124; &#167;2.12 &#124;

&#96;refact-fable&#96; 的 31 行**此前只抽过 3 处**，本轮补抽，出 7 处：

&#124; 源节 &#124; 缺的是什么 &#124; 补到 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#167;2 &#124; **六条设计原则 P0–P5**；尤其 **P5「凡能落成代码/测试/门禁的纪律必须落成」**，与推论**「一个只能靠人转述的环节等于没有环节」**——整段无落点 &#124; &#167;1.6 &#124;
&#124; &#167;2 &#124; P0 的适用层级：**对象的小生命周期不是第二套状态机** &#124; &#167;1.6 &#124;
&#124; &#167;3.10 &#124; **内核对象 ↔ 开发载体对照表**——&#167;3.3 是状态投影表，与它不是同一张 &#124; &#167;3.17 &#124;
&#124; &#167;3.8 &#124; 状态脚本硬要求：**推导值 ≠ 声明值即报错**、**边不在合法表即报错退出**、分发前角色冲突拒绝 &#124; &#167;3.18 &#124;
&#124; &#167;3.12 &#124; acceptor「既得利益最小、由处置表算出」；L3「抽样规则写进工单」 &#124; &#167;5.5 &#124;
&#124; &#167;3.5 &#124; 「分类节点只给四条判据的命中证据，**不给 tier**」 &#124; &#167;2.1 &#124;

⚠ **&#96;runtime-architecture&#96; 那 15 处是「查出来了没修」**——审计写完之后
在一份独立文件里躺了几个小时，没有回到被审对象上。
**这与 &#96;refact-fable.md&#96; &#167;5.2「承诺产出但不进验收」是同一个形状的第三次出现**：
第一次是 &#96;migration-map.md&#96; 从未产出，第二次是我在 &#167;4.7 承诺登记到 &#167;7.4 而没登记，
第三次是这份审计只记不修。**记录不等于修补，审计不等于验收。**

**查过但确认「不是缺」的，一并记下，免得下次重查：**

&#124; 曾疑 &#124; 实际 &#124;
&#124; --- &#124; --- &#124;
&#124; 合法转换全集（五行状态表） &#124; 本文**故意不重写**——&#167;0.1 边界写明「不重写对象定义、合法边」，改为按 commit 引用内核。**这是对的** &#124;
&#124; git 的两个角色（载体永久 / 账本要拆） &#124; &#167;5.4 有，措辞不同 &#124;
&#124; &#96;runtime-architecture&#96; &#167;2.5 产物→状态机 16 行 &#124; &#167;3.3 有 13 行 + 散文补 3 行，且**多一行**「同一执行从 checkpoint 续跑」——是 K1/K2 的新发现 &#124;
&#124; &#96;H5-final&#96; / &#96;H5-round&#96; 拆分 &#124; &#167;7.4 风险 4 有 &#124;
&#124; 三道边界的**机制** &#124; &#167;3.2 有（撤销的是「组合成安全架构」这个结论，不是机制本身） &#124;
&#124; &#167;2.7 六条比对规则 / &#96;TraceEnvelope&#96; &#124; &#167;5.3 全有；&#96;TraceEnvelope&#96; 明说不沿用该名但保留字段，并给了理由 &#124;
&#124; &#96;lifecycle-agent&#96; &#167;5.4「作者自检不能代替独立验收」 &#124; 已补入 &#167;5.5 L1 &#124;

**四份源稿 182 行全部抽到正文级，本轮抽查完成。**
累计 50 处真缺、2 处落点判错，本文 827 → 2352 行。


</pre>

**G-100** · 源 agent-dev-guide.md，L2448–L2506；SHA-256 c64255a657627d0237f05a3fe038c380ebb3c7b2ff513bfa6645f64ab0156658

<pre data-unit="G-100">### 9.5 GPT-6 再吸收记录（2026-09-08）

**用户目标：以保留的 guide 为基座，再吸收 archive 中相容而有用的内容，生成独立的
&#96;agent-dev-guide-gpt6.md&#96;，他人的文档不改。**本次不是重判 runtime-refact，
也不是执行另一轮的开轮/分发/发布任务。

输入固定于 k8s &#96;d9f827f810be6b645b9ef2c1339009328bca02f5&#96;：
底稿 2402 行，archive 五份历史正文和 README；另读现行产品合同、约束和协作协议核边界。
旧谱系为两 lifecycle → refact-fable → runtime-architecture，随后分叉为独立的
agent-dev-refact 与 runtime-refact 的 guide；两 lifecycle 在 9 月 7 日又直接补入 guide。
本次把兄弟分叉里的相容增量接回，并再查前四源的正文落点；不把共同祖先重合误称为全部已处置。

&#124; 本次吸收/修正的内容 &#124; 原来源 &#124; 实际正文落点 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 单份指南阅读路线、缺失词汇 &#124; agent-dev-refact 阅读入口；human 自足目标 &#124; &#167;0.3、&#167;13 &#124;
&#124; P6、检验真实动作路径与控制面自身 &#124; agent-dev-refact 设计原则、元观察 &#124; &#167;1.6–&#167;1.7 &#124;
&#124; 执行路线三层判断、Gate 0 三项、确定性熟路 &#124; lifecycle-agent 执行层路线 &#124; &#167;2.6 &#124;
&#124; 通用 DTO 与 Adapter 职责禁区 &#124; lifecycle-agent 执行 Port &#124; &#167;2.8 &#124;
&#124; 人贡献内容不等于产品执行器 &#124; human 三角色与 agent-dev-refact 人的位置 &#124; &#167;2.11、&#167;4.3 &#124;
&#124; T0 窄包理由、触点和两道门的时序 &#124; refact-fable/runtime/agent-dev-refact 工单 &#124; &#167;3.1 &#124;
&#124; 状态投影的拒绝与取消 &#124; 多稿状态表；现行产品合法边 &#124; &#167;3.3 &#124;
&#124; 清理失败不污染终态、失败现场保留 &#124; lifecycle-agent sandbox 清理 &#124; &#167;3.5、&#167;3.16 &#124;
&#124; 七环节、角色算法、产物取件、通知与超时 &#124; agent-dev-refact 流程导读；现行协议校准 &#124; &#167;3.18–&#167;3.22 &#124;
&#124; 私有 Git 元数据可写性与代提交 &#124; agent-dev-refact 工作区实验；现行协议代提交纪律 &#124; &#167;3.20 &#124;
&#124; 问询分层、三类威胁、具体批准对象与默认分级 &#124; refact-fable/runtime 人的通道与威胁；agent-dev-refact 中断 &#124; &#167;4.3–&#167;4.4、&#167;4.12 &#124;
&#124; 可信受理、附件校验、原值与默认值留痕 &#124; lifecycle-agent 前端与受理 &#124; &#167;3.1 &#124;
&#124; 网关令牌、环境洗白名单与跨腿委派禁令 &#124; lifecycle-agent 审批/凭据边界 &#124; &#167;4.13 &#124;
&#124; 门禁自身质量与七类假答案 &#124; agent-dev-refact 判据与实测汇总；README 正文抽查教训 &#124; &#167;5.12、&#167;12.1 &#124;
&#124; 历史证据的版本/环境/作者边界 &#124; 各稿的取证声明、未验证清单 &#124; &#167;5.13、&#167;9 &#124;
&#124; 对账观察面的覆盖、未归因与追认限制 &#124; agent-dev-refact 绕过观察 &#124; &#167;6.3 &#124;
&#124; 分组件迁移门、五源删除条件、完整 checkpoint &#124; agent-dev-refact 脚手架；lifecycle-agent 恢复和删除清单 &#124; &#167;7.2–&#167;7.5 &#124;
&#124; 内核修订工作单元与保留旧语义 &#124; agent-dev-refact 内核修订；runtime 迁移纪律 &#124; &#167;7.7 &#124;
&#124; 竞争评审的共同盲区和输入偏置 &#124; agent-dev-refact 评比边界与元观察 &#124; &#167;12.2 &#124;
&#124; 全部源标题与明确冲突处置 &#124; 五份历史正文及 README &#124; &#167;8.3、&#167;10 &#124;

**本次验证的范围**：源标题枚举与逐项处置一致；检查新增正文确有对应内容；
校验表格、相对链接、本文章节引用及完整源文件摘要；检查本文件不依赖 archive 的现行相对链接。
索引使用统一的一至四级标题口径：五稿 284 行，README 10 行，不再混用 182、197、76 的不同分母。

**本次没有做的验证**：没有复跑 SDK/模型、部署、权限、生产数据库或旧轮评审实验；
没有宣称已经获得独立验收，也没有宣称残余语义遗漏为零。
&#167;9.1–&#167;9.4 的旧测试结果仍属原作者、原环境、原版本。
源稿权限及 Git 布局实验保留为历史线索；“已有凭据即批准”“当前无需边界”等冲突不进入执行规则。

**完成内容迁移不等于完成删除门**：本次没有清理其他文档的旧引用，没有跑真实 T0/T1 开发任务，
也没有删除源稿。日常指南不再以 archive 为操作依赖；要删除历史源文件仍按 &#167;7.3 单独处理。

**输入文件 SHA-256（内容摘要，不是身份签名）：**

&#124; 源路径（相对 dev-plan） &#124; SHA-256 &#124;
&#124; --- &#124; --- &#124;
&#124; &#96;agent-dev-guide.md&#96; &#124; &#96;00065c06361e0097e56ac7f0a343b451001e253a2d636d37654e52cc98628e32&#96; &#124;
&#124; &#96;archive/README.md&#96; &#124; &#96;bb67f49c8563ca6dde81a9e81edc5dd70822342b9fbdff17a1af324b50805c1d&#96; &#124;
&#124; &#96;archive/agent-dev-refact.md&#96; &#124; &#96;888d8b1f6ec9a9d202fba6d3465b7e2e562219527b4a0812560655b00fb1b9a1&#96; &#124;
&#124; &#96;archive/development-lifecycle-agent.md&#96; &#124; &#96;70295ecf6ac887ecbc4346af6e2ac71c1ae659e0d8d79efb68631c6b28b9ffc9&#96; &#124;
&#124; &#96;archive/development-lifecycle-human.md&#96; &#124; &#96;33d0ba965734f4608d9519bed83947c09cb1c35e0f537647a2425d5441ad47d0&#96; &#124;
&#124; &#96;archive/refact-fable.md&#96; &#124; &#96;e318d5cede2d61e7b38a218cef0132bc240154ff42ec357912aaa182893958c2&#96; &#124;
&#124; &#96;archive/runtime-architecture.md&#96; &#124; &#96;9d8428d629d7fa52f925ff9e28f4b0bc8ed19c37601238f82b734f7628449741&#96; &#124;

</pre>

**G-101** · 源 agent-dev-guide.md，L2507–L2553；SHA-256 eb2712079c6eeebd1f5e80dba8f8b7624aa5668cba844a8243279ae99aa436fe

<pre data-unit="G-101">### 9.6 取代前 opus 做的核验（2026-09-08）

⚠ **这一节是 opus 写的，不是本版作者写的。**它记的是「凭什么敢用它换掉上一版」，
以及**核验到哪一步为止**。

**核了：**

&#124; # &#124; 核了什么 &#124; 结果 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; &#167;9.5 钉的输入 commit &#96;d9f827f8&#96; 是否可达、底稿是否 2402 行 &#124; ✓ 均对 &#124;
&#124; 2 &#124; &#167;9.5 给的**六个输入文件 SHA-256** &#124; ✓ **逐字节全部吻合** &#124;
&#124; 3 &#124; &#167;10 落点表行数与源节数是否一致 &#124; ✓ **294 = 284 + 10**，**零空落点** &#124;
&#124; 4 &#124; 是否覆盖了此前一直未落点的 &#96;agent-dev-refact.md&#96; &#124; ✓ **76 节全部有落点**（上一版完全没有） &#124;
&#124; 5 &#124; 随机抽 6 条 &#96;agent-dev-refact&#96; 落点，其中 3 条**回读落点正文** &#124; ✓ 关键词均在，**未抽到伪取证** &#124;
&#124; 6 &#124; 相对链接是否随改名失效 &#124; ✓ 全部指向兄弟文档，不受影响 &#124;

**它纠正了上一版三处，逐条复核属实：**

&#124; # &#124; 上一版的问题 &#124; 本版的处理 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; ⚠ **分母混用**：&#167;10 表用 &#96;##&#96;/&#96;###&#96;（182 行），正文却写「197 节」（一至四级口径） &#124; 统一为一至四级，**五稿 284**。⚠ 而 &#96;dev-plan-refact&#96; 任务书 &#167;8 **正是 opus 自己立的「计法固定为排除代码块后的 &#96;^#{1,4} &#96;」——立了规矩没照做** &#124;
&#124; 2 &#124; &#167;2.12 标题写「**实测**取值」，而那些值来自上一轮 &#124; 改为「**历史**取值示例」 &#124;
&#124; 3 &#124; 「身份只能来自目录名」把两件事混了 &#124; &#167;3.20 改为「目录名是**本地归属线索**，**不是经鉴别的 principal 身份**」 &#124;

⚠⚠ **没核的（比核了的更要紧）：**

&#124; # &#124; 没核 &#124; 为什么这条重要 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 1 &#124; ⚠ **294 条落点只抽了 6 条、正文级只验了 3 条** &#124; opus 上一次对 85 行做正文级抽查，**查出 50 处真缺、2 处落点判错**。按同一命中率，本表**很可能仍有数十处**。**「比上一版好」已证；「正确」未证** &#124;
&#124; 2 &#124; 新增 17 节的**反向覆盖**——有没有写进源稿里没有的东西 &#124; 一条未查 &#124;
&#124; 3 &#124; 与本轮只读输入的一致性 &#124; 见下 &#124;
&#124; 4 &#124; 全部继承自源稿的实测读数 &#124; &#167;9.5 已声明「仍属原作者、原环境、原版本」，opus **未复跑任何一条** &#124;

⚠ **对 &#96;dev-plan-refact&#96; 轮的影响，如实登记：**

本版**晚于该轮冻结基线 &#96;f1d5f8f4&#96;**。五家参赛方钉在基线上，**看到的仍是 2402 行那版**，
本次替换**不改变该轮的只读输入**——这正是冻结基线的用处。但由此产生两条待处置：

1. 该轮任务书 &#167;3 记的「&#96;agent-dev-guide.md&#96; 2388 行 92 节」与 master 现状不符——
   ⚠ **相对基线是对的，相对 master 是旧的**。本轮结束前不改任务书（&#96;B1&#96;）；
2. ⚠ 该轮 &#96;B8&#96; 要求「把 &#96;agent-dev-refact.md&#96; 76 节并入」——**本版已经做了**。
   该轮候选若重做，做的是**基线上那版**的并入。**这个重叠须由所有者在 ③ 处置**。

⚠ **opus 的利益申报**：opus 是本轮参赛方，且在写本节前**读了本版全文**。
按 &#96;call-①&#96;「提案冻结前不得读其他候选」，虽然本版不是该轮候选（路径不同），
但它是**同一主题、同一底稿、更新的融合稿**。**opus 的候选独立性已受影响，供 ③ 折算。**

</pre>

#### 历史源落点收据

**G-102** · 源 agent-dev-guide.md，L2554–L2875；SHA-256 0b028b5973ef57fd57dd7f9753605c11d64b421de58dab1c2e58e348cf6ecbe2

<pre data-unit="G-102">## 10. 五份历史正文及目录说明的逐节处置

这张表回答“源段内容在哪里，或为什么不保留”，不是日常执行步骤。
**唯一性的单位是“源文件 + 标题层级 + 标题文本”**；源文件固定为
k8s &#96;d9f827f810be6b645b9ef2c1339009328bca02f5&#96; 下 &#96;sunmoonai/docs/dev-plan/archive/&#96;。
源标题按脚本枚举，不把代码块里的样例标题算进正文。左列只是来源定位，右列的 &#167; 均指本文。

&#124; 源文件 &#124; 旧表口径：二/三级标题 &#124; 本次口径：一至四级标题 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; development-lifecycle-agent.md &#124; 73 &#124; 74 &#124;
&#124; development-lifecycle-human.md &#124; 45 &#124; 47 &#124;
&#124; refact-fable.md &#124; 31 &#124; 40 &#124;
&#124; runtime-architecture.md &#124; 33 &#124; 47 &#124;
&#124; agent-dev-refact.md &#124; 未入旧表 &#124; 76 &#124;
&#124; 合计历史正文 &#124; 182（仅前四稿） &#124; **284** &#124;
&#124; README.md（另计） &#124; 未入旧表 &#124; **10** &#124;

**覆盖索引不等于语义无缺。**本次在旧 182 行上增加原来未枚举的一级/四级标题、第五稿与
目录说明；对发现的落点错误重定位置。第一至第四稿已有行保留其来源处置语义，
其中“抽查发现原缺”等字样记录的是底稿吸收历史，不能误读成本次仍未补。
“不采用”并非漏迁：与底稿冲突的设计、失效文件拆分计划和无法成立的事实外推明确排除。

如将来发现右列正文不能支持对应处置，以实际正文和证据为准，登记修补；
不能用“表已全”驳回发现。历史源文件可用于审计复核，但开发动作不以读取它们为前置。

&#124; 源 &#124; 源标题（层级照原稿） &#124; 本文落点或不采用的理由 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; lifecycle-agent &#124; # 开发生命周期 · Agent &#124; &#167;0–&#167;7、&#167;11–&#167;14；整体承接执行纪律与架构，不保留“两条路径”的独立规范身份。 &#124;
&#124; lifecycle-agent &#124; ## 0. 边界和共同模型 &#124; &#167;0.1 &#124;
&#124; lifecycle-agent &#124; ### 0.1 本文负责什么 &#124; &#167;0.1；跨机同步与「子仓要自己推」补入 &#167;3.2（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ### 0.2 事实、目标和执行记录分开 &#124; &#167;1.2、&#167;5.2、**&#167;1.5 第 3 条**；&#96;request-baseline&#96; 的地位补入 &#167;0.1（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ### 0.3 两层监督职责与等位原则 &#124; **故意不要**：&#167;0.0 第 2 条判定「supervisor 一词三义」；由 &#167;2.1 五个组件词与 &#167;2.2 内容角色替代，「等位原则」不再需要单独声明 &#124;
&#124; lifecycle-agent &#124; ### 0.4 产出物的根本原则：私有地产生，单写者发布 &#124; &#167;3.6 &#124;
&#124; lifecycle-agent &#124; ## 1. 两条同构路径 &#124; **故意不要**：&#167;0.0 第 1 条——两条路径的差异只剩「谁按了回车」，撑不起两份文档 &#124;
&#124; lifecycle-agent &#124; ### 1.1 Agent 路径 &#124; 部分保留：&#167;3.1–&#167;3.3 的受理、物化、执行；不保留相对于 Human 的独立状态链。 &#124;
&#124; lifecycle-agent &#124; ### 1.2 Human 路径 &#124; 部分保留：&#167;3.1、&#167;4.1 的人工入口和 principal 职责；不另立 Human 运行时。 &#124;
&#124; lifecycle-agent &#124; ## 2. Submission 与 FastAPI 受理 &#124; &#167;3.1 &#124;
&#124; lifecycle-agent &#124; ### 2.1 前端提交 &#124; &#167;3.1；补原话/附件/输出/幂等键与前端不得自报可信身份、扩权的边界。 &#124;
&#124; lifecycle-agent &#124; ### 2.2 FastAPI 建立开发 Task &#124; &#167;3.1；补认证上下文、附件校验、版本化策略、首 Event 持久化与规范化留痕；不把框架名当规范。 &#124;
&#124; lifecycle-agent &#124; ### 2.3 Task 契约 &#124; &#167;2.4；⚠ **抽查发现原落点缺一半字段**，已补「硬门禁/质量偏好/待定项必须分开」与 8 个字段 &#124;
&#124; lifecycle-agent &#124; ## 3. 简单与复杂任务 &#124; 部分保留：&#167;3.4 的载体判据；不以该二分取代 T0/T1/T2 风险档位。 &#124;
&#124; lifecycle-agent &#124; ### 3.1 简单 Task &#124; &#167;3.4 **载体轴段**；⚠ **原落点判错**——简单/复杂是载体轴，T0/T2 是风险轴，两轴正交，混写即 &#167;2.5 警告的循环 &#124;
&#124; lifecycle-agent &#124; ### 3.2 复杂 Task &#124; &#167;3.4 载体轴段；同上 &#124;
&#124; lifecycle-agent &#124; ## 4. sandbox、Git 物化与执行器接入架构 &#124; &#167;3.2、&#167;2.6 &#124;
&#124; lifecycle-agent &#124; ### 4.1 谁建立什么 &#124; &#167;3.2 &#124;
&#124; lifecycle-agent &#124; ### 4.2 物化步骤 &#124; &#167;3.2 &#124;
&#124; lifecycle-agent &#124; ### 4.3 按 Task 塞入材料 &#124; **&#167;3.10** manifest 字段表 + 「材料可见 ≠ 使用授权」（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ### 4.4 物化门禁 &#124; **&#167;3.10** 物化门禁十条；⚠ **原落点 &#167;3.2 只有 3 条复用判据，十条全缺**（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 4.5 执行层路线：租用 loop，自建业务控制面 &#124; &#167;2.6；补 Gate 0 三条条件、三层成熟度与确定性熟路，均保留待验身份。 &#124;
&#124; lifecycle-agent &#124; ### 4.6 两个官方 SDK：两个轴、非对称能力 &#124; &#167;2.7 &#124;
&#124; lifecycle-agent &#124; ### 4.7 统一执行 Port 与三态能力探针 &#124; &#167;2.8；补通用 DTO、Adapter 不拥有授权/验收/四本账/Task 终态的边界。 &#124;
&#124; lifecycle-agent &#124; ### 4.8 Harness SDK 前置门禁与过渡补法 &#124; &#167;2.9 &#124;
&#124; lifecycle-agent &#124; ### 4.9 双 runtime 的部署、进程与恢复 &#124; &#167;2.10 &#124;
&#124; lifecycle-agent &#124; ### 4.10 专用 Agent 的构建方法，不冻结具体 Profile &#124; &#167;2.6；方法、dry-plan/query、submit_result 与暂不冻结财务具体契约均保留。 &#124;
&#124; lifecycle-agent &#124; ### 4.11 OpenClaw Gateway：借机制，不转向 &#124; &#167;2.6；保留机制取舍与实际依赖边界，非 &#167;3.2 工作区供给。 &#124;
&#124; lifecycle-agent &#124; ## 5. Agent 执行内核 &#124; &#167;3 &#124;
&#124; lifecycle-agent &#124; ### 5.1 冷启动核对 &#124; **&#167;3.10** 冷启动七条 + **写入前门禁五条（一票否决）**；⚠ **原落点两处均无此内容**（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 5.2 上下文路由 &#124; **&#167;5.8** 八个改动面 + 能力四级词典；⚠ **原落点 &#167;2.5 是路由成本字段，不是同一件事**（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 5.3 共同纪律 &#124; **&#167;1.5** 八条（**抽查发现原缺**；&#167;11 只有反面形式，无正面纪律） &#124;
&#124; lifecycle-agent &#124; ### 5.4 单路实施 &#124; &#167;3.4 T1 行；「作者自检不能代替独立验收」补入 &#167;5.5 L1（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ### 5.5 Checkpoint 与恢复 &#124; &#167;2.10、&#167;4.3、&#167;7.5；补完整 checkpoint 字段及恢复前权限/租约/基线/副作用复验。 &#124;
&#124; lifecycle-agent &#124; ### 5.6 失败、澄清与改判 &#124; &#167;1.5、&#167;4.8、&#167;5.13；失败、关键歧义、追加改判与目标转事实前取证。 &#124;
&#124; lifecycle-agent &#124; ## 6. Attempt 内的执行监督 Agent &#124; **部分故意不要**：「执行监督 Agent」是 &#167;0.0 第 2 条判掉的同名物；其纪律落 &#167;2.2 与 round-protocol，不保留该角色名 &#124;
&#124; lifecycle-agent &#124; ### 6.1 展开条件 &#124; **&#167;3.13** 五种执行形态；⚠ **原落点判错**——guide &#167;6.1 是「机械分类」（运行时值不值得用），与 fan-out 形态无关（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 6.2 Work Unit 契约 &#124; **&#167;2.11**；⚠ 原落点 &#167;2.4 是工单（整个 Task），派工契约是另一层，三字段派工纪律全缺（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 6.3 建立 worktree &#124; **&#167;3.14** 十条细则（**抽查发现原缺** 4 条：同分支不可双检出、只隔离写入、凭据不得进分支、删 worktree ≠ 删证据） &#124;
&#124; lifecycle-agent &#124; ### 6.4 候选隔离 &#124; &#167;2.2、**&#167;2.11**；⚠ 「隔离靠纪律不靠机制、无法事后证明独立」**原缺**（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 6.5 角色分离 &#124; &#167;2.2 &#124;
&#124; lifecycle-agent &#124; ### 6.6 评审、裁决和选优 &#124; **&#167;5.10** 事实裁决表 + 两阶段评审 + 「不合格候选不进偏好评分」（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ### 6.7 改进、整合和回归 &#124; **&#167;5.10** 整合纪律；⚠ 「一条独立主张一个提交」与「候选的绿不证明整合正确」**原缺**（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 6.8 停止规则 &#124; **&#167;3.13** 六条（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ### 6.9 内层的三条硬禁令 &#124; **&#167;4.9**（**抽查发现原缺**）；含「忘了传 handler 与故意自动批准在代码里长得一样」 &#124;
&#124; lifecycle-agent &#124; ## 7. 产出物与 commit 的全生命周期 &#124; &#167;3.6–&#167;3.9 &#124;
&#124; lifecycle-agent &#124; ### 7.1 先确定身份、所有权和发布权 &#124; &#167;3.6 &#124;
&#124; lifecycle-agent &#124; ### 7.2 命名空间 &#124; &#167;3.6 &#124;
&#124; lifecycle-agent &#124; ### 7.3 产出物分类与载体 &#124; &#167;3.3 末段 Artifact 版本属性 &#124;
&#124; lifecycle-agent &#124; ### 7.4 候选状态机 &#124; **&#167;3.11** 八态 + 七条纪律；⚠ **原落点只有一句「Artifact 有版本属性」，状态机全缺**（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 7.5 未提交文件、commit、分支与 worktree 的不同语义 &#124; **&#167;5.9** 七载体对照表 + 「reflog 里还在不是保留策略」；⚠ 原落点 &#167;5.4 只有散文，无对照表（抽查发现） &#124;
&#124; lifecycle-agent &#124; ### 7.6 各种并发场景的处置 &#124; &#167;3.7 &#124;
&#124; lifecycle-agent &#124; ### 7.7 最终路径的发布协议 &#124; **&#167;3.15** 三路径 + compare-and-swap + 「只要草案时 target 是候选集合」（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ### 7.8 覆盖或来源不明时的事故处理 &#124; &#167;3.8 &#124;
&#124; lifecycle-agent &#124; ### 7.9 保留与垃圾回收 &#124; **&#167;3.16** 六档表 + 「GC 是显式阶段不是退出副作用」+ 删除前六项验证（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ## 8. 冻结、迟到结果与取消 &#124; &#167;3.9 &#124;
&#124; lifecycle-agent &#124; ### 8.1 &#96;F-EXEC-*&#96; / &#96;F-INTERACT-*&#96; 双腿落地矩阵 &#124; &#167;5.6 &#124;
&#124; lifecycle-agent &#124; ## 9. 权限、预算与副作用 &#124; &#167;4.5、&#167;4.13；权限交集、父预算、稳定幂等键及副作用意图/回执/补偿。 &#124;
&#124; lifecycle-agent &#124; ### 9.1 三道正交门与工具不可见原则 &#124; &#167;4.6 &#124;
&#124; lifecycle-agent &#124; ### 9.2 四档审批、哈希绑定与凭据边界 &#124; &#167;4.7、&#167;4.13；四档/哈希/超时已在，补 egress 短令牌、环境白名单、跨腿委派禁令与副作用账。 &#124;
&#124; lifecycle-agent &#124; ## 10. 证据、验收、交付和清理 &#124; &#167;5、&#167;3.5 &#124;
&#124; lifecycle-agent &#124; ### 10.1 最小证据账 &#124; &#167;5.7 &#124;
&#124; lifecycle-agent &#124; ### 10.2 最终验收 &#124; &#167;5.5 L1/L3、**&#167;3.12** 十三条（抽查：七条中六条已在 &#167;3.12，「声称完成/全返回不算成功」在 &#167;3.12 与 &#167;11） &#124;
&#124; lifecycle-agent &#124; ### 10.3 Delivery &#124; &#167;3.5 &#124;
&#124; lifecycle-agent &#124; ### 10.4 sandbox 清理 &#124; &#167;3.5、&#167;3.16；补敏感缓存销毁、失败现场责任/期限、清理失败独立告警。 &#124;
&#124; lifecycle-agent &#124; ## 11. Human 与 Agent 对照 &#124; **故意不要**：&#167;0.0 第 1 条；两路径合一后无对照对象 &#124;
&#124; lifecycle-agent &#124; ### 11.1 本文的生效边界 &#124; &#167;0.1 &#124;
&#124; lifecycle-agent &#124; ### 11.2 本文的删除条件与清理清单 &#124; &#167;7.3；保留长期落点、可执行纪律与入口清理要求；不保留两路径/两文并存前提。 &#124;
&#124; lifecycle-agent &#124; ### 11.3 本轮未验证清单 &#124; **&#167;7.6** 八条 + 「清单为空前一律按 &#96;defined&#96; 对待」；⚠ **原落点两处均无此八条**（抽查发现） &#124;
&#124; lifecycle-agent &#124; ## 12. 完成判据 &#124; **&#167;3.12** 十三条 + 「缺项只能称已受理…不能笼统宣称完成」（**抽查发现原缺**） &#124;
&#124; lifecycle-agent &#124; ## 13. 反模式 &#124; &#167;11 &#124;
&#124; lifecycle-agent &#124; ## 14. 常见失败方式与项目实例 &#124; &#167;12 &#124;
&#124; lifecycle-agent &#124; ## 附录 A：词汇对照 &#124; &#167;13 &#124;
&#124; lifecycle-agent &#124; ## 附录 B：开发 Task 持久记录模板 &#124; &#167;14 &#124;
&#124; lifecycle-human &#124; # 开发生命周期 · 人 &#124; &#167;4、&#167;3、&#167;7.5；人的权力/义务与共同执行纪律进入同一指南。 &#124;
&#124; lifecycle-human &#124; ## 1. 为什么要单独一份 &#124; 部分保留：&#167;0.3 的单份指南自足目标；不保留 Human 独立流程文档的存在理由。 &#124;
&#124; lifecycle-human &#124; ### 1.1 为什么本文必须自足 &#124; &#167;0.3、&#167;3.19–&#167;3.22；保留执行者无需回到将删源稿拼规则的阅读要求，不维持两份同构规范。 &#124;
&#124; lifecycle-human &#124; ### 1.2 两条路径的差异总表 &#124; 部分保留：&#167;4.1、&#167;4.5 的人的权力与责任；不保留两条开发路径对照。 &#124;
&#124; lifecycle-human &#124; ## 2. 人的三个角色 &#124; &#167;2.11、&#167;4.1；保留提出、内容贡献、持权职责；人贡献内容不登记为 Agent Profile。 &#124;
&#124; lifecycle-human &#124; ## 3. 人独有的权力，及其义务 &#124; &#167;4.5 &#124;
&#124; lifecycle-human &#124; ## 4. 跨会话续接：靠文档，不靠记忆 &#124; &#167;7.5 &#124;
&#124; lifecycle-human &#124; ## 5. 小请求的裁量权 &#124; &#167;4.8 &#124;
&#124; lifecycle-human &#124; ## 6. 改判三要素 &#124; &#167;4.8 &#124;
&#124; lifecycle-human &#124; ## 7. 人与 agent 协作时，人的义务 &#124; **&#167;4.10** 六条 + 「盲区声明是自愿的，说了就受罚就没人说」（**抽查发现原缺**） &#124;
&#124; lifecycle-human &#124; ## 8. 提出与委派一项开发工作 &#124; &#167;3.1 &#124;
&#124; lifecycle-human &#124; ### 8.1 冻结工作单元 &#124; &#167;3.1、&#167;2.4 &#124;
&#124; lifecycle-human &#124; ### 8.2 工作区从哪来 &#124; &#167;3.2 &#124;
&#124; lifecycle-human &#124; ### 8.3 委派 &#124; &#167;3.4、**&#167;4.10**「委派转移执行不转移责任」（**抽查发现原缺**） &#124;
&#124; lifecycle-human &#124; ## 9. 终审与责任归属 &#124; &#167;4.5 责任归属表 &#124;
&#124; lifecycle-human &#124; # 共同内核 &#124; &#167;3–&#167;5；共同内核并入统一执行路径，不作为第二个独立文档。 &#124;
&#124; lifecycle-human &#124; ## 10. 执行内核 &#124; &#167;3（与 agent 文 源节 5 同源，重合度 0.4–0.85） &#124;
&#124; lifecycle-human &#124; ### 10.1 动手前的核对与写入前门禁 &#124; **&#167;3.10**（同 agent 文 源节 5.1，重合 0.66；随该行一并更正） &#124;
&#124; lifecycle-human &#124; ### 10.2 上下文路由与范围门禁 &#124; **&#167;5.8**（同 agent 文 源节 5.2，重合 0.84；随该行一并更正） &#124;
&#124; lifecycle-human &#124; ### 10.3 共同纪律 &#124; **&#167;1.5**（同 agent 文 源节 5.3，重合 0.85；随该行一并更正） &#124;
&#124; lifecycle-human &#124; ### 10.4 单路实施与定向审核 &#124; &#167;3.4 T1、&#167;5.5 L1（同 agent 文 源节 5.4） &#124;
&#124; lifecycle-human &#124; ### 10.5 冻结、迟到与取消 &#124; &#167;3.9（同 agent 文 源节 8） &#124;
&#124; lifecycle-human &#124; ## 11. 人作为协调者：fan-out &#124; &#167;2.2、&#167;3.4 &#124;
&#124; lifecycle-human &#124; ### 11.1 展开条件 &#124; **&#167;3.13**（同 agent 文 源节 6.1；随该行一并更正） &#124;
&#124; lifecycle-human &#124; ### 11.2 派工契约 &#124; **&#167;2.11**（同 agent 文 源节 6.2；随该行一并更正） &#124;
&#124; lifecycle-human &#124; ### 11.3 建立 worktree &#124; &#167;3.2、**&#167;3.14**（同 agent 文 源节 6.3） &#124;
&#124; lifecycle-human &#124; ### 11.4 候选隔离 &#124; &#167;2.2、**&#167;2.11**（同 agent 文 源节 6.4，重合 0.76） &#124;
&#124; lifecycle-human &#124; ### 11.5 角色分离 &#124; &#167;2.2（同 agent 文 源节 6.5，重合 0.70） &#124;
&#124; lifecycle-human &#124; ### 11.6 评审、裁决和选优 &#124; **&#167;5.10**（同 agent 文 源节 6.6，重合 0.57） &#124;
&#124; lifecycle-human &#124; ### 11.7 改进、整合和回归 &#124; **&#167;5.10**（同 agent 文 源节 6.7） &#124;
&#124; lifecycle-human &#124; ### 11.8 停止规则 &#124; **&#167;3.13**（同 agent 文 源节 6.8） &#124;
&#124; lifecycle-human &#124; ## 12. 产出物与 commit 的落地纪律 &#124; &#167;3.6–&#167;3.9（与 agent 文 源节 7 同源） &#124;
&#124; lifecycle-human &#124; ### 12.1 根本原则：私有地产生，单写者发布 &#124; &#167;3.6（同 agent 文 源节 0.4，重合 0.64） &#124;
&#124; lifecycle-human &#124; ### 12.2 本仓的具体落点 &#124; &#167;3.6 本仓落点表 &#124;
&#124; lifecycle-human &#124; ### 12.3 未提交文件、commit、分支与 worktree 的不同语义 &#124; **&#167;5.9**（同 agent 文 源节 7.5，重合 0.84） &#124;
&#124; lifecycle-human &#124; ### 12.4 产出物分类 &#124; &#167;3.3、**&#167;3.11**（同 agent 文 源节 7.3/源节 7.4） &#124;
&#124; lifecycle-human &#124; ### 12.5 各种场景的处置 &#124; &#167;3.7（同 agent 文 源节 7.6） &#124;
&#124; lifecycle-human &#124; ### 12.6 覆盖或来源不明时的事故处理 &#124; &#167;3.8（同 agent 文 源节 7.8，重合 0.88） &#124;
&#124; lifecycle-human &#124; ### 12.7 最终路径的发布协议 &#124; **&#167;3.15**（同 agent 文 源节 7.7） &#124;
&#124; lifecycle-human &#124; ### 12.8 保留与清理 &#124; **&#167;3.16**（同 agent 文 源节 7.9） &#124;
&#124; lifecycle-human &#124; ## 13. 证据账 &#124; &#167;5.7 &#124;
&#124; lifecycle-human &#124; ## 14. 成本与停止规则 &#124; **&#167;3.13** 成本纪律四条；⚠ 「交叉阅读是二次复杂度」「未经事实验证要标注」「失败/超时/缺席也进记录」**原缺**（抽查发现） &#124;
&#124; lifecycle-human &#124; ## 15. 完成判据 &#124; **&#167;3.12**（同 agent 文 源节 12；随该行一并更正） &#124;
&#124; lifecycle-human &#124; ## 16. 反模式 &#124; &#167;11 &#124;
&#124; lifecycle-human &#124; ## 17. 常见失败方式与项目实例 &#124; &#167;12 &#124;
&#124; lifecycle-human &#124; ## 18. 边界 &#124; &#167;0.1、&#167;0.3；保留单份开发指南自足与产品真源分工，不保留对另一条生命周期的依赖。 &#124;
&#124; lifecycle-human &#124; ## 附录 词汇对照 &#124; &#167;13 &#124;
&#124; refact-fable &#124; # 重构方案：开发框架从「两条路径 + 多重 supervisor」改为「一套状态机、多个 Profile、一张权力表」 &#124; &#167;0.0、&#167;1–&#167;7、&#167;8；保留诊断与纪律，架构以底稿后继裁定为准。 &#124;
&#124; refact-fable &#124; ## 0. 一页摘要 &#124; &#167;0、&#167;8.2 &#124;
&#124; refact-fable &#124; ## 1. 诊断：现状的六个结构问题 &#124; &#167;0.1、&#167;2、&#167;3.4、&#167;7.3 &#124;
&#124; refact-fable &#124; ### 1.1 「两条路径」是假分叉 &#124; &#167;0、&#167;3；统一为一条开发 Task 链 &#124;
&#124; refact-fable &#124; ### 1.2 supervisor 已有三套同名物，第三套还有一个未定义的别名 &#124; &#167;2.1、&#167;2.2；组件与内容角色分名 &#124;
&#124; refact-fable &#124; ### 1.3 权力与流程混写 &#124; &#167;4.2；权力表从执行顺序中独立 &#124;
&#124; refact-fable &#124; ### 1.4 一个环节判不了 &#124; &#167;4.4、&#167;5.2；把身份强度与未知显式化 &#124;
&#124; refact-fable &#124; ### 1.5 执行架构与开发流程装在同一份文件里 &#124; &#167;0.1、&#167;2 与 &#167;3 分开 &#124;
&#124; refact-fable &#124; ### 1.6 档位只有 T2 有正文 &#124; &#167;3.4；补齐三档执行形态 &#124;
&#124; refact-fable &#124; ## 2. 设计原则 &#124; **&#167;1.6** P0–P5 + 两条推论；⚠ **抽查发现原缺**：P5「凡能落成代码的纪律必须落成」与「只能靠人转述的环节等于没有环节」整段无落点 &#124;
&#124; refact-fable &#124; ## 3. 目标架构 &#124; &#167;2–&#167;5 &#124;
&#124; refact-fable &#124; ### 3.1 一套状态机，两个 Profile &#124; &#167;1.1、&#167;2.3；撤销部署形态分层，保留内核两种契约对象 &#124;
&#124; refact-fable &#124; #### 3.1.1 开发 Profile → 唯一状态机 的映射 &#124; &#167;3.3；对象/状态投影与合法边，取消两种部署 Profile 的命名。 &#124;
&#124; refact-fable &#124; ### 3.2 执行者模型：三种 kind，一张登记表 &#124; &#167;2.3、&#167;4.1；纠正人为 principal 而非 executor &#124;
&#124; refact-fable &#124; ### 3.3 权力表：驱动 APPROVAL 类 interrupt 的唯一来源 &#124; &#167;4.2 &#124;
&#124; refact-fable &#124; ### 3.4 人的通道：收件箱 + 回执 &#124; &#167;4.12；补对象展示、字段分级、决定持久化与触点观测；身份强制依 &#167;4.4，不恢复旧签名拓扑。 &#124;
&#124; refact-fable &#124; ### 3.5 路由：三值决策，模型只建议 &#124; &#167;2.1、&#167;2.5；「分类节点只给四条判据的命中证据，不给 tier」补入 &#167;2.1（**抽查发现原缺**） &#124;
&#124; refact-fable &#124; ### 3.6 工单：一个冻结的 Artifact，一次确认 &#124; &#167;2.4、&#167;3.1 &#124;
&#124; refact-fable &#124; ### 3.7 工作区供给：纯函数，判据是独占与干净 &#124; &#167;3.2 &#124;
&#124; refact-fable &#124; ### 3.8 状态判定与分发：一般化现有脚本 &#124; **&#167;3.18** 六条硬要求；⚠ **抽查发现原缺**「推导值 ≠ 声明值即报错」「边不在合法表即报错退出」「分发前角色冲突拒绝」 &#124;
&#124; refact-fable &#124; ### 3.9 角色：supervisor 解体为五个各有定义的词 &#124; &#167;2.1、&#167;2.2 &#124;
&#124; refact-fable &#124; ### 3.10 开发 Profile ↔ 内核对象对照 &#124; **&#167;3.17** 对照表本体（**抽查发现原缺**：&#167;3.3 是状态投影表，与「对象↔载体」不是同一张） &#124;
&#124; refact-fable &#124; ### 3.11 git 载体的语义映射：什么是权威、什么是投影、什么验不了 &#124; &#167;5.4 &#124;
&#124; refact-fable &#124; ### 3.12 验证分层：谁判什么 &#124; &#167;5.5；acceptor「既得利益最小、由处置表算出」与 L3「抽样规则写进工单」补入（**抽查发现原缺**） &#124;
&#124; refact-fable &#124; ### 3.13 签名回执的威胁模型与密钥分布 &#124; &#167;4.4、&#167;4.12、&#167;5.13、&#167;8.1；保留三类威胁、误签边界、环境取证，撤销旁路拓扑。 &#124;
&#124; refact-fable &#124; #### 3.13.0 取证声明（先于事实） &#124; &#167;5.13；取证环境先于权限结论。 &#124;
&#124; refact-fable &#124; #### 3.13.1 现状事实（2026-09-05；宿主身份由 opus / luna 复核，S1 前须按 3.13.0 重跑） &#124; &#167;4.4；同期凭据域与机器事实作为历史证据，开发前重核。 &#124;
&#124; refact-fable &#124; #### 3.13.2 三道边界都要放在 agent 的 credential domain 之外 &#124; 部分保留：&#167;4.4、&#167;8.1；保留凭据域外强制原则，拒绝组合旁路设施作为安全架构。 &#124;
&#124; refact-fable &#124; #### 3.13.3 回执仓的对象模型：回执是仓内自己的签名 commit，不是跨仓 tag &#124; 不采用：&#167;8.1 K3–K6；特定签名存储对象模型不在真实动作路径上。 &#124;
&#124; refact-fable &#124; #### 3.13.4 回执 schema &#124; 部分保留：&#167;4.12；批准对象/版本/验收内容保留，不继承特定回执 YAML schema。 &#124;
&#124; refact-fable &#124; #### 3.13.5 两台机器的身份与凭据分布 &#124; &#167;4.4；保留人机共享凭据与工作站代做风险，不恢复已撤销 key 拓扑。 &#124;
&#124; refact-fable &#124; #### 3.13.6 剩余风险（如实登记） &#124; &#167;4.4、&#167;4.12、&#167;5.13；保留误签、端点不可达、权限漂移与取证限制，丢弃绑定旧设施的操作步骤。 &#124;
&#124; refact-fable &#124; ## 4. 对原建议的处置 &#124; &#167;8.2 &#124;
&#124; refact-fable &#124; ## 5. 文档重构 &#124; &#167;0.1、&#167;7.3、&#167;10 &#124;
&#124; refact-fable &#124; ### 5.1 目标文件树 &#124; &#167;0.1、&#167;7.2；用真源职责取代一次性树形蓝图 &#124;
&#124; refact-fable &#124; ### 5.2 旧 → 新映射：按旧文全部标题，脚本检查零缺口 &#124; &#167;10 &#124;
&#124; refact-fable &#124; ### 5.3 删除条件 &#124; &#167;3.5、&#167;7.3 &#124;
&#124; refact-fable &#124; ## 6. 实施路线 &#124; &#167;7.1；按本轮核查重排为 G0–G5 &#124;
&#124; refact-fable &#124; ## 7. 风险与未决 &#124; &#167;7.4、&#167;9.2 &#124;
&#124; refact-fable &#124; ## 8. 本方案自身的验收标准（供开轮时冻结） &#124; &#167;5、&#167;7.3、&#167;9、&#167;10 &#124;
&#124; runtime-architecture &#124; # 运行时架构：只有一个运行时，开发是它的第一个 Task Profile &#124; &#167;0、&#167;1–&#167;7；唯一运行时保留，被后继推翻的设计在 &#167;8 明确隔离。 &#124;
&#124; runtime-architecture &#124; ## 0. 一页摘要 &#124; &#167;0、&#167;8.2 &#124;
&#124; runtime-architecture &#124; ## 1. 本稿与上一轮的关系 &#124; &#167;8.2、&#167;10 &#124;
&#124; runtime-architecture &#124; ## 2. P1 — 一个运行时、唯一状态机、&#96;dev.change&#96;、五个 Agent Profile &#124; &#167;1.1、&#167;2.3、&#167;3 &#124;
&#124; runtime-architecture &#124; ### 2.1 运行时 = 内核对象的唯一写入面 + 四个确定性组件 + 两个适配层 &#124; &#167;1.2、&#167;2.1 &#124;
&#124; runtime-architecture &#124; ### 2.2 Task Profile &#96;dev.change&#96; 版本 1 &#124; &#167;2.3、&#167;2.4、&#167;3；别名登记、&#96;privacy&#96;(NO ZDR)、观察窗中位数、&#96;freshness&#96; 四项补入 &#167;2.4（**抽查发现原缺**） &#124;
&#124; runtime-architecture &#124; #### 2.2.1 工单：一个冻结的 Artifact，一次确认 &#124; &#167;2.4、&#167;3.1；冻结工单、窄包与两道门已在正文。 &#124;
&#124; runtime-architecture &#124; ### 2.3 五个 Agent Profile：登记表 &#124; **&#167;2.12** 登记表本体 + &#96;channel_grade&#96;；⚠ **抽查发现原缺**（&#167;2.3 只说「至少登记这些字段」，无取值） &#124;
&#124; runtime-architecture &#124; ### 2.4 人：principal + 权力表；每一次介入 → 一条边 + 一行 &#124; &#167;4.1、&#167;4.2、**&#167;4.11** 实例级清单；⚠ **抽查发现原缺**——而实例级清单正是上一轮 ⑤ 验收 &#96;C-1&#96; 抓出的缺项，**连丢两轮** &#124;
&#124; runtime-architecture &#124; #### 2.4.1 本轮（&#96;runtime&#96;）已发生介入的逐条清单 &#124; &#167;4.11；12 次介入逐项清单，历史边归属不改作当前运行轨迹。 &#124;
&#124; runtime-architecture &#124; ### 2.5 &#96;dev.change&#96; 的产物 → 唯一状态机 &#124; &#167;3.3 &#124;
&#124; runtime-architecture &#124; ### 2.6 bootstrap 与目标态：同一 Task Profile 的两种 orchestrator 实现 &#124; &#167;5.4、&#167;7.2 &#124;
&#124; runtime-architecture &#124; ### 2.7 等效判据：两层 + 投影 + 来源等级 + 比较上下文 &#124; &#167;5.3；&#96;author_claimed&#96; / &#96;author_attested&#96; 拆分补入（**抽查发现原缺**） &#124;
&#124; runtime-architecture &#124; #### 2.7.1 S 层与 R 层 &#124; &#167;5.3；S/R 两层及静态权力约束。 &#124;
&#124; runtime-architecture &#124; #### 2.7.2 R 层的轨迹条目 &#124; &#167;5.3；轨迹字段、双作者与来源等级。 &#124;
&#124; runtime-architecture &#124; #### 2.7.3 &#96;TraceEnvelope&#96;（比较上下文，不是第五条序列） &#124; &#167;5.3；比较上下文字段完整保留，不另立 TraceEnvelope 内核对象。 &#124;
&#124; runtime-architecture &#124; #### 2.7.4 比对规则（六条） &#124; &#167;5.3；六条比对规则与白名单、较粗粒度、最低来源上限。 &#124;
&#124; runtime-architecture &#124; ### 2.8 trace 样例：&#96;refact-fable&#96; 轮的真实产物 &#124; **&#167;5.11** 轨迹表本体 + 对照组 + 引用纪律两条；⚠ **抽查发现原缺**——&#167;5.3 只留了「23 条里 2 条」的读数，**结论在、证据不在** &#124;
&#124; runtime-architecture &#124; ## 3. P2 — Interaction 双向带载荷：一个内核修订工作单元 &#124; &#167;4.3、&#167;8.1 K1–K2；核查后不启动该修订 &#124;
&#124; runtime-architecture &#124; ### 3.1 缺口 &#124; &#167;4.3；故意不要原缺口判断，因为现有自由 resume 原语已覆盖所述形状 &#124;
&#124; runtime-architecture &#124; ### 3.2 扩展后的绑定字段表 &#124; &#167;4.3；故意不要自造字段表，缺少真实消费者与拒收用例 &#124;
&#124; runtime-architecture &#124; ### 3.3 &#96;amend&#96; 的路径：新 Artifact 版本 → 下一 Attempt 的输入；不建新 Task &#124; &#167;3.3、&#167;4.3；故意不要另开 Attempt，checkpoint 应原地恢复 &#124;
&#124; runtime-architecture &#124; ### 3.4 与权力表的对应 &#124; &#167;4.2–&#167;4.3；只保留实际 Interaction 与权力动作绑定 &#124;
&#124; runtime-architecture &#124; ### 3.5 修订工作单元（按 &#96;request-lifecycle.md:627&#96; 修订纪律） &#124; &#167;1.1、&#167;4.3；故意不要该单元，因其前提已被代码证伪 &#124;
&#124; runtime-architecture &#124; ## 4. P3 — 可观测粒度进 Agent Profile，及其对证据权威性的后果 &#124; &#167;5.1–&#167;5.2 &#124;
&#124; runtime-architecture &#124; ### 4.1 粒度是三个字段，不是一个；至少四档 &#124; &#167;5.1；&#96;codex exec --json&#96; 的锚点取证补入 &#167;2.12（**抽查发现原缺**，本次已复跑于 &#96;7d6f808b&#96;） &#124;
&#124; runtime-architecture &#124; ### 4.2 五家的取值 &#124; **&#167;2.12** 读数三条 + 「机械非空不等于填对」的实例（**抽查发现原缺**） &#124;
&#124; runtime-architecture &#124; ### 4.3 证据权威性：由粒度推导，不由执行者声明 &#124; &#167;5.2 &#124;
&#124; runtime-architecture &#124; ### 4.4 三道边界是架构组件，不随脚手架拆 &#124; &#167;4.4、&#167;8.1 K3–K6；故意不要组合设计，真实动作未经过这些设施 &#124;
&#124; runtime-architecture &#124; #### 4.4.1 三道边界的具体形态 &#124; 不采用：&#167;8.1 K3–K6；保留 &#167;4.4 真实强制点要求，不恢复三道旁路拓扑。 &#124;
&#124; runtime-architecture &#124; #### 4.4.2 回执仓的对象模型：回执是仓内自己的签名 commit，不是跨仓 tag &#124; 不采用：&#167;8.1 K3–K6；不恢复特定签名存储对象模型。 &#124;
&#124; runtime-architecture &#124; #### 4.4.3 回执 schema &#124; 部分保留：&#167;4.12；保留批准的内容与版本绑定，不恢复旧 YAML schema。 &#124;
&#124; runtime-architecture &#124; ### 4.5 独占工作区在 CLI / GUI 腿是约定，不是隔离 &#124; &#167;3.2；「涉及第二租户或真实财务数据前必须经数据网关、不得给裸库凭据」补入（**抽查发现原缺**） &#124;
&#124; runtime-architecture &#124; #### 4.5.1 工作区供给：纯函数，判据是独占与干净 &#124; &#167;3.2、&#167;3.20；独占/干净/基线、工作区数量与实际提交能力。 &#124;
&#124; runtime-architecture &#124; ### 4.6 R2：principal 通道也有粒度 &#124; &#167;4.4、&#167;4.12、&#167;5.2、&#167;7.2；保留 channel_grade、不可预填批准与服务化身份前置。 &#124;
&#124; runtime-architecture &#124; #### 4.6.1 人的通道：收件箱 + 回执 &#124; &#167;4.12；收件箱与持久决定、默认分级、触点观测；不恢复旧人执行器登记。 &#124;
&#124; runtime-architecture &#124; #### 4.6.2 两台机器的身份与凭据分布 &#124; &#167;4.4、&#167;5.13；机器/身份事实限定历史范围，批准强制不靠旧密钥分布。 &#124;
&#124; runtime-architecture &#124; #### 4.6.3 剩余风险（如实登记） &#124; &#167;4.4、&#167;4.12；误签、配置漂移、端点失败及工作站代理风险，排除旧设施专属补丁。 &#124;
&#124; runtime-architecture &#124; ### 4.7 取证纪律与当前事实 &#124; &#167;4.4（含新补的三行现状事实：无 GPG 密钥、&#96;id_rsa&#96; 对主仓可写、Windows 侧亦跑本地 agent）、&#167;8.1、&#167;9 &#124;
&#124; runtime-architecture &#124; ## 5. 必答 Q：运行时相对手工直接调用助手的开销盈亏线 &#124; &#167;6 &#124;
&#124; runtime-architecture &#124; ### 5.1 分类规则（机械可判，全部由工单字段直接判） &#124; &#167;2.5、&#167;6.1 &#124;
&#124; runtime-architecture &#124; ### 5.2 反例（三类走运行时反而更贵的任务） &#124; &#167;6.2 &#124;
&#124; runtime-architecture &#124; ### 5.3 T0 开销上界（复合向量，任一维超标即不标 T0） &#124; &#167;6.2 &#124;
&#124; runtime-architecture &#124; ### 5.4 绕过的可观测性 &#124; &#167;6.3 &#124;
&#124; runtime-architecture &#124; ## 6. 对 OP-1 / OP-2 / OP-3 的裁定 &#124; &#167;5.3、&#167;6、&#167;8.2；保留 OP-1/OP-3，按 K1/K2 撤销 OP-2 &#124;
&#124; runtime-architecture &#124; ## 7. 覆盖声明、盲区与未验证项 &#124; &#167;7.4、&#167;9 &#124;
&#124; runtime-architecture &#124; ## 8. 自检：对照 &#96;task.md&#96; &#167;8 十条 &#124; &#167;1.3、&#167;8、&#167;9、&#167;10 &#124;
&#124; agent-dev-refact &#124; # AI 助手开发框架 &#124; &#167;0、&#167;0.3、&#167;13；保留面向新参与者的单文入口，不继承历史稿的优先效力声明。 &#124;
&#124; agent-dev-refact &#124; ## 0. 读这份文档之前 &#124; &#167;0.1、&#167;0.3、&#167;13；阅读路径与术语已在正文。 &#124;
&#124; agent-dev-refact &#124; ### 0.1 它管什么，不管什么 &#124; &#167;0.1；保持架构、规则、任务、进度的职责分工。 &#124;
&#124; agent-dev-refact &#124; ### 0.2 前置阅读 &#124; &#167;0.3、&#167;5.8；开发操作无需 archive，具体代码改动仍核现行合同和硬约束。 &#124;
&#124; agent-dev-refact &#124; ### 0.3 二十二个词，一句话一个 &#124; &#167;13；补七对象及 Profile、来源等级、等效、登记/路由两集合；不复刻第二套内核定义。 &#124;
&#124; agent-dev-refact &#124; ### 0.4 编号索引 &#124; &#167;0.3、&#167;13；H/T/E 编号索引保留，废弃路线编号改用 &#167;7.1 G0–G5。 &#124;
&#124; agent-dev-refact &#124; ## 1. 我们在建什么 &#124; &#167;0、&#167;1、&#167;2；保留一个产品运行时与开发投影。 &#124;
&#124; agent-dev-refact &#124; ### 1.1 三层：什么租、什么建 &#124; &#167;2.6、&#167;2.8；纪律自建、编排用库、执行 loop 租用。 &#124;
&#124; agent-dev-refact &#124; ### 1.2 六条设计原则 &#124; &#167;1.6–&#167;1.7；补 P6 与控制面可被复核的要求。 &#124;
&#124; agent-dev-refact &#124; ### 1.3 先看六条已经被证伪的设计 &#124; &#167;8.1、&#167;8.3；保留六项证伪教训，不采用“凭据即批准”“当前无需边界”的推论。 &#124;
&#124; agent-dev-refact &#124; ## 2. 系统：一个运行时 &#124; &#167;2；结构总览已有正文。 &#124;
&#124; agent-dev-refact &#124; ### 2.1 只有一个运行时，开发是它的第一个 Task Profile &#124; &#167;0、&#167;1.1、&#167;3.3；不将场景性的 Attempt 完成判断提升为全产品充要条件（&#167;8.3）。 &#124;
&#124; agent-dev-refact &#124; #### 运行时由什么组成 &#124; &#167;2.1；四组件与两适配层，不让 orchestrator 变为自由 Agent。 &#124;
&#124; agent-dev-refact &#124; #### 路由：模型只建议，规则表才决定 &#124; &#167;2.1、&#167;2.5；模型只提供证据、三值路由、命中理由/策略落账。 &#124;
&#124; agent-dev-refact &#124; ### 2.2 开发 Task Profile：&#96;dev.change&#96; &#124; &#167;2.3–&#167;2.4；保留开发契约字段，采用 dev.change/1，隐私不直接写“无”。 &#124;
&#124; agent-dev-refact &#124; #### 2.2.1 工单：一个冻结的 Artifact，一次确认 &#124; &#167;2.4、&#167;3.1；冻结 Artifact、proposal/effective/delta、开工触点分档。 &#124;
&#124; agent-dev-refact &#124; #### 2.2.2 T0 怎么做到「开工前零触点」而不是把关卡默认掉 &#124; &#167;3.1；窄包、两道门、无自然语言假门禁；不采用已批准包可以免 H5 的外推。 &#124;
&#124; agent-dev-refact &#124; #### 2.2.3 产物 → 状态机：每个内核状态都有落点 &#124; &#167;3.3；保留 Artifact 与状态分离及终态语义，按内核补拒绝/取消，不照抄错误简写边。 &#124;
&#124; agent-dev-refact &#124; ### 2.3 执行者：Agent Profile &#124; &#167;2.3、&#167;2.12、&#167;3.20；能力登记和路由集分开，补身份命令失败处理；旧表仅历史示例。 &#124;
&#124; agent-dev-refact &#124; ### 2.4 可观测粒度：三个字段，四档 &#124; &#167;5.1；三个正交字段、四档观测，不把自报事件变为强制证据。 &#124;
&#124; agent-dev-refact &#124; ### 2.5 证据等级：能看多细，决定能不能信 &#124; &#167;5.2、&#167;5.12；最低来源上限、重算和空集合 UNKNOWN。 &#124;
&#124; agent-dev-refact &#124; ### 2.6 人：principal 与八条权力 &#124; &#167;4.1–&#167;4.2；人是 requester/principal，持权不能由执行能力推导。 &#124;
&#124; agent-dev-refact &#124; #### 人不是执行者 &#124; &#167;2.11、&#167;4.1、&#167;4.3；人的内容以 Artifact/响应进入，不登记为产品执行器。 &#124;
&#124; agent-dev-refact &#124; #### 权力表 &#124; &#167;4.2、&#167;4.4；H1–H8 与强制点保留；不继承“所有者动作本身就足够可信”的简化。 &#124;
&#124; agent-dev-refact &#124; #### 推翻一件已经做完的事，落点是新 Task，不是问询 &#124; &#167;1.1、&#167;4.3；终态不可重开，推翻终态结果建 supersedes 新 Task。 &#124;
&#124; agent-dev-refact &#124; #### 无默认的字段不得预填 &#124; &#167;4.12；批准对象、字段分级、通知/收件箱分离；proposal 可展示，未决定 effective 为空。 &#124;
&#124; agent-dev-refact &#124; #### 当前最尖锐的矛盾：这道关卡的证据强度是零 &#124; &#167;4.4、&#167;5.2、&#167;7.2；共享身份记录仅 reported，服务化不自动提升身份归因。 &#124;
&#124; agent-dev-refact &#124; ### 2.7 中断与恢复：用库的原语，不自造协议 &#124; &#167;4.3；补按问询类型分层、人写 Artifact 的归属；不采用按作者类型强制换 Attempt。 &#124;
&#124; agent-dev-refact &#124; ### 2.8 工作区供给 &#124; &#167;3.2、&#167;3.10、&#167;3.20；独占/干净/基线、多仓与人的未提交改动。 &#124;
&#124; agent-dev-refact &#124; #### 工作区形态决定执行者能不能自己落账（2026-09-07 实测） &#124; &#167;3.20；保留私有 clone 与 Git 可写根的双条件实验及代提交退路，标历史未复跑。 &#124;
&#124; agent-dev-refact &#124; ### 2.9 边界：哪些强制点是真的 &#124; &#167;4.4、&#167;8.3；保留真实动作路径原则，排除无边界与授权即批准结论。 &#124;
&#124; agent-dev-refact &#124; #### 一条实测结论 &#124; &#167;4.4、&#167;5.13；宿主提权/凭据域是历史环境观测，不泛化当前全部进程。 &#124;
&#124; agent-dev-refact &#124; #### 但当前不需要建任何边界 &#124; 不采用：&#167;8.3；未经过某套边界只证该方案无效，不证 H5 或安全边界不需要。 &#124;
&#124; agent-dev-refact &#124; #### 真正的风险不是伪造，是只有一份 &#124; 部分保留：&#167;3.16、&#167;7.4 风险 21；单机丢失风险须重核，不能据此自动 push 或压过授权风险。 &#124;
&#124; agent-dev-refact &#124; #### 什么时候边界才需要建 &#124; 部分保留：&#167;4.4、&#167;7.2；服务化、多主体、外部审计需要复核边界，不能当成此前免除边界的条件。 &#124;
&#124; agent-dev-refact &#124; #### 但威胁模型要留着，因为它是对的 &#124; &#167;4.4、&#167;4.12；伪造肯定、绕过副作用、工作站 agent 代批三种威胁与误签残余。 &#124;
&#124; agent-dev-refact &#124; #### 取证纪律：取证工具自己也有边界 &#124; &#167;5.13；主机/身份/namespace、同实际环境复核；卫生检查不是强制点。 &#124;
&#124; agent-dev-refact &#124; ### 2.10 角色：五个各有定义的词 &#124; &#167;2.1–&#167;2.2；职责与角色分开；登记 roles_allowed 由分发门执行。 &#124;
&#124; agent-dev-refact &#124; #### 为什么一直在长同名物 &#124; &#167;0.0、&#167;1.7；用动作、权力、强制点回答问题，不靠再造 supervisor 名称。 &#124;
&#124; agent-dev-refact &#124; ## 3. 流程：一轮怎么走 &#124; &#167;3；操作路径进入现行正文。 &#124;
&#124; agent-dev-refact &#124; ### 3.1 档位：这件事该走多重的流程 &#124; &#167;2.5、&#167;3.4；沿用基座风险判据，不采用以“问题已定”自行给权威文件降档。 &#124;
&#124; agent-dev-refact &#124; ### 3.2 任何档位都不能省的三条 &#124; &#167;3.1、&#167;3.4、&#167;5.5；冻结标准、独立验收、不可逆批准三条不因档位消失。 &#124;
&#124; agent-dev-refact &#124; ### 3.3 裁量权与方向不对称 &#124; &#167;1.6、&#167;4.8；裁量保留理由、方向与改判记录。 &#124;
&#124; agent-dev-refact &#124; #### 不可裁量的下限 &#124; &#167;1.7、&#167;3.1、&#167;4.2；设计核前提与不可单方放松底线。 &#124;
&#124; agent-dev-refact &#124; #### 方向不对称 &#124; &#167;1.6–&#167;1.7、&#167;3.22；升严谨不突破预算，省事方向须批准。 &#124;
&#124; agent-dev-refact &#124; #### 裁量是规则的孵化器 &#124; &#167;1.7、&#167;7.4 风险 15；重复裁量反馈规则，不能静默覆盖政策。 &#124;
&#124; agent-dev-refact &#124; ### 3.4 七个环节（T2 专用） &#124; &#167;3.19；七环节、来源异议、验收算法与人确认；按现行协议补齐并列处理。 &#124;
&#124; agent-dev-refact &#124; ### 3.5 产物、路径与命名 &#124; &#167;3.19；按当前协议统一 reviews 子目录，不恢复旧稿平铺路径。 &#124;
&#124; agent-dev-refact &#124; #### 环节通知：组织者的产物，不是发起人的话术 &#124; &#167;3.21；通知含取件、对象事实、范围、交付与截止，不在阶段中偷偷换输入。 &#124;
&#124; agent-dev-refact &#124; ### 3.6 取件与检视面 &#124; &#167;3.21；冻结 commit 取件，分支只定位，不用可变分支头当对象。 &#124;
&#124; agent-dev-refact &#124; #### 检视面：需要人读时开临时 worktree &#124; &#167;3.21；确认前准备实际可读的冻结对象，临时 worktree 有归属与清理条件。 &#124;
&#124; agent-dev-refact &#124; ### 3.7 环节判定与判据自身的质量 &#124; &#167;3.18、&#167;5.12；产物反推及判据覆盖声明。 &#124;
&#124; agent-dev-refact &#124; #### 判据自身的质量：覆盖不全比没有更危险 &#124; &#167;5.12、&#167;12.1；UNKNOWN、空集、空标题、吞退出码与窄覆盖假通过。 &#124;
&#124; agent-dev-refact &#124; ### 3.8 逐环节的规则 &#124; &#167;3.19、&#167;4.12；互评四块、处置表、异议与持久确认；不把执行者填“是”升为可信身份。 &#124;
&#124; agent-dev-refact &#124; ### 3.9 停止、超时与回退 &#124; &#167;3.22；三处回退与次数上限，观察窗不足不可硬判。 &#124;
&#124; agent-dev-refact &#124; ### 3.10 清理与发布 &#124; &#167;3.15–&#167;3.16、&#167;3.19；按现行保留条件先存证再清理发布，不一律按旧稿删/归档。 &#124;
&#124; agent-dev-refact &#124; ### 3.11 验证分层：谁判什么，顺序不可换 &#124; &#167;5.5、&#167;3.19；保留 L0–L3 分工，明确 L2 来源异议先于⑤的 L1，数字不是时序。 &#124;
&#124; agent-dev-refact &#124; ### 3.12 状态判定与分发脚本的设计要点 &#124; &#167;3.18；补执行事件、人工桥接与“生成命令不等于执行”。 &#124;
&#124; agent-dev-refact &#124; ### 3.13 文档的删除条件 &#124; &#167;7.3；升级为五稿正文覆盖与可读性条件，不把仅五条旧门当完整删除授权。 &#124;
&#124; agent-dev-refact &#124; ## 4. 什么时候不该走这套流程 &#124; &#167;6；成本与风险分开，承认绕过观察不完备。 &#124;
&#124; agent-dev-refact &#124; ### 4.1 机械可判的分类 &#124; &#167;6.1；只从可判字段判断收益，不从 tier 倒推成本。 &#124;
&#124; agent-dev-refact &#124; ### 4.2 三类走流程反而更贵的活 &#124; &#167;6.2；三类成本反例保留，manual 的结论限定小任务。 &#124;
&#124; agent-dev-refact &#124; ### 4.3 最轻档位的开销上界 &#124; &#167;6.2；四维上界与人的实际动作数，不隐去敲命令/传输成本。 &#124;
&#124; agent-dev-refact &#124; ### 4.4 绕过看得见吗 &#124; &#167;6.3；补各 sink 覆盖与不可见面，追认仍须核 I1，不能伪造事前批准。 &#124;
&#124; agent-dev-refact &#124; ## 5. 实测记录 &#124; &#167;5.11、&#167;12.1–&#167;12.2；保留历史失败机制，不把旧稿“全是实测”搬成本次证明。 &#124;
&#124; agent-dev-refact &#124; ### 5.1 手工模式看起来在跑，轨迹却基本不可复原 &#124; &#167;5.11、&#167;4.12；23 条轨迹与对照已在；人的决定须有独立对象/来源，不只让被决定方转述。 &#124;
&#124; agent-dev-refact &#124; ### 5.2 判据给假答案：七次 &#124; &#167;12.1、&#167;5.12；七类假答案完整进入正文，历史次数不当当前统计。 &#124;
&#124; agent-dev-refact &#124; ### 5.3 未经现状核查的设计：六条 &#124; &#167;8.1、&#167;1.7、&#167;12.2；先验真实前提，不只验方案自洽性。 &#124;
&#124; agent-dev-refact &#124; ### 5.4 并行竞争评比的边界 &#124; &#167;12.2、&#167;1.7；外部对照与必要性检查保留，不预定至少删一项；缺列输入不能事后扣分。 &#124;
&#124; agent-dev-refact &#124; ### 5.5 一条元观察 &#124; &#167;1.7、&#167;12.2；控制面也需留痕、复算与被推翻；不移植未经本次核对的责任计数。 &#124;
&#124; agent-dev-refact &#124; ## 6. 实施路线 &#124; 部分保留：&#167;7.1–&#167;7.2、&#167;7.7；以 G0–G5 替代旧 R/S 排期，不改当前进度。 &#124;
&#124; agent-dev-refact &#124; #### 脚手架什么时候可以拆 &#124; &#167;7.2；补组件级等效、三轮验收对照、每路 Attempt 与身份前置；不把 Git 当事务/租约证明。 &#124;
&#124; agent-dev-refact &#124; #### 等效判据：拿什么证明「换了实现，还是同一套东西」 &#124; &#167;5.3；S/R、投影、来源、上下文和差异白名单已完整。 &#124;
&#124; agent-dev-refact &#124; #### 要改内核时，工作单元长什么样 &#124; &#167;7.7；补修订工作单元及不将 consumed 回填为 approved 的迁移纪律。 &#124;
&#124; agent-dev-refact &#124; ### 6.1 已登记的未决项 &#124; &#167;7.4；相容风险保留并补单机副本/库 API 范围；不保留立即 push 等未授权动作建议。 &#124;
&#124; agent-dev-refact &#124; ## 7. 覆盖声明、盲区与未验证 &#124; &#167;9.5、&#167;5.13、&#167;7.6；原作者核验范围保留其历史身份，不成为本次已运行验证。 &#124;
&#124; archive-README &#124; # &#96;archive/&#96; —— 一条谱系的历史稿 &#124; &#167;0 的版本声明、&#167;9.5、&#167;10；保留一条谱系的来源身份，不是第二套开发规范。 &#124;
&#124; archive-README &#124; ## 演变轨迹 &#124; &#167;9.5；两 lifecycle→refact-fable→runtime→兄弟分叉，之后直接补吸收；不再要求读图才能执行。 &#124;
&#124; archive-README &#124; ## 两格：已结清 / 待结清 &#124; &#167;10；已落点与待处置转换为每标题明确处置，不继续沿用旧甲乙格状态。 &#124;
&#124; archive-README &#124; ### 甲、已结清 —— 有逐节落点收据 &#124; &#167;10；四稿旧 182 行扩为完整层级索引，正文仍须复核。 &#124;
&#124; archive-README &#124; ### 乙、待结清 —— **无收据，剩 76 节** &#124; &#167;10 的 agent-dev-refact 76 行；本次已逐节处置，不把“待吸收”保留成现状。 &#124;
&#124; archive-README &#124; ## 一处欠账：承诺过的映射表从未产出 &#124; &#167;5.12、&#167;7.3、&#167;9.5；保留“映射承诺未进验收导致丢内容”的教训；不把历史缺表说成本次仍缺表。 &#124;
&#124; archive-README &#124; ## 本目录不能删 —— 这是一条可判的条件，不是态度 &#124; &#167;7.3；未验正文不能删与可证伪性保留；日常内容必须有无需翻历史的落点。 &#124;
&#124; archive-README &#124; ## 现在可以删了吗 &#124; &#167;7.3、&#167;9.5；本次只移入相容内容，不声明其他删除门已过，也不实施删除。 &#124;
&#124; archive-README &#124; ## 归档件怎么用 &#124; &#167;0.1、&#167;5.13；历史无规范效力、注明来源与版本；不修改他人历史文件。 &#124;
&#124; archive-README &#124; ## 引用它们的锚点 &#124; &#167;5.12–&#167;5.13、&#167;7.3；Markdown 与裸行号锚分别检查，历史软判不等于已验证。 &#124;

</pre>

### records/migration-context.md（R）

旧文标题、前言、目录与阅读路线属于旧排布的上下文；保留它们让源文件能完整重建，禁止它们继续指挥新入口。

| 内部栏目（顺序即阅读顺序） | 准入与排除条件 | 实际单元 |
| --- | --- | --- |
| 旧 guide 结构上下文 | 旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。 | G-001, G-005, G-006, G-015, G-028, G-051, G-065, G-079, G-083 |
| 旧入口上下文 | 旧计划/交接前言及 README 旧索引原文留证；新的入口由装配配方生成。 | D-001, I-001, H-001, M-001, M-002 |

#### 旧 guide 结构上下文

**G-001** · 源 agent-dev-guide.md，L1–L22；SHA-256 390918bc145a376746f0eebd929e1b74260a6fe874e567cdabc4c699a69a18b4

<pre data-unit="G-001"># Agent 开发指导：一个产品运行时，一套开发纪律

&gt; **底稿**：&#96;runtime-refact&#96; 轮定稿（基座作者 luna，2026-09-06）｜ 裁决方 opus 吸收 11 条
&gt; **扩充一**：2026-09-07 opus 吸收两份 lifecycle 共 118 节，并逐节抽查出 50 处真缺、2 处落点判错
&gt; **扩充二**：2026-09-08 **luna** 再吸收，以上一版 2402 行（k8s &#96;d9f827f8&#96;）为底稿，
&gt; 对照同一快照下 &#96;archive/&#96; 五份历史正文与 README 补入相容内容，**并把 &#96;agent-dev-refact.md&#96;
&gt; 的 76 节首次落点**。&#167;10 由 182 行扩为 **294 行**（284 源节 + 10 README）。
&gt;
&gt; ⚠ **2026-09-08 由所有者裁定，本版取代前一版**（原文件名 &#96;agent-dev-guide-gpt6.md&#96;，
&gt; 已改名为 &#96;agent-dev-guide.md&#96;）。取代前 opus 做的核验、以及**没做**的部分，见 &#167;9.6。
&gt; ⚠ **本文写作时的自述「不替换原 guide」已被该裁定取代**——保留此注是为了让
&gt; &#167;9.5 的记录仍可按成文时状态读。
&gt;
&gt; **阅读目标：日常开发不必再回 archive 拼接规则。**新增内容进入相应正文；
&gt; &#167;10 保存五稿 284 个标题与 README 10 个标题的处置索引，查沿革时才需阅读。
&gt; 产品合同、代码硬约束和协作协议仍各有权威来源（&#167;0.1）；本文提供开发操作入口，
&gt; 不以历史稿覆盖它们，也不把旧稿里与底稿抵触的判断带回来。
&gt;
&gt; **证据时间边界：**继承的 SDK、部署、权限、测试与事故读数是各源作者在其钉定版本下的记录，
&gt; 不是本次重新实测的结果。正文的“当前”“已核对”“本轮”须连同原版本和 &#167;9 的作者/时间读；
&gt; 用于新开发决策时按 &#167;5.13 重新核验。此次文档补写的范围、取舍与验证见 &#167;9.5。

</pre>

**G-005** · 源 agent-dev-guide.md，L87–L105；SHA-256 f1702dee9a38fff185c71aca821865bbbdd21126c60c133c0c28db989af0fbea

<pre data-unit="G-005">### 0.2 为什么分成这些章

&#124; 章 &#124; 独立存在的理由 &#124;
&#124; --- &#124; --- &#124;
&#124; &#167;1 契约与边界 &#124; 属权威约束，变更门槛高于实现结构，不能埋进组件说明 &#124;
&#124; &#167;2 运行时结构 &#124; 回答“谁负责什么”，不掺一次 Task 的时间顺序 &#124;
&#124; &#167;3 开发执行 &#124; 回答“一次请求怎样走”，可直接给开发者照做 &#124;
&#124; &#167;4 人介入与权限 &#124; 涉及身份和不可逆动作，必须从普通控制流中单列审计 &#124;
&#124; &#167;5 证据与等效 &#124; 决定哪些事实能信，不能与“流程跑完”混为一谈 &#124;
&#124; &#167;6 成本与绕过 &#124; 决定何时值得进入运行时，指标与正确性判据不同 &#124;
&#124; &#167;7 演进路线 &#124; 只写依赖顺序和退出条件，避免现状污染目标结构 &#124;
&#124; &#167;8 核查裁定 &#124; 保存本轮推翻旧设计的证据，防止同一错误复活 &#124;
&#124; &#167;9 覆盖声明 &#124; 让读者知道本文证据边界，不能散在各章脚注里 &#124;
&#124; &#167;10 逐节落点 &#124; 五份历史正文及目录说明的处置索引；标题齐全仍须结合正文核实 &#124;
&#124; &#167;11 反模式 &#124; 机制描述，与 &#167;8「已被推翻的设计」不同：前者是任何项目都会踩的做法 &#124;
&#124; &#167;12 失败实例 &#124; 本项目**实际**踩过的，按证据强度分三级；与 &#167;11 分开，防止把「机制上必然」写成「此处已核对」 &#124;
&#124; &#167;13 词汇对照 &#124; 内核对象名与本文用语的映射，独立成表才能被机械核 &#124;
&#124; &#167;14 Task 模板 &#124; 持久记录的最小字段集；空栏必须写「不适用」及理由 &#124;

</pre>

**G-006** · 源 agent-dev-guide.md，L106–L125；SHA-256 38acb4925ce92c7f030b712b222c3deb1b1064bb996995fd771c314c4f86ad5b

<pre data-unit="G-006">### 0.3 按工作阶段阅读，不按历史版本阅读

第一次读，先看本章的一条执行链、&#167;1 的约束与 &#167;13 的词汇。随后按下表定位，
不必先读迁移过程和历史稿。**默认只运行本次任务已授权且适用的动作；本文介绍并行轮次，
不代表每个开发请求都要开轮或自动增加参与方。**

&#124; 你现在要做什么 &#124; 本文入口 &#124; 动作结束时应留下什么 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; 接任务、定边界 &#124; &#167;2.4、&#167;3.1、&#167;3.4、&#167;14 &#124; 原话、冻结工单、风险档位、独立验收要求 &#124;
&#124; 确定架构或接执行器 &#124; &#167;1.7、&#167;2.6–&#167;2.10 &#124; 真实前提、SDK 能力三态、部署门禁与退路 &#124;
&#124; 开始写文件 &#124; &#167;3.2、&#167;3.10、&#167;3.20 &#124; 独占工作区、基线、manifest、明确的 Git 写入权限 &#124;
&#124; 单路实施或组织并行 &#124; &#167;2.11、&#167;3.13、&#167;3.19–&#167;3.22 &#124; 每个 Work Unit 的结果、冻结对象与处置记录 &#124;
&#124; 等人、暂停、取消或恢复 &#124; &#167;4、&#167;7.5 &#124; 绑定具体对象的 Interaction、checkpoint、副作用账 &#124;
&#124; 验收、发布与清理 &#124; &#167;3.12、&#167;3.15–&#167;3.16、&#167;5.5 &#124; 最终固定版本的证据、批准、可重取交付与清理记录 &#124;
&#124; 遇到规则冲突或准备删旧稿 &#124; &#167;7.3、&#167;7.7、&#167;8、&#167;10 &#124; 冲突裁定、迁移落点和仍未验证的事项 &#124;

一次性探索阅读按 &#167;6 判断流程成本；没有文件产出时，不为形式统一造空仓。
涉及具体产品字段、生产现状、契约测试时，仍须回读对应代码与现行合同（&#167;5.8）；
“只读一份开发指南”不等于“只读指南就能证明代码正确”。

</pre>

**G-015** · 源 agent-dev-guide.md，L235–L236；SHA-256 9350e03d2bf45b7f600fbd9be1a44ef63d6fd61c9cf6fe21cc5ad50bbfd262e9

<pre data-unit="G-015">## 2. 一个运行时的结构

</pre>

**G-028** · 源 agent-dev-guide.md，L649–L650；SHA-256 7f1c8bb4a72ff2a2e3fff986199e95eab3dcadd3676deb3240b564416f37167c

<pre data-unit="G-028">## 3. 一次开发 Task 怎样执行

</pre>

**G-051** · 源 agent-dev-guide.md，L1247–L1248；SHA-256 dfbdc82a34658ab40f4b2fb509d6b1ca23a90a8691af32b189c8b1861f3623b8

<pre data-unit="G-051">## 4. 人介入、Interaction 与权力

</pre>

**G-065** · 源 agent-dev-guide.md，L1629–L1630；SHA-256 a9069639a2d30d430a4be7c39b03a699f022144fc529cc3b9e710075c4a99818

<pre data-unit="G-065">## 5. 可观测性、证据与等效

</pre>

**G-079** · 源 agent-dev-guide.md，L1930–L1931；SHA-256 0ee39124c7630ca61df3c9620bfef940eb5c5f2ef80afc346e09cdf85147fb9e

<pre data-unit="G-079">## 6. 什么时候运行时值得用

</pre>

**G-083** · 源 agent-dev-guide.md，L1986–L1987；SHA-256 0b006e66bc53d36fcbc4adb5d25384e7cda2be4893d8270584b37425da7351e6

<pre data-unit="G-083">## 7. 演进与退出脚手架

</pre>

#### 旧入口上下文

**D-001** · 源 development-plan.md，L1–L9；SHA-256 8055b3106ed9b6550da0058d9cb9e81602aa43eaf9196b023e2f6b15aef1b2a0

<pre data-unit="D-001"># 开发计划

&gt; 最后更新：2026-08-29
&gt;
&gt; **这里回答&quot;要建什么、为什么这么建&quot;。**
&gt; 具体任务见 &#91;&#96;implementation-plan.md&#96;](implementation-plan.md)，
&gt; 当前状态见 &#91;&#96;handoff.md&#96;](handoff.md)，
&gt; 代码必须符合的规则见 &#91;&#96;constraints.md&#96;](constraints.md)。

</pre>

**I-001** · 源 implementation-plan.md，L1–L10；SHA-256 a3210412c57feae15e4f023caeac2a2057775c8b4f3e1a420070aa7c16bf8ffc

<pre data-unit="I-001"># 实施计划

&gt; 最后更新：2026-08-29
&gt;
&gt; **这里是任务本体：每件事怎么做、怎么算做完。**
&gt;
&gt; 现在到哪了、什么不能倒退，见 &#91;&#96;handoff.md&#96;](handoff.md)；
&gt; 为什么这么建见 &#91;&#96;development-plan.md&#96;](development-plan.md)；
&gt; 代码必须符合的规则见 &#91;&#96;constraints.md&#96;](constraints.md)。

</pre>

**H-001** · 源 handoff.md，L1–L13；SHA-256 1bea42449cbe09fa22c0db47a2d321f78757b6aba3cea997dcb1931d500fd58c

<pre data-unit="H-001"># 交接

&gt; 最后更新：2026-08-29
&gt;
&gt; **接手先读这份。**它回答&quot;现在到哪了、什么不能倒退、卡在哪&quot;。
&gt;
&gt; 要建什么见 &#91;&#96;development-plan.md&#96;](development-plan.md)；
&gt; 具体任务见 &#91;&#96;implementation-plan.md&#96;](implementation-plan.md)；
&gt; 代码必须符合的规则见 &#91;&#96;constraints.md&#96;](constraints.md)。
&gt;
&gt; **本文件只写状态。**任何&quot;应该怎样&quot;的论证不写在这里，
&gt; 任何任务的实施步骤也不写在这里。

</pre>

**M-001** · 源 README.md，L1–L24；SHA-256 b740e86ba1173c4df5acba1aa3e5a9648a8ba14831fabd34b8a777c1c2dba2d6

<pre data-unit="M-001"># dev-plan — 代码要符合什么、接下来建什么

&gt; 最后更新：2026-08-29

本目录管**开发**。判据是：**改了这里的东西，代码要跟着改。**

项目现在长什么样在 &#91;&#96;../project-guide/&#96;](../project-guide/)（那里改了，
只说明代码先变了）；我们怎么共事在 &#91;&#96;working/&#96;](working/)（那里改了，
代码不用动）。

&#124; 文件 &#124; 内容 &#124; 什么时候读 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#91;&#96;constraints.md&#96;](constraints.md) &#124; **代码必须符合的规则**，39 条按数据/契约/身份/拓扑/发布/智能体分组，每条标注谁在执行 &#124; **动代码前** &#124;
&#124; &#91;&#96;development-plan.md&#96;](development-plan.md) &#124; 要建什么、为什么这么建：起点、智能体通用/专用两分、四本账、执行层租用、三个阶段 &#124; 想知道方向时 &#124;
&#124; &#91;&#96;implementation-plan.md&#96;](implementation-plan.md) &#124; **任务本体**：每件事怎么做、怎么算做完。条目格式、测试层次、交付规则 &#124; 要动手时 &#124;
&#124; &#91;&#96;handoff.md&#96;](handoff.md) &#124; **状态与交接**：当前阶段、已就位的、未决项 U1–U5、不能倒退的输入 &#124; 接手时先读 &#124;
&#124; &#96;~/codex-reference-archive/&#96; &#124; **各助手的历史调研材料**（仓外，按助手分目录：&#96;cursor/&#96; &#96;kimi/&#96; &#96;luna/&#96; &#96;opus/&#96; &#96;qwen3.8/&#96;）：Codex 机制、SQLBot、WrenAI、沙箱、现状诊断。**已归档，可直接读**——不再是提案期的独立材料，引用时注明是谁的稿 &#124; 定 U1–U5 时 &#124;
&#124; &#91;&#96;agent-dev-guide.md&#96;](agent-dev-guide.md) &#124; **现行开发规范，这条谱系唯一的活文档**：不可变契约、运行时结构与**执行层/SDK 适配**、Task 执行与**并发处置**、人介入/权力表/**三道门与四档审批**、证据与等效、成本与绕过、演进路线、**反模式与失败实例**、词汇对照、Task 模板。&#167;10 是四份源稿的逐节落点表（182 行） &#124; 想知道系统怎么搭、怎么干活时 &#124;
&#124; &#91;&#96;archive/&#96;](archive/) &#124; **一条谱系的历史稿**：两份 lifecycle → &#96;refact-fable&#96; → &#96;runtime-architecture&#96; → 分叉为 &#96;agent-dev-refact&#96; 与现行的 &#96;agent-dev-guide&#96;。分两格——甲格已有逐节落点收据，乙格 197 节**还没有**，待 &#96;dev-plan-refact&#96; 轮并入。无规范效力 &#124; 追溯来龙去脉时；&#96;archive/README.md&#96; 有轨迹图 &#124;
&#124; &#91;&#96;protocol/&#96;](protocol/) &#124; **流程规范 + 它的实现，放在一起**：&#96;round-protocol.md&#96;（七环节、档位 T0/T1/T2、裁量权与方向不对称、产物落点、环节判定、立判据的人怎么约束自己）与 &#96;round-status.py&#96; / &#96;round-dispatch.py&#96; / &#96;agents.toml&#96; &#124; 开一轮多家并行出稿前；跑流程脚本前 &#124;
&#124; &#91;&#96;anchor-gate.py&#96;](anchor-gate.py) &#124; **锚点门禁**：&#96;doc-gate&#96; 只查 markdown 链接，查不到 &#96;&#96; &#96;文件.md:行&#96; &#96;&#96; 这类纯文本锚点——实测删掉被引文件后 &#96;doc-gate --all&#96; 仍报通过。本脚本补这一类：钉 commit 的锚在该 commit 内解析、裸路径锚对当前索引与外部取证仓解析、&#96;rounds/**&#96; 按归档软判 &#124; 删或改被引用的文档前 &#124;
&#124; &#91;&#96;scripts/check-no-owner-creds.sh&#96;](scripts/check-no-owner-creds.sh) &#124; **凭据卫生检查**（不是边界——本机 agent 可 &#96;sudo&#96;，能改它）：扫明文凭据、无口令 key、主仓是否对本机可写、提权面 &#124; 边界变更前后 &#124;
&#124; &#91;&#96;doc-gate.py&#96;](doc-gate.py) &#124; **文档不变量门禁**：仓内链接、章节引用、表格列数。由 &#96;.githooks/pre-commit&#96; 自动触发，不需要谁记得跑；&#96;--survey&#96; 巡检全仓、&#96;--selfcheck&#96; 查是否已安装 &#124; 不用主动读；提交文档时它自己会说话 &#124;

</pre>

**M-002** · 源 README.md，L25–L36；SHA-256 8f6f58fa2d02b9cbdd881b09f43e91e2b806e719ba730edd070f19b88b5137e7

<pre data-unit="M-002">## 各文档的分工，别混写

&#124; &#124; 写什么 &#124; 不写什么 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;constraints.md&#96; &#124; 必须遵守的 &#124; 现状、计划 &#124;
&#124; &#96;agent-dev-guide.md&#96; &#124; **架构与开发纪律：怎么搭、怎么干、为什么** &#124; 任务清单、进度 &#124;
&#124; &#96;development-plan.md&#96; &#124; 目标与理由 &#124; 进度、任务 &#124;
&#124; &#96;implementation-plan.md&#96; &#124; 任务：怎么做、怎么算做完 &#124; 状态叙述、架构论证 &#124;
&#124; &#96;handoff.md&#96; &#124; **状态**：做到哪、卡在哪、什么不能倒退 &#124; 论证与实施步骤 &#124;

混写的后果是具体的：论证和状态放一起，读计划的被状态打断，查进度的要翻过论证；
规则和计划放一起，两边都不好用。
</pre>

## 决定包：26 个全局 ID 与完整上下文

| 全局 ID | 原文件 | 源行 |
| --- | --- | --- |
| round/refact-fable/R1 | rounds/refact-fable/rulings.md | L9 |
| round/refact-fable/R2 | rounds/refact-fable/rulings.md | L10 |
| round/refact-fable/R3 | rounds/refact-fable/rulings.md | L11 |
| round/refact-fable/R4 | rounds/refact-fable/rulings.md | L12 |
| round/refact-fable/R5 | rounds/refact-fable/rulings.md | L13 |
| round/refact-fable/R6 | rounds/refact-fable/rulings.md | L14 |
| round/refact-fable/R7 | rounds/refact-fable/rulings.md | L15 |
| round/refact-fable/R8 | rounds/refact-fable/rulings.md | L16 |
| round/refact-fable/R9 | rounds/refact-fable/rulings.md | L17 |
| round/runtime/R1 | rounds/runtime/rulings.md | L13 |
| round/runtime/R2 | rounds/runtime/rulings.md | L14 |
| round/runtime/R3 | rounds/runtime/rulings.md | L15 |
| round/runtime/R4 | rounds/runtime/rulings.md | L16 |
| round/runtime/R5 | rounds/runtime/rulings.md | L17 |
| round/runtime/R6 | rounds/runtime/rulings.md | L18 |
| round/runtime-refact/R1 | rounds/runtime-refact/rulings.md | L12 |
| round/runtime-refact/R2 | rounds/runtime-refact/rulings.md | L13 |
| round/runtime-refact/R3 | rounds/runtime-refact/rulings.md | L14 |
| round/runtime-refact/R4 | rounds/runtime-refact/rulings.md | L15 |
| round/runtime-refact/R5 | rounds/runtime-refact/rulings.md | L16 |
| round/runtime-refact/R6 | rounds/runtime-refact/rulings.md | L17 |
| round/runtime-refact/R7 | rounds/runtime-refact/rulings.md | L18 |
| round/runtime-refact/R8 | rounds/runtime-refact/rulings.md | L19 |
| round/runtime-refact/R9 | rounds/runtime-refact/rulings.md | L20 |
| round/runtime-refact/R10 | rounds/runtime-refact/rulings.md | L21 |
| round/runtime-refact/R11 | rounds/runtime-refact/rulings.md | L22 |

以下全文包括表外更正；不能只提取表行再声称决定可检索。

### rounds/refact-fable/rulings.md

<pre data-ruling="rounds/refact-fable/rulings.md"># 裁定记录：refact-fable（开发框架重构方案）

&gt; 本目录记录方案 &#96;refact-fable.md&#96; 自身的裁定。方案内 R0–R5 各自开轮，各有自己的 &#96;rounds/&lt;id&gt;/rulings.md&#96;。
&gt; 字段按 &#96;round-protocol.md&#96;「裁定记录」。**人确认 = 是** 的行，以所有者 commit 为生效时刻；commit 前本文件是草稿。
&gt; 冻结对象哈希：&#96;refact-fable.md&#96; sha256 前 16 位 &#96;89303624bfd9ef27&#96;（12:58 版，927 行）；commit 后可复算。

&#124; 编号 &#124; 事由 &#124; 依据 &#124; 处置 &#124; 方向 &#124; 人确认 &#124; 影响到谁 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;R1&#96; &#124; 冻结 &#96;refact-fable.md&#96; &#167;8 九条验收标准、3.1.1 状态映射表、3.13 威胁模型（H1） &#124; 五家终审全部同意冻结：&#96;reviews/review-final-opus.md&#96;「建议冻结 &#167;8，但先改一处取证错误」（已改，3.13.0）；&#96;reviews/review-final-cursor.md&#96;「骨架可以冻」（F1–F3 已改）；&#96;reviews/review-final-kimi.md&#96;「同意冻结 &#167;8」；&#96;reviews/review-final-qoder.md&#96;「条件通过」（C3 驳回有据，其余已吸收）；&#96;reviews/review-final-luna.md&#96; REQUEST CHANGES 于 12:49 撤销（终端记录：「12:40 版已落实全部阻断项，我撤销 REQUEST CHANGES，同意按 bootstrap 例外冻结 &#167;8 九条并启动 R0 / S1」）。逐条处置见 &#96;reviews/review-final-fable-response.md&#96; &#124; 三处进入 FROZEN；此后只能经 H6 改，改动追加于本文件不覆盖 &#124; 更严谨 &#124; **是** &#124; 全部后续轮（R0、R0′、S1、R1–R5）；五家执行者 &#124;
&#124; &#96;R2&#96; &#124; R1 的回执形态：回执仓尚未建成（S1 产物），本次冻结无法按 3.13 用回执仓签名回执 &#124; 3.13.3 的回执仓与 &#167;6 S1 互为前后：S1 要在 &#167;8 冻结后跑，回执仓在 S1 里建。这是 &#167;6 已登记的 &#96;bootstrap&#96; 情形 &#124; 本次 H1 回执 = 本文件 R1 行 + 所有者 commit；S1 建成回执仓后，所有者补一份 &#96;transitions: &#91;H1]&#96;、&#96;target_commit&#96; = 本 commit 的回执，把 bootstrap 例外收口 &#124; **更省事**（回执弱于 3.13 标准） &#124; **是** &#124; 本方案自身；S1 验收加「补签 R1 回执」一项 &#124;
&#124; &#96;R3&#96; &#124; T0 的 H1 与「开工前零触点」矛盾如何解（kimi D2 / qoder B2） &#124; fable 11:52 提出四选一之外的第四种：T0 验收条只能来自已签策略，H1 在策略签名时一次完成 &#124; 采纳第四种；12:40 版细化为命名任务类包（3.6）。所有者 11:56 裁定 &#124; 更严谨 &#124; **是** &#124; T0 口径；策略文件 &#96;policies/tier-defaults.toml&#96; &#124;
&#124; &#96;R4&#96; &#124; 私有仓 GitHub ruleset 需付费计划，签名回执信任锚选什么（kimi D1 / qoder B1） &#124; GitHub 官方文档「About rulesets」：私有仓需 Pro / Team / Enterprise；已核 &#124; 选「回执仓」：所有者名下独立仓，VM 只读。所有者 11:56 裁定；12:40 版按 luna C1 改为仓内签名 commit + yaml &#124; 更严谨 &#124; **是** &#124; 3.13、S1、R1 &#124;
&#124; &#96;R5&#96; &#124; H2/H3/H4/H6 回执是否全部改回执仓签名（cursor C1） &#124; 3.3 规则三「回执必须不可伪造」主语是全表；&#96;rulings.md&#96; 在工作仓 agent 可写 &#124; 全表锚定，H7「取消」为唯一例外（失败安全）。所有者 12:13 点头 &#124; 更严谨 &#124; **是** &#124; 权力表全部行；签名次数观察值 &#124;
&#124; &#96;R6&#96; &#124; T0「可逆出口」（免 H5）是否加入权力表（cursor D5） &#124; 无签名次数数据；留在 worktree 的成果无状态，堆积后批量 push 即绕过 H5 &#124; 本轮不加，登记 &#167;7-13；S1/R1 后看两周观察值再定。所有者 12:13 点头 &#124; 更严谨 &#124; **是** &#124; T0 &#124;
&#124; &#96;R7&#96; &#124; 主仓写权限是否移出 VM（luna C2 / opus &#167;3） &#124; 3.13.1：VM &#96;id_rsa&#96; 对主仓可写，agent 可绕过回执直接 push；VM 上 hook 与脚本可改，不是强制点 &#124; 移出：主仓对 VM 只读，agent 推候选仓，⑦ 由 Windows 在签 H5 同一会话执行。所有者 12:34 裁定「移」 &#124; 更严谨 &#124; **是** &#124; 3.13.2 ②、3.13.5、S1 ②、H5 强制点 &#124;
&#124; &#96;R8&#96; &#124; 往 &#96;round-protocol.md&#96; 补「机器可读块」是否算改协议（原 R0 旁注 / &#167;7-12） &#124; round-protocol「流程档位」：改协议命中权威层即 T2；按方向不对称，它朝严谨方向但仍是协议正文变更 &#124; 算改协议，拆出 R0′ 按 T2 开轮；R0 只改脚本。所有者 12:34 裁定「要」 &#124; 更严谨 &#124; **是** &#124; R0 范围；opus（R0 执行者） &#124;
&#124; &#96;R9&#96; &#124; R1 所冻结的三处对象在 &#96;runtime&#96; 轮前提下重新处置 &#124; 所有者 2026-09-05 指出「没有开发过程和产品运行时这两个 profile，只能有一个产品运行时」；&#96;refact-fable.md&#96; &#167;1.1 杀第三个 Profile 的论证（「五格全同…那是档位不是 Profile」）对 A/B 同样成立；内核 &#96;working/request-lifecycle.md:505&#96;「新增领域应新增 Task Profile 和相容 Agent Profile，不修改通用状态语义」与 &#96;:580&#96; 反模式表 &#124; &#167;8：七条留、**第 7 条作废**、第 3 条改归因、第 4(c) 条扩为手工/运行时共用同一 schema；3.1.1 映射表**解冻重画**；3.13 威胁模型**留且升格为架构组件**。逐条见 &#96;../runtime/task.md&#96;「refact-fable.md &#167;8 九条的处置」一节 &#124; 混合：&#167;8-7 作废朝**省事**，3.13 升格朝严谨 &#124; **是** &#124; &#96;runtime&#96; 轮全部参与方；R0–R5 路线（&#167;5 目标文件树随 3.1.1 一起失效） &#124;

## 备注

- **R9 已生效**（所有者签发）：收件箱条目 &#96;../runtime/inbox-owner.md&#96; 的 &#96;I-01&#96;。
  按本文件抬头的规则，人确认 = 是 的行才以所有者 commit 为生效时刻。
  R1 规定其冻结物「此后只能经 H6 改，**改动追加于本文件不覆盖**」——故 R9 是追加行，R1 原文一字未动。
- R3–R8 是当日会话中已做出、此前只记录在对话里的所有者裁定，此处**回填**为记录——按「未记录的裁定无效」，回填是让它们生效，不是追认。
- 本文件、&#96;refact-fable.md&#96;、&#96;reviews/&#96; 下九份评审与处置表应在**同一个所有者 commit** 里进 master。评审原文保留在 &#96;reviews/&#96;，
  理由：R1 的依据必须能独立成立，不能只剩方案作者的转述；上一轮 refact 也把全部提案与评审保留在 tag 里。
</pre>

### rounds/runtime/rulings.md

<pre data-ruling="rounds/runtime/rulings.md"># 裁定记录：轮次 runtime

&gt; 字段按 &#96;round-protocol.md&#96;「裁量权」。**未记录的裁定无效。**
&gt; 编号自本轮 &#96;R1&#96; 起——每轮各有自己的 &#96;rulings.md&#96;，&#96;rounds/refact-fable/rulings.md&#96; 的 R1–R9 是那一轮的，不连号。
&gt; **人确认 = 是** 的行，以所有者 commit 为生效时刻。
&gt;
&gt; ⚠ **本轮回执形态的已知弱点见 &#96;R2&#96;**：本机 git 无签名、所有者与 agent 共用同一身份，
&gt; 「所有者 commit」在账本上与 agent 提交不可区分。凡本文件写「所有者确认」的行，
&gt; 其证据强度受此限制，不得当作不可伪造的凭据。

&#124; 编号 &#124; 事由 &#124; 依据 &#124; 处置 &#124; 方向 &#124; 人确认 &#124; 影响到谁 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;R1&#96; &#124; 本轮据以运行的协议版本 &#124; master &#96;7e8464c2&#96; 上 &#96;round-protocol.md&#96; 只有 165 行旧版，&#96;round-status.py&#96; / &#96;round-dispatch.py&#96; / &#96;agents.toml&#96; 在 master 上不存在；而本轮自 H1 起即按 601 行版运行——环节通知（&#167;6.1）、检视面（&#167;7.3）、判据自身的质量（&#167;8.1）、身份判别、停止判据均只在该版 &#124; 本轮程序基础 = 标签 &#96;runtime/protocol&#96;（&#96;protocol-v2&#96; @ &#96;8da46502&#96;，601 行）。&#96;protocol-v2&#96; 尚有五条待所有者裁定，**另轮处理，不阻塞本轮**。所有者 2026-09-05 裁定「选 A」 &#124; 中性偏严谨——601 行版的检查严于 165 行版，不减任何门槛 &#124; **是** &#124; 五家参与方、裁决方；&#96;protocol-v2&#96; 的合并时机 &#124;
&#124; &#96;R2&#96; &#124; 本轮回执形态不可验证，且所有者当前不存在 agent 够不着的操作面 &#124; 复核：VM 无 GPG 密钥、git 未配 &#96;user.signingkey&#96; / &#96;commit.gpgsign&#96;；H1 签发 &#96;94558713&#96; 与裁决方提交同为 &#96;sunmoonlion &lt;13701819268@163.com&gt;&#96; 且均无签名；所有者的 Cursor 与 Qoder 均 Remote 连入本 VM，人的动作与 agent 的动作同机器、同身份 &#124; 本轮沿用 &#96;rounds/refact-fable/rulings.md&#96; &#96;R2&#96; 的 bootstrap 例外（rulings 行 + 所有者 commit），**但如实登记其证据强度为零**。同时将「所有者需要一个 agent 够不着的操作面」列为 **S1 的前置**——先有该操作面，再谈 VM 换三把 key，否则只是在同一信任域里搬家 &#124; **更省事**（回执弱于 3.13 标准） &#124; **是**（依据：所有者执行了包含该弱点声明的签发 commit &#96;94558713&#96;，并于同日确认） &#124; S1 的形态；&#96;refact-fable.md&#96; &#167;3.13.5 两台机器的身份分布 &#124;
&#124; &#96;R3&#96; &#124; 本轮固定投喂指令须临时加一句指路 &#124; &#96;round-protocol&#96; 的固定指令是「按 round-protocol 定位当前环节，做你该做的那一步」，但它预设参与方的基线上有 &#96;round-protocol.md&#96; 当前版与 &#96;round-status.py&#96;——本轮基线 &#96;7e8464c2&#96; 两者皆无（&#96;R1&#96;） &#124; 本轮投喂时在固定指令后补一条取件命令，指向 ① 环节通知。**这是 R0 那三处脚本↔协议不一致的同源问题**（工具未随协议进主线），R0 合并 &#96;protocol-v2&#96; 后此补丁即可撤除 &#124; 中性——不改门槛，只补可达性 &#124; **是** &#124; 本轮五家的投喂措辞；R0 的验收应包含「固定指令无需补丁即可用」 &#124;
&#124; &#96;R4&#96; &#124; 身份判别命令在仓外不响亮失败，而是输出垃圾 &#124; 2026-09-05 复核：luna 的进程 cwd 是 &#96;~/worktrees/luna&#96;（仓外一层，该目录下有 k8s / info-app / investment-app / knowledge-app / tpl-app 五个仓）。在此处跑 &#96;basename &quot;$(git rev-parse --show-toplevel &#124; xargs dirname)&quot;&#96;，&#96;git&#96; 退出 128 但管道吞掉错误，&#96;basename&#96; 对着报错文本输出一串 &#96;.&#96; &#124; 硬化为：&#96;r=$(git rev-parse --show-toplevel 2&gt;/dev/null) &amp;&amp; basename &quot;$(dirname &quot;$r&quot;)&quot; &#124;&#124; echo &quot;❌ 不在 git 仓内&quot;&#96;。**任务书 &#167;6.2 里的原版已被 H1 冻在标签 &#96;runtime/h1&#96; 上，不改**；硬化版写进 ② 及以后的环节通知，本轮 ① 由所有者按需口头转达 &#124; 更严谨——原版会把失败伪装成一个不匹配的名字，硬化版让失败可见 &#124; **是** &#124; 本轮全部环节通知；&#96;task.md&#96; &#167;6.2 在下一轮重写时应采用硬化版 &#124;
&#124; &#96;R5&#96; &#124; 任务书与 ① 通知里的产品消歧句，本身成了误判身份的凭据 &#124; 2026-09-05 事故：&#96;cursor&#96; 参与方（cwd &#96;~/worktrees/cursor&#96;，模型 Cursor Grok 4.6）自判为 &#96;fable&#96;，并宣告「正在把候选写到 fable 工作区」。因果链与 &#96;R4&#96; 同源——cwd 在仓外，判别命令吐出一串 &#96;.&#96; 而非报错，该 agent 遂退回文本推理，读到 &#167;6.2 的「&#96;cursor&#96; = Cursor CLI，&#96;fable&#96; = Cursor 应用」，推出「我跑在 Cursor 产品里 → 我是 fable」。所有者当场发现，两个 worktree 均未被写，无污染 &#124; ① 通知删去产品映射，改为三条硬规矩：命令跑不出名字就停、产品/模型/界面一律不是身份证据、只写自己路径下的文件。**任务书 &#167;6.2 已被 H1 冻结不改**；以通知为准 &#124; 更严谨——移除一条会导致错误结论的证据来源 &#124; **是** &#124; 全部参与方；&#96;task.md&#96; &#167;6.2 在下一轮重写时不得再列产品映射 &#124;
&#124; &#96;R6&#96; &#124; 冻结判据 &#167;8-4 与 &#167;8-7 自相矛盾，如何裁 &#124; &#96;task.md&#96; &#167;8 第 4 条（已 H1 冻结）要求候选出向**必含**「展示哪个 Artifact 的哪个版本 / 渲染形式 / 人可编辑范围」、入向**必含**三值 + amend 载荷；而该条内容**就是 OP-2 的内容**，&#167;8 第 7 条与 &#167;5 又规定「有理由地推翻 OP-2 按加分记」。cursor 候选据 &#96;client_context&#96;（内核 &#96;:140&#96;）把 render 移出内核绑定并用入向四值——按 &#167;8-7 应加分，按 &#167;8-4 字面不满足。矛盾在冻结的判据本身，不在候选（裁决方 E-6 自查） &#124; **&#167;8-4 的「必含」从属于 &#167;8-7**：候选给出等价或更强的结构化字段表 + 内核修订工作单元即算满足；render 的具体归属不在冻结范围。所有者 2026-09-05 裁「a」。裁决稿据此采纳 cursor 的 render 归 Delivery（处置记录 D-2） &#124; **更省事**（放宽一条已冻结的验收条件）——故必须人确认 &#124; **是** &#124; cursor 的 &#167;8-4 判定；裁决稿的 Interaction 字段表；④ 异议中该维度的可争范围 &#124;

## 备注

- &#96;R4&#96; / &#96;R5&#96; 与 &#96;round-status.py&#96; 的 &#96;all({})&#96; 是**同一条纪律的三次触发**：
  **检查在边界条件下不报错，而是给出一个看起来像结论的东西**，下游据此继续推理。
  &#96;all({})&#96; 报「完成」，判别命令吐 &#96;.&#96;，产品映射句被当成身份证据——三次都不是「查漏了」，
  是「查出了一个假答案」。按「裁量是规则的孵化器」，第三次即达升级门槛：
  **本轮 ⑦ 清理时须把这条提为 &#96;round-protocol&#96; 的正式纪律**，不再留在轮次 rulings 里。
- &#96;R5&#96; 另有一层教训归裁决方：**消歧文本会被当成推理前提。**
  写「A 是甲产品、B 是乙产品」意在防混淆，实际给了 agent 一条从产品推身份的路。
  身份只能有一个来源，其余全部应显式标为「不是证据」。
- ⚠ **裁决方登记一处自身的不一致**：&#96;R1&#96; 的「人确认」是据对话里的「选 A」直接写成 **是** 的，
  而 &#96;inbox-owner.md&#96; 与本文件抬头都写着「回执只认落盘，对话里说『同意』不算」。
  &#96;R6&#96; 起改为：H6 类裁定一律先写 **待**，以所有者 commit 为生效时刻。&#96;R1&#96; 的形态不追改，但登记在此。
- &#96;R3&#96; 登记的是一笔**技术债的外化**：固定指令之所以要打补丁，是因为工具链停在一条未合并的分支上。
  按「裁量是规则的孵化器」，若下一轮仍需同样的补丁，说明 R0 的优先级判错了。
</pre>

### rounds/runtime-refact/rulings.md

<pre data-ruling="rounds/runtime-refact/rulings.md"># 裁定记录：&#96;runtime-refact&#96; 轮

&gt; **未记录的裁定无效**（&#96;round-protocol.md&#96; &#167;2.4）。
&gt; 「人确认 = 是」的行，以所有者的确认为生效时刻。
&gt;
&gt; ⚠ **本轮回执形态的已知弱点**：本机 git 无签名，所有者与 agent 共用同一身份，
&gt; 「所有者确认」在账本上与 agent 提交不可区分。凡本文件写「人确认 = 是」的行，
&gt; **证据强度按 &#96;reported&#96; 记，不按 &#96;attested&#96;**。这一点如实登记，不掩饰。

&#124; 编号 &#124; 事由 &#124; 依据 &#124; 处置 &#124; 方向 &#124; 人确认 &#124; 影响到谁 &#124;
&#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;R1&#96; &#124; **H-1：裁决方是谁**（任务书 &#167;9） &#124; 组织者 opus 同时是参考作品 &#96;agent-dev-refact.md&#96; 的作者，自裁则自我制衡弱；换人裁则多一轮上下文传递。两种都成立，代价不同，故交人 &#124; **opus 任裁决方**。所有者 2026-09-06 裁定。按 &#96;round-protocol.md&#96; &#167;8.2「起草人回避」，opus 的既有立场**不作判据**：候选与参考作品一致既不加分也不减分，冲突且论证扎实的应当高于一致但无论证的 &#124; 中性——两选项各有代价，非严谨/省事之分 &#124; **是** &#124; 五家参与方；③ 裁决；⑤ 验收方由处置表算出且不得是 opus &#124;
&#124; &#96;R2&#96; &#124; **H-2：五家能不能读参考作品** &#124; 给则省掉重复核查但候选会向它收敛，而独立性正是开这一轮的理由；不给则独立性强但六条结论要各自重核（每条约两分钟） &#124; **不得读 &#96;agent-dev-refact.md&#96;**。所有者 2026-09-06 裁定。该文从只读输入清单中移除；任务书 &#167;3.1 改为禁止条款。⚠ **本条靠纪律不靠机制**——该文就在各家工作区的主线上，打得开。执行者自行遵守并在候选里声明是否遵守 &#124; **更严谨**（收紧输入，提高独立性） &#124; **是** &#124; 五家参与方；任务书 &#167;3 只读输入清单；⑤ 验收 J8 &#124;
&#124; &#96;R3&#96; &#124; **fable 退赛**（所有者 2026-09-06 告知），① 期间 &#124; &#96;round-protocol.md&#96; &#167;14.1：「换角色只有一个合法理由：该家不可用（不响应、逾期、**退出**）」。① 环节的后果是「该家不出候选，本轮 &#96;N&#96; 减一，不阻塞其余；&#96;N&#96; 降到 1 时停轮问人」。本轮 &#96;N&#96;：5 → **4**，远高于停轮线 &#124; 工单 &#96;proposers&#96; 去掉 &#96;fable&#96;。**① 通知 &#96;call-①.md&#96; 不改**——产物一旦随环节通知发布，本环节内不得再改（&#96;round-protocol.md&#96; &#167;6.1）；fable 的缺席由本裁定与工单承载。已为 fable 建的 &#96;investment-app&#96; worktree 保留，不回收（无害，且它可能回来） &#124; 中性——非严谨/省事之分，是参与方状态变化 &#124; **是** &#124; 四家参与方（不影响各自的活）；③ 裁决的独立性折算；⑤ 验收方由四家中算出 &#124;
&#124; &#96;R4&#96; &#124; **kimi 在 ① 逾越同侪基准截止**（&#96;W&#96; = 19.6 分钟，截止 20:10:18），原因是网络慢 &#124; &#96;round-protocol.md&#96; &#167;14.1：「**可延长，不可缩短**。组织者延长观察窗只需记录；缩短须经人确认」。本条是延长，且由所有者本人提出 &#124; **本轮等 kimi，观察窗延长，不设新截止**。⚠ **下一轮起不再为同一原因延长**：按原判据处理，到点即按逾期减员。所有者 2026-09-06 裁定 &#124; **更省事**（放宽本轮的截止）——故必须人确认；其中「下次不等」的那一半是朝严谨 &#124; **是** &#124; 本轮 ① 的截止；下一轮的组织者 &#124;
&#124; &#96;R5&#96; &#124; **组织者可否自己执行分发**（此前一律由所有者手工投喂） &#124; &#96;round-dispatch.py&#96; 自身的设计约束是「**只生成不执行**」，&#96;automation-roadmap.md&#96; 第 3 步；第 4 步的真调用前提是「粘贴跑通一轮、确认判定与措辞无误」。① 已由所有者手工投喂跑通一轮，四家全部交付，判定与措辞均无误 &#124; **opus 可直接执行四家的分发命令**（luna / kimi / cursor / qwen）。所有者 2026-09-06 授权，本轮 ② 起生效，**同时作为自动流程的首次实测**。命令一律取自 &#96;round-dispatch.py&#96; 的输出，**不手写**——手写就绕过了「单一真源」 &#124; **更省事**（去掉人的一道传输动作）——故必须人确认 &#124; **是** &#124; ② 及以后各环节的分发；&#96;dispatch_event&#96; 的记法 &#124;
&#124; &#96;R6&#96; &#124; **自动分发被权限与沙箱挡住**：② 首次真调用，四家里三家零产物且退出码均为 0 &#124; 实测：&#96;codex exec&#96; 默认 &#96;approval: never&#96; + &#96;sandbox: read-only&#96;，luna 把评审做完却写不进；&#96;qoder&#96; 无权限参数，停下来请求批准；三种失败在退出码上完全不可见 &#124; **按最小够用放行**（所有者 2026-09-06 裁定）：codex 两家加 &#96;-s workspace-write&#96;（只放开工作区写入，**不给网络、不给全盘**，比 &#96;--full-auto&#96; 窄）；qwen 加 &#96;--permission-mode dont_ask&#96;（五档里 &#96;accept_edits&#96; 更窄但只覆盖文件编辑，qwen 还需 &#96;git show&#96; / &#96;git commit&#96;，Bash 仍会被挡，故不够用）。**不采用** &#96;--dangerously-*&#96; 两档 &#124; **更省事**（扩大 agent 无人看管时的动手范围）——故必须人确认 &#124; **是** &#124; &#96;agents.toml&#96;；② 及以后各环节的分发 &#124;
&#124; &#96;R7&#96; &#124; **自动分发跑不完 ②**：四家能写不能提交，根因在工作区形态而非权限档位 &#124; 实测：&#96;git worktree&#96; 的真实 git 目录在主仓 &#96;.git/worktrees/&#96; 下，**不在沙箱可写范围内**；而提交要写 &#96;index.lock&#96;、&#96;objects/&#96;、&#96;refs/&#96;。luna 自己在日志里准确指出该点。cursor 在 &#96;-p&#96; 非交互下三次写完不提交、所有者交互式跑一次即提交。qwen 的 &#96;dont_ask&#96; 实为**不问也不放行**，写操作一律被拒 &#124; **本轮改人工补完**（所有者 2026-09-06 裁定）：产物已落盘的，由组织者代提交，**逐字节不改**，commit message 写明内容作者、代提交者与原因，并附 sha256。⚠ 代提交的性质等同 &#96;dispatch_event{mode = manual}&#96;——**人代行的动作，是欠账不是权力，必须可数**。⚠ **不采用**「继续放宽权限」的路：让每个 agent 能写主仓 git 目录，等于每家都能改别家分支引用，与「强制点必须在 agent 的凭据域之外」直接冲突 &#124; **更省事**（本轮放弃自动化）——故须人确认 &#124; **是** &#124; 本轮 ②；&#96;agents.toml&#96;；下一轮的工作区供给形态 &#124;
&#124; &#96;R8&#96; &#124; ③ 之后怎么走：④ 要不要跑、⑤ 用什么方式跑、&#96;executor-adapter&#96; 何时开 &#124; ④ 是「对整合权的唯一制衡」，而本轮裁决方**推翻了四家的一处共识**（A-3：cursor 不违反 B4），正是 ④ 该检验的对象；⑤ 的验收方 kimi 在自动模式下写得出提不了交，交互式跑则验收稿由它自己提交，可追溯性高一档 &#124; 所有者 2026-09-07 裁定：**① ④ 照跑**；**② ⑤ 由所有者交互式跑一次**；**③ &#96;executor-adapter&#96; 现在就开**。⚠ 第三条与协议「同时只允许一个 ACTIVE 轮次」冲突（冷启动第 3 问靠它回答，两个 ACTIVE 会让参与方认不出该做哪一轮）。**处置：该轮次保持 DRAFT，但其工单 D1 要求的「每家最小 spike」由组织者即刻开跑**——spike 是组织者的活不是参与方的活，不占用轮次；结果落为该轮只读输入。⑦ 之后再转 ACTIVE &#124; 中性（④/⑤）＋ 更严谨（spike 先行取证） &#124; **是** &#124; 本轮 ④⑤；&#96;executor-adapter&#96; 的开轮时机 &#124;
&#124; &#96;R9&#96; &#124; **任务书 &#167;1.3 的前提作废**：两份源稿本轮发布后**不删** &#124; 所有者 2026-09-07 告知「后面还有用」。&#167;1.3 原写「⑥ 确认后将从主线删除」，并据此立了「**漏了就没了**」这一条紧迫性 &#124; **改为：两份源稿保留。**任务书已冻结不改，本条以裁定追加为准（协议 &#167;8.2 第 1 条：判据有问题在裁决书／裁定里追加，不回头改判据）。⚠ **不因此放宽 D2 落点表要求**——M1／M2 已按原判据判过，四家全过，且落点表的价值（可审计的覆盖索引）与源稿删不删**无关** &#124; 中性偏严谨——保留更多真源，不放宽任何已冻结判据 &#124; **是** &#124; ③ 处置记录 B-2；⑦ 清理与发布的范围 &#124;
&#124; &#96;R10&#96; &#124; &#96;R9&#96; 遗留的未决：源稿保留后三份并存，规范效力归谁 &#124; P1 要求「同一事实只有一个权威写入面」。若源稿仍为规范，则**三个真源**，且它们对六项已证伪设计的表述与新稿相反 &#124; **源稿降为历史档案，不再有规范效力**（所有者 2026-09-07 裁定 A 案）。冲突时以 &#96;agent-dev-guide.md&#96; 为准。⚠ **降级不等于作废**：历史档案仍可被引用为**当时的判断与取证**，只是不再作为「现在该怎么做」的依据 &#124; 更严谨——恢复 P1 的单一权威写入面 &#124; **是** &#124; ⑦ 发布；&#96;archive/README.md&#96;；三份文档各自的抬头 &#124;
&#124; &#96;R11&#96; &#124; **⑥ 确认：最终稿** &#124; ⑤ 判 J1 未过 → 回到 ③ 按验收方给的一行修法修补 → ⑤b 全部判据通过；两道门全过（&#96;doc-gate 199&#96; / &#96;anchor-gate&#96; 钉 commit 锚 40 + 裸路径锚 101） &#124; **所有者 2026-09-07 确认发布**。对象：裁决稿 &#96;agent-dev-guide.md&#96; @ &#96;runtime-refact/arbiter&#96;，**808 行，sha256&#91;:16] &#96;6b8f202d3c43eeb7&#96;**。确认前已告知三事：裁决方自查错误七条、&#96;O-4a&#96;/&#96;O-4b&#96; 正文残留留 ⑦、九条观察待 ⑦ 后处置 &#124; **不可逆**——全流程唯一 &#124; **是** &#124; ⑦ 清理与发布 &#124;

## &#96;R3&#96; 的独立性后果：有得有失，如实记

减一家等于少一路独立信号，这是**失**。但按 &#96;protocol/agents.toml&#96; 的登记，
fable 恰好是唯一同时具备以下三条的一家：

- **唯一无命令行入口**——分发只能人工投喂，&#96;observability = fs-only&#96;，运行时看不见它做了什么；
- **唯一模型不可机械核验**——模型在 GUI 里选，不经任何命令行参数，登记值只有所有者口述；
- **与 cursor 构成本表唯一一对存疑配对**——同厂不同产品（Cursor 应用 vs &#96;agent&#96; CLI），
  两者共用多少 harness 内核**未知**。

所以它的退出**同时移除了独立性折算里唯一不可复核的输入和唯一存疑的配对**，这是**得**。

剩下四家按 harness 分三组：&#96;{luna, kimi}&#96; 共用 codex-cli（provider 与模型不同），
&#96;cursor&#96; 与 &#96;qwen&#96; 各自一组。⚠ 「同 harness 不同模型」的相关性**仍未测**
（&#96;agent-dev-refact.md&#96; &#167;6.1 第 4 条登记的未决项），所以三组是**上界不是实数**。
③ 裁决时按三组算，并把这条 ⚠ 写进处置记录。

## &#96;R4&#96; 暴露的判据缺口：零字节判不出「没起来」还是「在跑」

kimi 的观测值是**零字节**。协议 &#167;14.1 的两种截止判据在这里都不好用：

- **停滞判据**要「产物字节数无变化」——零字节确实无变化，但那和「一直在下载模型权重」
  的观测值**完全相同**。判据分不出「进程没起来」与「起来了但慢」。
- **同侪基准**能算出截止（本轮 20:10:18），但它只回答「该不该等」，
  不回答「等了有没有用」。

所以本轮只能靠人告知原因（网络慢）才做出了正确决定——**这说明判据不够**。
缺的是一个**「已开始」信号**：哪怕零产出，也能证明该执行者的进程确实起来了。
候选形态（不在本轮范围，登记待办）：分发时落一条 &#96;dispatch_event&#96; 并记进程启动时刻；
或要求执行者一收到指令就先写一个零内容的占位提交。

⚠ **不要把这条改成「零字节即判未启动」**——那是把「没查到」写成「没有」，
正是 &#167;8.1 点名的形态。

## &#96;R5&#96; 的两条自我约束

授权的是**执行分发**，不是别的。两条边界现在写下来，免得日后含糊：

1. **仍然只发固定的那一句话。**&#96;round-dispatch.py&#96; 生成什么就发什么，
   不逐轮改写措辞——通知落盘且路径可推导，正是「固定指令」能成立的原因。
   要说的话写进 &#96;call-&lt;环节&gt;.md&#96;，不写进命令行。
2. **执行分发不等于可以碰参与方的工作区。**环节进行中不得往各家 worktree 写入
   （包括 &#96;git merge master&#96;）。同步只在**环节之间**做，且做完才发下一环的通知。
   ⚠ 本轮 ① 期间我违反过一次：&#96;R3&#96; 提交后照惯例同步了四家，
   当时 cursor 正在写候选，merge 恰好无冲突所以没出事——**那是运气不是纪律**。

⚠ 本次是自动流程的**首次实测**，按 &#167;8.1 第 4 条，它的结果要与 ① 的手工投喂结果对照：
四家是否都真的起来了、是否都读到了 &#96;call-②.md&#96;、产物形态是否与手工投喂时一致。
**对不上就停下问人，不要自行调参数重试。**

## &#96;R6&#96; 记三件必须留痕的事

**一、退出码第三次证明毫无意义。**&#96;agents.toml&#96; 抬头那句「判某家是否真的执行了只能看产物，
不能看退出码」原本记的是 cursor 未加 &#96;--trust&#96; 的情形。② 一次实测又添两个新形态：
&#96;codex exec&#96; 只读沙箱下写入被拒、&#96;qoder&#96; 停下来请求批准——**三种失败，退出码全是 0**。

**二、一个至今未解释的矛盾，不编原因。**① 由所有者手工投喂时，luna 用**同一条**
&#96;codex exec&#96; 命令写成并提交了候选（&#96;39889605&#96;）；② 由组织者执行同一条命令却是只读沙箱。
两者差异未查明。**登记为未解释**，不因为「看起来像是交互模式的差别」就写成结论。

**三、放宽容易收紧难。**本次放行的两档写进登记表后，将来要收窄得改所有轮次共用的
&#96;agents.toml&#96;，且没有任何轮次会因此重跑。所以这次取最小够用的一档，
**不顺手多给**——&#96;--full-auto&#96; 与 &#96;--dangerously-skip-permissions&#96; 均未采用。

## &#96;R7&#96; 之下：两个被名字误导的实例，一并登记

本轮两次因为**参数名与实际行为不符**而判错，形态相同，都记下来：

&#124; 参数 &#124; 名字让人以为 &#124; 实际 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; &#96;round-dispatch.py --stage&#96; &#124; 指定环节，覆盖自动判定 &#124; 传 &#96;4&#96; 与环节名 &#96;④ 异议&#96; 永不匹配，**静默退回当前环节** &#124;
&#124; &#96;qoder --permission-mode dont_ask&#96; &#124; 不问就放行 &#124; **不问也不放行**——写操作一律被拒，比默认档更严 &#124;

两次我都是照名字推理后直接用上。教训写成一条：
**参数名不是判据，第一次用一个未验过的开关，要先用一次最小调用验证它的实际行为**，
与 &#167;8.1「新判据第一次跑，先与人工结论对照」同源。

## &#96;R7&#96; 未解释项：交互 vs 非交互

cursor 在 &#96;-p&#96; 非交互模式下三次写完**不提交**，所有者交互式跑一次**即提交**。
差别在**运行模式**，不在「谁执行」——这一点已由对照实验确定。
但 codex 侧（① 能提交、② 不能）是否同源，**未验证**，登记为假设。

## &#96;R7&#96; 的续：自动分发怎么才能走通（2026-09-07 实测）

&#96;R7&#96; 只写了「本轮改人工补完」，没解决「以后怎么办」。补上，**结论全部来自实跑，不是推理**。

### 先记一次被实验推翻的分析

我先前判定根因是「&#96;git worktree&#96; 把仓与工作区拆开，提交要写工作区外的共用 gitdir」，
并据此认为**独立 clone 就能解**。**实验推翻了它**：在一个全新的独立 clone 里，
沙箱仍然报

&#96;&#96;&#96;text
fatal: Unable to create &#x27;.git/index.lock&#x27;: Read-only file system
&#96;&#96;&#96;

——&#96;codex exec -s workspace-write&#96; **按设计把 &#96;.git&#96; 挂只读**，与仓的布局无关。
若不做这个实验，下一轮会照着错的方向改工作区形态，白折腾一轮。

### 实测出来的解

试探配置键得到：&#96;sandbox_workspace_write.writable_roots&#96; **存在**（报错是「期望序列」），
而 &#96;exclude_git_dir&#96;、&#96;allow_git_writes&#96; **均不存在**。所以放行 &#96;.git&#96; 的开关只有
&#96;--add-dir&#96; / &#96;writable_roots&#96; 一个。由此两条路分岔：

&#124; 工作区形态 &#124; &#96;--add-dir&#96; 要放行什么 &#124; 结论 &#124;
&#124; --- &#124; --- &#124; --- &#124;
&#124; **worktree**（现状） &#124; **共用**的 &#96;.git&#96;（含所有家的 refs） &#124; **死路**——一家可写等于每家能改别家分支引用，与「强制点必须在 agent 的凭据域之外」直接冲突 &#124;
&#124; **独立 clone** &#124; **这家自己**的 &#96;.git&#96; &#124; ✅ **实测通过**：&#96;d0a2a822&#96;。不碰任何共用状态，隔离比现状更强 &#124;

**所以 clone 与 &#96;--add-dir&#96; 不是两个方案，是同一个解的两半**：clone 让 &#96;.git&#96; 变私有，
&#96;--add-dir&#96; 让它可写。先前把它们列成互斥的选项 A / C，是同一处判错。

成本已量：仓 &#96;.git&#96; 38M + 工作树 37M，每家约 75M，四家 300M。**不构成障碍。**

### 这条路解决什么，不解决什么

- 解决：**能不能自动化**。codex 两家（luna / kimi）由此可自提交。
- **不解决：谁签的。**clone 在本机，&#96;author&#96; 字段可随意填，本机无签名、各身份共用同一 git 身份。
  &#96;agent-dev-refact.md&#96; &#167;2.6「这道关卡的证据强度是零」一个字都不用改。**两件事不许混。**
- **未覆盖**：cursor 与 qwen 不是 codex，机制不同——cursor 是 &#96;-p&#96; 非交互下不提交（与沙箱无关），
  qwen 的 &#96;accept_edits&#96; 是否允许 git 操作**未验证**。这两家要各自单验，不得由本次结论外推。

## &#96;R9&#96; 影响面：一处要改，两处不改，一处新增未决

**要改的一处**：③ 处置记录的 &#96;B-2&#96;「该顺序源稿删除后只存在于这一份里」——
前提没了，该条**降级为参考理由**。⚠ 但**基座选择不变**：&#96;B-1&#96;（只有 &#96;luna&#96; 保住了
带前置与退出条件的依赖顺序，四份逐一查过）、&#96;B-3&#96;（无一处违反硬约束）、&#96;B-4&#96;
三条**各自独立成立**，不依赖删除前提。

**不改的两处**：裁决稿 &#167;7.3「删除与迁移门」与 &#96;G5&#96;「旧稿删除经人确认」是**条件门**
（「删除前必须同时满足…」），不是「承诺要删」。不删则不触发，逻辑不矛盾，原文保留。

**新增未决（⚠ 需所有者裁定，本轮不擅自定）**：源稿保留之后，
&#96;refact-fable.md&#96;、&#96;runtime-architecture.md&#96; 与新的 &#96;agent-dev-guide.md&#96; **三份并存**，
而 P1 要求「同一事实只有一个权威写入面」。三者的**规范效力**必须说清：

&#124; 选项 &#124; 后果 &#124;
&#124; --- &#124; --- &#124;
&#124; A 源稿降为**历史档案**，不再有规范效力 &#124; 满足 P1；读者知道冲突时以新稿为准 &#124;
&#124; B 源稿**仍是规范** &#124; **三个真源**，与 P1 直接冲突；且它们对六项已证伪设计的表述与新稿相反 &#124;

**不预设，交所有者。**在裁定之前，⑦ 发布时**不得**在新稿里写「源稿已作废」一类断言。
</pre>

## 机器清单与只读工具

清单是安置表的机器形态，输入与落点正文仍分别核对。

<!-- DATA BEGIN -->
<pre>{
&quot;baseline&quot;: &quot;78ccbf106d3189afabb3ce1a622b406516fa9ed2&quot;,
&quot;prefix&quot;: &quot;sunmoonai/docs/dev-plan/&quot;,
&quot;files&quot;: {&quot;working/request-lifecycle.md&quot;: {&quot;sha256&quot;: &quot;14368715f2ee32cf67d4f278eb67693bbebb240be832a1c63e58dd7590bb37c8&quot;, &quot;lines&quot;: 647, &quot;sections&quot;: 42}, &quot;agent-dev-guide.md&quot;: {&quot;sha256&quot;: &quot;4cfb988c77ecedb874754269ab914b4bfc57132160d9b82b443c01b7e375b8e0&quot;, &quot;lines&quot;: 3082, &quot;sections&quot;: 108}, &quot;protocol/round-protocol.md&quot;: {&quot;sha256&quot;: &quot;1e42ece55ac61f018f673f6fa110681fe682de1d88f704ace86e6108f3f8d3bd&quot;, &quot;lines&quot;: 929, &quot;sections&quot;: 57}, &quot;protocol/README.md&quot;: {&quot;sha256&quot;: &quot;184cd574174ff19f23e3c72f31256d07dece3492439b6951eb8f3ac78c08894f&quot;, &quot;lines&quot;: 46, &quot;sections&quot;: 4}, &quot;constraints.md&quot;: {&quot;sha256&quot;: &quot;fce1377b72e45688895284eeb76fe9b388f83cabd26417c534698dd928df303f&quot;, &quot;lines&quot;: 214, &quot;sections&quot;: 15}, &quot;development-plan.md&quot;: {&quot;sha256&quot;: &quot;f71d01b58a838d8b44b6a2ae83b5f32926415e698f015ae169c6c30ba07ead91&quot;, &quot;lines&quot;: 142, &quot;sections&quot;: 10}, &quot;implementation-plan.md&quot;: {&quot;sha256&quot;: &quot;7c0da00d2c1aaf04d34446ec49c1dfe8d0e809c62d42f81ce9c3108599c26c62&quot;, &quot;lines&quot;: 93, &quot;sections&quot;: 9}, &quot;handoff.md&quot;: {&quot;sha256&quot;: &quot;060b4c10ca55c137fdcfe30dc3f5c4333a65350edce709680811078253f74838&quot;, &quot;lines&quot;: 131, &quot;sections&quot;: 13}, &quot;README.md&quot;: {&quot;sha256&quot;: &quot;3c6bf37a0844baf1783243a17a833b9e5ff09383e4ede03fbf9cd2d9a1bb997e&quot;, &quot;lines&quot;: 36, &quot;sections&quot;: 2}},
&quot;docs&quot;: &#91;
{&quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;class&quot;: &quot;N&quot;, &quot;why&quot;: &quot;完整的产品合约闭环；对象、状态、要求与验收共享版本，保留原章节及所有行号。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;, &quot;units&quot;: &#91;&quot;K-001&quot;, &quot;K-002&quot;, &quot;K-003&quot;, &quot;K-004&quot;, &quot;K-005&quot;, &quot;K-006&quot;, &quot;K-007&quot;, &quot;K-008&quot;, &quot;K-009&quot;, &quot;K-010&quot;, &quot;K-011&quot;, &quot;K-012&quot;, &quot;K-013&quot;, &quot;K-014&quot;, &quot;K-015&quot;, &quot;K-016&quot;, &quot;K-017&quot;, &quot;K-018&quot;, &quot;K-019&quot;, &quot;K-020&quot;, &quot;K-021&quot;, &quot;K-022&quot;, &quot;K-023&quot;, &quot;K-024&quot;, &quot;K-025&quot;, &quot;K-026&quot;, &quot;K-027&quot;, &quot;K-028&quot;, &quot;K-029&quot;, &quot;K-030&quot;, &quot;K-031&quot;, &quot;K-032&quot;, &quot;K-033&quot;, &quot;K-034&quot;, &quot;K-035&quot;, &quot;K-036&quot;, &quot;K-037&quot;, &quot;K-038&quot;, &quot;K-039&quot;, &quot;K-040&quot;, &quot;K-041&quot;, &quot;K-042&quot;]}]},
{&quot;path&quot;: &quot;constraints.md&quot;, &quot;class&quot;: &quot;N&quot;, &quot;why&quot;: &quot;按改动影响面自检；规则 ID、验证载体、操作例证与门禁盲区留在同一文件，防止只看禁令不看效力。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;, &quot;units&quot;: &#91;&quot;C-001&quot;, &quot;C-002&quot;, &quot;C-003&quot;, &quot;C-004&quot;, &quot;C-005&quot;, &quot;C-006&quot;, &quot;C-007&quot;, &quot;C-008&quot;, &quot;C-009&quot;, &quot;C-010&quot;, &quot;C-011&quot;, &quot;C-012&quot;, &quot;C-013&quot;, &quot;C-014&quot;, &quot;C-015&quot;]}]},
{&quot;path&quot;: &quot;specs/foundation.md&quot;, &quot;class&quot;: &quot;N&quot;, &quot;why&quot;: &quot;先建立适用边界及设计取舍，再统一名词和反例；实现不同模块时有共同判定基础。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;, &quot;units&quot;: &#91;&quot;G-002&quot;, &quot;G-003&quot;, &quot;G-004&quot;, &quot;G-007&quot;, &quot;G-008&quot;, &quot;G-013&quot;, &quot;G-011&quot;]}, {&quot;name&quot;: &quot;产品取舍&quot;, &quot;rule&quot;: &quot;回答功能为什么做或暂不做；保持原阶段和观察日期限定，不把状态当作目标。&quot;, &quot;units&quot;: &#91;&quot;D-002&quot;, &quot;D-010&quot;, &quot;H-008&quot;]}, {&quot;name&quot;: &quot;名词与反例&quot;, &quot;rule&quot;: &quot;定义跨组件共同词义和禁止形态；单次失败的完整事件移历史/质量组。&quot;, &quot;units&quot;: &#91;&quot;G-107&quot;, &quot;G-103&quot;]}, {&quot;name&quot;: &quot;已裁定的设计边界&quot;, &quot;rule&quot;: &quot;明确哪些旧设计不得复活，独立观察与处置必须相邻；不能因其叫历史裁定就移出日常规范。&quot;, &quot;units&quot;: &#91;&quot;G-091&quot;, &quot;G-092&quot;, &quot;G-093&quot;, &quot;G-094&quot;]}]},
{&quot;path&quot;: &quot;specs/runtime.md&quot;, &quot;class&quot;: &quot;N&quot;, &quot;why&quot;: &quot;依次给持久责任、角色/Profile、工单/路由、内核到开发载体的映射；控制面依赖由前到后。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;持久责任与组件&quot;, &quot;rule&quot;: &quot;跨进程仍须成立的四账、组件责任及通用/专用界线在此；SDK 私有细节排除。&quot;, &quot;units&quot;: &#91;&quot;G-009&quot;, &quot;G-016&quot;, &quot;D-003&quot;, &quot;D-004&quot;]}, {&quot;name&quot;: &quot;角色与派工契约&quot;, &quot;rule&quot;: &quot;输入是任务类型、执行能力及角色关系；批准权本体另见 authority，历史五家取值留记录。&quot;, &quot;units&quot;: &#91;&quot;G-017&quot;, &quot;G-018&quot;, &quot;G-026&quot;, &quot;G-019&quot;, &quot;G-020&quot;]}, {&quot;name&quot;: &quot;状态和载体投影&quot;, &quot;rule&quot;: &quot;解释现有内核对象如何映射开发载体，不能修改内核状态或以阶段名再造状态机。&quot;, &quot;units&quot;: &#91;&quot;G-031&quot;, &quot;G-032&quot;, &quot;G-039&quot;, &quot;G-045&quot;, &quot;G-046&quot;]}]},
{&quot;path&quot;: &quot;specs/executor.md&quot;, &quot;class&quot;: &quot;N&quot;, &quot;why&quot;: &quot;先定租用边界，再比能力和 Port，再连接两腿恢复/部署与可验证接口；把 guide 原先分处两章的执行和中断放在一起。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;租用边界与能力&quot;, &quot;rule&quot;: &quot;执行原语的租/建选择、SDK 范围和版本限定；历史读数不据此升格为今天实测。&quot;, &quot;units&quot;: &#91;&quot;G-021&quot;, &quot;G-022&quot;, &quot;D-005&quot;]}, {&quot;name&quot;: &quot;Port 与适配门&quot;, &quot;rule&quot;: &quot;签名、能力探针和前置条件必须相邻；不收领域业务签名或具体派工进度。&quot;, &quot;units&quot;: &#91;&quot;G-023&quot;, &quot;G-024&quot;]}, {&quot;name&quot;: &quot;两腿恢复与部署&quot;, &quot;rule&quot;: &quot;同一执行器在进程生命周期中的恢复差异和接口落实矩阵；批准权限公式由 authority 持有。&quot;, &quot;units&quot;: &#91;&quot;G-025&quot;, &quot;G-054&quot;, &quot;G-071&quot;]}]},
{&quot;path&quot;: &quot;specs/authority.md&quot;, &quot;class&quot;: &quot;N&quot;, &quot;why&quot;: &quot;从主体和权力到强制点，再到动作门和凭据传播；读者能逐层检查具体动作是否越权。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;主体与权力&quot;, &quot;rule&quot;: &quot;谁有权做什么、权限怎样相交；谁何时点击按钮是 review 的步骤。&quot;, &quot;units&quot;: &#91;&quot;G-052&quot;, &quot;G-053&quot;, &quot;G-056&quot;]}, {&quot;name&quot;: &quot;边界与动作门&quot;, &quot;rule&quot;: &quot;身份鉴别、强制点、三门与审批档位必须在同一信任模型中解释；不得把约定写成强制机制。&quot;, &quot;units&quot;: &#91;&quot;G-055&quot;, &quot;G-057&quot;, &quot;G-058&quot;]}, {&quot;name&quot;: &quot;执行中禁止与凭据传播&quot;, &quot;rule&quot;: &quot;Attempt 内限制及子进程/跨腿令牌不得绕过前述边界；工具调用具体步骤留 execution。&quot;, &quot;units&quot;: &#91;&quot;G-060&quot;, &quot;G-064&quot;]}]},
{&quot;path&quot;: &quot;specs/evidence.md&quot;, &quot;class&quot;: &quot;N&quot;, &quot;why&quot;: &quot;先定义观测能看到什么，再定义它能证明什么，最后才谈成本和绕过；防止可见性被当成充分证据。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;观测及采信&quot;, &quot;rule&quot;: &quot;粒度、等级、四级词典与历史使用条件构成证据契约；单次实测全文不冒充契约。&quot;, &quot;units&quot;: &#91;&quot;G-066&quot;, &quot;G-067&quot;, &quot;G-073&quot;, &quot;G-078&quot;]}, {&quot;name&quot;: &quot;载体与等效&quot;, &quot;rule&quot;: &quot;Git/其它载体各能证明什么以及 S/R 等效边界；验收动作与判据质量另见 review。&quot;, &quot;units&quot;: &#91;&quot;G-069&quot;, &quot;G-074&quot;, &quot;G-068&quot;]}, {&quot;name&quot;: &quot;成本和观察上界&quot;, &quot;rule&quot;: &quot;只有先知道观测覆盖，才能判路由成本和绕过；保留反例和未归因限制，不推出绝对零绕过。&quot;, &quot;units&quot;: &#91;&quot;G-080&quot;, &quot;G-081&quot;, &quot;G-082&quot;]}]},
{&quot;path&quot;: &quot;playbooks/intake.md&quot;, &quot;class&quot;: &quot;P&quot;, &quot;why&quot;: &quot;把原散在架构、执行、末尾模板和实施计划的开工材料拼成一条前置链：自检 → 受理 → 冻结 → 工单落盘。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;自检与受理&quot;, &quot;rule&quot;: &quot;提交任务前的相关约束、可信输入、边界和默认值冻结；系统原则引用 foundation，不在此新立。&quot;, &quot;units&quot;: &#91;&quot;G-010&quot;, &quot;G-012&quot;, &quot;G-029&quot;]}, {&quot;name&quot;: &quot;记录表单&quot;, &quot;rule&quot;: &quot;要求执行者填写的持久记录与任务条目字段；具体任务清单属于 work/delivery。&quot;, &quot;units&quot;: &#91;&quot;I-002&quot;, &quot;G-108&quot;]}]},
{&quot;path&quot;: &quot;playbooks/execution.md&quot;, &quot;class&quot;: &quot;P&quot;, &quot;why&quot;: &quot;把供给、私有写入、并发故障、取消超时串成一次执行闭环；把发布和审批移到各自责任面。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;工作区准备&quot;, &quot;rule&quot;: &quot;满足开工需要的目录、Git 元数据及可写性验证；权限授予公式不在此改。&quot;, &quot;units&quot;: &#91;&quot;G-030&quot;, &quot;G-042&quot;, &quot;G-048&quot;]}, {&quot;name&quot;: &quot;写入与并发&quot;, &quot;rule&quot;: &quot;先隔离和单写者，再物化/写前门，最后按冲突场景处置；结果发布步骤另见 delivery。&quot;, &quot;units&quot;: &#91;&quot;G-034&quot;, &quot;G-038&quot;, &quot;G-035&quot;, &quot;G-036&quot;]}, {&quot;name&quot;: &quot;停止与恢复入口&quot;, &quot;rule&quot;: &quot;取消、迟到、超时、成本上限和回退共同决定何时停止；跨会话完整记录属于 maintenance。&quot;, &quot;units&quot;: &#91;&quot;G-037&quot;, &quot;G-041&quot;, &quot;G-050&quot;]}]},
{&quot;path&quot;: &quot;playbooks/review.md&quot;, &quot;class&quot;: &quot;P&quot;, &quot;why&quot;: &quot;先准备可重取的批准对象，再评审证据，最后挑战判据自身；把人义务和评审盲区纳入同一次决定。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;批准对象与人的动作&quot;, &quot;rule&quot;: &quot;人如何取得对象、履行义务和合法改判；权力表本体在 authority，不能从便利性推出新权限。&quot;, &quot;units&quot;: &#91;&quot;G-063&quot;, &quot;G-061&quot;, &quot;G-059&quot;]}, {&quot;name&quot;: &quot;七环节操作接口&quot;, &quot;rule&quot;: &quot;任务尺度的流程串联及取件操作；保留 protocol 权威声明，本组不成为另一套七环节规则。&quot;, &quot;units&quot;: &#91;&quot;G-047&quot;, &quot;G-049&quot;]}, {&quot;name&quot;: &quot;验收与整合&quot;, &quot;rule&quot;: &quot;测试层次、证据最小集和事实/选择的区分必须一起读；不存在用票数替代证据的入口。&quot;, &quot;units&quot;: &#91;&quot;I-003&quot;, &quot;G-070&quot;, &quot;G-072&quot;, &quot;G-075&quot;]}, {&quot;name&quot;: &quot;检查的反例与复核&quot;, &quot;rule&quot;: &quot;检验前提、控制面和判据本身；历史实例留作反证，不当作今天已复跑的结果。&quot;, &quot;units&quot;: &#91;&quot;G-014&quot;, &quot;G-077&quot;, &quot;G-104&quot;, &quot;G-105&quot;, &quot;G-106&quot;]}, {&quot;name&quot;: &quot;覆盖声明的写法&quot;, &quot;rule&quot;: &quot;区分查了、没查、不能排除以及三类未知；必须进入可复用规程，原作者未核清单只作带日期例证。&quot;, &quot;units&quot;: &#91;&quot;G-097&quot;]}]},
{&quot;path&quot;: &quot;playbooks/delivery.md&quot;, &quot;class&quot;: &quot;P&quot;, &quot;why&quot;: &quot;将完成判据置于写最终路径之前，将发布与 GC 置于其后；交付不是退出进程时顺手清理。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;完成与证据包&quot;, &quot;rule&quot;: &quot;先证明任务完成和跨仓交付满足条目要求；不以脚本退出码单独证明完成。&quot;, &quot;units&quot;: &#91;&quot;G-040&quot;, &quot;I-004&quot;]}, {&quot;name&quot;: &quot;发布与保留&quot;, &quot;rule&quot;: &quot;三个路径、发布动作、清理失败和 GC 明确顺序；进行中任务停止规程另见 execution。&quot;, &quot;units&quot;: &#91;&quot;G-043&quot;, &quot;G-033&quot;, &quot;G-044&quot;]}]},
{&quot;path&quot;: &quot;playbooks/maintenance.md&quot;, &quot;class&quot;: &quot;P&quot;, &quot;why&quot;: &quot;先续接同一个任务，再判断资产是否可迁移，最后用显式修订单处理内核；三者都保护跨会话的连续性。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;续接&quot;, &quot;rule&quot;: &quot;用于换会话仍可恢复真实任务上下文；不能把聊天摘要变成新的事实源。&quot;, &quot;units&quot;: &#91;&quot;G-088&quot;]}, {&quot;name&quot;: &quot;迁移与修订&quot;, &quot;rule&quot;: &quot;可复用删除门及内核修订步骤；G0–G5 的当前实施依赖留 work，不能删掉仍未满足的条件。&quot;, &quot;units&quot;: &#91;&quot;G-086&quot;, &quot;G-090&quot;]}]},
{&quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;class&quot;: &quot;P&quot;, &quot;why&quot;: &quot;定位/定档/裁量 → 工单与七环节 → 取件、判据、隔离 → 分环节细则 → 停止清理；完整保留以保持脚本接口和冻结引用。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;, &quot;units&quot;: &#91;&quot;P-001&quot;, &quot;P-002&quot;, &quot;P-003&quot;, &quot;P-004&quot;, &quot;P-005&quot;, &quot;P-006&quot;, &quot;P-007&quot;, &quot;P-008&quot;, &quot;P-009&quot;, &quot;P-010&quot;, &quot;P-011&quot;, &quot;P-012&quot;, &quot;P-013&quot;, &quot;P-014&quot;, &quot;P-015&quot;, &quot;P-016&quot;, &quot;P-017&quot;, &quot;P-018&quot;, &quot;P-019&quot;, &quot;P-020&quot;, &quot;P-021&quot;, &quot;P-022&quot;, &quot;P-023&quot;, &quot;P-024&quot;, &quot;P-025&quot;, &quot;P-026&quot;, &quot;P-027&quot;, &quot;P-028&quot;, &quot;P-029&quot;, &quot;P-030&quot;, &quot;P-031&quot;, &quot;P-032&quot;, &quot;P-033&quot;, &quot;P-034&quot;, &quot;P-035&quot;, &quot;P-036&quot;, &quot;P-037&quot;, &quot;P-038&quot;, &quot;P-039&quot;, &quot;P-040&quot;, &quot;P-041&quot;, &quot;P-042&quot;, &quot;P-043&quot;, &quot;P-044&quot;, &quot;P-045&quot;, &quot;P-046&quot;, &quot;P-047&quot;, &quot;P-048&quot;, &quot;P-049&quot;, &quot;P-050&quot;, &quot;P-051&quot;, &quot;P-052&quot;, &quot;P-053&quot;, &quot;P-054&quot;, &quot;P-055&quot;, &quot;P-056&quot;, &quot;P-057&quot;]}]},
{&quot;path&quot;: &quot;protocol/README.md&quot;, &quot;class&quot;: &quot;P&quot;, &quot;why&quot;: &quot;解释实现与规范必须共改，然后给设计约束、单一真源和已知不做；避免脚本使用者把欠账当能力。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;脚本接口及实现约束&quot;, &quot;rule&quot;: &quot;可执行接口、状态计算责任及已知限制；不收当轮执行日志。&quot;, &quot;units&quot;: &#91;&quot;T-001&quot;, &quot;T-002&quot;, &quot;T-003&quot;, &quot;T-004&quot;]}]},
{&quot;path&quot;: &quot;work/roadmap.md&quot;, &quot;class&quot;: &quot;W&quot;, &quot;why&quot;: &quot;先列产品阶段及各阶段输入，再列运行时从手工退出的依赖门；不凭时间顺序宣称依赖已满足。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;产品建设阶段&quot;, &quot;rule&quot;: &quot;要建什么及开工条件；含历史现状的段落按源日期读取，需要最新事实时另取证。&quot;, &quot;units&quot;: &#91;&quot;D-006&quot;, &quot;D-007&quot;, &quot;D-008&quot;, &quot;D-009&quot;]}, {&quot;name&quot;: &quot;运行时迁移顺序&quot;, &quot;rule&quot;: &quot;G0–G5 依赖及分组件退出门作为待实施路线；通用删除纪律引用 maintenance。&quot;, &quot;units&quot;: &#91;&quot;G-084&quot;, &quot;G-085&quot;]}]},
{&quot;path&quot;: &quot;work/delivery.md&quot;, &quot;class&quot;: &quot;W&quot;, &quot;why&quot;: &quot;保留产品任务及前置的原始次序，通用表单迁出后本文件只回答做哪项、依赖什么、怎么验收；旧框架路线按现行 guide 明确的处置存历史。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;产品任务&quot;, &quot;rule&quot;: &quot;阶段一空任务清单及阶段二/三前置完整保留；未决前不开工不能被空表覆盖检查掩盖。&quot;, &quot;units&quot;: &#91;&quot;I-006&quot;, &quot;I-007&quot;, &quot;I-008&quot;, &quot;I-009&quot;]}]},
{&quot;path&quot;: &quot;work/status.md&quot;, &quot;class&quot;: &quot;W&quot;, &quot;why&quot;: &quot;按观察日期记录产品阶段、就位能力和游标；更新状态不得顺手更新规范，旧框架路线的进度随旧计划存历史。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;产品状态&quot;, &quot;rule&quot;: &quot;阶段、已就位能力与任务游标是观察字段；不从没有调用推出不需要调用，也不将八月观察升级为今天现状。&quot;, &quot;units&quot;: &#91;&quot;H-002&quot;, &quot;H-003&quot;, &quot;H-010&quot;]}]},
{&quot;path&quot;: &quot;work/questions.md&quot;, &quot;class&quot;: &quot;W&quot;, &quot;why&quot;: &quot;先列阻塞产品任务的 U 项及已知输入，再列跨模块风险、未验证与文档待办；每项可被明确证据关闭。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;未决输入&quot;, &quot;rule&quot;: &quot;U1–U5 与其已知事实作为决策材料，不从已知字段推出方案已定。&quot;, &quot;units&quot;: &#91;&quot;H-004&quot;, &quot;H-005&quot;, &quot;H-006&quot;, &quot;H-007&quot;]}, {&quot;name&quot;: &quot;风险与验证债&quot;, &quot;rule&quot;: &quot;现有风险和 SDK 未验证清单先于开工；不能把列表存在当作验证完成。&quot;, &quot;units&quot;: &#91;&quot;G-087&quot;, &quot;G-089&quot;, &quot;H-013&quot;, &quot;H-009&quot;]}]},
{&quot;path&quot;: &quot;records/guide-history.md&quot;, &quot;class&quot;: &quot;R&quot;, &quot;why&quot;: &quot;将历史登记、介入实例、轨迹及旧路线按证据对象保存；已裁定设计边界在 foundation 保持现行效力，不在这里隐藏禁令。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;历史实测与实例&quot;, &quot;rule&quot;: &quot;五家取值、介入清单及轨迹读数各有环境和时点；查询今天能力必须另有当次证据。&quot;, &quot;units&quot;: &#91;&quot;G-027&quot;, &quot;G-062&quot;, &quot;G-076&quot;]}, {&quot;name&quot;: &quot;旧路线及当时进度&quot;, &quot;rule&quot;: &quot;G-094 已明确旧 R0–R5/S1 不作为现行路线；原实施表及旧进度完整保留供追溯，不能再以现在任务名义发出。&quot;, &quot;units&quot;: &#91;&quot;I-005&quot;, &quot;H-011&quot;, &quot;H-012&quot;]}]},
{&quot;path&quot;: &quot;records/guide-audit.md&quot;, &quot;class&quot;: &quot;R&quot;, &quot;why&quot;: &quot;按核验发生顺序保存范围、未核项、吸收与采用审计，最后附完整 294 行旧映射；审计的限制必须和通过项相邻。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;核验声明与补吸收&quot;, &quot;rule&quot;: &quot;原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。&quot;, &quot;units&quot;: &#91;&quot;G-095&quot;, &quot;G-096&quot;, &quot;G-098&quot;, &quot;G-099&quot;, &quot;G-100&quot;, &quot;G-101&quot;]}, {&quot;name&quot;: &quot;历史源落点收据&quot;, &quot;rule&quot;: &quot;完整保留既有 294 行；它不是本次 260 行的替代分母，也不是全部正文已验的证明。&quot;, &quot;units&quot;: &#91;&quot;G-102&quot;]}]},
{&quot;path&quot;: &quot;records/migration-context.md&quot;, &quot;class&quot;: &quot;R&quot;, &quot;why&quot;: &quot;旧文标题、前言、目录与阅读路线属于旧排布的上下文；保留它们让源文件能完整重建，禁止它们继续指挥新入口。&quot;, &quot;groups&quot;: &#91;{&quot;name&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;, &quot;units&quot;: &#91;&quot;G-001&quot;, &quot;G-005&quot;, &quot;G-006&quot;, &quot;G-015&quot;, &quot;G-028&quot;, &quot;G-051&quot;, &quot;G-065&quot;, &quot;G-079&quot;, &quot;G-083&quot;]}, {&quot;name&quot;: &quot;旧入口上下文&quot;, &quot;rule&quot;: &quot;旧计划/交接前言及 README 旧索引原文留证；新的入口由装配配方生成。&quot;, &quot;units&quot;: &#91;&quot;D-001&quot;, &quot;I-001&quot;, &quot;H-001&quot;, &quot;M-001&quot;, &quot;M-002&quot;]}]}
],
&quot;guide_recipe&quot;: &#91;
&quot;specs/foundation.md&quot;,
&quot;working/request-lifecycle.md&quot;,
&quot;constraints.md&quot;,
&quot;specs/runtime.md&quot;,
&quot;specs/executor.md&quot;,
&quot;specs/authority.md&quot;,
&quot;specs/evidence.md&quot;,
&quot;playbooks/intake.md&quot;,
&quot;playbooks/execution.md&quot;,
&quot;playbooks/review.md&quot;,
&quot;protocol/round-protocol.md&quot;,
&quot;protocol/README.md&quot;,
&quot;playbooks/delivery.md&quot;,
&quot;playbooks/maintenance.md&quot;
],
&quot;units&quot;: &#91;
{&quot;id&quot;: &quot;K-001&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 12, &quot;title&quot;: &quot;# Request Lifecycle：产品请求生命周期合同&quot;, &quot;sha256&quot;: &quot;e84e95c3e15e6a0008a8b3f207579f0f49f8e3349c3238eed22f4da6acec9485&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-002&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 13, &quot;end&quot;: 14, &quot;title&quot;: &quot;## 0. 规范边界与条款筛选&quot;, &quot;sha256&quot;: &quot;5cfe419678951f3901640af7eaa1582ed8a0f4c514a49b3b529ada8be10d7de6&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-003&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 15, &quot;end&quot;: 28, &quot;title&quot;: &quot;### 0.1 只收产品要求&quot;, &quot;sha256&quot;: &quot;211072c0ddfc924c17d9948d62738dd9b1b2e3f92b99129e47b38bbb05a3f16f&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-004&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 29, &quot;end&quot;: 51, &quot;title&quot;: &quot;### 0.2 本文负责什么&quot;, &quot;sha256&quot;: &quot;958c766beb0890138ae1612e0e1940414ad5f7b472b0a2f3d9915e66561db657&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-005&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 52, &quot;end&quot;: 57, &quot;title&quot;: &quot;### 0.3 规范用语&quot;, &quot;sha256&quot;: &quot;1af8de7a5036db3453fa433cd82dd811336de189a640438bd05fa8f5c493bf94&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-006&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 58, &quot;end&quot;: 91, &quot;title&quot;: &quot;## 1. 生命周期全景&quot;, &quot;sha256&quot;: &quot;e5a930a2a455430976e0620e2518d5774a027c797b0e7b8d32a15e22b63e5c76&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-007&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 92, &quot;end&quot;: 105, &quot;title&quot;: &quot;## 2. 核心对象&quot;, &quot;sha256&quot;: &quot;f6b8bb799c601ff50ed905cac5289a6d8959768314d95f86c9f698db0fbbd21b&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-008&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 106, &quot;end&quot;: 119, &quot;title&quot;: &quot;### 2.1 Task 不等于 Attempt&quot;, &quot;sha256&quot;: &quot;68de355f80a0ee318a752de42963b3a0bc9afdbbdc8077837195633d4b608ebb&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-009&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 120, &quot;end&quot;: 126, &quot;title&quot;: &quot;### 2.2 Submission 不一定产生 Task&quot;, &quot;sha256&quot;: &quot;040aaf38d70c36e15992845d5b0b18a52c14f5245c537afce91fe5aaebd965d1&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-010&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 127, &quot;end&quot;: 128, &quot;title&quot;: &quot;## 3. Task 契约&quot;, &quot;sha256&quot;: &quot;1a565d2cc3e920158817173d07771fa43d7724c583271465ed1771c114f6bd45&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-011&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 129, &quot;end&quot;: 146, &quot;title&quot;: &quot;### 3.1 提交信封&quot;, &quot;sha256&quot;: &quot;5cf8054fd131bf1557cbbe45a539773ea9eae1cfe1448717bead75bb3460a6ab&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-012&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 147, &quot;end&quot;: 165, &quot;title&quot;: &quot;### 3.2 持久化主档&quot;, &quot;sha256&quot;: &quot;28d65894c67ce592d5baa1cbef11a9b3109242e55276427df331f039393fb0e1&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-013&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 166, &quot;end&quot;: 182, &quot;title&quot;: &quot;### 3.3 解释、边界与完成契约&quot;, &quot;sha256&quot;: &quot;e58e503a626c389a71c638addcb011e59c973f734b77618e1c550076091de786&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-014&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 183, &quot;end&quot;: 202, &quot;title&quot;: &quot;### 3.4 最终结果信封&quot;, &quot;sha256&quot;: &quot;d99e32c277a9a4a7a1fcb4b44003f96b00caf194079ba0ce4b21ec180fcbe11b&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-015&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 203, &quot;end&quot;: 204, &quot;title&quot;: &quot;## 4. 两层状态机&quot;, &quot;sha256&quot;: &quot;f27a898b5d4f1d89c7f6c176050863d939c622b63f850e5e476b02a177598213&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-016&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 205, &quot;end&quot;: 246, &quot;title&quot;: &quot;### 4.1 Task 状态机&quot;, &quot;sha256&quot;: &quot;68ddaa272beefc3c2096e2ea006d0ab584daceb15abe57f8cc9b7975e0d63b4f&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-017&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 247, &quot;end&quot;: 278, &quot;title&quot;: &quot;### 4.2 WAITING 与 Interaction&quot;, &quot;sha256&quot;: &quot;f0db7217254c0abd6ef8fc3f4b43dc2e8df48014e230fc3b31a07068c848446c&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-018&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 279, &quot;end&quot;: 291, &quot;title&quot;: &quot;### 4.3 取消意图与终态&quot;, &quot;sha256&quot;: &quot;432df1f5f733fbed31794061894e9fcdf0b90dfc041c80b74804a930ad120862&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-019&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 292, &quot;end&quot;: 303, &quot;title&quot;: &quot;### 4.4 终态、刷新与重新处理&quot;, &quot;sha256&quot;: &quot;d8bdcd4d224aac927a6237d32bae6ce2962d58153cb9bc9a433d23031343a417&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-020&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 304, &quot;end&quot;: 345, &quot;title&quot;: &quot;### 4.5 Attempt / Run 状态机&quot;, &quot;sha256&quot;: &quot;808297a3b02fda24da5af6cc6c790b3ed1faf33d05472b1e6a6c783da802fea1&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-021&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 346, &quot;end&quot;: 350, &quot;title&quot;: &quot;## 5. 七阶段产品功能&quot;, &quot;sha256&quot;: &quot;6658f2ea1355a2f23da8ddc6dbe5315c88af64c5c37ed404617e9e55133bcb05&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-022&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 351, &quot;end&quot;: 359, &quot;title&quot;: &quot;### 5.1 提交（前端）&quot;, &quot;sha256&quot;: &quot;a75d9646a3af809389cc715f170ab52b7a46e07e924382494843c7d9ffe04310&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-023&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 360, &quot;end&quot;: 368, &quot;title&quot;: &quot;### 5.2 受理与校验（后端）&quot;, &quot;sha256&quot;: &quot;df392b9e69a88a2f9a77f914965bd314d8fbc7a51a43e252cc7c0429b162a670&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-024&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 369, &quot;end&quot;: 376, &quot;title&quot;: &quot;### 5.3 排队与可靠投递&quot;, &quot;sha256&quot;: &quot;66603ad94db307e83aca7dd419564da869113934d365c3a637968d7419e5ffe0&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-025&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 377, &quot;end&quot;: 390, &quot;title&quot;: &quot;### 5.4 Agent 执行&quot;, &quot;sha256&quot;: &quot;d9cd4a2113f1d16cff949e6468b336d43e02692d2418b9042920e021d775aeb5&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-026&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 391, &quot;end&quot;: 397, &quot;title&quot;: &quot;### 5.5 中断、批准与恢复&quot;, &quot;sha256&quot;: &quot;576c123269044622ed1529a8d7f6270461de4f6091cce9a463c37947f76d5526&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-027&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 398, &quot;end&quot;: 412, &quot;title&quot;: &quot;### 5.6 验收与完成提交&quot;, &quot;sha256&quot;: &quot;1b26545b3839a16d0c9022c1076e4dd5fee7a7168b92e753835521e66396cd80&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-028&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 413, &quot;end&quot;: 441, &quot;title&quot;: &quot;### 5.7 返回前端、失败与重试&quot;, &quot;sha256&quot;: &quot;7992ed7e8881770b5e3df18484ceaa605c8b5f957d66a0207adf3019353cae47&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-029&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 442, &quot;end&quot;: 443, &quot;title&quot;: &quot;## 6. 跨进程纪律与持久化账&quot;, &quot;sha256&quot;: &quot;60fe9f1ac3243ca03b5401a6e5039bd5945982e455b0ca126a44e6fa5c7a24d1&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-030&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 444, &quot;end&quot;: 466, &quot;title&quot;: &quot;### 6.1 全程不变量&quot;, &quot;sha256&quot;: &quot;692226447cb805ee82829f6a302186067620042cd98b25210674fa2db9dd1a33&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-031&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 467, &quot;end&quot;: 484, &quot;title&quot;: &quot;### 6.2 持久化记录&quot;, &quot;sha256&quot;: &quot;0e4ffe87700ecc51d4a2edde73176bfd2b84644b6dd013917d898ac931fa1b83&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-032&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 485, &quot;end&quot;: 486, &quot;title&quot;: &quot;## 7. Profile、Artifact 与扩展&quot;, &quot;sha256&quot;: &quot;802122c57f45437e8ec585ed0377e810dc6cf45e54314dffc77e83fcc28a102f&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-033&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 487, &quot;end&quot;: 507, &quot;title&quot;: &quot;### 7.1 Task Profile 与 Agent Profile&quot;, &quot;sha256&quot;: &quot;5f5ba765e84074b57d255760a180633bf7f7a32e5e178f9ac7fd131461176b81&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-034&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 508, &quot;end&quot;: 519, &quot;title&quot;: &quot;### 7.2 Profile 示例&quot;, &quot;sha256&quot;: &quot;a33d66afd49cccd4a1de0cbb8a90848a0cd8f264ce5316d3feee855b0f0aee8f&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-035&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 520, &quot;end&quot;: 549, &quot;title&quot;: &quot;## 8. 子 Task 与依赖编排&quot;, &quot;sha256&quot;: &quot;2deff7b7ad65de9a4b2c0ff16414a8edac15399e9ad25e6970235ffc4c47b752&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-036&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 550, &quot;end&quot;: 565, &quot;title&quot;: &quot;## 9. 前端、后端与 Agent 责任投影&quot;, &quot;sha256&quot;: &quot;1a2b24b6d0621edee2a82cca7e27f441709cd424ff74eb0749f1b8e93a43e17e&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-037&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 566, &quot;end&quot;: 585, &quot;title&quot;: &quot;## 10. 反模式&quot;, &quot;sha256&quot;: &quot;098396ef21c4153239f1f6eb31195cb4ee962e56a36d8d839f97f28630bb6d20&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-038&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 586, &quot;end&quot;: 622, &quot;title&quot;: &quot;## 11. 产品验收矩阵&quot;, &quot;sha256&quot;: &quot;fd899413db5cbb36b02437390e664ed32c9068be790f9323b545b4681af7c82f&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-039&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 623, &quot;end&quot;: 624, &quot;title&quot;: &quot;## 12. 修订、落地与参考材料&quot;, &quot;sha256&quot;: &quot;8520f5ac1c4f79c848be2656f631947b928c7ce687bcda7df75b5309c34a426b&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-040&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 625, &quot;end&quot;: 636, &quot;title&quot;: &quot;### 12.1 修订纪律&quot;, &quot;sha256&quot;: &quot;1d9f99c71d9a8c53368a3c9bed88406ee6d174f20b28d55c5e9aba56a9ae830d&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-041&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 637, &quot;end&quot;: 642, &quot;title&quot;: &quot;### 12.2 参考材料边界&quot;, &quot;sha256&quot;: &quot;941c9fc4553fef1ba75500df8ce50b82aada812bde19ee9a3f66f847beec05c8&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;K-042&quot;, &quot;path&quot;: &quot;working/request-lifecycle.md&quot;, &quot;line&quot;: 643, &quot;end&quot;: 647, &quot;title&quot;: &quot;### 12.3 生效边界&quot;, &quot;sha256&quot;: &quot;33c436a4ad278c3a5e92f891732e405bf0bff846399df438eeaf9b132271df4d&quot;, &quot;target&quot;: &quot;working/request-lifecycle.md&quot;, &quot;group&quot;: &quot;合约全文&quot;, &quot;rule&quot;: &quot;只收必须由产品实现或自动验收兑现的规则；开发步骤排除，例外与修订边界随合约保留。&quot;},
{&quot;id&quot;: &quot;G-001&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 22, &quot;title&quot;: &quot;# Agent 开发指导：一个产品运行时，一套开发纪律&quot;, &quot;sha256&quot;: &quot;390918bc145a376746f0eebd929e1b74260a6fe874e567cdabc4c699a69a18b4&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-002&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 23, &quot;end&quot;: 51, &quot;title&quot;: &quot;## 0. 先读结论&quot;, &quot;sha256&quot;: &quot;44a84cbd2de2a8ada67fd38f0ec3e737f5bcf12145e561cc190e83ce1421c122&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;},
{&quot;id&quot;: &quot;G-003&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 52, &quot;end&quot;: 69, &quot;title&quot;: &quot;### 0.0 原来是什么样，为什么非改不可&quot;, &quot;sha256&quot;: &quot;9946601352fc880ddf484049f1d74847d851a79ff5df073f881374e94579713e&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;},
{&quot;id&quot;: &quot;G-004&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 70, &quot;end&quot;: 86, &quot;title&quot;: &quot;### 0.1 文档边界&quot;, &quot;sha256&quot;: &quot;e5e1ab2117c5ec746ab76e0f545fefe1e8477e1ad31647dc514df88c4eae6d4e&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;},
{&quot;id&quot;: &quot;G-005&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 87, &quot;end&quot;: 105, &quot;title&quot;: &quot;### 0.2 为什么分成这些章&quot;, &quot;sha256&quot;: &quot;f1702dee9a38fff185c71aca821865bbbdd21126c60c133c0c28db989af0fbea&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-006&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 106, &quot;end&quot;: 125, &quot;title&quot;: &quot;### 0.3 按工作阶段阅读，不按历史版本阅读&quot;, &quot;sha256&quot;: &quot;38acb4925ce92c7f030b712b222c3deb1b1064bb996995fd771c314c4f86ad5b&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-007&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 126, &quot;end&quot;: 127, &quot;title&quot;: &quot;## 1. 不可变的契约与边界&quot;, &quot;sha256&quot;: &quot;fd773b00e856a9a6579a9674695912ee15f55fa2b63ef60651f821afc3a98db7&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;},
{&quot;id&quot;: &quot;G-008&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 128, &quot;end&quot;: 142, &quot;title&quot;: &quot;### 1.1 唯一产品内核&quot;, &quot;sha256&quot;: &quot;be7a7922e6be129918031ead9897db037299d4c4fbc5b8e6408c82c1c0c48003&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;},
{&quot;id&quot;: &quot;G-009&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 143, &quot;end&quot;: 150, &quot;title&quot;: &quot;### 1.2 四本账与单一权威写入面&quot;, &quot;sha256&quot;: &quot;c57080db28748eafe1fd3fa8127ac9691474ca808ca05f6480008961b0581d44&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;持久责任与组件&quot;, &quot;rule&quot;: &quot;跨进程仍须成立的四账、组件责任及通用/专用界线在此；SDK 私有细节排除。&quot;},
{&quot;id&quot;: &quot;G-010&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 151, &quot;end&quot;: 163, &quot;title&quot;: &quot;### 1.3 Agent 硬约束自检&quot;, &quot;sha256&quot;: &quot;d35e3c4f53319ad4f40f6760f0f23b226d37555d675d16915aa98ee19aedd820&quot;, &quot;target&quot;: &quot;playbooks/intake.md&quot;, &quot;group&quot;: &quot;自检与受理&quot;, &quot;rule&quot;: &quot;提交任务前的相关约束、可信输入、边界和默认值冻结；系统原则引用 foundation，不在此新立。&quot;},
{&quot;id&quot;: &quot;G-011&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 164, &quot;end&quot;: 170, &quot;title&quot;: &quot;### 1.4 开发验收不可外推&quot;, &quot;sha256&quot;: &quot;754904ef311d2d718d779665de7298d987cc6829b2c50e9957afb254d84f2f7b&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;},
{&quot;id&quot;: &quot;G-012&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 171, &quot;end&quot;: 186, &quot;title&quot;: &quot;### 1.5 执行者的共同纪律&quot;, &quot;sha256&quot;: &quot;ee67b25ecc07b1e3fc56489cde893d6e61930a1974ae41328446f2cf381a64a6&quot;, &quot;target&quot;: &quot;playbooks/intake.md&quot;, &quot;group&quot;: &quot;自检与受理&quot;, &quot;rule&quot;: &quot;提交任务前的相关约束、可信输入、边界和默认值冻结；系统原则引用 foundation，不在此新立。&quot;},
{&quot;id&quot;: &quot;G-013&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 187, &quot;end&quot;: 212, &quot;title&quot;: &quot;### 1.6 七条设计原则&quot;, &quot;sha256&quot;: &quot;ffb90d1095ec3ca2b57817132bfc84e073f058c662deca4cd6e60385a7fda406&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;边界与原则&quot;, &quot;rule&quot;: &quot;回答哪些概念及权威不能再造；部署读数和本次任务步骤不进入本组。&quot;},
{&quot;id&quot;: &quot;G-014&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 213, &quot;end&quot;: 234, &quot;title&quot;: &quot;### 1.7 先核前提，也核控制面&quot;, &quot;sha256&quot;: &quot;a76bb2f085b13bbb4d867b4ffbe70d4f34ecefc6712e917127e6840bfdb936c3&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;检查的反例与复核&quot;, &quot;rule&quot;: &quot;检验前提、控制面和判据本身；历史实例留作反证，不当作今天已复跑的结果。&quot;},
{&quot;id&quot;: &quot;G-015&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 235, &quot;end&quot;: 236, &quot;title&quot;: &quot;## 2. 一个运行时的结构&quot;, &quot;sha256&quot;: &quot;9350e03d2bf45b7f600fbd9be1a44ef63d6fd61c9cf6fe21cc5ad50bbfd262e9&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-016&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 237, &quot;end&quot;: 254, &quot;title&quot;: &quot;### 2.1 确定性组件与适配层&quot;, &quot;sha256&quot;: &quot;66e651c3a757505f7fbca46df9264324092db8bdc0601cc2c7b8af2e650efcf1&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;持久责任与组件&quot;, &quot;rule&quot;: &quot;跨进程仍须成立的四账、组件责任及通用/专用界线在此；SDK 私有细节排除。&quot;},
{&quot;id&quot;: &quot;G-017&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 255, &quot;end&quot;: 268, &quot;title&quot;: &quot;### 2.2 内容角色&quot;, &quot;sha256&quot;: &quot;d4fd6175d2bbb992c417d5469299a867e549d69d044e656acf8e23899a4e37b3&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;角色与派工契约&quot;, &quot;rule&quot;: &quot;输入是任务类型、执行能力及角色关系；批准权本体另见 authority，历史五家取值留记录。&quot;},
{&quot;id&quot;: &quot;G-018&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 269, &quot;end&quot;: 292, &quot;title&quot;: &quot;### 2.3 Task Profile 与 Agent Profile&quot;, &quot;sha256&quot;: &quot;f4efd211f757caa6f9109cacc574d9a29844baf1c45a725016dfaad31253d346&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;角色与派工契约&quot;, &quot;rule&quot;: &quot;输入是任务类型、执行能力及角色关系；批准权本体另见 authority，历史五家取值留记录。&quot;},
{&quot;id&quot;: &quot;G-019&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 293, &quot;end&quot;: 346, &quot;title&quot;: &quot;### 2.4 &#96;dev.change/1&#96; 工单&quot;, &quot;sha256&quot;: &quot;c5358a52d7cd89d987be6c449a662d99f28ecbd9734ff00504690cfbf9fc7590&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;角色与派工契约&quot;, &quot;rule&quot;: &quot;输入是任务类型、执行能力及角色关系；批准权本体另见 authority，历史五家取值留记录。&quot;},
{&quot;id&quot;: &quot;G-020&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 347, &quot;end&quot;: 353, &quot;title&quot;: &quot;### 2.5 路由只读可判字段&quot;, &quot;sha256&quot;: &quot;eab2e84cad7e5a721a9da65844b5be76eb9afdfbc9562dfaa00636b879785532&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;角色与派工契约&quot;, &quot;rule&quot;: &quot;输入是任务类型、执行能力及角色关系；批准权本体另见 authority，历史五家取值留记录。&quot;},
{&quot;id&quot;: &quot;G-021&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 354, &quot;end&quot;: 407, &quot;title&quot;: &quot;### 2.6 执行层：租用什么、自建什么&quot;, &quot;sha256&quot;: &quot;560a93f2d895995d98c5d1459b5ad15a61cadff793bf8561e9cd19a0be8f934b&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;租用边界与能力&quot;, &quot;rule&quot;: &quot;执行原语的租/建选择、SDK 范围和版本限定；历史读数不据此升格为今天实测。&quot;},
{&quot;id&quot;: &quot;G-022&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 408, &quot;end&quot;: 432, &quot;title&quot;: &quot;### 2.7 两个官方 SDK：两个轴、非对称能力&quot;, &quot;sha256&quot;: &quot;d6e35274097f62492a8b7df4084d45cae005e0e45659c381e3d143a56dcc0c48&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;租用边界与能力&quot;, &quot;rule&quot;: &quot;执行原语的租/建选择、SDK 范围和版本限定；历史读数不据此升格为今天实测。&quot;},
{&quot;id&quot;: &quot;G-023&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 433, &quot;end&quot;: 482, &quot;title&quot;: &quot;### 2.8 统一执行 Port 与三态能力探针&quot;, &quot;sha256&quot;: &quot;39308e39f9835449230564aaf4c73abe64c0e169185e88a853e08b16e1fb2abe&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;Port 与适配门&quot;, &quot;rule&quot;: &quot;签名、能力探针和前置条件必须相邻；不收领域业务签名或具体派工进度。&quot;},
{&quot;id&quot;: &quot;G-024&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 483, &quot;end&quot;: 510, &quot;title&quot;: &quot;### 2.9 Harness 腿的前置门禁与过渡补法&quot;, &quot;sha256&quot;: &quot;dc29499e912b2ba60f17e3978fb0580b29e7f05b06f6f0ea8cb8d564a9b23443&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;Port 与适配门&quot;, &quot;rule&quot;: &quot;签名、能力探针和前置条件必须相邻；不收领域业务签名或具体派工进度。&quot;},
{&quot;id&quot;: &quot;G-025&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 511, &quot;end&quot;: 547, &quot;title&quot;: &quot;### 2.10 双 runtime 的部署、进程与恢复&quot;, &quot;sha256&quot;: &quot;08de66f97522bb15be6b6b4575bd75f686ef307b75515c51da6553a05757265f&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;两腿恢复与部署&quot;, &quot;rule&quot;: &quot;同一执行器在进程生命周期中的恢复差异和接口落实矩阵；批准权限公式由 authority 持有。&quot;},
{&quot;id&quot;: &quot;G-026&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 548, &quot;end&quot;: 586, &quot;title&quot;: &quot;### 2.11 派工契约、角色补充与隔离的诚实边界&quot;, &quot;sha256&quot;: &quot;ca702ff8bddc29ee4b0b3395a511fbafbf969db20d212866bac3c82993c58ee4&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;角色与派工契约&quot;, &quot;rule&quot;: &quot;输入是任务类型、执行能力及角色关系；批准权本体另见 authority，历史五家取值留记录。&quot;},
{&quot;id&quot;: &quot;G-027&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 587, &quot;end&quot;: 648, &quot;title&quot;: &quot;### 2.12 五家 Agent Profile 的历史取值示例&quot;, &quot;sha256&quot;: &quot;4f5fdc34e7d7d17a078d2e4ce8d54022a735ae0b49e2cf5fe13b8ee36264cfba&quot;, &quot;target&quot;: &quot;records/guide-history.md&quot;, &quot;group&quot;: &quot;历史实测与实例&quot;, &quot;rule&quot;: &quot;五家取值、介入清单及轨迹读数各有环境和时点；查询今天能力必须另有当次证据。&quot;},
{&quot;id&quot;: &quot;G-028&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 649, &quot;end&quot;: 650, &quot;title&quot;: &quot;## 3. 一次开发 Task 怎样执行&quot;, &quot;sha256&quot;: &quot;7f1c8bb4a72ff2a2e3fff986199e95eab3dcadd3676deb3240b564416f37167c&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-029&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 651, &quot;end&quot;: 681, &quot;title&quot;: &quot;### 3.1 受理与冻结&quot;, &quot;sha256&quot;: &quot;0e94a304664ff0e9747c90bf5b37844ceda387296036ff36750fc5ef8358bf39&quot;, &quot;target&quot;: &quot;playbooks/intake.md&quot;, &quot;group&quot;: &quot;自检与受理&quot;, &quot;rule&quot;: &quot;提交任务前的相关约束、可信输入、边界和默认值冻结；系统原则引用 foundation，不在此新立。&quot;},
{&quot;id&quot;: &quot;G-030&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 682, &quot;end&quot;: 703, &quot;title&quot;: &quot;### 3.2 工作区供给&quot;, &quot;sha256&quot;: &quot;2f6020fca14c794bf0c03ccdfd8a6299d77b952f6c954fde02d8116508056d5a&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;工作区准备&quot;, &quot;rule&quot;: &quot;满足开工需要的目录、Git 元数据及可写性验证；权限授予公式不在此改。&quot;},
{&quot;id&quot;: &quot;G-031&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 704, &quot;end&quot;: 740, &quot;title&quot;: &quot;### 3.3 Attempt 与状态投影&quot;, &quot;sha256&quot;: &quot;6af778ffbd07bed1ddfebcc113999de3e1a6bfcef77f35c09dc6d895b5989fa3&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;状态和载体投影&quot;, &quot;rule&quot;: &quot;解释现有内核对象如何映射开发载体，不能修改内核状态或以阶段名再造状态机。&quot;},
{&quot;id&quot;: &quot;G-032&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 741, &quot;end&quot;: 766, &quot;title&quot;: &quot;### 3.4 T0/T1/T2 不是三套状态机&quot;, &quot;sha256&quot;: &quot;c2f804993f3cafd33dd851db0a0e9804a0e9cc70a2e0ab01eff2c002e0d1d23e&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;状态和载体投影&quot;, &quot;rule&quot;: &quot;解释现有内核对象如何映射开发载体，不能修改内核状态或以阶段名再造状态机。&quot;},
{&quot;id&quot;: &quot;G-033&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 767, &quot;end&quot;: 781, &quot;title&quot;: &quot;### 3.5 交付、清理和恢复&quot;, &quot;sha256&quot;: &quot;8627c4ddde0c570cfe17bb68388093ac245731bc8910b56be3b3e3b6da6dda53&quot;, &quot;target&quot;: &quot;playbooks/delivery.md&quot;, &quot;group&quot;: &quot;发布与保留&quot;, &quot;rule&quot;: &quot;三个路径、发布动作、清理失败和 GC 明确顺序；进行中任务停止规程另见 execution。&quot;},
{&quot;id&quot;: &quot;G-034&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 782, &quot;end&quot;: 821, &quot;title&quot;: &quot;### 3.6 私有地产生，单写者发布&quot;, &quot;sha256&quot;: &quot;94ec95396cbb2df8acf50a28e4a32cc6f8ec27f2f2e7ffbbd4395cec98ca2d13&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;写入与并发&quot;, &quot;rule&quot;: &quot;先隔离和单写者，再物化/写前门，最后按冲突场景处置；结果发布步骤另见 delivery。&quot;},
{&quot;id&quot;: &quot;G-035&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 822, &quot;end&quot;: 862, &quot;title&quot;: &quot;### 3.7 并发场景处置表&quot;, &quot;sha256&quot;: &quot;d978783d7cdd3473f409a694a7bddd1ecfec8fc881d8717e1273f108ced5441f&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;写入与并发&quot;, &quot;rule&quot;: &quot;先隔离和单写者，再物化/写前门，最后按冲突场景处置；结果发布步骤另见 delivery。&quot;},
{&quot;id&quot;: &quot;G-036&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 863, &quot;end&quot;: 892, &quot;title&quot;: &quot;### 3.8 覆盖或来源不明时的事故规程&quot;, &quot;sha256&quot;: &quot;ed2f923f74dfcd7b77d60e3d121ea7a3a58b81f3dbedc356ef9d02a27706a26b&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;写入与并发&quot;, &quot;rule&quot;: &quot;先隔离和单写者，再物化/写前门，最后按冲突场景处置；结果发布步骤另见 delivery。&quot;},
{&quot;id&quot;: &quot;G-037&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 893, &quot;end&quot;: 913, &quot;title&quot;: &quot;### 3.9 冻结、迟到与取消&quot;, &quot;sha256&quot;: &quot;bb61516bfa712e89efdafac5e0308c04c34edfb2e14239bf2b0ba1e24482154f&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;停止与恢复入口&quot;, &quot;rule&quot;: &quot;取消、迟到、超时、成本上限和回退共同决定何时停止；跨会话完整记录属于 maintenance。&quot;},
{&quot;id&quot;: &quot;G-038&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 914, &quot;end&quot;: 968, &quot;title&quot;: &quot;### 3.10 物化门禁与写入前门禁&quot;, &quot;sha256&quot;: &quot;0287133295fd64fc120c868734720e1001ea3b7ef76f0050a210e4514a6d453d&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;写入与并发&quot;, &quot;rule&quot;: &quot;先隔离和单写者，再物化/写前门，最后按冲突场景处置；结果发布步骤另见 delivery。&quot;},
{&quot;id&quot;: &quot;G-039&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 969, &quot;end&quot;: 987, &quot;title&quot;: &quot;### 3.11 候选状态机&quot;, &quot;sha256&quot;: &quot;e5748c8ace2b65e23a294b63ccaa5585ff25a9746847ab6a454914cf0d6bb484&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;状态和载体投影&quot;, &quot;rule&quot;: &quot;解释现有内核对象如何映射开发载体，不能修改内核状态或以阶段名再造状态机。&quot;},
{&quot;id&quot;: &quot;G-040&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 988, &quot;end&quot;: 1008, &quot;title&quot;: &quot;### 3.12 完成判据&quot;, &quot;sha256&quot;: &quot;4f741d49d296371394e3dab53fdbccc1849ae2f28efd9d77e9b23b68db599a31&quot;, &quot;target&quot;: &quot;playbooks/delivery.md&quot;, &quot;group&quot;: &quot;完成与证据包&quot;, &quot;rule&quot;: &quot;先证明任务完成和跨仓交付满足条目要求；不以脚本退出码单独证明完成。&quot;},
{&quot;id&quot;: &quot;G-041&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1009, &quot;end&quot;: 1041, &quot;title&quot;: &quot;### 3.13 执行形态、停止规则与成本&quot;, &quot;sha256&quot;: &quot;16e8e7631c81e3edee54124fdfb72ab85b66a634692ef66dd3ba5ca026814ca7&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;停止与恢复入口&quot;, &quot;rule&quot;: &quot;取消、迟到、超时、成本上限和回退共同决定何时停止；跨会话完整记录属于 maintenance。&quot;},
{&quot;id&quot;: &quot;G-042&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1042, &quot;end&quot;: 1054, &quot;title&quot;: &quot;### 3.14 建立 worktree 的细则&quot;, &quot;sha256&quot;: &quot;f1d246f7a14f983e5a815f6f7b8916e60140cfb99fe19cfc872a6e22f3a8f2b9&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;工作区准备&quot;, &quot;rule&quot;: &quot;满足开工需要的目录、Git 元数据及可写性验证；权限授予公式不在此改。&quot;},
{&quot;id&quot;: &quot;G-043&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1055, &quot;end&quot;: 1077, &quot;title&quot;: &quot;### 3.15 发布协议：三个路径不是一个&quot;, &quot;sha256&quot;: &quot;4f09aeba0065f8045a94dc22065670208adf84af2a6184df0487983daa92334c&quot;, &quot;target&quot;: &quot;playbooks/delivery.md&quot;, &quot;group&quot;: &quot;发布与保留&quot;, &quot;rule&quot;: &quot;三个路径、发布动作、清理失败和 GC 明确顺序；进行中任务停止规程另见 execution。&quot;},
{&quot;id&quot;: &quot;G-044&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1078, &quot;end&quot;: 1092, &quot;title&quot;: &quot;### 3.16 保留与垃圾回收&quot;, &quot;sha256&quot;: &quot;8a8209e1eadd334cc1899b9a6849716663ec3b4dfff7ea2e45545f71e3a60b5e&quot;, &quot;target&quot;: &quot;playbooks/delivery.md&quot;, &quot;group&quot;: &quot;发布与保留&quot;, &quot;rule&quot;: &quot;三个路径、发布动作、清理失败和 GC 明确顺序；进行中任务停止规程另见 execution。&quot;},
{&quot;id&quot;: &quot;G-045&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1093, &quot;end&quot;: 1113, &quot;title&quot;: &quot;### 3.17 内核对象 ↔ 开发载体对照&quot;, &quot;sha256&quot;: &quot;7f63cbae59d6107cdc55039fc16ebd21c00dbe48abd56b1fbb33e0bc08316df6&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;状态和载体投影&quot;, &quot;rule&quot;: &quot;解释现有内核对象如何映射开发载体，不能修改内核状态或以阶段名再造状态机。&quot;},
{&quot;id&quot;: &quot;G-046&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1114, &quot;end&quot;: 1130, &quot;title&quot;: &quot;### 3.18 状态脚本的硬要求&quot;, &quot;sha256&quot;: &quot;4f2f1aded33af1984c612bcbe9e4a0e87e5b1a087a8394dde07bea17a53f4085&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;状态和载体投影&quot;, &quot;rule&quot;: &quot;解释现有内核对象如何映射开发载体，不能修改内核状态或以阶段名再造状态机。&quot;},
{&quot;id&quot;: &quot;G-047&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1131, &quot;end&quot;: 1168, &quot;title&quot;: &quot;### 3.19 T2 七环节的操作闭环&quot;, &quot;sha256&quot;: &quot;9a75c4f5c2881bf38f7c6be38a7b1d4df0a406c0834a8050f41b68beea14c609&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;七环节操作接口&quot;, &quot;rule&quot;: &quot;任务尺度的流程串联及取件操作；保留 protocol 权威声明，本组不成为另一套七环节规则。&quot;},
{&quot;id&quot;: &quot;G-048&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1169, &quot;end&quot;: 1198, &quot;title&quot;: &quot;### 3.20 工作区能写，不代表 Git 能提交&quot;, &quot;sha256&quot;: &quot;fcb44fe363672dc1e9c8228a92cbeddcb246739f4c43f474933a84c60a981f56&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;工作区准备&quot;, &quot;rule&quot;: &quot;满足开工需要的目录、Git 元数据及可写性验证；权限授予公式不在此改。&quot;},
{&quot;id&quot;: &quot;G-049&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1199, &quot;end&quot;: 1223, &quot;title&quot;: &quot;### 3.21 通知、取件与人的检视面&quot;, &quot;sha256&quot;: &quot;48277b1472368a291220a2328bd092c834e4e957469070a731b5b1a7f363ff58&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;七环节操作接口&quot;, &quot;rule&quot;: &quot;任务尺度的流程串联及取件操作；保留 protocol 权威声明，本组不成为另一套七环节规则。&quot;},
{&quot;id&quot;: &quot;G-050&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1224, &quot;end&quot;: 1246, &quot;title&quot;: &quot;### 3.22 停止、超时与回退不能省略&quot;, &quot;sha256&quot;: &quot;53cd1d043287258748072df7e549de0286b07184d9b762d50215a8262e23873a&quot;, &quot;target&quot;: &quot;playbooks/execution.md&quot;, &quot;group&quot;: &quot;停止与恢复入口&quot;, &quot;rule&quot;: &quot;取消、迟到、超时、成本上限和回退共同决定何时停止；跨会话完整记录属于 maintenance。&quot;},
{&quot;id&quot;: &quot;G-051&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1247, &quot;end&quot;: 1248, &quot;title&quot;: &quot;## 4. 人介入、Interaction 与权力&quot;, &quot;sha256&quot;: &quot;dfbdc82a34658ab40f4b2fb509d6b1ca23a90a8691af32b189c8b1861f3623b8&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-052&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1249, &quot;end&quot;: 1260, &quot;title&quot;: &quot;### 4.1 人的位置&quot;, &quot;sha256&quot;: &quot;fec09b54a2a0f8d403d0b028016a720abc1af1951a26076d2c68ea508e120ad6&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;主体与权力&quot;, &quot;rule&quot;: &quot;谁有权做什么、权限怎样相交；谁何时点击按钮是 review 的步骤。&quot;},
{&quot;id&quot;: &quot;G-053&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1261, &quot;end&quot;: 1283, &quot;title&quot;: &quot;### 4.2 权力表&quot;, &quot;sha256&quot;: &quot;53723c879ad30a6265dd629513785c7793745cea111c149863b9bf85e3f15548&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;主体与权力&quot;, &quot;rule&quot;: &quot;谁有权做什么、权限怎样相交；谁何时点击按钮是 review 的步骤。&quot;},
{&quot;id&quot;: &quot;G-054&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1284, &quot;end&quot;: 1346, &quot;title&quot;: &quot;### 4.3 直接沿用实际中断/恢复原语&quot;, &quot;sha256&quot;: &quot;b8cc0007eee3c2a3672220541b65890fcf00bbe140cf2195b9c991b7a727e133&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;两腿恢复与部署&quot;, &quot;rule&quot;: &quot;同一执行器在进程生命周期中的恢复差异和接口落实矩阵；批准权限公式由 authority 持有。&quot;},
{&quot;id&quot;: &quot;G-055&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1347, &quot;end&quot;: 1382, &quot;title&quot;: &quot;### 4.4 身份、批准与强制点&quot;, &quot;sha256&quot;: &quot;d1a10a8971a7dfbfd58fe61a977920a23200ab558577eee75539ee7b771bd5ab&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;边界与动作门&quot;, &quot;rule&quot;: &quot;身份鉴别、强制点、三门与审批档位必须在同一信任模型中解释；不得把约定写成强制机制。&quot;},
{&quot;id&quot;: &quot;G-056&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1383, &quot;end&quot;: 1429, &quot;title&quot;: &quot;### 4.5 权限公式与只有 principal 能做的动作&quot;, &quot;sha256&quot;: &quot;750d96ef703bfae647e5b78da9dd2bb56333c53afed0926b1aaf9da6b28c0a5f&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;主体与权力&quot;, &quot;rule&quot;: &quot;谁有权做什么、权限怎样相交；谁何时点击按钮是 review 的步骤。&quot;},
{&quot;id&quot;: &quot;G-057&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1430, &quot;end&quot;: 1451, &quot;title&quot;: &quot;### 4.6 三道正交门&quot;, &quot;sha256&quot;: &quot;01aa04c2ad66c62165716539bc7ada4b72dd19996e324e9925258f9ec333cbfb&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;边界与动作门&quot;, &quot;rule&quot;: &quot;身份鉴别、强制点、三门与审批档位必须在同一信任模型中解释；不得把约定写成强制机制。&quot;},
{&quot;id&quot;: &quot;G-058&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1452, &quot;end&quot;: 1480, &quot;title&quot;: &quot;### 4.7 四档审批&quot;, &quot;sha256&quot;: &quot;fc2ca15040559f54581ea681d9a3e552b9f3fef901a06a8987b82bc984dac8df&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;边界与动作门&quot;, &quot;rule&quot;: &quot;身份鉴别、强制点、三门与审批档位必须在同一信任模型中解释；不得把约定写成强制机制。&quot;},
{&quot;id&quot;: &quot;G-059&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1481, &quot;end&quot;: 1508, &quot;title&quot;: &quot;### 4.8 principal 的裁量权与改判纪律&quot;, &quot;sha256&quot;: &quot;f4d2a4877ae39fb419899e9b99fda4d254fa67b09bca7d8f847c4ed9fea81ba2&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;批准对象与人的动作&quot;, &quot;rule&quot;: &quot;人如何取得对象、履行义务和合法改判；权力表本体在 authority，不能从便利性推出新权限。&quot;},
{&quot;id&quot;: &quot;G-060&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1509, &quot;end&quot;: 1527, &quot;title&quot;: &quot;### 4.9 Attempt 内的三条硬禁令&quot;, &quot;sha256&quot;: &quot;ac740a5514dccc30da7b603d98de13ef312167097b2500adb386201afc2ea0c9&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;执行中禁止与凭据传播&quot;, &quot;rule&quot;: &quot;Attempt 内限制及子进程/跨腿令牌不得绕过前述边界；工具调用具体步骤留 execution。&quot;},
{&quot;id&quot;: &quot;G-061&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1528, &quot;end&quot;: 1548, &quot;title&quot;: &quot;### 4.10 人这一侧的义务&quot;, &quot;sha256&quot;: &quot;ce0a5dbc876c30cf0becf43ebfc12696912840099a1f68e3db9a117244921002&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;批准对象与人的动作&quot;, &quot;rule&quot;: &quot;人如何取得对象、履行义务和合法改判；权力表本体在 authority，不能从便利性推出新权限。&quot;},
{&quot;id&quot;: &quot;G-062&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1549, &quot;end&quot;: 1579, &quot;title&quot;: &quot;### 4.11 本轮已发生介入的实例级清单&quot;, &quot;sha256&quot;: &quot;87af901ea8b055c7eb1745d73910dd81cbd375708889d0b8f369934fd259492d&quot;, &quot;target&quot;: &quot;records/guide-history.md&quot;, &quot;group&quot;: &quot;历史实测与实例&quot;, &quot;rule&quot;: &quot;五家取值、介入清单及轨迹读数各有环境和时点；查询今天能力必须另有当次证据。&quot;},
{&quot;id&quot;: &quot;G-063&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1580, &quot;end&quot;: 1604, &quot;title&quot;: &quot;### 4.12 人的收件箱：让批准具体、可读、可重取&quot;, &quot;sha256&quot;: &quot;563da4808b1ebe3b5370f2b2cb9d728cfb24c754e5bb555645c5553059fa4201&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;批准对象与人的动作&quot;, &quot;rule&quot;: &quot;人如何取得对象、履行义务和合法改判；权力表本体在 authority，不能从便利性推出新权限。&quot;},
{&quot;id&quot;: &quot;G-064&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1605, &quot;end&quot;: 1628, &quot;title&quot;: &quot;### 4.13 执行器凭据、子进程与跨腿委派&quot;, &quot;sha256&quot;: &quot;fd5c38c21e39456723fb7a964d49222d46692166e4708c8ce1254232590ad754&quot;, &quot;target&quot;: &quot;specs/authority.md&quot;, &quot;group&quot;: &quot;执行中禁止与凭据传播&quot;, &quot;rule&quot;: &quot;Attempt 内限制及子进程/跨腿令牌不得绕过前述边界；工具调用具体步骤留 execution。&quot;},
{&quot;id&quot;: &quot;G-065&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1629, &quot;end&quot;: 1630, &quot;title&quot;: &quot;## 5. 可观测性、证据与等效&quot;, &quot;sha256&quot;: &quot;a9069639a2d30d430a4be7c39b03a699f022144fc529cc3b9e710075c4a99818&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-066&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1631, &quot;end&quot;: 1658, &quot;title&quot;: &quot;### 5.1 三个粒度字段&quot;, &quot;sha256&quot;: &quot;08ea4247069a927b07cc715c5d82e47cdff3f4d2c69d8a42699a9564c38a64c9&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;观测及采信&quot;, &quot;rule&quot;: &quot;粒度、等级、四级词典与历史使用条件构成证据契约；单次实测全文不冒充契约。&quot;},
{&quot;id&quot;: &quot;G-067&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1659, &quot;end&quot;: 1673, &quot;title&quot;: &quot;### 5.2 证据等级与采信规则&quot;, &quot;sha256&quot;: &quot;aa6e6389758187aaa3716d98e2b8b1170dba113db81b58f0eb0669b535986dc5&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;观测及采信&quot;, &quot;rule&quot;: &quot;粒度、等级、四级词典与历史使用条件构成证据契约；单次实测全文不冒充契约。&quot;},
{&quot;id&quot;: &quot;G-068&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1674, &quot;end&quot;: 1698, &quot;title&quot;: &quot;### 5.3 手工态与服务态的等效判据&quot;, &quot;sha256&quot;: &quot;ee5e4116de60848e35a2d19695f81cc00df499e020501105e18c5e62e7de240c&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;载体与等效&quot;, &quot;rule&quot;: &quot;Git/其它载体各能证明什么以及 S/R 等效边界；验收动作与判据质量另见 review。&quot;},
{&quot;id&quot;: &quot;G-069&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1699, &quot;end&quot;: 1708, &quot;title&quot;: &quot;### 5.4 Git 载体能与不能证明什么&quot;, &quot;sha256&quot;: &quot;e0c63c56a0cfb4078344cca5a5db1c7047b03ddd332998af99356b554a6c60c9&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;载体与等效&quot;, &quot;rule&quot;: &quot;Git/其它载体各能证明什么以及 S/R 等效边界；验收动作与判据质量另见 review。&quot;},
{&quot;id&quot;: &quot;G-070&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1709, &quot;end&quot;: 1720, &quot;title&quot;: &quot;### 5.5 四层验证&quot;, &quot;sha256&quot;: &quot;faeb607e2b006ad8db680a6ad2e1931de71a29b7427ee0af35584ac891588b97&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;验收与整合&quot;, &quot;rule&quot;: &quot;测试层次、证据最小集和事实/选择的区分必须一起读；不存在用票数替代证据的入口。&quot;},
{&quot;id&quot;: &quot;G-071&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1721, &quot;end&quot;: 1746, &quot;title&quot;: &quot;### 5.6 &#96;F-EXEC-*&#96; / &#96;F-INTERACT-*&#96; 双腿落地矩阵&quot;, &quot;sha256&quot;: &quot;0e36721939b612bf5fd1379cb29e6761e0d6d5e3c5898d0d86283ef88f7dc718&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;两腿恢复与部署&quot;, &quot;rule&quot;: &quot;同一执行器在进程生命周期中的恢复差异和接口落实矩阵；批准权限公式由 authority 持有。&quot;},
{&quot;id&quot;: &quot;G-072&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1747, &quot;end&quot;: 1773, &quot;title&quot;: &quot;### 5.7 证据账按流程分级&quot;, &quot;sha256&quot;: &quot;e6d1a3e5db32cda2fba1238e6706b181a3966981081a9f9e37094eadb12e5df2&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;验收与整合&quot;, &quot;rule&quot;: &quot;测试层次、证据最小集和事实/选择的区分必须一起读；不存在用票数替代证据的入口。&quot;},
{&quot;id&quot;: &quot;G-073&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1774, &quot;end&quot;: 1803, &quot;title&quot;: &quot;### 5.8 上下文路由与能力四级词典&quot;, &quot;sha256&quot;: &quot;fb7b5f7f72fb837bc160c6d922310b422606825020fd163faef5f4f62a3f4c12&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;观测及采信&quot;, &quot;rule&quot;: &quot;粒度、等级、四级词典与历史使用条件构成证据契约；单次实测全文不冒充契约。&quot;},
{&quot;id&quot;: &quot;G-074&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1804, &quot;end&quot;: 1826, &quot;title&quot;: &quot;### 5.9 七种载体各能证明什么&quot;, &quot;sha256&quot;: &quot;b2f98196d60e008adf312582374f6a1a229681178f0848feaf131f0de500b451&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;载体与等效&quot;, &quot;rule&quot;: &quot;Git/其它载体各能证明什么以及 S/R 等效边界；验收动作与判据质量另见 review。&quot;},
{&quot;id&quot;: &quot;G-075&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1827, &quot;end&quot;: 1850, &quot;title&quot;: &quot;### 5.10 事实裁决表与整合纪律&quot;, &quot;sha256&quot;: &quot;618f6398fc223c75f2be431ef82790c5dfdbb544978a7ff9b644d0fce7fab3f5&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;验收与整合&quot;, &quot;rule&quot;: &quot;测试层次、证据最小集和事实/选择的区分必须一起读；不存在用票数替代证据的入口。&quot;},
{&quot;id&quot;: &quot;G-076&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1851, &quot;end&quot;: 1898, &quot;title&quot;: &quot;### 5.11 轨迹实测：23 条里 2 条 attested&quot;, &quot;sha256&quot;: &quot;cc6f48adf2889fce4019719d7b0a141e4d6fbb5076631606701e0ae725d9becd&quot;, &quot;target&quot;: &quot;records/guide-history.md&quot;, &quot;group&quot;: &quot;历史实测与实例&quot;, &quot;rule&quot;: &quot;五家取值、介入清单及轨迹读数各有环境和时点；查询今天能力必须另有当次证据。&quot;},
{&quot;id&quot;: &quot;G-077&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1899, &quot;end&quot;: 1915, &quot;title&quot;: &quot;### 5.12 检查本身也必须接受检查&quot;, &quot;sha256&quot;: &quot;a166660a821dba3bda24fbe05f896658bd5eb51187f628f8ff9c66f16e8af43a&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;检查的反例与复核&quot;, &quot;rule&quot;: &quot;检验前提、控制面和判据本身；历史实例留作反证，不当作今天已复跑的结果。&quot;},
{&quot;id&quot;: &quot;G-078&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1916, &quot;end&quot;: 1929, &quot;title&quot;: &quot;### 5.13 历史取证怎样用于今天的开发&quot;, &quot;sha256&quot;: &quot;96e054592724052db6dbfbca3cc7584e3d0be5caa6101cbe4870f18def5cdd65&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;观测及采信&quot;, &quot;rule&quot;: &quot;粒度、等级、四级词典与历史使用条件构成证据契约；单次实测全文不冒充契约。&quot;},
{&quot;id&quot;: &quot;G-079&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1930, &quot;end&quot;: 1931, &quot;title&quot;: &quot;## 6. 什么时候运行时值得用&quot;, &quot;sha256&quot;: &quot;0ee39124c7630ca61df3c9620bfef940eb5c5f2ef80afc346e09cdf85147fb9e&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-080&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1932, &quot;end&quot;: 1946, &quot;title&quot;: &quot;### 6.1 机械分类&quot;, &quot;sha256&quot;: &quot;7ed6716aca071042e7ac9c94cf934790e3edfef71a88151660cfcdc91ae043d7&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;成本和观察上界&quot;, &quot;rule&quot;: &quot;只有先知道观测覆盖，才能判路由成本和绕过；保留反例和未归因限制，不推出绝对零绕过。&quot;},
{&quot;id&quot;: &quot;G-081&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1947, &quot;end&quot;: 1962, &quot;title&quot;: &quot;### 6.2 三类反例与 T0 上界&quot;, &quot;sha256&quot;: &quot;c53656f27fcb29a657587cbdf70c8507aa60849f96538cebc0c748362986c640&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;成本和观察上界&quot;, &quot;rule&quot;: &quot;只有先知道观测覆盖，才能判路由成本和绕过；保留反例和未归因限制，不推出绝对零绕过。&quot;},
{&quot;id&quot;: &quot;G-082&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1963, &quot;end&quot;: 1985, &quot;title&quot;: &quot;### 6.3 绕过只能部分可观测&quot;, &quot;sha256&quot;: &quot;d4f05037f230c84881d61b08c7ea0570b534959af2701936568eba3e75ed1881&quot;, &quot;target&quot;: &quot;specs/evidence.md&quot;, &quot;group&quot;: &quot;成本和观察上界&quot;, &quot;rule&quot;: &quot;只有先知道观测覆盖，才能判路由成本和绕过；保留反例和未归因限制，不推出绝对零绕过。&quot;},
{&quot;id&quot;: &quot;G-083&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1986, &quot;end&quot;: 1987, &quot;title&quot;: &quot;## 7. 演进与退出脚手架&quot;, &quot;sha256&quot;: &quot;0b006e66bc53d36fcbc4adb5d25384e7cda2be4893d8270584b37425da7351e6&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧 guide 结构上下文&quot;, &quot;rule&quot;: &quot;旧布局的标题壳和阅读顺序不能成为新文档正文；内容原样保存供审计。&quot;},
{&quot;id&quot;: &quot;G-084&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 1988, &quot;end&quot;: 2001, &quot;title&quot;: &quot;### 7.1 依赖顺序&quot;, &quot;sha256&quot;: &quot;e4a5aa5ce8299f752bb5084d60ed536266b4f817106a69a3282d7ea7d44f1224&quot;, &quot;target&quot;: &quot;work/roadmap.md&quot;, &quot;group&quot;: &quot;运行时迁移顺序&quot;, &quot;rule&quot;: &quot;G0–G5 依赖及分组件退出门作为待实施路线；通用删除纪律引用 maintenance。&quot;},
{&quot;id&quot;: &quot;G-085&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2002, &quot;end&quot;: 2037, &quot;title&quot;: &quot;### 7.2 从手工态拆到服务态&quot;, &quot;sha256&quot;: &quot;b2806934c0490b65fb5bfb64d3b87f0c9220124809f721306055abb304f4664f&quot;, &quot;target&quot;: &quot;work/roadmap.md&quot;, &quot;group&quot;: &quot;运行时迁移顺序&quot;, &quot;rule&quot;: &quot;G0–G5 依赖及分组件退出门作为待实施路线；通用删除纪律引用 maintenance。&quot;},
{&quot;id&quot;: &quot;G-086&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2038, &quot;end&quot;: 2072, &quot;title&quot;: &quot;### 7.3 删除与迁移门&quot;, &quot;sha256&quot;: &quot;b9f02e4e94c70458777df570fec495c65ebf87a6d0bdb8ca34e23cfe9862d607&quot;, &quot;target&quot;: &quot;playbooks/maintenance.md&quot;, &quot;group&quot;: &quot;迁移与修订&quot;, &quot;rule&quot;: &quot;可复用删除门及内核修订步骤；G0–G5 的当前实施依赖留 work，不能删掉仍未满足的条件。&quot;},
{&quot;id&quot;: &quot;G-087&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2073, &quot;end&quot;: 2103, &quot;title&quot;: &quot;### 7.4 风险和未决&quot;, &quot;sha256&quot;: &quot;f12187998cf5644e487428aee4d2238cae6034c1cdbde1a527ce9e36ee189e0f&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;风险与验证债&quot;, &quot;rule&quot;: &quot;现有风险和 SDK 未验证清单先于开工；不能把列表存在当作验证完成。&quot;},
{&quot;id&quot;: &quot;G-088&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2104, &quot;end&quot;: 2139, &quot;title&quot;: &quot;### 7.5 跨会话续接&quot;, &quot;sha256&quot;: &quot;fbce68888fc963570a13cafb2503c93bfc0573c2284c556f83d0809a14ba595d&quot;, &quot;target&quot;: &quot;playbooks/maintenance.md&quot;, &quot;group&quot;: &quot;续接&quot;, &quot;rule&quot;: &quot;用于换会话仍可恢复真实任务上下文；不能把聊天摘要变成新的事实源。&quot;},
{&quot;id&quot;: &quot;G-089&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2140, &quot;end&quot;: 2158, &quot;title&quot;: &quot;### 7.6 执行器架构的未验证清单&quot;, &quot;sha256&quot;: &quot;40cd8311b3b089eaaeac8de530c1aad4d7a84b8b275707189cdd140db49fbeae&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;风险与验证债&quot;, &quot;rule&quot;: &quot;现有风险和 SDK 未验证清单先于开工；不能把列表存在当作验证完成。&quot;},
{&quot;id&quot;: &quot;G-090&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2159, &quot;end&quot;: 2177, &quot;title&quot;: &quot;### 7.7 需要改内核时，提交明确的修订工作单元&quot;, &quot;sha256&quot;: &quot;bae24dbe9f69e1757ae1eed8598e0b17478d672752b18478ebb8d275865d69e4&quot;, &quot;target&quot;: &quot;playbooks/maintenance.md&quot;, &quot;group&quot;: &quot;迁移与修订&quot;, &quot;rule&quot;: &quot;可复用删除门及内核修订步骤；G0–G5 的当前实施依赖留 work，不能删掉仍未满足的条件。&quot;},
{&quot;id&quot;: &quot;G-091&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2178, &quot;end&quot;: 2188, &quot;title&quot;: &quot;## 8. 本轮核查裁定&quot;, &quot;sha256&quot;: &quot;e2f855ae31e1f4ccc2ddf1a82ceeda920cd1861fd84b6d3729a3d43e5364e209&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;已裁定的设计边界&quot;, &quot;rule&quot;: &quot;明确哪些旧设计不得复活，独立观察与处置必须相邻；不能因其叫历史裁定就移出日常规范。&quot;},
{&quot;id&quot;: &quot;G-092&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2189, &quot;end&quot;: 2205, &quot;title&quot;: &quot;### 8.1 六项逐条处置&quot;, &quot;sha256&quot;: &quot;2d6f60a73d9fa434c12fa77176735cff452c77745e972642470ef776596553a6&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;已裁定的设计边界&quot;, &quot;rule&quot;: &quot;明确哪些旧设计不得复活，独立观察与处置必须相邻；不能因其叫历史裁定就移出日常规范。&quot;},
{&quot;id&quot;: &quot;G-093&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2206, &quot;end&quot;: 2214, &quot;title&quot;: &quot;### 8.2 保留与撤销&quot;, &quot;sha256&quot;: &quot;e68500042c8476049eec294a651105974524e838be014b011c8265ae51584372&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;已裁定的设计边界&quot;, &quot;rule&quot;: &quot;明确哪些旧设计不得复活，独立观察与处置必须相邻；不能因其叫历史裁定就移出日常规范。&quot;},
{&quot;id&quot;: &quot;G-094&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2215, &quot;end&quot;: 2234, &quot;title&quot;: &quot;### 8.3 本次补吸收明确不采用的旧主张&quot;, &quot;sha256&quot;: &quot;bbcf6fd91a65e2bfe3494eba4b007a61f5152e8061e10e2df8cfb34d7f6a0b39&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;已裁定的设计边界&quot;, &quot;rule&quot;: &quot;明确哪些旧设计不得复活，独立观察与处置必须相邻；不能因其叫历史裁定就移出日常规范。&quot;},
{&quot;id&quot;: &quot;G-095&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2235, &quot;end&quot;: 2240, &quot;title&quot;: &quot;## 9. 覆盖声明&quot;, &quot;sha256&quot;: &quot;87edee33cf73b9cb9178b41a811ac7d6a2694f8d0d0bf2f164ecd80371ff8672&quot;, &quot;target&quot;: &quot;records/guide-audit.md&quot;, &quot;group&quot;: &quot;核验声明与补吸收&quot;, &quot;rule&quot;: &quot;原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。&quot;},
{&quot;id&quot;: &quot;G-096&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2241, &quot;end&quot;: 2252, &quot;title&quot;: &quot;### 9.1 查了什么&quot;, &quot;sha256&quot;: &quot;17cff6af355dced4dfce88d8ab8c614e2078428ec8700c2e4a00a0f26c5d8806&quot;, &quot;target&quot;: &quot;records/guide-audit.md&quot;, &quot;group&quot;: &quot;核验声明与补吸收&quot;, &quot;rule&quot;: &quot;原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。&quot;},
{&quot;id&quot;: &quot;G-097&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2253, &quot;end&quot;: 2298, &quot;title&quot;: &quot;### 9.2 没查什么&quot;, &quot;sha256&quot;: &quot;0a079a71396c458e46c7745662236aa1fa4f374fd341d85f773d6f5d5690e37f&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;覆盖声明的写法&quot;, &quot;rule&quot;: &quot;区分查了、没查、不能排除以及三类未知；必须进入可复用规程，原作者未核清单只作带日期例证。&quot;},
{&quot;id&quot;: &quot;G-098&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2299, &quot;end&quot;: 2305, &quot;title&quot;: &quot;### 9.3 自增内容及理由（&#96;runtime-refact&#96; 轮）&quot;, &quot;sha256&quot;: &quot;f3e02e172af585aa01456a65e30637509182a7ab75a4843aa968d57304fdfb6c&quot;, &quot;target&quot;: &quot;records/guide-audit.md&quot;, &quot;group&quot;: &quot;核验声明与补吸收&quot;, &quot;rule&quot;: &quot;原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。&quot;},
{&quot;id&quot;: &quot;G-099&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2306, &quot;end&quot;: 2447, &quot;title&quot;: &quot;### 9.4 两份 lifecycle 的吸收轮（2026-09-07）&quot;, &quot;sha256&quot;: &quot;407fef5c1d20a360c4793214ba1ee52fae0f7a3ff7fcde852cabe10d8c81d8dc&quot;, &quot;target&quot;: &quot;records/guide-audit.md&quot;, &quot;group&quot;: &quot;核验声明与补吸收&quot;, &quot;rule&quot;: &quot;原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。&quot;},
{&quot;id&quot;: &quot;G-100&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2448, &quot;end&quot;: 2506, &quot;title&quot;: &quot;### 9.5 GPT-6 再吸收记录（2026-09-08）&quot;, &quot;sha256&quot;: &quot;c64255a657627d0237f05a3fe038c380ebb3c7b2ff513bfa6645f64ab0156658&quot;, &quot;target&quot;: &quot;records/guide-audit.md&quot;, &quot;group&quot;: &quot;核验声明与补吸收&quot;, &quot;rule&quot;: &quot;原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。&quot;},
{&quot;id&quot;: &quot;G-101&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2507, &quot;end&quot;: 2553, &quot;title&quot;: &quot;### 9.6 取代前 opus 做的核验（2026-09-08）&quot;, &quot;sha256&quot;: &quot;eb2712079c6eeebd1f5e80dba8f8b7624aa5668cba844a8243279ae99aa436fe&quot;, &quot;target&quot;: &quot;records/guide-audit.md&quot;, &quot;group&quot;: &quot;核验声明与补吸收&quot;, &quot;rule&quot;: &quot;原作者、当时的查项、历次新增理由和采用审计；摘要不证明语义覆盖。G-097 的通用声明规则含原未核例证安置在 review，可凭 ID 取回。&quot;},
{&quot;id&quot;: &quot;G-102&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2554, &quot;end&quot;: 2875, &quot;title&quot;: &quot;## 10. 五份历史正文及目录说明的逐节处置&quot;, &quot;sha256&quot;: &quot;0b028b5973ef57fd57dd7f9753605c11d64b421de58dab1c2e58e348cf6ecbe2&quot;, &quot;target&quot;: &quot;records/guide-audit.md&quot;, &quot;group&quot;: &quot;历史源落点收据&quot;, &quot;rule&quot;: &quot;完整保留既有 294 行；它不是本次 260 行的替代分母，也不是全部正文已验的证明。&quot;},
{&quot;id&quot;: &quot;G-103&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2876, &quot;end&quot;: 2923, &quot;title&quot;: &quot;## 11. 反模式&quot;, &quot;sha256&quot;: &quot;5c4f84af05095fe4b15c3812f5f9d28c0c62eb85dd66fe4c4b064c86fb6f79da&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;名词与反例&quot;, &quot;rule&quot;: &quot;定义跨组件共同词义和禁止形态；单次失败的完整事件移历史/质量组。&quot;},
{&quot;id&quot;: &quot;G-104&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2924, &quot;end&quot;: 2964, &quot;title&quot;: &quot;## 12. 常见失败方式与项目实例&quot;, &quot;sha256&quot;: &quot;6c49a2dacc55dda60bb9e1cfe2805bf595d25509bd7a6c3d98a481613e27d312&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;检查的反例与复核&quot;, &quot;rule&quot;: &quot;检验前提、控制面和判据本身；历史实例留作反证，不当作今天已复跑的结果。&quot;},
{&quot;id&quot;: &quot;G-105&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2965, &quot;end&quot;: 2983, &quot;title&quot;: &quot;### 12.1 七种“检查给出假答案”的回归线索&quot;, &quot;sha256&quot;: &quot;b7f6e4d275133d47944344e5ae8cfa701798e94506a0df83a5e8945928bf59ba&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;检查的反例与复核&quot;, &quot;rule&quot;: &quot;检验前提、控制面和判据本身；历史实例留作反证，不当作今天已复跑的结果。&quot;},
{&quot;id&quot;: &quot;G-106&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 2984, &quot;end&quot;: 3003, &quot;title&quot;: &quot;### 12.2 并行评审的收益与盲区&quot;, &quot;sha256&quot;: &quot;381fb92de6fa781025d41d6c9ec76cdae078e7115f69a62ccc1df1ebe05c2da9&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;检查的反例与复核&quot;, &quot;rule&quot;: &quot;检验前提、控制面和判据本身；历史实例留作反证，不当作今天已复跑的结果。&quot;},
{&quot;id&quot;: &quot;G-107&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 3004, &quot;end&quot;: 3037, &quot;title&quot;: &quot;## 13. 词汇对照&quot;, &quot;sha256&quot;: &quot;242917fd32677a5e94f62168fa7756e13ddad8e0ae3e69d0f95813e251850e75&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;名词与反例&quot;, &quot;rule&quot;: &quot;定义跨组件共同词义和禁止形态；单次失败的完整事件移历史/质量组。&quot;},
{&quot;id&quot;: &quot;G-108&quot;, &quot;path&quot;: &quot;agent-dev-guide.md&quot;, &quot;line&quot;: 3038, &quot;end&quot;: 3082, &quot;title&quot;: &quot;## 14. 开发 Task 持久记录模板&quot;, &quot;sha256&quot;: &quot;7b5384fbaedbe63defae494e1c7783a8a4e86075a75a49bac60a319eebb7dedd&quot;, &quot;target&quot;: &quot;playbooks/intake.md&quot;, &quot;group&quot;: &quot;记录表单&quot;, &quot;rule&quot;: &quot;要求执行者填写的持久记录与任务条目字段；具体任务清单属于 work/delivery。&quot;},
{&quot;id&quot;: &quot;P-001&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 21, &quot;title&quot;: &quot;# 并行评优轮：流程&quot;, &quot;sha256&quot;: &quot;b2f57cec6aae6e8e9348f9c95f28c419aed60958761f22c63ef71d1edfd4d529&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-002&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 22, &quot;end&quot;: 51, &quot;title&quot;: &quot;## 0. 收到「继续」时怎么办&quot;, &quot;sha256&quot;: &quot;fd49aa897d45299584a463faa4f3565c917a3c0a0fdf2b09c0d28cc5c7d6de82&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-003&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 52, &quot;end&quot;: 63, &quot;title&quot;: &quot;## 1. 流程档位：这件事该走多重的流程&quot;, &quot;sha256&quot;: &quot;3eb7fcb7a80fc9b93cf9ed1d569f941b9dae250e5926a2687f57a31b5ea5b9a3&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-004&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 64, &quot;end&quot;: 84, &quot;title&quot;: &quot;### 1.0 一套流程，靠参数覆盖三种协作形态&quot;, &quot;sha256&quot;: &quot;16cf91b6d52c1396f8b4df2fd90a7aeef325fa9e296e6d9bab7d34bf07b371ce&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-005&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 85, &quot;end&quot;: 98, &quot;title&quot;: &quot;### 1.1 判据：命中任一条即 T2&quot;, &quot;sha256&quot;: &quot;61e1dddebaa5c80fa3625ca1a8681817e9f3ed6ee59ac8ecf1b847c36dda6205&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-006&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 99, &quot;end&quot;: 110, &quot;title&quot;: &quot;### 1.2 升档随意，降档要理由——这条不对称是有意的&quot;, &quot;sha256&quot;: &quot;bf735dfab5d65be082040da79f9cff78d4e1d92601f0915f853aef96ac16339d&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-007&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 111, &quot;end&quot;: 119, &quot;title&quot;: &quot;### 1.3 任何档位都不能省的三条&quot;, &quot;sha256&quot;: &quot;88c336a7e0b3da96b03b3442a92f6882fd9c38fefa0a46f3524e8767381f9aaf&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-008&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 120, &quot;end&quot;: 126, &quot;title&quot;: &quot;## 2. 裁量权：supervisor 可以临机决定什么&quot;, &quot;sha256&quot;: &quot;80b2c1fbb4ff1317071700c470a2fafc8dca7e6bc77bb544a04cea881f6b697f&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-009&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 127, &quot;end&quot;: 137, &quot;title&quot;: &quot;### 2.1 不可裁量的下限&quot;, &quot;sha256&quot;: &quot;799cffbcd626c3f6d6fffdeb2d51b005400b4abc42e208bbf8f62e2caeb37aa5&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-010&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 138, &quot;end&quot;: 142, &quot;title&quot;: &quot;### 2.2 可裁量的事项&quot;, &quot;sha256&quot;: &quot;bf525d4b825a32ec150de9cf594ebc485b738d9929c8a9433b2706445c0f7bea&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-011&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 143, &quot;end&quot;: 158, &quot;title&quot;: &quot;### 2.3 方向不对称：这是本协议的统一原则&quot;, &quot;sha256&quot;: &quot;976c280c4588abb27dcf7cb7cb7875769c82a468114c828acd10e755ab9aa5ff&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-012&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 159, &quot;end&quot;: 170, &quot;title&quot;: &quot;### 2.4 裁定记录：未记录的裁定无效&quot;, &quot;sha256&quot;: &quot;40e738ec9f9d718a7a6c2fcab33af94a2a3a0bbb8133e5a53aaa532cdb370160&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-013&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 171, &quot;end&quot;: 178, &quot;title&quot;: &quot;### 2.5 推翻&quot;, &quot;sha256&quot;: &quot;a89d32d36ea370fb28d3f206afaf11544aa1cbf414a2a3fd3f1b382785cb4e04&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-014&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 179, &quot;end&quot;: 190, &quot;title&quot;: &quot;### 2.6 裁量是规则的孵化器&quot;, &quot;sha256&quot;: &quot;c366e080a1c9335ad76710a692719e23ce537ca8ddcefdbdc477bba346ee09a6&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-015&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 191, &quot;end&quot;: 196, &quot;title&quot;: &quot;## 3. 执行者与触发方式：两个轴，不要混&quot;, &quot;sha256&quot;: &quot;7cd5a95773b6a64eede39d5054248766a984c7e56391ac17ceb88ad4910512c2&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-016&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 197, &quot;end&quot;: 208, &quot;title&quot;: &quot;### 3.1 两个轴&quot;, &quot;sha256&quot;: &quot;83f7b3998c1ea69c7647c60efff769e962387c564ee8c921e7e3906439b8d594&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-017&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 209, &quot;end&quot;: 225, &quot;title&quot;: &quot;### 3.2 全部动作的归属&quot;, &quot;sha256&quot;: &quot;e05018cdfa78050de41bd0d5340d7210ff67a79d191a448ec9737b22b36f2ec7&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-018&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 226, &quot;end&quot;: 235, &quot;title&quot;: &quot;### 3.3 两类「人做」不可互相顶替&quot;, &quot;sha256&quot;: &quot;5850ef619f25dad9649661b42f25c7cb20fa3f1e51ea2163e51b4663fc4a05d2&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-019&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 236, &quot;end&quot;: 262, &quot;title&quot;: &quot;## 4. 七个环节（T2 专用）&quot;, &quot;sha256&quot;: &quot;ca0b9ccaaaaa5124110ec7b11b690ee7b5abe178d0d1004d0a8c34cf964e24b8&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-020&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 263, &quot;end&quot;: 290, &quot;title&quot;: &quot;## 5. 本轮定义：&#96;round.md&#96;&quot;, &quot;sha256&quot;: &quot;0a2f73141d51fb9be1712cbfc8c63381a4a4bb032e5f5787f5c72ccd8f229273&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-021&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 291, &quot;end&quot;: 322, &quot;title&quot;: &quot;## 6. 产物、路径与命名&quot;, &quot;sha256&quot;: &quot;1810ea8ba3da1737dce71841407f459af03c710617bb197f61017477ecbb33c8&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-022&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 323, &quot;end&quot;: 343, &quot;title&quot;: &quot;### 6.1 环节通知：组织者的产物，不是发起人的话术&quot;, &quot;sha256&quot;: &quot;057774ecfb3ac4590bec595b0fa8bf173f9be9c6620a26389d5c1240dc1edbb3&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-023&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 344, &quot;end&quot;: 348, &quot;title&quot;: &quot;## 7. 取件与检视面&quot;, &quot;sha256&quot;: &quot;8024eaeffd6b4451174e375b5c7d935e9501ae610c465eb402c30e1ca9c479c1&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-024&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 349, &quot;end&quot;: 364, &quot;title&quot;: &quot;### 7.1 取件：一律按 commit，不看工作区&quot;, &quot;sha256&quot;: &quot;54ee65565f3b4a2e4ec5fcf8dcd85e1a0ff6ce9baa03daaad1658dbfd8527cef&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-025&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 365, &quot;end&quot;: 381, &quot;title&quot;: &quot;### 7.2 检视面：需要人读时开临时 worktree&quot;, &quot;sha256&quot;: &quot;49546d85b547722a89f66a6a23e6d7c4073f2ce757cd050d4ab9078c127cb578&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-026&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 382, &quot;end&quot;: 390, &quot;title&quot;: &quot;### 7.3 每个需要人读的环节都必须先有检视面&quot;, &quot;sha256&quot;: &quot;05d4775dfaa5efda5cdba56f33eddeaf04c83df93ecaf1ad9c5ef4739cefbc87&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-027&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 391, &quot;end&quot;: 426, &quot;title&quot;: &quot;## 8. 环节判定：命令即判据&quot;, &quot;sha256&quot;: &quot;c83a4814637e9e52f6204973353633965e9d4daa1d7ed3030bdb80954b4aea9e&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-028&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 427, &quot;end&quot;: 464, &quot;title&quot;: &quot;### 8.1 判据自身的质量：覆盖不全比没有更危险&quot;, &quot;sha256&quot;: &quot;d3f07470839960a78f99a960f461aa2555d35ef016d2b8cb72d0619df3bd7bde&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-029&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 465, &quot;end&quot;: 471, &quot;title&quot;: &quot;### 8.2 立判据的人怎么约束自己&quot;, &quot;sha256&quot;: &quot;7d3eb45f752c059b0ff7b585d0cf722c74e2dbc39e150a9679a116abdaec1b80&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-030&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 472, &quot;end&quot;: 483, &quot;title&quot;: &quot;#### 只写判据，不写答案&quot;, &quot;sha256&quot;: &quot;3f8655d2e77fd875752df6769304d73ecff533e18308aa5b6e59ca000af78447&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-031&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 484, &quot;end&quot;: 491, &quot;title&quot;: &quot;#### 立据人的四条自我约束&quot;, &quot;sha256&quot;: &quot;5aca979658125a9feabfc8aba4846ea84a61ee715bfef28c560694b4ac413729&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-032&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 492, &quot;end&quot;: 500, &quot;title&quot;: &quot;#### 难点清单：记下来是为了检验发起方&quot;, &quot;sha256&quot;: &quot;07dc0d5d662583a460a3a52197ade4351fae3706d61f140bce50683e1bd40b83&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-033&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 501, &quot;end&quot;: 506, &quot;title&quot;: &quot;#### 三条通用扣分规则&quot;, &quot;sha256&quot;: &quot;161b2aec1a7554950c86b805e322169a42e941a0c7aa15009d20eb6e2bbd4e00&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-034&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 507, &quot;end&quot;: 515, &quot;title&quot;: &quot;#### 起草人回避&quot;, &quot;sha256&quot;: &quot;17eae03fd33f59846021d16bb7401717f548e7f4432681432f487545aa69b72d&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-035&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 516, &quot;end&quot;: 528, &quot;title&quot;: &quot;#### 判据自身的失效条件&quot;, &quot;sha256&quot;: &quot;55e27a31479b16af6f785e55fef235521f8ab028b80ba34edd12defc1d0975a9&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-036&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 529, &quot;end&quot;: 533, &quot;title&quot;: &quot;#### 一票否决项要事先列&quot;, &quot;sha256&quot;: &quot;a8f477fe4d70b7e594d205814b48902d78c3d4748c0e539d7c0ef0c48b2576c8&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-037&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 534, &quot;end&quot;: 552, &quot;title&quot;: &quot;## 8b. 两个脚本怎么调&quot;, &quot;sha256&quot;: &quot;2e5a0d4373a142ad468124aa719c967e1fdf5f4e30fa9757495e0cbc486abbc4&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-038&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 553, &quot;end&quot;: 563, &quot;title&quot;: &quot;### 退出码&quot;, &quot;sha256&quot;: &quot;0048e80805a07890a31441c3dfd61f3f28a2be41dd091ed0d490d5955a6cea03&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-039&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 564, &quot;end&quot;: 575, &quot;title&quot;: &quot;### 声明与计算对不上时&quot;, &quot;sha256&quot;: &quot;389ec90e15acf77ad0d986ec0322a19e22a07cac83ee3a84d83570a0e45d56c2&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-040&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 576, &quot;end&quot;: 580, &quot;title&quot;: &quot;## 8c. 组织者的两条纪律&quot;, &quot;sha256&quot;: &quot;ed7eef2d62055383508e8f0004b5de79f6656c4f6e51dc42dfd4ea2673c26f29&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-041&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 581, &quot;end&quot;: 603, &quot;title&quot;: &quot;### 8c.1 环节进行中，组织者不得写入参与方的工作区&quot;, &quot;sha256&quot;: &quot;2cbb6c299bb52f5fdf4c6e590bdb04694a109587ff8e5a83fa38a120398e54d7&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-042&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 604, &quot;end&quot;: 618, &quot;title&quot;: &quot;### 8c.2 代提交必须用 &#96;--author&#96;，且必须登记为欠账&quot;, &quot;sha256&quot;: &quot;ac3dacaeeda4e3710c71e741740ca0017b07a08c6ebe8bac0682b7dcdca20918&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-043&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 619, &quot;end&quot;: 623, &quot;title&quot;: &quot;## 9. ① 提案：隔离与冻结&quot;, &quot;sha256&quot;: &quot;046b7965313a82fc5b688c1662d82f45077e6ccd58267b72210e33a296fe80b2&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-044&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 624, &quot;end&quot;: 643, &quot;title&quot;: &quot;### 9.1 隔离为什么是硬要求&quot;, &quot;sha256&quot;: &quot;3f3790ee1ef63d193ce93cfceb8aa0d140865a9a0ce2951c20bee30b8570c42a&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-045&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 644, &quot;end&quot;: 674, &quot;title&quot;: &quot;### 9.2 工单发什么、不发什么&quot;, &quot;sha256&quot;: &quot;e52e2b9a38ad023a0c688d96b589a34d2ca301997e2486111c18d3111c807ae2&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-046&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 675, &quot;end&quot;: 689, &quot;title&quot;: &quot;### 9.3 机制化隔离：曾经有过，已经删掉&quot;, &quot;sha256&quot;: &quot;313d76a7dd3a24271a9a9dd5c483291cab6439fffc39d6cdc11b818ff58fa1fc&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-047&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 690, &quot;end&quot;: 712, &quot;title&quot;: &quot;## 10. ② 互评：评审文件写什么&quot;, &quot;sha256&quot;: &quot;0333dc6b3f3d835f385223506bc1f567f6ecbe2177b0ed9a378fc90c8f82eb1e&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-048&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 713, &quot;end&quot;: 723, &quot;title&quot;: &quot;## 11. ③ 裁决：定基座与吸收&quot;, &quot;sha256&quot;: &quot;ffefcb865111042c71eec4a1d0d61b6eab0a13429e8d56188a665b86b521e9e4&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-049&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 724, &quot;end&quot;: 740, &quot;title&quot;: &quot;## 12. ④ 异议：对整合权的唯一制衡&quot;, &quot;sha256&quot;: &quot;a0e351de21d20e1e5183891df29419b0a15e0d5ba006bf964c0475831c17ad5b&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-050&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 741, &quot;end&quot;: 759, &quot;title&quot;: &quot;## 13. ⑤ 验收 与 ⑥ 确认&quot;, &quot;sha256&quot;: &quot;9630ce23cb1f5deb38d45ccc424485be10f7dff28eeb70f6fb36277bcaaa5805&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-051&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 760, &quot;end&quot;: 779, &quot;title&quot;: &quot;### 13.1 定向审核分两阶段，防止被产出方锚定&quot;, &quot;sha256&quot;: &quot;7151fe1820f7034fc6cd7e32943a0577fc180e5332418a90111783fe2d7a3cb1&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-052&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 780, &quot;end&quot;: 788, &quot;title&quot;: &quot;### 13.2 验收通过意味着什么，不意味着什么&quot;, &quot;sha256&quot;: &quot;3495c7a5d802edc325e35301968efca8e5c970ce06b9b74c2f977c7d50afe989&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-053&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 789, &quot;end&quot;: 802, &quot;title&quot;: &quot;## 14. 停止、超时与回退&quot;, &quot;sha256&quot;: &quot;04e2930c6a7233a513494300f9d42b6acf21e363ae64527b3654138a312dee87&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-054&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 803, &quot;end&quot;: 882, &quot;title&quot;: &quot;### 14.1 参与方不可用：逾期、弃权与换人&quot;, &quot;sha256&quot;: &quot;f8fc4be2afeb30883e41a21beef559aada5603fb30f1cac0ca5ef2490f687683&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-055&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 883, &quot;end&quot;: 901, &quot;title&quot;: &quot;## 15. 角色不分会怎样&quot;, &quot;sha256&quot;: &quot;ebd100ea22ee1090a73729b0e7f89a227f22545f0ef14fb4cc0446dda6a59f6b&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-056&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 902, &quot;end&quot;: 916, &quot;title&quot;: &quot;## 16. ⑦ 清理与发布&quot;, &quot;sha256&quot;: &quot;d87754dac30c4231ce0b2bec8d2fc2c093617fec19df84bba03b8d3807a38a8c&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;P-057&quot;, &quot;path&quot;: &quot;protocol/round-protocol.md&quot;, &quot;line&quot;: 917, &quot;end&quot;: 929, &quot;title&quot;: &quot;## 17. 通用纪律&quot;, &quot;sha256&quot;: &quot;2900fa181f1b50354db85878410a334942c2eb7896820028a74c7a3492c58be9&quot;, &quot;target&quot;: &quot;protocol/round-protocol.md&quot;, &quot;group&quot;: &quot;完整轮次规程&quot;, &quot;rule&quot;: &quot;只收不随轮次变化的规则；参数、当次例外和产物留 rounds，不按实现现状静默降低规范。&quot;},
{&quot;id&quot;: &quot;T-001&quot;, &quot;path&quot;: &quot;protocol/README.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 22, &quot;title&quot;: &quot;# &#96;protocol/&#96; —— 流程规范与它的实现&quot;, &quot;sha256&quot;: &quot;758978d92e753c343ff2c33bdb8f39cf0c342fb2c54237c92f15c287c1c6aefc&quot;, &quot;target&quot;: &quot;protocol/README.md&quot;, &quot;group&quot;: &quot;脚本接口及实现约束&quot;, &quot;rule&quot;: &quot;可执行接口、状态计算责任及已知限制；不收当轮执行日志。&quot;},
{&quot;id&quot;: &quot;T-002&quot;, &quot;path&quot;: &quot;protocol/README.md&quot;, &quot;line&quot;: 23, &quot;end&quot;: 32, &quot;title&quot;: &quot;## 三条设计约束，改这里的代码前先读&quot;, &quot;sha256&quot;: &quot;8dd0ec495565418d52aa031b0b2914dbc96d21b0195e10af76d984646d3f0091&quot;, &quot;target&quot;: &quot;protocol/README.md&quot;, &quot;group&quot;: &quot;脚本接口及实现约束&quot;, &quot;rule&quot;: &quot;可执行接口、状态计算责任及已知限制；不收当轮执行日志。&quot;},
{&quot;id&quot;: &quot;T-003&quot;, &quot;path&quot;: &quot;protocol/README.md&quot;, &quot;line&quot;: 33, &quot;end&quot;: 38, &quot;title&quot;: &quot;## 单一真源&quot;, &quot;sha256&quot;: &quot;9a2e394190bc97aa4962cd6bb0125e79604efbc7b749385b29da7be80132fbcd&quot;, &quot;target&quot;: &quot;protocol/README.md&quot;, &quot;group&quot;: &quot;脚本接口及实现约束&quot;, &quot;rule&quot;: &quot;可执行接口、状态计算责任及已知限制；不收当轮执行日志。&quot;},
{&quot;id&quot;: &quot;T-004&quot;, &quot;path&quot;: &quot;protocol/README.md&quot;, &quot;line&quot;: 39, &quot;end&quot;: 46, &quot;title&quot;: &quot;## 已知不做的事&quot;, &quot;sha256&quot;: &quot;74ae159d70b850782f7c0e691e8cfdc2fdf00c52ae573051a405e69284eb9639&quot;, &quot;target&quot;: &quot;protocol/README.md&quot;, &quot;group&quot;: &quot;脚本接口及实现约束&quot;, &quot;rule&quot;: &quot;可执行接口、状态计算责任及已知限制；不收当轮执行日志。&quot;},
{&quot;id&quot;: &quot;C-001&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 12, &quot;title&quot;: &quot;# 开发必须遵守的规则&quot;, &quot;sha256&quot;: &quot;9896de6b95a2017f8b6e0666375be90be732eec1a04471c976c77de7bd85e652&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-002&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 13, &quot;end&quot;: 39, &quot;title&quot;: &quot;## 怎么用&quot;, &quot;sha256&quot;: &quot;4674596147384aca6c50d62ce32677ea582b7707e2b68001a7bb3d62a952a0f0&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-003&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 40, &quot;end&quot;: 53, &quot;title&quot;: &quot;## 数据&quot;, &quot;sha256&quot;: &quot;9ce9f390bc6ef3568ea6539869d836ba133e441d6d949e0f3ab7ed8448976e29&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-004&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 54, &quot;end&quot;: 70, &quot;title&quot;: &quot;### 做数据迁移时&quot;, &quot;sha256&quot;: &quot;d5afc083b2be89498be9d25320c8f3a3a58e9f2b33164ef3d241555bb65e72cc&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-005&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 71, &quot;end&quot;: 81, &quot;title&quot;: &quot;## 契约&quot;, &quot;sha256&quot;: &quot;15e0860aff2327e677f3dc0dfdb09b2c36f3ef8564646d10d7b152830c420839&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-006&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 82, &quot;end&quot;: 94, &quot;title&quot;: &quot;## 身份&quot;, &quot;sha256&quot;: &quot;97feffd0ab17a883c57b4514578ce27b3b37b3b4927569e191992c19e62d9621&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-007&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 95, &quot;end&quot;: 104, &quot;title&quot;: &quot;## 拓扑&quot;, &quot;sha256&quot;: &quot;19a7f1038693761aaf218e36e0b7561034f6e13c26f2336d31a49b161592b6d6&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-008&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 105, &quot;end&quot;: 115, &quot;title&quot;: &quot;### 什么时候才拆出专用 Worker&quot;, &quot;sha256&quot;: &quot;066c8c3a6899c9c7a9c7ac4385aba08e97da672ee5a5f796243a0abe3f5fd07c&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-009&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 116, &quot;end&quot;: 127, &quot;title&quot;: &quot;## 发布&quot;, &quot;sha256&quot;: &quot;846b2fd4655535a1369550d87d33331bb8f7797456ab94e8c03fdb7acabafc46&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-010&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 128, &quot;end&quot;: 136, &quot;title&quot;: &quot;### 改模板、同步实例时&quot;, &quot;sha256&quot;: &quot;e36bcc43b96db28190f13ff1a1c60064d0d973e5a52b755ab7501aae175e0375&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-011&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 137, &quot;end&quot;: 143, &quot;title&quot;: &quot;### 清理镜像时&quot;, &quot;sha256&quot;: &quot;f76c3eab37fae20a0a28f1fccbe4497c573ef38d2699200bd630eac29996ece3&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-012&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 144, &quot;end&quot;: 148, &quot;title&quot;: &quot;### 一条环境事实&quot;, &quot;sha256&quot;: &quot;532207857c4c9aeedeb33b812199c41cffb2d0cb13fd3541c9bc4884a66f65b4&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-013&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 149, &quot;end&quot;: 160, &quot;title&quot;: &quot;## 智能体&quot;, &quot;sha256&quot;: &quot;db4c3025e20d3f9d3fba7bc9152e62bdf7b02ab6d89202e1394275ae4e3d9613&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-014&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 161, &quot;end&quot;: 180, &quot;title&quot;: &quot;## 保证这些被遵守的三层&quot;, &quot;sha256&quot;: &quot;fdef054a43d01c8040bb9d016de53ae44d0567422bd015324a302ad5b9d5ed09&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;C-015&quot;, &quot;path&quot;: &quot;constraints.md&quot;, &quot;line&quot;: 181, &quot;end&quot;: 214, &quot;title&quot;: &quot;### &#96;doc-gate.py&#96; 为什么不是第三个被删的脚本&quot;, &quot;sha256&quot;: &quot;53c976a3d820eb42176bf01def590c0d22a5de4626ea2f88cc169c80666450b6&quot;, &quot;target&quot;: &quot;constraints.md&quot;, &quot;group&quot;: &quot;约束与执行载体&quot;, &quot;rule&quot;: &quot;以数据、契约、身份、拓扑、发布、智能体影响面判相关性；进度不作为规则，历史失败只解释规则适用限制。&quot;},
{&quot;id&quot;: &quot;D-001&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 9, &quot;title&quot;: &quot;# 开发计划&quot;, &quot;sha256&quot;: &quot;8055b3106ed9b6550da0058d9cb9e81602aa43eaf9196b023e2f6b15aef1b2a0&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧入口上下文&quot;, &quot;rule&quot;: &quot;旧计划/交接前言及 README 旧索引原文留证；新的入口由装配配方生成。&quot;},
{&quot;id&quot;: &quot;D-002&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 10, &quot;end&quot;: 23, &quot;title&quot;: &quot;## 起点：不延续 v5&quot;, &quot;sha256&quot;: &quot;0d5bffad5c99a490a12a8e3847eab5a709de2b4242ebad50c2002aac2c087b26&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;产品取舍&quot;, &quot;rule&quot;: &quot;回答功能为什么做或暂不做；保持原阶段和观察日期限定，不把状态当作目标。&quot;},
{&quot;id&quot;: &quot;D-003&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 24, &quot;end&quot;: 35, &quot;title&quot;: &quot;## 智能体分两部分&quot;, &quot;sha256&quot;: &quot;1f3498e3a3dea5e5681b639d5280bcb6f285065b60e2dc28db95af55dc9a296a&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;持久责任与组件&quot;, &quot;rule&quot;: &quot;跨进程仍须成立的四账、组件责任及通用/专用界线在此；SDK 私有细节排除。&quot;},
{&quot;id&quot;: &quot;D-004&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 36, &quot;end&quot;: 43, &quot;title&quot;: &quot;### 四本账是两部分共用的地基&quot;, &quot;sha256&quot;: &quot;ddf38efb8dd6ffa95ee3ee232c72b2c394395dfb8cee0a4ffc5d225a28332b1e&quot;, &quot;target&quot;: &quot;specs/runtime.md&quot;, &quot;group&quot;: &quot;持久责任与组件&quot;, &quot;rule&quot;: &quot;跨进程仍须成立的四账、组件责任及通用/专用界线在此；SDK 私有细节排除。&quot;},
{&quot;id&quot;: &quot;D-005&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 44, &quot;end&quot;: 63, &quot;title&quot;: &quot;### 执行层租用，不自建&quot;, &quot;sha256&quot;: &quot;cd79e37cec9704b2717f43cfe493ab5666b161c151e4d28a6fc56e8a00a88628&quot;, &quot;target&quot;: &quot;specs/executor.md&quot;, &quot;group&quot;: &quot;租用边界与能力&quot;, &quot;rule&quot;: &quot;执行原语的租/建选择、SDK 范围和版本限定；历史读数不据此升格为今天实测。&quot;},
{&quot;id&quot;: &quot;D-006&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 64, &quot;end&quot;: 67, &quot;title&quot;: &quot;## 三个阶段&quot;, &quot;sha256&quot;: &quot;50d3034d4b55f0386612c9fbb787f7d91f85521bf8fd90b1b43defcbeb94da7a&quot;, &quot;target&quot;: &quot;work/roadmap.md&quot;, &quot;group&quot;: &quot;产品建设阶段&quot;, &quot;rule&quot;: &quot;要建什么及开工条件；含历史现状的段落按源日期读取，需要最新事实时另取证。&quot;},
{&quot;id&quot;: &quot;D-007&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 68, &quot;end&quot;: 96, &quot;title&quot;: &quot;### 一 · 前后端对接&quot;, &quot;sha256&quot;: &quot;e5b2fd6f3530dee79af89b7f91042b0998bf1da6ebbbc63e18aee27e0148deb6&quot;, &quot;target&quot;: &quot;work/roadmap.md&quot;, &quot;group&quot;: &quot;产品建设阶段&quot;, &quot;rule&quot;: &quot;要建什么及开工条件；含历史现状的段落按源日期读取，需要最新事实时另取证。&quot;},
{&quot;id&quot;: &quot;D-008&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 97, &quot;end&quot;: 109, &quot;title&quot;: &quot;### 二 · agent 开发&quot;, &quot;sha256&quot;: &quot;36a9c3a4830131f870225ebb9687fef4c6f81192261ba6ce9fb37a787f5cf51e&quot;, &quot;target&quot;: &quot;work/roadmap.md&quot;, &quot;group&quot;: &quot;产品建设阶段&quot;, &quot;rule&quot;: &quot;要建什么及开工条件；含历史现状的段落按源日期读取，需要最新事实时另取证。&quot;},
{&quot;id&quot;: &quot;D-009&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 110, &quot;end&quot;: 133, &quot;title&quot;: &quot;### 三 · 结构化数据问答（后期）&quot;, &quot;sha256&quot;: &quot;66ba02171e4827bee6b9be29a18e7858cbae3125a3343c3f1c4e7ff32dffba06&quot;, &quot;target&quot;: &quot;work/roadmap.md&quot;, &quot;group&quot;: &quot;产品建设阶段&quot;, &quot;rule&quot;: &quot;要建什么及开工条件；含历史现状的段落按源日期读取，需要最新事实时另取证。&quot;},
{&quot;id&quot;: &quot;D-010&quot;, &quot;path&quot;: &quot;development-plan.md&quot;, &quot;line&quot;: 134, &quot;end&quot;: 142, &quot;title&quot;: &quot;## 有意留白的两处&quot;, &quot;sha256&quot;: &quot;bb2f1663c7d5fe79bc33f4375c4872b18993976f10c98140e5962554819afef9&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;产品取舍&quot;, &quot;rule&quot;: &quot;回答功能为什么做或暂不做；保持原阶段和观察日期限定，不把状态当作目标。&quot;},
{&quot;id&quot;: &quot;I-001&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 10, &quot;title&quot;: &quot;# 实施计划&quot;, &quot;sha256&quot;: &quot;a3210412c57feae15e4f023caeac2a2057775c8b4f3e1a420070aa7c16bf8ffc&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧入口上下文&quot;, &quot;rule&quot;: &quot;旧计划/交接前言及 README 旧索引原文留证；新的入口由装配配方生成。&quot;},
{&quot;id&quot;: &quot;I-002&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 11, &quot;end&quot;: 26, &quot;title&quot;: &quot;## 任务条目格式&quot;, &quot;sha256&quot;: &quot;df8f4d171db2e7656dcf23738a203ad88aaca5dc3f1ae8c340680323ca361c56&quot;, &quot;target&quot;: &quot;playbooks/intake.md&quot;, &quot;group&quot;: &quot;记录表单&quot;, &quot;rule&quot;: &quot;要求执行者填写的持久记录与任务条目字段；具体任务清单属于 work/delivery。&quot;},
{&quot;id&quot;: &quot;I-003&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 27, &quot;end&quot;: 37, &quot;title&quot;: &quot;## 测试层次&quot;, &quot;sha256&quot;: &quot;4bfef647952fad541626de7a6e3f6136bf69a1b06d31afc04f4af1df28e7105b&quot;, &quot;target&quot;: &quot;playbooks/review.md&quot;, &quot;group&quot;: &quot;验收与整合&quot;, &quot;rule&quot;: &quot;测试层次、证据最小集和事实/选择的区分必须一起读；不存在用票数替代证据的入口。&quot;},
{&quot;id&quot;: &quot;I-004&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 38, &quot;end&quot;: 52, &quot;title&quot;: &quot;## 交付规则&quot;, &quot;sha256&quot;: &quot;76c0139479c95502f5a7c9259b4910d46f51f9a97aa4053f9cc09a252c813609&quot;, &quot;target&quot;: &quot;playbooks/delivery.md&quot;, &quot;group&quot;: &quot;完成与证据包&quot;, &quot;rule&quot;: &quot;先证明任务完成和跨仓交付满足条目要求；不以脚本退出码单独证明完成。&quot;},
{&quot;id&quot;: &quot;I-005&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 53, &quot;end&quot;: 76, &quot;title&quot;: &quot;## 阶段〇 · 开发框架自身的实施路线（R0–R5）&quot;, &quot;sha256&quot;: &quot;6f267053e757d695be8bda0763d4917b9d6d71977cb72b288fae4eb2f532786d&quot;, &quot;target&quot;: &quot;records/guide-history.md&quot;, &quot;group&quot;: &quot;旧路线及当时进度&quot;, &quot;rule&quot;: &quot;G-094 已明确旧 R0–R5/S1 不作为现行路线；原实施表及旧进度完整保留供追溯，不能再以现在任务名义发出。&quot;},
{&quot;id&quot;: &quot;I-006&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 77, &quot;end&quot;: 78, &quot;title&quot;: &quot;## 阶段一 · 前后端对接&quot;, &quot;sha256&quot;: &quot;292e785931b999e1f3895dbea75b888f289a6a6090681198c1354e714c7d1f7a&quot;, &quot;target&quot;: &quot;work/delivery.md&quot;, &quot;group&quot;: &quot;产品任务&quot;, &quot;rule&quot;: &quot;阶段一空任务清单及阶段二/三前置完整保留；未决前不开工不能被空表覆盖检查掩盖。&quot;},
{&quot;id&quot;: &quot;I-007&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 79, &quot;end&quot;: 85, &quot;title&quot;: &quot;### 任务清单&quot;, &quot;sha256&quot;: &quot;48cf99f4ff8bdd38ae24437d3fcd15160e0e1b5c10d261a449bde365acd42ca4&quot;, &quot;target&quot;: &quot;work/delivery.md&quot;, &quot;group&quot;: &quot;产品任务&quot;, &quot;rule&quot;: &quot;阶段一空任务清单及阶段二/三前置完整保留；未决前不开工不能被空表覆盖检查掩盖。&quot;},
{&quot;id&quot;: &quot;I-008&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 86, &quot;end&quot;: 89, &quot;title&quot;: &quot;## 阶段二 · agent 开发&quot;, &quot;sha256&quot;: &quot;828e363521485eb77cab504595f18b9fdce7de18ecf5f8b82c6e4c5114911c3a&quot;, &quot;target&quot;: &quot;work/delivery.md&quot;, &quot;group&quot;: &quot;产品任务&quot;, &quot;rule&quot;: &quot;阶段一空任务清单及阶段二/三前置完整保留；未决前不开工不能被空表覆盖检查掩盖。&quot;},
{&quot;id&quot;: &quot;I-009&quot;, &quot;path&quot;: &quot;implementation-plan.md&quot;, &quot;line&quot;: 90, &quot;end&quot;: 93, &quot;title&quot;: &quot;## 阶段三 · 结构化数据问答&quot;, &quot;sha256&quot;: &quot;ae0a101c22b064d01722c78153217cea0fb801e91f28d5d67b9c4858bca463ad&quot;, &quot;target&quot;: &quot;work/delivery.md&quot;, &quot;group&quot;: &quot;产品任务&quot;, &quot;rule&quot;: &quot;阶段一空任务清单及阶段二/三前置完整保留；未决前不开工不能被空表覆盖检查掩盖。&quot;},
{&quot;id&quot;: &quot;H-001&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 13, &quot;title&quot;: &quot;# 交接&quot;, &quot;sha256&quot;: &quot;1bea42449cbe09fa22c0db47a2d321f78757b6aba3cea997dcb1931d500fd58c&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧入口上下文&quot;, &quot;rule&quot;: &quot;旧计划/交接前言及 README 旧索引原文留证；新的入口由装配配方生成。&quot;},
{&quot;id&quot;: &quot;H-002&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 14, &quot;end&quot;: 20, &quot;title&quot;: &quot;## 当前阶段&quot;, &quot;sha256&quot;: &quot;a5f226a4399cd6c7405dd15c0132b9a2013b6455fbb1c11e6f012f3f27339c68&quot;, &quot;target&quot;: &quot;work/status.md&quot;, &quot;group&quot;: &quot;产品状态&quot;, &quot;rule&quot;: &quot;阶段、已就位能力与任务游标是观察字段；不从没有调用推出不需要调用，也不将八月观察升级为今天现状。&quot;},
{&quot;id&quot;: &quot;H-003&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 21, &quot;end&quot;: 29, &quot;title&quot;: &quot;## 已经就位的（不用再做）&quot;, &quot;sha256&quot;: &quot;34b79d8a45ed5de8fb9833f1e9ca305e1678642fbd54ff6838e4e8e1cdcabc04&quot;, &quot;target&quot;: &quot;work/status.md&quot;, &quot;group&quot;: &quot;产品状态&quot;, &quot;rule&quot;: &quot;阶段、已就位能力与任务游标是观察字段；不从没有调用推出不需要调用，也不将八月观察升级为今天现状。&quot;},
{&quot;id&quot;: &quot;H-004&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 30, &quot;end&quot;: 41, &quot;title&quot;: &quot;## 未决项&quot;, &quot;sha256&quot;: &quot;c0ed70dcce404cbadcaaa538c29599dd9dda059055c1807b9c5a2055f77ce9a8&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;未决输入&quot;, &quot;rule&quot;: &quot;U1–U5 与其已知事实作为决策材料，不从已知字段推出方案已定。&quot;},
{&quot;id&quot;: &quot;H-005&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 42, &quot;end&quot;: 50, &quot;title&quot;: &quot;### U1 的已知输入&quot;, &quot;sha256&quot;: &quot;0ba1033af120563e340701b9d5da301a5ad213fa317abca3be69aa0ec442108b&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;未决输入&quot;, &quot;rule&quot;: &quot;U1–U5 与其已知事实作为决策材料，不从已知字段推出方案已定。&quot;},
{&quot;id&quot;: &quot;H-006&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 51, &quot;end&quot;: 58, &quot;title&quot;: &quot;### U3 的已知输入&quot;, &quot;sha256&quot;: &quot;63e1448c2e8619a3342a049743f491e7982d88b04187c712a0c0db5139dfe4c8&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;未决输入&quot;, &quot;rule&quot;: &quot;U1–U5 与其已知事实作为决策材料，不从已知字段推出方案已定。&quot;},
{&quot;id&quot;: &quot;H-007&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 59, &quot;end&quot;: 67, &quot;title&quot;: &quot;### U4 的已知输入&quot;, &quot;sha256&quot;: &quot;5512fca05def7601d853e9f3b288074e1b020d3a3e3216051c49bd54f76744c5&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;未决输入&quot;, &quot;rule&quot;: &quot;U1–U5 与其已知事实作为决策材料，不从已知字段推出方案已定。&quot;},
{&quot;id&quot;: &quot;H-008&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 68, &quot;end&quot;: 79, &quot;title&quot;: &quot;## 不能倒退的输入&quot;, &quot;sha256&quot;: &quot;aabd59897abbb06a7029bfc096f791351356e4ef40599a0522e285ab8940797c&quot;, &quot;target&quot;: &quot;specs/foundation.md&quot;, &quot;group&quot;: &quot;产品取舍&quot;, &quot;rule&quot;: &quot;回答功能为什么做或暂不做；保持原阶段和观察日期限定，不把状态当作目标。&quot;},
{&quot;id&quot;: &quot;H-009&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 80, &quot;end&quot;: 92, &quot;title&quot;: &quot;## 文档面待办&quot;, &quot;sha256&quot;: &quot;af08f3b4ea5e8f67452d866f53d05d58686a1e2849a4e717b7dd2a76a4f5c783&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;风险与验证债&quot;, &quot;rule&quot;: &quot;现有风险和 SDK 未验证清单先于开工；不能把列表存在当作验证完成。&quot;},
{&quot;id&quot;: &quot;H-010&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 93, &quot;end&quot;: 97, &quot;title&quot;: &quot;## 任务游标&quot;, &quot;sha256&quot;: &quot;ec4a33c74a659f5e6141594410ad6bdb102c96a7b0f79d4189c1cc1f50fced27&quot;, &quot;target&quot;: &quot;work/status.md&quot;, &quot;group&quot;: &quot;产品状态&quot;, &quot;rule&quot;: &quot;阶段、已就位能力与任务游标是观察字段；不从没有调用推出不需要调用，也不将八月观察升级为今天现状。&quot;},
{&quot;id&quot;: &quot;H-011&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 98, &quot;end&quot;: 117, &quot;title&quot;: &quot;## 开发框架自身（R0–R5 路线）的进度&quot;, &quot;sha256&quot;: &quot;50a2fdbe5c34ee52604e2b5df801f980bd2320a3e89015f5ac336c6f6b085626&quot;, &quot;target&quot;: &quot;records/guide-history.md&quot;, &quot;group&quot;: &quot;旧路线及当时进度&quot;, &quot;rule&quot;: &quot;G-094 已明确旧 R0–R5/S1 不作为现行路线；原实施表及旧进度完整保留供追溯，不能再以现在任务名义发出。&quot;},
{&quot;id&quot;: &quot;H-012&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 118, &quot;end&quot;: 126, &quot;title&quot;: &quot;## 已完成的轮次&quot;, &quot;sha256&quot;: &quot;d5d442bc498e2a0cdaf7097a976c0524825a4002f3e66e5d3a966fabd5eeee1e&quot;, &quot;target&quot;: &quot;records/guide-history.md&quot;, &quot;group&quot;: &quot;旧路线及当时进度&quot;, &quot;rule&quot;: &quot;G-094 已明确旧 R0–R5/S1 不作为现行路线；原实施表及旧进度完整保留供追溯，不能再以现在任务名义发出。&quot;},
{&quot;id&quot;: &quot;H-013&quot;, &quot;path&quot;: &quot;handoff.md&quot;, &quot;line&quot;: 127, &quot;end&quot;: 131, &quot;title&quot;: &quot;## 不能倒退的两条（本轮新增）&quot;, &quot;sha256&quot;: &quot;6a5176405320dce09b6f4ed176cd4eb55f67f07a131bbf9339abe9522969cebf&quot;, &quot;target&quot;: &quot;work/questions.md&quot;, &quot;group&quot;: &quot;风险与验证债&quot;, &quot;rule&quot;: &quot;现有风险和 SDK 未验证清单先于开工；不能把列表存在当作验证完成。&quot;},
{&quot;id&quot;: &quot;M-001&quot;, &quot;path&quot;: &quot;README.md&quot;, &quot;line&quot;: 1, &quot;end&quot;: 24, &quot;title&quot;: &quot;# dev-plan — 代码要符合什么、接下来建什么&quot;, &quot;sha256&quot;: &quot;b740e86ba1173c4df5acba1aa3e5a9648a8ba14831fabd34b8a777c1c2dba2d6&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧入口上下文&quot;, &quot;rule&quot;: &quot;旧计划/交接前言及 README 旧索引原文留证；新的入口由装配配方生成。&quot;},
{&quot;id&quot;: &quot;M-002&quot;, &quot;path&quot;: &quot;README.md&quot;, &quot;line&quot;: 25, &quot;end&quot;: 36, &quot;title&quot;: &quot;## 各文档的分工，别混写&quot;, &quot;sha256&quot;: &quot;8f6f58fa2d02b9cbdd881b09f43e91e2b806e719ba730edd070f19b88b5137e7&quot;, &quot;target&quot;: &quot;records/migration-context.md&quot;, &quot;group&quot;: &quot;旧入口上下文&quot;, &quot;rule&quot;: &quot;旧计划/交接前言及 README 旧索引原文留证；新的入口由装配配方生成。&quot;}
],
&quot;decisions&quot;: &#91;
{&quot;id&quot;: &quot;round/refact-fable/R1&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 9, &quot;sha256&quot;: &quot;832e2b82a44c828baf103b63a797f31e1811b39c4329b2175981df484ff1a46d&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R2&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 10, &quot;sha256&quot;: &quot;c53121f112869d0e22564be6c9c5eb74396fb486382b8d896f744e32b0d6a680&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R3&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 11, &quot;sha256&quot;: &quot;3b477b4e1b9a2d79b51c280fcc38514a6f8ce637c1e3db24d9684265c6b612e2&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R4&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 12, &quot;sha256&quot;: &quot;f427fe5c7c4f31666679ffdf2be439364fef92ebf80b2a427ecaca1cacb16668&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R5&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 13, &quot;sha256&quot;: &quot;3dc3bb3c4618f852444db9cf71f423ed8343fff8513b04ce880ffb12d2ae4ad1&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R6&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 14, &quot;sha256&quot;: &quot;6741d13954422c7b167ecef9801c858d56ceacbb26fec206d0268a4c163021ef&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R7&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 15, &quot;sha256&quot;: &quot;b027829fcc69060fed6415758ca0413fe943c0f499a04a71df5831ddc2280c8f&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R8&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 16, &quot;sha256&quot;: &quot;8e9442d17505b130512c0c027fdf41297b446a88e4a791034753c2ae4cf21441&quot;},
{&quot;id&quot;: &quot;round/refact-fable/R9&quot;, &quot;path&quot;: &quot;rounds/refact-fable/rulings.md&quot;, &quot;line&quot;: 17, &quot;sha256&quot;: &quot;976e28a5ac0913d3863e4e6708adbf4c1737324133b81f6c375434b970f8ae6d&quot;},
{&quot;id&quot;: &quot;round/runtime/R1&quot;, &quot;path&quot;: &quot;rounds/runtime/rulings.md&quot;, &quot;line&quot;: 13, &quot;sha256&quot;: &quot;8dcf8996f0e76f3ad65c5d18fefb6719448f87f1c4530c4a4a95bb5473c60547&quot;},
{&quot;id&quot;: &quot;round/runtime/R2&quot;, &quot;path&quot;: &quot;rounds/runtime/rulings.md&quot;, &quot;line&quot;: 14, &quot;sha256&quot;: &quot;cf7edffd5c5478b5cbfad3317d044109e2139d2ce2e19376687d47535395878e&quot;},
{&quot;id&quot;: &quot;round/runtime/R3&quot;, &quot;path&quot;: &quot;rounds/runtime/rulings.md&quot;, &quot;line&quot;: 15, &quot;sha256&quot;: &quot;b70e81ef3e3f18a73b3f6a449b88d3b7d9c32cd75dfd65fd0afeef4df2f1c642&quot;},
{&quot;id&quot;: &quot;round/runtime/R4&quot;, &quot;path&quot;: &quot;rounds/runtime/rulings.md&quot;, &quot;line&quot;: 16, &quot;sha256&quot;: &quot;a7dae0c6279a0c3aa61f2423d50a30af749d6b735cae82748a40b852421bb4f0&quot;},
{&quot;id&quot;: &quot;round/runtime/R5&quot;, &quot;path&quot;: &quot;rounds/runtime/rulings.md&quot;, &quot;line&quot;: 17, &quot;sha256&quot;: &quot;e12c1db1ea88e30c8baa8d5b008a787c55095240849990a1b5d5a1339afb5dd9&quot;},
{&quot;id&quot;: &quot;round/runtime/R6&quot;, &quot;path&quot;: &quot;rounds/runtime/rulings.md&quot;, &quot;line&quot;: 18, &quot;sha256&quot;: &quot;85a3c24071c9ae482c680144f8cca555c4ecf1ed79623d3d267d95483f465476&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R1&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 12, &quot;sha256&quot;: &quot;f414fd24e844838bc1630bba4ba94ff1c4991beabf2ed657973879eba38f48dd&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R2&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 13, &quot;sha256&quot;: &quot;58683e37b2a191e295bafac41ca5b1a78953254e66e6cd243e2ec29670c0c758&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R3&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 14, &quot;sha256&quot;: &quot;7e49c01f87d44f3ac969d53016eb62d755ae36559b089c5e5f133fbeaaf6a5bc&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R4&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 15, &quot;sha256&quot;: &quot;4cad2e4fde41570475e3c3bd55eab0801e336e134cd6f49a2532e69d4c41c229&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R5&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 16, &quot;sha256&quot;: &quot;7ae33c03469bafd92e8c47c810cda83cbb44901b0df1183d909263b268e2a733&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R6&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 17, &quot;sha256&quot;: &quot;b079500d16f4a18f9ea941430078977dbc71d0438d7e24ec6f575224d697fbe3&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R7&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 18, &quot;sha256&quot;: &quot;e653aeb6f8e1cd39b9542aaa8ac3c9a2e24c3c0d94cef781ebbd92ed25ef9795&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R8&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 19, &quot;sha256&quot;: &quot;86c4186d988dd833ab32416270aa03cd3070260c5c0e4a898ae1e24626e7253f&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R9&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 20, &quot;sha256&quot;: &quot;b96969fbad1d81ed42379ccb27efed5d86fb01b65f6f6518091dabccd562efc4&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R10&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 21, &quot;sha256&quot;: &quot;6c810d62af7e90ad30abcfcef281397c05a1f3ff7120d611f82616268a25d179&quot;},
{&quot;id&quot;: &quot;round/runtime-refact/R11&quot;, &quot;path&quot;: &quot;rounds/runtime-refact/rulings.md&quot;, &quot;line&quot;: 22, &quot;sha256&quot;: &quot;7069a1e02e7e402cb0e3d63bfdd50da5756d97ab7a846dbe4943aa70da66fe76&quot;}
],
&quot;rulings&quot;: {&quot;rounds/refact-fable/rulings.md&quot;: {&quot;sha256&quot;: &quot;f4e0c663a523fc7e4160a185021cacdc0b6ab7e5542e92430defd722c8894812&quot;}, &quot;rounds/runtime/rulings.md&quot;: {&quot;sha256&quot;: &quot;8c90937769c44da687a0afa8d9c27cc872f81c31c33640139c6381258843b915&quot;}, &quot;rounds/runtime-refact/rulings.md&quot;: {&quot;sha256&quot;: &quot;b5f57762543cf49c380ff71aabb2dbf134471b1b2d072da8dd2e80d1272a6f05&quot;}},
&quot;protected&quot;: {&quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-001-架构重构/request.md&quot;: &quot;018af6fc8132ac23d4806b9ffc3266b62f05f77ed9dfdb822e831e2cb7f03711&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-002-基线核对整改/plan-baseline.md&quot;: &quot;2dffea66a961dae576c4e718eb0bc46fceb781509a04001398de9df4ca2cca11&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-002-基线核对整改/request.md&quot;: &quot;697d74c1262cc66fe955bdde9c02243eeb1fea4f07a5affbb0b4b28cd60033f7&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-003-文档集结构重组/baseline.md&quot;: &quot;92061bffe87d3698aebfd2334e6c47c4f6ba658e7c139f270b2a4438f2691b60&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-003-文档集结构重组/request.md&quot;: &quot;eb5273ae92c51bbba3b412dfe495fd2a50e170dc58d1450b2676b9fdfa16214d&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-004-现有代码投影/baseline.md&quot;: &quot;c5d90926953b9e276d938cdfa3207733ab0ca2b6dc26e68a2e04ea5ea1cfed21&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-004-现有代码投影/request.md&quot;: &quot;c9ca11458a0b2fe886bcf5348efc67c2c36ba2026f8869c17c5dd50dd2c05675&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-005-智能体集群开发/request.md&quot;: &quot;1a60dde001bb75812e9fd02157cf9ffc49a743ca89fe34cee6f05e24a3e39419&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-006-投资研究编排/baseline.md&quot;: &quot;3bbd619d43980a24a3d07ca599be3e2ab55fe3ff00262bc6cc76cb58b31bd41a&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-006-投资研究编排/request.md&quot;: &quot;575f774ba1776a5c03ee22849444fe59ced837815abe57103820d01d3cf6b995&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-007-核对流程技能化/request.md&quot;: &quot;bd4437248005f24601ebb2ea261e8946334c0dee4faf02615210faf5dbfc4807&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-008-五仓投影撰写/request.md&quot;: &quot;a98cc31e38c1152864120d1630c91537ea12af86788e02a35f2209e197222eec&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-009-休眠能力可识别/request.md&quot;: &quot;884712f131e2795959c6a5a5f96bd4c0c5f833bfb02e5d821db2d9dc180928c2&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-010-REQ模板完善/request.md&quot;: &quot;5834d7d7209b7d2894c0b0b141ddcea635afba0d8cd50a13decc7d054c2ffc79&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/REQ-010-REQ模板完善/template-proposed.md&quot;: &quot;035c4268022d5b648e17182a554020fbb910fec48d3e9c361185e44863d8f32d&quot;, &quot;sunmoonai/docs/dev-plan/working/request-baseline/TEMPLATE.md&quot;: &quot;84f529c3e2d735bbc080251ae9ef5fe0e571b2e478e3d6df1cfe6c9b75b8a5e1&quot;}
}</pre>
<!-- DATA END -->

<!-- TOOL BEGIN -->
```python
import re, json, html, hashlib, subprocess, pathlib, sys

def digest(b):
    return hashlib.sha256(b).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args])

meta = json.loads(html.unescape(s.split('<!-- DATA BEGIN -->\n<pre>', 1)[1].split('</pre>\n<!-- DATA END -->', 1)[0]))
chunks = {k: html.unescape(v) for k, v in re.findall(r'<pre data-unit="([A-Z]-[0-9]+)">(.*?)</pre>', s, re.S)}
rulings = {k: html.unescape(v) for k, v in re.findall(r'<pre data-ruling="([^"]+)">(.*?)</pre>', s, re.S)}
units = {u['id']: u for u in meta['units']}
base, prefix = meta['baseline'], meta['prefix']

def enumerate_source(text):
    lines = text.splitlines(keepends=True)
    starts, fence = [], False
    for i, line in enumerate(lines):
        if line.startswith('```'):
            fence = not fence
        if not fence and re.match(r'^#{1,4} ', line):
            starts.append(i)
    return [(a + 1, starts[n + 1] if n + 1 < len(starts) else len(lines), lines[a].strip()) for n, a in enumerate(starts)]

def verify():
    assert len(units) == len(chunks) == 260 and set(units) == set(chunks)
    assert len(re.findall(r'^<pre data-unit=', s, re.M)) == 260
    placed = []
    for d in meta['docs']:
        assert d['class'] in {'N', 'P', 'W', 'R', 'V'} and d['why']
        for g in d['groups']:
            assert g['rule'] and g['units']
            for uid in g['units']:
                u = units[uid]
                assert (u['target'], u['group'], u['rule']) == (d['path'], g['name'], g['rule'])
                assert digest(chunks[uid].encode()) == u['sha256']
                placed.append(uid)
    assert len(placed) == 260 and len(set(placed)) == 260
    recipe = meta['guide_recipe']
    assert len(recipe) == len(set(recipe))
    assert set(recipe) == {d['path'] for d in meta['docs'] if d['class'] in {'N', 'P'}}
    mapping = s.split('## 安置表（', 1)[1].split('## 文档包：', 1)[0]
    rows = re.findall(r'^\| ([A-Z]-\d+) \| (.*?) \| (.*?) \| (.*?) \|$', mapping, re.M)
    assert len(rows) == 260 and {r[0] for r in rows} == set(units)
    for uid, source, title, target in rows:
        u = units[uid]
        assert source == u['path'] + ' L' + str(u['line'])
        assert target == u['target'] + ' / ' + u['group']
        expected = re.sub(r'^#+ ', '', u['title']).replace('|', '&#124;').replace('`', '')
        assert title == expected
    for path, f in meta['files'].items():
        frozen = git('show', base + ':' + prefix + path)
        assert digest(frozen) == f['sha256']
        assert frozen == git('show', 'c4b60abb:' + prefix + path)
        assert pathlib.Path(prefix + path).read_bytes() == frozen, ('输入已变化', path)
        source_units = sorted((u for u in units.values() if u['path'] == path), key=lambda u: u['line'])
        expected = enumerate_source(frozen.decode())
        assert len(expected) == f['sections'] == len(source_units)
        assert [(u['line'], u['end'], u['title']) for u in source_units] == expected
        assert ''.join(chunks[u['id']] for u in source_units).encode() == frozen
        assert len(frozen.decode().splitlines()) == f['lines']
    expected_decisions = []
    for path, f in meta['rulings'].items():
        frozen = git('show', base + ':' + prefix + path)
        assert digest(frozen) == f['sha256']
        assert rulings[path].encode() == frozen
        rid = path.split('/')[1]
        for n, line in enumerate(rulings[path].splitlines(), 1):
            m = re.match(r'^\| `R(\d+)` \|', line)
            if m:
                expected_decisions.append({'id': 'round/' + rid + '/R' + m[1], 'path': path, 'line': n, 'sha256': digest(line.encode())})
    assert expected_decisions == meta['decisions'] and len(expected_decisions) == 26
    assert len({d['id'] for d in expected_decisions}) == 26
    for path, sha in meta['protected'].items():
        assert digest(pathlib.Path(path).read_bytes()) == sha
        assert digest(git('show', base + ':' + path)) == sha
    print('PASS: 9 文件 / 5320 行 / 260 源节；260 唯一落点与正文；逐字节重建；26 全局裁定；15 原始需求及内核原文未变。')
    print('语义归属、旧 294 行吸收质量、外部实测真实性：本工具不判。')

def show(key):
    if key in chunks:
        print(json.dumps(units[key], ensure_ascii=False, indent=2))
        print(chunks[key], end='')
        return
    ds = [d for d in meta['docs'] if d['path'] == key]
    if len(ds) != 1:
        raise SystemExit('未知单元或目标路径: ' + key)
    d = ds[0]
    print(d['path'], d['class'], d['why'])
    for g in d['groups']:
        print('\n【' + g['name'] + '】', g['rule'])
        for uid in g['units']:
            u = units[uid]
            print('\n来源:', base, u['path'], 'L' + str(u['line']), uid)
            print(chunks[uid], end='')

def decisions(query):
    hits = 0
    context_paths = set()
    exact_id = query in {d['id'] for d in meta['decisions']}
    for d in meta['decisions']:
        line = rulings[d['path']].splitlines()[d['line'] - 1]
        if (exact_id and query == d['id']) or (not exact_id and query.casefold() in (d['id'] + line).casefold()):
            print(d['id'], base, d['path'], 'L' + str(d['line']), 'sha256=' + d['sha256'])
            print(line)
            print('适用性待按原记录判断；行后补充见以下 CONTEXT 或对应全文。')
            hits += 1
            context_paths.add(d['path'])
    for path, text in rulings.items():
        lines = text.splitlines()
        found = [i for i, line in enumerate(lines) if query.casefold() in line.casefold() and not re.match(r'^\| `R\d+` \|', line)]
        if path not in context_paths and (exact_id or not found):
            continue
        print('CONTEXT', base, path, '关联键集合:', ', '.join(d['id'] for d in meta['decisions'] if d['path'] == path))
        print('表外命中：不能凭相邻标题自动判定唯一裁定；以下保留完整上下文。')
        print(text)
        hits += 1
    if not hits:
        print('NO_MATCH：只代表此冻结版本的三个 rulings 未命中，不代表从未决定。')
        return 1
    return 0

def mapping():
    print('| 单元 | 冻结源路径与起行 | 原标题 | 目标 / 栏目 |')
    print('| --- | --- | --- | --- |')
    for uid, u in units.items():
        title = re.sub(r'^#+ ', '', u['title']).replace('|', '&#124;').replace('`', '')
        print('|', uid, '|', u['path'], 'L' + str(u['line']), '|', title, '|', u['target'], '/', u['group'], '|')

def view(name):
    if name != 'guide':
        raise SystemExit('当前可执行装配: view guide')
    print('开发指南装配 / 冻结源', base)
    print('本视图没有独立写入权；历史实测不等于今天验证，源节引用按来源上下文解释。')
    for path in meta['guide_recipe']:
        show(path)

routes = {'system': 'N/specs/（按组件主题；产品内核与 constraints 保留固定路径）', 'work-rule': 'P/playbooks/ 或 protocol/（七环节及脚本接口才进 protocol）', 'work-instance': 'W/work/delivery.md（未决材料进 questions，观察字段进 status）', 'record': 'R/records/work/<work-id>/（已有 round 则留原 rounds）', 'generated': 'V/入口视图（必须提交源清单与生成配方）'}
if len(sys.argv) < 2:
    raise SystemExit('用法: verify | map | show 单元或目标路径 | view guide | decisions 关键词或全局ID | route effect [subject]')
action = sys.argv[1]
if action == 'verify' and len(sys.argv) == 2:
    verify()
elif action == 'show' and len(sys.argv) == 3:
    show(sys.argv[2])
elif action == 'decisions' and len(sys.argv) == 3:
    raise SystemExit(decisions(sys.argv[2]))
elif action == 'map' and len(sys.argv) == 2:
    mapping()
elif action == 'view' and len(sys.argv) == 3:
    view(sys.argv[2])
elif action == 'route' and len(sys.argv) in {3, 4}:
    if sys.argv[2] not in routes:
        raise SystemExit('拒绝：effect 必须且只能是 system/work-rule/work-instance/record/generated 之一')
    effect = sys.argv[2]
    if len(sys.argv) == 3:
        print(routes[effect])
    else:
        subject = sys.argv[3]
        if effect == 'system' and subject in {'foundation','runtime','executor','authority','evidence'}:
            print('N/specs/' + subject + '.md')
        elif effect == 'record' and re.fullmatch(r'[a-z0-9][a-z0-9-]*', subject):
            print('R/records/work/' + subject + '/')
        elif effect == 'work-instance' and subject in {'roadmap','delivery','status','questions'}:
            print('W/work/' + subject + '.md')
        else:
            raise SystemExit('拒绝：未知主题，须先按文档包准入条件选定唯一现有责任面或提架构变更')
else:
    raise SystemExit('参数不合法')
```
<!-- TOOL END -->
