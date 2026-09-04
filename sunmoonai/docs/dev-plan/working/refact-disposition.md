# Refact 轮 · 环节③ 处置记录

> 裁决与整合：opus ｜ 日期：2026-09-04 ｜ 基座：**luna** `f8bc48e3`
> （SHA-256 `3749a0c00bfe6258525f809ec7cc4cb396e4b9c7cc6877d88abfc10f27a5e3e2`）
>
> 依 `round-protocol.md` §5：从选定候选的 commit 取基座（不从工作区取）；
> 一条主张一个提交；逐条写明接受 / 部分接受 / 拒绝及**能独立成立**的理由。

---

## 1. 候选集与评审集（冻结）

| 家 | 候选 commit | 行 | 字节 | SHA-256 |
| --- | --- | ---: | ---: | --- |
| luna | `f8bc48e3` | 1439 | 96,181 | `3749a0c0…a5e3e2` |
| kimi | `9fe43808` | 1605 | 107,909 | `83f1d8f8…4c0c99e` |
| cursor | `65cd113a` | 1649 | 113,596 | `98da6c5b…fc780b` |
| qwen | `0c6f0fc3` | 1560 | 105,425 | `ea2bb7ab…8675fd` |
| 基座（master） | `3555ad7e` | 1161 | 71,204 | — |

opus 本轮不参赛，其 worktree 内该文件与 master 逐字一致（已核）。

评审：luna `16c13ece`、cursor `49b1e6be`、qwen `d26166a5`、kimi（环节②交付，本记录采用其内容）。

## 2. 四家排序汇总

| 评审方 | 第1 | 第2 | 第3 | 第4 | 基座建议 |
| --- | --- | --- | --- | --- | --- |
| luna | luna（自） | qwen | kimi | cursor | luna |
| cursor | luna | kimi | cursor（自） | qwen | luna |
| kimi | luna | cursor | qwen | kimi（自） | luna |
| qwen | kimi | cursor | luna | qwen（自） | kimi |

三家推 luna，其中 cursor 与 kimi 均**把自己排在 luna 之下**。
**但票数不是依据**（`round-protocol.md` §4-C：事实题用证据裁）。下节是裁决方的独立复核。

## 3. 裁决方独立复核（不依赖任何评审转述）

| # | 复核项 | 结果 |
| --- | --- | --- |
| V1 | 七个冻结节（§5、§7、§12、§13、§14、附录 A、附录 B）逐字未改 | **四家全部逐字节一致**。验收标准 1 全过 |
| V2 | luna 删除 30 行的落点 | 全部在允许改动区：§0.3、§6 引言、§11.1/§11.2（后者正是 §9.3 要求重写的）。无回归风险 |
| V3 | cursor 的 §15–§23 位置 | 属实，落在 `附录 B` 的 ①–⑨ 模板之后；另三家均终止于 ⑨ |
| V4 | luna 头部日期「2026-09-03」 | **kimi 的批评不成立**：luna 候选 `f8bc48e3` 就提交于 09-03 20:09，日期属实 |
| V5 | qwen 引用 `constraints.md` I12 | **cursor 的指认成立**：`constraints.md` 的 I 系列只有 I1–I8；该条内容出自 `request-lifecycle.md:459` |
| V6 | qwen 给 dsh 腿 F-EXEC-01 的证据 | **四份评审都没发现的错误**，见 §5 D-Q3 |
| V7 | 「`RunBudget` 引用数为 0」探针（任务书 §4⑥ 的不精确表述） | **无一家照抄**。kimi/cursor/qwen 三家独立走到准确表述，其中两家自行找到 `test_dormant_capabilities.py` 登记表 |

## 4. 基座裁定

**选 luna。**理由三条，均可复核，且不含票数：

1. **AT-\* 锚定**：luna 11 个，kimi 4 个，cursor 与 qwen 仅范围引用。
   `refact-task.md` §12.3 括注「上一次整合栽在这里」——本轮最重维度，luna 独到。
2. **as-published 结构**：luna 整合式（内容进 §4/§8/§9/§11）、附录居末，无需搬迁。
   09-03 那次失败整合正是在搬家时把锚点抹成散文的（`round-protocol.md` §8），
   搬迁本身就是已知风险源。
