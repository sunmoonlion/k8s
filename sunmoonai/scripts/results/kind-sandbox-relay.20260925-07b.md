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
- Candidate bundle diff contains the backend image/source lock update and release metadata only.

## Deployment

The candidate is prepared but not applied. The KIND apply guard requires a release-specific restore rehearsal/backup receipt and the API, worker, and scheduler to be fully stopped before cutover. Applying will interrupt the Workbench while those workloads are stopped. No cluster or database writes were made for 07b; only read-only plan and server-side dry-run checks were run.
