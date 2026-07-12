# V5-P0-005 KIND evidence (2026-07-12)

## Scope

This result covers the real Casdoor service-token boundary and the anonymous
fail-closed checks for the three Admin APIs. It does not claim completion of
the browser PKCE matrix; that remains a separate Playwright/manual task.

## Runtime

- namespace: `app-platform-dev`
- traffic after the check: `research-admin-backend` `AGENT_V4_TRAFFIC_ENABLED=false`
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
- Research: `20260712_0002` was applied through the PostgreSQL migration
  administrator because the existing runtime role was not owner of the legacy
  `agent_sessions` table. The runtime role was not granted DDL; an automated
  migration-job/privileged migration Secret is still required before M1b.

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

## Acceptance status

`P0-005D` is **partial**: the real service boundary and anonymous checks pass;
browser PKCE/CSRF/cross-user evidence, forged/expired-token matrix, repeatable
Secret injection, and the migration job gate remain open. ADR-005 therefore
stays `CANDIDATE`.
