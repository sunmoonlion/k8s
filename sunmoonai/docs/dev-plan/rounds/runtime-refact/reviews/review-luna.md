# `runtime-refact` 轮 ② 互评：luna

> 身份：`luna`，由 `/home/zym/worktrees/luna/k8s` 的父目录名确定。
>
> 利益冲突声明：我是 luna 候选的作者，也是本轮评优方之一。以下四份候选使用同一套
> 冻结判据；把自己的候选排第一，不构成独立终审。
>
> 禁读声明：本次互评没有读取 `sunmoonai/docs/dev-plan/agent-dev-refact.md`。② 只解除
> 候选之间的隔离，不解除本轮裁定 R2。

## A. 自述

### A1. luna 候选做了什么

luna 候选新建十章，核心落法是：

- 以产品内核为唯一对象与状态真源，把 `dev.change/1` 写成 Task Profile，而不是第二套运行时；
- 把确定性组件、执行适配层、内容角色和 principal 分开命名；
- 给出开发工单、Task/Attempt 投影、T0/T1/T2 共用执行形状与工作区供给规则；
- 保留权力表、粒度三字段、E0–E4、S/R 等效、成本上界、绕过边界、L0–L3；
- 独立复核六项被证伪设计，改为直接使用 `interrupt()`、`Command(resume=...)` 和同一
  `thread_id` 的 checkpoint 原地恢复；
- 以 64 行逐节落点表和覆盖声明收口。

与其余候选的主要差异：luna 没有把“人的 Attempt”从源稿继续搬入正文，也没有把最终发布动作
交给人执行；人只作 requester/principal，publisher 在批准后实施。它也没有用一张未经复核的
五家当前值表冒充 Agent Profile 已落地。

### A2. 未验证、缺口与故意没写

- ⚠ 未验证 GUI 内模型、内部工具事件、外部托管方 key/branch protection、产品数据库迁移与
  预算/证据账；候选已在 §9.2 明列。
- ⚠ `Attempt kind` 与 typed Artifact 是否只是既有对象细化，仍需内核维护者裁定；候选只对后者
  显式标了未决，对前者标得不够醒目。
- `request-lifecycle.md` 的状态语义在 §1.1 有一段摘要，虽未另造定义，仍可再压缩成标题指针，
  以更稳地满足 J6。
- §3.4 的 T0 行写成“做 → 独立验收 → 确认”；准确边界应是“不可逆动作才需人确认”，
  否则会让可逆 T0 看起来也有固定确认触点。
- §10 对 `runtime-architecture` §2.3 的落点是字段登记与“具体未核值保持未知”，没有保留一张
  五家实测值快照。这是有意避免把易腐现状写进长期规范，但最终稿应把“为什么不搬快照”写成
  明确的“故意不要”，不能只靠落点后的短说明。
- 故意没搬 23 行历史 trace 明细、一次性目标文件树和旧 R0–R5 编号表：前两者可由历史重建，
  后者包含已证伪前置；正文保留读数、方法、依赖顺序和退出门。
- 没有把流程规范七环节逐条重写；只保留运行时投影和导读。

## B. 候选集冻结

四份均按 `call-②.md` 给出的 ref/commit 取件，不读工作区文件。哈希另以 blob id 交叉核过。

