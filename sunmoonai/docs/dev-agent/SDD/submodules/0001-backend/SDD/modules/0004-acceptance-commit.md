# 0004-acceptance-commit：验收与完成提交（已取消）

**本版起取消。**责任分两处：

- 确定性验收、语义验收派 Attempt、交付取件 → [`0010-acceptance`](0010-acceptance.md)
- 终态、结果、预算结算的**原子提交** → [`0005-kernel`](0005-kernel.md)

**为什么分**：原子提交要同时写状态、结果与预算账，那是内核的事。留在验收块里，就等于
验收块自己写状态机——原子性靠它一家保证，而预算在派发时已经被另一块扣过了。

**目录不删**：[`../submodules/0004-acceptance-commit/`](../submodules/0004-acceptance-commit/) 下的
turn 已交回并冻结，留着；该子任务不再开新的 turn。
