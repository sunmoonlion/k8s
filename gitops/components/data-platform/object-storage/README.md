# 对象存储（AIStor）

配置、许可准备和 StatefulSet 模板在本目录；版本摘要唯一引用 infrastructure/artifacts/upstream-images.lock.json。
现有 services-render/stage/bootstrap/check 入口统一管理，Flux 是唯一应用声明的执行者。

KIND 是单节点单卷验证配置：Retain 静态 PV，固定 worker2、UID/GID1000；不是高可用或硬件故障保护。
运行 HTTPS9000，内部证书由平台 CA 签发；Console9001不公开。
root 与许可从只读 SOPS Secret 文件加载；业务应用必须独立账号、独立版本化存储桶，不得持有 root。
已有许可只复制不迁走；私有文件 /etc/sunmoon/services/sunmoon-kind，非覆盖备份 /mnt/sunmoon-data/backups/services/sunmoon-kind。
许可签名与可用性以真实 S3 请求为准，不能以 JWT 可解析或 Pod Running 宣布通过。
无对象、镜像、许可或备份的自动删除规则。

依据：[官方容器运行说明](https://docs.min.io/aistor/installation/container/install/)。
云上多节点部署与许可范围须单独确认；本阶段不宣称云上已实机验证。
