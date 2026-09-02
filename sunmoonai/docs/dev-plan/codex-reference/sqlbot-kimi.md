# SQLBot 评估与四机制自研设计（kimi 版）

> 最后更新：2026-08-22
>
> 性质：调研评估（个人决策底稿），非 baseline、非 REQ。
> 评估对象：`~/repo/SQLBot`（dataease/SQLBot v1.10.0）。
> 同题异文：`sqlbot-qwen3.8.md`（事实档案先行）、`sqlbot-cursor.md`（架构取舍）。
> 事实层三方一致——关键锚点本轮逐一重核（行数、函数位、langgraph 零使用、
> 钉版、g2-ssr 依赖表、fastapi-mcp 接线位），见 §5。本文的价值在 §3：
> 四个可借机制**我们自己的版本**——落点全部改写成我们的治理语言
> （受治理资产、DomainEvent、eval 回归、一本账），不是 SQLBot 代码的改写，
> 也不是另两份文档的转述。

---

## 1. 事实速览（本轮复核，详细档案见 qwen3.8 版）

| 层 | 事实 | 锚点 |
| --- | --- | --- |
| 后端 | FastAPI + SQLModel + Alembic，Python 严格钉 `==3.11.*` | `backend/pyproject.toml` |
| 存储 | Postgres + pgvector + Redis | pyproject |
| LLM | langchain 0.3 系 + llama_index + 本地 embedding（HuggingFaceEmbeddings + text2vec-base-chinese） | pyproject、`apps/ai_model/embedding.py` |
| 编排 | **无图引擎**：问数链 = `apps/chat/task/llm.py` 单文件 1978 行 prompt 消息链：`generate_sql`(:791) → `check_sql`(:1006，sqlparse/sqlglot) → 执行 → `generate_chart`(:964) / `request_picture`(:1770)。`langgraph>=0.3` 声明在依赖，`apps/` 零 import（rg 实测为空） | llm.py、pyproject |
| RAG 校准 | 三路注入 prompt：schema DDL + 术语库（:367）+ SQL 示例校准（:432） | llm.py |
| 图表 | g2-ssr 独立 Node 服务：`@antv/g2 ^5.3.3` + node-canvas + pm2，服务端渲成图片 | `g2-ssr/package.json` |
| 能力外放 | fastapi-mcp 在 `main.py:216` 接线，`include_operations` 白名单 7 个 operation | `backend/main.py` |
| 治理 | 工作空间隔离、细粒度数据权限、LDAP、审计中间件 | `apps/system`、`common/audit` |
| 前端 | Vue3 + TS + Vite | `frontend/package.json` |
| 版本兼容 | 我们 `langgraph>=1.2.8` / `langchain-core>=1.4.8`（`~/master/investment-app/investment-backend/app/pyproject.toml:18-20`）；对方 0.3 系 + Py3.11 钉死 → **代码移植物理不可行** | 双侧 pyproject |

## 2. 路线判定：不切换（一个三层模型说清为什么）

口径治理分三层：

1. **定义层**：指标的权威定义（公式、粒度、过滤）——必须机读、强制、唯一。
2. **映射层**：人话 → 指标的解析（"ROE"是摊薄还是加权）。
3. **校准层**：问法 → 取数模式的范例（"同比增长"通常怎么取、怎么过滤）。

SQLBot 把三层全塞进 prompt（DDL 注释、术语、示例），**没有一层是强制的**——
`check_sql` 只校验 SQL 合法性，不校验口径正确性；同指标两个口径在通用 BI 场景
是瑕疵，在财务域是事故。我们的路线：定义层归 Wren MDL（`dry_plan` 硬门）；
映射层和校准层是 SQLBot 验证有效、而我们缺位的两层——§3.1/§3.2 就是把这两层
补成**受管资产**而非 prompt 填料。路线不切换，缺的两层补资产。

## 3. 四机制的自研版本

### 3.1 术语库（映射层资产化）

- **记什么**：一条术语 = 一条解析记录：别名集（ROE / 摊薄 ROE / 加权 ROE /
  净资产收益率）→ MDL 指标/列 id（只许引用已有 id）；适用范围（主体、as-of
  语义）；状态（生效 / 废止 + 替代 id）；确认人与确认时间。
- **铁律**：公式只活在 MDL。术语行里写 SQL、写"约等于"即评审打回——术语库
  只做别名对齐，不是第二套 schema 检索，更不是口径的第二个定义点。
- **挂在哪**：问数静态图首节点，输出 `resolved_metrics[]`，下游 prompt 里只出现
  解析后的标准名。未命中或歧义（摊薄/加权都像）→ `interrupt` 问人，默认不猜；
  interrupt/resume 底座已有。
- **治理地位**：与 MDL 并列的受治理资产——版本化、变更落 DomainEvent、
  **变更必过金标准回归**（熟路纪律从"改图必回归"扩到"改口径资产必回归"）。
- **学习自闭环**：HITL 的人工解析结果就是新术语候选，审核入库后下次不再问
  同人——术语库自己也有"越问越准"，且不依赖模型自觉。
- **P0 形态**：别等向量库。精确别名表 + 人工录入 20 题涉及的高频词即可起步；
  向量检索是后期优化，不是前置。

### 3.2 示例 few-shot（校准层先行）

