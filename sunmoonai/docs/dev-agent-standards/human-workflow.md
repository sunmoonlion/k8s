# human 版：人怎样走这套流程

[任务的生命周期](lifecycle.md) 的骨架两版通用；本文只写**人自己做**时的做法。agent 做时见 [agent 版](agent-workflow.md)。

## 谁在驱动

人驱动每一步：写用户消息、发出去、读 response、定稿、决定下一段问什么。没有 supervisor 程序，人兼这个角色。

| 步骤 | 人做什么 |
| --- | --- |
| 开一段 thread | 定这一段是哪个阶段（PRD、SDD、IMP、UAT，或一个具体问题的 ADR），建目录、写 `user-message.md` |
| 派工 | 把用户消息发给 AI 助手；要补的材料放 `others/` |
| 收 response | 把回答存成 `response.md`，提交，把提交号写进 `turn.md` |
| 审核 | 自己读。要改就开新 turn，理由写进新的 `user-message.md`；**不在已交回的 turn 里改任何东西** |
| 定稿 | 把满意的 response 整理进 `PRD/` 或 `SDD/`，写明以哪个 turn 为底、改了什么 |
| 建子任务 | 按 `SDD/modules/` 的拆分建目录，并写好各自第 `0001` 个 turn 的用户消息 |

## IMP 与 UAT 的三层 worktree

```text
助手的 worktree            AI 助手在这里实现，或在 test/ 里写验收
      ↓ 人对它开审核 worktree
审核 worktree              人在这里逐项核对、必要时修改
      ↓
合并到 master
```

- 人一个人做时是两层：助手的 worktree 与人的审核 worktree。若另有 supervisor 角色（比如由另一个 AI 助手先过一遍），就在中间加一层，顺序是助手 → supervisor 审核 → 人审核 → master。
- 每个 worktree 用独立分支，分支名与 `turn.md` 里的 `worktree` 字段一致。
- 审核发现问题：**不在审核 worktree 里替对方写**，开新 turn 让它重做；审核 worktree 只用来核对、跑测试、做最小修补。
- **人负责清理**：工作完成、合并进 master 之后再清 worktree；清理前确认分支或标签还在。

## 人要盯住的几件事

- **用户消息里没写的，模型不会知道**：要它交回什么、能改哪些文件、哪些动作要先问，都写进用户消息。
- **判据先于产出冻结，但讨论与设计段不写进用户消息**：那三段按各阶段规则判；IMP 段必须写完成条件。出题与答题分开，事后改题等于白问。
- **一段只问一件事**：PRD 段问「要什么」，SDD 段问「怎么做」，冒出来要定的具体问题开 ADR，别混在一个 turn 里。
- **定稿是人的动作**，不是 AI 的：AI 交的是 response，进 `PRD/`、`SDD/` 的那一版由人负责。
- 其余义务见 [人的批准点](detailed-rules/approvals.md)。
