# KIND共享环境与晋级身份

[site.yaml](site.yaml)只保存跨模块共用`cluster_name`、`registry_address`、`artifact_cache_root`及四个平台命名空间。模块参数在自身config，版本在锁，秘密在私有输入/SOPS；保持一个来源。

| 字段 | 维护条件 |
|---|---|
| cluster_name | 集群/目录/receipt/私有输入相关身份；当前实现明确sunmoon-kind，不是任意重命名入口 |
| registry_address | 公共仓库契约；域名/端口改变联动证书、镜像引用和节点/客户端信任 |
| artifact_cache_root | 正式物料路径；先核锁内文件完整与生成依赖，再迁移路径 |
| data/messaging/app/ingress_namespace | 共享运行位置；应用都用app_namespace；已有PVC/身份跨namespace不是热改配置 |

Makefile显式加载模块/组件config再加载`SITE`，当前默认本文件。不要引入同名重复字段依赖覆盖顺序维持“两个默认值”。

[flux-source.yaml](flux-source.yaml)保存已晋级repository/digest/revision/path/requires_sops，它们必须对应同一个真实已发布Git产物；当前path为`./clusters/kind`。公共加密recipient在[sops-recipient.txt](sops-recipient.txt)，私钥工作树外。

日常流程见[Flux发布与晋级](../../flux/README.md#发布与显式晋级)、[组件配置分类](../../../gitops/components/README.md)。修改共享身份需独立迁移、备份、恢复与验收安排，不能通过覆盖参数绕开原生守卫。
