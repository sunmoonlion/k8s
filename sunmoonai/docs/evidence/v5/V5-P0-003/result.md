# V5-P0-003 Info-Knowledge Artifact Contract 执行证据

日期：2026-07-12  
状态：ACCEPTED

## 固定产物与提交

- Knowledge Provider 契约：`knowledge-app/contracts/artifact/v1/info-knowledge-artifact.schema.json`
- Contract major：`artifact/v1`
- Schema SHA-256：`a3219604ed3562c436336d4650c2a0fd08afd9a8829e1d17b12d6a929f499c81`
- Info consumer lock：`info-app/contracts/knowledge-provider-lock.json`
- Info App commit：`3c21fac`；Backend commit：`7682237`
- Knowledge App commit：`333e219`；Backend commit：`acc8f79`
- KIND 验证镜像：
  - `info-admin-backend:v5-p0-003`：`sha256:ce28c20d6ec034e28638b1425f6a1463137a9fe864ce97145828990edbe09407`
  - `knowledge-admin-backend:v5-p0-003`：`sha256:aaf5f40edc8342e060730f0ec7a2cd6ff0a01d0fa645626928e09bd2e58c5673`
- 可重复验证脚本：`sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_003_kind.py`

上述镜像仅用于 Phase 0 KIND 验证，未推送、未作为生产发布物。Backend 提交在镜像构建后只增加了 contract 示例测试及 lock registry 归一化，应用实现与依赖版本未变化；正式推广仍须从确定提交重新构建并生成发布 provenance。

## 实现结果

- Info 不再发送 `info-artifact:{database-id}`，而是从 DocumentVersion 选择 `clean_markdown`，缺失时选择 `text_plain`，并发送不可变 `s3://` URI、S3 version ID、SHA-256、字节数和 media type。
- 未版本化、本地 fallback、lineage 不一致、状态不可用、类型/大小/hash 不合法的 artifact 在 Info 侧以 `409` 失败关闭。
- Knowledge 的 v1 请求模型拒绝 legacy `source_artifact_refs`、HTTP/data/inline、signed query、路径穿越、额外字段和超过 50 MiB 的声明。
- Knowledge 只使用自己的 S3 身份；先以指定 `versionId` HEAD 校验版本、Content-Length 和 media type，再受限流式 GET，完成后 constant-time 比较 SHA-256。
- Development allowlist 固定为 `development-info-originals/info/original/`；应用 allowlist 与对象存储 IAM 双重约束。
- Knowledge S3 IAM 对 Info bucket 只有 `s3:GetObject`/`s3:GetObjectVersion`，没有写入、删除权限；Knowledge 自有 bucket 权限保持独立。
- Celery Worker 补齐对象存储 ConfigMap/Secret 注入；生成器要求两者同时存在，避免 API Pod 可读而实际 Worker 无凭据。
- RAGFlow 未启用时只记录 `artifact_verified`，不再伪造 Knowledge/RAGFlow ID 或 `succeeded`。
- Provider manifest 与 Info consumer lock 固定相同 schema digest；Info/Knowledge 测试分别承担 consumer/provider compatibility check。

## 自动化验证

```text
Info Backend:
uv run pytest -q
=> 38 passed
uv run pyright
=> 0 errors, 0 warnings, 0 informations

Knowledge Backend:
uv run pytest -q
=> 25 passed
uv run pyright
=> 0 errors, 0 warnings, 0 informations

git diff --check
=> PASS（Info、Knowledge、K8s）
```

自动化覆盖：schema 与发布示例合法性、consumer digest pin、legacy/unversioned 拒绝、bucket/prefix allowlist、version/size/media type/hash 校验、403/404 脱敏分类、响应体超过声明值、50 MiB 上限和 SigV4 version query。

K8s 生成验证：Knowledge ConfigMap 与 Celery Worker YAML 均通过 kubectl client dry-run；Worker 运行时检查只验证 S3 credential 非空及 allowlist 值，不输出任何 credential。

## 真实 KIND 闭环

验证脚本从 Info API 自动选择真实、可分发且已版本化的 DocumentVersion，不读取 Knowledge/Info 数据库，也不复制正文。脚本暂时令 Knowledge Worker 进入 artifact-only 模式，验证完成后已删除临时环境覆盖并完成 rollout。

```json
{
  "contract_version": 1,
  "distribution_id": "556308b5-d7f2-44a4-aab2-78ef994af749",
  "source_document_version_id": "ef23fdc1-eaa9-436d-a9c6-b7eb67ae0870",
  "dataset_key": "p0-artifact-smoke-1783814567-a79e3b75",
  "success": {
    "ingestion_id": "e1a97246-88b7-497e-b8d8-ef829f9310af",
    "status": "artifact_verified",
    "verified_size_bytes": 78
  },
  "database_callback_used": false
}
```

故障矩阵：

| 场景 | Ingestion ID | 结果 | 脱敏错误 |
|---|---|---|---|
| SHA-256 篡改 | `ef816638-bd3c-4c81-b673-2b5f2a0830e1` | `artifact_unreadable` | `S3 object sha256 mismatch` |
| 合法但不存在的 object/version | `da8ba918-679f-40e8-85c8-1b355cad531f` | `artifact_unreadable` | `S3 object request failed with HTTP 404` |
| allowlist 内、IAM 无权的真实 bucket | `6183562d-07f1-4db6-8b92-6bcbfe37c88c` | `artifact_unreadable` | `S3 object request failed with HTTP 403` |

首次故障脚本曾为 missing-object 构造非 UUID MinIO version ID，MinIO 正确返回格式错误 400。脚本随后改用合法但不存在的 UUID version ID，最终验证的是目标 404 语义；该修正不涉及应用实现。

## 回滚与边界

- 回滚只能停用新 distribution，不得恢复 `info-artifact:`、inline content 或 mock success；保留不可变对象及 pending/failed record，修复后按相同幂等键重试。
- 当前只发布 `upsert`；deactivate/delete/reindex 等生命周期动作待 Knowledge domain identity 落地后版本化增加。
- P0-003 证明 artifact transport 与完整性，不等同于 RAGFlow 摄取、Retrieval/Citation 或完整 Info→Knowledge→Research E2E；后两者分别由 P0-004 和 M1a 验收。
- 当前内部 API 身份仍待 P0-005；本次验证仅在本地 KIND 内部测试边界执行，不授权公网或真实用户流量。
- 当前 commit→enqueue 窗口、并发重复 dispatch 和 worker lease 不在 Artifact Contract 内伪装为已解决，统一进入 P0-006 可靠交付。
- 跨仓 contract artifact 已具备唯一真相源、版本、manifest、consumer lock 和可执行兼容测试；自动发布/下载该 artifact 的 Jenkins wiring 在 Gate P0 前完成，不允许各消费者复制并自行编辑 schema。
- 未执行任何 `git push`；由项目负责人按仓库流程统一推送。
