# Research App MoocManus v4 Deployment Tasks

## 1. Status

- Status: in progress
- Source branch: `research-app/research-admin-backend` on `codex-1`
- Platform branch: `k8s` on `codex-1`
- Source task file: `/home/zymun/research-app/research-admin-backend/docs/mooc-manus-v4-rebuild-task.md`
- Platform architecture doc: `research-app/docs/research-app-moocmanus-v4-deployment.md`

## 2. Deployment Principles

1. Keep source implementation and k8s deployment closure synchronized.
2. Run API and Celery worker from the same backend image.
3. Keep LangGraph execution in `research-admin-backend` and
   `celeryworker-research-admin-backend`.
4. Keep `nodebullworker-research-web-backend` out of LangGraph execution.
5. Keep user traffic disabled until golden tests and controlled deployment pass.
6. Use existing bootstrap/provisioner flows for database, Redis, object storage,
   and search secrets.

## 3. M1 Runtime Wiring

- [x] Confirm `research-admin-backend` owns API, migrations, agent routes, SSE,
  Celery producer, and shared runtime code.
- [x] Confirm `celeryworker-research-admin-backend` uses the shared backend
  image.
- [x] Align backend and worker queue defaults to `research.admin.default`.
- [x] Add `AGENT_SESSION_LOCK_TTL_SECONDS` to backend configuration.
- [x] Add `AGENT_V4_TRAFFIC_ENABLED` as a deployment traffic gate.
- [x] Add Celery producer broker/result backend wiring to backend Secret template.
- [x] Keep generated DB/Redis/S3/Search secrets in the existing platform flow.
- [x] Document that Node Bull worker does not execute LangGraph tasks.

## 4. Resource Validation

- [x] Run resource dry validation for KIND.

Validation record:

```bash
export KUBECONFIG="$HOME/.kube/kind-config"
cd /home/zymun/k8s/sunmoonai/app-platform/research-app/deploy-research-app-all
./deploy-research-app-all.sh validate-resources --cluster KIND
```

Result on 2026-07-09:

- PostgreSQL dependency ready.
- Redis dependency ready.
- Elasticsearch dependency ready.
- `research-admin-backend` database/Redis dry provisioning passed.
- `research-admin-backend` S3 validation passed.
- `research-admin-backend` Elasticsearch validation passed.
- `research-web-backend` resource validation also passed as part of deploy-all.

Note: the same command cannot reach KIND from inside the Codex sandbox. It passed
when run outside the sandbox with the explicit KIND kubeconfig.

## 5. Controlled Deployment

- [x] Choose and record image tag for `research-admin-backend`: `codex-1-v4-20260709-5`.
- [x] Build/push image for the selected tag.
- [x] Run controlled KIND deployment.
- [x] Verify `research-admin-backend` pod health.
- [x] Verify `celeryworker-research-admin-backend` pod startup and task module
  registration.
- [x] Run Phase 0/M1 validation flow against deployed services.
- [x] Verify SSE replay/reconnect through the deployed service path.
- [ ] Verify no user route is enabled while `AGENT_V4_TRAFFIC_ENABLED=false`.
- [x] Record deploy command, cluster, image tag, and validation evidence in the
  source handoff.

## 6. Release Gate

M1 deployment is not complete until all of these are true:

- [x] Source tests pass.
- [x] Source type checking passes.
- [x] Compile check passes.
- [x] KIND resource validation passes.
- [x] Controlled KIND deployment passes.
- [x] Deployed Phase 0/M1 validation flow passes.
- [ ] User traffic gate remains closed until the golden set passes.

Current source validation:

- `uv run pytest`: 52 passed.
- `uv run pyright`: 0 errors.
- `uv run python -m compileall app core scripts`: passed.
