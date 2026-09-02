# SQLBot：能不能、该不该接进 investment-app

> 取证时点：2026-08-28 ｜ 作者：opus
> 源码：`/home/zym/repo/SQLBot` @ `59ca0970`（2026-08-22）

## 0. 它是什么

DataEase 出品的**基于 LLM + RAG 的 Text-to-SQL / ChatBI 系统**：
自然语言提问 → 生成 SQL → 执行 → 出数据与图表。

规模：backend 242 个 Python 文件，frontend 253 个 Vue/TS。
栈与我们高度接近：**FastAPI + SQLAlchemy + Alembic + `apps/` 分模块**。

```
backend/
├── apps/chat/          问答主链（api / curd / models / task）
├── apps/ai_model/      模型适配（含 openai/）
├── apps/datasource/    数据源管理
├── apps/db/            SQL 执行与安全校验 ← 关键
├── apps/mcp/           MCP 集成面
└── apps/data_training/ 训练/调优
```

## 1. 与 investment-app 的关系：它补的是我们没有的那一半

investment-app 现在的证据来源**只有一条**：knowledge 的 retrieval 契约，
而 knowledge 背后是 RAGFlow——**面向非结构化文本**。

投资研究显然还需要**结构化数据**（财务指标、行情、持仓）。
这一半 investment-app 目前完全没有：没有任何数据库查询类的工具或 Port。

```bash
cd investment-app/investment-backend/app
grep -rn "sql\|SQL\|query.*database" app/domain/agent/tools.py   # 无结果
```

SQLBot 恰好是这一半。所以问题不是"要不要 Text-to-SQL"，
而是"**自建还是接入**"。

## 2. 接入方式：MCP 是唯一该考虑的那条

SQLBot 提供三种集成（README 自述）：Web 嵌入、弹窗嵌入、**MCP 调用**。
前两种是给人用的 UI，与 agent 无关。**只有 MCP 面对我们有意义。**

`apps/mcp/mcp.py` 暴露的端点：

| 端点 | `operation_id` | 用途 |
| --- | --- | --- |
| `/access_token` | `access_token` | 取令牌 |
| `/mcp_start` | `mcp_start` | 起会话 |
| `/mcp_ws_list` | — | 列工作空间 |
| `/mcp_ds_list` | `mcp_datasource_list` | 列数据源 |
| `/mcp_model_list` | — | 列模型 |
| **`/mcp_question`** | `mcp_question` | **提问 → 出 SQL 与结果** |
| `/mcp_assistant` | — | 助手模式 |

即：**它可以作为一个外部工具被 agent 调用**，
形态与 investment-app 现在调 knowledge retrieval 是同一类（HTTP + 令牌）。

```bash
grep -nE "@router|operation_id" backend/apps/mcp/mcp.py | head -15
```

## 3. 它的安全边界够不够（这是接入与否的决定性问题）

**LLM 生成 SQL 然后执行**是本质上危险的动作。我逐层查了它的防护。

### 3.1 一个容易误读的地方

`apps/chat/task/llm.py` 的 `check_sql()` 名字像安全检查，**实际不是**——
它只校验"LLM 返回的是合法 JSON、`sql` 字段非空"。没有只读判断、没有 DML 拦截。

**光看这个函数会得出"SQLBot 不安全"的错误结论。**（我初读时就是这么以为的。）

### 3.2 真正的防护在 `apps/db/db.py`

`check_sql_read()` 是四层防护，相当完整：

```python
# 1. 首关键字白名单（可配置是否含元数据查询）
allowed_read_commands = {"SELECT", "WITH", "SHOW", "DESCRIBE", "DESC", "EXPLAIN"}
#    SQLBOT_ALLOW_METADATA_QUERIES=false 时收紧到 {"SELECT", "WITH"}

# 2. 写操作黑名单
denied_write_commands = {"INSERT","UPDATE","DELETE","CREATE","DROP","ALTER",
                         "TRUNCATE","MERGE","COPY","REPLACE","GRANT","REVOKE",
                         "USE","SET","CALL"}

# 3. 危险模式正则
for pattern in DANGEROUS_PATTERNS: ...

# 4. sqlglot 按数据库方言真实解析（不是字符串匹配）
statements = sqlglot.parse(sql, dialect=get_sqlglot_dialect(ds.type))
```

**第 4 层是关键**——用 `sqlglot` 按方言解析，能挡住靠字符串匹配绕不过的构造
（注释注入、多语句、方言特有语法）。这比只做正则的实现强一档。

```bash
sed -n '/def check_sql_read/,/statements = sqlglot.parse/p' backend/apps/db/db.py
```

### 3.3 但仍须自己加一层

**白名单在应用层，不在数据库层。**应用层的检查一旦有绕过（新方言、
`sqlglot` 解析歧义、配置被改成允许元数据查询），就没有第二道防线。

**接入时必须做的**：给 SQLBot 配的数据源用**只读数据库账号**。
这与本项目已有的纪律一致——`topics/data.md` §3 写的"数据库双角色：
运行态用户与迁移用户分离"，同一个思路再往下推一格。

## 4. 判定

| 问题 | 判定 |
| --- | --- |
| 能接吗 | **能**。MCP 面就是为此设计的，形态与现有 knowledge 调用同类 |
| 该接吗 | **该，但不是现在** |
| 自建还是接入 | **接入**。Text-to-SQL 的难点（方言适配、schema RAG、SQL 安全解析）它已经做完，自建是重复造轮子 |

**为什么不是现在**：接入 SQLBot 等于给 agent 增加一个**有成本、有副作用面**的外部工具。
按 [`investment-app-agent-architecture-opus.md`](investment-app-agent-architecture-opus.md) §7 的顺序，
`RunBudget` 未接线之前不应新增这类工具——
一个没有闸门的 agent 再加一个能跑数据库查询的出口，风险是叠乘的。

**正确顺序**：接线预算 → 证据账 → 再接 SQLBot。

## 5. 接入时的四条具体要求

1. **只读数据库账号**（§3.3）——不依赖它的应用层白名单作为唯一防线
2. **SQL 与结果都进证据账**——投资结论若引用了数据查询，必须能答"这个数字从哪来、哪天查的、哪个库"。这正是 investment-app 缺口二（证据账）的典型场景
3. **走契约锁**——若真接入，按本项目既有规矩：schema 真源在提供方，我们持锁文件 + 双端测试（`topics/contracts.md` §2）。**不要直接裸调它的 HTTP**
4. **计入预算**——每次 `mcp_question` 是一次 LLM 调用 + 一次数据库查询，两种成本都要记

## 6. 边界

| 边界 | 说明 |
| --- | --- |
| 未运行 SQLBot | 全部结论来自静态读码，未起服务、未实际调 MCP 端点 |
| 未评估其 RAG 质量 | Text-to-SQL 的准确率是选型的核心指标，本文完全没有评估——**这是最大的空白** |
| 只读了 backend 的关键路径 | 242 个 Python 文件里读了 mcp / chat/task/llm / db 三处 |
| 未核对版本演进 | 只看了 `59ca0970` 一个提交 |
| `DANGEROUS_PATTERNS` 的具体内容未读 | 只确认它存在并被调用 |
