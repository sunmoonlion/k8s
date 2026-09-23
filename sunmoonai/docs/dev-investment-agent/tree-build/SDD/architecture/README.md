# `architecture/`

**模块之间怎么连**，以及各方共用的对象、契约与约束。每个模块**各自是什么**在同层的 [`modules/`](../modules/)。

> 依据：[需求](../../PRD/requirement.md)。本树 2026-09-23 重写；旧树 `../../../tree-build-v1/SDD/architecture/` 只作取证。

| 文件 | 内容 |
| --- | --- |
| [`components.md`](components.md) | **先读这一份**：六块加评测、各跑在哪、映射到哪个仓；退役了什么 |
| [`topology.md`](topology.md) | 边缘 + 内网的正式部署拓扑：什么在公网、什么在内网、两条不变量、多站点 |
| [`channels.md`](channels.md) | 八条通道：两端、协议、内容、安全要点 |
| [`objects.md`](objects.md) | 核心对象：Session、Task、Attempt、Interaction、Artifact、Event、Side Effect、Delivery、Environment、Profile |
| [`wheel.md`](wheel.md) | 方向盘：两层决策权在同一个 thread 上怎么交接 |
| [`task-contract.md`](task-contract.md) | Task 契约：提交信封、持久化主档、完成契约、结果信封、步骤交回物 |
| [`state-machine.md`](state-machine.md) | Task 与 Attempt 两层状态机 |
| [`approval.md`](approval.md) | 审批：工具级、Task 级、本地上限三条路 |
| [`workspace.md`](workspace.md) | 工作区：用户选工作区与项目、本地代理的根目录白名单、云端怎么读写 |
| [`security.md`](security.md) | 安全模型：威胁、本地上限、key 的走向、会合点令牌 |
| [`methods.md`](methods.md) | 方法与专家包：怎么下发、什么留服务端 |
| [`profile.md`](profile.md) | Task Profile 与专家包的契约 |
| [`invariants.md`](invariants.md) | 全程不变量 `I1`–`I14` 与持久化账 |
| [`ownership.md`](ownership.md) | 责任投影：每个 `F-*`、`I*`、`AT-*` 归谁 |
| [`engineering.md`](engineering.md) | 工程落点：仓、技术栈、版本配对、第一期切法 |

再上一层是 [`tree-build/`](../../README.md)：`PRD/` 写要什么，`rules/` 放代码规则。
