# 合并前评审记录

> 最后更新：2026-08-29

本目录保存**其他 AI 助手作为独立评审方**给出的意见，以及吸收方的处置记录。
它是 [`../../dev-plan/agent-discipline.md`](../../dev-plan/agent-discipline.md)
§5「评审—吸收循环」的产物——该节明确要求**吸收方必须留处置记录**，
本目录就是那条纪律的执行实例。

| 文件 | 评审方 | 内容 |
| --- | --- | --- |
| [`qoder.md`](qoder.md) | qoder | 合并前评审与补充 |
| [`qoder-final-statement.md`](qoder-final-statement.md) | qoder | 最终声明：合并将删除什么、什么必须在消失前留下 |
| [`cursor.md`](cursor.md) | cursor | 对照自身旧 baseline，对 opus `project-guide/` 的评审与可吸收条文 |
| [`cursor-final-statement.md`](cursor-final-statement.md) | cursor | 最终声明：宣称「处置完毕」会盖住什么、收口前必须留下什么 |
| [`kimi.md`](kimi.md) | kimi | 拿 App 源码逐条对账（取证于 `~/master` 08-22 快照） |
| [`luna.md`](luna.md) | luna | 结构与一致性评审 |
| [`disposition.md`](disposition.md) | **opus** | **吸收处置记录**：每条意见的采纳 / 部分接受 / 拒绝 / 证伪，各带理由 |

## 什么时候删除本目录

**三个条件全部满足后删除，不是"觉得差不多了"：**

1. 其余 AI 助手（cursor / kimi / luna / qoder 已给出；qwen3.8 未）**都已给出意见**
2. 每条意见都已**吸收或明确拒绝**，且按 §5.3 留下处置记录
3. 上述结果已 **merge 到 master**

在此之前它是活的工作材料，不是归档。

## 为什么要写清删除条件

`decisions/` 与 `history.md` 的教训：**没有删除条件的记录会变成孤儿**——
既不被执行，也没人敢删，最后堆在目录里让人以为它还权威。
本目录一开始就带着退出条件。
