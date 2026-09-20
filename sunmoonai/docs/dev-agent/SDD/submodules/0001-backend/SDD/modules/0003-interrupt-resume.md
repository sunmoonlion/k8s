# 0003-interrupt-resume：中断、批准与恢复

**承担**：Interaction 的原子消费、断线暂停后的对账。合同 `F-INTERACT-*`、`F-APPROVE-*` 的后端侧。

**不承担**：不做工具级审批——那在本机闭环，后端只收摘要与结论；两条提交逻辑**不得共用**。

**边界要点**：Interaction 的令牌在**同一并发控制边界**内消费，只能消费一次；
断线后按 fencing 对账，拒绝旧执行端的迟到写入。

**要满足什么**见子任务 [`submodules/0003-interrupt-resume/`](../submodules/0003-interrupt-resume/PRD/requirement.md)。
