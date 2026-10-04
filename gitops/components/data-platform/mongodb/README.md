# MongoDB

用户配置在本目录 config.yaml；当前采用正式9.0.2-noble，版本/amd64摘要唯一取 infrastructure/artifacts/upstream-images.lock.json。配置、实现、初始化与验收同目录维护，不调用旧chart或部署脚本。

## 运行与身份

data-platform-dev/mongodb-0，内部 TLS 服务 mongodb.data-platform-dev.svc.cluster.local:27017；单成员副本集 sunmoon，支持事务，**不具备高可用能力**。20Gi静态Retain卷绑worker2，节点内/data/kind-local-storage/mongodb，宿主独立盘/data/kind-clusters/sunmoon-kind/worker2/static/mongodb。PVC声明20Gi不是ext4磁盘配额。

/etc/sunmoon/services/sunmoon-kind/mongodb.yaml保存独立管理员、内部副本集密钥和验收账号，root0600；独立备份在/mnt/sunmoon-data/backups/services/sunmoon-kind/mongodb.yaml。TLS目录mongodb-tls同样备份，Git只保存SOPS密文，既有身份不得自动重生成。应用未来须另建各自逻辑库和账号，不能使用root或验收账号。

官方entrypoint仅在空数据目录中临时监听loopback创建root，最终进程requireTLS+认证+keyFile。独立初始化Job建立副本集和只拥有sunmoon_acceptance库readWrite的验收用户；既有副本集必须与声明一致，不自动reconfig、不盲目重置口令。headless Service使用publishNotReadyAddresses供初始化DNS；Ready验证认证TLS ping，独立Flux初始化与服务验收确认PRIMARY，避免初始化依赖死锁。

容器UID999、只读根目录、drop ALL、禁用SA令牌；仅允许Mongo自己与显式初始化Job，无公网端口。CA和DNS名称严格校验，不启用无效证书/名称绕过。

## 日常操作

物料：make -C infrastructure services-materials SERVICE_IMAGES=mongodb，再services-publish同参数。候选：make -C infrastructure services-stage；审核、本地提交、发布并晋级固定Flux source，步骤见infrastructure/services/README.md。统一部署：make -C infrastructure services-bootstrap；日常核验：make -C infrastructure services-check。

开关控制候选声明，不隐式删数据；Flux prune:false，不靠关闭开关清除既有资源。已完成Job变更需新generation并审核。每次验收仅写独立库的唯一随机collection，验证CRUD、提交/回滚及匿名/跨库/管理权限拒绝，然后精确清理本次collection。整机/集群重启、备份恢复及业务驱动适配须分别验收。

官方依据：[9.0发布说明](https://www.mongodb.com/docs/manual/release-notes/9.0/)、[官方镜像构建](https://github.com/docker-library/mongo/tree/6d9f651b25238502cb141313df49d6215e9b44ac/9.0)、[keyFile副本集](https://www.mongodb.com/docs/manual/tutorial/deploy-replica-set-with-keyfile-access-control/)、[TLS配置](https://www.mongodb.com/docs/manual/tutorial/configure-ssl/)。
