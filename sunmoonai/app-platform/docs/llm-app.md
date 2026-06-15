# LLM App 架构

## 1. 系统定位

`llm-app` 是 App Platform 的统一大模型与知识处理能力系统，为各领域 App 提供模型调用、Prompt、Agent、Embedding、语义检索和 RAG 能力。

它负责智能能力及其运行治理，不拥有资讯、投资组合、研究结论等其他领域主数据。

## 2. 职责边界

负责：

- 模型供应商、模型和能力目录。
- 统一推理接口、路由、限流和配额。
- Prompt、Agent、工具调用配置及版本。
- 推理任务、成本、延迟和质量记录。
- Embedding、知识库、检索和 RAG 编排。
- RAGFlow 等知识基础设施的适配和运行。
- 模型安全策略及评测。

不负责：

- 保存唯一资讯原文。
- 决定资讯的业务分类和权威事实。
- 保存投资观点和最终投资决策主档。
- 把模型输出直接升级为业务事实。

## 3. 核心模型

```text
Provider
Model
ModelCapability
CredentialReference
Prompt
PromptVersion
Agent
ToolBinding
InferenceRun
Evaluation
KnowledgeSpace
KnowledgeDocumentReference
RetrievalRun
RagflowBinding
UsageRecord
```

每次重要推理至少记录：

```text
model_id
model_version
prompt_version
parameters
input_reference
output
citations
token_usage
latency
created_at
```

敏感输入和输出根据数据分级决定是否保存全文。

## 4. 能力分层

```text
Domain Apps
  -> LLM Gateway
      -> Model Routing
      -> Prompt / Agent Runtime
      -> Knowledge Retrieval
          -> RAGFlow Adapter
      -> Provider Adapters
```

### LLM Gateway

向业务 App 提供稳定接口，隔离供应商 API、模型命名、认证和限流差异。

### Prompt And Agent Runtime

管理 Prompt 版本、Agent 流程、工具绑定和运行记录。Prompt 变更不覆盖历史版本。

### Knowledge Service

管理知识空间、文档引用、检索请求和结果引用。业务原文仍由其领域所有者保存。

### Provider And Product Adapters

隔离具体模型供应商及 RAGFlow API，避免业务 App 直接依赖私有协议。

## 5. 与 Info App 和 RAGFlow

```text
info-app
  -> llm-app knowledge API
      -> RAGFlow adapter
          -> RAGFlow
```

- `info-app` 拥有资讯、版本和原始文件。
- `llm-app` 拥有知识处理配置、运行记录和适配关系。
- RAGFlow 保存处理副本、分块和索引。
- `info-app` 保存业务分发状态，并能触发重建。
- RAGFlow 不应成为其他 App 的直接集成契约。

## 6. 对外能力

建议 API：

```text
POST /api/v1/inference/runs
GET  /api/v1/inference/runs/{run_id}
POST /api/v1/embeddings
POST /api/v1/knowledge-spaces/{id}/documents
POST /api/v1/knowledge-spaces/{id}/retrievals
POST /api/v1/knowledge-spaces/{id}/answers
GET  /api/v1/models
```

长耗时任务异步执行，立即返回 `run_id`。

建议事件：

```text
llm.inference.completed.v1
llm.inference.failed.v1
llm.knowledge-document.ready.v1
llm.knowledge-document.failed.v1
```

## 7. 模型治理

- 模型和 Prompt 使用不可变版本。
- 生产变更经过评测和审批。
- 记录成本、延迟、错误率和质量指标。
- 为不同数据等级设置允许使用的模型供应商。
- 支持内容过滤、提示注入防护和输出校验。
- 高影响投资结论必须有人审，不允许模型自行成为决策主体。
- 业务系统保存采用了哪个模型结果及其证据。

## 8. 可靠性与降级

- 模型不可用不能阻止领域主数据保存。
- 支持供应商超时、限流、熔断和可控回退。
- 推理请求使用幂等键，避免昂贵任务重复执行。
- RAGFlow 故障时保留待处理任务并可恢复。
- 知识库提供全量重建、增量同步和对账。
- 缓存只能优化调用，不能替代运行审计。

## 9. 当前部署与目标组件

当前组件：

```text
llm-app
├── llm-web-backend
├── llm-admin-backend
├── nodebullworker-llm-web-backend
├── celeryworker-llm-admin-backend
├── llm-web-frontend
├── llm-admin-frontend
├── ragflow
└── deploy-llm-app-all
```

RAGFlow 当前在 Kind 中启用，使用平台维护的固定版本镜像及 Helm 配置。

目标逻辑模块：

```text
model-catalog
llm-gateway
prompt-agent-registry
inference-runtime
knowledge-service
ragflow-adapter
evaluation
usage-governance
administration
```

这些模块初期可以落在现有后端和 Worker 中。

## 10. 分阶段建设

### 第一阶段

- 建立模型目录和统一调用接口。
- 建立 Prompt 版本和推理运行记录。
- 封装 RAGFlow Adapter。
- 打通 Info App 文档同步与状态查询。

### 第二阶段

- 模型路由、配额、成本和限流。
- 知识空间权限、对账和重建。
- Prompt/模型评测和发布流程。

### 第三阶段

- Agent 运行治理和工具安全。
- 多模型故障转移。
- 高级质量评测、审计和容量治理。

## 11. 验收标准

- 业务 App 不直接绑定模型供应商或 RAGFlow 私有 API。
- 每次关键推理可以定位模型、Prompt、输入版本和引用。
- RAGFlow 删除后可以从领域主档重建。
- 模型故障不导致资讯或投资主数据丢失。
- 成本、延迟、失败率和质量可以度量。
