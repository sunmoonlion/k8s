# 照抄用的两个头

建 turn 时复制下面两段。字段是什么意思、什么时候写 `无`，见 [任务的生命周期](lifecycle.md)「turn 的固定字段」；
这一段的问最少要说清什么，见各阶段规则的「这一段的用户消息」。**正文没有模板**——问是开放的，固定栏目会给答案定骨架。

## `user-message.md`

```markdown
---
executor: <派给谁；还没派出去写 unassigned>
verifies: <只有 UAT 段填「thread 号/turn 号」，如 0004/0001；其余写 无>
---
# turn <四位号>：<短名>

<这一问要什么。一问只谈一件事>

**交回：<写成这个 turn 的 `response.md` / 产物在 worktree 的分支上>。**
```

## `turn.md`

```markdown
---
status: <completed / interrupted / failed>
worktree: <分支名；就在当前分支上做的写 无>
commit: <交回物所在的提交；同上>
---
# turn <四位号> 的回执

<一句话指向交回物>
```

正文那一句按阶段写：

| 阶段 | 写什么 |
| --- | --- |
| BRD、PRD、SDD | 答见 `response.md`。 |
| SDP | 产物在分支 `<分支名>` 的提交 `<提交>` 上。 |
| UAT | 验收 `<thread 号/turn 号>`，结论 `<通过 / 不通过 / 不可判>`；测试在分支 `<分支名>` 的提交 `<提交>` 上。 |

`interrupted` 或 `failed` 时，把为什么停的写进正文，接在上面那句后面。
