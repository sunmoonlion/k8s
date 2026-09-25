# KIND Knowledge MCP — 2026-09-25

## 08 server-side work

- Provisioned the declared Knowledge object-storage access. The `development-knowledge-datasets` bucket policy grants Knowledge read-only object access.
- Dataset source: lesson 25 `integrated_agent_service/data/business_analysis.sqlite`. Size: 21,364,736 bytes. Local and uploaded-object SHA-256 both equal `a1764f1defa673670bb1e4df9e3223a82cdc6d2b66365370617c6be509a04cf5`.
- The first upload attempt correctly failed with the backend's read-only credentials. Uploaded through the MinIO S3 endpoint using the object-storage admin Secret; credentials were not printed. The stored object's size and hash match the pinned values.
- Created `app-platform-dev/knowledge-mcp-tokens` and `sandbox-pool/sandbox-demo-knowledge`; the generated static token is held only at `/home/zymun/private/demo-mcp-token` (0600). Restarted `sandbox-demo` so it receives the token.
- Recovered Knowledge identity preparation from live state. Plan hash: `f72dbfad14983d331a3e93b6bc523436cee2ac8a1e4163b0b7bba2ce5bb56ac5`; 18 database probes passed; three AMQP roles authenticated and all three foreign-vhost attempts were denied; old identities are retired.
- Built and pushed Knowledge backend digest `sha256:67028600d4a128d2a6d9700d88a337ad403e0924db57aef03eb1a76937076e23`. Ruff, format check and Pyright passed during image build.
- First release `knowledge-mcp-20260925` rolled out but the MCP data tools reported missing S3 credentials: the renderer injected them into worker, not API. Added optional API references to the existing read-only S3 Secret and a rendering regression test, then deployed the corrected release `know-mcp-0925-r2` with a fresh backup receipt. Both isolated restore iterations matched the live catalog and rows at head `20260911_0006`; no live DB writes occurred in rehearsal.
- Corrected candidate gate, read-only plan, server-side dry-run and deployment passed. The Knowledge-focused test set passed (26 tests); the expanded all-app committed-candidate test has an unrelated existing Investment render failure (`source checkout does not match the development lock`).
- Post-deploy drift is false. All Knowledge Deployments are ready. MCP `tools/list` returned `describe_schema`, `metric_definitions`, and `run_sql`; all three calls returned data version `lesson23-analysis-b7ad59fddab30331`. Schema lists nine tables; read-only count query returned 26,387 `order_performance` rows. The dataset was fetched from S3 and SHA-256 verified by the backend.
- `sandbox-demo` config contains the `sunmoon_knowledge` URL and `SUNMOON_KNOWLEDGE_TOKEN` environment-variable reference. The browser prompt from 08 step 11 has not been sent yet.

The corrected bundle also carries the optional D10 JWT public-key reference/issuer and API S3 credential references. The public-key fields remain dormant until D10 settings-page provisioning.

No credential or token values are recorded here. Private backup and identity records remain outside Git under `/home/zymun/private/`.

## Per-user sandbox check

- After the 09 sandbox refresh, verified that the provisioned sandbox config references `sunmoon_knowledge` and its app-server process has the credential environment set (the secret value was not printed).
- A read-only MCP probe from the live user sandbox using that in-process credential passed `initialize`, `tools/list`, and `describe_schema`: three tools, nine tables, data version `lesson23-analysis-b7ad59fddab30331`. This is a server-side probe; the browser Workbench prompt is still pending.
- Follow-up read-only `run_sql` from the live user sandbox using its app-server-only credential returned 26,387 `order_performance` rows with data version `lesson23-analysis-b7ad59fddab30331`. This confirms the per-user JWT can query Knowledge directly; it does not replace the Workbench browser DATA_QUERY delegation, which remains to be verified after relay-token rotation.
