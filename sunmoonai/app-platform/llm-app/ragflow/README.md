# RAGFlow

Platform deployment wrapper for RAGFlow v0.25.4.

The Helm chart under `resources/ragflow` is vendored from
`/home/zymun/repo/ragflow/helm` and carries only platform-specific metadata
and health probe changes.

Runtime passwords are generated in `.runtime/secrets-values.yaml` on the
first deployment and are intentionally excluded from Git.

The platform image tag `v0.25.4-sunmoonai.1` is based on upstream v0.25.4
and replaces its truncated `cl100k_base.tiktoken` cache with the verified
file whose SHA-256 is
`223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7`.
