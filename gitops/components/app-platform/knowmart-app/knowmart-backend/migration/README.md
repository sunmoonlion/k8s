# knowmart 迁移

一次性 Job 用 `knowmart_migrator` 跑 Alembic，`migration_job_revision` 在[后端config](../config.yaml)；API / Worker / Scheduler 不隐式升级数据库。本目录的 `workload.yaml`、`auth.sops.yaml`、`kustomization.yaml` 由 `application-stage APP=knowmart` 从[共用模板](../../../common/backend/migration/workload.yaml.j2)生成，不手改；生成前目录只有本说明（`stages.py` 要求阶段目录存在）。

尚未部署（qwen-003 D 段）。操作流程见[应用维护](../../../../../../infrastructure/applications/README.md)。
