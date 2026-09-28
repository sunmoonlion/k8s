# 独立 Harbor 的跨集群信任

本地 KIND 和云集群都从独立仓库 `harbor.sunmoonai.com:30443` 拉取。Harbor 不属于 C1，也不能把 C1 的 Secret 当作 CA/密钥的唯一来源。

- 仓库地址、证书与私有凭据来源在 `registry-platform/config/` 及其明确引用的私有目录中。
- Docker、节点 containerd、Pod/CI 分别配置 CA 和凭据，并实际核验；宿主客户端成功不能代替节点验收。
- 本地 30443 由 SNI 直通代理分流；云上独立仓库主机无需这一层共享入口。
- Traefik 组合式证书分发库继续保留自身用途；不要通过运行旧的跨集群 rotate/force 示例来为新 Harbor 重建根 CA。

具体步骤见 [客户端说明](../../sunmoonai/registry-platform/docs/clients.md) 和 [Harbor 迁移方案](../../sunmoonai/kind-infrastructure/docs/harbor-external-integration-plan.md)。云端仍未经实机验证。
