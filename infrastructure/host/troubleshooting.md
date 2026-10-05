# WSL、挂载与认证故障定位

先看[宿主责任](README.md)，执行均从k8s根目录。以下检查只读取状态；重启、提权、磁盘压缩和入口切换按相应维护范围执行。

## 数据盘/服务看到的目录不一致

```sh
findmnt -T /mnt/sunmoon-data
findmnt -T /data/kind-clusters
findmnt -T /data/harbor
systemctl status docker --no-pager
```

1. 对照[UUID及fsroot](config.yaml)，确认新数据盘确已附加。目录存在而目标仍落在WSL系统盘时停止启动。
2. 检查systemd与Docker的mount namespace可见性。Harbor启动守卫会做Docker只读stat对照；不能仅凭当前shell通过宣布修好。
3. Windows侧核对当前附盘任务指向的新VHDX与管理脚本、启用状态、上次结果及维护标记。旧D/E盘任务不能作为现在自动挂载的证明。
4. 挂载修复只恢复已有UUID；禁止运行初始化/mkfs、覆盖原始存储路径或改变节点卷。

当前新代码未交付整套开机恢复，出现UAC时先核对发起程序及任务账号/权限；不要添加一分钟一次的重复提权轮询。修复后需实际开机验证，而非只看任务配置。

## 重启后集群或域名反了

```sh
make -C infrastructure cluster-status
make -C infrastructure registry-status
make -C infrastructure entry-status
```

新环境是sunmoon-kind，原始kind是受保护旧环境。Docker重启策略、旧容器和端口监听可使旧控制面自动占用30443；查实际监听者、容器身份及systemd状态，按获批维护顺序恢复。禁止按名字批量start/stop全部容器。

节点IP/网桥gateway变化可能使CoreDNS或Harbor解析仍指旧地址；比较集群配置与实际Docker网络、节点hosts/containerd信任。`cluster-pull-check`检查三节点实际拉取和DNS；它需要已恢复的Harbor/入口，不替代修复开机编排。

## Docker认证拉取失败

按顺序区分DNS/代理→TCP→证书链与域名→`/v2/`401 challenge→token realm/CA→身份期限与权限→manifest→全部blob。

```sh
docker version
make -C infrastructure registry-status
make -C infrastructure registry-accounts
make -C infrastructure registry-publish-check
```

后两项分别可能创建/恢复机器人身份、写入并拉回验收镜像，有副作用；不是只读诊断。使用前读[仓库身份手册](../registry/README.md#项目和受限身份)。

已核实Docker29.4.3认证token请求忽略专用CA的问题，29.8.1通过实际拉取；这是有日期的兼容性结论，不是以后任何x509报错都应升级Docker。CA文件存在、skopeo成功或镜像缓存命中均不等于Docker实际认证拉取成功。保留CA/摘要验证，禁止改insecure registry绕过。

## Docker维护前必须保存的状态

这不是自动升级操作卡。安排Docker维护前记录版本/包来源、storage driver及data-root、容器ID与原运行/停止状态、完整restart policy、卷集合、所有挂载及节点IPv4/IPv6；同时保存入口三文件和匹配冷备。比较挂载按Destination排序，不能因inspect列表顺序不同误判变化。

停机范围包含Docker socket，避免服务被自动拉起；仅恢复原运行对象，原停止节点不自动启动。重启策略与动态节点地址会影响旧控制面抢入口、Traefik恢复和DNS，不能只凭容器Running宣布恢复。先数据盘/Docker→仓库后端→需要的集群/Traefik→公共代理，再验TLS/token、真实镜像拉取与应用路由；明确保持停止的对象仍须保持停止。实际顺序要按届时监听和依赖核定，不复制历史main/136恢复步骤。

## Flux/Pod失败的初步分层

声明发布候选≠晋级，OCI Ready≠子阶段Ready，Pod Running≠协议/权限/持久化通过。先查[Flux源及字段归属](../flux/README.md#故障与退回)，再查组件README。

初始化失败保留精确Job代次/错误；不要删除PVC、重生成口令或force apply。网络下载错误按[构建网络流程](../applications/README.md#下载失败与代理)处理，证书/签名/哈希错误不属于自动切源。
