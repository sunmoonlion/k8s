# 已知缺口

> 最后更新：2026-08-29
>
> 从五仓代码投影中查出、**尚未处置**的缺口。
>
> **本文件只放未办的。**一条了结了就从这里删掉——结论写到它该在的地方去：
> 现状类进 [`../project-guide/`](../project-guide/) 的对应投影，设计类进
> [`README.md`](README.md)，为什么这么改进 git 提交信息。清单清空后本文件即可删除。
>
> 按 [`../project-guide/request-lifecycle.md`](../project-guide/request-lifecycle.md) R6：
> 每条要么立请求，要么明确"已知并接受"——**接受也算了结，同样从这里删掉**，
> 但接受的理由与重新审视的触发条件必须落到投影里。悬空的代价很具体：下一轮做
> 代码投影的人会把它当新缺口再报一遍，然后重新论证一次它是有意的。本轮浪费过一遍。

编号 O 系列，与 [`README.md`](README.md)「下一步」的 U 系列（智能体设计未决）不同：
U 是"还没想清楚"，O 是"已经查实、等着处理"。**编号不复用**——删掉的号就作废，
这样 git 历史与提交信息里的 O 编号永远指向同一件事。

| # | 事项 | 出处 | 性质 |
| --- | --- | --- | --- |
| **O6** | 契约 `source_href` 与真实路由不匹配，照字面 GET 会 404 | [`topics/contracts.md`](../project-guide/topics/contracts.md) §5 | **真缺陷**：任何按契约文档实现的 consumer 都会踩 |
| O7 | REQ-009 的"休眠能力声明+校验"机制未落地 | [来历记录](../project-guide/history.md) §3.3 | 机制缺口 |
| O8 | `docs/` 下并存的历史目录尚未清理 | [`README.md`](../project-guide/README.md) §本集之外 | 待整理 |
| O9 | Harbor 上 `:2.0.0` 别名是否物理存在未核实。`build_r7_release_manifest.py` 的 `tagged_image()` 只拼出该字符串写入清单，仓库内无任何脚本执行 `docker tag` 或等价推送 | [总览](../project-guide/overall-architecture.md) §9.1 | 一条 `curl` 可定，需能访问 Harbor。若缺失则补打别名即可，digest 不变，不影响运行中的负载 |
| O10 | 构建脚本默认 tag 与发布口径脱节：`build-push-app-images.conf` 默认 `TAG=1.0.0`，与 manifest `overwrite_v1_1_0_0: false` 的 v1 保护位相撞；且该脚本组件名仍是 v1 的 `admin-backend`/`web-backend`（目录已随 ADR-0007 消失） | `k8s:sunmoonai/app-platform/scripts/` | 现为**哑火**——组件名不对，跑起来先失败。修好脚本会立刻兑现覆盖 v1 制品的风险 |

**O1–O5 已了结**（版本口径、RAGFlow CANCEL、RunBudget、Outbox、Scheduler），
条目已删，结论分别在：总览 §9.1、`repos/knowledge-app.md` 与该仓的
`test_knowledge_ingestion.py`、[`README.md`](README.md) 的 U3 行、总览 §9.2。
过程见 git 历史。
