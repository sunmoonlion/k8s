<!-- I06-001 -->
# 开发计划

> 最后更新：2026-08-29
>
> **这里回答"要建什么、为什么这么建"。**
> 具体任务见 [`implementation-plan.md`](implementation-plan.md)，
> 当前状态见 [`handoff.md`](handoff.md)，
> 代码必须符合的规则见 [`constraints.md`](constraints.md)。

> 路线图 / SDP 输入｜S0/S3。产品阶段和运行时演进各自按依赖顺序列，不能把某次历史取证当本次开工凭据；架构取向迁 TLD/SDD。
>
> 2026-09-14 按 [dev-plan-architecture.md](dev-plan-architecture.md) 第八节从 `1d0adde3` 迁入。每节前的 `<!-- Ixx-xxx -->` 是安置表 ID，冻结原文用 architecture 的 `show` 取。

## 产品建设顺序

先前后端，再 agent，后问数；每阶段原始约束和日期保留，决定过的顺序不由文档重排改变。

<!-- I06-006 -->
### 三个阶段

**一 前后端对接 → 二 agent 开发 → 三 问数。**

<!-- I06-007 -->
#### 一 · 前后端对接

**缺口是确切的：两边路由已经对称，缺中间那个适配器。**

```
浏览器 → /api/web/v1/runs …（7 条，已存在）
              ↓
      WebInteractionPort ← 只有两个实现，都不能用于生产
              ↓
      /api/internal/v1/investment/runs …（5 条，已存在，Pilot 链路在跑）
```

| 实现 | 状态 |
| --- | --- |
| `UnavailableWebInteractionAdapter` | 生产默认，一律 **503** |
| `ReferenceWebInteractionAdapter` | 确定性夹具，**生产配置明令拒绝**（检出 `REFERENCE_INTERACTION_ENABLED` 为真即拒绝启动） |

即：**web 面没有任何生产实现**，四个仓都是这个状态。

前端栈不是缺口：八个前端均 Next.js 16.2.2 + React 19.2.4，与 v5 §10.10 的
目标态一致（唯一差异：v5 要求 Admin 用 Ant Design 6，实际未引入）。

做这一阶段时逐节引用 v5 §10：§10.1 对象边界 · §10.2 事务原则 · §10.3 SSE 对账 ·
§10.4 前端 API 边界 · §10.5 Web 交互状态机 · §10.7 安全与隐私 · §10.9 观测与测试。

**§10.4 的 BFF 问题仍然开放**，别当它已被否决：Next.js 可以承担浏览器同源
BFF / session 边界，但不得成为领域数据所有者；且授权分工必须有显式契约
（规则 I4、I5）。用不用 BFF 是这一阶段要定的事。

<!-- I06-008 -->
#### 二 · agent 开发

即上面「智能体分两部分」几节。

**四本账已有两本是真的**，不是从零建四张表：

| 账 | 表 | 生产接线 |
| --- | --- | --- |
| 幂等 | `idempotency_key` | ✅ 8 个源文件在用 |
| 副作用 | `tool_side_effects` | ✅ `tasks/agent_graph.py` 的 `record_once` |
| **预算** | 无 | ❌ 只有内存 `RunBudget`，跨进程即失 |
| **证据** | 无 | ❌ citation 只在事件流里，不落表 |

<!-- I06-009 -->
#### 三 · 结构化数据问答（后期）

归**专用部分**——它是专用智能体的一个实例，加一份 Profile 加一个工具，
不是另一套架构。

理由是范围控制，不是能力归属：定位为通用会诱导第一版支持任意数据源与 schema，
在跑通一条真实链路之前先铺抽象。**抽象推迟到第二个领域需要时再做**——
不到第二个用例，不知道通用的边界在哪；提前抽出的"通用"多半是投资的形状
套了通用的名字，比不抽更糟。

**开工前必须先解决一件事：投资仓现在没有任何业务数据表。**13 张表全是运行时
基础设施（agent 运行时 / LangGraph checkpoint / outbox / auth），全仓
`portfolio|holding|ticker|instrument` 命中数为 0。**没有数据就没有问数。**

参考资料在 `~/codex-reference-archive/`（2026-08-29 核）：

| | 现状 |
| --- | --- |
| `sqlbot-opus.md` | SQLBot 是**完整问数应用**，SQL 安全防护默认开启 |
| `wrenai-opus.md` | WrenAI **已转型**为"给 agent 用的语义上下文层"，旧 GenBI 应用冻结在 `legacy-v1` 分支 |

