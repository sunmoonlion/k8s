# BRD 回执模板

交回时复制成 turn 里的 `turn.md`，写完冻结。字段见 [任务的生命周期](../lifecycle.md)「turn 的固定字段」。

```markdown
---
status: <completed / interrupted / failed>
worktree: <只有另开分支做时填：分支名>
commit: <只有另开分支做时填：response 所在的提交>
---
# turn <四位号> 的回执

答见 `response.md`。
```

就在当前分支上做的，`worktree` 与 `commit` 两行整行删掉——git 自己记着。
另开分支做的必须填：`response.md` 只在那条分支上，从主线找不到它。
`interrupted` 或 `failed` 时，把为什么停的写进正文，接在上面那句后面。
