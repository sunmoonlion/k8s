# UAT 任务书模板

复制成 turn 里的 `user-message.md`。字段的含义见 [任务的生命周期](../lifecycle.md)「turn 的固定字段」，
这一问要写清什么见 [任务书规则](../task-brief-rules.md) 与 [UAT 规则](uat-rules.md)。

```markdown
---
deliverable: UAT
agent: acceptance
executor: <具体执行者；不能是实现这份 SDP 的那一个>
verifies: <验收哪个 turn，写「thread 号/turn 号」，如 0004/0001>
base: <发出时依据的提交>
sent_at: <发出时间>
---
# turn <四位号>：<短名>

## 验收对象
- turn：<thread 号/turn 号>
- 分支与提交：<被验收的分支名与提交>

## 按什么判
<逐条列出被验收 turn 的任务书里写明的验收标准；这些标准在派工时已冻结，不在这里改>

## 工作区
- worktree：<在被验收的 worktree 之上再开一个>
- 测试写在：`test/`
- 不得修改被验收的产物

## 证据要求
- 每条判定写明查了什么、没查什么、不能排除什么；
- 命令要能复跑，附原始输出的位置；
- 自述只是待验证的主张，结论从冻结的产物独立重算。

## 怎么判
- 每条只有三种结论：`pass`、`fail`、`undecidable`；
- 任务书没有可判定依据的地方判 `undecidable` 交给人，**不自己发明标准**；
- 不为通过而静默改标准；判定为「标准本身过期」时写明理由交回。

**交回：UAT。测试在 worktree 的 `test/` 里，这个 turn 里不放 `response.md`；交回时在 `turn.md` 记分支、提交与结论。**
```
