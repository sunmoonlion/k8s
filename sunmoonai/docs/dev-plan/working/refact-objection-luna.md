# Refact 轮 · 环节 ④ 异议 · luna

提交方：luna（基座作者）｜日期：2026-09-04

## 1. 固定取件与范围

我只处理 `refact-objection-call.md` §4.1 指给 luna 的内容，不评价整稿优劣，也不替其他候选
主张异议。取件对象为 `refact-integration` 的环节③整合提交
`f693744613f7b39a2cdfbe38d20a2b3be460cd33`：

| 对象 | SHA-256 |
| --- | --- |
| `development-lifecycle-agent.md` | `ef20c8c6c5db5eb9a0722872b4d067766195951529658a29d5d915d618f881ea` |
| `refact-disposition.md` | `1a0534e586444145341dd82279f9eba94f7e1aadf16113d6a98c6586c205f717` |

异议通知本身位于随后提交 `b20607f16a61f4a72bffe79086f3f76b63ddb65f`。外部 SDK 事实仍按
整合稿钉定的 DeepSeek Harness `dd6322d604e00eec1ba5e0c8541159906a21094a` 复核。

结论：有 **4 条语义异议 + 1 条结构异议**。我不坚持原候选的所有判断；其中
`F-EXEC-02` 的原判 `explicit_unsupported` 确实过严，但裁决稿现在的改判仍没有落到正确三态。

## 2. 内在一致性回答

| 插入点 | 判断 | 理由 |
| --- | --- | --- |
| §0.3 | **有冲突，见 O-L2** | 新增的版本化确定性路由与原文仍允许模型直接“选择”合法候选并存，未满足任务书“上层不能是模型” |
| §4.5 | **一处冲突，见 O-L3；另有范围膨胀，见 O-L5** | Gate 0 第 3 条的退路与 §4.9/T3 冲突；“生产无 agent”与成熟度表有重复，但属于先给认识论地基再给局部判断，不构成冲突 |
| §4.7 | **无异议** | `submit_result`、三态探针、Fake 可测性、可序列化 binding 与原 Port/Adapter 边界相容；重复是在补“为什么”和完成语义 |
| §4.9 | **除 O-L3 指向的跨节冲突外无异议** | prefork 事故、KIND 限制和 teardown 是原部署门禁的证据补强；但 `python/sdk/…/client.py` 中的省略号不是可复跑路径，裁决方宜顺手展开真实路径 |
| §6.9 | **无异议** | 与 §0.3 的“三不得”重复是有意把上层关系落实成 Attempt 内可执行禁令，没有扩大 §6 范围 |
| §9.2 | **有冲突，见 O-L4** | `approval_timeout` 作为审计 reason 正确；称为“独立一态”会与产品合同的既有状态机冲突 |
| §11.3 | **无异议** | 它明确是散标汇总，并非新事实；与各节 ⚠ 的重复服务于 Gate 0 建单，不构成双真源 |

qwen 对基座 §4 膨胀的批评成立：整合前 §4.5–§4.11 已把 184 行执行器架构放在
“sandbox 与 Git 物化”标题下，整合后又继续增加内容。现在不是段内语义冲突，而是标题已不能
覆盖章节范围；O-L5 给出只改标题、不搬锚点的最小修正。

## 3. 正式异议

### O-L1：D-K1 对 `F-EXEC-02` 的改判仍然分类错误

**处置条目：** `refact-disposition.md` D-K1；整合稿 §8.1 的 dsh `F-EXEC-02`。

**为什么错：** 产品义务原文是“将工具输入输出、模型/工具版本和证据关联到 Attempt”，没有
Turn 级子义务。裁决理由一方面认定 `sessionId` + Attempt↔session 1:1 已使 Attempt 级关联成立，
另一方面却把整格判成“当前缺失（turn 级）”。这把一个额外的上游精度缺口当成整条产品义务的
三档状态，与刚加入的对应表也不一致：协议没有显式否定 Attempt 级关联，就不应映射
`explicit_unsupported → 当前缺失`。