两者不再是同类产品的两个选项。**两份调研都未评估准确率**——真要选型时，
那是核心指标。

## 运行时演进与退出门

现行 G0–G5 和分组件迁移门描述待交付增量；不能混同本候选 DEV/G0–G6。

<!-- I02-083：原章标题「演进与退出脚手架」无正文，不单列 -->

<!-- I02-084 -->
### 依赖顺序

| 步 | 产物 | 前置 | 退出条件 |
| --- | --- | --- | --- |
| G0 | 协议、状态脚本与分发脚本一致 | 无 | 历史已完成轮次和空轮次均得到人工一致的状态结果 |
| G1 | Interaction 现状 spike | G0 | 真实中断、同 thread 恢复、stale/重复/跨 Task 拒收有可复现实验 |
| G2 | 服务端 principal channel 与 Side Effect 强制点 | G1 | executor 无权伪造响应或直接写生产，失败关闭；不依赖本机可改门禁 |
| G3 | Agent Profile + executor adapter + 角色冲突门 | G1/G2 | 每个自动候选至少跑通一次 Attempt，字段值有探针证据 |
| G4 | `dev.change/1` 服务态与 T0/T1/T2 execution policy | G2/G3 | 三档真实 Task 与手工历史按 `design/evidence-sdd.md`「手工态与服务态的等效判据」 等效，证据强度不下降 |
| G5 | 文档与脚手架收口 | G4 | 逐节迁移零缺口、引用清零、门禁全过、旧稿删除经人确认 |

G1 是本轮对旧路线的修正：先验证现有库原语，不先发明字段。G2 的判据针对真实写路径和服务端身份，
不以新增 Git 仓或轮换网络 key 代替产品授权。当前阶段游标仍以 handoff 为准；目标顺序不因现状阻塞而改写。

<!-- I02-085 -->
### 从手工态拆到服务态

| 手工实现 | 服务实现 | 可拆条件 |
| --- | --- | --- |
| `round.md` Task 主档 | Task 表 | 三档至少各一条轨迹等效且 provenance 不下降 |
| commit + rulings + events 投影 | Event 表 | 同一历史轮次输出相同状态序列，新判据已人工对照 |
| 落盘通知与人工投喂 | executor adapter / principal channel | 自动执行器有进程入口；人工执行器有显式审计桥 |
| `round-status.py --verify` | acceptance runner | 对历史轮次逐条判定一致 |
| `git worktree add` | provision service | 独占、干净、基线判据进代码并有测试；worktree 载体可保留 |

事务、租约、fencing 只有服务态验收通过才算实现，不能用轨迹“相似”替代。

⚠ **而服务态那一侧已经验过了，这一栏因此不是「未来才能做的事」。**
产品仓（PostgreSQL 载体）现有测试全部通过，实跑 **156 passed, 2 skipped in 5.13s**：

| 项 | 测试 |
| --- | --- |
| fencing | `test_expected_version_prevents_two_workers_claiming_same_run` |
| 租约 / 并发 | `test_relational_schema_enforces_identity_and_concurrency_constraints`、`test_same_thread_rejects_second_non_terminal_run` |
| 副作用恰好一次 | `test_interrupt_resume_executes_side_effect_once`、`test_retry_after_crash_after_commit_does_not_repeat_effect` |
| 陈旧覆盖被拒 | `test_versioned_reducer_rejects_stale_plan_overwrite` |
| 取消先于副作用 | `test_cancelled_run_stops_before_side_effect_and_releases_thread` |

**所以缺的不是「并发语义没人验」，是「手工态与服务态的等效比对」还没做。**
两句话差别很大：前者指向一件未开工的事，后者指向一件已完成一半的事。

⚠ **这一段也曾写偏过。**「**git 载体**验不了这三样」这句本身成立，
但整份文档只写了这一句，**读起来像「本项目至今没验过」**。
教训：**「某载体证不了 X」与「X 未被证明」是两件事，不许合写。**

拆脚手架按组件逐项判，不因服务部署成功整批宣布完成：Task/Event 要比完整状态序列；
acceptance runner 至少对三轮可取得的历史产物逐条对照；每个拟自动路由的 Agent Profile
实际跑通一次 Attempt；人工桥接仍需记账；Interaction 还须证明响应者身份进入不同于执行者的
受保护凭据域。轨迹各类 attested 数量与最低 provenance 都不能退步。
这些是迁移验收条件，**不表示本次已完成等效实验**。
