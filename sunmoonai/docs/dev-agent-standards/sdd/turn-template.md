# SDD 回执模板

交回时复制成 turn 里的 `turn.md`，写完冻结。字段见 [任务的生命周期](../lifecycle.md)「turn 的固定字段」。

```markdown
---
status: <completed / interrupted / failed>
---
# turn <四位号> 的回执

答见 `response.md`。
```

`interrupted` 或 `failed` 时，把为什么停的写进正文，接在上面那句后面。
