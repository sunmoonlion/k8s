# Research App MoocManus v4 Deployment Architecture

## 1. Positioning

MoocManus v4 is implemented inside `research-app/research-admin-backend`.
The k8s app-platform layer is responsible for wiring the runtime into the
existing Research App deployment topology.

This document mirrors the `info-app` convention: source implementation details
stay in the source repository, while platform deployment boundaries and
validation records stay under `k8s/sunmoonai/app-platform/research-app/docs`.

## 2. Component Boundary

| Component | v4 Role |
|---|---|
| `research-admin-backend` | FastAPI API, Alembic migrations, agent session/run APIs, SSE replay endpoint, Celery producer, LangGraph runtime code in the shared image. |
| `celeryworker-research-admin-backend` | Runs the same backend image as a Celery worker and consumes graph execution tasks. |
| `research-admin-frontend` | Not part of the M1 graph runtime yet. It must not route user traffic to v4 before the release gate. |
| `research-web-backend` | Not part of MoocManus v4 M1 execution. |
| `research-web-frontend` | Not part of MoocManus v4 M1 execution. |
| `nodebullworker-research-web-backend` | Remains a web/backend async worker and does not execute LangGraph tasks. |

## 3. Runtime Dependencies

MoocManus v4 M1 uses the existing platform dependencies:

- PostgreSQL: agent sessions, runs, events, side-effect records, and LangGraph
  checkpoint tables.
- Redis: SSE live fan-out and session execution locks.
- Celery broker: API dispatches graph tasks; worker consumes them.
- S3/Object Storage: available to the app platform, but M1 agent runtime only
  uses object references where needed.
- Elasticsearch/Search: inherited Research App capability, not required by the
  first M1 graph runtime.

PostgreSQL checkpoint tables are migration-owned. Worker pods must not call
LangGraph `checkpointer.setup()` at runtime.

## 4. ConfigMap and Secret Contract

`research-admin-backend` ConfigMap now exposes the M1 runtime controls:

- `ENV`
- `LOG_LEVEL`
- `SESSION_TTL_SECONDS`
- `AGENT_SESSION_LOCK_TTL_SECONDS`
- `AGENT_V4_TRAFFIC_ENABLED`
- `FRONTEND_BASE_URL`
- `CASDOOR_ENDPOINT`
- `CASDOOR_ORGANIZATION`
- `CASDOOR_APPLICATION`
- `CASDOOR_REDIRECT_URI`
- `CASDOOR_VERIFY_SSL`
- `CELERY_QUEUE`
- `CELERY_TASK_DEFAULT_QUEUE`

`research-admin-backend` Secret exposes:

- `CELERY_BROKER_URL`
- `CELERY_RESULT_BACKEND`
- `CASDOOR_CLIENT_ID`
- `CASDOOR_CLIENT_SECRET`

The API Secret generates `CELERY_BROKER_URL` from the RabbitMQ producer account
by default:

- vhost: `research-development`
- user: `research-admin-backend-producer`
- queue: `research.admin.default`

Database, Redis, S3, and Elasticsearch credentials continue to come from the
existing bootstrap/provisioner-generated platform secrets.

## 5. Celery Worker Contract

`celeryworker-research-admin-backend` uses the same backend image and starts:

```text
celery -A app.worker worker -Q research.admin.default
```

Default queue alignment:

- backend `Settings.celery_queue`: `research.admin.default`
- worker ConfigMap `CELERY_QUEUE`: `research.admin.default`
- worker ConfigMap `CELERY_TASK_DEFAULT_QUEUE`: `research.admin.default`

The worker imports `app.tasks.agent_graph`, which registers the v4 graph task.
Its worker Secret generates `CELERY_BROKER_URL` from the RabbitMQ worker account
so the API and worker use different RabbitMQ users with the same environment
variable name.

## 6. Traffic Gate

K8S defaults `AGENT_V4_TRAFFIC_ENABLED=false`.

This flag is a deployment-level guard for future UI/user routing. It does not
replace tests, golden validation, or controlled deployment validation.

User traffic must remain disabled until the M1 release gate passes.

## 7. Validation Commands

Use the KIND kubeconfig explicitly when validating from this machine:

```bash
export KUBECONFIG="$HOME/.kube/kind-config"
cd /home/zymun/k8s/sunmoonai/app-platform/research-app/deploy-research-app-all
./deploy-research-app-all.sh validate-resources --cluster KIND
```

Current validation record:

- Date: 2026-07-09
- Cluster: KIND
- Command: `KUBECONFIG=$HOME/.kube/kind-config ./deploy-research-app-all.sh validate-resources --cluster KIND`
- Result: passed outside the Codex sandbox.
- Covered dependencies: PostgreSQL, Redis, S3/Object Storage, Elasticsearch.

## 8. Known Gaps

- Controlled KIND deployment passed on 2026-07-09.
- API pod health, Celery worker startup, logs, and deployed Phase 0/M1 validation
  flow passed with image `harbor.sunmoonai.com:30443/app-images/research-admin-backend:codex-1-v4-20260709-5`.
- Deployed validation timeline:
  `TimelineRunStarted`, `TimelineWaitInputDisplayed`, `TimelineUserInputReceived`,
  `TimelineToolStarted`, `TimelineToolCompleted`, `TimelineRunCompleted`.
- HTTP replay and SSE replay both returned the expected cursor-tail events.
- Real ingress-level SSE reconnect is not verified yet; service-level SSE replay
  through port-forward passed.
- Real Celery process kill/restart recovery is not scripted yet.
- Redis ACL for `research_admin_backend` must allow `research:*` keys,
  `research:agent:*` channels, and `+@pubsub`.
