# 对 refact-fable.md 的分点异议稿

> 日期：2026-09-05 ｜ 异议者：qoder ｜ 对象：`refact-fable.md`（当日 11:30 修订版，§8 未冻结）
> 性质：按 round-protocol 异议格式组织的分点异议稿（条目 + 为什么错 + 应当是什么 + 可复跑证据）
> 总体判断：诊断 §1.4（⑥ 可判性）、§3.11 签名回执威胁模型、§3.8 脚本一般化方向成立；但 §3.1「一个内核」过度扩张、§3.2/3.3 把人降格为执行者会丢失人路径的结构性差异、实施路线 R1 把文档重构任务扩成基础设施改造，且 T0「零触点」与 H1「不可默认」自相矛盾。以下分阻断级、设计级、文字级三类。

---

## 阻断级

### B1：R1 把文档重构扩成基础设施改造，且依赖未验证的外部条件

**为什么错**：原任务 `refact-task.md` 是重写 `working/development-lifecycle-agent.md`（文档工程）。本方案 §6 的 R1 却要求「GitHub ruleset 配置、VM 侧凭据换身份、`round-status.py` 改查远端 tag」，这已超出文档重构范围，变成仓库权限架构与运维改造。更严重的是，A 档方案依赖 GitHub tag protection ruleset，而目标仓 `sunmoonlion/k8s` 若是 free 私有仓则 ruleset 的 tag pattern 推送者限制不可用（kimi D1 已指出）。R3/R4/R5 全部以 R1 为前置，R1 失败则整条路线停摆，但 §8 的自身验收标准里没有一条验证「ruleset 真的建得起来」。

**应当是什么**：把「签名回执」作为可选增强项，而不是 R1 前置。文档重构路线应先用现有可落盘的回执形态（如 `rulings.md` 追加 + 人工确认）跑通 R3/R4，签名 tag 作为独立 T2 工作单元另开。若坚持 R1 前置，则 §8 必须新增判据：在目标仓库实际创建 tag protection ruleset 成功，并把失败 fallback（gitee 第二锚、或分支保护 + 签名 commit）写进 §3.11.4。

**证据**：
- `refact-task.md` §6 原任务交付物是 `development-lifecycle-agent.md` 与评审文件，无基础设施要求；
- `refact-fable.md:489` R1 产物列「GitHub ruleset、VM 侧凭据换身份」；
- `refact-fable.md:518-521` §8 验收标准未含 ruleset 可用性验证。

### B2：T0「零触点」与 H1「不可设默认」自相矛盾

**为什么错**：§3.3 权力表 H1「冻结题目与验收标准（DRAFT → FROZEN）」可否设默认 = **否**；§3.6 写「T0/T1 通常一签两用」；§8 第 5 条验收标准写「T0 可为零次（human 触点）」。在 T0 全自动场景下，H2 即便按默认放行，工单仍卡在 DRAFT，因为 H1 无人能默认。于是「T0 可为零次」不成立。方案用 R1 来解决 R3「全自动跑不完最后一步」的问题，但 T0 在第一步（H1）就卡死。

**应当是什么**：三选一，需所有者裁定后写入 §3.3/§3.6/§8：
1. T0 豁免 H1（题目琐碎、验收可直接机械判定，出题/答题同体风险可承受）；
2. T0 的 H1 可随 H2 默认一并放行，`RouteDecision` 中注明；
3. 承认 T0 也需要一次人签，删去「T0 可为零次」。

在裁定前，§8 第 5 条不能冻结。

**证据**：
- `refact-fable.md:178` H1 行「可否设默认：否」；
- `refact-fable.md:213`「只有 H2 在策略明确允许的 T0 场景可以按默认放行」；
- `refact-fable.md:269-270`「T0/T1 通常一签两用」；
- `refact-fable.md:519` §8 第 5 条「T0 可为零次且落账」。

### B3：把人降格为「三种执行者之一」会丢失人路径的结构性差异

