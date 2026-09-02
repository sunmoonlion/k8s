# WrenAI × investment-app 财务分析系统：调研与总体设计笔记（kimi 版）

> 最后更新：2026-08-18
>
> 性质：调研笔记（个人参考），非 baseline、非 REQ；转实施时按
> `k8s/sunmoonai/docs/sunmoonai-architecture/` 的治理规则另立 REQ。
> 本文目的：固化已查证事实与论证结论，供后续系统讨论直接引用，避免重复查证。
> 姊妹文档：`~/codex-reference/codex-orchestration-assessment-kimi.md`（编排框架论证）、
> `~/codex-reference/sandbox-extension-advice-kimi.md`（沙箱机制选型）。

---

## 0. 一句话总体思路（用户原始构想）

investment-app 在现有框架（LangGraph + DDD + PostgresSaver + tpl-app 模板）基础上：

- **编排框架** = Codex 编排指南讨论的框架设计（见 codex-orchestration-assessment-kimi.md）；
- **具体能力** = WrenAI 的 wren-langchain SDK（NL→SQL 语义层），做财务管理分析系统；
- **代码参考** = 第 25 课综合智能体集成工程。

**总体判定：思路成立。** 三者角色互补不冲突：编排管"任务怎么拆验收口"，WrenAI 管
"结构化数据怎么问"，第 25 课管"结果怎么交付"。

---

## 1. 参考对象档案（已查证事实，勿重复查）

### 1.1 WrenAI repo（`/home/zymun/repo/WrenAI`）

**形态**：新一代 SDK-first 的 "Wren AI Core"（非经典版 wren-ai-service Haystack 架构）。
引擎是 pip 包 `wren-engine`（DuckDB 内置），CLI 准备项目，SDK 挂进 Agent 框架。

**目录结构**：

| 路径 | 内容 |
| --- | --- |
| `core/` | `wren`（CLI）、`wren-core`（Rust 核心）、`wren-core-py`、`wren-core-wasm`、`wren-mdl` |
| `sdk/wren-langchain` | LangChain/LangGraph 集成，**Apache-2.0**（pyproject 已核实，商用无碍） |
| `sdk/wren-pydantic` | Pydantic AI 集成，Apache-2.0 |
| `docs/core/sdk/` | `overview.md`（SDK 总览）、`langchain.md`、`wasm.md` |
| repo 根目录 | 有 LICENSE-AGPL-3.0 文件——对应其他组件，**SDK 本身是 Apache-2.0** |
| 用户自加文件 | `wren_research-guide.md`、`python装饰器描述符元类*.tsv/md`（此前学习痕迹） |

**wren-langchain 关键事实**（`sdk/wren-langchain/README.md`）：

- 依赖 `wren-engine>=0.5.0`；数据源 extras 透传：
  `pip install "wren-langchain[postgres,memory]"`；可选数据源：postgres、mysql、
  bigquery、snowflake、clickhouse、trino、mssql、databricks、redshift、spark、athena、
  oracle；DuckDB 内置无需 extra。`memory` extra 开启三个记忆工具。
- 前置：先用 CLI 准备项目——`wren context init` → `wren context build` →
  `wren memory index`（可选但建议）→ `wren profile add ...`。
- 入口：`WrenToolkit.from_project("./analytics_db")`。
- **6 个 LLM 工具**：运行时三件套 `wren_query`（执行 SQL 返回行）、`wren_dry_plan`
  （只规划不执行，验证 SQL 是否对准模型）、`wren_list_models`（列出模型与列描述）；
  记忆三件套 `wren_fetch_context`（检索相关 schema/业务上下文）、
  `wren_recall_queries`（召回相似历史 NL→SQL 对作 few-shot）、`wren_store_query`
  （固化已确认的 NL→SQL 对）。
- 直接 Python API：`toolkit.query()` → `pyarrow.Table`；`toolkit.dry_plan()` →
  目标方言 SQL 字符串；`toolkit.dry_run()`（仅校验）；`toolkit.memory.fetch/recall/store`。
