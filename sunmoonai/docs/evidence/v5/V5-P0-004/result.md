# V5-P0-004 Retrieval/Citation Contract 验收证据

- 日期：2026-07-16
- 状态：**ACCEPTED**
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-004-knowledge-retrieval-citation-contract.md`
- 历史诊断：`sunmoonai/docs/evidence/v5/V5-P0-004/partial.md`

## 1. 固定输入

- Knowledge 候选：
  `harbor.sunmoonai.com:30443/app-images/knowledge-admin-backend:p0-004-retrieval-r2-20260715`
  - 运行 digest：
    `sha256:13e31518585b2bda9091eedb503217e9e28064fe73e944c103fa5df5604e26eb`
- Research Worker 候选：
  `harbor.sunmoonai.com:30443/app-images/research-admin-backend:p0-004-retrieval-r2-20260715`
  - 运行 digest：
    `sha256:7a93cde873ca97b40d741c51bbac2158376120c2708a0e82ccee50622d869e5d`
- Knowledge migration head：`20260715_0003`
- 索引版本数：`1`
- 稳定领域身份检查：通过
- Retrieval contract major：`1`

权威 contract 继续由 `knowledge-app/contracts/retrieval/v1/` 管理，Research
consumer lock 与六个 schema/example digest 全部一致。候选镜像按 Pod 实际
`imageID@sha256` 核对，不以 tag 文本替代 digest 证据。

## 2. KIND 出站修复

原 RAGFlow Pod 直接访问 DashScope Fake-IP 时连续 TLS 探针仅 `2/10` 成功，真实
retrieval 在 Knowledge `15s` 和诊断 `90s` 下均 connect timeout。未通过增加应用重试、
放宽正式 timeout、mock Provider 或切换 embedding 模型绕过。

2026-07-16 完成以下环境修复：

1. FlClash 仅绑定 Windows WSL 私网网关 `192.168.32.1:7890`，不监听整个局域网；
   WSL TCP 探针通过，HTTPS CONNECT 返回 `200 Connection established`，DashScope
   TLS 请求返回预期无资源 `404`。
2. RAGFlow Helm Chart 新增默认关闭的 `ragflow.egressProxy`；仅在
   `CLUSTER=KIND` 且显式提供 `RAGFLOW_KIND_EGRESS_PROXY_URL` 时注入 upper/lower
   case `HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY`。
3. `NO_PROXY` 覆盖 loopback、`.svc`、`.cluster.local` 与私有服务网段，保证
   MySQL/Elasticsearch/MinIO/Redis/本地 Nginx 继续直连。
4. Chart lint/template 通过；Helm release `ragflow-sunmoonai` 升级至 revision `3`，
   新 Pod Ready。
5. RAGFlow Pod 先以显式 `proxies=`、再仅依赖环境变量各连续探测 `10/10` 成功。

该配置只解决本地 KIND 开发环境。生产环境不得依赖开发者桌面 FlClash，必须使用
受治理的 NAT、egress gateway 或显式代理。

## 3. 完整门禁

执行：

```bash
cd /home/zymun/k8s
export KUBECONFIG="$HOME/.kube/kind-config"

python -u sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_004_kind.py \
  --knowledge-image harbor.sunmoonai.com:30443/app-images/knowledge-admin-backend:p0-004-retrieval-r2-20260715 \
  --research-image harbor.sunmoonai.com:30443/app-images/research-admin-backend:p0-004-retrieval-r2-20260715 \
  --kubeconfig "$KUBECONFIG" \
  --namespace app-platform-dev
```

结果：`V5-P0-004 passed`。

### 3.1 身份边界

- 匿名 retrieval：`401`
- retrieval token 调 ingestion：`401`
- ingestion token 调 retrieval：`401`
- 有效 retrieval token 到达 request validation：`422`
- 过期、错误 audience、错误 issuer、错误 scope、伪造签名：`401`
- 未绑定 subject：`403`
- 独立 retrieval client ID/secret：通过
- retrieval caller secret 只在 Research Worker：通过
- resource binding 只在 Knowledge API：通过
- 独立 ServiceAccount 且不挂载 Kubernetes token：通过

### 3.2 Retrieval 与 Citation

- 真实 dataset：`codex-smoke`
- 真实 Evidence：`1`
- 未知 dataset：`403`
- 已授权但无匹配版本：成功空结果
- 不可映射 Provider chunk：丢弃
- Provider timeout：`504`
- token budget `1`：Evidence 截断为估算 `1`，item/response 均标记 truncated
- Citation source href：同源相对路径
- Citation -> Knowledge version：可回溯
- Knowledge version -> Info source version：可回溯
- Browser Citation：无 Provider 字段、Provider ID、raw source URI
- query、Evidence 正文、token、credential、Provider private key：均未输出

## 4. 验证器误判修正

首次恢复真实 retrieval 后，门禁因序列化 Citation 的任意字符串值包含
`ragflow` 而失败。只输出字段路径的受控诊断证明命中字段是 `title` 和 `quote`：
来源文档本身合法提到了 RAGFlow，并非 Provider identity 泄漏。

门禁已改为结构化检查：禁止 `source_uri`、`provider`、`provider_metadata`、
`provider_*` 和 `ragflow_*` 字段。不得对合法 title/quote 做关键词封禁。修正后同一
候选 digest 通过全矩阵，因此无需重建运行时镜像。

## 5. 清理与发布边界

- Knowledge 的 `RAGFLOW_API_BASE`、dataset allowlist、Provider timeout 临时 override
  已删除，正式 Knowledge/Research timeout 保持 `15s/20s`。
- `p0-004-provider-double` Deployment/Service 已删除。
- Knowledge、Research Worker、RAGFlow 均 Ready。
- 本验收接受 ADR-004，但不自动覆盖已有正式 `1.0.1` tag；正式版本提升仍遵循统一
  release decision、组件 digest、canary 与回滚门禁。
- P0-004 不代表 Knowledge/Research Admin React 迁移完成，也不代表完整
  reindex/deactivate/delete/reranker/答案质量 golden set 完成。

## 6. 结论

P0-004 的契约、稳定领域身份、真实 Provider、服务身份、Evidence/Citation 浏览器
边界、故障语义、lineage 与可重复 KIND 验证全部闭合。ADR-004 状态改为
`ACCEPTED`；任务游标返回 P0-001 Runtime 选型，P0-008 仅继续受 ADR-001 阻塞。
