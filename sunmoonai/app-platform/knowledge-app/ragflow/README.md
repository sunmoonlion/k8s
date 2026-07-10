# RAGFlow

Platform deployment wrapper for RAGFlow v0.25.4.

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

The current KIND cluster has no configured embedding provider. The `Builtin`
factory is present in RAGFlow metadata but the deployed image does not expose a
working built-in encoder for `BAAI/bge-m3`; attempting to add it returns a model
validation error.