- `toolkit.system_prompt()`：按启用工具自适应，且自动纳入项目的 `instructions.md`。
- 两个示例：`examples/langchain_demo.py`（`create_agent` 高层工厂）与
  **`examples/langgraph_demo.py`（用 `StateGraph`+`ToolNode`+条件边手搭 ReAct 循环——
  与 investment-app 运行时同生态，集成零翻译成本）**。

### 1.2 第 25 课（`/home/zymun/AI-Application-Development-Lessons/lessons/25_实战——综合智能体集成`）

**关键事实：全课无 WrenAI**（`rg -i wren` 零命中）。问数模块来自第 24 课（手搓
text-to-SQL），第 25 课本体是**交付层工程**。

**内容清单**：

| 内容 | 位置 | 价值 |
| --- | --- | --- |
| IM 统一入口分发 | `integrated_agent_service/app/im_router.py`、`service_backends.py` | 一个入口按服务注册表分发到搜索 Agent/问数适配器/文档 Agent/Codex ACP |
| SSE 流式交付（Web 与 IM 双客户端共享同一服务） | 讲义 §2、scripts v2 | 对应 investment-app 的 `event_sink`/`timeline_projector` 事件流外放 |
| `ChartSpec` 客户端无关图表契约 | scripts `v3_问数图表契约`、讲义 §2 | EvidenceBlock → ChartSpec（单位/系列/证据引用），Web 渲染 SVG——分析系统的正确抽象 |
| 参数化压测（并发/排队/背压） | scripts `v5_参数化压测与验收.demo`（`--requests/--client-concurrency/--workers/--queue-capacity/--worker-delay-ms`） | 方法学可照搬，实现不必搬 |
| Codex ACP 后端 | `app/codex_acp_backend.py` | 把本机 Codex 当后端接入的案例（备选参考） |
| 问数工作流本体 | `question_data/workflows/main_flow.py` + `chunks/execute_sql.py` | 手搓版 text-to-SQL——WrenAI 正是把这个产品化 |

**不要搬的部分**：`task_service`/自带简易队列（investment-app 已有 celery + outbox，
是更壮的等价物）；扁平 `app/` 单体的整体架构（教学工程，无 DDD 分层）。

**运行前提**：`DEEPSEEK_API_KEY`；企业微信链路需 `WECOM_BOT_ID/SECRET`；Codex 链路
需本机 Node.js、`npx` 与 Codex 登录态。

### 1.3 investment-app 现状（基线锚点，深读 2026-08-16/17）

| 能力 | 锚点（`investment-backend/app/` 下） | 状态 |
| --- | --- | --- |
| 幂等建 run | `app/application/agent/run_service.py:30` | 生产 |
| PostgresSaver 检查点 | `app/infrastructure/graph/checkpointer.py` | 生产 |
| 副作用记账 | `app/application/agent/side_effect_service.py` | 生产 |
| Redis 会话锁 | `app/application/agent/session_lock.py` | 生产 |
| 事件汇/时间线投影 | `app/application/agent/event_sink.py`、`timeline_projector.py` | 生产 |
| 生产链两条 | `app/tasks/agent_graph.py`（walking skeleton）、`app/tasks/pilot_agent_graph.py`（含 KnowledgeQuery/Citation） | celery worker 承载 |
| 工具权限 profile | `app/domain/agent/profiles.py:20,31,37`（`allowed_tools`/`denied_tools`，含 `model_key`） | 生产 |
| `RunBudget` 四维限额 | `app/domain/agent/runtime.py:62` | **休眠**（生产无调用方） |
| `AgentMemoryService` | `app/application/agent/memory_service.py` | **休眠**（仅测试） |
| `CancelRunCommand` | `app/domain/agent/commands.py` | **休眠** |
| `SandboxPort` | `app/domain/agent/sandbox.py:39`；唯一实现 `DeterministicFakeSandbox`（`infrastructure/agent/fake_sandbox.py:6`） | **休眠** |
| 知识检索契约锁 | `contracts/knowledge-retrieval-provider-lock.json`（v1 sha256） | 生产 |
| 内部 HTTP 接口 | `app/interfaces/http/internal/`（空 `__init__.py`） | 未接线 |
| 迁移链 | 5 个版本线性：agent_phase0 → auth_identity → agent_pilot → outbox_primitives → uuid_defaults | — |

