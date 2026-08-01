# V5-P0-004 Retrieval/Citation Contract 阶段证据（历史）

- 日期：2026-07-15
- 状态：**SUPERSEDED_BY_ACCEPTED_RESULT**
- ADR：`sunmoonai/docs/mooc-manus-v5/adr/ADR-004-knowledge-retrieval-citation-contract.md`
- 结论：本文保留阻塞定位过程。2026-07-16 已建立 KIND 显式 egress proxy、
  完成真实全矩阵并接受 ADR-004；最终结论以
  `sunmoonai/docs/evidence/v5/V5-P0-004/result.md` 为准。

## 1. 固定候选

- Knowledge：`harbor.sunmoonai.com:30443/app-images/knowledge-admin-backend:p0-004-retrieval-r2-20260715`
  - Harbor manifest digest：`sha256:13e31518585b2bda9091eedb503217e9e28064fe73e944c103fa5df5604e26eb`
- Research：`harbor.sunmoonai.com:30443/app-images/research-admin-backend:p0-004-retrieval-r2-20260715`
  - Harbor manifest digest：`sha256:7a93cde873ca97b40d741c51bbac2158376120c2708a0e82ccee50622d869e5d`
- Knowledge Alembic head：`20260715_0003`
- Research retrieval Worker：独立 ServiceAccount `research-knowledge-retrieval-worker`，`automountServiceAccountToken=false`。

上述候选均按 digest 在 KIND 核对。Knowledge migration gate 成功后才更新业务 Deployment；Research Worker 使用独立 retrieval client identity，不复用 Info ingestion credential。

## 2. 已通过范围

1. Retrieval v1 的 request、Evidence response、browser-safe Citation schema、examples、manifest 和 consumer lock 已建立；Knowledge 是唯一契约编辑源，Research 以 digest 锁定消费。
2. Knowledge migration 已创建稳定 `KnowledgeDocument`、`KnowledgeDocumentVersion` 和 Provider binding；首个 r1 migration 暴露 asyncpg 无类型 JSON bind 问题，改为显式 `text/timestamptz` cast，并增加 asyncpg dialect 编译回归测试后，r2 migration 在真实 PostgreSQL 通过。
3. Knowledge API、RAGFlow adapter、token budget、不可映射 chunk 丢弃、Evidence lineage 和 Citation projection 已实现并通过本地 provider/consumer tests；Research `KnowledgePort`/client 不包含 `ragflow_*` 类型。
4. 独立 Casdoor retrieval client-credentials 已完成 reconciliation；RS256、exact issuer/audience/subject 和本地 `knowledge:retrieve` 关系探针通过，凭据未打印、未落盘。
5. KIND 验证已通过独立服务身份、未知 dataset 和空结果路径，并已进入真实 retrieval 路径。验证器只输出受控错误类型/固定状态，不输出 query、Evidence 正文、token、Provider credential 或完整 Provider response。

## 3. 验证中发现并系统修复的问题

### 3.1 Research Worker 依赖共享 ConfigMap，但组件部署未证明依赖存在

只更新 Worker Deployment 时，既有 `research-admin-backend-config` 缺少 retrieval URL、application、scope 和 timeout，导致真实身份路径失败。正式 ConfigMap 组件部署后恢复；Worker 部署脚本现增加 fail-closed 门禁，在共享检索配置缺失或不匹配时拒绝更新 Deployment，避免“Pod Ready 但检索必然失败”。

### 3.2 Knowledge Secret 生成器会用空环境变量覆盖既有 Provider credential

Knowledge 候选部署过程中，旧 Secret 脚本从空本地环境重新生成清单，把集群中非空 `RAGFLOW_API_KEY` 覆盖为空，真实 retrieval 因而返回 `503`。已从 RAGFlow 自有数据库以内存管道恢复既有 credential；恢复过程未打印、未写文件。

Secret 部署脚本现改为：显式输入优先，否则保留集群既有非空值；`RAGFLOW_API_KEY` 缺失时 fail closed；用 `kubectl create secret --dry-run | kubectl apply` 无落盘协调；禁用敏感 Secret 的明文 YAML generate。已验证空值部署会被拒绝，未显式传值的重复部署会保留现有非空 key。

### 3.3 原验证器隐藏子进程故障上下文

原 verifier 只报告 harness exit code，无法区分配置、授权、Provider 和协议问题。现仅允许输出 `P0_SAFE_FAILURE` 受控结构：异常类型，以及由本地固定消息构造的安全状态；Provider 原始异常、query、正文和 credential 仍不输出。

这些修复属于部署依赖、Secret 生命周期和可诊断性边界的系统修复，不是接受 P0-004 的临时集群补丁。

## 4. 当前真实阻塞

恢复 RAGFlow credential 后，Knowledge 内部 API 与默认 embedding 配置均可访问，但真实 RAGFlow retrieval 在 Provider 边界超时：

