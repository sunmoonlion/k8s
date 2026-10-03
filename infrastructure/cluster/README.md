# KIND 建群

- `config.yaml`：建群开关、API/入口端口、网段、数据根、kubeconfig、操作用户和建群容量预算。
- `kind.yaml.j2`、`calico-kustomization.yaml.j2`：消费配置的原生模板。
- `deploy.yaml`、`build-node.yaml`、`pull-check.yaml`：创建、节点物料构建、拉取验收。
- `node.yaml`：每个节点的仓库信任、离线 CNI 导入及持久挂载核对；版本摘要仍由 `../artifacts/` 锁定。

从 `infrastructure/` 使用 `make cluster-plan`、`make cluster-deploy`、`make cluster-status`。
共享集群名在 `../environments/kind/site.yaml`；不要在本模块重复填写。
完整边界见 [集群操作](../../docs/platform-kind-v1/cluster.md)。此模块当前实现 KIND，云端建群没有实机验证。