---

## 2. 四个天然契合点（为什么思路成立）

1. **编排与能力是两层，互不打架**。Codex 指南那套（Supervisor + fan-out +
   Generator-Critic）管任务拆验收口；WrenAI 管结构化数据问数。Wren 的 6 个工具就是
   图节点手里的工具，编排设计（见 codex-orchestration-assessment-kimi.md）原封适用。
2. **WrenAI 填上 v5 架构的结构化数据缺口**。现有版图：info-app 管资讯、knowledge-app
   管非结构化检索，唯独没有"对财务数据库问数"的路径。不引入 WrenAI 就得手搓——
   第 24 课手搓的正是 WrenAI 产品化掉的同一个问题。
3. **`wren_dry_plan` 是白捡的 Critic**。财务数字必须对：生成 SQL → dry_plan 校验 →
   执行 → 结果合理性检查 → 作答，比我们原 Generator-Critic 设计还省一个评审节点。
4. **memory 三件套给休眠的 `AgentMemoryService` 第一个真实用例**。人工确认后
   `wren_store_query`，下次同类问题 `wren_recall_queries` 召回——记忆服务该有的
   第一种形态。

## 3. 五个必须想清楚的边界问题

1. **Wren 的"项目"模型 ≠ investment-app 的"run"模型**。WrenToolkit 挂在 CLI 准备的
   静态项目目录上（`wren_project.yml` + MDL 语义模型 + `.wren/memory/`）；run 是动态、
   按会话、有权限边界的。必须回答：一个数据源一个项目？项目目录在 k8s 放哪？
   MDL 变更走什么流程？建议：**MDL 语义模型按受治理资产管理**（地位等同
   knowledge-app 的数据集绑定），它是一种新契约面，建模质量直接决定答数质量。
2. **Wren 查询不走 DockerSandbox**（澄清非矛盾）。沙箱防"任意代码"；Wren 本身是
   SQL 治理层（语义层约束可访问模型、profile 控制数据源权限）。分工：问数走 Wren
   （受管路径 + 只读数据源凭据）；对结果做 pandas 二次加工等任意 Python 才进沙箱。
3. **第 25 课取模式、不取架构**。拿四样：ChartSpec 契约、SSE 交付模式、参数化压测
   方法学、IM 入口分发思路。不搬 task_service/队列与单体架构。
4. **先有静态主链，再谈 Supervisor fan-out**（"确定性下沉"原则）。问数主链（取上下文
   → 生成 SQL → dry_plan → 执行 → 出图 → 作答）写成 LangGraph 静态图；Supervisor 只在
   动态场景出场（如"分析这家公司"拆营收/成本/现金流多路并行）。
5. **按治理规则这是一个决策型 REQ**。新增运行时依赖（worker 镜像加 `wren-engine`）、
   新增受治理资产（MDL）、新增数据源连接（财务库凭据）——命中 AGENTS.md §1.1
   漂移尺子的"拓扑与组件""跨 App 契约"两条。是否立项由用户拍板。

## 4. 落地架构（在 investment-app 分层中的位置）

| 层 | 新增物 | 说明 |
| --- | --- | --- |
| infrastructure | `infrastructure/analytics/wren_toolkit_adapter.py` | WrenToolkit 包在 port 后（SandboxPort 同款手法）；测试配 FakeWren，生产注真 toolkit |
| infrastructure/graph | analytics 图 | 静态主链 + dry_plan critic 节点 + LangGraph `interrupt` 做新 SQL 模式人工审批（对应 v5 HITL） |
| application | Wren 项目治理服务 | 管理 CLI 项目目录、MDL 版本、profile 与数据源凭据挂载 |
| domain | 分析领域模型 | 复用 Run/RunAttempt/ToolExecution 实体；MDL 资产引用进 domain |
| 交付 | SSE + ChartSpec | run 事件经 SSE 推 Web（借 25 课 v2）；图表走 ChartSpec 式契约（借 v3） |