- 正式默认 timeout 为 Knowledge `15s`、Research `20s`，返回 `504`。
- 诊断时临时放宽为 Knowledge `90s`、Research `120s`，仍在 `90s` 返回 `504`；RAGFlow 日志显示连接 `dashscope.aliyuncs.com:443` 超时。
- 早期 WSL 探针结果不稳定；2026-07-15 复测确认 WSL 主机经本机 Fake-IP/TUN 可分别在约 `1.3s/1.8s` 访问 DashScope/阿里云 HTTPS，但 RAGFlow Pod 的真实请求即使放宽到 `90s` 仍超时。因此当前边界已收窄为 Docker/KIND 容器出站路径，而不是 Provider 整体不可用。namespace 中没有阻断该流量的 NetworkPolicy，Docker daemon 未配置 HTTP/HTTPS proxy，也没有可复用的本地 embedding 服务。
- 所有诊断 timeout override 已删除，正式 ConfigMap 已恢复为 `15s/20s`，相关 Deployment 已重新 rollout。

2026-07-16 的进一步诊断排除了“只需等待网络恢复”或“默认 timeout 太短”：

- 普通 Docker `host`/`bridge` 容器曾同时成功建立 TLS 1.3，但完整 verifier 在正式 `15/20s` 和受控诊断 `90/120s` 下均由真实 retrieval 返回 `504`；每次诊断后均恢复 `15/20s`。
- RAGFlow Pod 内原始 DNS/TCP/TLS 和 Python `requests` 对根路径偶尔成功，但精确 embedding 路径仍可在 connect 阶段失败；同一 Pod 对同一 Fake-IP 连续十次三秒 TCP/TLS 探针只有 `2/10` 成功。
- RAGFlow 日志明确记录 `HTTPSConnectionPool(host='dashscope.aliyuncs.com', port=443)` 的 `ConnectTimeoutError`；Knowledge 的 `15s/90s` 取消只是上层边界生效，不是根因。
- Windows 实际运行 `FlClashCore`，稳定显式代理只监听 Windows loopback `127.0.0.1:7890`；WSL 对 `127.0.0.1:7890` connection refused，对 Windows 网关/Fake-IP 网关的 `7890` 均超时。浏览器和 Windows/WSL 的部分流量可由 TUN 接管，但该 Fake-IP 转发没有为 KIND Pod 提供稳定承载。

因此当前最小环境修复是为本地 KIND 提供一个 WSL/Pod 可达、仅限受信私有网段的显式 HTTP(S) 代理入口，并给 RAGFlow 配置 `HTTPS_PROXY` 与完整 `NO_PROXY`；生产环境必须使用受治理的 egress/NAT/proxy，不能依赖开发者桌面 FlClash。增加应用重试或 timeout 不得作为网络修复。

因此当前阻塞是 KIND 到现用真实 DashScope embedding Provider 缺少稳定显式 egress proxy，不是 Knowledge/Research 内部调用、JWT、契约、migration 或默认 timeout。下一步需让 FlClash/等价代理向 WSL 私有网段提供受限监听，验证 Pod 经代理连续连接稳定，再将代理作为 KIND-only 配置注入 RAGFlow 并复跑完整矩阵。

## 5. 不接受与禁止项

- 不用 deterministic/fake embedding、mock retrieval 或伪造 Evidence 绕过真实 Provider 门禁。
- 不把 schema/unit/empty-result 通过解释成真实 retrieval 通过。
- 不将 r2 候选提升为正式版本，不覆盖当前稳定 tag。
- 不把本后端任务解释成 Knowledge/Research Admin React 迁移完成；两者仍是后续独立迁移任务。
- 不直接切换 embedding model 后沿用旧向量索引；若采用本地真实模型，必须建立独立部署、绑定新模型并重新索引后再验收。

## 6. 继续条件与复验

优先恢复 KIND/Docker 到现用 DashScope Provider 的可靠 HTTPS 出站，因为现有 RAGFlow dataset 已用该 embedding 模型建立索引；这条路径变更最小，也不破坏向量兼容性。若环境明确不能提供该出站能力，则应另立有范围的“本地真实 embedding Provider + 模型制品 + RAGFlow binding + 全量 reindex”任务，不能静默切换。

出站或本地 Provider 修复后，使用相同 r2 digest 重新运行：

```bash
cd /home/zymun/k8s
export KUBECONFIG="$HOME/.kube/kind-config"
python -u sunmoonai/docs/mooc-manus-v5/scripts/verify_p0_004_kind.py \
  --knowledge-image harbor.sunmoonai.com:30443/app-images/knowledge-admin-backend:p0-004-retrieval-r2-20260715 \
  --research-image harbor.sunmoonai.com:30443/app-images/research-admin-backend:p0-004-retrieval-r2-20260715 \
  --kubeconfig "$KUBECONFIG" \
  --namespace app-platform-dev
```

只有真实 retrieval lineage、Research consumer、JWT 负向矩阵、Provider timeout/unmappable/token-budget、Citation 回溯和清理恢复全部通过后，才生成 `result.md`、接受 ADR-004 并更新任务游标。