我撤回原候选的 `explicit_unsupported` 原判；但 `sessionId` 只提供来源标签，不自动完成平台侧
唯一 binding、全 runtime 事件过滤、子 session 归属、模型/工具版本补齐和证据持久化，所以也不能
判“已支持”。

**应当是什么：** dsh 该格改为 **`implicit_fallback`（需补法）**：SDK 的 `sessionId` 足以作为
Attempt 级关联输入；平台必须强制 Attempt↔根 session binding、过滤全 runtime 通知、递归登记子
session、补齐版本并持久化证据。另保留一句：逐 Turn completion correlation 当前缺失，是上游
G3 门禁；需要逐 Turn 保真时路线 fail-closed。这样既不把 Turn 偷换成产品义务，也不把 SDK 标签
冒充完整证据链。

**可复跑证据：**

```sh
git show f6937446:sunmoonai/docs/dev-plan/working/request-lifecycle.md | nl -ba | sed -n '380,386p'
git show f6937446:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md | nl -ba | sed -n '1131,1155p'
git -C ~/repo/deepseek-harness show dd6322d6:packages/sdk/protocol/src/types.ts | nl -ba | sed -n '61,70p'
git -C ~/repo/deepseek-harness show dd6322d6:packages/sdk/protocol/README.md | nl -ba | sed -n '34,52p'
```

前两处分别显示 `F-EXEC-02` 的 Attempt 级原文和裁决稿三态/映射；后两处显示每个
`SessionEventNotification` 确有 `sessionId`，但 `session.event` 对 runtime 全量未过滤，且
`messageId` 不标识 turn ending/result。

### O-L2：§0.3 的确定性路由仍留有模型决定口

**处置条目：** D-K6/D-C20 插入 §0.3 后的内在一致性。

**为什么错：** 整合稿先说路由表是版本化配置，又说调度监督器必须是确定性代码，随后仍允许
模型“在合法候选中选择”。固定 schema、无工具和低预算只能收窄风险，不能使模型输出可重放、
确定；这与任务书 §9.1 的硬要求“上层是代码所以确定”“不能是模型”正面冲突。新增的“v1 不做
模型驱动动态编排”也没有关闭模型分类选路口，因为分类与动态编排不是同一件事。

**应当是什么：** 最终 `worker_kind/Profile` 只能由版本化确定性规则选择。若保留模型分类，输出
只能作为不具决策权的建议/证据；确定性规则能唯一验证时才落档，否则创建 Interaction 或明确
失败，不能默认通用档，也不能由模型结果直接决定路线。

**可复跑证据：**

```sh
git show f6937446:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md | nl -ba | sed -n '84,101p'
git show f6937446:sunmoonai/docs/dev-plan/refact-task.md | nl -ba | sed -n '277,295p'
```

整合稿 `:90-96` 同时保留确定性配置和模型选择；任务书 `:293-295` 明定上层必须是确定性代码、
不能是模型。

### O-L3：§4.5 Gate 0 第 3 条的退路与 §4.9/T3 冲突

**处置条目：** D-K3（部分）与 D-C8 合并到 §4.5 后的内在一致性。

**为什么错：** 第 3 条写 Harness 在 Celery worker 内不稳定时“只在独立运行角色内使用，
不进 worker”；§4.9 随即规定运行角色分为通用执行 worker、专业执行 worker。`constraints.md`
T3 也把 Worker 定义为 Backend 的运行角色，并另设“什么时候才拆出专用 Worker”的证据门槛。
“独立运行角色但不进 worker”在现有拓扑词典里没有合法落点，容易被实现成新的领域服务。

**应当是什么：** 改成：“该腿不得进入**现有通用 Celery worker**；若资源/失败率证据满足
`constraints.md`‘什么时候才拆出专用 Worker’，则拆专业 Worker/Deployment，仍属于同一 Backend
运行角色；否则该腿不进产品链路。”

**可复跑证据：**

