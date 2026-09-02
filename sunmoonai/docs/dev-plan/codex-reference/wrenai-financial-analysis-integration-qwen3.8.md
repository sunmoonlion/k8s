# WrenAI × investment-app 财务分析系统：独立调研与设计笔记（qwen3.8 独立版）

> 最后更新：2026-08-19
>
> 性质：独立调研笔记（个人参考），非 baseline、非 REQ；转实施走
> `k8s/sunmoonai/docs/sunmoonai-architecture/requests/` 的 REQ 流程。
> 与 kimi 版 `~/wrenai-financial-analysis-integration-kimi.md`（2026-08-18）平行存在：
> 事实我今日独立复核，修正其一处课程编号错误，补充依赖兼容、制品治理、敏感数据面
> 三块它未覆盖的内容。后续系统讨论以两份对读为准。

---

## 0. 方法论与证据等级（延续我前两份独立版的做法）

| 层级 | 内容 | 状态 |
| --- | --- | --- |
| L1 亲自复核 | WrenAI repo、第 23/25 课、investment-app 锚点，全部今日 ls/grep/read 过 | 下文所有 file:line 均可复查 |
| L2 既有产物 | repo 内已有 `wren_research-guide.md`（此前系统性研究 WrenAI 的产物） | 可直接引用，避免重复探索 |
| L3 对读 | kimi 版笔记 | 结构合理；事实部分我逐条比对，发现一处错误（§1.5） |

## 1. 已查证事实（独立复核版）

### 1.1 WrenAI repo（`/home/zymun/repo/WrenAI`）真实形态

- **结构**：`core/`（wren 主包 + wren-core/wren-core-base/wren-core-py/wren-core-wasm/wren-mdl）、
  `sdk/`（**wren-langchain** 与 **wren-pydantic** 两个 SDK）、`docs/`、`skills/`。
- **CLI**：`core/wren/pyproject.toml` 注册入口 `wren = "wren.cli:app"`；测试面有
  `test_profile_cli.py / test_context_cli.py / test_cube_cli.py / test_cli_store_tip.py`，
  印证 CLI 负责 profile（数据源连接）、context（项目上下文构建）、memory store 三类准备动作。
- **数据源**：`core/wren/pyproject.toml` optional-dependencies 列出
  postgres / mysql / bigquery / snowflake / clickhouse / trino / mssql / databricks
  （均经 ibis-framework），DuckDB 为内置默认——**财务库是 Postgres 的话装
  `wren-engine[postgres]` 即可**。
- **SDK 事实**（`sdk/wren-langchain/pyproject.toml`，今日读原文）：
  - 版本 **0.2.0**，`Development Status :: 4 - Beta`（注意：尚未 1.0，API 可能动）；
  - license **Apache-2.0**（pyproject 与 LICENSE 文件双重确认，商用无碍；
    repo 根的 AGPL 文件是别的组件的，不传染 SDK）；
  - `requires-python >= 3.11`（investment-app venv 是 3.12，满足）；
  - 依赖 `wren-engine>=0.5.0`、`langchain>=1.0`、`langchain-core>=0.3`、
    `langgraph>=1.0`、`pydantic>=2`。
- **六个工具**（`src/wren_langchain/_tools.py` 与 `_tools_memory.py`，行号今日核对）：

  | 工具 | 锚点 | 用途 |
  | --- | --- | --- |
  | `wren_query(sql, limit=100)` | `_tools.py:45` | 执行 SQL（受语义层约束） |
  | `wren_dry_plan(sql)` | `_tools.py:82` | 只验证不执行——天然 Critic |
  | `wren_list_models()` | `_tools.py:105` | 列出语义模型 |
  | `wren_fetch_context(...)` | `_tools_memory.py:42` | 取项目上下文 |
  | `wren_recall_queries(question, limit=3)` | `_tools_memory.py:73` | 召回相似历史问法 |
  | `wren_store_query(...)` | `_tools_memory.py:96` | 存入已确认的 NL→SQL 对 |