3. **映射表判定锋利度**：`F-EXEC-05` Codex 腿只有 luna 判准（见 D-L2）。

**不选 kimi**（qwen 的推荐）：qwen 的理由是「as-delivered 免搬迁」，但该批评的对象是
cursor；luna 同样免搬迁，故该理由不构成推翻 luna 的依据。kimi 另有实质判轻（D-K1）。

**不选 cursor**：内容最完整、§9.3 最佳，但 §15–§23 在附录之后（V3），当基座需先做结构手术。
其独有主张按 §5 逐条吸收。

**不选 qwen**：单点锚点最硬，但有 V5、V6 两处取证错误；当基座会把它们写成正文默认。

## 5. 逐条处置

编号规则：`D-<出处首字母><序号>`。**接受**=原样并入；**部分接受**=改写后并入，写明止于何处；
**拒绝**=不并入，写明理由。

### 5.1 事实判定类（与吸收无关，先裁定，因为它们决定并入什么）

| # | 争议 | 裁定 | 理由 |
| --- | --- | --- | --- |
| D-L2 | `F-EXEC-05` Codex 腿：luna `implicit_fallback` vs cursor/qwen「已支持」 | **采 luna** | 义务是「可恢复进度写 checkpoint，**不依赖进程内记忆**」。`thread/resume` 恢复的是 Codex 自有 `CODEX_HOME` rollout，不是我们的业务 checkpoint。cursor 在自评中已认此条判宽 |
| D-K1 | `F-EXEC-02` dsh 腿：kimi「已支持（设计）」vs luna `explicit_unsupported` vs cursor/qwen「当前缺失」 | **两家都不采，取 cursor/qwen 的「当前缺失」** | 义务是关联到 **Attempt**，不是 Turn。`sessionId` 挂在每个事件上，Attempt↔session 1:1 时 Attempt 级关联成立 → kimi 判「已支持」忽略了结果无法绑定 turn（`protocol/README.md:52` 明写 `messageId` 不标识 turn 结束或结果），过宽；luna 判 `explicit_unsupported` 把「缺 turn 粒度」升格成「Attempt 级关联不支持」，过严。**luna 的诊断与上游补法表述（turn correlation + filtered cursor）保留** |
| D-Q3 | qwen 给 dsh 腿 `F-EXEC-01` 判「已支持（进程内）」，证据 `profiles.py:36-41` `permits_tool` + `adding-a-tool.md:59` | **部分接受** | `profiles.py` 是**本仓 investment-app 自己的代码**（`app/domain/agent/profiles.py`），不是 dsh；且该 Profile 在生产休眠（`allowed_tools`/`denied_tools` 在两条生产图引用数为 0）。**拿我方休眠代码当租来 SDK 的能力证据，是跨仓取证错位。**同格另一半 `ctx.tools.guard()` 单调 deny（`adding-a-tool.md:59`）确属 dsh，裁决方 09-04 亲核。→ 只并入 dsh 侧真证据，删去 `profiles.py` 锚点。kimi 的 D 建议整条吸收，**不采纳该建议** |
| D-C5 | qwen 错引 `constraints.md` I12（V5） | **确认，不并入** | 并入编号分写纪律：`constraints.md` 为 I1–I8，产品不变量为 I1–I15，引用必须写明出处文档 |
| D-K5 | kimi 指 luna 头部日期误写（V4） | **拒绝** | 事实不成立，luna 候选确实提交于 09-03 |

### 5.2 接受并入（每条一个提交）

