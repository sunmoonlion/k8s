# Cursor 续作说明（历史文档族索引）

日期：2026-07-29（Asia/Shanghai）  
这些文件记录 Cursor 的施工过程，不再作为当前验收真相源。Codex 已完成独立代码审查、
干净源码重建、六组运行时配对、三套真实回滚及 fail-closed P0-009E 总门禁。

当前权威入口：

1. [`codex审查-cursor续作-20260729.md`](./codex审查-cursor续作-20260729.md)
2. [`evidence/v5/V5-P0-009E/result.md`](./evidence/v5/V5-P0-009E/result.md)
3. [`mooc-manus-langgraph-v5-implementation-plan.md`](./mooc-manus-langgraph-v5-implementation-plan.md)

---

## 0. 现在该读哪份

| 若你要… | 打开 |
|---------|------|
| **当前游标** | 下表 + [`cursor续作-P0-009E.md`](./cursor续作-P0-009E.md) |
| B6 模板门禁 | [`cursor续作-B6.md`](./cursor续作-B6.md) |
| 009A/B Info | [`cursor续作-P0-009.md`](./cursor续作-P0-009.md) |
| 009C Knowledge | [`cursor续作-P0-009C.md`](./cursor续作-P0-009C.md) |
| 009D Research | [`cursor续作-P0-009D.md`](./cursor续作-P0-009D.md) |
| 009E 收敛 | [`cursor续作-P0-009E.md`](./cursor续作-P0-009E.md) |

**当前状态（2026-07-29）**

- Wave-1～5 已经 Codex 独立复验；P0-009E 严格门禁通过
- **P0-009 整体 ACCEPTED**；三 App `INSTANCE_FOUNDATION_ALIGNED`  
- **下一任务：P0-008C**（未开工，需明确授权）  
- 远端 Git：**未推**；业务流量：**未切**

---

## 1. 五波对照

| Wave | 对象 | 详文 |
|------|------|------|
| 1 | `tpl-app` B6 | [`cursor续作-B6.md`](./cursor续作-B6.md) |
| 2 | Info 009A/B | [`cursor续作-P0-009.md`](./cursor续作-P0-009.md) |
| 3 | Knowledge 009C | [`cursor续作-P0-009C.md`](./cursor续作-P0-009C.md) |
| 4 | Research 009D | [`cursor续作-P0-009D.md`](./cursor续作-P0-009D.md) |
| 5 | Convergence 009E | [`cursor续作-P0-009E.md`](./cursor续作-P0-009E.md) |

历史施工顺序：1 → 2 → 3 → 4 → 5。不得再按这些文档里的旧候选 digest 或旧
`domain-keep`/overlay 指令重放；重放使用当前 commit、alignment lock 和权威证据。

---

## 2. 共享约束

不推 Gitee；不切业务流量；Harbor 仅 candidate；KIND 用 `kubectl-kind-v1.27.3`；digest 带全仓库前缀；勿 `merge -X theirs`。

---

## 3. 文件族

```text
cursor续作.md
cursor续作-B6.md
cursor续作-P0-009.md
cursor续作-P0-009C.md
cursor续作-P0-009D.md
cursor续作-P0-009E.md
```
