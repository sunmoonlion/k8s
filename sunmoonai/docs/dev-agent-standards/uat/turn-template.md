# UAT 回执模板

交回时复制成 turn 里的 `turn.md`，写完冻结。字段见 [任务的生命周期](../lifecycle.md)「turn 的固定字段」。
这一段没有 `response.md`，测试在 worktree 的 `test/` 里。

```markdown
---
status: <completed / interrupted / failed>
completed_at: <交回时间>
commit: <worktree 分支上的提交>
worktree: <分支名>
verdict: <pass / fail / undecidable>
provider_record: <运行时自己的记录在哪；没有写 none>
reason: <只有 interrupted 填，且必填：interrupted / replaced / review-ended / budget-limited / cancelled>
error: <只有 failed 填：失败原因>
---
# turn <四位号> 的回执

验收 <thread 号/turn 号>，结论 `<pass / fail / undecidable>`。测试在分支 `<分支名>` 的提交 `<提交>` 上。
```

不知道的值写 `unknown`，不得空着；`reason` 与 `error` 不适用时整行删掉。
`verdict` 是这一段的结论，**`status: completed` 只表示这次验收做完了，不表示被验收的东西通过了**。
