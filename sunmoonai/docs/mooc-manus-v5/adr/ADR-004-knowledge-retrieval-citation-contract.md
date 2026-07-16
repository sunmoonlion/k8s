# ADR-004：Knowledge Retrieval / Evidence / Citation Contract

状态：ACCEPTED
日期：2026-07-15（2026-07-16 接受）
任务：V5-P0-004

## 1. 问题

Research 目前没有可消费的 Knowledge Retrieval API。Knowledge 只有 Artifact
摄取接口，且既有成功路径把 `ragflow-dataset:{provider_dataset_id}` 写入
`knowledge_document_id`。这会把可替换 Provider 的内部 ID 错当成领域身份，导致
Provider 切换、重建索引、版本失效和 citation 回溯都无法保持稳定。

直接把 RAGFlow SDK 响应交给 Research 或浏览器还会造成三类耦合：

1. Research graph、tool 和 prompt 依赖 RAGFlow 字段与版本；
2. 浏览器得到任意 Provider metadata、内部对象 ID 或未经授权的来源 URL；
3. evidence 无法确定回溯到 Info `DocumentVersion`，引用只能证明“搜到了某个
   chunk”，不能证明来源版本。

## 2. 决策

### 2.1 契约治理

1. 机器契约唯一可编辑真相源是
   `knowledge-app/contracts/retrieval/v1/`。Knowledge 是 Provider，Research 是
   service consumer，Research Web 只消费 Citation projection。
2. v1 同时发布 request、provider response、browser-safe citation 三个 JSON
   Schema 和带 SHA-256 的 manifest。Research 固定 manifest digest，并在 CI 运行
   consumer-driven contract test；Provider 在 CI 验证 schema、example 和实现输出。
3. 请求 exact-fields；响应消费者必须容忍新增可选字段。删除字段、放宽身份边界、
   改变字段语义或暴露新的 Provider identity 必须新建 major 并提供双版本窗口。

### 2.2 领域身份与 Provider binding

1. `KnowledgeDocument` 以 `(source_app, source_document_id, dataset_key)` 唯一，
   拥有平台 UUID；`KnowledgeDocumentVersion` 以
   `(knowledge_document_id, source_document_version_id)` 唯一，拥有独立平台 UUID。
2. `KnowledgeDocumentVersion` 保存 Info lineage、content hash、来源元数据、索引状态
   和 Provider binding。RAGFlow dataset/document/chunk ID 只能存在于 Knowledge
   内部 binding，不能成为 Knowledge ID，也不能出现在公共 Citation DTO。
3. 摄取只有在 job 状态、Knowledge document/version 和 Provider binding 同一
   PostgreSQL transaction 持久化后才是 `succeeded`。Provider 已成功但事务未确认时
   允许凭既有幂等 identity 重试；不得留下无 lineage 的成功记录。
4. 旧行中的 `ragflow-dataset:*` 仅作为 migration 输入：迁移生成稳定领域 UUID，
   提取 Provider dataset binding 并保留原 `ragflow_document_id`。迁移后 API 只返回
   稳定领域 UUID。

### 2.3 Retrieval 请求与授权

1. Research 只提交稳定 `dataset_keys`、query、受限 source UUID filters、top_k、
   token_budget、request_id 和 delegated security context；不能提交 Provider dataset
   或 document ID。
2. Knowledge 先验证独立的 `Research worker -> Knowledge retrieval` 服务关系，
   再将 dataset key 与版本访问范围求交。payload 中的 security context 只用于授权
   输入和审计，不能替代服务 JWT、subject binding 或资源授权。
3. Retrieval 使用与 Info ingestion 不同的 Casdoor application/client、audience、
   subject allowlist 和本地关系 scope `knowledge:retrieve`。任一配置缺失均返回 503
   fail closed；撤销 ingestion credential 不影响 retrieval，反向亦然。
4. P0 静态 dataset allowlist 是显式配置，不接受通配符。未知/未授权 dataset 返回
   403，避免通过 404 枚举可见 dataset；没有已索引版本时返回成功空集合。

### 2.4 Provider 适配与 Evidence

1. Knowledge 的 RAGFlow adapter 使用已验证的 v0.25.4
   `POST /api/v1/retrieval`，只用数据库 binding 解析 dataset/document IDs。
2. Provider 返回的 chunk 必须能映射到状态为 `indexed` 的
   `KnowledgeDocumentVersion`；无法映射的 chunk 丢弃并记录去敏观测，不以原始
   Provider 结果补位。
3. `knowledge_document_id`、`knowledge_document_version_id` 是存储 UUID；
   `chunk_id` 与 `evidence_id` 使用版本化 namespace + Provider chunk/content fingerprint
   生成确定性 UUIDv5。相同索引结果重试时 identity 稳定，但不暴露原始 chunk ID。
4. Evidence 固定包含内容、score/rank、Info document/version、content hash、受控
   source URI、access scope 和 token estimate。`provider_metadata` 只允许 Provider
   名称与标准化 similarity 分量，不允许任意 dict、内部 ID 或 credential。
5. `token_budget` 在 Knowledge 边界强制执行。P0 使用保守的 Unicode code-point
   上界估算；超出时按 rank 截断最后一条 Evidence，并显式标记 item/response
   `truncated`。正式 tokenizer 可作为兼容实现升级，但不能放宽预算。

### 2.5 Citation 与浏览器边界

