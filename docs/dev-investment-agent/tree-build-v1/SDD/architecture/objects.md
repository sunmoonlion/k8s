# 核心对象

> 三方共用同一套词；它们怎么流动见 [九站](../../../pipeline.md)。

| 对象 | 定义 | 必须保持的边界 |
| --- | --- | --- |
| **Task** | 用户提交并等待业务结果的持久请求 | 跨连接、进程、设备与多次 Attempt 存在 |
| **Attempt** | 为完成一个 Task 在某台设备上发起的一次执行 | 一个 Task 可以有零到多次 Attempt；每次绑定一台设备与一个独立工作区 |
| **Interaction** | 向用户或授权角色请求输入、批准，以及对方的响应 | 绑定 Task、一次性恢复、不可串请求 |
| **Artifact** | 输入、计划、中间结果、研究底稿、最终结果等稳定产物 | 有类型、版本、所有者和来源；正文加密存放 |
| **Event** | Task 与 Attempt 已发生事实的追加记录 | 只追加；状态与进度由它投影；不含结果正文 |
| **Side Effect** | 对文件、外部系统、消息等的写动作 | 幂等、可审计、必要时可补偿 |
| **Delivery** | 向桌面应用呈现状态、事件和持久化结果 | 可重放；失败不污染 Task 终态 |
| **Device** | 经配对绑定到用户的执行端（一台装有桌面应用与 runtime 的电脑） | 以设备密钥证明身份；可吊销 |
| **Task Profile** | 某类 Task 的输入、输出、验收、证据和策略契约 | 可版本化；不另造状态机 |
| **Agent Profile** | 执行某类 Task 的能力、工具、权限、自动放行范围与方法 | Attempt 固定所用版本；签名发布 |

**Task 不等于 Attempt**：一次派发失败、执行端离线、模型超时或验收不通过，只结束对应 Attempt。只有不存在获准的成功路径、重试策略耗尽，或完成契约已不可能满足时，Task 才进入 `FAILED`。

```text
Task T1
├── Attempt A1（设备 D1）→ FAILED(retryable)
├── Attempt A2（设备 D1）→ BUDGET_EXCEEDED
└── Attempt A3（设备 D1）→ COMPLETED → 验收通过 → Task SUCCEEDED
```

**Submission 不一定产生 Task**：未认证、无法解析或在分配 `task_id` 前即被协议层拒绝的提交，只产生安全的协议错误，不进入 Task 生命周期。后端一旦分配 `task_id` 并提交首个事件，后续业务或政策拒绝必须形成可审计的 `REJECTED` Task。

