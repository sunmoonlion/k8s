# 存储、网络与运行安全基线

config共享来源在[site](../../../infrastructure/environments/kind/site.yaml)及各组件volume字段；render/stage入口由[services](../../../infrastructure/services/README.md)提供，基础SOPS/声明协调由[Flux](../../../infrastructure/flux/README.md)提供。

## 对象责任

- runtime：业务命名空间、service account、默认token禁用、LimitRange、默认拒绝网络等；共享对象只声明一次。
- network：DNS及PG/Redis/Rabbit/存储/检索等按namespace和客户端标签明确允许；缺标签拒绝，不为排障开放任意出站。
- storage：静态StorageClass及组件PV/PVC；namespace来自各组件责任映射，数据卷节点由volume配置约束。
- puller.sops：各平台独立拉取Secret；只读身份来自仓库，age私钥属于Flux。

## 静态与动态存储

PV集群作用域、PVC属于namespace。每个静态卷指节点内/data/kind-local-storage/<组件>，对应三节点独立宿主static目录，Retain防止声明删除时隐式回收。声明size不是ext4配额；改size不扩数据VHDX，改node/path不迁移已有数据。

KIND默认local-path目录也独立bind到数据盘dynamic，节点容器不作为唯一持久介质。[节点挂载](../../../infrastructure/cluster/README.md#配置和存储)描述准确路径。

已有PVC不能改namespace；已有PV的claimRef/UID不可套历史patch重新认领。跨namespace迁移需一致备份/恢复、停止写入、核数据/权限/身份并显式发布，当前没有通用自动迁移入口。

## 使用与失败边界

```sh
make -C infrastructure foundations-bootstrap
make -C infrastructure foundations-check
```

bootstrap安装SOPS并协调晋级基础声明，有API写入；check核声明/拉取/安全配置。服务检查的随机Pod另验证允许/拒绝边界，不打印凭据。密文恢复见[secrets](../../../infrastructure/flux/secrets.md)。

共享namespace已包含业务应用统一app-platform-dev，Casdoor database Job在data，而Casdoor init/runtime在app。目录归属不等于运行位置。所有数据/Secret/Job保留，失败不能用删PV/PVC或放开网络绕过。完整机器/删群持久化和备份恢复见[未完成项](../../../docs/platform-kind-v1/verification.md#未完成项)。
