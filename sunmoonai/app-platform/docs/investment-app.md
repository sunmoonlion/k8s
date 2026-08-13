# Investment App 架构

## 1. 系统定位

`investment-app` 是投资研究、组合管理、估值、风险和投资决策支持系统。

它是投资业务的核心应用，但不是其他 App 的总控系统。它通过稳定 API 和领域事件使用身份、资讯、模型和工具能力，并拥有投资领域自己的主数据。

当前阶段定位为决策支持系统。涉及真实资金交易、订单执行或面向客户的投资建议前，必须另行完成监管、合规、审批和运行风险评审。

## 2. 设计原则

- 从第一天固定领域边界，初期采用模块化单体。
- 证券、研究、组合、估值、风险和决策数据各有明确所有模块。
- 重要结论能够按历史时点重现。
- AI 只提供辅助能力，不能成为不可审计的事实来源。
- 客观资讯与主观研究观点分离。
- 计算结果必须保留输入、规则和版本。

## 3. 领域模块

```text
investment-app
├── security-master
├── research
├── portfolio
├── valuation
├── risk
├── decision
├── reporting
└── audit
```

### 3.1 Security Master

负责：

- 证券、公司、基金、指数和其他标的。
- 市场、交易所、币种和交易日历。
- 股票代码、ISIN 及外部标识映射。
- 行业分类和标的关系。
- 公司行动和主数据版本。

它是 Investment App 内其他模块引用标的的唯一入口。

### 3.2 Research

负责：

- 研究项目、假设、笔记和任务。
- 观点、评级、目标和置信度。
- 资讯、财务数据及模型结果的证据引用。
- 研究报告版本和协作。

研究记录引用 `info_id` 和 `info_version_id`，不复制 Info App 主档。

### 3.3 Portfolio

负责：

- 投资账户和组合。
- 持仓、现金和组合流水。
- 组合层级、基准和授权关系。
- 交易或外部成交导入后的组合状态。

持仓不能只保存当前数量，必须保存可重建流水或有效期版本。

### 3.4 Valuation

负责：

- 市场价格和汇率引用。
- 估值规则和估值批次。
- 市值、成本、收益和损益。
- 估值结果及输入快照。

市场数据来源可以位于未来独立数据服务中，但 Valuation 拥有投资业务采用的估值规则和结果。

### 3.5 Risk

负责：

- 风险暴露、集中度和流动性。
- 风险指标、限额和预警。
- 情景分析和压力测试。
- 风险结果的输入和模型版本。

### 3.6 Decision

负责：

- 投资建议和备选方案。
- 决策、审批、驳回和撤销。
- 决策依据、限制条件和有效期。
- 执行状态及与组合变化的关联。

决策状态变化使用明确状态机，不以普通字段任意覆盖。

### 3.7 Reporting

负责面向投资业务的报表定义和快照。报表不是主档，应能由领域数据重建；正式发布的报告版本需要保留。

### 3.8 Audit

负责汇集关键领域变更：

- 操作者和服务身份。
- 变更前后版本。
- 发生、记录和生效时间。
- 请求、审批、模型运行和证据引用。

## 4. 时间与可重现性

系统至少区分：

```text
business_date
effective_at
recorded_at
calculation_at
```

任何重要投资结论应能够回答：

```text
当时有哪些持仓？
使用了哪个价格、汇率和主数据版本？
引用了哪些资讯版本？
采用了什么模型、Prompt 和计算规则？
由谁审核和批准？
```

## 5. 与其他 App 的关系

### Auth App

提供用户、组织、服务身份和平台权限。Investment App 负责组合、研究和决策对象的资源级授权。

### Info App

提供客观资讯、原始证据和版本。Investment App 保存引用、使用目的、研究解释和决策关系。

### Knowledge App

提供知识检索、RAG、模型辅助处理和 AI 运行引用。Investment App 保存被采用结果的运行 ID、模型版本、Prompt 版本、引用和人工确认状态。

### Tools App

提供通用文件转换等工具。工具产物由 Investment App 判断是否成为研究附件或报告版本。

## 6. 核心数据关系

```text
Security
  <- ResearchSubject
  <- Position
  <- ValuationResult
  <- RiskExposure
  <- InvestmentDecision

Research
  -> EvidenceReference(info_id, info_version_id)
  -> AiRunReference(ai_run_id, knowledge_run_id)
  -> InvestmentDecision

Portfolio
  -> Position
  -> ValuationBatch
  -> RiskAssessment
  -> InvestmentDecision
```

## 7. API 与事件

建议 API 领域：

```text
/api/v1/securities
/api/v1/research
/api/v1/portfolios
/api/v1/valuations
/api/v1/risks
/api/v1/decisions
/api/v1/reports
```

建议事件：

```text
investment.security.changed.v1
investment.research.published.v1
investment.portfolio.position-changed.v1
investment.valuation.completed.v1
investment.risk.limit-breached.v1
investment.decision.approved.v1
```

初期模块位于同一进程时也应通过应用服务和内部领域事件协作，为未来拆分保留边界。

## 8. 计算与数据质量

- 金融金额使用定点数或高精度 Decimal，禁止二进制浮点直接计算。
- 数量、价格、汇率和金额明确精度与舍入规则。
- 每个计算批次保存规则版本和输入引用。
- 建立黄金样例、边界样例和对账测试。
- 外部数据进入系统时执行完整性、时效性和异常值校验。
- 修订数据不覆盖已发布结果，而是生成新版本并标记影响范围。

## 9. 当前正式部署

当前组件和运行角色：

```text
investment-app
├── investment-backend
│   ├── API
│   ├── Celery Worker
│   ├── Celery Scheduler
│   └── Alembic Migration Job
├── investment-admin-frontend
├── investment-web-frontend
├── deploy-investment-app-all
└── deploy-investment-<component>
```

Admin 与 Web 前端共享同一个 FastAPI Backend 和一个逻辑数据库。API、Worker、Scheduler 与
Migration 复用同一源码和镜像，但以独立 Kubernetes 工作负载运行，可分别部署、扩缩和恢复。
`deployment/` 是正式声明的唯一真相源；App 级入口负责整体验收和收敛，每个
`deploy-investment-<component>/` 入口负责独立组件操作。

领域模块继续位于统一后端内部，不立即拆为八个微服务。只有满足以下条件时才拆分：

- 需要独立发布或团队独立负责。
- 负载和扩缩容特征显著不同。
- 故障隔离或合规隔离有明确要求。
- 模块契约已经稳定。

## 10. 分阶段建设

### 第一阶段：研究基础

- Security Master 最小模型。
- Research、EvidenceReference 和研究版本。
- 接入 Info App 资讯引用。
- 接入 Knowledge App / AI 运行引用。
- 建立统一审计。

### 第二阶段：组合与估值

- 账户、组合、持仓和流水。
- 价格、汇率、估值批次和损益。
- 历史时点查询和对账。

### 第三阶段：风险与决策

- 风险指标、限额、预警和情景分析。
- 决策状态机、审批和证据链。
- 组合、估值、风险与决策闭环。

### 第四阶段：生产治理

- 数据质量、计算验证和正式报告。
- 职责分离、合规审计和恢复演练。
- 根据真实压力决定是否拆分服务。

## 11. 第一阶段验收标准

- 所有研究对象引用统一 Security ID。
- 研究结论引用确定的资讯版本，而非仅保存 URL。
- AI 辅助内容能够定位推理运行和引用。
- 研究版本不可被静默覆盖。
- 关键操作记录用户、时间和变更。
- 删除 RAGFlow 不影响研究证据主链。