1. Research 从 Evidence 生成 Citation，citation 必须引用 `evidence_id` 并同时保留
   Knowledge document/version、chunk 和 Info document/version lineage。
2. 浏览器 Citation DTO 不包含 `source_uri`、Provider metadata 或 Provider ID；只提供
   限长 quote、title、content hash 和同源相对路径
   `/api/citations/{evidence_id}/source`。
3. 来源跳转由 Research BFF/API 按当前浏览器身份重新授权后 302/stream；不能把
   Retrieval 时的 service credential、delegated context 或任意外部 URL交给浏览器。
4. Evidence 存在不等于答案已验证。Research 必须在答案生成后执行 citation
   validation；无可用 Evidence 时明确降级，不伪造 citation。

## 3. 错误语义

- `401 unauthenticated`：无/无效 service bearer token。
- `403 forbidden`：service subject 未绑定、dataset/lineage 不在访问范围。
- `422 invalid_request`：schema、query、filter、top_k 或 budget 非法。
- `503 provider_unavailable`：身份 binding 或 Provider 配置缺失、Provider 不可达。
- `504 timeout`：Provider 超时。
- `502 retrieval_failed`：Provider 返回不可解析协议或检索失败。
- `409 contract_version_unsupported`：后续多版本入口中的不支持 major；v1 的 const
  校验在当前 FastAPI/Pydantic 边界表现为 422。

错误响应和日志可携带 request/retrieval/correlation ID 与去敏分类，不记录 query
正文、Evidence 正文、token、Provider credential 或任意完整 Provider response。

## 4. 拒绝方案

### 4.1 Research 直接调用 RAGFlow

拒绝。它绕过 Knowledge 数据所有权、lineage、版本失效、dataset 授权和 Provider
替换边界。

### 4.2 用 ingestion job 或 RAGFlow ID 作为 Knowledge identity

拒绝。job 是一次处理尝试，Provider ID 是可变 binding，二者都不能稳定表达领域
document/version。

### 4.3 把完整 Evidence 或 source URL 直接送给浏览器

拒绝。会泄露内部 Provider 结构、绕过当前用户授权，并把服务间 trust context 扩散
到不可信客户端。

### 4.4 P0 建通用搜索 DSL 或多 Provider federation

拒绝。v1 只支持受限 source UUID filters 和单一 Provider adapter；排序融合、复杂
metadata filters、多 Provider federation 在真实检索基线稳定后单独决策。

## 5. P0 接受条件

本 ADR 只有在以下证据全部存在后改为 `ACCEPTED`：

1. 三个 schema、examples、manifest digest 和 Provider/Research consumer tests 通过。
2. migration 创建并回填稳定 Knowledge document/version identity；测试证明 Provider
   ID 变化不改变领域 ID，source version 变化会产生新 version ID。
3. 真实 RAGFlow retrieval 通过 Knowledge API 返回可回溯 Info DocumentVersion 的
   Evidence；Research `KnowledgePort` 和 client model 中没有 `ragflow_*` 字段。
4. 未知 dataset、空结果、无权限 subject/dataset、Provider timeout、不可映射 chunk、
   token budget 截断均按本 ADR fail closed/降级。
5. 独立 retrieval client-credentials 允许矩阵和 issuer/audience/subject/signature 负向
   矩阵通过；ingestion/retrieval credential 可独立撤销。
6. Citation projection 通过 schema，能从 citation -> evidence -> Knowledge version ->
   Info source version 回溯，且浏览器 DTO 不含 raw source URI/Provider ID/metadata。
7. KIND 以候选镜像 digest 运行 provider/consumer compatibility matrix，清理恢复原
   Deployment 配置；证据归档到 `docs/evidence/v5/V5-P0-004/`。

## 6. 接受结果

2026-07-16 使用固定 Knowledge/Research r2 候选 digest 在 KIND 完成全矩阵：

1. 真实 RAGFlow/DashScope retrieval 返回一条可治理 Evidence；citation 能回溯
   Knowledge version 与 Info source version，且浏览器 DTO 只包含结构化安全字段。
2. 未知 dataset `403`、空结果、不可映射 chunk 丢弃、Provider timeout `504` 和
   token budget 截断均符合本 ADR。
3. 独立 retrieval 身份的有效控制、匿名、跨 ingestion/retrieval credential、过期、
   issuer、audience、subject、scope 和伪造签名矩阵全部通过；凭据和正文未输出。
4. RAGFlow KIND 出站通过默认关闭的显式 Helm egress proxy 配置恢复；Pod 自动代理
   连续探测 `10/10`。生产仍要求受治理 NAT/egress gateway/proxy，不继承开发者桌面
   代理。
5. 验证器发现并修正一次值级误判：合法 `title`/`quote` 可以包含“RAGFlow”字样；
   Provider 泄漏必须按字段结构检查，不能对来源正文做关键词封禁。
6. 验证结束后 Knowledge 临时 override 和 Provider double 均已清理，正式 timeout
   保持 Knowledge `15s`、Research `20s`。

最终证据：
`sunmoonai/docs/evidence/v5/V5-P0-004/result.md`。

## 7. 后续边界

P0-004 只建立真实最小 Retrieval/Citation 竖切及其治理。完整 Knowledge Admin 诊断、
deactivate/delete/reindex、正式 tokenizer/reranker、检索指标告警和 Research 答案质量
golden set 分别由 M1-405、M1-206、M1-503、M1-402/501 验收，不能在 P0 误报完成。
