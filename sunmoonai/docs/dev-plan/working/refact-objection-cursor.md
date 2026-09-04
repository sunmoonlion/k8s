# Refact 环节④异议 · cursor

> 作者：cursor  
> 日期：2026-09-04  
> 范围：只核对本家被处置主张（`refact-objection-call.md` §4.2）。不评稿子整体，不替别家喊冤。  
> 结论：**无异议。**

取件一律 `git show` / `git diff` / `git log`，不看工作区。候选 `65cd113a` 与评审 `49b1e6be` 本轮未改。

---

## 1. 取件冻结

| 对象 | 分支 / commit | SHA-256 |
| --- | --- | --- |
| 异议通知 | `refact-integration` `b20607f1` | `fcc6f59f0dcdc53c00de45a9bab6257fffcb277ee7b98d9343eb770f91eda226` |
| 裁决稿 | `refact-integration`（文件停在整合链；通知称 `f6937446` 时稿已定）1593 行 | `ef20c8c6c5db5eb9a0722872b4d067766195951529658a29d5d915d618f881ea` |
| 处置记录 | 同上 | `1a0534e586444145341dd82279f9eba94f7e1aadf16113d6a98c6586c205f717` |
| 基座 luna | `f8bc48e3` | `3749a0c00bfe6258525f809ec7cc4cb396e4b9c7cc6877d88abfc10f27a5e3e2` |
| 本家候选 | `cursor` `65cd113a` | `98da6c5bceedc9ddef9191a6f34af44a49dc34a8e77ee0556bdcf6f2aefc780b` |
| 本家评审 | `cursor` `49b1e6be` | — |

对照命令：`git diff f8bc48e3 refact-integration -- sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md`。  
哈希与通知 §1 一致；`refact-integration` 现 HEAD `b20607f1` 只比通知所记 `f6937446` 多一笔「④ 发起异议轮」，未改裁决稿或处置记录。

---

## 2. 本家处置逐条核对

通知 §4.2 列出的 12 条（10 接受 + D-C5 确认并入纪律 + D-C20 部分接受），对照评审 D 节原文与裁决稿落点：

| # | 裁定 | 本家原文 | 落点是否忠实 |
| --- | --- | --- | --- |
| D-C1 | 接受 | 候选 §17：Port 存在理由是纪律层能用 Fake worker 测，不是「将来可能换」 | 是。§4.7 写明 `FakeAgentWorker` 可测性是**现在就成立**的理由 |
| D-C5 | 确认，错引不并入；纪律并入 | 评审 C.3：qwen 把产品 I12 写成 `constraints.md` I12；constraints I 系列只到 I8 | 是。头部新增「编号必须写明出处文档」，并点名本轮已有此错 |
| D-C7 | 接受 | 候选 §19.1：⚠ KIND 默认不 enforce NetworkPolicy，包级验证须另起 Calico | 是。§4.9 部署表下保留 ⚠ |
| D-C8 | 接受 | 评审 D.8 / 候选 §15.2：熟路（问数主链）编排权留控制面，租用的是生路循环 | 是。§4.5 独立成段，并接到 §9.1 |
| D-C9 | 接受 | 候选 §6.9：不改路由 / 不换执行器 / 不扩权；`worker_kind` 创建时钉死 | 是。新增 §6.9 三条表。落点写「执行器种类」而非字段名 `worker_kind`——与 D-L4「不固化未验证字段表」同向，含义未改 |
| D-C10 | 接受 | 候选 §17.1：`submit_result` 与三态探针属 Port 签名 | 是。`submit_result` 进 `AgentExecutorPort`；三态落在已有 `capabilities()`。补句「Harness SDK 当前并无此方法」是澄清，不是改义 |
| D-C11 | 接受 | 候选 §20.3：超时独立成态，不折成 `auto-deny` | 是。§9.2 写 `approval_timeout` 及审计区分 |
| D-C12 | 接受 | 候选 §23.4：文末集中未验证清单 | 是。新增 §11.3。条目与 luna/kimi/qwen 的 ⚠ 合并，结构主张（集中清单）在 |
| D-C15 | 接受 | 候选 §23.1：人那份头部仍写「开发结束后会删除」，与混合存续当下冲突 | 是。§11.1 挑明冲突在当下，并以本文为准 |
| D-C16 | 接受 | 候选头部：本文不是 `request-lifecycle.md` 的投影，I1–I15 / AT-\* 以那份为准 | 是。头部两段均在 |
| D-C17 | 接受 | 候选 §0.5：产品子 Task 编排是第三套名字 | 是。§0.3 表下点名，只引用不定义 |
| D-C20 | 部分接受 | 评审 D.20：**建议**上层用 Router **或** TaskRouter 作代码符号，中文保留「调度监督器」，不采 `Dispatcher` | **部分接受的内容就是该条建议本身**（选了 `TaskRouter` 这一侧）。不是截断或改义 |

基座未选本家：通知所述结构硬伤（§15–§23 在附录 B 之后）是评审 C 节本家自己列的第 1 条，不翻案。

D-L4 是 luna 的主张（吸收本家 `WorkerHandle` 字段清单），不在本家异议范围内。处置「只并入可序列化 + I13，不并入字段表」与本家评审 A.6「不把 Port 字段名写成已冻结 API」一致，无喊冤必要。

---

## 3. 结论

**无异议。**

十二条处置均未发现「误读原文 / 接受了却没落到稿上 / 部分接受截错了边界」。没有达到门槛（处置条目 + 为什么错 + 应当是什么 + 可复跑证据）的条目，故不提出异议。

---

## 4. 盲区

- 未对 `~/repo/codex` / `~/repo/deepseek-harness` 重跑锚点；本环只核处置是否忠实于本家主张，不重做事实裁判。
- §11.3 清单条目是四家 ⚠ 的并集，未逐条回溯每一条 ⚠ 的最初出处家。
- 未读裁决方 worktree 工作区；只读 `refact-integration` 已提交对象。
