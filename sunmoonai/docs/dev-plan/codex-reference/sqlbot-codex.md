# SQLBot 源码评估与 Investment 采用建议

> 研究基线：`/home/zymun/repo/SQLBot` @ `59ca0970`，2026-08-28

## 结论

SQLBot 是完整的 ChatBI 产品，不是可直接嵌入的轻量 Text-to-SQL 库。它把工作空间、数据源选择、schema/sample/RAG、术语与训练样例、SQL 生成/纠错、行权限注入、执行、图表、分析、预测和持久化串在同一业务链中。

对 Investment 最有价值的是产品流程和数据治理做法；最不适合的是直接复制其 `LLMService` 或在 Investment 进程内依赖整套 backend。除技术耦合外，仓库采用带额外品牌限制的 GPLv3 变体，源码复用或衍生分发必须先做许可证决策。

## 1. 实际问数链

从 `apps/chat/task/llm.py` 可还原：

```text
用户问题
  → 校验 chat / workspace / datasource
  → 选择 datasource（可动态）
  → schema、sample data、embedding、术语、训练样例、历史轮次
  → LLM 生成 SQL
  → sqlglot 提取真实表（不信 AI 声明的 tables）
  → 表权限与 row filters
  → 执行 SQL
  → 保存 SQL、数据和日志
  → 生成 chart / analysis / predict / recommended questions
```

`LLMService.__init__` 会校验 chat 所属 workspace 和 datasource 所属 workspace，并加载模型、历史错误和日志（`llm.py:122-210`）。它随后通过多个同类方法完成 schema 选择、SQL、filter、chart、analysis、predict 等阶段（同文件 `446-1200`）。这是一套状态丰富的 application service，而非纯函数。

## 2. 值得吸收的设计

### 不信任模型返回的表名

`extract_tables_from_sql` 用 sqlglot 解析 AST，排除 CTE alias，再取得真实表引用（`llm.py:71-89`）；运行链在权限检查前重新解析真实 SQL。这个原则必须保留：权限对象来自 parser/semantic planner，不来自 LLM 的附带 JSON。

### 运营上下文进入生成链

术语、custom prompt、data training、历史成功 SQL 和上次执行错误都成为生成/修复上下文。这比只塞 DDL 更接近企业问数。Investment 可以把这些对象抽象为版本化的 `QueryContextSnapshot`，由证据/配置版本追踪，而非散落在 prompt 拼接中。

### workspace 与行权限

chat、datasource、assistant 都绑定 workspace；系统也会在执行前取得 row permission filters。但当前 `build_table_filter()` 把原 SQL 和 filters 交给 LLM 重新生成 SQL，再做 JSON 解析和保存（`llm.py:898-962, 1078-1084`），这不是可证明等价的机械权限改写。它可以作为产品流程参考，不能成为 Investment 的授权边界；Investment 应使用 AST/semantic planner 或数据库 RLS 注入谓词，并配合每 tenant/role 的只读 DB identity。

### 生成后的多产品投影

同一 SQL 结果继续产出表、图表、分析和预测。Investment 可借鉴“查询结果是 artifact，图表/报告是独立 projection”，不要让 LLM 一次返回混杂 SQL、图表配置和自然语言的大 JSON。

## 3. 不应直接移植的部分

### 巨型有状态 Service

`LLMService` 同时持有 DB session、用户、assistant、datasource、LLM、消息历史、日志、future 和各种产品步骤；单文件超过 1700 行。失败恢复、阶段重试、预算和独立测试都受限。Investment 已有 ports/adapters 与 Run/Attempt，不应退回这种聚合方式。

### 线程池并发模型

模块级 `ThreadPoolExecutor(max_workers=200)` 与 scoped sync DB session 共同存在（`llm.py:61-66`）。在多租户 Agent runtime 内直接复用容易造成连接池、线程、取消和 context propagation 问题。应让 Celery/worker 管执行并发，每个 Invocation 拥有清晰 lease 与 timeout。

### SQL 安全不能只靠字符串与 AST 检查

