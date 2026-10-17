# investment → knowlab 服务身份（read）

分身运行时读用户自己绑定的数据：工作台按委托核过，再向 knowlab 读（[SDD 0027](../../../../../../docs/dev-investment-agent/tree-build/SDD/modules/0027-knowbot-first-path.md) §3.5，契约 `knowbot-data/v1`）。配置是[后端config](../config.yaml)的 `service_clients` 里 target=knowlab、relation=read 那一项，机制在[通用出站服务身份](../../../common/backend/service-client/README.md)。本目录的 `workload.yaml`、`provision.sops.yaml`、`kustomization.yaml` 由 stage 生成，不手改；生成前目录只有本说明（`stages.py` 要求阶段目录存在）。

在 Casdoor 里建独立组织 `sunmoon-workload-investment-knowlab-read` 与只有 client_credentials 的服务应用，scope `knowlab:read`；私有输入 `service-client-knowlab-read.yaml` 主备逐字节一致，丢了先恢复，不重新生成。knowlab 按自己的 `service_receivers` 从这里推出受众、主体与 scope 来校验令牌，入口是 traefik service-access 的 `service_access_routes.knowlab`。

尚未部署（随 0027 P6 一起发布）。
