# ADR-003：Info -> Knowledge 不可变 Artifact Contract

状态：ACCEPTED  
日期：2026-07-11  
接受日期：2026-07-12  
决策者：项目负责人、Info/Knowledge owner、架构评审

## 1. 背景

现有 Info distribution 发送 `info-artifact:{database-id}`，Knowledge 无法在不反查 Info 数据库/API 的前提下读取内容。Knowledge 的试验 resolver 虽支持 HTTP、data URI、inline metadata 和 S3，但字段均可选，且没有 bucket/key allowlist、对象版本、下载大小、content type、SHA-256 校验。RAGFlow 未配置时还会返回 mock ingestion success。

这既不是闭合契约，也不能证明不可变 artifact 已被目标服务读取。

## 2. 决策

1. Knowledge 作为 ingestion Provider，机器契约唯一真相源为 `knowledge-app/contracts/artifact/v1/info-knowledge-artifact.schema.json`。
2. v1 每次 `upsert` 只携带一个首选派生 artifact：`clean_markdown` 优先，缺失时使用 `text_plain`。
3. Artifact 必须同时携带 `s3://bucket/key`、S3 `storage_version`、SHA-256、size 和 content type。Info 数据库 UUID 只承担 lineage，不能用于内容解析。
4. Info 只有在对象存储返回非空、非 `null` 的版本 ID 后才能创建 distribution；本地文件 fallback 和未版本化 S3 对象返回冲突，不得降级成 `info-artifact:`。
5. Knowledge 使用独立只读对象存储身份；development 只允许 `development-info-originals/info/original/`，生产由显式环境配置提供 allowlist。
6. Knowledge 先用带 `versionId` 的 HEAD 验证版本、Content-Length 和 media type，再流式 GET；超过声明值/平台上限立即中止，读取完成后以 constant-time comparison 校验 SHA-256。
7. v1 拒绝 HTTP(S)、signed URL、data URI、inline content、任意 bucket/key、缺失 storage version 和额外请求字段。需要其他 transport 时新增明确版本/ADR，不扩宽 v1。
8. RAGFlow 未配置时只把真实读取校验结果记为 `artifact_verified`，不产生假的 Knowledge/RAGFlow document ID，不使用 `succeeded` 冒充摄取完成。
9. `distribution_id` 同时是 operation/correlation ID；`causation_id` 指向 Info DocumentVersion；幂等键固定包含 contract major、source version 和 dataset key。
10. P0-003 只开放 `upsert`。`deactivate/delete/reindex` 在 Knowledge domain identity 落地后以兼容扩展或新 major 引入。

## 3. 错误语义

- Info `409`：没有可分发的 clean/text artifact、对象未版本化、lineage/状态/大小/hash/content type 不满足契约。
- Knowledge request `422`：schema、URI、版本、dataset 或额外字段不合法。
- Knowledge `artifact_unreadable`：身份未配置、bucket/prefix 越界、对象缺失、版本/size/type/hash 不一致或读取超限。
- RAGFlow 故障仍使用独立 `ragflow_*`/`external_api_error`，不能覆盖 artifact 完整性错误。

错误和日志可包含 distribution/source version/correlation ID 与非敏感分类，不记录 credential、signed header 或正文。

## 4. 兼容与迁移

旧接口是未接流量的原型，没有生产兼容承诺；Provider 在 v1 启用后 fail-closed 拒绝旧 `source_artifact_refs`/`info-artifact:` payload。Info 与 Knowledge consumer/provider tests 必须固定同一 schema digest。breaking change 新建 `artifact/v2` 并提供双版本窗口。

## 5. 回滚

回滚代码不会恢复旧伪契约。若真实 S3 链路故障，停止 distribution dispatch、保留 pending/failed record 和不可变对象，修复身份/配置后重试；禁止回退 inline/mock success。

## 6. 接受证据

KIND 中真实 Info DocumentVersion 的版本化 S3 artifact 已由 Knowledge 独立只读身份读取并完成 version、size、media type 和 SHA-256 校验；hash 篡改、对象缺失和无权限 bucket 分别以完整性错误、HTTP 404 和 HTTP 403 失败关闭。机器契约 digest、提交、测试和 operation ID 见 `docs/evidence/v5/V5-P0-003/result.md`。