| # | 出自 | 主张 | 处置 | 落点 |
| --- | --- | --- | --- | --- |
| D-K2 | kimi §15 引言 | 「当前生产事实：没有任何 agent 在跑」，按 §5.2 四级词典全部判 `defined` | **接受** | §4.5 开篇 |
| D-Q1 | qwen §15.2 事实⑥ | 用 `test_dormant_capabilities.py:154/182/208` 代替「引用数为 0」 | **接受** | §4.5 |
| D-K3 | kimi §15.1 | 「更好」的三条**可证伪硬条件** + ⚠「是 Gate 0 退出标准，不是既成事实」 | **部分接受** | §4.5；**删去「失败则退回自研 LangGraph」**——与 `development-plan.md` 的执行层租用方向冲突，失败应换公开 SDK 路线或走约束变更（luna D-1 同此判断） |
| D-C9 | cursor §6.9 | 内层三不得（不改路由 / 不换执行器 / 不扩权），`worker_kind` 创建时钉死 | **接受** | 新增 §6.9 |
| D-C17 | cursor §0.5 | 点名**第三套** supervisor（产品子 Task 编排，属 `request-lifecycle.md`） | **接受** | §0.3 |
| D-C12 | cursor §23.4 | 文末集中「本轮未验证」清单 | **接受** | 新增 §11.3（存续之后、§12 之前） |
| D-C11 | cursor §20.3 | 审批**超时独立成态**，不折成 `auto-deny` 以免污染审计 | **接受** | §9.2（档名用 luna 的四档） |
| D-C10 | cursor §17.1 | `submit_result` 与三态 `probe` 属 Port **签名**，不是 Adapter 私货 | **接受** | §4.7 |
| D-C1 | cursor §17 | Port 的存在理由是「纪律层能用 Fake worker 测」 | **接受** | §4.7 |
| D-Q4 | qwen §15.5 | prefork/OOM 事故锚点：默认 12 进程打爆 768Mi，模板已钉 `CELERY_WORKER_CONCURRENCY: '2'` | **接受** | §4.9 |
| D-K4 | kimi §15.7 | spawn 前环境白名单，DB/Redis 凭据不下发给 harness 子进程（I12） | **接受** | §9.2 |
| D-K6 | kimi §15.2 | Router 的**不做清单**（不拆 Work Unit、不收候选、不选优；v1 不做 LLM 动态编排） | **接受** | §0.3 |
| D-Q5 | qwen §15.2 事实① | dsh 自带 `subagent-codex`，专业腿可再委派 Codex → 凭据互斥须写进 Adapter 禁令 | **接受** | §9.2 |
| D-C8 | cursor §15.1 | **熟路 / 生路**：已能画边的问数主链编排权留控制面，不交给聊天循环 | **接受** | §4.5 |
| D-C7 | cursor §19.1 | ⚠ KIND 默认不 enforce NetworkPolicy，包级验证须另起 Calico | **接受** | §4.9 |
| D-Q2 | qwen §15.4 | dsh teardown ladder 行号 `client.py:94/117/124` | **接受** | §4.9 |
| D-L5 | luna 独有 | 三仓 commit pin + 「升级钉版必须重跑锚点」 | **保留**（基座已有） | §4.6 |
| D-C16 | cursor 头部 | 「本文不是 `request-lifecycle.md` 的投影，I1–I15/AT-* 一律以那份为准」 | **接受** | 头部 |
| D-C15 | cursor §23.1 | §9.3 存续：**挑明与 `human.md` 头部的当下矛盾** | **接受** | §11.1 |

### 5.3 部分接受 / 拒绝

| # | 出自 | 主张 | 处置与理由 |
| --- | --- | --- | --- |
| D-C20 | cursor §D20 | 上层命名取 Router / TaskRouter | **部分接受**：中文保留基座「调度监督器」，英文标识采 `TaskRouter`（可进代码符号）。不采 `Dispatcher`——会与 `F-DISPATCH-*` 绑死 |
| D-L4 | luna 评审 | 吸收 cursor `WorkerHandle` 可序列化等字段 | **部分接受**：只并入「句柄必须可序列化落 PostgreSQL、SDK id 不是 Task 真源（I13）」这条纪律，**不并入字段清单**——`refact-task.md` §10 禁止写成实例表 |
| D-K7 | kimi | 「退回自研 LangGraph」作为 Gate 0 失败后的退路 | **拒绝**：与 `development-plan.md` 的执行层租用方向冲突；失败应换公开 SDK 路线或走约束变更流程 |
| D-Q6 | qwen | 自由文本分类器的默认通用兜底 | **拒绝**：与 §9.1「上层必须确定性代码」冲突（luna 评审 D-2 同判） |

