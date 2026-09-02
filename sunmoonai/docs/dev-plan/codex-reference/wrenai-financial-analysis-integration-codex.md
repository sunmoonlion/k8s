# WrenAI × Investment：金融分析集成建议

> 研究基线：`/home/zymun/repo/WrenAI` @ `49a6e7f3`，2026-08-28

## 结论

当前主分支 WrenAI 的定位已经不是旧版 GenBI 应用，而是 Apache-2.0 的业务数据 context/semantic layer。它适合放在 Investment 的结构化数据工具层：用 MDL 管业务语义与访问规则，用 deterministic dry-plan 将语义 SQL 展开到物理 SQL，再通过受限 connector 查询。

它不应替代 Investment 的 Agent runtime、HITL、Run 状态机、知识检索或报告生成；也不应直接在多租户 Web 进程里按 README 的单机项目方式裸用。最稳妥路径是先做单数据域 sidecar/worker adapter，再补齐 tenant 隔离、async 并发、审计和版本发布。

## 1. 源码中的实际能力

### MDL 与 deterministic planning

`WrenEngine.dry_plan()` 先按目标 dialect 用 sqlglot 解析 SQL，提取引用模型，裁剪 manifest，再由 Wren core 展开模型/关系/计算字段，最后用 CTE rewriter 生成目标数据库 SQL（`core/wren/src/wren/engine.py:87-101, 163-216`）。

这使 LLM 写的是面向业务模型的 SQL，物理表、join 和 calculated field 由版本化 MDL 决定。对金融分析而言，净利润、区间收益、复权口径、交易日历等定义应进入 MDL/治理层，而不是每次让 prompt 重述。

### strict model boundary

`validate_sql_policy` 在 strict mode 下拒绝不属于 MDL 的表和 table-valued function，并支持 denied functions（`core/wren/src/wren/policy.py:15-120`）。这是良好的模型 allowlist，但默认 `WrenConfig.strict_mode` 是 `false`、denied functions 为空（`core/wren/src/wren/config.py:12-27`）；它也不是完整的 SQL 安全系统。Investment adapter 必须机械强制自己的 managed policy，不能依赖用户级 Wren 配置。

### Agent 工具契约

LangChain SDK 暴露：

- `wren_query`
- `wren_dry_plan`
- `wren_list_models`
- 可选的 `wren_fetch_context`
- `wren_recall_queries`
- `wren_store_query`

运行工具用统一 success/error envelope，错误携带 code、phase、message、脱敏并限长的 metadata（`sdk/wren-langchain/_envelope.py:1-18, 55-118`）。LLM-facing query 默认 100 行、硬上限 1000 行，避免在格式化前物化无界 rows（`_tools.py:26-76`）。

### Memory

本地 memory 用 LanceDB 保存 schema context 与已确认 NL→SQL 对。它能提供 few-shot recall，但 SDK 仅以 `.wren/memory/` 是否存在自动开启；index 操作会 drop/recreate schema table，README 明确警告不能与在线读取并发。这更像单项目本地索引，不是现成的多租户在线 memory service。

## 2. 与 Investment 的职责划分

| 能力 | Owner |
| --- | --- |
| Run/Attempt/Invocation、预算、checkpoint、resume | Investment |
| 用户/tenant/service identity 与 approval | Investment |
| 非结构化文档证据与 citation | Knowledge + Investment |
| 结构化业务模型、关系、指标定义 | Wren MDL（由 Investment 治理发布） |
| 语义 SQL 展开与 dialect transpile | Wren |
| 物理查询身份、timeout、审计、结果 artifact | Investment adapter |
| 最终金融观点、风险披露、报告综合 | Investment Agent graph |

Wren 返回的是查询事实，不是投资建议。结果必须带 query evidence：MDL version、planned SQL hash、datasource snapshot/as-of、row count、execution identity 和 audit ID。

## 3. 推荐适配器

```text
Investment SemanticQueryPort
  └── WrenSemanticQueryAdapter
      ├── resolve tenant/data-domain → immutable project release
      ├── fetch context / recall (read-only)
      ├── dry_plan
      ├── local policy checks
      ├── execute with read-only identity + timeout
      ├── redact/classify result
      └── store artifact + StructuredDataEvidence
```

接口建议：

```text
SemanticQueryRequest
  tenant_id, actor_id, run_id, question,
  domain_key, mdl_release, max_rows, as_of, purpose

SemanticQueryResult
  columns, artifact_ref, preview,
  mdl_release, planned_sql_hash, query_audit_id,
  datasource_as_of, warnings, evidence_refs
```

不要把 DB password、完整 planned SQL、无限 rows 或 Wren 内部对象写入 graph state。planned SQL 可进入受控审计库；模型上下文只拿必要摘要和 evidence ref。

## 4. 多租户与生产化缺口

### Project/profile 隔离

SDK `from_project()` 会从项目目录加载 `.env` 到进程全局环境且 `override=False`（`sdk/wren-langchain/_toolkit.py:156-218`）。同一进程加载多个 tenant 项目时，先进入环境的同名变量可能影响后续 profile 解析。README 也建议“一项目一 profile”。