**为什么错**：本方案核心主张「人是一种执行者，不是一条路径」。但 `development-lifecycle-human.md` 明确列出人与 agent 的四处**真实差异**：人有批准权、可跨会话续接、可裁量「不值得走全流程」、承担最终责任（`development-lifecycle-human.md:23-31`）。这些不是「通道」或「权力表」能覆盖的：跨会话续接意味着人可以把意图存在记忆里但别人接不上；裁量权意味着人可以判断简化流程；责任归属意味着人必须是最终判定方。本方案把人放进 `agents.toml` 与 agent-cli 并列，只保留 `authority = "*"` 和 `channel = "inbox"`，把「跨会话续接」「裁量」这两个人独有的能力从结构里抹掉了。结果是：人路径不再自足，必须回到内核文档才能理解自己的特殊地位——而这正是本方案批评旧框架「权力与流程混写」的反面。

**应当是什么**：保留 `human` 作为独立执行者 kind，但在 `authority.md` 中单立一节说明人除权力表外还有三项不可委托的结构性能力：跨会话续接（不等于 agent 的 checkpoint，允许依赖记忆但需 handoff 兜底）、流程裁量（方向 asymmetric，朝省事须人确认，但人确认后可以省略环节）、最终责任（H7 的语义不仅是签 tag，而是对外承担后果）。合并后的 `lifecycle.md` 必须显式处理这四点，不能压缩成「channel 不同」。

**证据**：
- `development-lifecycle-human.md:6-9`「本文自足……写全了人执行一件开发工作所需的全部内核」；
- `development-lifecycle-human.md:23-31` 人与 agent 四处真实差异表；
- `development-lifecycle-human.md:61-68`「地位等同是协调职责等同，不表示系统授权相同」；
- `refact-fable.md:34-36`「人是一种执行者……差别只在通道和权力」。

---

## 设计级

### D1：「一个内核」过度扩张，request-lifecycle.md 不是开发流程内核

**为什么错**：§3.1 声称「request-lifecycle.md 已经定义了那个内核」，开发实例只是内核的 git 载体实例。但 `request-lifecycle.md` 是**产品运行时契约**，定义的是前端 Submission → 后端 Task → Attempt → Delivery 的状态机、持久化、幂等、预算等（`request-lifecycle.md:29-48` 本文负责什么）。它完全不涉及 git worktree、候选隔离、评审选优、round-protocol 六环节、签名 tag 等开发侧概念。把开发流程的每个产物都说成是产品状态机的「实例」，是一种投影，不是结构同一。若强制同一，产品契约每次演化都会反向冲击开发流程文档与脚本——这正是 §1.1 批评的「两个真源」换了一种形态复活。

**应当是什么**：把「一个内核」降级为「一个共享词汇表」：开发流程引用 `request-lifecycle.md` 的对象名（Task/Attempt/Interaction/Artifact/Event/Delivery），但开发流程自有 git 工作区、候选、评审、commit 等对象；§3.9 对照表改成「产品对象 → 开发侧对应物」，并注明内核版本冻结。产品契约修改按它自己的 T2 流程，开发流程按 round-protocol 的 T2 流程，两者不互相实例化。

**证据**：
- `request-lifecycle.md:29-48`「本文负责什么」——无 git、worktree、候选、评审；
- `request-lifecycle.md:96-105` 核心对象定义无 worktree/候选/评审；
- `refact-fable.md:114-133` §3.1 主张三个实例共用同一套对象名与状态名；
- `refact-fable.md:315-330` §3.9 对照表把 commit/worktree/候选等都塞进内核对象。

### D2：禁「supervisor」一词不禁义，同名物仍会换名再生

**为什么错**：§8 第 1 条验收标准说「新结构中 supervisor 一词只出现在词汇对照与历史说明里」。但 §1.2 指出「每加一层就加一个名字」的问题根源不是词，而是抽象层级选错。只禁一个词，coordination organizer / orchestrator / dispatcher / arbiter / integrator 都会成为复活通道。本方案自己就在用 `arbiter`/`acceptor`/`proposers` 这些词替代 supervisor 的某些职责，但未说明它们是否属于原 supervisor 概念的子集。

**应当是什么**：把 §8 第 1 条改为「维护一份禁止词表（含 supervisor 及其已知同义词），词表修改按 T2；规则句中不得用表中任何词指代『协调/裁决/整合』角色」。同时在本方案附录中给出旧 supervisor 三义 → 新词的完整映射，并明确新词是否仍可能兼任。

**证据**：
- `development-lifecycle-agent.md:71-82` §0.3 已用「调度监督器 / 执行监督 Agent」消歧；
- `refact-fable.md:328-330` 自己承认前三个 supervisor 名字被 roles 替代；
- `refact-fable.md:518` §8 第 1 条只禁一个词。

