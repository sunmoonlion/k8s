# V5-P0-005 KIND evidence (2026-07-12 to 2026-07-13)

## Scope

This result covers the real Casdoor service-token boundary and the anonymous
fail-closed checks for the three Admin APIs. It does not claim completion of
the browser PKCE matrix; that remains a separate Playwright/manual task.

## Runtime

- namespace: `app-platform-dev`
- traffic after the check: `research-admin-backend` `AGENT_V4_TRAFFIC_ENABLED=false`
- final Admin Backend API/worker release tag: `1.0.1` for Info, Knowledge and Research
- Info image: `info-admin-backend:p0-005-auth-20260712-r3`
  digest: `sha256:6c8041e83f96f4952718ecf63a8c8d8a5664d8343ecc135b1c1e0ad13a2ceb3d`
- Knowledge image: `knowledge-admin-backend:p0-005-auth-20260712-r3`
  digest: `sha256:7c55d2bfd130f0b68a8b8df3f338739c1570ceef36b6112da63f1bd740b9b7d4`
- Research image: `research-admin-backend:p0-005-auth-20260712`
  digest: `sha256:b10820a71218f5630cc519452c426a867a85ba5ed95870fae164e9d31fec6d5b`
- Knowledge service verifier uses the explicit standard Casdoor discovery URL
  for the provider's access-token issuer; browser BFF discovery remains
  application-specific.

## Database

- Info: Alembic `20260712_0003 (head)`.
- Knowledge: Alembic `20260712_0002 (head)`.
- Research: Alembic `20260712_0002 (head)`.

On 2026-07-13 the manual administrator workaround was replaced by a repeatable
deployment-pre migration gate:

- `provision_p0_005_migration_roles.sh` defaults to plan-only mode and requires
  explicit `--apply`. It reconciles three distinct, non-superuser migration
  roles and three app-namespace Secrets without printing credentials.
- Each Secret contains only `MIGRATION_DATABASE_URL` and
  `MIGRATION_DATABASE_USER`; the latter is used as non-secret identity metadata
  and checked by the Job before Alembic runs.
- Existing public-schema tables, sequences, views, materialized views, enum or
  domain types, functions and procedures are transferred to the migration
  owner. New objects inherit runtime DML/sequence grants from migration-owner
  default privileges.
- Runtime roles retain application DML but have public-schema `CREATE`
  revoked. The live probes returned:
  `info_admin_user=False`, `knowledge_admin_user=False`, and
  `research_admin_user=False` for `has_schema_privilege(..., 'CREATE')`.
- The shared gate is invoked by all three Admin Backend component deployment
  scripts before `kubectl apply` updates a Deployment. It rejects a missing or
  shared migration Secret and verifies that the image resolves a migration URL
  whose user differs from the runtime user and matches Secret metadata.

The role/Secret provisioner completed repeatedly, including after existing
function/procedure ownership was added to its reconciliation scope, proving the
operation is idempotent. The three positive gates then reported:

```text
info-admin-backend:      info_admin_user_migration      20260712_0003 (head)
knowledge-admin-backend: knowledge_admin_user_migration 20260712_0002 (head)
research-admin-backend:  research_admin_user_migration  20260712_0002 (head)
```

The Knowledge negative test used the previous `1.0.1` image, which did not
resolve `MIGRATION_DATABASE_URL`. The gate failed before Alembic with
`migration gate: image does not resolve MIGRATION_DATABASE_URL`, and the live
Deployment remained on `knowledge-admin-backend:1.0.1`. The positive test used
`knowledge-admin-backend:p0-005-migration-20260713`, registry digest
`sha256:59889fdf08894546852ed3f92970e5d5f5c80bcf5a4fd92109ad22d641850e88`,
and passed without changing that Deployment. Knowledge source commits are
`bdc92bc` (backend) and `c18453d` (parent pointer).

## Verification output

`verify_p0_005_kind.py` passed without printing a token or secret:

```json
{
  "task": "V5-P0-005",
  "result": "passed",
  "anonymous": {
    "info_documents": 401,
    "knowledge_ingestions": 401,
    "research_sessions": 401
  },
  "internal_route": {
    "without_service_token": 401,
    "with_real_client_credentials": 422,
    "token_printed": false
  },
  "browser_pkce_matrix": "not_automated_by_this_script"
}
```

The real Casdoor access-token claims were inspected in-process only: RS256,
the configured service audience, and the allowlisted service subject. The
token itself was never printed or persisted.

After retagging the tested digests as `1.0.1`, the same verification was run
again and passed with the identical 401/401/422 matrix. No `ImagePullBackOff`
Pod remained in `app-platform-dev`; untested Web/Frontend components stayed on
their previous stable tags.

## Acceptance status

`P0-005D` is **partial**: the real service boundary, anonymous checks,
repeatable database migration Secret injection, role separation, and
deployment-pre migration gate pass. Browser PKCE/CSRF/cross-user evidence,
forged/expired-token KIND matrix, and repeatable browser-client Secret
injection remain open. ADR-005 therefore stays `CANDIDATE`.