- **入口**：`WrenToolkit.from_project(...)`（`_toolkit.py:156`）挂在 CLI 准备好的
  项目目录上；`examples/langgraph_demo.py` 手搭 StateGraph + ToolNode 的 ReAct 循环，
  注释明示可定制 Routing/State/Streaming/**Per-turn middleware（approval gates）**
  ——与 investment-app 的 LangGraph 运行时同一生态。
- **SDK 有 provider 扩展点**：`_providers/{mdl_source,memory,connection}.py`——
  MDL 来源、记忆后端、连接都可替换，这对后文 §4 的治理设计是关键事实。

### 1.2 第 25 课（`~/AI-Application-Development-Lessons/lessons/25_实战——综合智能体集成`）

- **WrenAI 零命中**：全目录 `grep -ril wren` 无结果，与 kimi 一致。
- 五个递进版本（`scripts/`）：v1 统一多服务路由 → v2 问数 SSE 双客户端 →
  v3 问数图表契约 → v4 本地 Skills 文件回传 → v5 参数化压测与验收。
- 完整工程 `integrated_agent_service/`：含 `ARCHITECTURE.md`、`load_test.py`、
  IM 入口（`run_im_assistant.py`，企业微信链路）、Codex ACP 链路（README 要求
  本机 Node.js + Codex 登录态）。
- **取四样**：ChartSpec 图表契约（v3）、SSE 流式交付（v2）、参数化压测方法学（v5）、
  IM 统一入口分发思路（v1）。**不搬两样**：其自带简易队列/任务服务（你有
  celery + outbox，是更壮的等价物）、其扁平单体结构（与你的 DDD 分层不兼容）。

### 1.3 investment-app 相关锚点（今日复核）

| 事实 | 锚点 |
| --- | --- |
| 记忆域已就位 | `domain/agent/memory.py:29` `AgentMemory`、`:56` `WindowMemoryPolicy`；`application/agent/memory_service.py:14` `AgentMemoryService` |
| SandboxPort 休眠、生产零调用 | `domain/agent/sandbox.py:39`（详见 `~/sandbox-extension-advice-qwen3.8.md` §1） |
| RunBudget / CancelRunCommand 休眠 | `runtime.py:62` / `commands.py:31` |
| 事件溯源底座 | `application/agent/event_sink.py` + `timeline_projector.py` |
| 结构化问数能力 | **无**——info-app 管资讯、knowledge-app 管非结构化检索，对财务库问数是版图空缺 |

### 1.4 依赖兼容性实测（kimi 未查，我今日跑 venv 补上）

investment-app venv（python 3.12）现状：`langgraph 1.2.8`、`langchain_core 1.4.8`、
`langgraph_checkpoint_postgres 3.1.0` 在装；**未检出 `langchain` 主包**。
SDK 声明依赖 `langchain>=1.0`（因 `langchain.agents.create_agent` 高层工厂）。
**但**：走 `langgraph_demo.py` 那条路（StateGraph + ToolNode 手搭循环）只需
langgraph + langchain-core，两者已就位——**P0 spike 建议走 langgraph 原语路线，
先不引入 langchain 主包**，少一个依赖面；等确需 create_agent 高层工厂再评估。

### 1.5 对 kimi 版的事实修正（一处）

kimi 说"问数模块是第 24 课手搓的 text-to-SQL"。**实际是第 23 课**：第 24 课文档
开头自述"第23课完成了真实 SQL 问数项目：问题经过改写与拆解，模型生成 SQL，宿主
校验并执行 SQL，结果整理成 EvidenceBlock……"。第 24 课本体是 Eval 与上线门禁。
这不影响 kimi 的论证（反而强化：第 24 课的 eval 方法学正好是 P0 spike 的验收工具，
见 §5），但课程编号要改对。

---

## 2. 总体判定（我的版本）

**思路成立，且我同意 kimi 的四个契合点**（编排与能力两层不打架、Wren 填结构化
数据缺口、dry_plan 白捡 Critic、memory 三件套给记忆服务首个真实用例）——这四条
我逐条核对过 SDK 源码，均站得住。

在 kimi 的结论之上，我强调三点判断：

**一、这套组合的本质是"三层分工"，讨论时按层归位才不会乱：**

```
编排层   Codex 指南式框架（Supervisor/fan-out/Generator-Critic）
          —— 管"任务怎么拆、怎么验、怎么收口"；对问数主链它是 P2 的事，不是 P0
能力层   wren-langchain 六工具 —— 管"结构化数据怎么问"
交付层   第 25 课四样模式（ChartSpec/SSE/压测/入口分发）—— 管"结果怎么给人"
```

问数主链（取上下文→生成 SQL→dry_plan→执行→出图→作答）是**固定流程**，按
`~/codex-orchestration-assessment-qwen3.8.md` §2.3 的决策权三分法，它属于第 1 档
（静态图），写成 LangGraph 静态图即可；Supervisor 只在"分析一家公司"这类真正
需要动态拆解的场景出场（P2+）。**先有一条问得准的静态流水线，再谈编排。**

**二、Wren 查询与 DockerSandbox 的分工是澄清不是矛盾**（沿用 kimi 判断并给准则）：
沙箱防的是"任意代码"；Wren 本身就是 SQL 的治理层（语义层约束可访问模型、
只读凭据）。准则一句话：**走 SQL 的进 Wren 受管路径，跑任意 Python 的（如查询
结果的 pandas 二次加工）才进沙箱。** 两条路径各管各的威胁模型，永不合并。

**三、eval 门禁先于架构投入**：第 24 课的方法学（eval_cases + 上线门禁报告，
仓内就有 `eval_cases/` 与 `reports/business_eval_v1_report.md` 范例）应该直接
搬进 P0：20 个金标准财务问题做准确率基线。**问不准，后面的编排、图表、记忆全是
空中楼阁**——这是所有后续投入的总闸门。

---

## 3. 边界问题（kimi 五问全收，我加三问）

kimi 已列：① Wren"项目"与 run 粒度不匹配（MDL 是受治理资产）；② Wren 查询不走
沙箱；③ 第 25 课取模式不取架构；④ 先静态流水线后 Supervisor；⑤ 这是决策型 REQ
（新运行时依赖 + 新受治理资产 + 新数据源连接）。均成立。我追加：

**⑥ 项目制品怎么进 k8s（kimi 问了"放哪"，我给出决策框架）**：Wren 项目目录
（`wren_project.yml` + MDL + `.wren/` 记忆与索引）是部署制品，三个候选：

| 方案 | 利 | 弊 | 判定 |
| --- | --- | --- | --- |
| 打进 worker 镜像 | 对齐 release.json 不可变 digest 纪律（baseline §3.2），发布即冻结 | MDL 改一次要发一次版 | **MDL 语义模型选这个**——它是契约面，该走发布纪律 |
| ConfigMap | 热更 | 1MB 上限、变更无审计、与不可变纪律相悖 | 否决 |
| PVC | 记忆索引可写可持久 | 多副本一致性、版本失控 | **只给 memory 索引用**（见 ⑦） |

**⑦ Wren memory 是新的敏感数据面**：`.wren/memory` 存的是 NL→SQL 对——财务
查询模式本身就是敏感信息（暴露你在关注什么财务问题）。两个决策：a) 利用 SDK 的
`_providers/memory.py` 扩展点，把记忆后端接到受治理存储而不是项目目录里的裸文件；
b) 明确 Wren memory 与 `AgentMemory`（`memory.py:29`，有 sensitive/ttl/scope 字段）
的关系——建议 Wren memory 只存"查询模式"（去标识化），凡带具体数值/主体的一律
按 AgentMemory 的 sensitive 纪律走，两者不混存。

**⑧ schema 演进是 L3 的另一半**：kimi 指出 L3 数据供给（数据从哪来）是最大开口；
我补上它的下游链路：**数据供给变化 → 财务库 schema 变 → MDL 必须跟着变**。
MDL 与库 schema 的一致性要有校验（哪怕 P1 先做成一个启动时断言：MDL 引用的
表/列在库里存在），否则答数会静默出错——这是"问得准"的持续性条件，不是一次性
建模就完事。

---

## 4. 落地形态（与 kimi 版对齐，补制品与凭据两条线）

- `infrastructure/analytics/wren_toolkit_adapter.py`：WrenToolkit 包在新 port 后面
  （SandboxPort 同款手法），测试用 FakeWren，生产注入真 toolkit；
- `infrastructure/graph/`：新增 analytics 静态主链图——fetch_context/recall →
  生成 SQL → **dry_plan critic 节点** → 新模式走 LangGraph interrupt 人工审批
  （v5 的 HITL 要求）→ wren_query 执行 → 结果合理性检查 → 作答；
- 交付：run 事件经既有 `event_sink`/`timeline_projector` 走 SSE 推 Web；图表用
  ChartSpec 式契约（借第 25 课 v3），前端渲染与数据解耦；
- **制品线（我的补充）**：MDL 进镜像 + digest 钉死；memory 索引挂 PVC；两者都
  不进 ConfigMap；
- **凭据线（沿用沙箱文档纪律）**：Wren profile 里的财务库凭据**只读、最小权限、
  单 scope**；凭据经现有 secret 管理进 worker，不落 MDL 文件、不进镜像。

## 5. 分阶段路径（我的版本，把 eval 门禁提到最前）

| 阶段 | 内容 | 完成判据 |
| --- | --- | --- |
| P0 spike | 选定第一个财务数据源（**L3 第一个必须先答的问题**）；DuckDB 或该库样例数据建 MDL（窄而精：营收/成本/利润核心表）；wren-langchain 走 langgraph 原语路线跑通问答；**借第 24 课 eval 方法建 20 个金标准问题基线** | 准确率过线（线由你在讨论中定）；过不去则回头查建模/模型，不进 P1 |
| P1 | adapter + 静态主链进生产链（含 dry_plan critic、interrupt 审批）；接线 RunBudget；MDL 进发布纪律 | 第一个真实用户在 Web 上完成一次问数 |
| P2 | memory 三件套接线 AgentMemoryService 纪律 + Web 反馈按钮（答对/答错→人工确认→store）；Supervisor 多角度 fan-out（营收/成本/现金流并行） | 记忆命中率可度量；fan-out 全落 DomainEvent |
| P3 | ChartSpec 上 Web 工作台 + SSE 进度面 + 第 25 课 v5 方法压测 | 压测报告给出并发/排队/背压三指标 |
| P4 | 决策型 REQ 过审（新依赖/新资产/新数据源三条都命中 AGENTS.md 漂移尺子），生产加固、gVisor 无关但沙箱通道若启用则按沙箱文档纪律 | REQ 闭环 |

注：P0 的"数据源选择"与 kimi 的 L3 判断一致——**它是整条链的起点，不回答连
spike 都没有数据可问**。

## 6. 闭环分析（我的复核与补充）

kimi 的 L1-L5 分层我复核后接受：L1 单次问数（本波合上）、L2 学习闭环（差反馈
按钮）、L3 数据供给（最大开口）、L4 用户工作台（半开）、L5 主动服务（先不追）。
我补两点：

- **L3 实际是两段**：上游"数据从哪个系统入库"（kimi 已指）+ 下游"schema 演进
  带动 MDL 演进"（我 §3-⑧）。讨论 L3 时两段都要过。
- **闭环顺序建议**：L3 数据源（现在答）→ L1 合拢（P0-P1）→ L4 工作台 + L2 按钮
  （一起做，按钮是工作台的一个部件）→ L5（最后，锦上添花）。

## 7. 待决问题清单（后续系统讨论逐个过）

1. **L3-上游**：第一个财务数据源是什么、在哪个库、谁负责入库与 freshness？
2. **L3-下游**：MDL 与库 schema 的一致性校验机制（P1 做断言还是持续 CI）？
3. **MDL 治理**：建模责任人、变更流程、进发布纪律的具体形式（镜像+digest 方案
   需你确认）？
4. **memory 边界**：Wren memory 存什么、AgentMemory 存什么、敏感分级谁裁决？
5. **eval 门禁线**：20 个金标准问题的准确率阈值定多少算过关？
6. **多租户形态**：一个 Wren 项目服务所有 session，还是按用户/数据集分项目？
   （影响 PVC 布局与权限模型）
7. **REQ 立项范围**：决策型 REQ 覆盖到哪一档——只含 P1，还是 P1+P2 一起立？
8. **Codex ACP 是否入路线**：第 25 课有 Codex ACP 后端，但你的平台走 LangGraph
   自建路线，建议明确排除，避免讨论时反复（我倾向排除）。
9. **langchain 主包取舍**：P0 走 langgraph 原语可避开；P1+ 若需 create_agent
   再评估引入。

## 8. 速查

```bash
# WrenAI SDK 事实
cat /home/zymun/repo/WrenAI/sdk/wren-langchain/pyproject.toml          # 版本/license/依赖
grep -n '@tool("wren_' /home/zymun/repo/WrenAI/sdk/wren-langchain/src/wren_langchain/_tools*.py
head -90 /home/zymun/repo/WrenAI/sdk/wren-langchain/examples/langgraph_demo.py
grep -A12 "optional-dependencies" /home/zymun/repo/WrenAI/core/wren/pyproject.toml  # 数据源清单

# 第 25 课交付模式（无 WrenAI：grep -ril wren 零命中）
ls "/home/zymun/AI-Application-Development-Lessons/lessons/25_实战——综合智能体集成/scripts/"

# 第 23 课手搓问数（kimi 误记为 24）、第 24 课 eval 方法学
ls /home/zymun/AI-Application-Development-Lessons/lessons/ | grep -E "^2[34]"

# investment-app 相关锚点
cd ~/master/investment-app/investment-backend/app
grep -n "class AgentMemory\|WindowMemoryPolicy" app/domain/agent/memory.py   # :29 / :56
grep -rn "SandboxPort" app/ | grep -v .venv                                  # 仍应零生产调用

# 既有研究产物（避免重复探索）
cat /home/zymun/repo/WrenAI/wren_research-guide.md

# 对读文件
ls -la ~/wrenai-financial-analysis-integration-kimi.md ~/wrenai-financial-analysis-integration-qwen3.8.md
ls -la ~/codex-orchestration-assessment*.md ~/sandbox-extension-advice*.md
```