### D3：签名 tag 作为 ⑥ 的 done 条件，弱化了「确认」的语义

**为什么错**：§3.3 规则 3 和 §3.11 把人的确认改成「受保护远端上存在签名 tag」，§3.8 把 `round-status.py` 的 `done: None` 改成 `git verify-tag` / `ls-remote`。但 tag 存在只能说明「所有者执行了签名 push 动作」，不能证明「所有者理解了最终稿内容并认为它满足意图」。round-protocol 的 ⑥ 是「人读最终稿，确认或打回」；把 done 条件降成 tag 存在，等于把「确认」变成「收到回执」，与 P2「状态从产物反推」不矛盾，但丢失了 §3.4 收件箱本应承载的语义确认。

**应当是什么**：把 ⑥ 的 done 拆成两层：
1. 形式门：远端存在签名 tag，且指向 final commit（§3.11.3 已要求）；
2. 内容门：收件箱中 `confirm/<id>` 条目的 `diff_stat` 与 `target_commit` 已被列出（kimi D9 建议），且 `rulings.md` 中该次确认有「逐条验收标准结论」字段。
`round-status.py` 的 done 必须同时满足两门，不能只查 tag。

**证据**：
- `round-protocol.md:28-31` ⑥ 的定义是「人读最终稿，确认或打回」；
- `refact-fable.md:193-195`「回执必须是产物且不可伪造」——只解决伪造，不解决误签；
- `refact-fable.md:407` 剩余风险第 1 行承认「人被 agent 输出误导而签错」是 A 档下仍存在的风险。

### D4：权力表遗漏「澄清」类 interrupt

**为什么错**：§3.3 权力表只有 H1–H7，全部是 APPROVAL 类型转换（DRAFT→FROZEN、FROZEN→ACTIVE、省事方向裁定、追加预算、不可逆动作、推翻裁定、最终责任）。但 `request-lifecycle.md` 定义了 `WAITING(INPUT)`/`APPROVAL`/`DEPENDENCY`/`RESOURCE`/`EXTERNAL` 五种等待原因（`request-lifecycle.md:251-256`），其中 INPUT 是请求用户补充关键输入，不是权力行使。本方案把「哪些转换必须是人」当成 interrupt 唯一来源，会导致执行者在遇到歧义时无法发起澄清 Interaction——而只能按默认策略走或停下来等人主动看收件箱。

**应当是什么**：权力表只负责「必须由 human 执行者完成的转换」；另立一张「触发 Interaction 的条件表」，包含 INPUT（歧义改变结果/权限/成本/风险时）、APPROVAL（权力表 H*）、RESOURCE/EXTERNAL（依赖未满足）。或者至少把 H2 的「ask」路由结果与 INPUT 类 Interaction 区分：前者是不知道走哪档，后者是缺少信息无法继续。

**证据**：
- `request-lifecycle.md:251-256` WAITING 五种原因；
- `request-lifecycle.md:180`「只有歧义会实质改变结果、权限、成本或风险时才请求澄清」；
- `refact-fable.md:176-185` H1–H7 表无 INPUT 项。

### D5：工单 DRAFT/FROZEN/ACTIVE/DONE 与 round-protocol 六环节不对齐

**为什么错**：§3.6 把 round-protocol 的 `round.md` 一般化为工单，状态机是 DRAFT→FROZEN→ACTIVE→DONE。但 round-protocol 的六环节是 ①提案→②互评→③裁决→④验收→⑤确认→⑥清理，每个环节有自己的产物和门。把 round-protocol 改成 lifecycle 的 T2 Profile，却没有给出六环节如何映射到 DRAFT/FROZEN/ACTIVE/DONE。例如：①②③④ 都在 ACTIVE 里吗？⑤确认是 H5/H7 转换还是 ACTIVE→DONE 的一部分？⑥清理是 DONE 之后还是 DONE 的一部分？没有映射，round-protocol 作为本仓已经跑通的 T2 流程会被拍扁。

**应当是什么**：在 §3.6 或 §5.2 给出显式映射表：

