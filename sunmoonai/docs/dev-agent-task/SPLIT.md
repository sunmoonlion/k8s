# 拆分表：通用规范（standards）与任务（task）

> 临时审阅文件，所有者审过再拆，拆完删除。原则（所有者 2026-09-15）：
> `dev-agent-standards/` 只放**通用规范**；具体任务只放 **通用规范的具体化** 与 **不通用的规范**。

## 标记

| 标记 | 含义 | 去向 |
| --- | --- | --- |
| **G** | 通用规范：换一个 agent、换一个项目仍然成立 | `dev-agent-standards/`（整节原文搬） |
| **C** | 通用规范的具体化：同一条规范在本任务里落到哪、怎么做 | 留在任务里，**链接到它依据的 G** |
| **S** | 不通用：只对本任务 / 本产品成立 | 留在任务里 |
| **G + C** | 一节里两者混写 | 原则写进 standards；原文作为具体化留在任务里，链到那条原则 |
| 草案 | luna 的协议草案 | 原样不动（所有者：草案勿清理） |

**链接方向：**只许 C → G（任务引用规范），不许 G → C。standards 里我此前加的「agent 项目的原文见……」反向链接要删掉。

## 先要你定的三件事

1. **平台一级放哪。**constraints（本平台 39 条代码规则）和 round 工具（`round-status.py`、`GO.md`、`round.md` 格式、`rounds/` 路径）
   既不是跨项目通用，也不专属某一个 agent，而是**本平台所有任务共用**。建议把 `dev-agent-task` 当作平台的根任务：
   以后每个具体 agent 是它的一个组成部分，这些平台一级的 C / S 就放在它的顶层 `composition/`。
   这样也就意味着：**constraints 应从 standards 退回任务顶层**，我刚把它放进 standards、并把 standards 说明改成「两类东西」，
   都违背了原则，要改回。其中真正通用的几条（智能体 A1–A5 的原则、「规则要有载体」）作为 G 提进 standards。
2. **执行纪律算什么。**你之前定过：工作区、单写者、并发、事故、冻结与取消等是「通用 agent 的规则」，留在产品里。
   按新原则再看，它们同时是**任何执行 agent 做开发都要守的规范**（换个项目也成立），只是写法带着本仓的路径和工具。
   建议按 G + C 拆：原则进 `deliverables/sdp/`（执行 agent 的交付规范），本仓的具体做法（`~/worktrees/<助手>`、分支命名等）留作 C。
   这会改动你之前的决定，请确认。
3. **protocol 也要拆。**round-protocol 的规则是通用的（G），但正文夹着本仓的路径、工单文件格式、脚本命令和历史轮次的例子（C）。
   建议：协议正文按节拆 G + C；`GO.md`、`README.md`（投喂、所有者确认）、`round-status.py` 是本仓的具体化，归平台一级（见第 1 条）。

## 逐节归类

### dev-agent-standards（现有）

| 文件 / 节 | 标记 | 处理 |
| --- | --- | --- |
| README：任务与交付物、多方竞争、总则、共同纪律、改判 | G | 保留；「这里放两类东西……本平台代码规则」一句改回「只放通用规范」；删去指向任务的反向链接 |
| constraints.md：标题、怎么用、数据、做数据迁移时、契约、身份、拓扑、专用 Worker、发布、改模板、清理镜像、环境事实 | S | 退回 `dev-agent-task/composition/constraints.md`（平台一级，见第 1 条） |
| constraints.md：智能体 A1–A5 | G + C | 原则（通用/专用两分、四本账必须持久化、执行层租用不自建、领域概念不进 Port）进 `deliverables/sdd/`「设计必须满足」；原文（含 PostgreSQL 等）留任务 |
| constraints.md：保证这些被遵守的三层 | G + C | 原则已在总则第 5 条；原文（本仓测试、hook、指针）留任务 |
| deliverables/sdd、sdp、uat，task/prd 各 README | G | 保留；删去举例与反向链接中指向本任务的部分 |
| protocol/round-protocol.md §1 档位、§2 裁量权、§3 执行者与触发、§4 七个环节、§8 判定及 8.1/8.2、§8c 组织者纪律、§9 隔离、§10–§13 各环节、§14 停止与回退、§15 角色不分、§17 通用纪律 | G + C | 规则进 standards；其中的本仓路径、历史轮次例子作 C 留平台一级 |
| protocol/round-protocol.md §0 收到「继续」、§5 round.md、§6 产物路径命名、§7 取件与检视面（worktree 路径）、§8b 脚本怎么调、§16 清理发布 | C | 平台一级 |
| protocol/GO.md、protocol/README.md、round-status.py | C | 平台一级 |
| protocol/round-operations.md（原 §3.19、§3.21） | G + C | 同协议正文 |
| protocol/round-protocol-draft*.md（四份） | 草案 | 原样 |

### dev-agent-task：顶层 composition

| 文件 / 节 | 标记 | 处理 |
| --- | --- | --- |
| request-lifecycle.md 全文 | C | 本任务的 PRD，即 PRD 规范的实例；链到 `task/prd/` |
| agent-dev-guide：0 先读结论、0.0、0.1 文档边界、1.1 唯一产品内核、7.4 风险和未决、13 词汇对照 | S | 留 |
| agent-dev-guide：1.5 执行者的共同纪律 | C | G 已在 standards 总则；此处留原文并链过去 |
| agent-dev-guide：1.6 七条设计原则 | G + C | 通用的设计原则（如「同一事实只有一个权威写入面」）进 `deliverables/sdd/`；原文留 |
| agent-dev-guide：7.7 需要改内核时的修订工作单元 | G + C | 「改契约要提交修订单元：改与不改、影响、迁移回滚、验收、旧语义处置」进 `deliverables/sdd/`；原文留 |
| development-plan、handoff 全部 | S | 留 |
| implementation-plan：测试层次 | S | 留（所有者已定本项目专有） |
| implementation-plan：任务条目格式 | C | G 已在 `deliverables/sdp/`；此处留原文并链过去 |
| implementation-plan：N4-OPS-01、阶段一至三 | S | 留 |

