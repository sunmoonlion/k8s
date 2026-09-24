# `0006-knowledge` 知识服务

> 内网；映射 `knowledge-app`（`info-app` 采集）。自有数据与用户资料，同一套检索，经 MCP 给沙箱里的 Codex。要装什么见 [数据与资料](../../PRD/knowledge.md)。

## 功能义务

| ID | 义务 |
| --- | --- |
| `F-KNOW-01` | MCP 服务端：检索、领域工具、口径表、SQL 执行（数据集内）；工具清单按 token 携带的专家包步骤过滤 |
| `F-KNOW-02` | 每个片段带来源、时点、数据版本；进证据账 |
| `F-KNOW-03` | 按用户 + 沙箱发 token，可吊销，限流；异常调用上报 |
| `F-KNOW-04` | 用户资料入库：网页上传或代理上送；按用户隔离；同一检索接口 |
| `F-KNOW-05` | 只返回所需字段与片段，不整批下发；必要时加水印 |
| `F-KNOW-06` | 自有数据只含事实与数据，不含观点（`F-POS-01`） |
| `F-KNOW-07` | 口径表随数据版本化；评测真值引用数据版本 |

## 最小实例

第 23 课零售经营库作为一个数据集装入；MCP 提供 `run_sql`、`describe_schema`、`metric_definitions`。

## 第一切口

A 股非金融三大表与附注：入库的三大表、附注表提取工具、勾稽规则集。数据盘点（`D2`）先于此。

## 部署

内网站点；浏览器不直连；沙箱经内网直连或边缘 `/mcp/` 隧道。

## 实现状态（2026-09-24，第四段）

已落在 `knowledge-app/knowledge-backend/app`：`application/services/dataset_query.py`（只读 SQLite 数据集：单条 SELECT/WITH、禁 ATTACH/PRAGMA、超时中断、200 行封顶，每个结果带 `citation{dataset_id,data_version,as_of,query_digest}`）；`interfaces/mcp/knowledge_mcp.py`（Streamable HTTP JSON-RPC：`initialize`/`tools/list`/`tools/call`/`ping`；Bearer 令牌表，按令牌过滤工具清单、每分钟限流、越权计数）；`bootstrap/mcp.py`（只挂 MCP 的最小应用，联调与评测用）；主路由同挂。三个工具 `describe_schema`、`metric_definitions`、`run_sql`；数据集 = 第 23 课库（`datasets/`，不进 git）。沙箱镜像入口按 `KNOWLEDGE_MCP_URL`/`KNOWLEDGE_MCP_TOKEN` 写 `[mcp_servers.sunmoon_knowledge]`（`bearer_token_env_var`）。Codex 0.155.1 实测能列出并调用（`k8s/sunmoonai/scripts/local-integration/workbench-dataquery.sh`）。15 测试。

未做：`F-KNOW-03` 令牌仍是静态表（随 `D10`）；`F-KNOW-04` 用户资料入库；检索与领域工具（第一切口）；异常调用上报只到日志与计数。

