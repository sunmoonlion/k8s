# 0006-acceptance：验收

**承担**：合同 `control-plane.md` 里 **validator 与 acceptor 两个角色**。

- **validator**：按固定 Task Profile 版本做确定性验收；核对本地内容检查的签名回执；
- **acceptor**：需要语义判断的验收，作为**独立的验收 Attempt** 派出去（不同 Agent Profile、
  不同运行时 thread），**不自己判**；
- 终态提交的发起：终态、结果、预算结算**原子提交**——由 [`0001-state`](0001-state.md) 一次转换完成。

**不承担**：

- **不送给用户**——事件流、取件与通知归 [`0007-delivery`](0007-delivery.md)；
- 不自己判语义——那要派 Attempt；
- 不自己写终态，经 `0001-state`。

**不朝外**：和 `0003-orchestrator` 一样是内部判断，判完把结论交出去。

**边界要点**：**依据是派工时冻结的完成条件**，派工后不改、不加；没有可判定依据的地方判
`undecidable` 交给人，**不自己发明标准来判通过**。作者自检不能代替独立验收——这是 acceptor
必须另派 Attempt、且用不同 Agent Profile 的理由。
