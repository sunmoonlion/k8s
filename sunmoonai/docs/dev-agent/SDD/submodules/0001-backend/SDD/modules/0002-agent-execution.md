# 0002-agent-execution：排队、派发与执行对接（已取消）

**本版起取消。**责任拆成三处：

- 「下一步派什么」→ [`0007-orchestrator`](0007-orchestrator.md)
- 「怎么送出去、设备在不在」→ [`0008-gateway`](0008-gateway.md)
- outbox 与任务队列本身 → [`0005-kernel`](0005-kernel.md)

**为什么拆**：原来这一块把「决定」和「投递」捆在一起。新增一种 workflow 步骤类型本该只动
编排，捆着就得连派发一起改——`control-plane.md` 那句「步骤类型是开放集合」在这种结构下守不住。

**目录不删**：[`../submodules/0002-agent-execution/`](../submodules/0002-agent-execution/) 下的
turn 已交回并冻结，留着；该子任务不再开新的 turn。
