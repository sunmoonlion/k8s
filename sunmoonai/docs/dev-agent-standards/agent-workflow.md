# agent 版：supervisor 怎样走这套流程

[任务的生命周期](lifecycle.md) 的骨架两版通用；本文只写**由 supervisor 驱动**时的做法。人自己做时见 [human 版](human-workflow.md)。

## 谁在驱动

supervisor 是程序：按 workflow 决定下一段问什么、派给谁、怎么验收，人只在批准点介入。

| 步骤 | supervisor 做什么 | 人做什么 |
| --- | --- | --- |
| 开一段 thread | 按 workflow 选阶段与 Profile，生成 `user-message.md` | 需要澄清时回答 |
| 派工 | 把任务书派给执行者，记录派工与租约 | — |
| 收 response | 自动存 `response.md`、提交、写 `turn.md` | — |
| 验收 | 先做确定性验收（规则、schema、测试）；需要语义判断的另派一个验收 turn | 在批准点批准或打回 |
| 定稿 | 把通过验收的 response 整理进 `PRD/` 或 `SDD/`，提请人批准 | 批准即定稿 |
| 打回 | 生成新 turn 的任务书，写清理由与改判三要素 | 第三次打回时裁决 |

## worktree

- 执行者在 Attempt 的 worktree 里实现；验收在 worktree 的 `test/` 里。
- supervisor 审核以 **diff 为主**，不必为每次审核都另开 worktree；要跑测试或做最小修补时才开，开了就登记。
- 合并到 master 必须经人的批准点（不可逆动作）。
- **supervisor 负责清理**：工作完成、合并之后清 worktree；清理前确认分支或标签已保留，并把清理这件事记下来。

## 与 human 版的差别

| 方面 | human 版 | agent 版 |
| --- | --- | --- |
| 谁发起 turn | 人 | supervisor 按 workflow |
| 谁写 `turn.md` | 人手写 | 运行时与后端自动写 |
| 审核 | 人读 response | 确定性验收 + 语义验收 turn，人只在批准点 |
| worktree 层数 | 助手、（supervisor）、人，逐层向上 | 助手一层；审核按需开 |
| 清理 | 人 | supervisor |
| 打回 | 人写理由 | supervisor 生成任务书，改判入账 |

## supervisor 必须守的

- **不改已冻结的东西**：已发出的任务书、已交回的 turn 一律不动，要改就开新 turn。
- **每一步都要留痕**：派工、交回、验收结论、打回理由、改判、清理，都进记录。
- **该停就停**：同一项交付物第三次被打回、遇到不可判、越出已授权的能力，停下来交给人。
- **人的批准点不能自动通过**：见 [人的批准点](detailed-rules/approvals.md)。