| round-protocol 环节 | 工单状态 | 触发/转换 | 回执形态 |
|---|---|---|---|
| ① 提案 | ACTIVE | 工作区已准备好，执行者开始写候选 | commit |
| ② 互评 | ACTIVE | 候选冻结后评审方读候选 | commit |
| ③ 裁决 | ACTIVE→ACTIVE | 选定 commit，产生裁决稿 | commit |
| ④ 验收 | ACTIVE | 验收方运行门禁 | commit/结果 |
| ⑤ 确认 | ACTIVE→DONE? | H5/H7 人签 | 签名 tag |
| ⑥ 清理 | DONE 后 | 删除临时分支 | 清理记录 |

或者，承认 round-protocol 的六环节状态机不完全等同于工单状态机，两者并行。

**证据**：
- `round-protocol.md:16-31` 六环节定义；
- `refact-fable.md:246-270` §3.6 工单字段与状态机，无映射表；
- `refact-fable.md:466`「round-protocol 七环节保留为 T2 Profile」——只说要保留，没说怎么保留。

### D6：`independence` 属性缺少操作定义

**为什么错**：§3.2 提出 `independence = cross-vendor | same-runtime` 等取值，并说评审权重按此折算。但「cross-vendor 一致算独立信号；same-runtime 一致只算一票」没有操作定义：N 家 same-runtime 一致是否仍只算一票？与一家 cross-vendor 带 `file:line` 证据相比谁重？没有折算表，裁决方仍靠手感，本方案批评的「supervisor 选择」问题没有真正可执行化。

**应当是什么**：在 `authority.md` 或 `agents.toml` 说明中给出首版折算规则，例如：
- 独立信号数 = 不同 `independence` 值的组数；
- 每组内若带 `file:line` 取证，该组权重 ×2；
- 裁决时先按独立信号数比较，相同则比较取证组数。

允许首版粗糙，但必须有表。

**证据**：
- `refact-fable.md:163-166` §3.2 原文只有一句话描述折算；
- `refact-fable.md:509` §7 风险表第 6 条承认「`independence` 的取值目前靠人登记」。

### D7：签名 tag 的摩擦与 H 触点疲劳未纳入观测

**为什么错**：A 档方案下每次 H1/H5/H7 回执都需要人到 Windows 工作站、输入 GPG/SSH 口令、push tag（§3.11.3）。对于日常 T1/T2 开发任务，这个摩擦远高于现有「在对话里说同意」或 `rulings.md` 追加。§7 风险表第 2 条承认「人只剩 H1–H7 七个触点，可能觉得参与感不足」，但把它当成设计目标。没有观测指标，无法区分「人认真阅读后签名」与「人因为摩擦而批量盖章」。

**应当是什么**：在 §3.4 或 §7 增加观测指标：每次 H 回执记录「收件箱落盘 → tag 推送」耗时、回执相对预填值的改动项数；⑦ 清理时汇总趋势。若平均耗时或改动项数出现单调漂移，触发 H6 复核。

**证据**：
- `refact-fable.md:380-389` §3.11.3 A 档要求 Windows 工作站签名 push；
- `refact-fable.md:505-506` §7 风险 2「参与感不足是设计目标」；
- `refact-fable.md:520-521` §8 第 6 条要求 tag 判据，但不要求观测摩擦。

---

## 文字/可执行级

### T1：§8 第 1 条验收标准是 superficial 的机械判据

**为什么错**：「supervisor 一词只出现在词汇对照与历史说明里」容易通过 `grep` 验证，但验证通过不等于概念清晰。如 D2 所述，同义替换会绕过判据；而且即使 supervisor 一词消失，若 `arbiter`/`integrator`/`coordinator` 的职责边界未写清楚，同名物问题依旧。

**应当是什么**：把 §8 第 1 条扩展为两条：
1. 禁止词表（含 supervisor 及同义词）在规则句中零命中；
2. 旧 supervisor 三义的职责在 `lifecycle.md`/`authority.md` 中有明确新词映射，且每个新词的职责、禁止事项、与权力表 H* 的对应关系可机械核查。

**证据**：
- `refact-fable.md:518` §8 第 1 条原文；
- `development-lifecycle-agent.md:71-82` 旧 supervisor 三义表是更好的对照目标。

### T2：文档行数压缩论断缺少基线

