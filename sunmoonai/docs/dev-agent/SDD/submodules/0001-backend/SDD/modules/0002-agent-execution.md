# 0002-agent-execution：排队、派发与执行对接

**承担**：outbox 投递、租约与 fencing、事件与副作用回传、用量归集。合同 `F-DISPATCH-*`、`F-EXEC-*` 的后端侧。

**不承担**：不做受理判定（那是 `0001-intake`），不做验收（那是 `0004-acceptance-commit`）；
执行本身在用户电脑上，这里只负责把它派出去并接住回传。

**边界要点**：租约与 fencing **随派发下发**；事件、副作用与用量**按 Attempt 归集**；
设备离线则等待，不丢派发。

**要满足什么**见子任务 [`submodules/0002-agent-execution/`](../submodules/0002-agent-execution/PRD/requirement.md)。
