# PRD 回执模板

交回时复制成 turn 里的 `turn.md`，写完冻结。字段见 [任务的生命周期](../lifecycle.md)「turn 的固定字段」。

```markdown
---
status: <completed / interrupted / failed>
worktree: <另开分支做的填分支名；就在当前分支上做的写 无>
commit: <另开分支做的填 response 所在的提交；否则写 无>
---
# turn <四位号> 的回执

答见 `response.md`。
```

字段集固定，用不上的写 `无`，不删行。就在当前分支上做的，`worktree` 与 `commit` 都写 `无`——git 自己记着；
另开分支做的两个都要填：`response.md` 只在那条分支上，从主线找不到它。
`interrupted` 或 `failed` 时，把为什么停的写进正文，接在上面那句后面。

**交回之后**：人读 `response.md`，整理成 `SDD/`（`architecture/` 与 `modules/`），写明以哪个 turn 为底、改了什么。
