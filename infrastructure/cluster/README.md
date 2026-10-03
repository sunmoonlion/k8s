# KIND 建群

- `config.yaml`：建群开关、API/入口端口、网段、数据根、kubeconfig、操作用户和建群容量预算。
- `kind.yaml.j2`、`calico-kustomization.yaml.j2`：消费配置的原生模板。
- `deploy.yaml`、`build-node.yaml`、`pull-check.yaml`：创建、节点物料构建、拉取验收。
- `node.yaml`：每个节点的仓库信任、离线 CNI 导入及持久挂载核对；版本摘要仍由 `../artifacts/` 锁定。

从 `infrastructure/` 使用 `make cluster-plan`、`make cluster-deploy`、`make cluster-status`。
共享集群名在 `../environments/kind/site.yaml`；不要在本模块重复填写。
完整边界见 [集群操作](../../docs/platform-kind-v1/cluster.md)。此模块当前实现 KIND，云端建群没有实机验证。

## 配置字段与修改条件

配置真源为本目录 `config.yaml`，由现有Make入口明确传给Ansible。下表说明当前支持边界；有字段不等于已有实例可直接修改。

| 字段 | 用途 | 修改条件与限制 |
| --- | --- | --- |
| `cluster_enabled` | 建群/配置动作准入 | 不代表现有节点的停止或删除；生命周期入口仍需后续完成。 |
| `cluster_api_port` | API宿主端口映射 | 当前27443；建群参数，已有配置与期望不同会拒绝复用，不自动重绑。 |
| `cluster_ingress_port` | 入口宿主端口映射 | 当前29443；建群参数。当前Casdoor验收程序仍写死29443，任意端口尚未贯通。 |
| `cluster_pod_subnet` | Pod网段 | 创建参数，变更需要网络/建群方案；不能作为已运行集群日常调整。 |
| `cluster_service_subnet` | Service网段 | 创建参数，已有集群变更需要重建与依赖核对。 |
| `cluster_data_root` | 三个节点独立持久目录的根 | 当前守卫限定/data/kind-clusters；搬迁要核数据盘及全部挂载。 |
| `cluster_kubeconfig` | 本集群独立访问文件 | 包含访问身份，不提交Git；新建不得覆盖既有文件，路径变更要同步调用方。 |
| `cluster_operator` | 宿主操作用户/文件属主 | 不是Kubernetes应用用户名；需真实用户、权限与路径配套，未验任意用户切换。 |
| `cluster_create_budget_bytes` | 建群新增预算 | 与宿主容量门禁一起计算；不是资源配额，也不能代替实际物料容量。 |

固定约定：本期1个控制面和2个worker、节点内静态路径/data/kind-local-storage、入口NodePort30443。节点数量不是已实现的用户配置项。版本和镜像摘要取artifacts锁，节点内路径与PV模板配套。当前只支持KIND已验环境；云上入口尚未实机验证。
