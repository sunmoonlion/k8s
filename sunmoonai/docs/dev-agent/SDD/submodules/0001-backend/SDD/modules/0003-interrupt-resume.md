# 0003-interrupt-resume：中断、批准与恢复（已取消）

**本版起取消。**责任分两处：

- Interaction 的创建与原子消费、两层审批的后端侧 → [`0009-interaction`](0009-interaction.md)
- 断线暂停后的对账、租约与 fencing → [`0008-gateway`](0008-gateway.md)

**为什么分**：「等人」和「等设备」是两回事，原来混在一块。前者的对手是人与批准对象，
后者的对手是连接与租约；它们的失败方式、重试策略、超时含义都不同。

**目录不删**：[`../submodules/0003-interrupt-resume/`](../submodules/0003-interrupt-resume/) 下的
turn 已交回并冻结，留着；该子任务不再开新的 turn。