生产建议：每个 immutable project release 在隔离 worker/sidecar 中运行，凭据由 Investment 注入 typed connection provider，不依赖全局 `.env`；tenant/domain → project release 映射由服务端控制，模型不能提交任意 filesystem path 或 profile name。

### 同步执行

LangChain SDK 当前工具是同步的，README 提示 async LangGraph 会借线程池桥接，约 32+ 并发可能耗尽默认 executor。Investment 不能在 FastAPI event loop 直接执行；先放到 Celery 专用 queue，并设置每 worker 连接数、并发和 statement timeout。

### Connector 与 query policy

即使 Wren strict mode 只允许 MDL model，仍必须：

- 数据库账号只读，最好数据库原生 RLS；
- 单语句 query allowlist；
- deny file/network/extension functions；
- max rows、max bytes、statement timeout、cost guard；
- 不允许 LLM 选择 connection info；
- planned SQL 与执行 SQL hash 一致性校验；
- Investment managed policy 强制 strict mode，Agent 无权关闭。

### Memory 写入

`wren_store_query` 的注释要求只在查询成功且结果有用后调用，但这只是模型指令，不是人工确认的机械保证（`_tools_memory.py:95-121`）。生产默认 `include_memory_write=False`；只有经过用户反馈/评审、脱敏和 tenant 校验的 pair 进入异步 curated pipeline。

## 5. 金融 MDL 建模建议

首个 PoC 只选一个稳定数据域，例如“上市公司季度财务”：

- models：company、security、fiscal_period、income_statement、balance_sheet、cashflow_statement；
- relationships：security→company、statements→company/period；
- measures：revenue、net_income、operating_cash_flow；
- calculated fields：YoY/QoQ、margin、TTM；
- mandatory dimensions：currency、accounting_standard、consolidation_scope、restatement_version、announcement_date；
- as-of 规则：任何回答必须区分 fiscal period 与市场可知日期，避免前视偏差。

MDL release 必须 Git/versioned build，CI 用 golden queries 比较 expanded SQL 与结果口径。数据修订不能静默覆盖历史 evidence；query result 记录 release 与 datasource snapshot。

## 6. 分阶段落地

### Phase 0：离线验证

- 固定 DuckDB/Postgres 只读快照；
- 20–50 条金融 golden NL→semantic SQL；
- strict mode + denied functions；
- 比较 planned SQL、结果和 as-of 正确性。

### Phase 1：单域 worker adapter

- Celery 独立 queue；
- memory read-only；
- 结果写 artifact store，返回 preview + evidence；
- 接入 Investment RunBudget 与 Invocation event。

### Phase 2：tenant-safe service

- immutable project releases；
- 秘密管理与 per-tenant DB identity；
- concurrency/backpressure；
- audit、metrics、timeout、circuit breaker。

### Phase 3：进入 Agent graph

- planner 先 fetch context/recall，再 dry-plan；
- policy 通过后 query；
- query evidence 与 Knowledge evidence 一起交给 synthesizer；
- HITL 只用于高成本查询、敏感数据或下游副作用，不让每个只读查询都阻塞。

## 7. Go/No-Go 条件

Go：golden correctness 达标；所有执行使用只读 identity；tenant 项目/凭据隔离；MDL 可版本发布和回滚；错误能稳定映射到 planning/policy/execution；结果带 as-of 与 evidence lineage。

No-Go：依赖进程全局 `.env` 服务多 tenant；Agent 可传任意 project path/profile；memory 在线 drop/reindex；strict mode 可由模型关闭；查询结果直接进入最终回答而无审计/evidence；把 Wren 当交易副作用执行器。

## 源码索引

- 引擎：[engine.py](/home/zymun/repo/WrenAI/core/wren/src/wren/engine.py:39)
- SQL policy：[policy.py](/home/zymun/repo/WrenAI/core/wren/src/wren/policy.py:15)
- policy 默认值：[config.py](/home/zymun/repo/WrenAI/core/wren/src/wren/config.py:12)
- CTE rewrite：[cte_rewriter.py](/home/zymun/repo/WrenAI/core/wren/src/wren/mdl/cte_rewriter.py:41)
- LangChain query tools：[_tools.py](/home/zymun/repo/WrenAI/sdk/wren-langchain/src/wren_langchain/_tools.py:26)
- Memory tools：[_tools_memory.py](/home/zymun/repo/WrenAI/sdk/wren-langchain/src/wren_langchain/_tools_memory.py:26)
- 错误 envelope：[_envelope.py](/home/zymun/repo/WrenAI/sdk/wren-langchain/src/wren_langchain/_envelope.py:1)
- Toolkit/project 加载：[_toolkit.py](/home/zymun/repo/WrenAI/sdk/wren-langchain/src/wren_langchain/_toolkit.py:156)
- Apache-2.0 许可证：[LICENSE](/home/zymun/repo/WrenAI/LICENSE:1)
