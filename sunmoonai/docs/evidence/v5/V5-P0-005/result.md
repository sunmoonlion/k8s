# V5-P0-005 KIND evidence (2026-07-12 to 2026-07-14)

## Scope

This result covers the real Casdoor service-token boundary, anonymous
fail-closed checks, negative JWT matrix, browser PKCE/CSRF/cross-user matrix,
and strict TLS browser execution for the three Admin APIs.

## Runtime

- namespace: `app-platform-dev`
- traffic after the check: `research-admin-backend` `AGENT_V4_TRAFFIC_ENABLED=false`
- final Admin Backend API/worker release tag: `1.0.1` for Info, Knowledge and Research
- Info image digest: `sha256:0dd720796ad52086345ca3b5f5b87a52bf2e2141fa00214a1c301561dda570ad`
- Knowledge image digest: `sha256:29fdbabc8a59ed855141bb292b2525a585bf94cfdb3ddb434973fcc91774911f`
- Research image digest: `sha256:1ad5ef63069f4345ce52a4951b1a82eacb2e86267c848561c172b399e5e114ef`
- All six API/worker Pods reported the corresponding registry digest; no
  `p0-*` image remains in the six Admin Backend Deployments.
- Knowledge service verifier uses the explicit standard Casdoor discovery URL
  for the provider's access-token issuer; browser BFF discovery remains
  application-specific.

> 2026-07-26 compatibility addendum: the final clause above is retained as the
> historical P0-005 assumption, not as the current browser rule. P0-008B/B4
> proved against Casdoor `v3.42.0` and its official tagged source that
> application-specific discovery advertises an application-scoped issuer while
> `generateJwtToken()` still signs browser and service tokens with the base
> `originBackend` issuer. ADR-005 now requires standard discovery/base issuer
> for this Provider version and still enforces exact client audience and all
> other App/Surface isolation. This is a correction with a stricter single
> issuer, not a dual-issuer compatibility bypass.

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

An earlier check intentionally caught that the pre-existing Knowledge
`1.0.1` digest did not resolve `MIGRATION_DATABASE_URL`. The tested candidates
were therefore deployed under unique tags first, passed the migration gate,
and only then published as `1.0.1`. The shared migration gate now defaults to
`imagePullPolicy: Always`; this prevents a node-local old tag cache from
silently bypassing the digest selected in Harbor. The old stable artifacts
remain reachable through their `p0-005-auth-*` rollback tags.

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

The service negative matrix passed with statuses:
`valid_control=422`, `expired=401`, `wrong_audience=401`, `wrong_issuer=401`,
`unbound_subject=403`, `malformed_scope=401`, `forged_signature=401`.

The strict TLS browser matrix passed with primary and secondary identities for
Info, Knowledge, and Research. Each identity returned `authenticated_me=200`,
stable actor binding, one-time callback consumption, HttpOnly session cookie,
four CSRF negative cases, logout revocation, and no provider material. The
strict runner used full bundled Chromium with an isolated NSS database seeded
from the platform Root CA; provider UI latency was approximately 0.5–1.0 s.
Casdoor runtime checks confirmed local static assets (no external font/CDN),
PostgreSQL connectivity, and the `Organization.languages` JSON-array
invariant.

## Acceptance status

`P0-005D`, `P0-005E`, and `P0-005F` are **ACCEPTED** as of 2026-07-14.
ADR-005 is ready to move from `CANDIDATE` to `ACCEPTED`; Research traffic was
restored to the declarative fail-closed value `false` after every check.
