# 首批平台服务

本期使用新体系的 Make/Ansible 准备物料与私有输入，Flux 从已提交、固定摘要的 OCI 声明部署。旧 `sunmoonai` 组件脚本不是运行依赖。

## 固定版本与部署顺序

| 项目 | 版本 / 实现 | 持久化 |
|---|---|---|
| Traefik | 3.7.13，官方 chart 41.6.0；Helm 4.3.0 用于离线 chart 发布 | 无业务数据 |
| PostgreSQL | 18.6-trixie，官方镜像 | worker/static/postgresql，8 GiB PVC |
| Redis | 8.10.2-trixie，官方镜像；AOF everysec | worker2/static/redis，2 GiB PVC |
| RabbitMQ | 4.3.6-management，官方镜像 | worker2/static/rabbitmq，4 GiB PVC |
| Casdoor | 4.12.0，官方镜像 | 独立 PostgreSQL 库/角色；worker/static/casdoor，1 GiB PVC |

版本与 manifest 摘要见 `platform/artifacts/upstream-images.lock.json`，安装包与 chart 摘要见 `files.lock.json`。安装包、OCI 归档、chart 分别存入正式物料目录的 `packages/`、`images/`、`charts/`。五个服务镜像及 chart 已发布至新 Harbor，节点按摘要从 Harbor 拉取。

Flux 顺序：`platform-services`（存储、入口、三个数据服务）→ `casdoor-db`（独立库/角色 Job）→ `casdoor-init`（身份初始化 Job）→ `casdoor`（服务）。数据目录是新集群三个节点独立挂载中的专属子目录；PV 使用 `sunmoon-static`、显式 nodeAffinity、Retain。15 GiB PVC 容量声明不是立即分配 15 GiB；本地 PV 的容量字段不是目录配额，实际占用另行监控。所有阶段 `prune:false`，禁止借配置变更自动删除数据。

本期都是单副本，适用于当前本机验证。跨主机高可用、数据库一致性备份与独立恢复、WSL/KIND 重启与删除重建验收、应用链路并未由本页替代。

## 配置和 Secret

- 普通字段：`platform/environments/kind/services.yaml`，包含各组件启用开关、命名空间、数据库名/角色、域名与卷位置。
- 私有输入：`/etc/sunmoon/services/sunmoon-kind/credentials.yaml`，root:root 0600；目录 0700。
- 独立副本：`/mnt/sunmoon-data/backups/services/sunmoon-kind/`，包含输入和 TLS 身份；与系统盘同一物理硬盘，不是机器外灾备。
- Git 只存 SOPS 密文。原始密码表仍只是所有者的集中查阅表；新运行链不读取旧 `.conf` 或密码表，不执行旧脚本。
- 本次一次性按字面值导入原 PostgreSQL 管理员、Casdoor 数据库、Redis、RabbitMQ 用户/密码/cookie 六个字段；没有执行配置文件。新 Casdoor 初始管理员密码单独生成，保存在上述私有输入中，不在对话/日志展示。
- `services-credentials`：有输入时保留；主输入缺失时从备份恢复；只有未声明的全新环境才生成随机凭据。已经存在加密声明却同时丢失输入和备份时拒绝重新生成，要求恢复。
- 修改密码不等于修改运行数据库密码。凭据轮换必须单独编排数据库/客户端更新、验证和备份；当前入口会拒绝私有输入与备份不同，或候选与已提交声明不同，避免把修改静默当成成功。

私有输入字段为 `service_credentials` 下的 `postgresql_password`、`redis_password`、`rabbitmq_username`、`rabbitmq_password`、`rabbitmq_cookie`、`casdoor_db_password`、`casdoor_admin_password`。`casdoor_application_secret` 预留给后续应用注册，本期未用于业务 OAuth 客户端。

Casdoor 的 `/server -export` 在导入初始身份之前退出，因此首次 Job 启动隔离服务、等待可用，再写入 `/files/.initialized-v1`。随后停止初始化进程；正式服务不配置 init_data 导入。存在完成标记时初始化 Job 仅运行无身份覆盖的数据库导出检查，防止集群重建重置管理员。该标记应与 Casdoor 文件卷和数据库一起备份；本期尚未验证这些数据的整套恢复。Casdoor 官方服务仍有内置 schema 初始化行为，不将其冒充业务应用的独立迁移链。