| 家 | worktree / 冻结路径 | 行 | 字节 | commit | SHA-256 |
| --- | --- | ---: | ---: | --- | --- |
| luna | `/home/zym/worktrees/luna/k8s`；`runtime-refact/luna:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 648 | 43921 | `39889605f21bd41d22501a426bc690e0df76f5a2` | `cc47d068c39c9bcd68b5f120a9794b4eecb3aacf60a2c1d8c72502afdb8dcfea` |
| kimi | `/home/zym/worktrees/kimi/k8s`；`runtime-refact/kimi:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 917 | 71858 | `dc8efd599e007ebe8c3e87e0209d317866cd61ef` | `913ccb082320b8e6470dc3d8566590c157aad6488fd15cb373b773e7f4a84774` |
| cursor | `/home/zym/worktrees/cursor/k8s`；`runtime-refact/cursor:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 921 | 70095 | `d8fdb32a94c678f489481b861a9cc63e72184298` | `926a974e02df238f3a180dc1afa20aa89333a2ba3fdebd2d24a18269971d5138` |
| qwen | `/home/zym/worktrees/qwen/k8s`；`runtime-refact/qwen:sunmoonai/docs/dev-plan/agent-dev-guide.md` | 187 | 22316 | `7d31265a8c0c0f905b0a420a39d0740602175ee5` | `e783ce080489c83783e99ee576cdaacfd508c80d47decc73437562b8d2213198` |

blob id 依次为 `410fd77c`、`fc5b7629`、`d4a11aaa`、`83644ad4`。

## C. 按冻结判据评优

判定记号：✅ 满足；◐ 有实质内容但需修；❌ 未满足或直接冲撞硬边界；⚠ 本次互评无法独立机械判。

### C1. 机械条 M1–M7

| 判据 | luna | kimi | cursor | qwen | 比较依据 |
| --- | --- | --- | --- | --- | --- |
| M1 64 行落点 | ✅ | ✅ | ✅ | ✅ | 四份固定路径形状均数得 64 行 |
| M2 每行有落点或充分理由 | ✅ | ✅ | ✅ | ✅ | 均有章节号或具体“故意不要”理由；未见只写“已过时” |
| M3 两门禁 | ⚠ | ⚠ | ⚠ | ⚠ | 两门读取当前索引/工作树；本次按冻结 blob 评审，不能把当前 luna 分支的门禁结果冒充四个候选 commit 的结果。③/⑤ 应在各 ref 检视面重跑 |
| M4 五个被证伪词不复活 | ✅ | ✅ | ✅ | ✅ | luna/qwen 字面零命中；kimi/cursor 只在明确“已证伪/不采纳”章节出现 |
| M5 不复活部署形态双 Profile | ✅ | ✅ | ✅ | ✅ | 四份都只区分内核已有 Task Profile / Agent Profile |
| M6 人不作执行者 kind | ✅ | ✅ | ✅ | ✅ | 四份 `kind = "human"` 零命中；但 kimi/cursor 的“人的 Attempt”另按 B4/J4 判失败，不能被这个窄正则掩盖 |
| M7 覆盖声明含具体没查项 | ✅ | ✅ | ✅ | ✅ | 四份均有非空清单；qwen 还披露规划子代理可能看过禁读文件匹配内容 |

M1/M2/M4–M7 对四份无区分力；按任务书“全部满分则作废”规则，不用于排序。M3 明确保留未知，
没有把“未在对应 ref 上跑”写成通过。

### C2. 判断条总览

| 判据 | luna | kimi | cursor | qwen |
| --- | --- | --- | --- | --- |
| J1 新读者可读 | ✅ | ✅ | ✅ | ✅ |
| J2 落点表属实 | ✅ | ✅ | ✅ | ❌ |
| J3 六条处置有据 | ✅ | ◐ | ✅ | ◐ |
| J4 立得住/站不住分清 | ✅ | ◐ | ◐ | ❌ |
| J5 取证质量 | ✅ | ◐ | ✅ | ◐ |
| J6 不重写权威定义 | ✅ | ◐ | ◐ | ◐ |
| J7 开发验收不可外推 | ✅ | ✅ | ✅ | ✅ |
| J8 自增内容质量 | ✅ | ◐ | ✅ | ◐ |

J1、J7 四份全部通过，无区分力，不参与排序。其余依据如下。

### C3. luna

推荐作基座。

- **J2**：抽查 `refact-fable` §1.3、§3.3、§3.13、§6，以及 `runtime-architecture`
  §2.3、§2.8、§3.2、§4.1、§5.3；目标节均存在对应正文。§2.3 的五家具体快照被改为
  “字段 + 未核值未知”，内容确实存在，但最终稿应将这个取舍改写为明确“故意不要”。
- **J3/J5**：`39889605:agent-dev-guide.md` §4.3 与 §8.1 对 K1–K6 逐项给出代码或命令；
  `pilot_graph.py:59-66`、`langgraph_runtime.py:14-21`、`graph_runtime_service.py:14-46` 与
  `agent_graph.py:106-128` 支持“任意 resume 值 + 同 thread/checkpointer”。宿主 sudo、远端
  heads/tags 与本地 upstream 的环境差异也分开写，没有混成一次执行。
- **J4**：对象模型、三粒度、E0–E4、权力表、S/R+TraceEnvelope、T0 上界和绕过边界均保留；
  K1–K6 对应分支撤销，正文不保留旁路仓/key 架构。
- **J6**：没有复制七环节正文，也没有完整重定义内核对象；状态表是 `dev.change` 投影。
  §1.1 的摘要仍可进一步缩为指针。
- **J8**：“沿真实动作路径设强制点”、产品 Interaction 到 LangGraph 原语的最小绑定、G0–G5
  证据依赖顺序均有 §4.3/§4.4/§8.1 支持。

必须修的局部问题：T0 的“确认”限定为不可逆动作；把 `Attempt kind` 是否需规范修订标成 ⚠；
把不搬五家易腐快照写成明确理由。

### C4. cursor

内容覆盖与独立复核很强，排第二，但不能原样作基座。

- **J2**：64 行表最容易抽查，诊断、权力表、Agent Profile、等效、成本、证伪各有直接落点。
- **J3/J5**：六条均声称在宿主恒等 `uid_map` 环境复跑，代码、`sudo -n -l`、远端 heads/tags
  与本地分支事实分开，四份中与 luna 同属证据最完整的一档。
- **B4/J4 硬冲突**：`d8fdb32a:agent-dev-guide.md` §5.1 写“人的 Attempt 无 checkpoint 义务”，
  把人重新放回 Attempt；§5.2 又写 H5 的强制点是“人执行该动作”，而协议中人只确认，⑦ 由
  裁决/发布方执行。相关段落按 B4 不计分。这是从 `refact-fable.md:315` 原样带回来的旧错，
  不能因为源稿曾写过就继续保留。
- **J6**：§1.1 先说合法转换全集只在内核，紧接着逐字列出完整 Task 转换表；§3.3、§5.2、
  §9 又重述较多协议规则。它们多数正确，但与“只引用不重写”自相矛盾。
- **内部证据矛盾**：§4.3 的 E1/E2 表承认重算与进程观察是证据，下一段却断言“只有
  `tool.enforced` 的事件是证据”。正确说法应限定为“只有 tool.enforced 的**工具事件**可直接
  支持工具级断言”；否则 E1/E2 被自己否定。
- **J8**：强制点必须位于真实路径、登记集合与自动路由集合分离、恢复接库均值得吸收。

### C5. kimi

覆盖完整、治理与风险登记很强，排第三；核心问题与 cursor 相同，且六项独立复核较弱。

- **J2**：64 行落点与正文基本一致；对旧轮判据/处置/进度为何不搬的理由比 luna 更具体。
- **B4/J4 硬冲突**：`dc8efd59:agent-dev-guide.md` §5.3 同样写“人的 Attempt 无 checkpoint
  义务”。这直接违反任务书 B4；对应段落不计分。
- **角色混淆**：§5.1 把产品场景 `acceptor` 的实体写成 `validator`，而 §4.1 又明确定义
  validator 是确定性代码、acceptor 是人判角色；两者不能互为同一实体。
- **J3/J5**：K1/K2 独立复核充分；K3–K5 因沙箱限制主要引用 `forensics.md` 与本地旁证，
  且明确标出未独立复跑，诚实但弱于 luna/cursor。`cli.rs:60` 等现状锚也在覆盖声明中承认未复跑。
- **内部证据矛盾**：§6.2 同样在 E1/E2/E3 表后写“只有 `tool.enforced` 的事件是证据”，
  必须收窄“事件”的语义，否则与本节自己的证据等级冲突。
- **J6/J8**：工单、T0 包、超时、验收方算法等协议内容重复较多；独立性折算算法虽有启发，
  但单轮数据不足，候选自己也标为未验证，不能作为长期硬规则直接吸收。

### C6. qwen

表达最紧凑、内核边界意识好，但正文不足以支撑“完整融合”，排第四。

- **J2 计零**：抽查 `runtime-architecture` §2.3、§2.8、§4.1、§5.3 和 `refact-fable`
  §3.3：落点表分别声称落入 §2.1/§4.1/§5，但正文没有五家登记表、23 行 trace 读数、
  observability/enforcement/sandbox 三字段、T0 复合上界或 H1–H8 权力表。表格写“完整保留”
  不能代替正文，符合任务书 F3 的形状。
- **J3/J5**：K1/K2 的代码与测试锚很强，尤其指出抽象基类 `resume()` 仍是
  `NotImplementedError`，避免把 SDK 原语存在写成端到端能力已接线；但覆盖声明明确没有复查
  远端写能力变化，K4–K6 只做原则性收敛，因此是部分通过。
- **J4**：只保留了证据层次的摘要，没有保留任务书点名的粒度三字段、权力表与等效判据完整形状。
- **J6 流程顺序错误**：§5 写成“机械门 → acceptor → 来源作者异议”，而协议顺序是③裁决
  → ④来源异议 → ⑤验收；异议在验收后会使验收作废。即使随后说“完整顺序以协议为准”，
  前一句仍是错误的流程复述。
- 覆盖声明如实披露规划子代理可能通过宽搜索看到禁读文件匹配内容；这比隐瞒好，不按 F2 否决。
- **J8**：简洁的权威地图、端到端恢复未接线的提醒值得吸收，但不能弥补主体覆盖缺失。

### C7. 一票否决检查

四份都有 D2、路径正确，也都不是无锚点通用散文，因此本票不触发任务书 §8.3 的四项否决。
cursor/kimi 的 B4 冲突按“违反段落不计分”处理，不擅自扩张为任务书未写的一票否决。

### C8. 完整排序

1. **luna**：唯一同时保持完整主体、六项独立处置、正确的人/发布者边界，缺口可局部修复。
2. **cursor**：正文和宿主取证非常完整，但“人的 Attempt/人执行发布”与 B4 直接冲突，且重写
   内核/协议较多。
3. **kimi**：迁移理由与未决登记最完整；同样有 B4 冲突，角色/证据内部矛盾更多，独立复核弱一档。
4. **qwen**：边界简洁且 K1/K2 锚点好，但多个落点只有索引没有正文，J2/J4 失败，并写错异议/验收顺序。

推荐 `luna` 为基座。理由是可复核的缺陷修补量最小，不是票数、作者身份或篇幅。

## D. 值得吸收的点

不论最终选择哪份基座，下列主张值得逐条进入裁决：

| 出处 | 冻结位置 | 具体主张 | 建议吸收方式 |
| --- | --- | --- | --- |
| cursor | `d8fdb32a:agent-dev-guide.md` §0、§11.1 | 用六个结构问题给新读者解释“为什么要改”，而非只给目标形状 | 压缩并入 luna §0/§8；不带回“人的 Attempt” |
| cursor | `d8fdb32a:agent-dev-guide.md` §7 | `GraphRuntimeService` 抽象基类与 `LangGraphRuntimeService` 适配实现分开核；同 thread 恢复有三处代码锚 | 并入 luna §4.3，补“SDK 原语存在 ≠ 产品端到端 Interaction 已接线” |
| cursor | `d8fdb32a:agent-dev-guide.md` §12 | 六项证伪集中放在明确隔离的历史章节，专名只在被证伪语境出现 | 保留 luna §8 的集中形状，吸收 cursor 更清楚的“防再犯”导语 |
| cursor | `d8fdb32a:agent-dev-guide.md` §15 | 宿主恒等 `uid_map`、远端 heads/tags、模型配置未核分列 | 补强 luna §9 的环境声明；禁止把不同环境命令合成一次执行 |
| kimi | `dc8efd59:agent-dev-guide.md` §10.2–§10.4 | 映射骨架机械生成、删除条件与内核按 commit 引用 | 吸收“一个标题恰有一个落点”和状态词集合对称差；不要新造第二份状态真源 |
| kimi | `dc8efd59:agent-dev-guide.md` §11 | 17 项未决逐条登记，尤其 H5-final/H5-round、typed Artifact、retroactive/I1 | 与 luna §7.4 合并去重；未决保持 ⚠，不升级为既成规则 |
| kimi | `dc8efd59:agent-dev-guide.md` §5.6 | 独立性不能用单一 vendor 标签，至少拆 provider/harness/model_family | 吸收“字段化、证据优先”；不直接吸收未经跨题验证的 ×2 权重算法 |
| qwen | `7d31265a:agent-dev-guide.md` §3 | 代码测试证明同 thread resume，且抽象层 `resume()` 未完成适配 | 作为 luna §4.3 的现状限定，防止宣称端到端已实现 |
| qwen | `7d31265a:agent-dev-guide.md` §1 | 三份权威文档地图短而清楚 | 用于压缩 luna §0.1，避免重复权威正文 |
| qwen | `7d31265a:agent-dev-guide.md` §7 | 覆盖声明披露“可能被宽搜索触及”的不确定性 | 保留这种诚实形状；不得改写成隔离已证明 |
| luna | `39889605:agent-dev-guide.md` §4.2–§4.4 | principal 只批准，publisher 执行动作；强制点沿真实动作路径设置 | 作为最终权力边界基座，修 cursor/kimi 的 B4 冲突 |
| luna | `39889605:agent-dev-guide.md` §5.1–§5.5 | 三粒度、E0–E4、S/R+TraceEnvelope、Git 限度、L0–L3 串成一条证据链 | 原形保留；把“tool.reported 只作索引”与 E1/E2 的外部重算证据区分清楚 |
| luna | `39889605:agent-dev-guide.md` §8.1 | K1–K6 每条观察、结论和落点相邻 | 作为六项处置主表，补 cursor/qwen 的端到端未接线限定 |

## 本票的覆盖边界

**查了**：四份冻结 blob 全文；任务书 §8；两份源稿的 64 个标题与本票抽样涉及的小节；
investment-app 的中断/恢复实现与测试锚；`forensics.md`；当前 `agents.toml`。

**没查**：没有在四个候选 ref 各自检出完整树后运行 doc-gate/anchor-gate；没有登录托管方；
没有重新执行候选所称的远端或 sudo 命令；没有逐条重放 23 行历史 trace；没有读取三个外部参考仓。

**未验证 ⚠**：四份候选各自 M3 的最终结果；各 Agent Profile 当前模型/工具事件真实值；
独立性分组和权重算法；产品端到端 Interaction 恢复是否已接线。
