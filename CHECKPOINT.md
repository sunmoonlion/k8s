# 新体系交接状态（2026-10-05）

本文件只保留当前续接需要的事实；历次开发过程从Git及私有证据取得，不作为日常维护入口。工作树 `/home/zymun/worktrees/platform-kind-v1/k8s`、分支 `platform-kind-v1`，五仓并列；当前只修改k8s新体系，不push，不改业务仓、旧sunmoonai或冻结Luna参考。

## 已完成单元与批准边界

所有者批准第二个两小时窗口：2026-10-05 08:25:05–10:25:05 UTC（16:25–18:25 CST）。范围是ES永久修复发布、整套统一停启、Harbor全目录摘要与真实节点拉取；不关闭WSL、不删除重建集群。停服前在执行进程内复核时间，预留15分钟恢复。当前开发阶段容量底线10GiB，仍扣除数据盘长满230GiB的增长及操作预算；进入真实服务阶段再确定运维约束。

## 已完成的运行状态

- 原生 Make→独立Ansible模块→Flux/SOPS；已有环境整套platform-deploy、统一platform-check已通过。修复说明文档误入发布门禁后，最后一次完整platform-deploy退出0，46个recap全部failed/unreachable=0；最终健康及Harbor/资产比对均通过。完整原始日志归档到本节私有证据，不保留/tmp作为依赖。
- 独立root运行副本 `/opt/sunmoon/host/sunmoon-kind`、统一target、cluster/boot单元及Harbor/entry依赖已安装。Windows `sunmoon-data-mount` 为所有者登录触发、Highest/Interactive、无分钟周期，实际执行0；固定输入在管理员持有的ProgramData目录，不依赖worktree。
- 六个新旧节点 restart=no；旧Linux附盘单元disabled、新boot enabled。boot当前inactive，因为通过手动start恢复；不能当作真实开机证明。新target/cluster/Harbor/entry active。
- 新三节点sunmoon-kind运行、Ready；原始kind控制面停、两个worker运行。57个Running Pod全部Ready、33个Completed Job保留；51个Flux阶段当前代次Ready，13组PV/PVC Bound/Retain。
- 第二窗口两轮完整stop/start和重复start通过；重复start前后90个Pod UID和重启计数一致。平台/四应用真实公共协议、Harbor认证推拉、三节点Always认证拉取和DNS通过。所有节点、Docker卷、业务卷与数据保留。

## 固定身份与路径

- kubeconfig `~/.kube/sunmoon-kind.config`，context `kind-sunmoon-kind`；kubectl `infrastructure/.tools/bin/kubectl`。Kubernetes1.36.5、KIND0.33.0、Calico3.32.2；版本事实源为物料/image锁。
- kube-system UID `67d27d4a-f9ad-4f01-a37f-225144cacaef`；节点精确ID/挂载事实源 `/data/kind-clusters/sunmoon-kind/bootstrap/identity.json`，不要手写复制ID执行删除。
- Harbor2.15.2，宿主后端11443，公共仓库 `harbor.sunmoonai.com:30443`；独立数据 `/data/harbor/platform-kind-v1`。新集群入口29443、API27443。
- 数据盘230GiB，UUID `a28de356-4ba1-4a21-93f5-744b9b9d8be0`，`/mnt/sunmoon-data` bind到 `/data/kind-clusters` 和 `/data/harbor`；禁止覆盖 `/data/kind-local-storage`。同C物理盘，不防硬件故障。
- 新物料根 `~/k8s-packages`，唯一配置site.yaml；旧物料根仅供原始部署。真实秘密在各模块私有配置/独立备份和SOPS，不能输出或提交。
- 已晋级源 revision `a49760273f05320f16231647d253e25541a94e1f`，digest `sha256:9f7bce56f15708fa015a8c967b32f7f802724e50bab4aebb60ee02676140b33f`。文档/宿主修复提交不自动改变晋级源。

## 本单元修复与证据

1. ES emptyDir保留0440TLS副本导致普通cp重启失败。原模板改 `cp --remove-destination`，保留Secret/数据/权限；a4976027发布、3ef5f402晋级，实际镜像重复复制、滚动及两轮冷启动通过。一次临时权限恢复只为先恢复现网，不成为日常依赖。
2. Docker重写节点hosts丢失Harbor网关，解析127.0.0.1后误访问节点Traefik证书。19191323在原ready/start恢复拥有节点的精确网关记录；未关TLS、未改代理/外部DNS。拉取探针另修正shell参数转义并保存失败Job/events。
3. 原生Windows安装器规范化短账号SID；Bash JSON比较加引号；容量脚本在本地C路径与root副本核对，不绕过RemoteSigned；API readyz、Pod/Flux加入有界收敛等待。
4. 3b4a6912只排除组件README参与晋级对象diff；全GitOps工作区仍须提交，所有其他文件仍严格匹配。只读核对接受README差异、拒绝实际ES声明差异；原失败总入口日志保留。
5. 第二窗口基线40仓库/104镜像条目；data完整冷态清单2676文件。registry/secret共1086文件、13,210,981,875字节路径/大小/SHA256完全保持。24处可变内容仅23个PostgreSQL文件及1个Redis文件；不声称数据库物理字节不变。完整目录逻辑digest/标签/大小、PV/PVC及Job身份、六节点ID/挂载/运行态、Docker卷集合比对通过。

私有证据 `/data/kind-clusters/sunmoon-kind/bootstrap/evidence/lifecycle-maintenance-20261005T0825Z`；前窗口0419Z独立保留。原安装回退 `/mnt/sunmoon-data/backups/host/lifecycle-a2gzkked`。原窗口等管理员操作后已到期，停服前未重新核对；发现后结束新增停服并恢复。失败原始记录不得覆盖为成功。

## 日常入口与后续顺序

日常维护以docs/README.md和模块手册为准：platform-deploy/start/stop/status/check均由 `make -C infrastructure` 调用，保留模块配置开关及单组件入口。修改声明仍render/stage→审阅提交→flux-release→显式晋级→原生bootstrap，不自动部署未批准配置。

1. 本单元完整部署/两轮启停/镜像与卷验收已完成。临时日志和一次性助手逐字节归档后清理；实际运行文件、任务输入、原任务XML及必要回退备份保留。
2. Windows/WSL DNS和系统CA信任、真实浏览器访问；准备具体恢复操作卡后另批真实Windows/WSL关闭/重启。当前任务执行时盘已挂好，不证明缺盘冷启动。
3. 单独维护批准后执行KIND删除重建持久化验收：保护原始kind与Harbor，核对全目录/全部镜像摘要并由新节点认证拉取。不能用当前启停通过代替。
4. 长期空间管理：统一查看/预览/执行，持续容量/告警、Harbor保留GC、构建缓存、日志/索引和备份轮换；删除政策先确认，保护在用/回退镜像及必要备份。只已有批准日志轮转自动运行。
5. 数据库/对象原文/私有输入完整备份恢复、机器外落点待所有者选定；安全门禁/官方修复跟踪、按需身份轮换、业务完整功能和云端建群实机验证仍未完成。
6. 最终清理与维护文档收敛；保护原始kind、新体系及所有者指定Luna参考。本轮未使用东京；不能泛删别人/tmp或原始代码/数据。