## 5. 分阶段路径

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| P0 spike | DuckDB 样例财务库 + CLI 备项目 + langgraph_demo 式 ReAct | **20 个金标准问题准确率**（过不去则先修语义建模/模型选型，不投编排层） |
| P1 | adapter + 静态主链进生产链 + Chart 产物 | 主链 E2E 通；FakeWren 单测齐 |
| P2 | Supervisor 多角度 fan-out + memory 存取 + SQL 人工审批 HITL | 多路并行正确汇合；确认对被记忆复用 |
| P3 | SSE/图表上 Web + 第 25 课方法压测 | 双客户端交付；背压参数化达标 |
| P4 | 生产加固（只读凭据、RunBudget 接线、出口收拢）——走 REQ | 评审通过 |

## 6. 闭环分析（"做完是否闭环"的五层答案）

| 环 | 内容 | 状态 |
| --- | --- | --- |
| L1 单次问数 | 提问 → 取上下文 → SQL → dry_plan → 执行 → 出图 → 交付 | **本波建设后合拢**（心脏） |
| L2 学习 | 对错反馈 → 人工确认 → store_query → 下次 recall 更准 | 设计已合，**缺反馈采集入口**（Web 对错按钮+纠错通道，小活但决定系统是否越用越聪明） |
| L3 数据供给 | 数据源（ERP/记账/行情）→ 入库 → MDL 建模 → freshness | **完全开口，最大缺口**。WrenAI 只查库不填库；info-app 采的是资讯不是结构化财务数据。**P0 spike 的前置** |
| L4 用户工作流 | 入口 → 工作台（提问/SSE/图表/审批/导出） | 半开：只有模板端面；25 课给模式，工程量实打实 |
| L5 主动服务 | 定时扫描 → 异常预警 → 主动推送（celery beat） | 未启动；锦上添花，非闭环必需，放最后 |

**优先级**：L3 现在就回答（无数据则无 spike）；L2 反馈按钮随 L4 工作台同做；
L5 最后。

## 7. 待决问题清单（后续系统讨论的议题）

1. L3：财务数据从哪来？第一个数据源选什么（自有记账？样例库？行情 API 落库？）
2. Wren 项目目录与 MDL 的存放与治理（k8s volume？git 管理 MDL？变更评审？）
3. 多租户/多数据源形态：一个 Wren 项目 per 数据源还是 per 租户？
4. 模型选型：问数用哪个 LLM（准确率 vs 成本）；profiles 的 `model_key` 按角色分配
5. 决策型 REQ 的立项范围（是否把 WrenAI 引入、MDL 治理、数据源连接打包成一次评审）
6. 记忆边界：`.wren/memory/` 与 `AgentMemoryService` 的职责划分（前者 NL→SQL 对，
   后者通用 agent 记忆——是否统一？）
7. 第 25 课 Codex ACP 后端是否纳入路线（把本机 Codex 作为一个 agent 后端）

## 8. 速查

```bash
# WrenAI SDK 事实
cat ~/repo/WrenAI/sdk/wren-langchain/README.md
sed -n 1,90p ~/repo/WrenAI/sdk/wren-langchain/examples/langgraph_demo.py
# 第 25 课交付模式
ls ~/AI-Application-Development-Lessons/lessons/25_实战——综合智能体集成/scripts/
# investment-app 休眠能力复核
cd ~/master/investment-app && rg -l "RunBudget|CancelRunCommand|AgentMemoryService|SandboxPort" investment-backend/app/app
# 相关文档
~/codex-reference/codex-orchestration-assessment-kimi.md   # 编排框架论证（含八拓扑落地矩阵、五条完善、P0-P3）
~/codex-reference/sandbox-extension-advice-kimi.md         # 沙箱机制选型（Docker 加固清单、gVisor 衔接）
~/master/k8s/sunmoonai/docs/sunmoonai-architecture/baseline/repos/investment-app.md  # 现状基线
```
