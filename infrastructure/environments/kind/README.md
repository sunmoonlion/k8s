# KIND 共享环境输入

这里仅保存跨模块共享参数与发布身份；专属参数留在对应模块config.yaml。现有Make入口的 `make config` 列出全部普通配置。

| 文件/字段 | 职责与修改边界 |
| --- | --- |
| site.yaml / cluster_name | 共同集群身份；当前sunmoon-kind，多个守卫明确限定；已有集群改名需重建/迁移，不是一次替换 |
| site.yaml / registry_address | 固定外部仓库地址harbor.sunmoonai.com:30443；镜像引用、信任和认证共同依赖，不随单模块改端口 |
| site.yaml / artifact_cache_root | 已校验物料的共同根；改路径前准备完整材料并核对摘要，不允许指向临时缺包目录 |
| site.yaml / data_namespace、messaging_namespace、app_namespace、ingress_namespace | 平台命名空间身份；当前渲染守卫限定已批准值，已有资源变更需明确迁移 |
| flux-source.yaml / repository、digest、revision、path、requires_sops | 一个不可变发布的源地址/摘要/源码提交/根路径/解密要求；通过发布候选审查晋级，不当作普通字符串随意编辑 |
| sops-recipient.txt | 当前加密公钥；必须与独立私钥/备份及已有密文配套。换公钥不等于完成密钥轮换 |

这里不保存明文密码、kubeconfig或age私钥。当前仅KIND实现，不宣称通过复制该目录就能完成云端部署。
