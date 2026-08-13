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
