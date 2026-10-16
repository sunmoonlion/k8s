# knowlab Redis身份

账号 `redis_user`、键前缀 `redis_key_pattern` 与 `redis_identity_revision` 在[后端config](../config.yaml)。本目录的 `workload.yaml`、`provision.sops.yaml`、`runtime.sops.yaml`、`kustomization.yaml` 由 `application-stage APP=knowlab` 从[共用模板](../../../common/backend/redis/workload.yaml.j2)生成，不手改；生成前目录只有本说明（`stages.py` 要求阶段目录存在）。

尚未部署（qwen-003 D 段）。操作流程见[应用维护](../../../../../../infrastructure/applications/README.md)。
