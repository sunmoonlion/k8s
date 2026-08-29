# 协作治理

> 最后更新：2026-08-29
>
> **动手前必读。**本文件规定"改代码和改文档时必须遵守什么"，
> 与 [`overall-architecture.md`](overall-architecture.md)（项目是什么）分工不同。
>
> 只剩三件事：权威排序、接手演练、什么不属于本文档集。
> 其余原属本文件的内容已按性质移出：
> 写文档的约定 → [`../working/doc-conventions.md`](../working/doc-conventions.md)；
> 提请求 → [`../working/request-lifecycle.md`](../working/request-lifecycle.md)；
> 推送与多助手 → [`../working/collaboration.md`](../working/collaboration.md) 与
> [`../dev-plan/agent-discipline.md`](../dev-plan/agent-discipline.md)。

## 1. 权威排序

```
源代码（各仓） > 规则（../dev-plan/constraints.md） > 本文档集其余部分
```

- **代码是现状的唯一真相。**本文档集是帮助理解代码的缓存，与代码冲突时以代码为准。
- 文档之间矛盾：先比"取证时点/最后更新"的新旧，再比上面的层级，不盲目采信。
- **规则**（[`../dev-plan/constraints.md`](../dev-plan/constraints.md)）是**必须遵守的**，
  投影是**现状的描述**。两者冲突时，说明代码违反了约束——该改代码，不是改文档。
  规则与投影冲突时，说明**代码违反了规则**——该改代码，不是改文档。

## 2. 接手演练

每次大阶段收口，验证一件事：

> 一个从未接触过本项目的人或智能体，**只靠读本目录**，
> 能否完整恢复工作现场——说出五仓分工、动手前的红线、部署顺序、
> 以及当前 digest 应到何处查？

发现断点立即补文档。这是本文档集是否合格的最终判据。

## 3. 什么不属于本文档集

| 内容 | 去哪 |
| --- | --- |
| 将来要做什么、应该怎样 | 请求记录（见 [`../working/request-lifecycle.md`](../working/request-lifecycle.md)） |
| 必须遵守的规则 | [`../dev-plan/constraints.md`](../dev-plan/constraints.md) |
| 做到第几步了 | 请求的进度游标；本文档集**一律不写进度** |
| 镜像 digest、迁移 head 等易变值 | 只指真源，见 [`verify.md`](verify.md) |