SQLBot 的 `exec_sql()` 会调用 `check_sql_read()`：限制首关键字、匹配危险模式、用 sqlglot 拒绝写操作 AST 和危险函数（`apps/db/db.py:761-767, 1070-1132`）。这是重要防线，但仍不是数据库安全边界。生产环境还需：

- 只读数据库账号和 transaction read-only；
- 单 statement 且仅允许 query AST；
- statement/lock timeout；
- row、byte、execution cost 上限；
- allowlisted schema/model；
- 禁止危险函数、外部文件/network extension；
- 审计保存 planned SQL、effective identity 与 policy version。

### MCP 表面不是标准 MCP server 的证据

`apps/mcp/mcp.py` 实际提供 `/mcp/access_token`、`mcp_start`、`mcp_question` 等 FastAPI JSON endpoint，并复用内部 chat API（`mcp.py:38-55, 90-197`）。仅凭目录名不能假设它实现了标准 MCP transport/tool negotiation。若集成，应按 HTTP API 适配并独立验证协议。

## 4. 许可证边界

根 `LICENSE` 表明：基础为 GPLv3，额外要求前端不得移除/修改 LOGO 与版权，并保留贡献代码可商用等条款。README 也明确二次开发需要遵守 GPLv3 开源义务和品牌限制。

因此：

- 复制 backend 源码进入 Investment 很可能形成衍生作品，不能仅当作普通 MIT/Apache 依赖处理。
- 独立部署后通过稳定 HTTP 调用是否满足隔离要求，属于法律判断，不由技术文档替代。
- 只借鉴通用思想并自行实现，仍需避免逐段翻译其受版权保护的具体实现。

本建议不是法律意见；投产前应由项目权利人/法务确认。

## 5. Investment 的建议采用方式

### 推荐：能力拆分后自行实现

```text
SemanticQueryTool
├── ContextProvider (MDL/schema/terms/examples)
├── SQLGenerator (LLM)
├── SQLPlanner/Policy (Wren + AST checks)
├── QueryExecutor (read-only identity + limits)
└── ResultProjector (table/chart/evidence/artifact)
```

每一步产生结构化 Invocation event 和版本化输入输出。生成失败可重试 generator；policy 拒绝不可通过重试绕过；执行失败可以把结构化错误反馈给 repair 节点；最终结果只以 artifact/evidence ref 进入 Agent state。

### 可选：SQLBot 独立服务试验

如果许可证审查允许，可在隔离环境中把 SQLBot 当外部 ChatBI 服务做只读 PoC：

- 单独数据库、身份和网络策略；
- 不共享 Investment session token；
- 通过 service identity + delegated actor 映射 workspace；
- 返回 SQL、列 schema、有限 rows 和审计 ID，不直接返回可信投资结论；
- Investment 再将其结果包装为 evidence/artifact。

不建议把 SQLBot MCP endpoint 暴露给通用 Agent 后直接执行任意 datasource 查询。

## 6. PoC 验收矩阵

| 维度 | 验收条件 |
| --- | --- |
| 正确性 | schema linking、join、metric、时间口径均有 golden NL→SQL 用例 |
| 权限 | 跨 workspace、越表、越行、CTE/子查询绕过全部失败 |
| 安全 | DDL/DML、多语句、危险函数、超时、超行数全部阻断 |
| 恢复 | LLM/DB 超时能区分并有限重试，不重复写 memory/event |
| 审计 | 保存问题、context version、generated/planned SQL、identity、policy、结果摘要 |
| 许可证 | 源码、镜像、网络服务三种采用方式均有书面结论 |

## 源码索引

- 主问数链：[llm.py](/home/zymun/repo/SQLBot/backend/apps/chat/task/llm.py:71)
- prompt 模板入口：[template.py](/home/zymun/repo/SQLBot/backend/apps/template/template.py:1)
- 行权限：[permission.py](/home/zymun/repo/SQLBot/backend/apps/datasource/crud/permission.py:1)
- 数据库执行：[db.py](/home/zymun/repo/SQLBot/backend/apps/db/db.py:1)
- HTTP “MCP” 表面：[mcp.py](/home/zymun/repo/SQLBot/backend/apps/mcp/mcp.py:38)
- 许可证：[LICENSE](/home/zymun/repo/SQLBot/LICENSE:1)