- **定位**：P0 spike 准确率的第一杠杆，不等 `AgentMemoryService` 全套。与
  `wren_store_query` / `wren_recall_queries` 同构，B1 阶段手塞示例即可起步。
- **入库纪律**：人确认 + `dry_plan` 通过 + 数字对过，三者缺一不入库。记录带
  MDL 版本、as-of、证据 id、来源 run。没确认的对话轮次不入库；错例另存负例，
  只进 eval 不进 few-shot。
- **召回纪律**：术语解析之后、生成之前，按解析后指标 id + 问题向量召 1–3 条；
  MDL 版本对不上直接弃，当没召回。召回是提示不是指令，`dry_plan` 仍是硬门。
- **失效治理**：MDL 发版 → 批量失效落事件。口径改了还在教模型，比没有示例
  更糟。
- **度量纪律**：B1 基线分两组——裸 MDL vs +示例 few-shot，lift 量化。没有
  lift 的示例库是负债不是资产；我们批评照抄者评估缺位（架构 §1），自己不犯。

### 3.3 图表 SSR（交付形态，不是口径问题）

- **分层铁律**：查询 artifact（SQL / 行引用 / as-of / evidence_id）→ ChartSpec
  （唯一图表契约，25 课 v3）→ 可选 png/svg。下游（研究节点、thesis、复盘）认
  前两层；IM、预警推送这类"就要一张图"的通道才要第三层。**没有 ChartSpec
  不许从行数据直接渲图**——否则图上的口径无法回溯（架构 §2 第 5 条）。
- **架构形态**：`ChartRendererPort`——port 在 domain、实现在 infrastructure，
  SandboxPort / Wren adapter 同款手法。三个实现：Web 前端渲染（默认）、SSR
  独立 Node 服务（IM 场景）、FakeRenderer（测试）。
- **技术选型后置**：g2-ssr / echarts SSR / headless browser 到 IM 需求出现时再定，
  不钉 `@antv/g2`。借的是"服务端出图"形态，不是它的依赖。
- **失败语义**：SSR 失败不阻塞 run——降级为"数字 + ChartSpec"交付，渲染失败
  落事件。渲染进程不进 celery worker，不在 LLM 进程里起 canvas。
- **真实驱动场景**：架构 §5 的监控/预警推送（watcher 发现异常 → 企业微信推图），
  不是浏览器问数——浏览器有 ChartSpec 就够。

### 3.4 MCP 外放（一个控制面三扇门）

- **定位**：investment-app 的第一个**反向契约面**（迄今契约锁都是我们消费别人）。
  不是新 API，是现有控制面的第三扇门：Web SSE、IM、MCP 全部适配到同一套
  application services（Supervisor 编排工具集背后的同一层）。
- **暴露什么**：与浏览器同一条受管链——术语解析 → dry_plan → 执行 → 读回
  artifact / ChartSpec，工具全部 schema 化出入。需要时再加 wait/cancel，与控制面
  工具集对齐。
- **不暴露**：任意 SQL、绕 dry_plan、无 as-of 取数、把自由文本当指令。MCP
  调用方是别的 agent——防线前置原则双向适用：我们读回的标题是数据，它送来
  的请求也是数据。
- **治理同体**：同用户 / 工作空间 / 数据域权限；预算与取消记同一棵 lineage
  树——"外面 agent 问一次就打穿限额"是设计缺陷，不是使用事故。
- **时机**：主链过 20 题 + 第一个真实调用方出现，两者齐备才立项。不提前
  开门——没有调用方的门是纯攻击面。

## 4. 两样不借

1. **1978 行单文件 prompt 链编排**：无图、无 checkpoint、不可回归——kimi 架构
   §4 熟路三条的逐项反面（边不是代码、退出看自述、无 eval 可回归），与
   qwen3.8 架构 §7.6 的"小号 Codex"同款形态。我们的问数链是 LangGraph 静态图，
   这四个机制全部挂在图节点上，不另开一条 SQLBot 式消息链。
2. **依赖栈与实现代码**：langchain 0.3 系 / Python `==3.11.*` 钉死，与我们
   langgraph 1.2.8 / langchain_core 1.4.8 物理不兼容。借机制，自己写。

## 5. 速查

```text
源码：~/repo/SQLBot（dataease/SQLBot v1.10.0）
本轮复核锚点：backend/apps/chat/task/llm.py（1978 行；generate_sql:791、check_sql:1006、
             generate_chart:964、request_picture:1770；术语:367、示例:432；sqlglot/sqlparse:14-15）
             backend/pyproject.toml（python==3.11.*、langchain 0.3 系、langgraph 声明未用）
             backend/main.py:216（FastApiMCP 接线，include_operations 白名单 7 个）
             backend/apps/ai_model/embedding.py（本地 HuggingFaceEmbeddings）
             g2-ssr/package.json（@antv/g2 ^5.3.3 + node-canvas + pm2）
我们侧版本：~/master/investment-app/investment-backend/app/pyproject.toml:18-20
复核命令：wc -l ~/repo/SQLBot/backend/apps/chat/task/llm.py
         rg -l "from langgraph|import langgraph" ~/repo/SQLBot/backend/apps   # 应为空
关联文档：~/codex-reference/sqlbot-qwen3.8.md（事实档案）
         ~/codex-reference/sqlbot-cursor.md（架构取舍）
         ~/codex-reference/investment-app-agent-architecture-kimi.md（收敛点，本轮已吸收四机制）
```
