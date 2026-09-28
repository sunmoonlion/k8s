# RAGFlow

Platform deployment wrapper for RAGFlow v0.25.4.

RAGFlow 是 Knowledge App 拥有的外部知识处理 Provider。它保留独立 StatefulSet、Service、
Secret 与 PVC 生命周期，但不是独立业务 App，也不与 Knowledge 的统一 Backend 数据库合并。
R7.1 旧应用退役不得删除或改名本目录声明的 Provider 资源。

The Helm chart under `resources/ragflow` is vendored from
`/home/zymun/repo/ragflow/helm` and carries only platform-specific metadata
and health probe changes.

Development passwords are committed in
`resources/custom-values/dev-secrets-values.yaml` so a fresh checkout can
be deployed without regenerating credentials. Production deployments must
use separately managed secrets.

The platform image tag `v0.25.4-sunmoonai.1` is based on upstream v0.25.4
and replaces its truncated `cl100k_base.tiktoken` cache with the verified
file whose SHA-256 is
`223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7`.

## Default embedding model

RAGFlow document parsing requires a tenant default embedding model. Without
one, ingestion reaches `documents/parse` but fails with:

```text
No default embedding model is set.
```

This is a RAGFlow runtime configuration requirement, not a Knowledge App API
compatibility issue. Configure a real embedding provider through the RAGFlow UI
or API before running production ingestion smoke tests.

Knowledge App now exposes an operational check:

```text
GET /api/knowledge/ragflow/config-check
```

Expected result before the embedding provider is configured:

```text
enabled=true
reachable=true
has_default_embedding=false
ready=false
```

Failed ingestion jobs caused by this condition are recorded as
`ragflow_config_error`. After configuring a valid embedding provider, retry them
with:

```text
POST /api/knowledge/ingestions/{ingestion_id}/retry
```

2026-07-11 status:

- The admin tenant default models were configured through the RAGFlow UI.
- Knowledge App `config-check` reports `ready=true`.
- The first real parse smoke reached chunk generation, then failed while calling
  the provider default DashScope endpoint:

```text
dashscope.aliyuncs.com:443 connect timeout
```

- After reconfiguring the provider endpoint to the Beijing MaaS URL, retrying
  the same Knowledge App ingestion job succeeded:

```text
ingestion id: 7012be9a-7071-4445-9e01-f412b4717baf
ragflow document: 20769e647cc911f1a85655b688ac3ca7
parse status: DONE
chunk count: 1
```

This confirms the remaining issue was provider endpoint reachability, not a
missing default embedding setting and not a Knowledge App adapter issue.

Do not commit model API keys to this repository. For development, use a local
values override or a secret-managed deployment process to populate
`ragflow.service_conf.user_default_llm.default_models.embedding_model`. Example
shape:

```yaml
ragflow:
  service_conf:
    user_default_llm:
      default_models:
        embedding_model:
          name: text-embedding-3-small
          factory: OpenAI
          api_key: "<managed outside git>"
          base_url: "https://api.openai.com/v1"
```

The `Builtin` factory is present in RAGFlow metadata but the deployed image does
not expose a working built-in encoder for `BAAI/bge-m3`; attempting to add it
returns a model validation error.

## KIND development egress proxy

The chart supports an explicit RAGFlow-only HTTP(S) egress proxy. It is disabled
by default and is never inferred for production. This is useful when a local
KIND cluster cannot reliably reach the configured embedding provider directly.

For WSL development, expose an unauthenticated proxy only on the Windows WSL
gateway/private interface, then deploy with the current gateway:

```bash
WIN_HOST="$(ip route show default | awk '{print $3; exit}')"
RAGFLOW_KIND_EGRESS_PROXY_URL="http://${WIN_HOST}:7890" \
  deploy-ragflow/app/deploy-app/deploy-ragflow.sh --cluster KIND deploy
```

The deployment injects both upper- and lower-case proxy variables into the
RAGFlow container and keeps loopback, cluster DNS and private service networks
in `NO_PROXY`. Do not use a developer desktop proxy as a production egress
design; production must use governed NAT, egress gateway or proxy controls.

## 部署入口整改（2026-09-28）

本地与云端共用上述入口；云端仍未经实机验证。本轮只修改代码，Chart、数据库及应用版本、代理配置值不变。

- 主入口和路由入口实际动作必须指定 CLUSTER、KUBECONFIG、SUNMOON_KUBECTL、SUNMOON_EXPECTED_CLUSTER_UID；共用部署目标绑定、写前复核，不自动SSH重连/猜context/清连接。命名空间和release名称先校验；kubectl请求10秒、进程25秒，logs也是有界观察。
- 主入口支持deploy/uninstall/status/logs；`--dry-run`仍在加载配置前返回。旧purge-data动作明确拒绝，数据删除须走最终清理方案，不能借卸载失败后继续删PVC。uninstall仅忽略release不存在，路由/Helm错误返回失败，timeout继续读原RAGFLOW_HELM_TIMEOUT。相关参数参照[Helm 3 官方实现](https://github.com/helm/helm/blob/v3.15.4/cmd/helm/uninstall.go)。
- Harbor拉取身份使用统一registry-platform/pull_secret.py，凭据在内存/标准输入中处理，不再写临时认证文件，也不因同名Secret存在就跳过目标/内容核对；实际私有凭据仍需准备。既有Secret字段冲突会阻止部署，不force覆盖。
- 镜像检查从**同一组values渲染的Chart**提取Pod容器/init/临时容器镜像，逐一核对固定Harbor地址及manifest摘要，不再检查另一份手写列表。Helm输出中的Secret只经管道进入内存，不写文件或回显；失败不泄露解析片段。镜像层、节点拉取及tag检查到实际安装间的tag漂移仍未验收；本单元没有把Chart所有镜像改为digest，也不能当成完整发布来源证明。
- 路由只在deploy时从模板解析生成JSON并原子写入原.yaml输出；名字/namespace/域名校验，确认Service存在后apply。status/uninstall不生成，删除按名字，保留原域名/后端端口。模板仍使用默认Traefik证书。
- 主入口错误显式传播；Helm lint/upgrade诊断不直接显示私有values，status仅显示release名称/namespace/revision/status，不输出整个Helm状态或Notes。实际失败需在私有运维会话诊断；本次没有产生真实失败日志。
- 业务密码values仍在原路径，未宣称凭据全部迁出工作树。Chart现有PVC keep/StatefulSet保留设置不变，没有实际删除任何资源。

静态检查通过不代表服务实机通过：本单元未运行Helm lint/template、生成器、行为测试、Harbor/Kubernetes API、Docker、SSH或清理。仍需在准入后的集群验收路由、部署失败、卸载保留、镜像拉取和真实业务请求。
