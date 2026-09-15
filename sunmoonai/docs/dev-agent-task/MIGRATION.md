# 迁移记录：dev-plan → dev-agent-task / dev-agent-standards

> 2026-09-14 已按本表完成迁移；dev-plan 各文件头链接到这里，故保留作记录。节 ID 同 dev-plan-architecture.md（tag `dev-plan-final`）
> 第八节的安置表（源文件 + 起行 + 原标题可在那里查到）。
>
> 2026-09-15：`dev-plan/` 已删除，全部内容原样存于 tag `dev-plan-final`（提交 `6afbb062`）；门禁脚本已移到 [`../tools/`](../tools/)，多方竞争判定脚本 `competition-status.py` 已删除。下表的「史」「留原处」是当时的去向。

## 规则（所有者 2026-09-14）

1. **默认去 `dev-agent-task/`**：dev-plan 的内容绝大多数是 agent 这个具体项目的。
2. **`dev-agent-standards/` 只收与项目无关的规范、原则、纪律，篇幅很少。**一节里两种都有时拆开：
   通用原则进 `dev-agent-standards/`，agent 的做法留在任务里。
3. 节点自己的开发文档就在它的 `composition/`；跨阶段的内容进上一层的 `composition/`。
4. `rounds/`、`records/`、`archive/` 与 dev-plan-refact 轮的产物成为历史，不迁。

## 落点代号

| 代号 | 路径（相对 `dev-agent-task/`） |
| --- | --- |
| T | `composition/`：agent 顶层（前后端之上） |
| B | `components/backend/composition/`：后端内部各部分的关系、跨阶段内容 |
| B02 … B07 | `components/backend/components/` 下对应阶段目录 |
| F01 / F05 / F07 | `components/frontend/components/` 下对应阶段目录 |
| P-xxx | `../dev-agent-standards/` 下对应阶段（`task/prd`；`deliverables/sdd`、`sdp`、`uat`。原 brd 并入 prd） |
| 史 | 留在 dev-plan 作历史，不迁 |
| 留原处 | 仍在 dev-plan 原位置、继续使用（门禁脚本及其说明） |

## 去向总表