## 6. 验收方指定（`round-protocol.md` §6）

规则：不得是裁决方、不得是基座作者、优先指定主张被采纳最少的一家。

- 裁决方 opus — 排除（整合方不能自验）；
- 基座作者 luna — 排除（存量最大）；
- 实际采纳条数（按下节提交清单统计，含部分接受）：**cursor 12、qwen 5、kimi 4**；
- **指定 kimi 为验收方**：在三家可选中主张被采纳最少，对结果的既得利益最小。

指定理由不含「kimi 候选排名最低」——名次与验收资格无关，
`round-protocol.md` §6 的判据是既得利益，不是质量。

指定在裁决稿完成后作出，**不得事后更换**。

## 7. 本记录的盲区

1. 未实跑任何 SDK、未起部署、未对生产库核表；所有判断处于 `defined` 层。
2. 锚点抽验非全量：裁决方独立复核了 V1–V7 共 7 项 + 09-04 的八条事实回源，
   四家合计约 160 处 `file:line` 未全量复核。
3. AT-\* 语义未逐条核对（qwen 评审 E.3 同此盲区）：确认编号存在，
   未逐条核对 AT-05/07/09… 的验收内容与所映射 `F-EXEC-*` 是否精确对应。


## 8. 整合提交清单

从基座起一条主张一个提交，便于事后复核与回退（`round-protocol.md` §5）：

| commit | 主张 |
| --- | --- |
| `ec575636` | 取 luna `f8bc48e3` 为基座 |
| `fdaa6659` | D-K1 `F-EXEC-02` dsh 腿改判「当前缺失（turn 级）」 |
| `6962add8` | D-Q3 `F-EXEC-01` dsh 腿补真证据，剔除跨仓取证错位 |
| `616cd9e1` | 映射表补三档对应表（满足 §9.2 措辞要求） |
| `8260ef6e` | D-K2 + D-Q1 §4.5 钉住「生产现在没有 agent」 |
| `c74af02a` | D-K3（部分）+ D-C8 Gate 0 硬条件与熟路/生路 |
| `0fe5ec2f` | D-C17 + D-K6 + D-C20 第三套名字、不做清单、代码符号 |
| `12e1aa51` | D-C9 新增 §6.9 内层三条硬禁令 |
| `b78d2d9e` | D-C10 + D-C1 + D-L4（部分）Port 补强 |
| `1d0dc706` | D-Q4 + D-C7 + D-Q2 §4.9 部署与进程 |
| `15cabea7` | D-C11 + D-K4 + D-Q5 §9.2 审批与凭据 |
| `b2af5a44` | D-C16 + D-C15 + D-C5 头部声明、编号纪律、存续矛盾 |
| `e9307d51` | D-C12 新增 §11.3 未验证集中清单 |

## 9. 整合后自查

| 验收标准（`refact-task.md` §12） | 结果 |
| --- | --- |
| 1 冻结节逐字未改 | ✅ 七节与 master 逐字节一致（整合后复验） |
| 2 七块到位、带锚点 | ✅ 继承基座，另补 dsh 侧真锚点与 teardown 行号 |
| 3 用 `F-*`/`I*`/`AT-*`/A-R 锚定 | ✅ `AT-*` 13 个、`F-EXEC/F-INTERACT` 10 个全覆盖 |
| 4 双腿映射表 | ✅ §8.1，另补三档对应表 |
| 5 supervisor 消歧 | ✅ 两层定名 + 第三套点名 + 冻结区裸词规则 |
| 6 存续显式处理 + 清理清单 | ✅ §11.1（含当下矛盾）+ §11.2 清理表 |
| 7 无具体 Profile 字段表 | ✅ 零命中 |
| 8 不重定义产品对象 | ✅ 头部声明 |
| 9 「dsh 需要系统 Node」不得出现 | ✅ 全文唯一命中是「不得复活缺 Node 阻断」这句禁令本身 |
| 10 两轴分开 | ✅ 继承基座 §4.5/§4.6 |
| 11 未验证标 ⚠ | ✅ 散标保留 + §11.3 集中清单 |

行数：master 1161 → 基座 luna 1439 → 整合稿 1593。
