# 0003-orchestrator：编排

**承担**：编排——`F-DISPATCH-03`、`F-DISPATCH-05`，以及方法库的取用。

- 按 workflow 拆步骤、**推进游标**、按步决定下一步派什么；
- **步骤契约**：每步的输入、交回物形状、验收条件与返工上限；
- `escalate` 的裁决：Attempt 报「已升级」后，由这里判是否改走 workflow，改判入账；
- **方法库**：直发与编排两种形态、按敏感度分档、注入面控制（核心方法只下发「这一步做什么」）；
- **按步骤决定哪些方法工具对当前 Attempt 可见**，并在调用回来时做二次校验（见下）。

**必须做到**（定义原在 `PRD/functions.md`，ID 不变）：

- **F-DISPATCH-03**：调度策略明确用户公平性、优先级、设备容量与并发上限、deadline；
- **F-DISPATCH-05**：派发内容带签名（F-GUARD-01），只按步下发当前步骤所需的指令。

**不承担**：

- 不送派发——那是 `0004-bridge`。这里只决定「下一步是什么」；
- 不改状态、不写账，经 `0001-ledger`；游标推进**不新增状态词**（P0）。

**方法工具怎么走**：口径与计算做成 MCP 工具**留在服务端**，而 **Codex 不直接连后端**。
所以走代理：本步工具清单随派发下发 → runtime 注册成本地 MCP 的代理工具 → Codex 调用 →
runtime 经通道 ① 转回后端 → 这里**二次校验**（是不是这个 Attempt、是不是这一步的清单、租约还有效吗）
→ 执行并返回。**清单随换步失效**，runtime 只代理、不缓存、不实现——否则方法就落地到用户电脑了。

二次校验不可省：runtime 在用户电脑上，清单可能被改。这与 `approval.md` 三道门里
「工具网关收到伪造名称再 deny 一次」是同一条道理。

**为什么不用协议原生的动态工具**：`codex app-server` 有客户端注册、服务端回调的机制
（`DynamicToolSpec` → `item/tool/call`），看上去比 MCP 代理直接。但它**只能在 `thread/start`
下发，没有 turn 级覆盖，也没有注册与注销方法**，且标着 `#[experimental]`——**满足不了
「清单随换步失效」**。走 MCP 代理，换步时用 `config/mcpServer/reload` 重载清单。
详见 [`codex.md`](../../../0003-runtime/PRD/codex.md)。

**边界要点**：workflow 的**步骤类型是开放集合**——确定性规则、派 Attempt、人介入三者之一；
新增类型只加一个适配器，**不改状态机**。

**编排的边界**

**workflow 的步骤类型是开放集合**：一步是确定性规则、派 Attempt、人介入三者之一。
新增类型（例如受理判定改用模型，D11）只加一个适配器，**不新增状态词、不改状态机**。

**编排留在后端**：supervisor 按步派发，每步只下发这一步需要的指令，完整流程不下发；核心计算与规则放在 MCP 工具内部执行，只返回结果。

**子 Task 与依赖编排**

派生子 Task 必须满足：

- 父 Task 的完成标准仍是用户业务目标，不能以「已经拆出子 Task」冒充完成；
- 父级预算覆盖全部子 Task，子级预算是预留，不是凭空新增；
- 子 Task 的授权只能收窄；扩大权限必须重新批准；
- 子 Task 各自有 Task Profile、Attempt、结果与验收；
- 父 Task 汇总结果时保留来源与子 Task 血缘。

多个 Task 的依赖图由一个有边界的 `COORDINATION` Task 管理：

```text
managed_task_ids[]
edges[] = from → to + 依据 + 可判定的满足条件
parallel_groups[]
ownership[]
graph_version
```

协调 Task 是边的唯一权威；被协调 Task 只保存 `coordination_task_id`。同时只能有一个现行协调视图。协调 Task 验收：节点存在、每条边有依据与解除条件、阻塞图无环、工作有责任归属、同一事实无第二写入面。协调 Task 在图建立并验收后即 `SUCCEEDED`，不等待被协调 Task 完成；依赖实质变化时建立 `supersedes` 旧图的新协调 Task。对子结果的等待发生在依赖这些节点的业务 Task：它进入 `WAITING(DEPENDENCY)`，条件满足后按 [重连对账](../../../0003-runtime/PRD/discipline.md) 恢复。
