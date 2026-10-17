# knowbench → knowmart 服务身份（summon）

工作台「请分身」后向 knowmart 取分身清单（SDD 0027）。配置是[后端config](../config.yaml)的 `service_clients` 里 target=knowmart、relation=summon 那一项，机制在[通用出站服务身份](../../../common/backend/service-client/README.md)。本目录的 `workload.yaml`、`provision.sops.yaml`、`kustomization.yaml` 由 stage 生成，不手改；生成前目录只有本说明（`stages.py` 要求阶段目录存在）。

在 Casdoor 里建独立组织 `sunmoon-workload-knowbench-knowmart-summon` 与只有 client_credentials 的服务应用，scope `knowmart:summon`；私有输入 `service-client-knowmart-summon.yaml` 主备逐字节一致，丢了先恢复，不重新生成。knowmart 按自己的 `service_receivers` 从这里推出受众、主体与 scope 来校验令牌。

尚未部署（随 0027 P6 一起发布）。
