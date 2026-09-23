# 核心对象

> 各方共用同一套词；它们怎么流动见 [九站](../../../pipeline.md)。

| 对象 | 定义 | 必须保持的边界 |
| --- | --- | --- |
| **Session** | 一个用户在一个工作区里的一段连续工作：绑定一个 Codex thread、一个项目目录、一个执行环境；有方向盘属性 | 一个用户同时只有一个活跃 Session 握着某个 thread；Session 不是 Task |
| **Task** | 用户交出方向盘后，等待可验收结果的持久委托 | 跨连接、进程与多次 Attempt 存在；一个 Session 同时最多一个非终态 Task |
| **Attempt** | 为推进一个 Task，顾问在该 Session 的 thread 上发起的一段执行（一到多个 turn） | 一个 Task 零到多次 Attempt；第一期串行 |
| **Interaction** | 向用户请求输入或批准，以及对方的响应 | 绑定 Task、一次性消费、不可串请求 |
| **Artifact** | 输入、计划、中间结果、研究底稿、最终结果等稳定产物 | 有类型、版本、所有者和来源；正文明文存放，同时可落工作区 |
| **Event** | Session、Task 与 Attempt 已发生事实的追加记录 | 只追加；状态与进度由它投影 |
| **Side Effect** | 对文件、外部系统、消息等的写动作 | 幂等、可审计；工作区内的写由 Codex 协议记录，工作区外的须审批 |
| **Delivery** | 向网页呈现状态、事件和结果 | 可重放；失败不污染 Task 终态 |
| **Environment** | 用户机器上的执行环境：本地代理 + exec-server + 根目录白名单 + 本地上限 | 由代理声明，工作台登记；在线状态是事实不是承诺 |
| **Sandbox** | 该用户在内网里的 app-server 进程与 `CODEX_HOME` | 每用户一个；持有用户 key 的进程环境 |
| **Task Profile** | 某类委托的输入、输出、验收、证据和策略契约 | 版本化；不另造状态机 |
| **专家包** | 一个领域的 workflow、步骤契约、方法文本、工具绑定、验收规则、评测集 | 版本化、签名、配评测；等于旧树的 Agent Profile + 方法库 |

**Task 不等于 Attempt**：一次 turn 失败、执行环境离线、模型超时或验收不通过，只结束对应 Attempt。只有不存在获准的成功路径、重试策略耗尽，或完成契约已不可能满足时，Task 才进入 `FAILED`。

```text
Session S1（thread th_1，项目 ~/research/2025H1，环境 E1）
└── 方向盘：用户 ─交出─▶ 顾问 ─交回─▶ 用户
    └── Task T1
        ├── Attempt A1 → FAILED(retryable)
        ├── Attempt A2 → BUDGET_EXCEEDED → Task WAITING(RESOURCE) → 用户加预算
        └── Attempt A3 → COMPLETED → 验收通过 → Task SUCCEEDED
```

**Submission 不一定产生 Task**：未认证、无法解析或在分配 `task_id` 前即被协议层拒绝的提交，只产生安全的协议错误。一旦分配 `task_id` 并提交首个事件，后续拒绝必须形成可审计的 `REJECTED` Task。
