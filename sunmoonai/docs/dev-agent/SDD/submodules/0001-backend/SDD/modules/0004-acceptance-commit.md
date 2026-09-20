# 0004-acceptance-commit：验收与完成提交

**承担**：确定性验收、本地内容检查回执核对、终态与结果与预算结算的原子提交、交付。
合同 `F-ACCEPT-*`、`F-DELIVERY-*` 的后端侧。

**不承担**：不判"需求满没满足"那种语义结论——需要语义判断就另派 Attempt；
也不解密结果，它只存密文与元数据。

**边界要点**：**终态、结果、预算结算必须原子提交**；事件先持久化后通知，
客户端按 cursor 续传、重复事件幂等。

**要满足什么**见子任务 [`submodules/0004-acceptance-commit/`](../submodules/0004-acceptance-commit/PRD/requirement.md)。