## 入口和操作

新 Traefik 监听新集群 NodePort 30443，经宿主 `127.0.0.1:29443` 验收。Casdoor 域名不变、证书沿用平台 CA 签发，有效期五年。**宿主 30443 的应用分流仍指向原集群，本批不切换。** 浏览器常用域名当前不能据此视作已切到新 Casdoor。

```bash
cd /home/zymun/worktrees/platform-kind-v1/k8s/platform
make services-plan                 # 五个固定镜像来源与目标
make services-credentials          # 初始化/恢复私有输入
make services-materials            # 准备缺失的压缩 OCI 归档
make services-publish              # 发布缺失的 Harbor 内容；不同摘要标签拒绝覆盖
make services-tools services-chart # 校验 Helm；发布并完整拉回核对 chart
make services-render              # 生成 .build/services 下可审查候选，不直接写 Kubernetes
make services-validate-release     # 配置、解密后的 Secret 与已提交晋级版本必须一致
make services-bootstrap            # 已晋级版本的一键部署与实际验收
make services-check                # 实际数据库/消息/身份验收
```

常规容量门槛保持 50 GiB。2026-10-03 所有者为这一批特批 40 GiB、最多新增 5 GiB，使用有期限和操作范围的外部参数，本批结束撤销，不作为日常绕过门槛的方法。

`services-bootstrap` 顺序执行凭据检查、离线镜像验证/发布、工具/chart、候选生成、与晋级声明比对、Flux 协调和功能验收。已改配置但未提交发布时明确失败；不会“执行成功但用旧配置”。首次准备依赖已有 Harbor、KIND、Flux/SOPS 及已备齐包，本入口是首批服务单元，完整宿主到应用的一键编排仍是后续交付项。

变更发布流程：修改普通配置或私有输入 → `services-render` → 审查 `.build/services/{core,casdoor-db,casdoor-init,casdoor}` 与 `stages.yaml` → 将候选晋级至 `gitops/components/services/` 和 `gitops/clusters/kind/services.yaml` → 本地 Git 提交 → `make flux-release` → 将 `.build/flux/source-candidate.yaml` 晋级到 `environments/kind/flux-source.yaml` → `make services-bootstrap`。发布器递归校验各子阶段不存在明文 Secret，发布源只来自 Git 对象。

开关控制新声明包含的工作负载；因 `prune:false`，把开关改 false 不会暗中卸载已经存在的服务/卷。全平台启停和组件退役需要后续生命周期入口，不以该开关替代。

## 验收范围及已知变更

`services-check` 核对拥有的 kube-system UID、当前 Flux generation Ready、四个 PV Bound/Retain/目录，然后执行 PostgreSQL 临时事务读写、Redis 有过期时间的唯一键读写并删除、RabbitMQ 临时队列发布/取回并删除、Casdoor 经 TLS 入口登录和会话读取。凭据经私有输入/stdin/cookie 文件传递，临时 cookie 和端口转发在 finally 中清理。

RabbitMQ 使用管理 API 完成真实消息路由/取回，**尚不是业务客户端 AMQP 链路验收**。4.3 默认不再接受非持久非独占队列，验收改为 durable classic + 队列 TTL，不开启废弃功能。后续应用客户端的队列声明需单独核对。[官方队列说明](https://www.rabbitmq.com/docs/queues#durability)

Traefik chart 41.6 使用 `log`、`accessLog`，`versionOverride` 在 values 根层；首次错误已修正。官方 Helm schema/模板校验通过后才晋级修正版本。此前失败记录保留，不能用最后 Ready 覆盖第一次失败事实。

机器侧证据在 `/data/kind-clusters/sunmoon-kind/bootstrap/evidence/services/`；日志归档在相邻带日期目录。数据库与消息验证通过不等于业务 App、完整登录/授权体系、网络策略的客户端覆盖和持久化重建已全部通过。
