# Secret 与证书模块的职责

| 模块 | 接口/调用方 | 保留原因 |
| --- | --- | --- |
| `secret-management/lib/secret-core.sh` | 参数化生成 TLS、Docker、Opaque、Basic、SSH Secret YAML；被多个组件调用 | 通用生成库 |
| `secret-management/lib/secret-data.sh` | 组件的数据准备；仓库认证读取独立配置/私有文件 | 组件接口不能用组合式接口替换 |
| `secret-management/lib/cert-core.sh` | 从已有 CA 生成叶证书；Traefik 生成器调用 | 不负责独立 Harbor 的生命周期 |
| `unified-cert-secret-management/` | 组合配置、服务端/客户端插件和分发；`ensure-kind-ca.sh` 等仍使用 | 是分发层，不能因为也有 secret-data/common 文件就整目录删掉 |

两套 `secret-data.sh` 的函数名虽有交集，参数和配置协议不同。本次只合并逐字节相同的规范/示例文件，权威位置为 [证书规范](secret-management/lib/README-specifications.md)。没有改变证书、密钥或轮换策略。

独立 Harbor 配置和客户端信任用 [registry-platform](../sunmoonai/registry-platform/README.md)；不从某个集群的 Secret 自动重建唯一 CA，不把旧组合式分发当作新仓库安装步骤。
云 SSH 分发、旧 CA 同步/轮换和真实消费者验收仍须按迁移计划处理；代码保留不是生产验证通过。