### dev-agent-task：后端组成设计（backend/composition）

| 文件 / 节 | 标记 | 处理 |
| --- | --- | --- |
| agent-dev-guide：1.2 四本账、2.1–2.5 运行时结构、2.11 派工契约、3.3 Attempt 与状态投影、3.11 候选状态机、3.17 内核对象对照 | S | 产品设计，留 |
| agent-dev-guide：3.4 T0/T1/T2 不是三套状态机 | G + C | 「档位不是另一套状态机」进 protocol 规范；与产品状态的映射留 |
| agent-dev-guide：3.18 状态脚本的硬要求 | G + C | 「状态从产物反推、不从声明读取」进 standards 总则；脚本细节留 |
| agent-dev-guide：1.3 硬约束自检 | C | 随 constraints（平台一级） |
| agent-dev-guide：4.1 人的位置、4.8 裁量权五条底线 | G | 进 `dev-agent-standards/approvals.md`（新建：人的批准点） |
| agent-dev-guide：4.2 权力表、4.5 权限公式、4.6 三道门 | G + C | 谁批什么、权限取交集、三道门为何正交 → `approvals.md`；本项目的 H 行绑定与强制点留 |
| agent-dev-guide：4.4 身份、批准与强制点 | G + C | 「批准绑定具体对象、未鉴别的记录只算 reported」→ `approvals.md`；产品强制点设计留 |
| agent-dev-guide：5.2 证据等级、5.4 Git 能与不能证明什么、5.9 七种载体、5.13 历史取证 | G + C | 采信与载体原则进 `deliverables/uat/`；E 级与本仓载体的具体说明留 |
| agent-dev-guide：5.1 粒度字段、5.3 手工态与服务态等效、5.8 上下文路由、7.1/7.2 演进、8.x 本轮核查裁定 | S | 留 |
| development-plan：起点、四本账、留白 | S | 留 |
| development-plan：智能体分两部分 | G + C | 「通用 / 专用两分」是框架原则 → standards；本项目的分法留 |
| handoff：不能倒退的输入 | S | 留 |
| pipeline.md | G + C | 通用部分已在总则；DEV/G 门、S0–S6 与本仓路径作 C 留 |

### dev-agent-task：各阶段组成部分

| 文件 / 节 | 标记 | 处理 |
| --- | --- | --- |
| 02：3.1 受理与冻结、6.x 运行时值得用吗 | S | 产品受理与定档设计，留（其中「原话不可覆盖、判据先冻结」已在 PRD/UAT 规范） |
| 02：14 开发 Task 持久记录模板 | G | 进 `task/`，作为任务记录模板 |
| 04：2.6–2.10 执行层、SDK、Port、Harness、双 runtime；4.13 执行器凭据；5.6 双腿矩阵；7.6 未验证清单 | S | 产品执行器设计，留 |
| 04：3.2 工作区供给、3.6 单写者发布、3.7 并发处置、3.8 事故规程、3.9 冻结迟到取消、3.10 物化与写前门禁、3.13 执行形态与停止、3.14 worktree 细则、3.20 Git 能否提交、3.22 停止超时回退、7.5 跨会话续接、11 反模式 | G + C | **待第 2 条定**：原则进 `deliverables/sdp/`；本仓路径与工具作 C 留 |
| 04：4.9 Attempt 内三条硬禁令 | G + C | 「执行者不得改路由、降门禁、扩权限预算」→ `deliverables/sdp/`；产品强制留 |
| 04：development-plan 执行层租用 | S | 产品决定，留（原则见 A4） |
| 05：4.3 中断/恢复原语 | S | 留 |
| 05：4.7 四档审批 | G + C | 档位原则 → `approvals.md`；本项目取值留 |
| 05：4.10 人这一侧的义务 | G | 进 `approvals.md`（写需求的两条已在 PRD） |
| 06：1.4 验收不可外推、1.7 先核前提 | G + C | 原则已在 UAT；本项目实例留 |
| 06：3.12 完成判据、5.5 四层验证、5.7 证据账分级、5.10 事实裁决表、12.1 七种假答案、12.2 并行评审盲区 | G + C | 原则进 `deliverables/uat/`；本仓实例留 |
| 06：5.12 检查受检查、9.2 没查什么（前半） | C | G 已在 UAT；留原文并链过去 |
| 06：12 常见失败方式与项目实例 | C | 本项目实例，链到 UAT |
| 06：3.5 交付清理恢复、3.15 发布协议、3.16 保留与回收；implementation-plan 交付规则 | G + C | 原则进 `deliverables/`（交付总则）；本仓路径（`docs/evidence/`、五仓同步脚本）留 |
| 前端 05：4.12 人的收件箱 | G + C | 「无默认的决定不得预填、批准绑定版本」→ `approvals.md`；界面设计留 |
| 各 README、composition/README | S | 留 |

## 这张表之后

- 拆的做法照旧：**原文一律保留**（整节 G 原文搬进 standards；G + C 的原文留在任务，standards 只写抽象后的原则），
  搬完用迁移前原文逐行复核，保证不丢。
- standards 里不许出现本平台专有的名字、路径、产品；每条 C 都链到它依据的 G。