**为什么错**：§0 一页摘要声称旧框架「约两千行重复」，§8 观察值说「两份 lifecycle 合计 2426 行」。但 agent 文 1604 行中约 500 行是产品执行架构（§4.5–§4.11、§8.1、§9.1–§9.2）应迁出；human 文 824 行是故意自足重复共同内核。真正重复的「共同流程」不是 2426 行。新结构 `lifecycle.md` ≈400 + `authority.md` ≈120 + `executor-architecture.md` ≈500 = 1020 行，加上 T0/T1 Profile 和 round-protocol 改版，总量不会显著低于 1000 行。把「行数减少」作为观察值可以，但不应暗示这是主要收益。

**应当是什么**：§0 和 §8 的行数对比改为「重复段落消除」而非「总行数压缩」；§8 观察值增加「重复主张计数」：用脚本对比两份 lifecycle 的逐段相似度，给出可消除的重复行数。

**证据**：
- `development-lifecycle-agent.md:376-620` §4.5–§4.11 约 245 行执行架构；
- `development-lifecycle-agent.md:1137-1269` §8.1、§9.1–§9.2 约 133 行；
- `development-lifecycle-human.md:236-824` 共同内核是故意自足；
- `refact-fable.md:529-531` §8 观察值只给行数，无重复度量。

### T3：§1.2「第四套 supervisor 正在生成」是对 agent 文的误读

**为什么错**：§1.2 说现文 §0.3 消歧了三套 supervisor，而 `rounds/refact/round.md` U2 的「轮次组织者」是第四套。但 agent 文 §0.3 明确说「下表只比较执行监督 Agent 与 Human supervisor；等位是开发协调职责等同」，并且「为保持既有开发内核逐字稳定，下文冻结小节里未加前缀的 supervisor 一律专指执行监督 Agent / Human supervisor 这一开发协调角色」。换言之，「轮次组织者」就是执行监督 Agent 在 round-protocol 场景下的称呼，不是第四套。本方案把已经消歧好的东西重新说成「第四套」，然后再说自己的方案消灭了它，是稻草人。

**应当是什么**：§1.2 改为「现文 §0.3 已正确消歧三套；round-protocol 的『轮次组织者』是执行监督 Agent 在 T2 流程中的具体称呼，不是新的同名物。本方案不再引入 supervisor 词，并将该角色的职责拆入工单 `arbiter`/executors 字段」。

**证据**：
- `development-lifecycle-agent.md:71-82` §0.3 三物表；
- `development-lifecycle-agent.md:107-109`「未加前缀的 supervisor 一律专指执行监督 Agent / Human supervisor」；
- `refact-fable.md:62-65` §1.2 原文。

---

## 处置建议汇总

| # | 级别 | 落点 | 建议 |
|---|---|---|---|
| B1 | 阻断 | §6 R1、§3.11.4、§8 | R1 降为非前置增强项，或新增 ruleset 可用性判据与 fallback |
| B2 | 阻断 | §3.3 H1、§3.6、§8 第 5 条 | 所有者裁定 T0 的 H1 处置，三选一 |
| B3 | 阻断 | §3.2、§3.3、authority.md | 恢复人的结构性差异：跨会话续接、裁量、最终责任 |
| D1 | 设计 | §3.1、§3.9 | 把「一个内核」降格为「共享词汇表 + 开发侧自有对象」 |
| D2 | 设计 | §8 第 1 条、附录 | 用禁止词表 + 旧义映射替代单禁 supervisor |
| D3 | 设计 | §3.4、§3.8、§3.11.3 | ⑥ done 需内容门 + 形式门 |
| D4 | 设计 | §3.3、§3.5 | 权力表外另立 Interaction 触发条件表，包含 INPUT |
| D5 | 设计 | §3.6、§5.2 | 给出 round-protocol 六环节 ↔ 工单状态映射 |
| D6 | 设计 | §3.2、§6 R5 | 给出 independence 折算表雏形 |
| D7 | 设计 | §3.4、§7、§8 | 增加 H 回执摩擦观测指标 |
| T1 | 文字 | §8 第 1 条 | 扩展为禁止词表 + 职责映射 |
| T2 | 文字 | §0、§8 | 行数对比改为重复度量 |
| T3 | 文字 | §1.2 | 承认 round-protocol 组织者不是第四套 |

B1–B3 在 §8 冻结前必须处置，否则实施路线会卡死或产生结构损失；D1–D7 可吸收进下一轮修订；T1–T3 为文字修正。
