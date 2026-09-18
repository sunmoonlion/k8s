# SDP 回执模板

交回时复制成 turn 里的 `turn.md`，写完冻结。字段见 [任务的生命周期](../lifecycle.md)「turn 的固定字段」。
这一段没有 `response.md`，产物在 worktree 的分支上。

```markdown
---
status: <completed / interrupted / failed>
worktree: <分支名>
commit: <worktree 分支上的提交>
verdict: 无
---
# turn <四位号> 的回执

产物在分支 `<分支名>` 的提交 `<提交>` 上。
```

`interrupted` 或 `failed` 时，把为什么停的写进正文。
**分支或标签必须在 worktree 清理之前留下**：工作区可以删，提交不能跟着消失。

**交回之后**：由不是实现者的一方做 UAT；通过并经人批准后才合并到 master，然后才清理 worktree。
