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

## 配置与日常使用

| 字段/输入 | 位置与边界 |
| --- | --- |
| 开关、资源、节点、卷声明容量 | 本目录 config.yaml；已有数据换节点需备份迁移，不能直接改节点后当作空盘初始化。 |
| HTTPS9000、Console9001、区域 | 本目录 config.yaml；当前入口守卫固定端口，应用引用同一来源。 |
| root 用户与口令 | /etc/sunmoon/services/sunmoon-kind/object-storage.yaml；只初始化一次，已有声明丢失输入必须从备份恢复。 |
| 许可 | 配置指定旧输入文件，复制到上述私有目录和独立备份；原输入不移走，真实 S3 已验收接受。 |
| 应用用户名、桶、Job revision | 各应用后端 config.yaml.object_storage；应用口令在该应用 private_dir/s3.yaml。 |
| 镜像版本/摘要、管理客户端 | infrastructure/artifacts 的统一锁，无 latest 运行引用。 |

20Gi 是静态 local PV 声明容量，不是 ext4 子目录硬配额，不能据此承诺不会填满数据盘。容量监控/保留与备份轮换属于后续统一空间管理交付。

2026-10-03：services-bootstrap 实际通过已有许可、TLS CA 验证、版本化对象写入/读回与摘要核对。信息应用进一步通过实际 ObjectStorage 的两版本读取、跨桶拒绝及桶管理拒绝；验收数据版本由限定 root 探针清除，业务版本没有删除。