| 源（切换前） | 节 | 去向 | 说明 |
| --- | --- | --- | --- |
| `working/request-lifecycle.md` 全文 | I01-001…042 | T | 整份即 agent 顶层的 composition；不拆 |
| constraints 全部规则（「doc-gate 为什么」一节除外） | I05-001…014 | P（constraints） | 先按类别拆到五处；2026-09-15 所有者定合回一张总表 `dev-agent-task/composition/constraints.md`（原文、原顺序），所有 agent 开发任务共用 |
| constraints `doc-gate.py` 为什么留下 | I05-015 | 留原处 | 随门禁脚本 |
| guide 先读结论、原来是什么样、文档边界、不可变契约、唯一内核 | I02-002/003/004/007/008 | T | 项目总体 |
| guide 七条设计原则 | I02-013 | T | 本项目的设计原则 |
| guide 词汇对照 | I02-107 | T | |
| guide 结构：组件与适配层、内容角色、Profile、`dev.change/1`、路由字段、四本账、派工契约 | I02-015/016/017/018/019/020/009/026 | B | 后端内部结构 |
| development-plan 智能体两分、四本账 | I06-003/004 | B | |
| guide Attempt 与状态投影、T0/T1/T2、候选状态机、内核对象↔开发载体、状态脚本 | I02-031/032/039/045/046 | B | 跨阶段 |
| 已决定的取舍：development-plan 起点与留白、handoff 不能倒退、guide 核查裁定四节 | I06-002/010、I08-008、I02-091…094 | B | 决定随任务走 |
| guide 执行层租用、两个 SDK、Port 与探针、Harness 门禁、双 runtime、F-EXEC 矩阵 | I02-021/022/023/024/025/071 | B04 | |
| development-plan 执行层租用 | I06-005 | B04 | |
| guide 直接沿用中断/恢复原语 | I02-054 | B05 | |
| guide 人的位置、权力表、权限公式 | I02-051/052/053/056 | B | 授权跨阶段 |
| guide 身份与强制点、三道门 | I02-055/057 | B | |
| guide 四档审批 | I02-058 | B05 | 批准即 Interaction |
| guide Attempt 内三条硬禁令、执行器凭据与跨腿委派 | I02-060/064 | B04 | |
| guide 粒度字段、上下文路由与能力词典、历史取证怎样用 | I02-066/073/078 | B | 观测跨阶段 |
| guide 证据等级与采信规则 | I02-067 | B + P-uat | 拆：通用的采信原则进 P-uat |
| guide Git 载体、七种载体、手工态与服务态等效 | I02-069/074/068 | B | |
| guide 运行时值得用吗：机械分类、反例与 T0 上界、绕过可观测 | I02-079…082 | B02 | 定档发生在受理 |
| guide 执行者的共同纪律（八条） | I02-012 | T + P（总则） | 原文在 T；总则写通用版 |
| guide 受理与冻结 | I02-029 | B02 | |
| guide 开发 Task 持久记录模板 | I02-108 | B02 | |
| implementation-plan 任务条目格式 | I07-002 | T + P-sdp | 原文在 T；SDP 写通用版 |
| guide 硬约束自检 | I02-010 | B | 自检表列的是 A1–A5，随智能体规则 |
| guide 反模式 | I02-103 | B04 | 执行中的做法 |
| guide 工作区供给、worktree 细则、Git 能否提交 | I02-030/042/048 | B04 | |
| guide 私有产生单写者发布、物化与写前门禁、并发处置、事故规程、冻结迟到取消、执行形态与停止、停止超时回退 | I02-034/038/035/036/037/041/050 | B04 | |
| guide 人的收件箱 | I02-063 | F05 | 人读的 Interaction 投影 |
| guide 人这一侧的义务 | I02-061 | P-prd + B05 | 拆：「请求写清边界、给可判定验收」进 P-prd（原写 P-brd，BRD 已并入 PRD） |
| guide principal 裁量权与改判 | I02-059 | B + P（总则） | 拆：改判三要素是通用纪律 |
| guide T2 七环节操作闭环、通知取件检视面 | I02-047/049 | P-sdd | 随 protocol 移入，文件 `protocol/competition-operations.md` |
| `protocol/` 全部（competition-protocol、README、GO、competition-status.py、草案） | I03-*、I04-* | P-sdd | 2026-09-15 由 B04 移入 dev-agent-standards（先放 SDD 下，同日提到根下 `dev-agent-standards/protocol/`）：任何交付物多方竞争时的规程 |
| implementation-plan 交付规则 | I07-004 | B06 | |
| guide 发布三个路径、交付清理恢复、保留与垃圾回收 | I02-043/033/044 | B06 | |
| guide 跨会话续接 | I02-088 | B04 | checkpoint 属执行 |
| guide 删除与迁移门 | I02-086 | 史 | 随历史冻结 |
| guide 修订内核的工作单元 | I02-090 | T | 改的是顶层合同 |
| guide 先核前提、开发验收不可外推、完成判据 | I02-014/011/040 | B06 + P-uat | 拆：「判据先冻结、验收不可外推」进 P-uat |
| implementation-plan 测试层次 | I07-003 | T | 本项目的测试层次 |
| guide 四层验证、证据账分级 | I02-070/072 | B06 | |
| guide 事实裁决表、七种假答案、常见失败、并行评审盲区 | I02-075/104/105/106 | B06 | |
| guide 检查本身也须接受检查 | I02-077 | B06 + P-uat | 原文在 B06；UAT 写通用版 |
| guide 没查什么（覆盖声明） | I02-097 | B06 + P-uat + 史 | 前半原文在 B06，UAT 写通用版；整节原文（含 `runtime-refact` 轮的覆盖清单）留作历史 |
| development-plan 产品建设顺序 | I06-001/006…009 | T | 顶层的开发计划 |
| guide 依赖顺序、手工态到服务态 | I02-083/084/085 | B | 后端运行时演进 |
| implementation-plan 计划与任务、N4-OPS-01、文档面待办 | I07-001/006…009、I08-009、N4-OPS-01 | T | 顶层计划 |
| handoff 当前阶段、已就位、游标、未决项、U1/U3/U4 输入、不能倒退两条 | I08-001…007/010/013 | T | 顶层交接 |
| guide 风险和未决 | I02-087 | T | |
| guide 执行器未验证清单 | I02-089 | B04 | |
| `pipeline.md` | — | B + P（总流程） | 整份移入 B（agent 项目的具体流程）；流程原则抽象后写进 `dev-agent-standards` 总则 |
| 历史取值、旧路线、吸收审计、旧版入口 | I02-027/062/076/095/096/098…102/001/005/006、I07-005、I08-011/012、I09-* | 史 | 吸收审计中的「没查什么」（I02-097）已单列进 P-uat |
| guide 无正文的章标题（「3. 一次开发 Task 怎样执行」「5. 可观测性、证据与等效」） | I02-028/065 | 不迁 | 只有标题，其下各节已分别归位 |
| `dev-plan-architecture.md`、`rounds/`、`records/`、`archive/` | — | 史 | |
| `anchor-gate.py`、`doc-gate.py`、`scripts/` | — | 留原处 | 管全仓文档，不属于 agent |

