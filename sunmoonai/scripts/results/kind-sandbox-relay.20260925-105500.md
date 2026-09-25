# KIND sandbox relay 07 — passed (2026-09-25)

## Completed

- Built and pushed sandbox image digest: `harbor.sunmoonai.com:30443/app-images/sandbox@sha256:ba14b8d3f69e4359a4b13dc78c1078b2ef2ec1498e54eeda8dd62e100c219a2f`.
- Built and pushed relay image digest: `harbor.sunmoonai.com:30443/app-images/relay@sha256:9a155338849e57d0e4e3b9ba075783de71fe4d19053d9f2602b695da85476806`.
- Updated the resource manifests to use these digests. Relay Secret permissions use mode 0440 and fsGroup 10002. Sandbox mounts its home PVC at /data and its app-server token with mode 0440/fsGroup 10001; this lets the non-root entrypoint initialize /data/codex.
- Relay and sandbox pods are Running and Ready. Sandbox logs report app-server listening at ws://0.0.0.0:47800 and a paired connection.
- Registered the existing Workbench user `admin@sunmoonai.local` without sending email. Environment `this-pc`: `3c306437-b499-4830-b85f-3209f78700f7`; sandbox: `ce3fe8da-f055-4bf3-acaf-2c7aaa2331ff`.
- Initialized and started the local agent under `/home/zymun/.sunmoon-agent-kind`; startup log reports `relay connected` to edge-1. Agent remains running for follow-up.

## Browser acceptance

The user reports browser steps 8–9 passed: a Workbench session was created with `this-pc` and the sandbox; sending “在当前目录写一个 hello.txt，内容 hello，然后 cat 它” returned `hello`; SMOKE delegation reached `SUCCEEDED` in 2 steps at a cost of 1.000240 CNY; “打开底稿” showed the result and conclusion draft. Session: `d6a9d709-21e3-42dd-9ae3-8ec0e05e0b4c`; task: `72dedd8a-c929-4cbb-9222-10b63d8f8742`. I independently read `/home/zymun/research/smoke1/hello.txt`; its content is `hello`.

Known issue carried to 07b: new events do not appear in the timeline until the page is refreshed. The backend command/event records show the turn completed; the SSE/browser delivery path is being fixed separately.

## Final runtime evidence

- Sandbox log: app-server paired at connection `216be9ff`; an earlier tail also showed the app-server listening on port 47800.
- Runner log: sandbox link up at `03:36:01`; advisor task `72dedd8a-c929-4cbb-9222-10b63d8f8742` stopped in `SUCCEEDED` at `03:54:48`.
- Local agent terminal: `stream bridged conn=216be9ff local=ws://127.0.0.1:45231`.
- Latest relay log tail contained health-check responses only.
- Sanitized diagnostic capture: `kind-sandbox-relay.20260925-034108.step9-diag.txt`. Output lines containing `sk-`, `token`, or `password` were filtered.

## Identity ownership correction reported after initial registration

The initial `workbench_register` invocation used `admin@sunmoonai.local` and created the records under actor `e2e04d5c-dba9-44f9-8eae-0d6997be8448`. Per the command history relayed from Cursor, the local `investment_admin` database was then changed directly so the environment and sandbox belong to actor `f25b3602-f8b2-47a6-af84-279e7cdad453` (the `sunmoonai`-organization test account `architecture-v2-admin-a`). This bypassed `workbench_register`; no rollback was performed.

The only reported database writes were these two statements, each affecting one row:

```sql
UPDATE workbench_environments
SET owner_actor_id = 'f25b3602-f8b2-47a6-af84-279e7cdad453'
WHERE id = '3c306437-b499-4830-b85f-3209f78700f7'
  AND owner_actor_id = 'e2e04d5c-dba9-44f9-8eae-0d6997be8448';

UPDATE workbench_sandboxes
SET owner_actor_id = 'f25b3602-f8b2-47a6-af84-279e7cdad453'
WHERE id = 'ce3fe8da-f055-4bf3-acaf-2c7aaa2331ff'
  AND owner_actor_id = 'e2e04d5c-dba9-44f9-8eae-0d6997be8448';
```

The reported post-update check was:

```sql
SELECT 'env' AS t, owner_actor_id::text
FROM workbench_environments
WHERE id = '3c306437-b499-4830-b85f-3209f78700f7'
UNION ALL
SELECT 'sb', owner_actor_id::text
FROM workbench_sandboxes
WHERE id = 'ce3fe8da-f055-4bf3-acaf-2c7aaa2331ff';
```

This change was performed outside the registration CLI. The browser login and steps 8–9 remain unverified; do not treat the reassignment as evidence of successful login or a completed smoke test. No password or token is included in this report.
