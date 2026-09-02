# SQLBot 源码评估与借鉴清单（qwen3.8 版）

> 最后更新：2026-08-22
>
> 性质：第三方开源项目源码评估（个人参考），非 baseline、非 REQ。
> 评估对象：dataease/SQLBot v1.10.0，本地源码 = `~/repo/SQLBot`
>（remote: github.com/dataease/SQLBot，2026-08-22 亲读）。
> 所有技术栈断言均出自本地源码 grep/read（REQ-002 纪律），行号锚点见正文。
> 结论先行：**机制可借，代码不可搬，路线不切换**——SQLBot 是"prompt 链 + RAG
> 校准"路线的 ChatBI 产品，与我们选定的"Wren 语义层受管 SQL"路线是竞争关系，
> 不改变 wrenai-qwen3.8 的路线决策。

---

## 1. 它是什么

DataEase 团队（FIT2CLOUD）开源的**基于大模型和 RAG 的智能问数系统（ChatBI）**：
对话式取数、出图、智能分析。四个卖点（README 原文）：开箱即用、安全可控
（工作空间级隔离 + 细粒度数据权限）、易于集成（Web 嵌入/弹窗/MCP/n8n/Dify/
MaxKB）、越问越准（自定义提示词 + 术语库 + SQL 示例校准）。

## 2. 技术栈（源码核实）

| 层 | 技术 | 锚点 |
| --- | --- | --- |
| 后端框架 | FastAPI + SQLModel + Alembic；Python 严格钉 `==3.11.*` | `backend/pyproject.toml` |
| 存储 | Postgres + pgvector + Redis | pyproject；`apps/ai_model/embedding.py` |
| LLM 层 | LangChain 0.3 系（langchain/langchain-core/langchain-openai/langchain-community）+ llama_index + sentence-transformers 本地 embedding | pyproject |
| 编排 | **无图引擎**：核心问数链 = `apps/chat/task/llm.py`（1978 行）的 prompt 消息链拼装。`langgraph>=0.3` 声明在依赖里但 apps/ 与 common/ **零使用**（grep 实测） | llm.py:791 `generate_sql`、:1006 `check_sql` |
| RAG 校准 | 三路注入 prompt：schema DDL + 术语库（terminology，llm.py:367）+ SQL 示例校准（data_training，llm.py:432） | llm.py:303-304,367-383,432-437 |
| SQL 校验 | `check_sql`（sqlparse/sqlglot 依赖） | llm.py:1006,1079,1331 |
| 图表 | **g2-ssr 独立 Node 服务**：@antv/g2 5.3 服务端渲染 + node-canvas + pm2，渲染成图片 | `g2-ssr/package.json`、llm.py:1770 `request_picture` |
| 数据源驱动 | MySQL/PG/Oracle/MSSQL/ClickHouse/Hive/达梦/ES/Redshift 等（驱动全家桶） | pyproject |
| 治理 | 工作空间隔离、细粒度数据权限、LDAP、审计中间件 | `apps/system/middleware/auth.py`、`common/audit/` |
| 前端 | Vue3 + TS + Vite | `frontend/package.json` |
| 部署 | Docker 单镜像 / docker-compose | `docker-compose.yaml` |

## 3. 问数链路的形状

```text
提问 → 检索注入（DDL + 术语库 + SQL 示例 few-shot）→ generate_sql
     → check_sql 校验 → 执行 → 结果 + g2-ssr 出图 → 流式回传
```

指标口径的治理全靠**提示词里塞什么**（DDL 注释、术语、示例），没有语义层；
会话历史取最近 N 轮（llm.py:1955，轮数可配）。"越问越准"= 运营把用户交互数据
沉淀成 data_training 示例与术语库，检索回注。

## 4. 与我们路线的对照（关键）

| 维度 | SQLBot | 我们（wrenai-qwen3.8 决策） |
| --- | --- | --- |
| 口径治理 | 提示词注入（DDL+术语+示例），无强制 | Wren MDL 语义层，dry_plan 预检强制 |
| 编排形态 | 1978 行单文件 prompt 链，无图无 checkpoint | LangGraph 静态图 + PostgresSaver |
| 学习闭环 | data_training 示例 + 术语库检索 | wren_store_query + AgentMemory |
| 依赖兼容 | langchain 0.3 / Python 3.11 钉死 | langgraph 1.2.8 / langchain_core 1.4.8（实测不兼容，代码移植物理不可行） |

判断：SQLBot 的路线在"通用 BI 问数"场景成立（部署简单、上手快），但财务域的
同指标多口径风险它只靠提示词软约束——这正是我们选语义层的原因。**路线不切换。**

## 5. 借鉴清单（四样，按价值排序）

1. **术语库（terminology）**：业务术语 → 标准口径的检索注入，是我们方案缺的一环。
   Wren MDL 管表/列/指标，但"ROE 用摊薄还是加权"这类**术语级口径**没有落点。
   落点建议：问数链增加独立术语检索源（P1 静态主链的取上下文节点内）。
2. **"越问越准"的轻量起步形态**：示例检索 few-shot 校准——P0 spike 阶段先用它
   提准确率，不必等 memory 全套上线（对照 wrenai-qwen3.8 的 20 题基线）。
3. **g2-ssr 模式**：图表服务端渲染成图片，IM 场景（企业微信发图）刚需。我们 25 课
   的 ChartSpec 配一个同款 SSR 渲染微服务即可（对照 P4 的 SSE/ChartSpec 上 Web）。
4. **fastapi-mcp 范式**：把问数能力暴露成 MCP 工具供其他 agent 调用——
   investment-app 作为平台能力输出时的现成做法（远期）。

## 6. 不借清单（两样）

1. **1978 行单文件 prompt 链编排**：无图、无 checkpoint、不可回归——正是
   architecture-qwen3.8 §7.6 说的"小号 Codex"反面形态。
2. **代码移植**：依赖栈代差（langchain 0.3 vs 我们的 1.x）+ Python 版本钉死，
   物理不兼容；只借机制设计，不抄实现。

## 7. 速查

```text
源码：~/repo/SQLBot（dataease/SQLBot v1.10.0）
关键锚点：backend/apps/chat/task/llm.py:791(generate_sql) :1006(check_sql)
         :1770(request_picture) │ backend/pyproject.toml（依赖全表）
         g2-ssr/package.json（@antv/g2 SSR）
关联文档：~/codex-reference/wrenai-financial-analysis-integration-qwen3.8.md（路线决策）
         ~/codex-reference/investment-app-agent-architecture-qwen3.8.md §7.6（成色分层）
```