进 `dev-agent-standards/` 的一共 10 处：总则 4 处（共同纪律、改判三要素、pipeline 总流程、规则保证的三层），
P-prd 1、P-sdp 1、P-uat 4。

拆分的做法：任务侧原文保留，作为具体实例；`dev-agent-standards` 只写抽象出来的原则，措辞通用，并链接到实例。
进 `dev-agent-standards` 的 10 处都是抽象后的原则，原文一律保留在任务侧或历史里。

## 已定（所有者 2026-09-14）

1. constraints 按规则类别拆开，各归合适的层（见上表 I05 各行）。2026-09-15 改为合回一张总表，放 `dev-agent-task/composition/constraints.md`。
2. protocol 放 B04；2026-09-15 改为放进 `dev-agent-standards/protocol/`（SDD、SDP、UAT 多方竞争时都用）。
3. 删除与迁移门随历史冻结。
4. 测试层次放 T。
5. 门禁脚本留原处。

## 2026-09-15 按「standards 只放通用规范」拆分

所有者定原则：`dev-agent-standards/` 只放通用规范；具体任务只放通用规范的具体化与不通用的规范。据此：

- constraints 与本仓的多方竞争协议、工具（competition-protocol、competition-operations、GO、README、competition-status.py）归平台一级，
  放在 `dev-agent-task/composition/`（`composition/constraints.md`、`composition/protocol/`）。上表中写作 P 的这几项以此为准。
- `dev-agent-standards/` 写入抽象后的通用规范：总则、`approvals.md`（人的批准点）、`general-rules.md`（总则与任务记录模板）、
  SDD「设计必须满足」、SDP「执行规范」与「交付、发布与保留」、UAT 的验证与采信原则、`protocol/competition-rules.md`（通用多方竞争协议）。
- 任务里的原文全部保留，作为具体化；每个具体化的节在标题下链接到它依据的通用规范（原 56 处；「状态从产物反推」不再作为通用总则后，backend 指南 §3.18 改为本任务自己的规定，现 55 处）。
- 「状态」不再作为一般任务的规范（一般任务可能只是一段话）：总则「状态从产物反推」、生命周期「怎么看出做到哪了」一节移出 standards，原文在 backend 指南 §3.18；SDD 设计原则 P2 移出 standards（其后 P3–P6 改号为 P2–P5），原文仍在 `composition/agent-dev-guide.md` §1.6 的 P2。
- 任务侧协议文件改名：`round-protocol.md` → `competition-protocol.md`、`round-operations.md` → `competition-operations.md`、`round-status.py` → `competition-status.py`（参数 `--competition`，旧名 `--round` 仍可用），「轮次」改称「多方竞争」；历史目录 `rounds/`、工单 `round.md` 与钉在提交上的锚点保留旧名。
