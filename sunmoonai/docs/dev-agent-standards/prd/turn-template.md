# PRD 回执模板

交回时复制成 turn 里的 `turn.md`，写完冻结。字段见 [任务的生命周期](../lifecycle.md)「turn 的固定字段」。

```markdown
---
status: <completed / interrupted / failed>
completed_at: <交回时间>
commit: <response 所在的提交>
provider_record: <运行时自己的记录在哪；没有写 none>
reason: <只有 interrupted 填，且必填：interrupted / replaced / review-ended / budget-limited / cancelled>
error: <只有 failed 填：失败原因>
---
# turn <四位号> 的回执

答见 `response.md`。
```

不知道的值写 `unknown`，不得空着；`reason` 与 `error` 不适用时整行删掉。
