# KIND Workbench 07b — SSE live timeline fix (2026-09-25)

## Finding

The backend SSE endpoint emitted frames with a named event equal to each domain type (for example, `event: turn/completed`). The Workbench client consumes `EventSource.onmessage`, which only receives default `message` events. The JSON payload already carries its domain `type`, so named SSE dispatch caused new timeline events to be missed until a page refresh fetched them again.

## Change

Backend commit `f7c7404380f8dc281c1c2dacca51c8091b63baf1` adds `_session_sse_frame`, dispatches session frames as `event: message`, and keeps the event cursor and domain type in the JSON payload. Regression test: `app/tests/test_workbench_sse.py`.

## Validation

- Ruff check passed.
- Focused tests: `1 passed, 7 skipped`; the database-backed route tests skipped because `AGENT_TEST_DATABASE_URL` was unset.
- Docker build type-check stage passed Ruff, formatting, and Pyright.
- Candidate image pushed to private KIND Harbor: `harbor.sunmoonai.com:30443/app-images/investment-backend@sha256:100504a9734e225a01496d5ded731710b16b6ce8872d2606649cd05ac89a1af8`.
- Rendered candidate `kind-wb-20260925-07b`; deployment bundle gate, plan, and KIND server-side dry-run all passed.
- Candidate bundle was rendered from the updated runtime configuration and the approved A6 checklist; its diff includes the backend/web image and source-lock updates, release metadata, Workbench configuration and optional Secret references, runner resources, and the specified NetworkPolicies.

## Deployment

Deployment completed on KIND with release `kind-wb-20260925-07b`.

- The maintenance guard initially rejected the backup rehearsal with `maintenance_writers_not_stopped`: the runner also matched the backend-writer guard. The API, worker, scheduler, and runner were all scaled to zero and their pods were confirmed gone before retrying in a fresh private directory.
- The release-specific backup/isolated-restore rehearsal passed from `/home/zymun/private/investment-wb-07b-20260925-retry2`; the receipt and dump remain private, mode 0600. Both restore iterations matched catalog and all rows at migration head `20260925_0011`; no live database writes were made by the rehearsal.
- Server-side dry-run passed. The migration Job completed and was cleaned up. The deployment command returned `passed`; API (2), worker (1), scheduler (1), runner (1), admin frontend (2), and web frontend (2) all rolled out.
- API and runner now use backend digest `sha256:100504a9734e225a01496d5ded731710b16b6ce8872d2606649cd05ac89a1af8`. Runner logs show successful Redis and Postgres initialization and service startup.
- Post-deploy `drift` passed with `drift: false`; `status` passed. The recovered identity directory contains the generated `database-upgrade-kind-wb-20260925-07b/complete.json` and `database-activation/complete.json`, both private mode 0600.
- The original browser symptom was that live events appeared only after refresh. The backend now emits default SSE `message` events, retaining each domain event type in its JSON payload. Cluster rollout and static/code tests passed; a fresh authenticated browser session has not yet been used to verify live timeline updates after deployment.