```sh
git show f6937446:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md | nl -ba | sed -n '400,416p;525,529p'
git show f6937446:sunmoonai/docs/dev-plan/constraints.md | nl -ba | sed -n '98,108p'
```

### O-L4：审批超时应是 reason/outcome，不应称“独立一态”

**处置条目：** D-C11；整合稿 §9.2。

**为什么错：** 区分“策略拒绝”和“无人响应超时”的审计动机正确，但产品合同已经穷举 Task
状态与合法转换，并规定 Interaction 到期后由 Task Profile 选择 `FAILED`、重新 `QUEUED`、回
`VALIDATING` 或按政策 `CANCELLED`。开发指南验收标准又禁止重定义这些对象。“独立一态”会被
读成第五个 Task/Interaction 状态；整合稿实际给出的却只是 `approval_timeout` reason code，标题
和落地语义互相矛盾。

**应当是什么：** 改成“**超时是独立审计结果/reason，不折成 `auto-deny` reason**”。行为仍
fail-closed，记录 `approval_timeout`、等待时长和对象哈希；随后严格按 Task Profile 关闭
Interaction 并走产品合同已有合法转换。不得新增状态。

**可复跑证据：**

```sh
git show f6937446:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md | nl -ba | sed -n '1228,1248p'
git show f6937446:sunmoonai/docs/dev-plan/working/request-lifecycle.md | nl -ba | sed -n '203,230p;257,274p'
git show f6937446:sunmoonai/docs/dev-plan/refact-task.md | nl -ba | sed -n '361,374p'
```

### O-L5：§4 标题已经不能覆盖 §4.5–§4.11

**处置条目：** §0.3、§4.5、§4.7、§4.9 等插入后的整体结构问题（通知 §4.1 第 1 问）。

**为什么错：** §4 标题仍是“sandbox 与 Git 物化”，但 §4.5–§4.11 已覆盖执行层路线、双 SDK、
Port、Harness 门禁、runtime 部署/恢复、专用 Agent 构建和 OpenClaw。整合方选择 luna 的理由是
避免搬迁抹掉锚点；这不等于标题与范围仍匹配。继续在 §4 追加会让后续读者误以为执行器架构只是
物化子问题。

**应当是什么：** 本轮不要搬动 §4.5–§4.11；只把顶层标题改为
“`## 4. sandbox、Git 物化与执行器接入架构`”。这是最小修正，保留 as-published 结构与全部
行内锚点。若未来拆章，应另开规范重构并逐条保持引用映射，不在本轮做结构手术。

**可复跑证据：**

```sh
git show f6937446:sunmoonai/docs/dev-plan/working/development-lifecycle-agent.md | nl -ba | sed -n '301,371p;568,590p'
git show f6937446:sunmoonai/docs/dev-plan/working/refact-disposition.md | nl -ba | sed -n '52,58p'
```

## 4. 对通知列出的另外两项处置

- **D-L4 部分接受：无异议。**只保留“binding 可序列化、SDK id 不是 Task 真源（产品 I13）”，
  不冻结 cursor 的 `WorkerHandle` 字段清单，符合 `refact-task.md` §10。整合稿 §4.7 随后声明
  字段由契约测试钉死，也没有把它冒充具体 Profile 字段表。
- **三态与三档对应表：原则上无异议。**显式对应能消除措辞歧义；但 O-L1 所述 dsh
  `F-EXEC-02` 必须按对应表重新归为 `implicit_fallback / 需补法`，不能用“当前缺失（turn 级）”
  给产品义务增加一个未登记的 Turn 级口径。

## 5. 盲区

本异议仍是静态合同/源码审查：没有运行 dsh 多 session、多 Turn、子 Agent、断线或事件丢失测试，
所以 O-L1 提出的 `implicit_fallback` 也只是正确的设计分类，不是 `wired` 或
`runtime-verified`。KIND、Celery、SDK teardown 与审批超时扫描均未实跑。裁决方若以运行证据
推翻任一条，应固定 runtime/SDK commit、测试输入和事件输出，而不能只以“实现时可以处理”作答。
