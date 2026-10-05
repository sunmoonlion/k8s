# 逐份文档与逐文件代码处置表（待审定）

主方案：[新体系文档维护化重构方案](maintenance-docs-proposal.md)。基线完整身份：[522文件清单](maintenance-docs-baseline.json)。

审阅基线：`d869c6370f7ec840c3bdd930e0b8158ccc2bd72f`。67份Markdown均有单独的内容处置；455个其余文件均有职责与保留理由。以下路径都相对k8s工作树根目录。

**这是一份方案，不是已完成的重构清单。** 目标路径为拟定去向；旧文档在确认内容覆盖、更新引用之后才删除。代码静态阅读及解析不等于执行所有分支或完整安全审计。

## 一、67份现有Markdown逐份处置

### D01 docs/platform-kind-v1/architecture.md

- 原文件：[docs/platform-kind-v1/architecture.md](../docs/platform-kind-v1/architecture.md)，208行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`docs/platform-kind-v1/architecture.md`。
- 当前内容与问题：208行混合架构草案、实施单元、历史待办与最新约定；对外已有引用，应维持路径。
- 必须保留/补齐：宿主机/仓库/入口/集群/控制器/应用职责；声明所有权；就近配置；命名空间分类；单机数据与安全边界；2小时、10GiB最新约定。
- 删除/改写：初期第一实现单元、尚未建立Flux/应用等已过期计划；重复版本表及临时阶段承诺；旧容量例外。
- 核对依据：[infrastructure/Makefile](../infrastructure/Makefile), [infrastructure/services/layout.yaml](../infrastructure/services/layout.yaml), [infrastructure/cluster/kind.yaml.j2](../infrastructure/cluster/kind.yaml.j2), [gitops/clusters/kind/kustomization.yaml](../gitops/clusters/kind/kustomization.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D02 docs/platform-kind-v1/cluster.md

- 原文件：[docs/platform-kind-v1/cluster.md](../docs/platform-kind-v1/cluster.md)，94行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/cluster/README.md；宿主机诊断归host/troubleshooting.md；结果归verification.md`。
- 当前内容与问题：建群方法与模块README重复，夹杂main/136保护和早期尚未部署Traefik等描述。
- 必须保留/补齐：三节点extraMounts、静态/动态路径、API与入口端口、所有权receipt、CNI导入、节点CA/DNS与Pod拉取区别、重启DNS变化风险。
- 删除/改写：临时候选环境名与已删除资产的操作指令；初期成功数量；把挂载检查当作重建持久化证明；50GiB旧门槛。
- 核对依据：[infrastructure/cluster/config.yaml](../infrastructure/cluster/config.yaml), [infrastructure/cluster/deploy.yaml](../infrastructure/cluster/deploy.yaml), [infrastructure/cluster/pull-check.yaml](../infrastructure/cluster/pull-check.yaml), [infrastructure/cluster/kind.yaml.j2](../infrastructure/cluster/kind.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D03 docs/platform-kind-v1/docker-maintenance.md

- 原文件：[docs/platform-kind-v1/docker-maintenance.md](../docs/platform-kind-v1/docker-maintenance.md)，106行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/host/troubleshooting.md；日期兼容性结论归verification.md`。
- 当前内容与问题：29.4.3到29.8.1维护卡包括旧节点/容器清单和一次性的回退步骤，不宜作为日常升级教程。
- 必须保留/补齐：Docker registry token/CA故障分层；停机前身份/卷/入口记录；恢复顺序风险；曾实际验证的版本兼容性结论及范围。
- 删除/改写：固定历史容器ID、已移除main/136操作、一次性包名和时间预算；未交付自动升级入口的暗示。
- 核对依据：[infrastructure/host/preflight.yaml](../infrastructure/host/preflight.yaml), [infrastructure/registry/service.yaml](../infrastructure/registry/service.yaml), [infrastructure/entry/service.yaml](../infrastructure/entry/service.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D04 docs/platform-kind-v1/entry-cutover.md

- 原文件：[docs/platform-kind-v1/entry-cutover.md](../docs/platform-kind-v1/entry-cutover.md)，67行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/entry/README.md；日期结果归verification.md`。
- 当前内容与问题：首次代理切换卡保留旧候选端口、旧代理和main后端，现网路由已变化。
- 必须保留/补齐：SNI分流、Harbor独立后端、应用后端、候选配置校验、备份三文件、维护止损和回退检查。
- 删除/改写：旧32443/19443候选操作命令；历史临时容量豁免；把旧代理容器当作永久依赖。
- 核对依据：[infrastructure/entry/config.yaml](../infrastructure/entry/config.yaml), [infrastructure/entry/service.yaml](../infrastructure/entry/service.yaml), [infrastructure/entry/templates/haproxy.cfg.j2](../infrastructure/entry/templates/haproxy.cfg.j2), [infrastructure/entry/templates/sunmoon-entry.service.j2](../infrastructure/entry/templates/sunmoon-entry.service.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D05 docs/platform-kind-v1/flux.md

- 原文件：[docs/platform-kind-v1/flux.md](../docs/platform-kind-v1/flux.md)，50行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/flux/README.md；物料职责归artifacts/README.md`。
- 当前内容与问题：发布来源、身份和初期阶段结果与Flux模块说明重复，已部署平台仍被写作后续任务。
- 必须保留/补齐：固定OCI digest与Git revision；发布候选后显式晋级；pull-only身份；CA；本地运行工具prepare/skopeo/exporter的保留职责。
- 删除/改写：Flux首次安装的历史数量与旧容量豁免；平台/应用尚未部署的全局断言。
- 核对依据：[infrastructure/flux/source.yaml](../infrastructure/flux/source.yaml), [infrastructure/flux/materials.yaml](../infrastructure/flux/materials.yaml), [infrastructure/environments/kind/flux-source.yaml](../infrastructure/environments/kind/flux-source.yaml), [infrastructure/artifacts/tasks/publish-image.yaml](../infrastructure/artifacts/tasks/publish-image.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D06 docs/platform-kind-v1/images.md

- 原文件：[docs/platform-kind-v1/images.md](../docs/platform-kind-v1/images.md)，102行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`architecture.md的版本策略；infrastructure/artifacts/README.md；个别例外归组件README`。
- 当前内容与问题：包含选型理由，但手写镜像表与实际锁并行；部分模型/跨应用状态已经过期。
- 必须保留/补齐：版本选择与固定摘要原则；官方镜像优先；RAGFlow最小派生例外及理由；引导离线与应用在线构建分工。
- 删除/改写：重复56条版本摘要表；未经重新核对的“最新”断言；尚未下载/尚未推理等过期状态。
- 核对依据：[infrastructure/artifacts/upstream-images.lock.json](../infrastructure/artifacts/upstream-images.lock.json), [infrastructure/artifacts/files.lock.json](../infrastructure/artifacts/files.lock.json), [infrastructure/artifacts/node-image.lock.json](../infrastructure/artifacts/node-image.lock.json), [gitops/components/data-platform/ragflow/Dockerfile](../gitops/components/data-platform/ragflow/Dockerfile)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D07 docs/platform-kind-v1/info-entry-cutover.md

- 原文件：[docs/platform-kind-v1/info-entry-cutover.md](../docs/platform-kind-v1/info-entry-cutover.md)，31行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/entry/README.md；info-app/README.md；verification.md`。
- 当前内容与问题：Info两域名一次性切换卡重复公共切换流程，少量业务边界需要保留。
- 必须保留/补齐：真实public验收与内部检查的区别；Info使用S3、搜索后端disabled的范围；切换不会证明完整抓取业务。
- 删除/改写：一次性候选提交、备份路径、已结束维护窗口及重复代理命令。
- 核对依据：[infrastructure/entry/config.yaml](../infrastructure/entry/config.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py), [gitops/components/app-platform/info-app/info-backend/config.yaml](../gitops/components/app-platform/info-app/info-backend/config.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D08 docs/platform-kind-v1/inventory.md

- 原文件：[docs/platform-kind-v1/inventory.md](../docs/platform-kind-v1/inventory.md)，81行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/applications/README.md；architecture.md；verification.md`。
- 当前内容与问题：初期5仓基线与保留资产清单，包含已结束的阶段和历史物料组织。
- 必须保留/补齐：多仓/子模块固定源码关系；原始kind与新体系保留边界；源码/物料/数据不同所有权；本地提交不自动push。
- 删除/改写：与sources.yaml重复的提交清单；已经删除的试验环境作为活动资产；早期“尚未应用部署”状态。
- 核对依据：[infrastructure/applications/sources.yaml](../infrastructure/applications/sources.yaml), [infrastructure/applications/build.yaml](../infrastructure/applications/build.yaml), [infrastructure/environments/kind/site.yaml](../infrastructure/environments/kind/site.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D09 docs/platform-kind-v1/knowledge-investment-entry-cutover.md

- 原文件：[docs/platform-kind-v1/knowledge-investment-entry-cutover.md](../docs/platform-kind-v1/knowledge-investment-entry-cutover.md)，73行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/entry/README.md；knowledge/investment应用README；verification.md`。
- 当前内容与问题：四域名维护卡与其他切换卡重复，但备份与运行文件权限区别值得保留。
- 必须保留/补齐：三文件恢复关系；私有备份0600与运行配置0644区别；候选校验/恢复/真实public检查；四域名边界。
- 删除/改写：固定某次提交与临时目录；尚未接入跨应用检索的过期描述；历史备份路径复制执行。
- 核对依据：[infrastructure/entry/service.yaml](../infrastructure/entry/service.yaml), [infrastructure/entry/config.yaml](../infrastructure/entry/config.yaml), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D10 docs/platform-kind-v1/namespace-layout.md

- 原文件：[docs/platform-kind-v1/namespace-layout.md](../docs/platform-kind-v1/namespace-layout.md)，94行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`architecture.md；foundations/README.md；迁移风险归cluster/README.md`。
- 当前内容与问题：目录与命名空间映射是长期知识；已有PVC跨命名空间操作属于已结束迁移，不能继续作为标准部署。
- 必须保留/补齐：Casdoor归app-platform/auth-app而数据库Job跑data；所有业务统一app-platform-dev；PVC命名空间、PV集群作用域、Retain与claimRef限制。
- 删除/改写：历史UID、claimRef patch命令、已完成停服步骤与旧容量要求；迁移成功数量作为实时状态。
- 核对依据：[infrastructure/services/layout.yaml](../infrastructure/services/layout.yaml), [infrastructure/environments/kind/site.yaml](../infrastructure/environments/kind/site.yaml), [gitops/components/foundations/storage.yaml.j2](../gitops/components/foundations/storage.yaml.j2), [gitops/clusters/kind/services.yaml.j2](../gitops/clusters/kind/services.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D11 docs/platform-kind-v1/object-storage.md

- 原文件：[docs/platform-kind-v1/object-storage.md](../docs/platform-kind-v1/object-storage.md)，27行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`gitops/components/data-platform/object-storage/README.md；app-platform/common/backend/storage/README.md；verification.md`。
- 当前内容与问题：AIStor初期操作记录与当前组件说明重复；包含mc返回0但JSON报错的有效经验。
- 必须保留/补齐：许可证必须经过实际S3检查；mc逐行status核验；原文版本及摘要；平台根身份与应用限定身份分离。
- 删除/改写：首次镜像/Pod观察日志；“未接入S3”的过期全局描述；把目录存在当作数据持久化。
- 核对依据：[gitops/components/data-platform/object-storage/prepare.yaml](../gitops/components/data-platform/object-storage/prepare.yaml), [gitops/components/data-platform/object-storage/verify.py](../gitops/components/data-platform/object-storage/verify.py), [gitops/components/app-platform/common/backend/storage/verify-runtime.py](../gitops/components/app-platform/common/backend/storage/verify-runtime.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D12 docs/platform-kind-v1/scanning-recovery.md

- 原文件：[docs/platform-kind-v1/scanning-recovery.md](../docs/platform-kind-v1/scanning-recovery.md)，72行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/registry/scanning.md；infrastructure/registry/recovery.md；verification.md`。
- 当前内容与问题：扫描与恢复两种长期操作混合，含真实全目录恢复知识，不能直接丢弃。
- 必须保留/补齐：离线扫描库摘要/所有权；报告和系统包已知问题范围；完整冷备结构、密钥/配置/数据库、同版本隔离恢复、TLS realm、推拉及全目录摘要比较。
- 删除/改写：固定已结束演练路径/旧备份名；过期扫描结果当作当前安全状态；从演练推导WSL重启/删群验收通过。
- 核对依据：[infrastructure/registry/scanner-databases.yaml](../infrastructure/registry/scanner-databases.yaml), [infrastructure/registry/scan.yaml](../infrastructure/registry/scan.yaml), [infrastructure/registry/recovery.yaml](../infrastructure/registry/recovery.yaml), [infrastructure/registry/prepare-recovery.py](../infrastructure/registry/prepare-recovery.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D13 docs/platform-kind-v1/secrets-foundations.md

- 原文件：[docs/platform-kind-v1/secrets-foundations.md](../docs/platform-kind-v1/secrets-foundations.md)，50行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/flux/secrets.md；gitops/components/foundations/README.md`。
- 当前内容与问题：SOPS私钥恢复方法与基础声明首次安装状态混合，模块本身说明过短。
- 必须保留/补齐：独立age主输入/备份、recipient与密文、主输入丢失恢复、双丢失拒绝生成、puller与基础网络/存储职责。
- 删除/改写：首次单元预算/临时豁免；把密钥恢复说明散放在阶段记录里。
- 核对依据：[infrastructure/flux/secrets.yaml](../infrastructure/flux/secrets.yaml), [gitops/.sops.yaml](../gitops/.sops.yaml), [gitops/components/foundations/kustomization.yaml](../gitops/components/foundations/kustomization.yaml), [infrastructure/services/tasks/encrypt.yaml](../infrastructure/services/tasks/encrypt.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D14 docs/platform-kind-v1/services.md

- 原文件：[docs/platform-kind-v1/services.md](../docs/platform-kind-v1/services.md)，180行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/services/README.md；各平台组件README；architecture.md；verification.md`。
- 当前内容与问题：180行重复共同入口、各组件账户/端口表与追加开发结果，维护角色不集中。
- 必须保留/补齐：已晋级声明与候选区别；操作依赖；Casdoor marker/DB/files共同恢复；PV容量不等于quota；各身份及实际协议检查的边界。
- 删除/改写：重复全组件参数表；追加的历史执行日志；将平台管理API队列检查混同应用AMQP；应用消息仍未验收的过期总断言。
- 核对依据：[infrastructure/services/render.yaml](../infrastructure/services/render.yaml), [infrastructure/services/validate-release.yaml](../infrastructure/services/validate-release.yaml), [infrastructure/services/verify.yaml](../infrastructure/services/verify.yaml), [infrastructure/services/verify-live.py](../infrastructure/services/verify-live.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D15 docs/platform-kind-v1/tpl-entry-cutover.md

- 原文件：[docs/platform-kind-v1/tpl-entry-cutover.md](../docs/platform-kind-v1/tpl-entry-cutover.md)，73行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`infrastructure/entry/README.md；tpl-app/README.md；verification.md`。
- 当前内容与问题：三个域名切换卡与首次入口卡重复；模板业务503的解释仍有价值。
- 必须保留/补齐：public入口与内部浏览器协议检查区别；PKCE/SSR/CSRF证据范围；Tpl故意未配置provider时503不等于部署故障。
- 删除/改写：固定提交/时间窗口/回退目录；重复切换命令；模板参考业务启用的隐含承诺。
- 核对依据：[infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py), [infrastructure/entry/config.yaml](../infrastructure/entry/config.yaml), [gitops/components/app-platform/tpl-app/tpl-backend/config.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/config.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D16 docs/platform-kind-v1/tpl-redis-maintenance.md

- 原文件：[docs/platform-kind-v1/tpl-redis-maintenance.md](../docs/platform-kind-v1/tpl-redis-maintenance.md)，81行；基线SHA256见清单。
- 处置：**归并后删除**。目标：`gitops/components/data-platform/redis/README.md；tpl-backend/README.md；verification.md`。
- 当前内容与问题：持久ACL修复与两轮维护记录混合；旧源回退可能包含已修复的权限缺陷。
- 必须保留/补齐：主进程umask0077、ACL0600、持久挂载、应用限定账号、再次Pod重建验证；回退需要版本与ACL数据匹配。
- 删除/改写：已结束的等待批准/10分钟维护；旧失败代码源当作推荐回退；重复账号初始化命令。
- 核对依据：[gitops/components/data-platform/redis/workload.yaml.j2](../gitops/components/data-platform/redis/workload.yaml.j2), [gitops/components/app-platform/common/backend/redis/provision.py.j2](../gitops/components/app-platform/common/backend/redis/provision.py.j2), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D17 gitops/components/README.md

- 原文件：[gitops/components/README.md](../gitops/components/README.md)，20行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/README.md`。
- 当前内容与问题：总分类原则正确，需要加入责任导航和生成物编辑边界。
- 必须保留/补齐：平台→应用→组件层；config/template/rendered/SOPS四类；common共享实现；core组合；跨目录资源命名空间区别。
- 删除/改写：在这里复制全部组件字段或共同部署命令。
- 核对依据：[infrastructure/services/layout.yaml](../infrastructure/services/layout.yaml), [gitops/components/core/kustomization.yaml](../gitops/components/core/kustomization.yaml), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D18 gitops/components/app-platform/auth-app/casdoor/README.md

- 原文件：[gitops/components/app-platform/auth-app/casdoor/README.md](../gitops/components/app-platform/auth-app/casdoor/README.md)，9行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/auth-app/casdoor/README.md`。
- 当前内容与问题：9行说明未充分解释目录归属和数据库Job跨命名空间。
- 必须保留/补齐：auth-app分类；data数据库Job与app运行；marker/DB/files共同恢复、公共域名、TLS、管理员初始化。
- 删除/改写：把初始化marker作为独立可恢复完整业务数据；浏览器登录等同所有应用业务完成。
- 核对依据：[gitops/components/app-platform/auth-app/casdoor/config.yaml](../gitops/components/app-platform/auth-app/casdoor/config.yaml), [gitops/components/app-platform/auth-app/casdoor/database/workload.yaml.j2](../gitops/components/app-platform/auth-app/casdoor/database/workload.yaml.j2), [gitops/components/app-platform/auth-app/casdoor/init/workload.yaml.j2](../gitops/components/app-platform/auth-app/casdoor/init/workload.yaml.j2), [gitops/components/app-platform/auth-app/casdoor/workload.yaml.j2](../gitops/components/app-platform/auth-app/casdoor/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D19 gitops/components/app-platform/common/README.md

- 原文件：[gitops/components/app-platform/common/README.md](../gitops/components/app-platform/common/README.md)，13行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/common/README.md`。
- 当前内容与问题：共享职责正确，组件README大量重复其共同尾段。
- 必须保留/补齐：backend/web/admin通用模板、来源与专用config读取、schema/身份/消息共享机制、common变更影响4应用。
- 删除/改写：每个应用README重复整段共同流程；机械合并不同业务边界。
- 核对依据：[gitops/components/app-platform/common/admin/workload.yaml.j2](../gitops/components/app-platform/common/admin/workload.yaml.j2), [gitops/components/app-platform/common/backend/database/workload.yaml.j2](../gitops/components/app-platform/common/backend/database/workload.yaml.j2), [gitops/components/app-platform/common/backend/identity/workload.yaml.j2](../gitops/components/app-platform/common/backend/identity/workload.yaml.j2), [gitops/components/app-platform/common/backend/migration/workload.yaml.j2](../gitops/components/app-platform/common/backend/migration/workload.yaml.j2), [gitops/components/app-platform/common/backend/rabbitmq/workload.yaml.j2](../gitops/components/app-platform/common/backend/rabbitmq/workload.yaml.j2), [gitops/components/app-platform/common/backend/redis/workload.yaml.j2](../gitops/components/app-platform/common/backend/redis/workload.yaml.j2), [gitops/components/app-platform/common/backend/runtime/workload.yaml.j2](../gitops/components/app-platform/common/backend/runtime/workload.yaml.j2), [gitops/components/app-platform/common/backend/service-identity/prepare.yaml](../gitops/components/app-platform/common/backend/service-identity/prepare.yaml), [gitops/components/app-platform/common/backend/service-identity/workload.yaml.j2](../gitops/components/app-platform/common/backend/service-identity/workload.yaml.j2), [gitops/components/app-platform/common/backend/storage/prepare.yaml](../gitops/components/app-platform/common/backend/storage/prepare.yaml), [gitops/components/app-platform/common/backend/storage/verify-runtime.py](../gitops/components/app-platform/common/backend/storage/verify-runtime.py), [gitops/components/app-platform/common/backend/storage/workload.yaml.j2](../gitops/components/app-platform/common/backend/storage/workload.yaml.j2), [gitops/components/app-platform/common/web/workload.yaml.j2](../gitops/components/app-platform/common/web/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D20 gitops/components/app-platform/common/backend/service-identity/README.md

- 原文件：[gitops/components/app-platform/common/backend/service-identity/README.md](../gitops/components/app-platform/common/backend/service-identity/README.md)，13行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/common/backend/service-identity/README.md`。
- 当前内容与问题：独立关系身份与权限边界实现存在，需说明维护代次与恢复。
- 必须保留/补齐：Casdoor关系application/client_id/org/scope、900秒token、provider/receiver分离、同名冲突拒绝、主备输入恢复。
- 删除/改写：用管理员token替换业务身份；改client_id就当轮换完成；URL中输出secret。
- 核对依据：[gitops/components/app-platform/common/backend/service-identity/prepare.yaml](../gitops/components/app-platform/common/backend/service-identity/prepare.yaml), [gitops/components/app-platform/common/backend/service-identity/workload.yaml.j2](../gitops/components/app-platform/common/backend/service-identity/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D21 gitops/components/app-platform/common/backend/storage/README.md

- 原文件：[gitops/components/app-platform/common/backend/storage/README.md](../gitops/components/app-platform/common/backend/storage/README.md)，13行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/common/backend/storage/README.md`。
- 当前内容与问题：原文版本/独立权限机制存在，需强调check实际写两个版本。
- 必须保留/补齐：专用bucket/user、S3原文、版本/摘要、跨bucket与management拒绝、probe精确清理、backup未交付。
- 删除/改写：把验收清理当业务retention；所有应用S3均已验收的扩大结论。
- 核对依据：[gitops/components/app-platform/common/backend/storage/prepare.yaml](../gitops/components/app-platform/common/backend/storage/prepare.yaml), [gitops/components/app-platform/common/backend/storage/verify-runtime.py](../gitops/components/app-platform/common/backend/storage/verify-runtime.py), [gitops/components/app-platform/common/backend/storage/workload.yaml.j2](../gitops/components/app-platform/common/backend/storage/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D22 gitops/components/app-platform/info-app/README.md

- 原文件：[gitops/components/app-platform/info-app/README.md](../gitops/components/app-platform/info-app/README.md)，7行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/info-app/README.md`。
- 当前内容与问题：7行仍写S3/知识链路后续接入；引用组件过少。
- 必须保留/补齐：信息应用角色、S3原文版本、搜索disabled、Knowledge ingestion关系；完整抓取业务未完成。；整体config开关和三组件导航。
- 删除/改写：重复共同构建/部署命令；无日期阶段状态；把登录通当全部业务通过。
- 核对依据：[gitops/components/app-platform/info-app/config.yaml](../gitops/components/app-platform/info-app/config.yaml), [infrastructure/applications/sources.yaml](../infrastructure/applications/sources.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D23 gitops/components/app-platform/info-app/info-admin-frontend/README.md

- 原文件：[gitops/components/app-platform/info-app/info-admin-frontend/README.md](../gitops/components/app-platform/info-app/info-admin-frontend/README.md)，5行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/info-app/info-admin-frontend/README.md`。
- 当前内容与问题：info前端通用段误带后端数据库/迁移身份；缺少本前端职责。
- 必须保留/补齐：admin前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；管理员surface与未授权诊断拒绝。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；S3/知识未接入的过期总断言。
- 核对依据：[gitops/components/app-platform/info-app/info-admin-frontend/config.yaml](../gitops/components/app-platform/info-app/info-admin-frontend/config.yaml), [gitops/components/app-platform/info-app/info-admin-frontend/image.lock.yaml](../gitops/components/app-platform/info-app/info-admin-frontend/image.lock.yaml), [gitops/components/app-platform/info-app/info-admin-frontend/workload.yaml](../gitops/components/app-platform/info-app/info-admin-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D24 gitops/components/app-platform/info-app/info-backend/README.md

- 原文件：[gitops/components/app-platform/info-app/info-backend/README.md](../gitops/components/app-platform/info-app/info-backend/README.md)，15行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/info-app/info-backend/README.md`。
- 当前内容与问题：15行业务边界有效，标题/通用共同内容需分离。
- 必须保留/补齐：API/Worker/Scheduler、数据库runtime/migrator、Redis/Rabbit身份、schema/job代次、private/backup路径、资源/port/concurrency；信息应用角色、S3原文版本、搜索disabled、Knowledge ingestion关系；完整抓取业务未完成。
- 删除/改写：共同编排命令归applications；旧代次日志/待做断言；运行参数与secret值混写。
- 核对依据：[gitops/components/app-platform/info-app/info-backend/config.yaml](../gitops/components/app-platform/info-app/info-backend/config.yaml), [gitops/components/app-platform/info-app/info-backend/image.lock.yaml](../gitops/components/app-platform/info-app/info-backend/image.lock.yaml), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D25 gitops/components/app-platform/info-app/info-web-frontend/README.md

- 原文件：[gitops/components/app-platform/info-app/info-web-frontend/README.md](../gitops/components/app-platform/info-app/info-web-frontend/README.md)，5行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/info-app/info-web-frontend/README.md`。
- 当前内容与问题：info前端通用段误带后端数据库/迁移身份；缺少本前端职责。
- 必须保留/补齐：web前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；用户surface、session与对侧surface隔离。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；S3/知识未接入的过期总断言。
- 核对依据：[gitops/components/app-platform/info-app/info-web-frontend/config.yaml](../gitops/components/app-platform/info-app/info-web-frontend/config.yaml), [gitops/components/app-platform/info-app/info-web-frontend/image.lock.yaml](../gitops/components/app-platform/info-app/info-web-frontend/image.lock.yaml), [gitops/components/app-platform/info-app/info-web-frontend/workload.yaml](../gitops/components/app-platform/info-app/info-web-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D26 gitops/components/app-platform/investment-app/README.md

- 原文件：[gitops/components/app-platform/investment-app/README.md](../gitops/components/app-platform/investment-app/README.md)，3行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/investment-app/README.md`。
- 当前内容与问题：3行概述不足以区分当前基础运行和投资Agent目标。
- 必须保留/补齐：5角色、Knowledge检索关系、权限范围；Agent工具/执行环境/外部模型仍待接入。；整体config开关和三组件导航。
- 删除/改写：重复共同构建/部署命令；无日期阶段状态；把登录通当全部业务通过。
- 核对依据：[gitops/components/app-platform/investment-app/config.yaml](../gitops/components/app-platform/investment-app/config.yaml), [infrastructure/applications/sources.yaml](../infrastructure/applications/sources.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D27 gitops/components/app-platform/investment-app/investment-admin-frontend/README.md

- 原文件：[gitops/components/app-platform/investment-app/investment-admin-frontend/README.md](../gitops/components/app-platform/investment-app/investment-admin-frontend/README.md)，5行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/investment-app/investment-admin-frontend/README.md`。
- 当前内容与问题：investment前端通用段误带后端数据库/迁移身份；缺少本前端职责。
- 必须保留/补齐：admin前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；管理员surface与未授权诊断拒绝。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；Knowledge检索待做的过期总断言。
- 核对依据：[gitops/components/app-platform/investment-app/investment-admin-frontend/config.yaml](../gitops/components/app-platform/investment-app/investment-admin-frontend/config.yaml), [gitops/components/app-platform/investment-app/investment-admin-frontend/image.lock.yaml](../gitops/components/app-platform/investment-app/investment-admin-frontend/image.lock.yaml), [gitops/components/app-platform/investment-app/investment-admin-frontend/workload.yaml](../gitops/components/app-platform/investment-app/investment-admin-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D28 gitops/components/app-platform/investment-app/investment-backend/README.md

- 原文件：[gitops/components/app-platform/investment-app/investment-backend/README.md](../gitops/components/app-platform/investment-app/investment-backend/README.md)，7行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/investment-app/investment-backend/README.md`。
- 当前内容与问题：7行只描述基础配置，需要明确已完成Knowledge HTTPS检索与未完成Agent部分。
- 必须保留/补齐：API/Worker/Scheduler、数据库runtime/migrator、Redis/Rabbit身份、schema/job代次、private/backup路径、资源/port/concurrency；5角色、Knowledge检索关系、权限范围；Agent工具/执行环境/外部模型仍待接入。
- 删除/改写：共同编排命令归applications；旧代次日志/待做断言；运行参数与secret值混写。
- 核对依据：[gitops/components/app-platform/investment-app/investment-backend/config.yaml](../gitops/components/app-platform/investment-app/investment-backend/config.yaml), [gitops/components/app-platform/investment-app/investment-backend/image.lock.yaml](../gitops/components/app-platform/investment-app/investment-backend/image.lock.yaml), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D29 gitops/components/app-platform/investment-app/investment-web-frontend/README.md

- 原文件：[gitops/components/app-platform/investment-app/investment-web-frontend/README.md](../gitops/components/app-platform/investment-app/investment-web-frontend/README.md)，5行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/investment-app/investment-web-frontend/README.md`。
- 当前内容与问题：investment前端通用段误带后端数据库/迁移身份；缺少本前端职责。
- 必须保留/补齐：web前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；用户surface、session与对侧surface隔离。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；Knowledge检索待做的过期总断言。
- 核对依据：[gitops/components/app-platform/investment-app/investment-web-frontend/config.yaml](../gitops/components/app-platform/investment-app/investment-web-frontend/config.yaml), [gitops/components/app-platform/investment-app/investment-web-frontend/image.lock.yaml](../gitops/components/app-platform/investment-app/investment-web-frontend/image.lock.yaml), [gitops/components/app-platform/investment-app/investment-web-frontend/workload.yaml](../gitops/components/app-platform/investment-app/investment-web-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D30 gitops/components/app-platform/knowledge-app/README.md

- 原文件：[gitops/components/app-platform/knowledge-app/README.md](../gitops/components/app-platform/knowledge-app/README.md)，3行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/knowledge-app/README.md`。
- 当前内容与问题：3行概述太简略，找不到provider/权限/组件维护入口。
- 必须保留/补齐：知识应用与RAGFlow派生索引职责；只读Info原文、domain ingestions/retrieval、真实HTTP身份与worker流程；PDF范围未验。；整体config开关和三组件导航。
- 删除/改写：重复共同构建/部署命令；无日期阶段状态；把登录通当全部业务通过。
- 核对依据：[gitops/components/app-platform/knowledge-app/config.yaml](../gitops/components/app-platform/knowledge-app/config.yaml), [infrastructure/applications/sources.yaml](../infrastructure/applications/sources.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D31 gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md

- 原文件：[gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md)，5行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md`。
- 当前内容与问题：knowledge前端通用段误带后端数据库/迁移身份；缺少本前端职责。
- 必须保留/补齐：admin前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；管理员surface与未授权诊断拒绝。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；RAG未接入的过期总断言。
- 核对依据：[gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/config.yaml](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/config.yaml), [gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/image.lock.yaml](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/image.lock.yaml), [gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D32 gitops/components/app-platform/knowledge-app/knowledge-backend/README.md

- 原文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/README.md](../gitops/components/app-platform/knowledge-app/knowledge-backend/README.md)，15行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。
- 当前内容与问题：15行需把业务provider与真实跨应用身份关联，并明确配置/初始化副作用。
- 必须保留/补齐：API/Worker/Scheduler、数据库runtime/migrator、Redis/Rabbit身份、schema/job代次、private/backup路径、资源/port/concurrency；知识应用与RAGFlow派生索引职责；只读Info原文、domain ingestions/retrieval、真实HTTP身份与worker流程；PDF范围未验。
- 删除/改写：共同编排命令归applications；旧代次日志/待做断言；运行参数与secret值混写。
- 核对依据：[gitops/components/app-platform/knowledge-app/knowledge-backend/config.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/config.yaml), [gitops/components/app-platform/knowledge-app/knowledge-backend/image.lock.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/image.lock.yaml), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D33 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md

- 原文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md)，13行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。
- 当前内容与问题：13行流程实用；准备dataset有远端写入，须写清所有权与失败journal。
- 必须保留/补齐：provider/operator分权、固定dataset绑定、未知同名拒绝；版本/hash与只读原文；真实Info HTTP和Investment HTTP、异步Worker、精确临时清理。
- 删除/改写：stage纯只读的表述；失败后可任意删除dataset；仅组件探针成功就等同跨App HTTP成功。
- 核对依据：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/prepare.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/prepare.yaml), [gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision-dataset.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision-dataset.py), [gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D34 gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md

- 原文件：[gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md)，5行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md`。
- 当前内容与问题：knowledge前端通用段误带后端数据库/迁移身份；缺少本前端职责。
- 必须保留/补齐：web前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；用户surface、session与对侧surface隔离。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；RAG未接入的过期总断言。
- 核对依据：[gitops/components/app-platform/knowledge-app/knowledge-web-frontend/config.yaml](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/config.yaml), [gitops/components/app-platform/knowledge-app/knowledge-web-frontend/image.lock.yaml](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/image.lock.yaml), [gitops/components/app-platform/knowledge-app/knowledge-web-frontend/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D35 gitops/components/app-platform/tpl-app/README.md

- 原文件：[gitops/components/app-platform/tpl-app/README.md](../gitops/components/app-platform/tpl-app/README.md)，13行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/tpl-app/README.md`。
- 当前内容与问题：13行仍写前端/真实运行待做，与现有声明和验收不一致。
- 必须保留/补齐：可复制模板结构与5个运行角色；登录/消息已验范围；默认业务provider不启用时503。；整体config开关和三组件导航。
- 删除/改写：重复共同构建/部署命令；无日期阶段状态；把登录通当全部业务通过。
- 核对依据：[gitops/components/app-platform/tpl-app/config.yaml](../gitops/components/app-platform/tpl-app/config.yaml), [infrastructure/applications/sources.yaml](../infrastructure/applications/sources.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D36 gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md

- 原文件：[gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md)，14行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md`。
- 当前内容与问题：Tpl前端较完整，但真实公共入口仍写待切换。
- 必须保留/补齐：admin前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；管理员surface与未授权诊断拒绝。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；入口待切换的过期总断言。
- 核对依据：[gitops/components/app-platform/tpl-app/tpl-admin-frontend/config.yaml](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/config.yaml), [gitops/components/app-platform/tpl-app/tpl-admin-frontend/image.lock.yaml](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/image.lock.yaml), [gitops/components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D37 gitops/components/app-platform/tpl-app/tpl-backend/README.md

- 原文件：[gitops/components/app-platform/tpl-app/tpl-backend/README.md](../gitops/components/app-platform/tpl-app/tpl-backend/README.md)，50行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。
- 当前内容与问题：50行前段说runtime通过，后段仍说Rabbit/Casdoor待做；旧迁移ID与多个子手册重复。
- 必须保留/补齐：API/Worker/Scheduler、数据库runtime/migrator、Redis/Rabbit身份、schema/job代次、private/backup路径、资源/port/concurrency；可复制模板结构与5个运行角色；登录/消息已验范围；默认业务provider不启用时503。
- 删除/改写：共同编排命令归applications；旧代次日志/待做断言；运行参数与secret值混写。
- 核对依据：[gitops/components/app-platform/tpl-app/tpl-backend/config.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/config.yaml), [gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D38 gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md

- 原文件：[gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md](../gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md)，17行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md`。
- 当前内容与问题：setup阶段与浏览器验证范围需明确，不能把setup没做的检查写成全局未通过。
- 必须保留/补齐：Web/Admin独立client、输入恢复、scope和初始化代次；setup仅创建身份，实际PKCE/SSR由统一browser check。
- 删除/改写：已发生浏览器验收仍被写作全局待做；重复所有应用身份配置。
- 核对依据：[gitops/components/app-platform/common/backend/identity/provision.py.j2](../gitops/components/app-platform/common/backend/identity/provision.py.j2), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D39 gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md

- 原文件：[gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md](../gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md)，20行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md`。
- 当前内容与问题：应用AMQP与平台HTTP管理验收是不同层次。
- 必须保留/补齐：tpl用户/vhost/队列、Celery独占设置、API→Worker实际消息、Scheduler受控tick、临时probe范围；当前非mTLS。
- 删除/改写：消息链路尚未接入的旧断言；混用root管理账号为业务身份。
- 核对依据：[gitops/components/app-platform/common/backend/rabbitmq/provision.py.j2](../gitops/components/app-platform/common/backend/rabbitmq/provision.py.j2), [gitops/components/app-platform/common/backend/runtime/workload.yaml.j2](../gitops/components/app-platform/common/backend/runtime/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D40 gitops/components/app-platform/tpl-app/tpl-backend/runtime/README.md

- 原文件：[gitops/components/app-platform/tpl-app/tpl-backend/runtime/README.md](../gitops/components/app-platform/tpl-app/tpl-backend/runtime/README.md)，36行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/tpl-app/tpl-backend/runtime/README.md`。
- 当前内容与问题：36行混入早期入口计划，需要保留各角色/认证协议实际差别。
- 必须保留/补齐：5角色职责、health、PKCE/session/CSRF、限定消息检查；浏览器HTTPS、既有Casdoor HTTP backchannel与关系服务HTTPS分别说明。
- 删除/改写：public切换尚未发生的旧描述；将所有backchannel机械写成TLS；完整业务provider已启用承诺。
- 核对依据：[gitops/components/app-platform/common/backend/runtime/workload.yaml.j2](../gitops/components/app-platform/common/backend/runtime/workload.yaml.j2), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D41 gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md

- 原文件：[gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md](../gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md)，14行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md`。
- 当前内容与问题：Tpl前端较完整，但真实公共入口仍写待切换。
- 必须保留/补齐：web前端origin、port、replicas、resources、公共Casdoor application/client_id；SSR与后端session接口关联；image.lock来源；用户surface、session与对侧surface隔离。
- 删除/改写：数据库口令、migrator职责与后端私有路径；重复共同发布步骤；入口待切换的过期总断言。
- 核对依据：[gitops/components/app-platform/tpl-app/tpl-web-frontend/config.yaml](../gitops/components/app-platform/tpl-app/tpl-web-frontend/config.yaml), [gitops/components/app-platform/tpl-app/tpl-web-frontend/image.lock.yaml](../gitops/components/app-platform/tpl-app/tpl-web-frontend/image.lock.yaml), [gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml), [infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D42 gitops/components/data-platform/elk/README.md

- 原文件：[gitops/components/data-platform/elk/README.md](../gitops/components/data-platform/elk/README.md)，26行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/elk/README.md`。
- 当前内容与问题：先写未启用自动采集、后又介绍collector，内容矛盾。
- 必须保留/补齐：ES/Logstash/Kibana职责、volume/resources/heap/sysctl、独立writer/reader/ingest、TLS、collector/view导航和429边界。
- 删除/改写：未采集应用日志的过期断言；公共Kibana/整机恢复已完成的扩大结论。
- 核对依据：[gitops/components/data-platform/elk/collector/config.yaml](../gitops/components/data-platform/elk/collector/config.yaml), [gitops/components/data-platform/elk/collector/prepare.yaml](../gitops/components/data-platform/elk/collector/prepare.yaml), [gitops/components/data-platform/elk/collector/workload.yaml.j2](../gitops/components/data-platform/elk/collector/workload.yaml.j2), [gitops/components/data-platform/elk/config.yaml](../gitops/components/data-platform/elk/config.yaml), [gitops/components/data-platform/elk/elasticsearch/workload.yaml.j2](../gitops/components/data-platform/elk/elasticsearch/workload.yaml.j2), [gitops/components/data-platform/elk/initialize/workload.yaml.j2](../gitops/components/data-platform/elk/initialize/workload.yaml.j2), [gitops/components/data-platform/elk/kibana/data-view/config.yaml](../gitops/components/data-platform/elk/kibana/data-view/config.yaml), [gitops/components/data-platform/elk/kibana/data-view/prepare.yaml](../gitops/components/data-platform/elk/kibana/data-view/prepare.yaml), [gitops/components/data-platform/elk/kibana/data-view/workload.yaml.j2](../gitops/components/data-platform/elk/kibana/data-view/workload.yaml.j2), [gitops/components/data-platform/elk/kibana/workload.yaml.j2](../gitops/components/data-platform/elk/kibana/workload.yaml.j2), [gitops/components/data-platform/elk/logstash/workload.yaml.j2](../gitops/components/data-platform/elk/logstash/workload.yaml.j2), [gitops/components/data-platform/elk/prepare.yaml](../gitops/components/data-platform/elk/prepare.yaml), [gitops/components/data-platform/elk/verify.py](../gitops/components/data-platform/elk/verify.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D43 gitops/components/data-platform/elk/collector/README.md

- 原文件：[gitops/components/data-platform/elk/collector/README.md](../gitops/components/data-platform/elk/collector/README.md)，17行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/elk/collector/README.md`。
- 当前内容与问题：专属安全和缓存知识较完整，需与ELK入口及缺失保留策略衔接。
- 必须保留/补齐：三节点只读CRI日志、无SA token/socket、offset/待发送块持久、背压、仅app命名空间、配置资源与真实日志核对。
- 删除/改写：把偏移缓存当备份、任意删collector state或未批准日志删除策略。
- 核对依据：[gitops/components/data-platform/elk/collector/config.yaml](../gitops/components/data-platform/elk/collector/config.yaml), [gitops/components/data-platform/elk/collector/prepare.yaml](../gitops/components/data-platform/elk/collector/prepare.yaml), [gitops/components/data-platform/elk/collector/workload.yaml.j2](../gitops/components/data-platform/elk/collector/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D44 gitops/components/data-platform/elk/kibana/data-view/README.md

- 原文件：[gitops/components/data-platform/elk/kibana/data-view/README.md](../gitops/components/data-platform/elk/kibana/data-view/README.md)，9行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/elk/kibana/data-view/README.md`。
- 当前内容与问题：初始化generation与独立服务身份正确，冷空首次创建分支未实测。
- 必须保留/补齐：稳定view id/title/@timestamp、专属identity无日志读取、immutable Job代次、只读check不能修复metadata。
- 删除/改写：冷重建已验收的暗示；复用人类reader口令进行初始化。
- 核对依据：[gitops/components/data-platform/elk/kibana/data-view/config.yaml](../gitops/components/data-platform/elk/kibana/data-view/config.yaml), [gitops/components/data-platform/elk/kibana/data-view/prepare.yaml](../gitops/components/data-platform/elk/kibana/data-view/prepare.yaml), [gitops/components/data-platform/elk/kibana/data-view/workload.yaml.j2](../gitops/components/data-platform/elk/kibana/data-view/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D45 gitops/components/data-platform/infinity/README.md

- 原文件：[gitops/components/data-platform/infinity/README.md](../gitops/components/data-platform/infinity/README.md)，7行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/infinity/README.md`。
- 当前内容与问题：7行专用依赖，存储/内存及无TLS边界应明确。
- 必须保留/补齐：仅RAGFlow派生索引、30Gi声明非quota、buffer/memindex、网络限制、丢失后的恢复依赖而非自动重建承诺。
- 删除/改写：可随意丢弃派生索引、或未实现TLS认证的承诺。
- 核对依据：[gitops/components/data-platform/infinity/config.yaml](../gitops/components/data-platform/infinity/config.yaml), [gitops/components/data-platform/infinity/prepare.yaml](../gitops/components/data-platform/infinity/prepare.yaml), [gitops/components/data-platform/infinity/workload.yaml.j2](../gitops/components/data-platform/infinity/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D46 gitops/components/data-platform/mongodb/README.md

- 原文件：[gitops/components/data-platform/mongodb/README.md](../gitops/components/data-platform/mongodb/README.md)，21行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/mongodb/README.md`。
- 当前内容与问题：独立21行说明保留单成员TLS事务边界，需要补维护账号/初始化代次。
- 必须保留/补齐：replset固定成员、TLS、limited acceptance、WiredTiger/oplog、事务、nonce跨Pod持久探针、初始化拒绝自动改配置。
- 删除/改写：把验收账号当业务账号；单成员副本集称HA；Pod重启称整机恢复。
- 核对依据：[gitops/components/data-platform/mongodb/config.yaml](../gitops/components/data-platform/mongodb/config.yaml), [gitops/components/data-platform/mongodb/initialize/workload.yaml.j2](../gitops/components/data-platform/mongodb/initialize/workload.yaml.j2), [gitops/components/data-platform/mongodb/prepare.yaml](../gitops/components/data-platform/mongodb/prepare.yaml), [gitops/components/data-platform/mongodb/workload.yaml.j2](../gitops/components/data-platform/mongodb/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D47 gitops/components/data-platform/neo4j/README.md

- 原文件：[gitops/components/data-platform/neo4j/README.md](../gitops/components/data-platform/neo4j/README.md)，26行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/neo4j/README.md`。
- 当前内容与问题：26行含受限rollout恢复与权限修复，应保留专属手法。
- 必须保留/补齐：Community账号权限边界、HTTPS查询/事务回滚真实200、Bolt TLS协商、卷UID、只替换不健康旧revision守卫。
- 删除/改写：修复路径泛化递归chown；把Bolt握手当完整驱动会话或业务图谱完成。
- 核对依据：[gitops/components/data-platform/neo4j/config.yaml](../gitops/components/data-platform/neo4j/config.yaml), [gitops/components/data-platform/neo4j/prepare.yaml](../gitops/components/data-platform/neo4j/prepare.yaml), [gitops/components/data-platform/neo4j/recover-rollout.yaml](../gitops/components/data-platform/neo4j/recover-rollout.yaml), [gitops/components/data-platform/neo4j/verify.py](../gitops/components/data-platform/neo4j/verify.py), [gitops/components/data-platform/neo4j/workload.yaml.j2](../gitops/components/data-platform/neo4j/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D48 gitops/components/data-platform/object-storage/README.md

- 原文件：[gitops/components/data-platform/object-storage/README.md](../gitops/components/data-platform/object-storage/README.md)，29行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/object-storage/README.md`。
- 当前内容与问题：许可与S3边界正确，与全局卡重复。
- 必须保留/补齐：license路径/安全、真实S3而非格式检查、版本/字节摘要、应用/root身份、mc JSON errors、静态卷与非硬配额。
- 删除/改写：旧未接入应用状态；同盘副本能防硬件故障；单节点说明HA。
- 核对依据：[gitops/components/data-platform/object-storage/config.yaml](../gitops/components/data-platform/object-storage/config.yaml), [gitops/components/data-platform/object-storage/prepare.yaml](../gitops/components/data-platform/object-storage/prepare.yaml), [gitops/components/data-platform/object-storage/verify.py](../gitops/components/data-platform/object-storage/verify.py), [gitops/components/data-platform/object-storage/workload.yaml.j2](../gitops/components/data-platform/object-storage/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D49 gitops/components/data-platform/postgresql/README.md

- 原文件：[gitops/components/data-platform/postgresql/README.md](../gitops/components/data-platform/postgresql/README.md)，7行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/postgresql/README.md`。
- 当前内容与问题：7行通用短说明，runtime/migrator、静态卷和事务边界没有独立维护说明。
- 必须保留/补齐：开关/volume字段、口令输入路径、数据库Job职责、5432当前模板位置、事务检查与已有账号变更限制。
- 删除/改写：仅把读者转给services.md的说明；没有配置字段却宣称均可调。
- 核对依据：[gitops/components/data-platform/postgresql/config.yaml](../gitops/components/data-platform/postgresql/config.yaml), [gitops/components/data-platform/postgresql/workload.yaml.j2](../gitops/components/data-platform/postgresql/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D50 gitops/components/data-platform/ragflow/README.md

- 原文件：[gitops/components/data-platform/ragflow/README.md](../gitops/components/data-platform/ragflow/README.md)，23行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/ragflow/README.md`。
- 当前内容与问题：最小派生/DDL分离说明重要，需区分平台检索和业务关系验收。
- 必须保留/补齐：源hash守卫、非root路径、API/Worker、init/runtime身份、PostgreSQL/Infinity/Valkey/AIStor/TEI依赖、精确版本清理。
- 删除/改写：旧业务未接入的过期描述；PDF/UI/HA/mTLS均通过的扩大结论。
- 核对依据：[gitops/components/data-platform/ragflow/config.yaml](../gitops/components/data-platform/ragflow/config.yaml), [gitops/components/data-platform/ragflow/database/workload.yaml.j2](../gitops/components/data-platform/ragflow/database/workload.yaml.j2), [gitops/components/data-platform/ragflow/initialize/workload.yaml.j2](../gitops/components/data-platform/ragflow/initialize/workload.yaml.j2), [gitops/components/data-platform/ragflow/prepare.yaml](../gitops/components/data-platform/ragflow/prepare.yaml), [gitops/components/data-platform/ragflow/runtime/workload.yaml.j2](../gitops/components/data-platform/ragflow/runtime/workload.yaml.j2), [gitops/components/data-platform/ragflow/storage/workload.yaml.j2](../gitops/components/data-platform/ragflow/storage/workload.yaml.j2), [gitops/components/data-platform/ragflow/verify.py](../gitops/components/data-platform/ragflow/verify.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D51 gitops/components/data-platform/redis/README.md

- 原文件：[gitops/components/data-platform/redis/README.md](../gitops/components/data-platform/redis/README.md)，11行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/redis/README.md`。
- 当前内容与问题：11行有持久ACL关键知识，仍需完整说明恢复与权限。
- 必须保留/补齐：ACL/AOF持久目录、主进程0077、文件0600；应用账号key/channel边界；初始化与轮换；Pod重建证据范围。
- 删除/改写：历史维护窗口和失败版本回退；将口令文件编辑当作完整轮换。
- 核对依据：[gitops/components/data-platform/redis/config.yaml](../gitops/components/data-platform/redis/config.yaml), [gitops/components/data-platform/redis/workload.yaml.j2](../gitops/components/data-platform/redis/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D52 gitops/components/data-platform/text-embeddings/README.md

- 原文件：[gitops/components/data-platform/text-embeddings/README.md](../gitops/components/data-platform/text-embeddings/README.md)，42行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/text-embeddings/README.md`。
- 当前内容与问题：42行含充分模型/CPU/性能知识，不应粗略删成部署命令。
- 必须保留/补齐：Qwen模型revision、1024维、float32、batch/concurrency/thread、查询前缀、模型文件校验、CPU资源、换模型重索引要求。
- 删除/改写：把四条中文样本验收叫模型benchmark；外部模型服务已接入的未实现承诺。
- 核对依据：[gitops/components/data-platform/text-embeddings/config.yaml](../gitops/components/data-platform/text-embeddings/config.yaml), [gitops/components/data-platform/text-embeddings/prepare.yaml](../gitops/components/data-platform/text-embeddings/prepare.yaml), [gitops/components/data-platform/text-embeddings/verify.py](../gitops/components/data-platform/text-embeddings/verify.py), [gitops/components/data-platform/text-embeddings/workload.yaml.j2](../gitops/components/data-platform/text-embeddings/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D53 gitops/components/data-platform/valkey/README.md

- 原文件：[gitops/components/data-platform/valkey/README.md](../gitops/components/data-platform/valkey/README.md)，7行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/data-platform/valkey/README.md`。
- 当前内容与问题：7行说明专用RAGFlow queue，不能和业务Redis混并。
- 必须保留/补齐：独立用户/prefix、probe、内存/持久卷、RAGFlow任务关系、网络边界、ACL恢复。
- 删除/改写：“只是缓存随便删”及TLS/HA未实现承诺。
- 核对依据：[gitops/components/data-platform/valkey/config.yaml](../gitops/components/data-platform/valkey/config.yaml), [gitops/components/data-platform/valkey/prepare.yaml](../gitops/components/data-platform/valkey/prepare.yaml), [gitops/components/data-platform/valkey/workload.yaml.j2](../gitops/components/data-platform/valkey/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D54 gitops/components/ingress-platform/traefik/README.md

- 原文件：[gitops/components/ingress-platform/traefik/README.md](../gitops/components/ingress-platform/traefik/README.md)，7行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/ingress-platform/traefik/README.md`。
- 当前内容与问题：通用说明过短，缺entry/Traefik各自入口和证书责任。
- 必须保留/补齐：开关、chart/image锁、30443 NodePort和29443宿主后端、Ingress/TLS持有者、public入口切换与内部检查区别。
- 删除/改写：重复版本列表；把HAProxy当TLS终止或把修改Ingress当已完成外部流量切换。
- 核对依据：[gitops/components/ingress-platform/traefik/config.yaml](../gitops/components/ingress-platform/traefik/config.yaml), [gitops/components/ingress-platform/traefik/service-access/config.yaml](../gitops/components/ingress-platform/traefik/service-access/config.yaml), [gitops/components/ingress-platform/traefik/service-access/prepare.yaml](../gitops/components/ingress-platform/traefik/service-access/prepare.yaml), [gitops/components/ingress-platform/traefik/service-access/workload.yaml.j2](../gitops/components/ingress-platform/traefik/service-access/workload.yaml.j2), [gitops/components/ingress-platform/traefik/workload.yaml.j2](../gitops/components/ingress-platform/traefik/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D55 gitops/components/ingress-platform/traefik/service-access/README.md

- 原文件：[gitops/components/ingress-platform/traefik/service-access/README.md](../gitops/components/ingress-platform/traefik/service-access/README.md)，7行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/ingress-platform/traefik/service-access/README.md`。
- 当前内容与问题：7行维护专用内部HTTPS链路，不能因通用名字而删除。
- 必须保留/补齐：cluster-local知识/CasdoorTLS主机名、Traefik唯一持有服务私钥、调用者CA、shared config引用。
- 删除/改写：重复公网上域名切换；把所有Casdoor backchannel一概称为HTTPS。
- 核对依据：[gitops/components/ingress-platform/traefik/service-access/config.yaml](../gitops/components/ingress-platform/traefik/service-access/config.yaml), [gitops/components/ingress-platform/traefik/service-access/prepare.yaml](../gitops/components/ingress-platform/traefik/service-access/prepare.yaml), [gitops/components/ingress-platform/traefik/service-access/workload.yaml.j2](../gitops/components/ingress-platform/traefik/service-access/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D56 gitops/components/messaging-platform/rabbitmq/README.md

- 原文件：[gitops/components/messaging-platform/rabbitmq/README.md](../gitops/components/messaging-platform/rabbitmq/README.md)，9行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`gitops/components/messaging-platform/rabbitmq/README.md`。
- 当前内容与问题：通用说明过短，持久节点名沿用platform-system属于重要例外。
- 必须保留/补齐：vhost/用户/队列隔离、Celery独占队列、持久nodename、运行新messaging DNS；真实管理API检查与应用AMQP检查区别。
- 删除/改写：根据目录新名字机械改nodename；把内部AMQP说成已交付mTLS。
- 核对依据：[gitops/components/messaging-platform/rabbitmq/config.yaml](../gitops/components/messaging-platform/rabbitmq/config.yaml), [gitops/components/messaging-platform/rabbitmq/workload.yaml.j2](../gitops/components/messaging-platform/rabbitmq/workload.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D57 infrastructure/README.md

- 原文件：[infrastructure/README.md](../infrastructure/README.md)，205行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/README.md`。
- 当前内容与问题：205行混合总目录、Make目录、版本和阶段结果；与各模块重复。
- 必须保留/补齐：原生部署链；工作目录约定；Make参数；共享环境与就近配置来源；干净宿主机前置条件；模块导航。
- 删除/改写：完整命令复制表和重复BOM；首次开发过程；已过期尚未部署描述。
- 核对依据：[infrastructure/Makefile](../infrastructure/Makefile), [infrastructure/environments/kind/site.yaml](../infrastructure/environments/kind/site.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D58 infrastructure/applications/README.md

- 原文件：[infrastructure/applications/README.md](../infrastructure/applications/README.md)，157行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/applications/README.md`。
- 当前内容与问题：157行含大量历史构建过程、早期digest及过期跨应用待办；若省APP默认会指Tpl。
- 必须保留/补齐：4应用×backend/web/admin显式选择；干净固定源/子模块；在线下载配套切换；私有Harbor直连；发布→声明→晋级→部署；check/public与探针清理范围。
- 删除/改写：历史构建日志和旧digest表；少传APP示例；Info/Knowledge/Investment已验关系仍写未接入；将provider-stage说成纯文件预览。
- 核对依据：[infrastructure/applications/build.yaml](../infrastructure/applications/build.yaml), [infrastructure/applications/build-network.yaml](../infrastructure/applications/build-network.yaml), [infrastructure/applications/build-attempt.yaml](../infrastructure/applications/build-attempt.yaml), [infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml), [infrastructure/applications/sources.yaml](../infrastructure/applications/sources.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D59 infrastructure/artifacts/README.md

- 原文件：[infrastructure/artifacts/README.md](../infrastructure/artifacts/README.md)，23行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/artifacts/README.md`。
- 当前内容与问题：类型和锁职责正确，需要更清楚区分文件摘要、manifest和发布状态。
- 必须保留/补齐：bin/packages/images/charts/models/DB分类、锁和校验；应用在线依赖分工；prepare/skopeo/exporter引导用途；离线已有不等于Harbor已有。
- 删除/改写：再写一个版本BOM或靠扩展名推断用途；新源码目录之外旧物料清理建议。
- 核对依据：[infrastructure/artifacts/files.lock.json](../infrastructure/artifacts/files.lock.json), [infrastructure/artifacts/upstream-images.lock.json](../infrastructure/artifacts/upstream-images.lock.json), [infrastructure/artifacts/tasks/publish-image.yaml](../infrastructure/artifacts/tasks/publish-image.yaml), [infrastructure/artifacts/verify-oci-archive.py](../infrastructure/artifacts/verify-oci-archive.py)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D60 infrastructure/cluster/README.md

- 原文件：[infrastructure/cluster/README.md](../infrastructure/cluster/README.md)，28行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/cluster/README.md`。
- 当前内容与问题：配置就近正确；重建/启停和身份风险说明不足。
- 必须保留/补齐：三个独立宿主目录、两类节点路径、证书目录；API27443/入口29443；固定sunmoon-kind与receipt守卫；CNI和拉取检查。
- 删除/改写：将现有deploy视作任意删群重建入口；旧候选名和未验收重启承诺。
- 核对依据：[infrastructure/cluster/config.yaml](../infrastructure/cluster/config.yaml), [infrastructure/cluster/deploy.yaml](../infrastructure/cluster/deploy.yaml), [infrastructure/cluster/pull-check.yaml](../infrastructure/cluster/pull-check.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D61 infrastructure/entry/README.md

- 原文件：[infrastructure/entry/README.md](../infrastructure/entry/README.md)，65行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/entry/README.md`。
- 当前内容与问题：知识/投资仍指旧集群等描述过期；需要保留未知域名过渡路由的真实含义。
- 必须保留/补齐：entry_cluster_routes字段、Harbor域名优先、其它域名default后端；候选校验、三文件备份/恢复权限、短断检查。
- 删除/改写：main19443和旧代理候选活动步骤；已迁移四域名仍待做；把剩余default旧worker误写为已完全移除。
- 核对依据：[infrastructure/entry/config.yaml](../infrastructure/entry/config.yaml), [infrastructure/entry/service.yaml](../infrastructure/entry/service.yaml), [infrastructure/entry/templates/haproxy.cfg.j2](../infrastructure/entry/templates/haproxy.cfg.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D62 infrastructure/environments/kind/README.md

- 原文件：[infrastructure/environments/kind/README.md](../infrastructure/environments/kind/README.md)，14行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/environments/kind/README.md`。
- 当前内容与问题：说明共享变量来源正确，但缺环境身份与晋级字段变更限制。
- 必须保留/补齐：site与flux-source职责；共享命名空间；配置覆盖顺序；私有字段归模块；改变集群身份需要新receipt/存储方案。
- 删除/改写：把版本复制到site；用README作为另一份当前来源提交表。
- 核对依据：[infrastructure/environments/kind/site.yaml](../infrastructure/environments/kind/site.yaml), [infrastructure/environments/kind/flux-source.yaml](../infrastructure/environments/kind/flux-source.yaml), [infrastructure/Makefile](../infrastructure/Makefile)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D63 infrastructure/flux/README.md

- 原文件：[infrastructure/flux/README.md](../infrastructure/flux/README.md)，23行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/flux/README.md`。
- 当前内容与问题：23行无法独立说明晋级、退回、SOPS和恢复责任。
- 必须保留/补齐：控制器物料与OCI声明分开；发布候选→显式修改flux-source→apply；所有权/Ready/observedGeneration；secret手册导航。
- 删除/改写：把一次发布描述成自动晋级；重复早期控制器数量和开发预算。
- 核对依据：[infrastructure/flux/source.yaml](../infrastructure/flux/source.yaml), [infrastructure/flux/tasks/apply.yaml](../infrastructure/flux/tasks/apply.yaml), [infrastructure/environments/kind/flux-source.yaml](../infrastructure/environments/kind/flux-source.yaml)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D64 infrastructure/host/README.md

- 原文件：[infrastructure/host/README.md](../infrastructure/host/README.md)，24行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/host/README.md`。
- 当前内容与问题：现有24行不足以说明数据盘和开机恢复责任。
- 必须保留/补齐：config真实字段；挂载UUID/ext4/可见性；未来VHD增长+操作峰值+10GiB计算；同物理C盘风险；管理员首次附盘边界。
- 删除/改写：将当前检查能力泛化为已完成开机恢复；把声明容量说成真实配额。
- 核对依据：[infrastructure/host/config.yaml](../infrastructure/host/config.yaml), [infrastructure/host/preflight.yaml](../infrastructure/host/preflight.yaml), [infrastructure/host/tasks/capacity.yaml](../infrastructure/host/tasks/capacity.yaml), [infrastructure/host/windows-capacity.ps1](../infrastructure/host/windows-capacity.ps1)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D65 infrastructure/registry/README.md

- 原文件：[infrastructure/registry/README.md](../infrastructure/registry/README.md)，99行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/registry/README.md`。
- 当前内容与问题：安装/凭据方法较完整，但仍有新节点信任尚未验证、发布范围过时描述。
- 必须保留/补齐：官方安装包与组件版本适配；start/stop不删数据；项目身份、证书、日志轮转、mount守卫；扫描/恢复入口导航。
- 删除/改写：追加开发时间线；已完成节点信任仍写待做；把HAProxy推拉检查扩大到所有镜像恢复。
- 核对依据：[infrastructure/registry/service.yaml](../infrastructure/registry/service.yaml), [infrastructure/registry/accounts.yaml](../infrastructure/registry/accounts.yaml), [infrastructure/registry/config.yaml](../infrastructure/registry/config.yaml), [infrastructure/registry/templates/compose.override.yaml.j2](../infrastructure/registry/templates/compose.override.yaml.j2)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D66 infrastructure/services/README.md

- 原文件：[infrastructure/services/README.md](../infrastructure/services/README.md)，52行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/services/README.md`。
- 当前内容与问题：共同流程夹杂每批追加结果；render副作用和组件参数边界需要扩充。
- 必须保留/补齐：材料/私有输入/render/stage/validate/promotion/bootstrap/check顺序；计划与准备区别；组件导航；凭据恢复拒绝条件。
- 删除/改写：各组件端口/账号大表和历史逐批结果；render纯只读、全部检查无写入等不准确概括。
- 核对依据：[infrastructure/services/render.yaml](../infrastructure/services/render.yaml), [infrastructure/services/layout.yaml](../infrastructure/services/layout.yaml), [infrastructure/services/validate-release.yaml](../infrastructure/services/validate-release.yaml), [infrastructure/Makefile](../infrastructure/Makefile)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

### D67 infrastructure/tools/README.md

- 原文件：[infrastructure/tools/README.md](../infrastructure/tools/README.md)，9行；基线SHA256见清单。
- 处置：**保留路径、重写**。目标：`infrastructure/tools/README.md`。
- 当前内容与问题：9行工具说明过短，原生工具安装还依赖uv/jq/宿主Python及联网前置条件。
- 必须保留/补齐：工作树.venv/.tools隔离、哈希依赖锁、安装目标；宿主Python与应用Python版本分别说明；真正干净宿主机能力边界。
- 删除/改写：全新机器可直接离线一键的未验证承诺；把宿主Python当作业务runtime。
- 核对依据：[infrastructure/tools/requirements.in](../infrastructure/tools/requirements.in), [infrastructure/tools/requirements.lock](../infrastructure/tools/requirements.lock), [infrastructure/tools/install-binaries.yaml](../infrastructure/tools/install-binaries.yaml), [infrastructure/Makefile](../infrastructure/Makefile)。
- 退出条件：上述独有内容在目标说明中可定位；命令/字段对应真实实现；日期验收与运行方法分开；相对引用更新后再完成本项。

## 二、8份拟新增维护文档

| 目标 | 职责 | 内容来源 | 内容边界 |
|---|---|---|---|
| `docs/README.md` | 全局维护任务导航 | 全局与模块README | 仅链接权威维护说明，标明功能状态，不复制命令和参数。 |
| `docs/platform-kind-v1/verification.md` | 日期验收与未完成项 | 16份旧全局文档、各模块已有验收范围 | 少量结论/来源/日期/范围；完整日志私有；不声称今晚实时状态。 |
| `infrastructure/host/troubleshooting.md` | 宿主机/WSL/Docker故障诊断 | docker-maintenance.md、cluster.md、host/registry/entry代码 | mount visibility、启动错误集群、DNS/IP、Docker token/CA；无虚构全自动恢复。 |
| `infrastructure/registry/recovery.md` | 仓库备份与隔离恢复维护 | scanning-recovery.md、registry/recovery.yaml及prepare-recovery.py | 明确同版本/全目录/密钥/DB、BACKUP/SHA、隔离、空间与验收差别。 |
| `infrastructure/registry/scanning.md` | 扫描器与数据库维护 | scanning-recovery.md、registry/scanner-databases.yaml/scan.yaml | 库/报告身份、已知系统包问题范围、版本升级与业务删除策略分离。 |
| `infrastructure/flux/secrets.md` | SOPS与受保护身份的维护 | secrets-foundations.md、flux/secrets.yaml、encrypt.yaml | recipient、age主备、双丢失拒绝、私有口令/TLS输入来源；不贴值。 |
| `gitops/clusters/kind/README.md` | 声明入口和阶段所有权 | clusters/kind/*.yaml、flux/source.yaml | 只说明source/path/dependsOn/Ready及删除风险，不成为第二份环境config。 |
| `gitops/components/foundations/README.md` | 安全/存储/网络基础维护 | namespace-layout.md、secrets-foundations.md、foundations模板 | 目录归属和命名空间、Retain/PVC、访问标签与默认拒绝、容量非quota。 |

新增内容不得重复维护配置、版本或当前晋级身份；所有生成YAML/密文继续按现有入口维护。

## 三、455个代码、配置、模板及锁文件逐一处置

每个文件完整读取并记录摘要；按职责列出静态事实。生成声明与生成模板都保留，初始化/校验/回归程序都保留。本文档重构不改变它们的行为。

以下各项的“事实”是静态源码信息，资源数量是文件内对象数，不是集群当前对象数；SOPS只记录密文结构，无口令值。

### C001 gitops/.sops.yaml

- 源文件：[gitops/.sops.yaml](../gitops/.sops.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`creation_rules`。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`docs/README.md（拟新增）`。

### C002 gitops/clusters/kind/applications-info.yaml

- 源文件：[gitops/clusters/kind/applications-info.yaml](../gitops/clusters/kind/applications-info.yaml)；170行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Kustomization×10；命名空间：flux-system。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C003 gitops/clusters/kind/applications-investment.yaml

- 源文件：[gitops/clusters/kind/applications-investment.yaml](../gitops/clusters/kind/applications-investment.yaml)；153行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Kustomization×9；命名空间：flux-system。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C004 gitops/clusters/kind/applications-knowledge.yaml

- 源文件：[gitops/clusters/kind/applications-knowledge.yaml](../gitops/clusters/kind/applications-knowledge.yaml)；153行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Kustomization×9；命名空间：flux-system。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C005 gitops/clusters/kind/applications-tpl.yaml

- 源文件：[gitops/clusters/kind/applications-tpl.yaml](../gitops/clusters/kind/applications-tpl.yaml)；136行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Kustomization×8；命名空间：flux-system。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C006 gitops/clusters/kind/foundation.yaml

- 源文件：[gitops/clusters/kind/foundation.yaml](../gitops/clusters/kind/foundation.yaml)；59行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ServiceAccount×2, LimitRange×1, NetworkPolicy×2；命名空间：platform-system。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C007 gitops/clusters/kind/kustomization.yaml

- 源文件：[gitops/clusters/kind/kustomization.yaml](../gitops/clusters/kind/kustomization.yaml)；12行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C008 gitops/clusters/kind/namespace.yaml

- 源文件：[gitops/clusters/kind/namespace.yaml](../gitops/clusters/kind/namespace.yaml)；12行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；对象：Namespace×1。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C009 gitops/clusters/kind/registry-puller.sops.yaml

- 源文件：[gitops/clusters/kind/registry-puller.sops.yaml](../gitops/clusters/kind/registry-puller.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：platform-system。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C010 gitops/clusters/kind/release-info.yaml

- 源文件：[gitops/clusters/kind/release-info.yaml](../gitops/clusters/kind/release-info.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；对象：ConfigMap×1；命名空间：platform-system。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C011 gitops/clusters/kind/services.yaml

- 源文件：[gitops/clusters/kind/services.yaml](../gitops/clusters/kind/services.yaml)；233行；.yaml；完整SHA256见基线清单。
- 职责：Flux环境入口、分阶段编排或基础声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Kustomization×13；命名空间：flux-system。
- 处置：**保留原文件及行为**。保留stage/path/dependsOn和所有权；README说明控制器命名空间与业务命名空间不同。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C012 gitops/clusters/kind/services.yaml.j2

- 源文件：[gitops/clusters/kind/services.yaml.j2](../gitops/clusters/kind/services.yaml.j2)；24行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：elk_collector_enabled, elk_log_data_view_enabled, service_stage_paths, services_casdoor_enabled, services_elk_enabled, services_mongodb_enabled, services_ragflow_enabled。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/clusters/kind/README.md（拟新增）`。

### C013 gitops/components/app-platform/auth-app/casdoor/app.conf.j2

- 源文件：[gitops/components/app-platform/auth-app/casdoor/app.conf.j2](../gitops/components/app-platform/auth-app/casdoor/app.conf.j2)；16行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：casdoor_database, casdoor_database_user, casdoor_hostname, data_namespace, initializing, service_credentials。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C014 gitops/components/app-platform/auth-app/casdoor/config.sops.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/config.sops.yaml](../gitops/components/app-platform/auth-app/casdoor/config.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C015 gitops/components/app-platform/auth-app/casdoor/config.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/config.yaml](../gitops/components/app-platform/auth-app/casdoor/config.yaml)；12行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_casdoor_enabled`；键`casdoor_volume`；键`casdoor_hostname`；键`casdoor_database`；键`casdoor_database_user`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C016 gitops/components/app-platform/auth-app/casdoor/database/auth.sops.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/database/auth.sops.yaml](../gitops/components/app-platform/auth-app/casdoor/database/auth.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C017 gitops/components/app-platform/auth-app/casdoor/database/kustomization.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/database/kustomization.yaml](../gitops/components/app-platform/auth-app/casdoor/database/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C018 gitops/components/app-platform/auth-app/casdoor/database/workload.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/database/workload.yaml](../gitops/components/app-platform/auth-app/casdoor/database/workload.yaml)；35行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C019 gitops/components/app-platform/auth-app/casdoor/database/workload.yaml.j2

- 源文件：[gitops/components/app-platform/auth-app/casdoor/database/workload.yaml.j2](../gitops/components/app-platform/auth-app/casdoor/database/workload.yaml.j2)；35行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：casdoor_database, casdoor_database_user, data_namespace, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C020 gitops/components/app-platform/auth-app/casdoor/init/config.sops.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/init/config.sops.yaml](../gitops/components/app-platform/auth-app/casdoor/init/config.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C021 gitops/components/app-platform/auth-app/casdoor/init/identity.sops.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/init/identity.sops.yaml](../gitops/components/app-platform/auth-app/casdoor/init/identity.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C022 gitops/components/app-platform/auth-app/casdoor/init/kustomization.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/init/kustomization.yaml](../gitops/components/app-platform/auth-app/casdoor/init/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C023 gitops/components/app-platform/auth-app/casdoor/init/workload.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/init/workload.yaml](../gitops/components/app-platform/auth-app/casdoor/init/workload.yaml)；50行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C024 gitops/components/app-platform/auth-app/casdoor/init/workload.yaml.j2

- 源文件：[gitops/components/app-platform/auth-app/casdoor/init/workload.yaml.j2](../gitops/components/app-platform/auth-app/casdoor/init/workload.yaml.j2)；50行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, cluster_name, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C025 gitops/components/app-platform/auth-app/casdoor/kustomization.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/kustomization.yaml](../gitops/components/app-platform/auth-app/casdoor/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C026 gitops/components/app-platform/auth-app/casdoor/tls.sops.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/tls.sops.yaml](../gitops/components/app-platform/auth-app/casdoor/tls.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C027 gitops/components/app-platform/auth-app/casdoor/workload.yaml

- 源文件：[gitops/components/app-platform/auth-app/casdoor/workload.yaml](../gitops/components/app-platform/auth-app/casdoor/workload.yaml)；62行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C028 gitops/components/app-platform/auth-app/casdoor/workload.yaml.j2

- 源文件：[gitops/components/app-platform/auth-app/casdoor/workload.yaml.j2](../gitops/components/app-platform/auth-app/casdoor/workload.yaml.j2)；62行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, casdoor_hostname, cluster_name, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/auth-app/casdoor/README.md`。

### C029 gitops/components/app-platform/common/admin/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/admin/workload.yaml.j2](../gitops/components/app-platform/common/admin/workload.yaml.j2)；86行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：admin_cfg, app_images, app_namespace, application_name, cfg, deployment_id, ingress_namespace, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C030 gitops/components/app-platform/common/backend/database/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/database/workload.yaml.j2](../gitops/components/app-platform/common/backend/database/workload.yaml.j2)；69行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：application_name, cfg, cluster_name, data_namespace, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C031 gitops/components/app-platform/common/backend/identity/provision.py.j2

- 源文件：[gitops/components/app-platform/common/backend/identity/provision.py.j2](../gitops/components/app-platform/common/backend/identity/provision.py.j2)；98行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：application_name。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C032 gitops/components/app-platform/common/backend/identity/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/identity/workload.yaml.j2](../gitops/components/app-platform/common/backend/identity/workload.yaml.j2)；80行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_images, app_namespace, application_name, browser_clients, casdoor_hostname, cfg, lookup, mechanism_root, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C033 gitops/components/app-platform/common/backend/migration/verify-database.py.j2

- 源文件：[gitops/components/app-platform/common/backend/migration/verify-database.py.j2](../gitops/components/app-platform/common/backend/migration/verify-database.py.j2)；52行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C034 gitops/components/app-platform/common/backend/migration/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/migration/workload.yaml.j2](../gitops/components/app-platform/common/backend/migration/workload.yaml.j2)；42行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_images, application_name, cfg, lookup, mechanism_root, migration_job, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C035 gitops/components/app-platform/common/backend/rabbitmq/provision.py.j2

- 源文件：[gitops/components/app-platform/common/backend/rabbitmq/provision.py.j2](../gitops/components/app-platform/common/backend/rabbitmq/provision.py.j2)；129行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：application_name。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C036 gitops/components/app-platform/common/backend/rabbitmq/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/rabbitmq/workload.yaml.j2](../gitops/components/app-platform/common/backend/rabbitmq/workload.yaml.j2)；65行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_images, application_name, cfg, lookup, mechanism_root, messaging_namespace, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C037 gitops/components/app-platform/common/backend/redis/provision.py.j2

- 源文件：[gitops/components/app-platform/common/backend/redis/provision.py.j2](../gitops/components/app-platform/common/backend/redis/provision.py.j2)；73行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：application_name。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C038 gitops/components/app-platform/common/backend/redis/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/redis/workload.yaml.j2](../gitops/components/app-platform/common/backend/redis/workload.yaml.j2)；64行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_images, application_name, cfg, data_namespace, lookup, mechanism_root, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C039 gitops/components/app-platform/common/backend/runtime/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/runtime/workload.yaml.j2](../gitops/components/app-platform/common/backend/runtime/workload.yaml.j2)；267行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_images, app_namespace, application_name, casdoor_hostname, cfg, cluster_pod_subnet, data_namespace, deployment_id, ingress_namespace, object_storage_port, object_storage_region, provider_binding, provider_enabled, ragflow_ingestion_timeout_seconds, ragflow_port, receiver_enabled, registry_address, runtime_config_digest, service_access_hosts, service_bindings, service_enabled, service_env_prefix, service_relation, storage_enabled, workload_ca。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C040 gitops/components/app-platform/common/backend/service-identity/prepare.yaml

- 源文件：[gitops/components/app-platform/common/backend/service-identity/prepare.yaml](../gitops/components/app-platform/common/backend/service-identity/prepare.yaml)；97行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数16；入口任务“Require relation-specific service credentials and isolated organization”；末任务“Render explicit service identity resource list”；显式include/引用8处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/app-platform/common/backend/service-identity/README.md`。

### C041 gitops/components/app-platform/common/backend/service-identity/provision.py.j2

- 源文件：[gitops/components/app-platform/common/backend/service-identity/provision.py.j2](../gitops/components/app-platform/common/backend/service-identity/provision.py.j2)；82行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：application_name。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/backend/service-identity/README.md`。

### C042 gitops/components/app-platform/common/backend/service-identity/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/service-identity/workload.yaml.j2](../gitops/components/app-platform/common/backend/service-identity/workload.yaml.j2)；56行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_images, app_namespace, application_name, casdoor_hostname, cfg, ingress_namespace, lookup, mechanism_root, registry_address, service_access_hosts。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/backend/service-identity/README.md`。

### C043 gitops/components/app-platform/common/backend/stages.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/stages.yaml.j2](../gitops/components/app-platform/common/backend/stages.yaml.j2)；76行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：application_name, cfg, provider_enabled, receiver_enabled, service_enabled, storage_enabled。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C044 gitops/components/app-platform/common/backend/storage/prepare.yaml

- 源文件：[gitops/components/app-platform/common/backend/storage/prepare.yaml](../gitops/components/app-platform/common/backend/storage/prepare.yaml)；95行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数14；入口任务“Validate independent domain object storage boundaries”；末任务“Encrypt separate root provisioning input outside the application namespace”；显式include/引用7处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/app-platform/common/backend/storage/README.md`。

### C045 gitops/components/app-platform/common/backend/storage/verify-runtime.py

- 源文件：[gitops/components/app-platform/common/backend/storage/verify-runtime.py](../gitops/components/app-platform/common/backend/storage/verify-runtime.py)；49行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/app-platform/common/backend/storage/README.md`。

### C046 gitops/components/app-platform/common/backend/storage/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/backend/storage/workload.yaml.j2](../gitops/components/app-platform/common/backend/storage/workload.yaml.j2)；68行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：application_name, cfg, data_namespace, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/backend/storage/README.md`。

### C047 gitops/components/app-platform/common/web/workload.yaml.j2

- 源文件：[gitops/components/app-platform/common/web/workload.yaml.j2](../gitops/components/app-platform/common/web/workload.yaml.j2)；86行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_images, app_namespace, application_name, cfg, deployment_id, ingress_namespace, registry_address, web_cfg。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/common/README.md`。

### C048 gitops/components/app-platform/info-app/config.yaml

- 源文件：[gitops/components/app-platform/info-app/config.yaml](../gitops/components/app-platform/info-app/config.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`info_deployment`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/info-app/README.md`。

### C049 gitops/components/app-platform/info-app/info-admin-frontend/config.yaml

- 源文件：[gitops/components/app-platform/info-app/info-admin-frontend/config.yaml](../gitops/components/app-platform/info-app/info-admin-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`info_admin_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/info-app/info-admin-frontend/README.md`。

### C050 gitops/components/app-platform/info-app/info-admin-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/info-app/info-admin-frontend/image.lock.yaml](../gitops/components/app-platform/info-app/info-admin-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/info-app/info-admin-frontend/README.md`。

### C051 gitops/components/app-platform/info-app/info-admin-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-admin-frontend/kustomization.yaml](../gitops/components/app-platform/info-app/info-admin-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-admin-frontend/README.md`。

### C052 gitops/components/app-platform/info-app/info-admin-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-admin-frontend/workload.yaml](../gitops/components/app-platform/info-app/info-admin-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-admin-frontend/README.md`。

### C053 gitops/components/app-platform/info-app/info-backend/config.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/config.yaml](../gitops/components/app-platform/info-app/info-backend/config.yaml)；50行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`info_backend_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C054 gitops/components/app-platform/info-app/info-backend/database/bootstrap.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/database/bootstrap.sops.yaml](../gitops/components/app-platform/info-app/info-backend/database/bootstrap.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C055 gitops/components/app-platform/info-app/info-backend/database/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/database/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/database/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C056 gitops/components/app-platform/info-app/info-backend/database/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/database/runtime.sops.yaml](../gitops/components/app-platform/info-app/info-backend/database/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C057 gitops/components/app-platform/info-app/info-backend/database/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/database/workload.yaml](../gitops/components/app-platform/info-app/info-backend/database/workload.yaml)；67行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ServiceAccount×1, Job×1；命名空间：app-platform-dev, data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C058 gitops/components/app-platform/info-app/info-backend/identity/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/identity/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/identity/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C059 gitops/components/app-platform/info-app/info-backend/identity/provision.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/identity/provision.sops.yaml](../gitops/components/app-platform/info-app/info-backend/identity/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C060 gitops/components/app-platform/info-app/info-backend/identity/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/identity/runtime.sops.yaml](../gitops/components/app-platform/info-app/info-backend/identity/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C061 gitops/components/app-platform/info-app/info-backend/identity/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/identity/workload.yaml](../gitops/components/app-platform/info-app/info-backend/identity/workload.yaml)；180行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；对象：ConfigMap×2, NetworkPolicy×2, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C062 gitops/components/app-platform/info-app/info-backend/image.lock.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/image.lock.yaml](../gitops/components/app-platform/info-app/info-backend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C063 gitops/components/app-platform/info-app/info-backend/migration/auth.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/migration/auth.sops.yaml](../gitops/components/app-platform/info-app/info-backend/migration/auth.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C064 gitops/components/app-platform/info-app/info-backend/migration/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/migration/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/migration/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C065 gitops/components/app-platform/info-app/info-backend/migration/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/migration/workload.yaml](../gitops/components/app-platform/info-app/info-backend/migration/workload.yaml)；93行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C066 gitops/components/app-platform/info-app/info-backend/rabbitmq/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/rabbitmq/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/rabbitmq/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C067 gitops/components/app-platform/info-app/info-backend/rabbitmq/provision.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/rabbitmq/provision.sops.yaml](../gitops/components/app-platform/info-app/info-backend/rabbitmq/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：messaging-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C068 gitops/components/app-platform/info-app/info-backend/rabbitmq/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/rabbitmq/runtime.sops.yaml](../gitops/components/app-platform/info-app/info-backend/rabbitmq/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C069 gitops/components/app-platform/info-app/info-backend/rabbitmq/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/rabbitmq/workload.yaml](../gitops/components/app-platform/info-app/info-backend/rabbitmq/workload.yaml)；193行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：messaging-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C070 gitops/components/app-platform/info-app/info-backend/redis/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/redis/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/redis/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C071 gitops/components/app-platform/info-app/info-backend/redis/provision.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/redis/provision.sops.yaml](../gitops/components/app-platform/info-app/info-backend/redis/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C072 gitops/components/app-platform/info-app/info-backend/redis/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/redis/runtime.sops.yaml](../gitops/components/app-platform/info-app/info-backend/redis/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C073 gitops/components/app-platform/info-app/info-backend/redis/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/redis/workload.yaml](../gitops/components/app-platform/info-app/info-backend/redis/workload.yaml)；136行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C074 gitops/components/app-platform/info-app/info-backend/runtime/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/runtime/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/runtime/kustomization.yaml)；7行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C075 gitops/components/app-platform/info-app/info-backend/runtime/service.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/runtime/service.sops.yaml](../gitops/components/app-platform/info-app/info-backend/runtime/service.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C076 gitops/components/app-platform/info-app/info-backend/runtime/storage.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/runtime/storage.sops.yaml](../gitops/components/app-platform/info-app/info-backend/runtime/storage.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C077 gitops/components/app-platform/info-app/info-backend/runtime/tls.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/runtime/tls.sops.yaml](../gitops/components/app-platform/info-app/info-backend/runtime/tls.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C078 gitops/components/app-platform/info-app/info-backend/runtime/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/runtime/workload.yaml](../gitops/components/app-platform/info-app/info-backend/runtime/workload.yaml)；312行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×3, Deployment×3, Service×1, NetworkPolicy×4；命名空间：app-platform-dev；显式include/引用6处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C079 gitops/components/app-platform/info-app/info-backend/service-identity/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/service-identity/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/service-identity/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C080 gitops/components/app-platform/info-app/info-backend/service-identity/provision.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/service-identity/provision.sops.yaml](../gitops/components/app-platform/info-app/info-backend/service-identity/provision.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C081 gitops/components/app-platform/info-app/info-backend/service-identity/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/service-identity/workload.yaml](../gitops/components/app-platform/info-app/info-backend/service-identity/workload.yaml)；137行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×1, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C082 gitops/components/app-platform/info-app/info-backend/storage/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/storage/kustomization.yaml](../gitops/components/app-platform/info-app/info-backend/storage/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C083 gitops/components/app-platform/info-app/info-backend/storage/provision.sops.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/storage/provision.sops.yaml](../gitops/components/app-platform/info-app/info-backend/storage/provision.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C084 gitops/components/app-platform/info-app/info-backend/storage/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-backend/storage/workload.yaml](../gitops/components/app-platform/info-app/info-backend/storage/workload.yaml)；68行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-backend/README.md`。

### C085 gitops/components/app-platform/info-app/info-web-frontend/config.yaml

- 源文件：[gitops/components/app-platform/info-app/info-web-frontend/config.yaml](../gitops/components/app-platform/info-app/info-web-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`info_web_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/info-app/info-web-frontend/README.md`。

### C086 gitops/components/app-platform/info-app/info-web-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/info-app/info-web-frontend/image.lock.yaml](../gitops/components/app-platform/info-app/info-web-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/info-app/info-web-frontend/README.md`。

### C087 gitops/components/app-platform/info-app/info-web-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/info-app/info-web-frontend/kustomization.yaml](../gitops/components/app-platform/info-app/info-web-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/info-app/info-web-frontend/README.md`。

### C088 gitops/components/app-platform/info-app/info-web-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/info-app/info-web-frontend/workload.yaml](../gitops/components/app-platform/info-app/info-web-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/info-app/info-web-frontend/README.md`。

### C089 gitops/components/app-platform/investment-app/config.yaml

- 源文件：[gitops/components/app-platform/investment-app/config.yaml](../gitops/components/app-platform/investment-app/config.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`investment_deployment`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/investment-app/README.md`。

### C090 gitops/components/app-platform/investment-app/investment-admin-frontend/config.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-admin-frontend/config.yaml](../gitops/components/app-platform/investment-app/investment-admin-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`investment_admin_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-admin-frontend/README.md`。

### C091 gitops/components/app-platform/investment-app/investment-admin-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-admin-frontend/image.lock.yaml](../gitops/components/app-platform/investment-app/investment-admin-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-admin-frontend/README.md`。

### C092 gitops/components/app-platform/investment-app/investment-admin-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-admin-frontend/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-admin-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-admin-frontend/README.md`。

### C093 gitops/components/app-platform/investment-app/investment-admin-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-admin-frontend/workload.yaml](../gitops/components/app-platform/investment-app/investment-admin-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-admin-frontend/README.md`。

### C094 gitops/components/app-platform/investment-app/investment-backend/config.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/config.yaml](../gitops/components/app-platform/investment-app/investment-backend/config.yaml)；61行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`investment_backend_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C095 gitops/components/app-platform/investment-app/investment-backend/database/bootstrap.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/database/bootstrap.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/database/bootstrap.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C096 gitops/components/app-platform/investment-app/investment-backend/database/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/database/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-backend/database/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C097 gitops/components/app-platform/investment-app/investment-backend/database/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/database/runtime.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/database/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C098 gitops/components/app-platform/investment-app/investment-backend/database/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/database/workload.yaml](../gitops/components/app-platform/investment-app/investment-backend/database/workload.yaml)；66行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ServiceAccount×1, Job×1；命名空间：app-platform-dev, data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C099 gitops/components/app-platform/investment-app/investment-backend/identity/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/identity/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-backend/identity/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C100 gitops/components/app-platform/investment-app/investment-backend/identity/provision.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/identity/provision.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/identity/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C101 gitops/components/app-platform/investment-app/investment-backend/identity/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/identity/runtime.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/identity/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C102 gitops/components/app-platform/investment-app/investment-backend/identity/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/identity/workload.yaml](../gitops/components/app-platform/investment-app/investment-backend/identity/workload.yaml)；180行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；对象：ConfigMap×2, NetworkPolicy×2, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C103 gitops/components/app-platform/investment-app/investment-backend/image.lock.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/image.lock.yaml](../gitops/components/app-platform/investment-app/investment-backend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C104 gitops/components/app-platform/investment-app/investment-backend/migration/auth.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/migration/auth.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/migration/auth.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C105 gitops/components/app-platform/investment-app/investment-backend/migration/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/migration/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-backend/migration/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C106 gitops/components/app-platform/investment-app/investment-backend/migration/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/migration/workload.yaml](../gitops/components/app-platform/investment-app/investment-backend/migration/workload.yaml)；93行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C107 gitops/components/app-platform/investment-app/investment-backend/rabbitmq/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/rabbitmq/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-backend/rabbitmq/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C108 gitops/components/app-platform/investment-app/investment-backend/rabbitmq/provision.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/rabbitmq/provision.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/rabbitmq/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：messaging-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C109 gitops/components/app-platform/investment-app/investment-backend/rabbitmq/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/rabbitmq/runtime.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/rabbitmq/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C110 gitops/components/app-platform/investment-app/investment-backend/rabbitmq/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/rabbitmq/workload.yaml](../gitops/components/app-platform/investment-app/investment-backend/rabbitmq/workload.yaml)；193行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：messaging-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C111 gitops/components/app-platform/investment-app/investment-backend/redis/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/redis/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-backend/redis/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C112 gitops/components/app-platform/investment-app/investment-backend/redis/provision.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/redis/provision.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/redis/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C113 gitops/components/app-platform/investment-app/investment-backend/redis/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/redis/runtime.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/redis/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C114 gitops/components/app-platform/investment-app/investment-backend/redis/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/redis/workload.yaml](../gitops/components/app-platform/investment-app/investment-backend/redis/workload.yaml)；136行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C115 gitops/components/app-platform/investment-app/investment-backend/runtime/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/runtime/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-backend/runtime/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C116 gitops/components/app-platform/investment-app/investment-backend/runtime/service.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/runtime/service.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/runtime/service.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C117 gitops/components/app-platform/investment-app/investment-backend/runtime/tls.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/runtime/tls.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/runtime/tls.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C118 gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml](../gitops/components/app-platform/investment-app/investment-backend/runtime/workload.yaml)；292行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×3, Deployment×3, Service×1, NetworkPolicy×4；命名空间：app-platform-dev；显式include/引用6处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C119 gitops/components/app-platform/investment-app/investment-backend/service-identity/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/service-identity/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-backend/service-identity/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C120 gitops/components/app-platform/investment-app/investment-backend/service-identity/provision.sops.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/service-identity/provision.sops.yaml](../gitops/components/app-platform/investment-app/investment-backend/service-identity/provision.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C121 gitops/components/app-platform/investment-app/investment-backend/service-identity/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-backend/service-identity/workload.yaml](../gitops/components/app-platform/investment-app/investment-backend/service-identity/workload.yaml)；137行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×1, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-backend/README.md`。

### C122 gitops/components/app-platform/investment-app/investment-web-frontend/config.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-web-frontend/config.yaml](../gitops/components/app-platform/investment-app/investment-web-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`investment_web_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-web-frontend/README.md`。

### C123 gitops/components/app-platform/investment-app/investment-web-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-web-frontend/image.lock.yaml](../gitops/components/app-platform/investment-app/investment-web-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-web-frontend/README.md`。

### C124 gitops/components/app-platform/investment-app/investment-web-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-web-frontend/kustomization.yaml](../gitops/components/app-platform/investment-app/investment-web-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-web-frontend/README.md`。

### C125 gitops/components/app-platform/investment-app/investment-web-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/investment-app/investment-web-frontend/workload.yaml](../gitops/components/app-platform/investment-app/investment-web-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/investment-app/investment-web-frontend/README.md`。

### C126 gitops/components/app-platform/knowledge-app/config.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/config.yaml](../gitops/components/app-platform/knowledge-app/config.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`knowledge_deployment`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/README.md`。

### C127 gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/config.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/config.yaml](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`knowledge_admin_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md`。

### C128 gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/image.lock.yaml](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md`。

### C129 gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md`。

### C130 gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-admin-frontend/README.md`。

### C131 gitops/components/app-platform/knowledge-app/knowledge-backend/config.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/config.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/config.yaml)；65行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`knowledge_backend_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C132 gitops/components/app-platform/knowledge-app/knowledge-backend/database/bootstrap.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/database/bootstrap.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/database/bootstrap.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C133 gitops/components/app-platform/knowledge-app/knowledge-backend/database/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/database/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/database/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C134 gitops/components/app-platform/knowledge-app/knowledge-backend/database/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/database/runtime.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/database/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C135 gitops/components/app-platform/knowledge-app/knowledge-backend/database/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/database/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/database/workload.yaml)；67行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ServiceAccount×1, Job×1；命名空间：app-platform-dev, data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C136 gitops/components/app-platform/knowledge-app/knowledge-backend/identity/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/identity/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/identity/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C137 gitops/components/app-platform/knowledge-app/knowledge-backend/identity/provision.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/identity/provision.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/identity/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C138 gitops/components/app-platform/knowledge-app/knowledge-backend/identity/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/identity/runtime.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/identity/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C139 gitops/components/app-platform/knowledge-app/knowledge-backend/identity/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/identity/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/identity/workload.yaml)；180行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；对象：ConfigMap×2, NetworkPolicy×2, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C140 gitops/components/app-platform/knowledge-app/knowledge-backend/image.lock.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/image.lock.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C141 gitops/components/app-platform/knowledge-app/knowledge-backend/migration/auth.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/migration/auth.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/migration/auth.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C142 gitops/components/app-platform/knowledge-app/knowledge-backend/migration/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/migration/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/migration/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C143 gitops/components/app-platform/knowledge-app/knowledge-backend/migration/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/migration/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/migration/workload.yaml)；93行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C144 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/cleanup-runtime.py

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/cleanup-runtime.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/cleanup-runtime.py)；37行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：run。
- 处置：**保留原文件及行为**。精确identity/nonce清理验收记录；不可写作通用业务数据删除入口。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C145 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C146 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/prepare.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/prepare.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/prepare.yaml)；163行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数27；入口任务“Validate knowledge provider and upstream original ownership”；末任务“Render the provider Kustomize root”；显式include/引用13处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C147 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision-dataset.py

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision-dataset.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision-dataset.py)；39行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：call。
- 处置：**保留原文件及行为**。会用operator API创建远端dataset；未知同名与绑定变化拒绝；文档明确准备副作用。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C148 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/provision.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C149 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-info-http.py

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-info-http.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-info-http.py)；34行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：run。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C150 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-investment-http.py

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-investment-http.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-investment-http.py)；34行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：run。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C151 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-runtime.py

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-runtime.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify-runtime.py)；99行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：run。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C152 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify.py

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify.py](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/verify.py)；119行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：save_probe, execute。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C153 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/workload.yaml)；60行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C154 gitops/components/app-platform/knowledge-app/knowledge-backend/provider/workload.yaml.j2

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/provider/workload.yaml.j2](../gitops/components/app-platform/knowledge-app/knowledge-backend/provider/workload.yaml.j2)；60行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cfg, data_namespace, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/provider/README.md`。

### C155 gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C156 gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/provision.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/provision.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：messaging-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C157 gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/runtime.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C158 gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/rabbitmq/workload.yaml)；193行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：messaging-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C159 gitops/components/app-platform/knowledge-app/knowledge-backend/redis/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/redis/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/redis/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C160 gitops/components/app-platform/knowledge-app/knowledge-backend/redis/provision.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/redis/provision.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/redis/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C161 gitops/components/app-platform/knowledge-app/knowledge-backend/redis/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/redis/runtime.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/redis/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C162 gitops/components/app-platform/knowledge-app/knowledge-backend/redis/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/redis/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/redis/workload.yaml)；136行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C163 gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C164 gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/provider.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/provider.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/provider.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C165 gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/tls.sops.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/tls.sops.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/tls.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C166 gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-backend/runtime/workload.yaml)；294行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×2, Deployment×3, Service×1, NetworkPolicy×5；命名空间：app-platform-dev；显式include/引用6处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-backend/README.md`。

### C167 gitops/components/app-platform/knowledge-app/knowledge-web-frontend/config.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-web-frontend/config.yaml](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`knowledge_web_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md`。

### C168 gitops/components/app-platform/knowledge-app/knowledge-web-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-web-frontend/image.lock.yaml](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md`。

### C169 gitops/components/app-platform/knowledge-app/knowledge-web-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-web-frontend/kustomization.yaml](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md`。

### C170 gitops/components/app-platform/knowledge-app/knowledge-web-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/knowledge-app/knowledge-web-frontend/workload.yaml](../gitops/components/app-platform/knowledge-app/knowledge-web-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/knowledge-app/knowledge-web-frontend/README.md`。

### C171 gitops/components/app-platform/tpl-app/config.yaml

- 源文件：[gitops/components/app-platform/tpl-app/config.yaml](../gitops/components/app-platform/tpl-app/config.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`tpl_deployment`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/tpl-app/README.md`。

### C172 gitops/components/app-platform/tpl-app/tpl-admin-frontend/config.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-admin-frontend/config.yaml](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`tpl_admin_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md`。

### C173 gitops/components/app-platform/tpl-app/tpl-admin-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-admin-frontend/image.lock.yaml](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md`。

### C174 gitops/components/app-platform/tpl-app/tpl-admin-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-admin-frontend/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md`。

### C175 gitops/components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-admin-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-admin-frontend/README.md`。

### C176 gitops/components/app-platform/tpl-app/tpl-backend/config.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/config.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/config.yaml)；33行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`tpl_backend_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C177 gitops/components/app-platform/tpl-app/tpl-backend/database/bootstrap.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/database/bootstrap.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/database/bootstrap.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C178 gitops/components/app-platform/tpl-app/tpl-backend/database/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/database/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/database/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C179 gitops/components/app-platform/tpl-app/tpl-backend/database/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/database/runtime.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/database/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C180 gitops/components/app-platform/tpl-app/tpl-backend/database/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/database/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/database/workload.yaml)；66行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ServiceAccount×1, Job×1；命名空间：app-platform-dev, data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C181 gitops/components/app-platform/tpl-app/tpl-backend/identity/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/identity/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/identity/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md`。

### C182 gitops/components/app-platform/tpl-app/tpl-backend/identity/provision.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/identity/provision.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/identity/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md`。

### C183 gitops/components/app-platform/tpl-app/tpl-backend/identity/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/identity/runtime.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/identity/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md`。

### C184 gitops/components/app-platform/tpl-app/tpl-backend/identity/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/identity/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/identity/workload.yaml)；180行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；对象：ConfigMap×2, NetworkPolicy×2, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/identity/README.md`。

### C185 gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C186 gitops/components/app-platform/tpl-app/tpl-backend/migration/auth.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/migration/auth.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/migration/auth.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C187 gitops/components/app-platform/tpl-app/tpl-backend/migration/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/migration/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/migration/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C188 gitops/components/app-platform/tpl-app/tpl-backend/migration/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/migration/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/migration/workload.yaml)；93行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C189 gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md`。

### C190 gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/provision.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/provision.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：messaging-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md`。

### C191 gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/runtime.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/runtime.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md`。

### C192 gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/workload.yaml)；193行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：messaging-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/rabbitmq/README.md`。

### C193 gitops/components/app-platform/tpl-app/tpl-backend/redis/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/redis/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/redis/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C194 gitops/components/app-platform/tpl-app/tpl-backend/redis/provision.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/redis/provision.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/redis/provision.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C195 gitops/components/app-platform/tpl-app/tpl-backend/redis/runtime.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/redis/runtime.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/redis/runtime.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C196 gitops/components/app-platform/tpl-app/tpl-backend/redis/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/redis/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/redis/workload.yaml)；136行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, NetworkPolicy×2, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/README.md`。

### C197 gitops/components/app-platform/tpl-app/tpl-backend/runtime/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/runtime/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/runtime/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/runtime/README.md`。

### C198 gitops/components/app-platform/tpl-app/tpl-backend/runtime/tls.sops.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/runtime/tls.sops.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/runtime/tls.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/runtime/README.md`。

### C199 gitops/components/app-platform/tpl-app/tpl-backend/runtime/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-backend/runtime/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-backend/runtime/workload.yaml)；232行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×2, Deployment×3, Service×1, NetworkPolicy×3；命名空间：app-platform-dev；显式include/引用6处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-backend/runtime/README.md`。

### C200 gitops/components/app-platform/tpl-app/tpl-web-frontend/config.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-web-frontend/config.yaml](../gitops/components/app-platform/tpl-app/tpl-web-frontend/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`tpl_web_deployment`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md`。

### C201 gitops/components/app-platform/tpl-app/tpl-web-frontend/image.lock.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-web-frontend/image.lock.yaml](../gitops/components/app-platform/tpl-app/tpl-web-frontend/image.lock.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`repository`；键`digest`；键`source_revision`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md`。

### C202 gitops/components/app-platform/tpl-app/tpl-web-frontend/kustomization.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-web-frontend/kustomization.yaml](../gitops/components/app-platform/tpl-app/tpl-web-frontend/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md`。

### C203 gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml

- 源文件：[gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml](../gitops/components/app-platform/tpl-app/tpl-web-frontend/workload.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Deployment×1, Service×1, NetworkPolicy×1, Ingress×1；命名空间：app-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/app-platform/tpl-app/tpl-web-frontend/README.md`。

### C204 gitops/components/core/kustomization.yaml

- 源文件：[gitops/components/core/kustomization.yaml](../gitops/components/core/kustomization.yaml)；7行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/README.md`。

### C205 gitops/components/data-platform/elk/collector/acceptance.py

- 源文件：[gitops/components/data-platform/elk/collector/acceptance.py](../gitops/components/data-platform/elk/collector/acceptance.py)；67行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：verify_application_logs, get。
- 处置：**保留原文件及行为**。读取真实CRI与ES日志并比对哈希；不创建业务日志保留策略；无日志原文交付。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C206 gitops/components/data-platform/elk/collector/auth.sops.yaml

- 源文件：[gitops/components/data-platform/elk/collector/auth.sops.yaml](../gitops/components/data-platform/elk/collector/auth.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：sunmoon-log-collector。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C207 gitops/components/data-platform/elk/collector/config-identity.j2

- 源文件：[gitops/components/data-platform/elk/collector/config-identity.j2](../gitops/components/data-platform/elk/collector/config-identity.j2)；1行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, cluster_name, data_namespace, elk_collector_applications, elk_collector_memory_chunks, elk_collector_namespace, elk_collector_read_from_head, elk_collector_resources, elk_collector_state_directory, elk_ingest_username, logstash_ingest_port。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C208 gitops/components/data-platform/elk/collector/config.yaml

- 源文件：[gitops/components/data-platform/elk/collector/config.yaml](../gitops/components/data-platform/elk/collector/config.yaml)；15行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`elk_collector_enabled`；键`elk_collector_namespace`；键`elk_collector_applications`；键`elk_collector_state_directory`；键`elk_collector_memory_chunks`；键`elk_collector_resources`；键`elk_collector_read_from_head`；键`elk_collector_initial_budget_bytes`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C209 gitops/components/data-platform/elk/collector/kustomization.yaml

- 源文件：[gitops/components/data-platform/elk/collector/kustomization.yaml](../gitops/components/data-platform/elk/collector/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C210 gitops/components/data-platform/elk/collector/prepare.yaml

- 源文件：[gitops/components/data-platform/elk/collector/prepare.yaml](../gitops/components/data-platform/elk/collector/prepare.yaml)；79行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数10；入口任务“Validate the collector's bounded responsibility”；末任务“Render explicit collector root”；显式include/引用5处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C211 gitops/components/data-platform/elk/collector/puller.sops.yaml

- 源文件：[gitops/components/data-platform/elk/collector/puller.sops.yaml](../gitops/components/data-platform/elk/collector/puller.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：sunmoon-log-collector。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C212 gitops/components/data-platform/elk/collector/workload.yaml

- 源文件：[gitops/components/data-platform/elk/collector/workload.yaml](../gitops/components/data-platform/elk/collector/workload.yaml)；143行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Namespace×1, ServiceAccount×1, ConfigMap×1, DaemonSet×1, NetworkPolicy×1；命名空间：sunmoon-log-collector；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C213 gitops/components/data-platform/elk/collector/workload.yaml.j2

- 源文件：[gitops/components/data-platform/elk/collector/workload.yaml.j2](../gitops/components/data-platform/elk/collector/workload.yaml.j2)；144行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, cluster_name, data_namespace, elk_collector_applications, elk_collector_input_digest, elk_collector_memory_chunks, elk_collector_namespace, elk_collector_read_from_head, elk_collector_resources, elk_collector_state_directory, elk_ingest_username, image_map, logstash_ingest_port, lookup, playbook_dir, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/collector/README.md`。

### C214 gitops/components/data-platform/elk/config.yaml

- 源文件：[gitops/components/data-platform/elk/config.yaml](../gitops/components/data-platform/elk/config.yaml)；32行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_elk_enabled`；键`services_elasticsearch_enabled`；键`services_kibana_enabled`；键`services_logstash_enabled`；键`elasticsearch_volume`；键`kibana_volume`；键`logstash_volume`；键`elasticsearch_heap`；键`elasticsearch_resources`；键`kibana_resources`；键`logstash_heap`；键`logstash_resources`；键`elasticsearch_port`；键`kibana_port`；键`logstash_ingest_port`；键`elk_index_prefix`；键`elk_init_generation`；键`elk_logstash_writer`；键`elk_log_reader`；键`elk_ingest_username`；键`elk_max_map_count`；键`elk_logstash_max_content_bytes`；显式include/引用3处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C215 gitops/components/data-platform/elk/elasticsearch/auth.sops.yaml

- 源文件：[gitops/components/data-platform/elk/elasticsearch/auth.sops.yaml](../gitops/components/data-platform/elk/elasticsearch/auth.sops.yaml)；26行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C216 gitops/components/data-platform/elk/elasticsearch/kustomization.yaml

- 源文件：[gitops/components/data-platform/elk/elasticsearch/kustomization.yaml](../gitops/components/data-platform/elk/elasticsearch/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C217 gitops/components/data-platform/elk/elasticsearch/workload.yaml

- 源文件：[gitops/components/data-platform/elk/elasticsearch/workload.yaml](../gitops/components/data-platform/elk/elasticsearch/workload.yaml)；125行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×1, ConfigMap×1, StatefulSet×1, NetworkPolicy×2；命名空间：data-platform-dev；显式include/引用3处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C218 gitops/components/data-platform/elk/elasticsearch/workload.yaml.j2

- 源文件：[gitops/components/data-platform/elk/elasticsearch/workload.yaml.j2](../gitops/components/data-platform/elk/elasticsearch/workload.yaml.j2)；125行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, elasticsearch_heap, elasticsearch_input_digest, elasticsearch_port, elasticsearch_resources, elasticsearch_volume, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C219 gitops/components/data-platform/elk/initialize/auth.sops.yaml

- 源文件：[gitops/components/data-platform/elk/initialize/auth.sops.yaml](../gitops/components/data-platform/elk/initialize/auth.sops.yaml)；28行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C220 gitops/components/data-platform/elk/initialize/kustomization.yaml

- 源文件：[gitops/components/data-platform/elk/initialize/kustomization.yaml](../gitops/components/data-platform/elk/initialize/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C221 gitops/components/data-platform/elk/initialize/workload.yaml

- 源文件：[gitops/components/data-platform/elk/initialize/workload.yaml](../gitops/components/data-platform/elk/initialize/workload.yaml)；39行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C222 gitops/components/data-platform/elk/initialize/workload.yaml.j2

- 源文件：[gitops/components/data-platform/elk/initialize/workload.yaml.j2](../gitops/components/data-platform/elk/initialize/workload.yaml.j2)；39行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：data_namespace, elasticsearch_port, elk_init_generation, elk_log_reader, elk_logstash_writer, image_map, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C223 gitops/components/data-platform/elk/kibana/auth.sops.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/auth.sops.yaml](../gitops/components/data-platform/elk/kibana/auth.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C224 gitops/components/data-platform/elk/kibana/data-view/admin.sops.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/admin.sops.yaml](../gitops/components/data-platform/elk/kibana/data-view/admin.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C225 gitops/components/data-platform/elk/kibana/data-view/config.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/config.yaml](../gitops/components/data-platform/elk/kibana/data-view/config.yaml)；7行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`elk_log_data_view_enabled`；键`elk_log_data_view_id`；键`elk_log_data_view_generation`；键`elk_log_data_view_user`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C226 gitops/components/data-platform/elk/kibana/data-view/initialize-identity.js.j2

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/initialize-identity.js.j2](../gitops/components/data-platform/elk/kibana/data-view/initialize-identity.js.j2)；36行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, elk_index_prefix, elk_log_data_view_user。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C227 gitops/components/data-platform/elk/kibana/data-view/initialize.js.j2

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/initialize.js.j2](../gitops/components/data-platform/elk/kibana/data-view/initialize.js.j2)；23行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：elk_index_prefix, elk_log_data_view_id。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C228 gitops/components/data-platform/elk/kibana/data-view/kustomization.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/kustomization.yaml](../gitops/components/data-platform/elk/kibana/data-view/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C229 gitops/components/data-platform/elk/kibana/data-view/prepare.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/prepare.yaml](../gitops/components/data-platform/elk/kibana/data-view/prepare.yaml)；70行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数9；入口任务“Validate declarative Kibana view identity”；末任务“Render explicit saved-object component root”；显式include/引用7处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C230 gitops/components/data-platform/elk/kibana/data-view/service-identity.sops.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/service-identity.sops.yaml](../gitops/components/data-platform/elk/kibana/data-view/service-identity.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C231 gitops/components/data-platform/elk/kibana/data-view/tls-client.js.j2

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/tls-client.js.j2](../gitops/components/data-platform/elk/kibana/data-view/tls-client.js.j2)；28行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：data_namespace, elasticsearch_port, kibana_port。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C232 gitops/components/data-platform/elk/kibana/data-view/workload.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/workload.yaml](../gitops/components/data-platform/elk/kibana/data-view/workload.yaml)；161行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1, NetworkPolicy×2；命名空间：data-platform-dev；显式include/引用3处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C233 gitops/components/data-platform/elk/kibana/data-view/workload.yaml.j2

- 源文件：[gitops/components/data-platform/elk/kibana/data-view/workload.yaml.j2](../gitops/components/data-platform/elk/kibana/data-view/workload.yaml.j2)；74行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：data_namespace, elasticsearch_port, elk_data_view_input_digest, elk_log_data_view_generation, image_map, kibana_port, lookup, playbook_dir, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/kibana/data-view/README.md`。

### C234 gitops/components/data-platform/elk/kibana/kibana.yml.j2

- 源文件：[gitops/components/data-platform/elk/kibana/kibana.yml.j2](../gitops/components/data-platform/elk/kibana/kibana.yml.j2)；18行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：data_namespace, elasticsearch_port, elk_credentials, kibana_port。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C235 gitops/components/data-platform/elk/kibana/kustomization.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/kustomization.yaml](../gitops/components/data-platform/elk/kibana/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C236 gitops/components/data-platform/elk/kibana/workload.yaml

- 源文件：[gitops/components/data-platform/elk/kibana/workload.yaml](../gitops/components/data-platform/elk/kibana/workload.yaml)；52行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×1, StatefulSet×1, NetworkPolicy×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C237 gitops/components/data-platform/elk/kibana/workload.yaml.j2

- 源文件：[gitops/components/data-platform/elk/kibana/workload.yaml.j2](../gitops/components/data-platform/elk/kibana/workload.yaml.j2)；52行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, image_map, kibana_input_digest, kibana_port, kibana_resources, kibana_volume, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C238 gitops/components/data-platform/elk/logstash/auth.sops.yaml

- 源文件：[gitops/components/data-platform/elk/logstash/auth.sops.yaml](../gitops/components/data-platform/elk/logstash/auth.sops.yaml)；26行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C239 gitops/components/data-platform/elk/logstash/kustomization.yaml

- 源文件：[gitops/components/data-platform/elk/logstash/kustomization.yaml](../gitops/components/data-platform/elk/logstash/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C240 gitops/components/data-platform/elk/logstash/workload.yaml

- 源文件：[gitops/components/data-platform/elk/logstash/workload.yaml](../gitops/components/data-platform/elk/logstash/workload.yaml)；135行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×1, ConfigMap×1, StatefulSet×1, NetworkPolicy×1；命名空间：data-platform-dev；显式include/引用3处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C241 gitops/components/data-platform/elk/logstash/workload.yaml.j2

- 源文件：[gitops/components/data-platform/elk/logstash/workload.yaml.j2](../gitops/components/data-platform/elk/logstash/workload.yaml.j2)；137行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, elasticsearch_port, elk_collector_enabled, elk_collector_namespace, elk_index_prefix, elk_ingest_username, elk_logstash_max_content_bytes, elk_logstash_writer, image_map, logstash_heap, logstash_ingest_port, logstash_input_digest, logstash_resources, logstash_volume, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C242 gitops/components/data-platform/elk/prepare.yaml

- 源文件：[gitops/components/data-platform/elk/prepare.yaml](../gitops/components/data-platform/elk/prepare.yaml)；183行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数22；入口任务“Validate single node ELK profile and independent accounts”；末任务“Aggregate the post-initialization runtime components”；显式include/引用21处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C243 gitops/components/data-platform/elk/runtime/kustomization.yaml

- 源文件：[gitops/components/data-platform/elk/runtime/kustomization.yaml](../gitops/components/data-platform/elk/runtime/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C244 gitops/components/data-platform/elk/verify.py

- 源文件：[gitops/components/data-platform/elk/verify.py](../gitops/components/data-platform/elk/verify.py)；134行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：require, forward, TrustedTunnel, main, connect, request。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/elk/README.md`。

### C245 gitops/components/data-platform/infinity/config.yaml

- 源文件：[gitops/components/data-platform/infinity/config.yaml](../gitops/components/data-platform/infinity/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_infinity_enabled`；键`infinity_volume`；键`infinity_buffer_size`；键`infinity_memindex_quota`；键`infinity_resources`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/infinity/README.md`。

### C246 gitops/components/data-platform/infinity/infinity_conf.toml.j2

- 源文件：[gitops/components/data-platform/infinity/infinity_conf.toml.j2](../gitops/components/data-platform/infinity/infinity_conf.toml.j2)；56行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：infinity_buffer_size, infinity_memindex_quota。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/infinity/README.md`。

### C247 gitops/components/data-platform/infinity/kustomization.yaml

- 源文件：[gitops/components/data-platform/infinity/kustomization.yaml](../gitops/components/data-platform/infinity/kustomization.yaml)；3行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/infinity/README.md`。

### C248 gitops/components/data-platform/infinity/prepare.yaml

- 源文件：[gitops/components/data-platform/infinity/prepare.yaml](../gitops/components/data-platform/infinity/prepare.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数3；入口任务“Validate bounded Infinity profile”；末任务“Declare explicit Infinity root”；显式include/引用3处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/infinity/README.md`。

### C249 gitops/components/data-platform/infinity/workload.yaml

- 源文件：[gitops/components/data-platform/infinity/workload.yaml](../gitops/components/data-platform/infinity/workload.yaml)；148行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Service×2, StatefulSet×1, NetworkPolicy×2；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/infinity/README.md`。

### C250 gitops/components/data-platform/infinity/workload.yaml.j2

- 源文件：[gitops/components/data-platform/infinity/workload.yaml.j2](../gitops/components/data-platform/infinity/workload.yaml.j2)；93行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, image_map, infinity_resources, infinity_volume, lookup, playbook_dir, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/infinity/README.md`。

### C251 gitops/components/data-platform/kustomization.yaml

- 源文件：[gitops/components/data-platform/kustomization.yaml](../gitops/components/data-platform/kustomization.yaml)；12行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/README.md`。

### C252 gitops/components/data-platform/mongodb/auth.sops.yaml

- 源文件：[gitops/components/data-platform/mongodb/auth.sops.yaml](../gitops/components/data-platform/mongodb/auth.sops.yaml)；27行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C253 gitops/components/data-platform/mongodb/common.js

- 源文件：[gitops/components/data-platform/mongodb/common.js](../gitops/components/data-platform/mongodb/common.js)；17行；.js；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C254 gitops/components/data-platform/mongodb/config.yaml

- 源文件：[gitops/components/data-platform/mongodb/config.yaml](../gitops/components/data-platform/mongodb/config.yaml)；13行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_mongodb_enabled`；键`mongodb_volume`；键`mongodb_port`；键`mongodb_replica_set`；键`mongodb_acceptance_database`；键`mongodb_init_generation`；键`mongodb_wiredtiger_cache_gib`；键`mongodb_oplog_mib`；键`mongodb_resources`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C255 gitops/components/data-platform/mongodb/health.js

- 源文件：[gitops/components/data-platform/mongodb/health.js](../gitops/components/data-platform/mongodb/health.js)；6行；.js；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C256 gitops/components/data-platform/mongodb/initialize.js

- 源文件：[gitops/components/data-platform/mongodb/initialize.js](../gitops/components/data-platform/mongodb/initialize.js)；35行；.js；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C257 gitops/components/data-platform/mongodb/initialize/auth.sops.yaml

- 源文件：[gitops/components/data-platform/mongodb/initialize/auth.sops.yaml](../gitops/components/data-platform/mongodb/initialize/auth.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C258 gitops/components/data-platform/mongodb/initialize/kustomization.yaml

- 源文件：[gitops/components/data-platform/mongodb/initialize/kustomization.yaml](../gitops/components/data-platform/mongodb/initialize/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C259 gitops/components/data-platform/mongodb/initialize/workload.yaml

- 源文件：[gitops/components/data-platform/mongodb/initialize/workload.yaml](../gitops/components/data-platform/mongodb/initialize/workload.yaml)；45行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Job×1, NetworkPolicy×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C260 gitops/components/data-platform/mongodb/initialize/workload.yaml.j2

- 源文件：[gitops/components/data-platform/mongodb/initialize/workload.yaml.j2](../gitops/components/data-platform/mongodb/initialize/workload.yaml.j2)；45行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：data_namespace, image_map, mongodb_acceptance_database, mongodb_init_generation, mongodb_port, mongodb_replica_set, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C261 gitops/components/data-platform/mongodb/kustomization.yaml

- 源文件：[gitops/components/data-platform/mongodb/kustomization.yaml](../gitops/components/data-platform/mongodb/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C262 gitops/components/data-platform/mongodb/persistence.js

- 源文件：[gitops/components/data-platform/mongodb/persistence.js](../gitops/components/data-platform/mongodb/persistence.js)；22行；.js；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C263 gitops/components/data-platform/mongodb/prepare.yaml

- 源文件：[gitops/components/data-platform/mongodb/prepare.yaml](../gitops/components/data-platform/mongodb/prepare.yaml)；93行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数10；入口任务“Validate the owned single member MongoDB profile”；末任务“Render explicit MongoDB roots”；显式include/引用9处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C264 gitops/components/data-platform/mongodb/verify.js

- 源文件：[gitops/components/data-platform/mongodb/verify.js](../gitops/components/data-platform/mongodb/verify.js)；45行；.js；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。限定集合事务/权限验收及精确清理；不证明业务身份或灾备。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C265 gitops/components/data-platform/mongodb/workload.yaml

- 源文件：[gitops/components/data-platform/mongodb/workload.yaml](../gitops/components/data-platform/mongodb/workload.yaml)；242行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×1, ConfigMap×1, StatefulSet×1, NetworkPolicy×1；命名空间：data-platform-dev；显式include/引用3处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C266 gitops/components/data-platform/mongodb/workload.yaml.j2

- 源文件：[gitops/components/data-platform/mongodb/workload.yaml.j2](../gitops/components/data-platform/mongodb/workload.yaml.j2)；116行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, image_map, lookup, mongodb_acceptance_database, mongodb_input_digest, mongodb_oplog_mib, mongodb_port, mongodb_replica_set, mongodb_resources, mongodb_volume, mongodb_wiredtiger_cache_gib, playbook_dir, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/mongodb/README.md`。

### C267 gitops/components/data-platform/neo4j/auth.sops.yaml

- 源文件：[gitops/components/data-platform/neo4j/auth.sops.yaml](../gitops/components/data-platform/neo4j/auth.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C268 gitops/components/data-platform/neo4j/config.yaml

- 源文件：[gitops/components/data-platform/neo4j/config.yaml](../gitops/components/data-platform/neo4j/config.yaml)；13行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_neo4j_enabled`；键`neo4j_failed_rollout_recovery`；键`neo4j_volume`；键`neo4j_heap`；键`neo4j_pagecache`；键`neo4j_https_port`；键`neo4j_bolt_port`；键`neo4j_resources`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C269 gitops/components/data-platform/neo4j/kustomization.yaml

- 源文件：[gitops/components/data-platform/neo4j/kustomization.yaml](../gitops/components/data-platform/neo4j/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C270 gitops/components/data-platform/neo4j/prepare.yaml

- 源文件：[gitops/components/data-platform/neo4j/prepare.yaml](../gitops/components/data-platform/neo4j/prepare.yaml)；65行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数9；入口任务“Validate the owned Neo4j profile”；末任务“Render the explicit graph component root”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C271 gitops/components/data-platform/neo4j/recover-rollout.yaml

- 源文件：[gitops/components/data-platform/neo4j/recover-rollout.yaml](../gitops/components/data-platform/neo4j/recover-rollout.yaml)；85行；.yaml；完整SHA256见基线清单。
- 职责：限定旧不健康rollout的故障恢复任务。
- 阅读记录：任务数10；入口任务“Read the graph template from the promoted Git object”；末任务“Gracefully remove only the observed failed old Pod with API preconditions”；显式include/引用2处。
- 处置：**保留原文件及行为**。保留UID/revision/健康守卫；文档不能泛化删除所有旧Pod或卷。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C272 gitops/components/data-platform/neo4j/verify.py

- 源文件：[gitops/components/data-platform/neo4j/verify.py](../gitops/components/data-platform/neo4j/verify.py)；106行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：require, forward, TrustedTunnel, main, connect, request, query。
- 处置：**保留原文件及行为**。实际HTTPS图事务/回滚和Bolt TLS协商；未证明驱动业务会话、HA或备份恢复。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C273 gitops/components/data-platform/neo4j/workload.yaml

- 源文件：[gitops/components/data-platform/neo4j/workload.yaml](../gitops/components/data-platform/neo4j/workload.yaml)；122行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×1, ConfigMap×1, StatefulSet×1, NetworkPolicy×1；命名空间：data-platform-dev；显式include/引用3处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C274 gitops/components/data-platform/neo4j/workload.yaml.j2

- 源文件：[gitops/components/data-platform/neo4j/workload.yaml.j2](../gitops/components/data-platform/neo4j/workload.yaml.j2)；122行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, image_map, neo4j_bolt_port, neo4j_heap, neo4j_https_port, neo4j_input_digest, neo4j_pagecache, neo4j_resources, neo4j_volume, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/neo4j/README.md`。

### C275 gitops/components/data-platform/object-storage/auth.sops.yaml

- 源文件：[gitops/components/data-platform/object-storage/auth.sops.yaml](../gitops/components/data-platform/object-storage/auth.sops.yaml)；26行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/object-storage/README.md`。

### C276 gitops/components/data-platform/object-storage/config.yaml

- 源文件：[gitops/components/data-platform/object-storage/config.yaml](../gitops/components/data-platform/object-storage/config.yaml)；16行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_object_storage_enabled`；键`object_storage_volume`；键`object_storage_port`；键`object_storage_console_port`；键`object_storage_region`；键`object_storage_license_file`；键`object_storage_resources`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/object-storage/README.md`。

### C277 gitops/components/data-platform/object-storage/kustomization.yaml

- 源文件：[gitops/components/data-platform/object-storage/kustomization.yaml](../gitops/components/data-platform/object-storage/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/object-storage/README.md`。

### C278 gitops/components/data-platform/object-storage/prepare.yaml

- 源文件：[gitops/components/data-platform/object-storage/prepare.yaml](../gitops/components/data-platform/object-storage/prepare.yaml)；130行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数23；入口任务“Validate the object storage profile and existing license source”；末任务“Render the object storage StatefulSet into the services candidate”；显式include/引用10处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/object-storage/README.md`。

### C279 gitops/components/data-platform/object-storage/verify.py

- 源文件：[gitops/components/data-platform/object-storage/verify.py](../gitops/components/data-platform/object-storage/verify.py)；123行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：require, main, mc。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/object-storage/README.md`。

### C280 gitops/components/data-platform/object-storage/workload.yaml

- 源文件：[gitops/components/data-platform/object-storage/workload.yaml](../gitops/components/data-platform/object-storage/workload.yaml)；50行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×1, StatefulSet×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/object-storage/README.md`。

### C281 gitops/components/data-platform/object-storage/workload.yaml.j2

- 源文件：[gitops/components/data-platform/object-storage/workload.yaml.j2](../gitops/components/data-platform/object-storage/workload.yaml.j2)；50行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, image_map, object_storage_console_port, object_storage_input_digest, object_storage_port, object_storage_region, object_storage_resources, object_storage_volume, registry_address, services_object_storage_enabled。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/object-storage/README.md`。

### C282 gitops/components/data-platform/postgresql/auth.sops.yaml

- 源文件：[gitops/components/data-platform/postgresql/auth.sops.yaml](../gitops/components/data-platform/postgresql/auth.sops.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/postgresql/README.md`。

### C283 gitops/components/data-platform/postgresql/config.yaml

- 源文件：[gitops/components/data-platform/postgresql/config.yaml](../gitops/components/data-platform/postgresql/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_postgresql_enabled`；键`postgresql_volume`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/postgresql/README.md`。

### C284 gitops/components/data-platform/postgresql/kustomization.yaml

- 源文件：[gitops/components/data-platform/postgresql/kustomization.yaml](../gitops/components/data-platform/postgresql/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/postgresql/README.md`。

### C285 gitops/components/data-platform/postgresql/workload.yaml

- 源文件：[gitops/components/data-platform/postgresql/workload.yaml](../gitops/components/data-platform/postgresql/workload.yaml)；86行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×2, StatefulSet×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/postgresql/README.md`。

### C286 gitops/components/data-platform/postgresql/workload.yaml.j2

- 源文件：[gitops/components/data-platform/postgresql/workload.yaml.j2](../gitops/components/data-platform/postgresql/workload.yaml.j2)；92行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, component_namespaces, image, image_map, registry_address, services_postgresql_enabled, services_volumes, volume。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/postgresql/README.md`。

### C287 gitops/components/data-platform/ragflow/.dockerignore

- 源文件：[gitops/components/data-platform/ragflow/.dockerignore](../gitops/components/data-platform/ragflow/.dockerignore)；2行；.dockerignore；完整SHA256见基线清单。
- 职责：生成物/构建上下文隔离规则。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留隐藏配置；文档扫描不能遗漏规则或把被忽略运行产物当版本资产。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C288 gitops/components/data-platform/ragflow/Dockerfile

- 源文件：[gitops/components/data-platform/ragflow/Dockerfile](../gitops/components/data-platform/ragflow/Dockerfile)；21行；Dockerfile；完整SHA256见基线清单。
- 职责：固定官方基线的最小派生构建。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留source SHA守卫、非root和运行边界；不能误删为一次性调试程序。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C289 gitops/components/data-platform/ragflow/config.yaml

- 源文件：[gitops/components/data-platform/ragflow/config.yaml](../gitops/components/data-platform/ragflow/config.yaml)；18行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_ragflow_enabled`；键`ragflow_database`；键`ragflow_database_owner`；键`ragflow_database_runtime`；键`ragflow_bucket`；键`ragflow_storage_user`；键`ragflow_initialize_generation`；键`ragflow_port`；键`ragflow_node`；键`ragflow_ingestion_timeout_seconds`；键`ragflow_api_resources`；键`ragflow_worker_resources`；显式include/引用2处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C290 gitops/components/data-platform/ragflow/database/bootstrap.sops.yaml

- 源文件：[gitops/components/data-platform/ragflow/database/bootstrap.sops.yaml](../gitops/components/data-platform/ragflow/database/bootstrap.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C291 gitops/components/data-platform/ragflow/database/kustomization.yaml

- 源文件：[gitops/components/data-platform/ragflow/database/kustomization.yaml](../gitops/components/data-platform/ragflow/database/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C292 gitops/components/data-platform/ragflow/database/workload.yaml

- 源文件：[gitops/components/data-platform/ragflow/database/workload.yaml](../gitops/components/data-platform/ragflow/database/workload.yaml)；66行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ServiceAccount×1, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C293 gitops/components/data-platform/ragflow/database/workload.yaml.j2

- 源文件：[gitops/components/data-platform/ragflow/database/workload.yaml.j2](../gitops/components/data-platform/ragflow/database/workload.yaml.j2)；1行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：lookup, playbook_dir。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C294 gitops/components/data-platform/ragflow/health.py

- 源文件：[gitops/components/data-platform/ragflow/health.py](../gitops/components/data-platform/ragflow/health.py)；18行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C295 gitops/components/data-platform/ragflow/image-budget.py

- 源文件：[gitops/components/data-platform/ragflow/image-budget.py](../gitops/components/data-platform/ragflow/image-budget.py)；18行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C296 gitops/components/data-platform/ragflow/image-build.yaml

- 源文件：[gitops/components/data-platform/ragflow/image-build.yaml](../gitops/components/data-platform/ragflow/image-build.yaml)；166行；.yaml；完整SHA256见基线清单。
- 职责：模块实现或运行声明。
- 阅读记录：任务数33；入口任务“End when the component is disabled”；末任务“Preserve public formal inventory on builds and repeat verification”；显式include/引用5处。
- 处置：**保留原文件及行为**。保留原位置和行为；责任说明归就近手册。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C297 gitops/components/data-platform/ragflow/image-publish.yaml

- 源文件：[gitops/components/data-platform/ragflow/image-publish.yaml](../gitops/components/data-platform/ragflow/image-publish.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：模块实现或运行声明。
- 阅读记录：显式include/引用1处。
- 处置：**保留原文件及行为**。保留原位置和行为；责任说明归就近手册。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C298 gitops/components/data-platform/ragflow/image.lock.json

- 源文件：[gitops/components/data-platform/ragflow/image.lock.json](../gitops/components/data-platform/ragflow/image.lock.json)；18行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`archive_sha256`；键`base_manifest`；键`dockerfile_sha256`；键`images`；键`platform`；键`schema_version`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C299 gitops/components/data-platform/ragflow/initialize.py

- 源文件：[gitops/components/data-platform/ragflow/initialize.py](../gitops/components/data-platform/ragflow/initialize.py)；64行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：identifier。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C300 gitops/components/data-platform/ragflow/initialize/auth.sops.yaml

- 源文件：[gitops/components/data-platform/ragflow/initialize/auth.sops.yaml](../gitops/components/data-platform/ragflow/initialize/auth.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C301 gitops/components/data-platform/ragflow/initialize/kustomization.yaml

- 源文件：[gitops/components/data-platform/ragflow/initialize/kustomization.yaml](../gitops/components/data-platform/ragflow/initialize/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C302 gitops/components/data-platform/ragflow/initialize/workload.yaml

- 源文件：[gitops/components/data-platform/ragflow/initialize/workload.yaml](../gitops/components/data-platform/ragflow/initialize/workload.yaml)；263行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C303 gitops/components/data-platform/ragflow/initialize/workload.yaml.j2

- 源文件：[gitops/components/data-platform/ragflow/initialize/workload.yaml.j2](../gitops/components/data-platform/ragflow/initialize/workload.yaml.j2)；63行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, lookup, playbook_dir, ragflow_initialize_generation, ragflow_node, ragflow_runtime_image, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C304 gitops/components/data-platform/ragflow/prepare.yaml

- 源文件：[gitops/components/data-platform/ragflow/prepare.yaml](../gitops/components/data-platform/ragflow/prepare.yaml)；164行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数19；入口任务“Load the separately reviewed non-root runtime image”；末任务“Declare explicit RAGFlow roots”；显式include/引用21处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C305 gitops/components/data-platform/ragflow/runtime.py

- 源文件：[gitops/components/data-platform/ragflow/runtime.py](../gitops/components/data-platform/ragflow/runtime.py)；138行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：initialize_logging, main, collect, redact, record_factory, restrict_surface, ready, start_progress, stop_progress, health。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C306 gitops/components/data-platform/ragflow/runtime/auth.sops.yaml

- 源文件：[gitops/components/data-platform/ragflow/runtime/auth.sops.yaml](../gitops/components/data-platform/ragflow/runtime/auth.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C307 gitops/components/data-platform/ragflow/runtime/kustomization.yaml

- 源文件：[gitops/components/data-platform/ragflow/runtime/kustomization.yaml](../gitops/components/data-platform/ragflow/runtime/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C308 gitops/components/data-platform/ragflow/runtime/workload.yaml

- 源文件：[gitops/components/data-platform/ragflow/runtime/workload.yaml](../gitops/components/data-platform/ragflow/runtime/workload.yaml)；343行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Service×1, Deployment×2, NetworkPolicy×2；命名空间：data-platform-dev；显式include/引用4处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C309 gitops/components/data-platform/ragflow/runtime/workload.yaml.j2

- 源文件：[gitops/components/data-platform/ragflow/runtime/workload.yaml.j2](../gitops/components/data-platform/ragflow/runtime/workload.yaml.j2)；123行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, cluster_name, data_namespace, lookup, playbook_dir, ragflow_api_resources, ragflow_input_digest, ragflow_node, ragflow_port, ragflow_runtime_image, ragflow_worker_resources, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C310 gitops/components/data-platform/ragflow/service_conf.yaml.j2

- 源文件：[gitops/components/data-platform/ragflow/service_conf.yaml.j2](../gitops/components/data-platform/ragflow/service_conf.yaml.j2)；33行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：data_namespace, initializing, object_storage_port, ragflow_bucket, ragflow_credentials, ragflow_database, ragflow_database_owner, ragflow_database_runtime, ragflow_port, ragflow_storage_user, valkey_credentials, valkey_runtime_username。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C311 gitops/components/data-platform/ragflow/storage/kustomization.yaml

- 源文件：[gitops/components/data-platform/ragflow/storage/kustomization.yaml](../gitops/components/data-platform/ragflow/storage/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C312 gitops/components/data-platform/ragflow/storage/provision.sops.yaml

- 源文件：[gitops/components/data-platform/ragflow/storage/provision.sops.yaml](../gitops/components/data-platform/ragflow/storage/provision.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C313 gitops/components/data-platform/ragflow/storage/workload.yaml

- 源文件：[gitops/components/data-platform/ragflow/storage/workload.yaml](../gitops/components/data-platform/ragflow/storage/workload.yaml)；68行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`data`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：ConfigMap×1, Job×1；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C314 gitops/components/data-platform/ragflow/storage/workload.yaml.j2

- 源文件：[gitops/components/data-platform/ragflow/storage/workload.yaml.j2](../gitops/components/data-platform/ragflow/storage/workload.yaml.j2)；1行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：lookup, playbook_dir。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C315 gitops/components/data-platform/ragflow/verify.py

- 源文件：[gitops/components/data-platform/ragflow/verify.py](../gitops/components/data-platform/ragflow/verify.py)；116行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：main。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/ragflow/README.md`。

### C316 gitops/components/data-platform/redis/auth.sops.yaml

- 源文件：[gitops/components/data-platform/redis/auth.sops.yaml](../gitops/components/data-platform/redis/auth.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/redis/README.md`。

### C317 gitops/components/data-platform/redis/config.yaml

- 源文件：[gitops/components/data-platform/redis/config.yaml](../gitops/components/data-platform/redis/config.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_redis_enabled`；键`redis_volume`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/redis/README.md`。

### C318 gitops/components/data-platform/redis/kustomization.yaml

- 源文件：[gitops/components/data-platform/redis/kustomization.yaml](../gitops/components/data-platform/redis/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/redis/README.md`。

### C319 gitops/components/data-platform/redis/workload.yaml

- 源文件：[gitops/components/data-platform/redis/workload.yaml](../gitops/components/data-platform/redis/workload.yaml)；108行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×2, StatefulSet×1；命名空间：data-platform-dev；显式include/引用3处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/redis/README.md`。

### C320 gitops/components/data-platform/redis/workload.yaml.j2

- 源文件：[gitops/components/data-platform/redis/workload.yaml.j2](../gitops/components/data-platform/redis/workload.yaml.j2)；114行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, component_namespaces, image, image_map, registry_address, services_redis_enabled, services_volumes, volume。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/redis/README.md`。

### C321 gitops/components/data-platform/text-embeddings/config.yaml

- 源文件：[gitops/components/data-platform/text-embeddings/config.yaml](../gitops/components/data-platform/text-embeddings/config.yaml)；20行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_text_embeddings_enabled`；键`text_embeddings_model`；键`text_embeddings_model_revision`；键`text_embeddings_dimensions`；键`text_embeddings_port`；键`text_embeddings_volume`；键`text_embeddings_resources`；键`text_embeddings_batch_tokens`；键`text_embeddings_client_batch_size`；键`text_embeddings_concurrent_requests`；键`text_embeddings_tokenization_workers`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/text-embeddings/README.md`。

### C322 gitops/components/data-platform/text-embeddings/kustomization.yaml

- 源文件：[gitops/components/data-platform/text-embeddings/kustomization.yaml](../gitops/components/data-platform/text-embeddings/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/text-embeddings/README.md`。

### C323 gitops/components/data-platform/text-embeddings/prepare.yaml

- 源文件：[gitops/components/data-platform/text-embeddings/prepare.yaml](../gitops/components/data-platform/text-embeddings/prepare.yaml)；113行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数15；入口任务“Select immutable model files from the single artifact lock”；末任务“Render CPU inference through the existing candidate chain”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/text-embeddings/README.md`。

### C324 gitops/components/data-platform/text-embeddings/verify.py

- 源文件：[gitops/components/data-platform/text-embeddings/verify.py](../gitops/components/data-platform/text-embeddings/verify.py)；104行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：require, main, request, cosine。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`gitops/components/data-platform/text-embeddings/README.md`。

### C325 gitops/components/data-platform/text-embeddings/workload.yaml

- 源文件：[gitops/components/data-platform/text-embeddings/workload.yaml](../gitops/components/data-platform/text-embeddings/workload.yaml)；109行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×1, Deployment×1, NetworkPolicy×2；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/text-embeddings/README.md`。

### C326 gitops/components/data-platform/text-embeddings/workload.yaml.j2

- 源文件：[gitops/components/data-platform/text-embeddings/workload.yaml.j2](../gitops/components/data-platform/text-embeddings/workload.yaml.j2)；109行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, image_map, registry_address, text_embeddings_batch_tokens, text_embeddings_client_batch_size, text_embeddings_concurrent_requests, text_embeddings_model, text_embeddings_model_digest, text_embeddings_model_revision, text_embeddings_port, text_embeddings_resources, text_embeddings_tokenization_workers, text_embeddings_volume。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/text-embeddings/README.md`。

### C327 gitops/components/data-platform/valkey/auth.sops.yaml

- 源文件：[gitops/components/data-platform/valkey/auth.sops.yaml](../gitops/components/data-platform/valkey/auth.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/data-platform/valkey/README.md`。

### C328 gitops/components/data-platform/valkey/config.yaml

- 源文件：[gitops/components/data-platform/valkey/config.yaml](../gitops/components/data-platform/valkey/config.yaml)；10行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_valkey_enabled`；键`valkey_volume`；键`valkey_runtime_username`；键`valkey_probe_username`；键`valkey_maxmemory`；键`valkey_resources`；显式include/引用1处。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/data-platform/valkey/README.md`。

### C329 gitops/components/data-platform/valkey/kustomization.yaml

- 源文件：[gitops/components/data-platform/valkey/kustomization.yaml](../gitops/components/data-platform/valkey/kustomization.yaml)；3行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/data-platform/valkey/README.md`。

### C330 gitops/components/data-platform/valkey/prepare.yaml

- 源文件：[gitops/components/data-platform/valkey/prepare.yaml](../gitops/components/data-platform/valkey/prepare.yaml)；65行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数7；入口任务“Validate separate Valkey identities and bounded profile”；末任务“Declare explicit Valkey root”；显式include/引用7处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/data-platform/valkey/README.md`。

### C331 gitops/components/data-platform/valkey/workload.yaml

- 源文件：[gitops/components/data-platform/valkey/workload.yaml](../gitops/components/data-platform/valkey/workload.yaml)；84行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×2, StatefulSet×1, NetworkPolicy×2；命名空间：data-platform-dev；显式include/引用2处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/data-platform/valkey/README.md`。

### C332 gitops/components/data-platform/valkey/workload.yaml.j2

- 源文件：[gitops/components/data-platform/valkey/workload.yaml.j2](../gitops/components/data-platform/valkey/workload.yaml.j2)；85行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, data_namespace, image_map, registry_address, valkey_input_digest, valkey_probe_username, valkey_resources, valkey_volume。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/data-platform/valkey/README.md`。

### C333 gitops/components/foundations/app-platform-dev-puller.sops.yaml

- 源文件：[gitops/components/foundations/app-platform-dev-puller.sops.yaml](../gitops/components/foundations/app-platform-dev-puller.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C334 gitops/components/foundations/data-platform-dev-puller.sops.yaml

- 源文件：[gitops/components/foundations/data-platform-dev-puller.sops.yaml](../gitops/components/foundations/data-platform-dev-puller.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：data-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C335 gitops/components/foundations/kustomization.yaml

- 源文件：[gitops/components/foundations/kustomization.yaml](../gitops/components/foundations/kustomization.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C336 gitops/components/foundations/messaging-platform-dev-puller.sops.yaml

- 源文件：[gitops/components/foundations/messaging-platform-dev-puller.sops.yaml](../gitops/components/foundations/messaging-platform-dev-puller.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：messaging-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C337 gitops/components/foundations/network.yaml

- 源文件：[gitops/components/foundations/network.yaml](../gitops/components/foundations/network.yaml)；162行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：NetworkPolicy×11；命名空间：app-platform-dev, data-platform-dev, messaging-platform-dev。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C338 gitops/components/foundations/network.yaml.j2

- 源文件：[gitops/components/foundations/network.yaml.j2](../gitops/components/foundations/network.yaml.j2)；48行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, component_namespaces, data_namespace, ingress_namespace, object_storage_port。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C339 gitops/components/foundations/runtime.yaml

- 源文件：[gitops/components/foundations/runtime.yaml](../gitops/components/foundations/runtime.yaml)；204行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`apiVersion`；键`kind`；键`metadata`；键`automountServiceAccountToken`；键`imagePullSecrets`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Namespace×3, ServiceAccount×6, LimitRange×3, NetworkPolicy×6；命名空间：app-platform-dev, data-platform-dev, messaging-platform-dev。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C340 gitops/components/foundations/runtime.yaml.j2

- 源文件：[gitops/components/foundations/runtime.yaml.j2](../gitops/components/foundations/runtime.yaml.j2)；70行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, data_namespace, messaging_namespace。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C341 gitops/components/foundations/storage.yaml

- 源文件：[gitops/components/foundations/storage.yaml](../gitops/components/foundations/storage.yaml)；527行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`provisioner`；键`reclaimPolicy`；键`volumeBindingMode`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：StorageClass×1, PersistentVolume×13, PersistentVolumeClaim×13；命名空间：app-platform-dev, data-platform-dev, messaging-platform-dev；显式include/引用13处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C342 gitops/components/foundations/storage.yaml.j2

- 源文件：[gitops/components/foundations/storage.yaml.j2](../gitops/components/foundations/storage.yaml.j2)；49行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, component_namespaces, lookup, services_volumes。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/foundations/README.md（拟新增）`。

### C343 gitops/components/ingress-platform/kustomization.yaml

- 源文件：[gitops/components/ingress-platform/kustomization.yaml](../gitops/components/ingress-platform/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/README.md`。

### C344 gitops/components/ingress-platform/traefik/config.yaml

- 源文件：[gitops/components/ingress-platform/traefik/config.yaml](../gitops/components/ingress-platform/traefik/config.yaml)；3行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_ingress_enabled`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/ingress-platform/traefik/README.md`。

### C345 gitops/components/ingress-platform/traefik/kustomization.yaml

- 源文件：[gitops/components/ingress-platform/traefik/kustomization.yaml](../gitops/components/ingress-platform/traefik/kustomization.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/ingress-platform/traefik/README.md`。

### C346 gitops/components/ingress-platform/traefik/puller.sops.yaml

- 源文件：[gitops/components/ingress-platform/traefik/puller.sops.yaml](../gitops/components/ingress-platform/traefik/puller.sops.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：ingress-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/ingress-platform/traefik/README.md`。

### C347 gitops/components/ingress-platform/traefik/service-access/config.yaml

- 源文件：[gitops/components/ingress-platform/traefik/service-access/config.yaml](../gitops/components/ingress-platform/traefik/service-access/config.yaml)；6行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`service_access_enabled`；键`service_access_hosts`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/ingress-platform/traefik/service-access/README.md`。

### C348 gitops/components/ingress-platform/traefik/service-access/kustomization.yaml

- 源文件：[gitops/components/ingress-platform/traefik/service-access/kustomization.yaml](../gitops/components/ingress-platform/traefik/service-access/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/ingress-platform/traefik/service-access/README.md`。

### C349 gitops/components/ingress-platform/traefik/service-access/prepare.yaml

- 源文件：[gitops/components/ingress-platform/traefik/service-access/prepare.yaml](../gitops/components/ingress-platform/traefik/service-access/prepare.yaml)；41行；.yaml；完整SHA256见基线清单。
- 职责：组件私有输入、候选声明或依赖初始化准备。
- 阅读记录：任务数6；入口任务“Require bounded internal TLS hostnames”；末任务“Render explicit service access resource list”；显式include/引用4处。
- 处置：**保留原文件及行为**。保留原生include链；说明目录/证书/身份/API写入等准备副作用，不称纯预览。
- 维护说明归属：`gitops/components/ingress-platform/traefik/service-access/README.md`。

### C350 gitops/components/ingress-platform/traefik/service-access/tls.sops.yaml

- 源文件：[gitops/components/ingress-platform/traefik/service-access/tls.sops.yaml](../gitops/components/ingress-platform/traefik/service-access/tls.sops.yaml)；24行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`type`；键`data`；键`sops`；对象：Secret×1；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/ingress-platform/traefik/service-access/README.md`。

### C351 gitops/components/ingress-platform/traefik/service-access/workload.yaml

- 源文件：[gitops/components/ingress-platform/traefik/service-access/workload.yaml](../gitops/components/ingress-platform/traefik/service-access/workload.yaml)；52行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×2, Ingress×2；命名空间：app-platform-dev。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/ingress-platform/traefik/service-access/README.md`。

### C352 gitops/components/ingress-platform/traefik/service-access/workload.yaml.j2

- 源文件：[gitops/components/ingress-platform/traefik/service-access/workload.yaml.j2](../gitops/components/ingress-platform/traefik/service-access/workload.yaml.j2)；28行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：app_namespace, ingress_namespace, service_access_hosts。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/ingress-platform/traefik/service-access/README.md`。

### C353 gitops/components/ingress-platform/traefik/workload.yaml

- 源文件：[gitops/components/ingress-platform/traefik/workload.yaml](../gitops/components/ingress-platform/traefik/workload.yaml)；64行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Namespace×1, OCIRepository×1, HelmRelease×1；命名空间：flux-system；显式include/引用1处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/ingress-platform/traefik/README.md`。

### C354 gitops/components/ingress-platform/traefik/workload.yaml.j2

- 源文件：[gitops/components/ingress-platform/traefik/workload.yaml.j2](../gitops/components/ingress-platform/traefik/workload.yaml.j2)；66行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：chart_source, image_map, ingress_namespace, registry_address, services_ingress_enabled。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/ingress-platform/traefik/README.md`。

### C355 gitops/components/messaging-platform/kustomization.yaml

- 源文件：[gitops/components/messaging-platform/kustomization.yaml](../gitops/components/messaging-platform/kustomization.yaml)；4行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/README.md`。

### C356 gitops/components/messaging-platform/rabbitmq/auth.sops.yaml

- 源文件：[gitops/components/messaging-platform/rabbitmq/auth.sops.yaml](../gitops/components/messaging-platform/rabbitmq/auth.sops.yaml)；25行；.yaml；完整SHA256见基线清单。
- 职责：受保护的加密输入/Secret声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`stringData`；键`sops`；对象：Secret×1；命名空间：messaging-platform-dev。
- 处置：**保留原文件及行为**。保留密文及加密身份；本轮不解密、不重新生成、不移动、不删。
- 维护说明归属：`gitops/components/messaging-platform/rabbitmq/README.md`。

### C357 gitops/components/messaging-platform/rabbitmq/config.yaml

- 源文件：[gitops/components/messaging-platform/rabbitmq/config.yaml](../gitops/components/messaging-platform/rabbitmq/config.yaml)；10行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_rabbitmq_enabled`；键`rabbitmq_volume`；键`rabbitmq_node_hostname`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`gitops/components/messaging-platform/rabbitmq/README.md`。

### C358 gitops/components/messaging-platform/rabbitmq/kustomization.yaml

- 源文件：[gitops/components/messaging-platform/rabbitmq/kustomization.yaml](../gitops/components/messaging-platform/rabbitmq/kustomization.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：Kustomize资源组合与引用入口。
- 阅读记录：键`apiVersion`；键`kind`；键`resources`；对象：Kustomization×1；显式include/引用1处。
- 处置：**保留原文件及行为**。保留依赖闭包；文档迁移不能改变resources/path/命名空间。
- 维护说明归属：`gitops/components/messaging-platform/rabbitmq/README.md`。

### C359 gitops/components/messaging-platform/rabbitmq/workload.yaml

- 源文件：[gitops/components/messaging-platform/rabbitmq/workload.yaml](../gitops/components/messaging-platform/rabbitmq/workload.yaml)；101行；.yaml；完整SHA256见基线清单。
- 职责：已生成并提交的Kubernetes资源声明。
- 阅读记录：键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；键`apiVersion`；键`kind`；键`metadata`；键`spec`；对象：Service×2, StatefulSet×1；命名空间：messaging-platform-dev；显式include/引用3处。
- 处置：**保留原文件及行为**。保留真实对象；在输入或模板修改后按现有render/stage生成；文档不能直接改PV/Job或删对象。
- 维护说明归属：`gitops/components/messaging-platform/rabbitmq/README.md`。

### C360 gitops/components/messaging-platform/rabbitmq/workload.yaml.j2

- 源文件：[gitops/components/messaging-platform/rabbitmq/workload.yaml.j2](../gitops/components/messaging-platform/rabbitmq/workload.yaml.j2)；107行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, component_namespaces, image, image_map, rabbitmq_node_hostname, registry_address, services_rabbitmq_enabled, services_volumes, volume。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`gitops/components/messaging-platform/rabbitmq/README.md`。

### C361 infrastructure/.gitignore

- 源文件：[infrastructure/.gitignore](../infrastructure/.gitignore)；5行；.gitignore；完整SHA256见基线清单。
- 职责：生成物/构建上下文隔离规则。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留隐藏配置；文档扫描不能遗漏规则或把被忽略运行产物当版本资产。
- 维护说明归属：`infrastructure/README.md`。

### C362 infrastructure/Makefile

- 源文件：[infrastructure/Makefile](../infrastructure/Makefile)；332行；Makefile；完整SHA256见基线清单。
- 职责：现有原生操作入口与配置文件闭包。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留入口；手册按真实target与APP/COMPONENT/SITE参数编写，不新增转接CLI。
- 维护说明归属：`infrastructure/README.md`。

### C363 infrastructure/applications/build-attempt.yaml

- 源文件：[infrastructure/applications/build-attempt.yaml](../infrastructure/applications/build-attempt.yaml)；91行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数10；入口任务“Reset diagnostics for this attempt”；末任务“Retain diagnostics separately for each attempted mode”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/applications/README.md`。

### C364 infrastructure/applications/build-network.yaml

- 源文件：[infrastructure/applications/build-network.yaml](../infrastructure/applications/build-network.yaml)；46行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数8；入口任务“Attempt the configured download mode”；末任务“Exit unsuccessfully without waiting for interactive input”；显式include/引用3处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/applications/README.md`。

### C365 infrastructure/applications/build.yaml

- 源文件：[infrastructure/applications/build.yaml](../infrastructure/applications/build.yaml)；240行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数34；入口任务“Require the reviewed source and build budget”；末任务“Remove only this invocation context and temporary authentication”；显式include/引用9处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/applications/README.md`。

### C366 infrastructure/applications/check-browser.py

- 源文件：[infrastructure/applications/check-browser.py](../infrastructure/applications/check-browser.py)；140行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：require, run, Connection, Browser, connect, __init__, request。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`infrastructure/applications/README.md`。

### C367 infrastructure/applications/config.yaml

- 源文件：[infrastructure/applications/config.yaml](../infrastructure/applications/config.yaml)；11行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`application_base_image_ids`；键`application_build_budget_bytes`；键`application_frontend_build_budget_bytes`；键`application_download_mode`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`infrastructure/applications/README.md`。

### C368 infrastructure/applications/deploy.yaml

- 源文件：[infrastructure/applications/deploy.yaml](../infrastructure/applications/deploy.yaml)；946行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数117；入口任务“Validate the selected deployment and identity boundaries”；末任务“Report only structured browser assertions”；显式include/引用61处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/applications/README.md`。

### C369 infrastructure/applications/download-modes.json

- 源文件：[infrastructure/applications/download-modes.json](../infrastructure/applications/download-modes.json)；14行；.json；完整SHA256见基线清单。
- 职责：国内直连/官方代理配套下载源。
- 阅读记录：键`domestic`；键`official-proxy`。
- 处置：**保留原文件及行为**。保留配套网络方案；说明自动切换只限下载类失败且仅一次，代理不可用非交互退出。
- 维护说明归属：`infrastructure/applications/README.md`。

### C370 infrastructure/applications/select-python-source.py

- 源文件：[infrastructure/applications/select-python-source.py](../infrastructure/applications/select-python-source.py)；106行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：sha, main, map_url, canonical。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`infrastructure/applications/README.md`。

### C371 infrastructure/applications/sources.yaml

- 源文件：[infrastructure/applications/sources.yaml](../infrastructure/applications/sources.yaml)；35行；.yaml；完整SHA256见基线清单。
- 职责：5仓/子模块固定提交与应用构建源选择。
- 阅读记录：键`applications`。
- 处置：**保留原文件及行为**。保留固定源；不使用任意dirty源码，文档说明本地提交与所有者推送职责。
- 维护说明归属：`infrastructure/applications/README.md`。

### C372 infrastructure/applications/tasks/runtime-tls.yaml

- 源文件：[infrastructure/applications/tasks/runtime-tls.yaml](../infrastructure/applications/tasks/runtime-tls.yaml)；8行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数1；入口任务“Prepare the existing application TLS identity through the shared recovery mechanism”；末任务“Prepare the existing application TLS identity through the shared recovery mechanism”；显式include/引用1处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/applications/README.md`。

### C373 infrastructure/applications/tests/rehearse-downloads.py

- 源文件：[infrastructure/applications/tests/rehearse-downloads.py](../infrastructure/applications/tests/rehearse-downloads.py)；145行；.py；完整SHA256见基线清单。
- 职责：持续构建选择/网络切换回归保护。
- 阅读记录：符号：run。
- 处置：**保留原文件及行为**。保留回归检查；本轮仅阅读，没有运行。rehearse是真实构建且会消耗空间，其清理仅处理自有fixture。
- 维护说明归属：`infrastructure/applications/README.md`。

### C374 infrastructure/applications/tests/test_build_selection.py

- 源文件：[infrastructure/applications/tests/test_build_selection.py](../infrastructure/applications/tests/test_build_selection.py)；34行；.py；完整SHA256见基线清单。
- 职责：持续构建选择/网络切换回归保护。
- 阅读记录：符号：BuildSelection, test_all_twelve_build_and_publication_arguments, test_invalid_app_or_component_rejected_before_execution。
- 处置：**保留原文件及行为**。保留回归检查；本轮仅阅读，没有运行。rehearse是真实构建且会消耗空间，其清理仅处理自有fixture。
- 维护说明归属：`infrastructure/applications/README.md`。

### C375 infrastructure/applications/tests/test_download_classification.py

- 源文件：[infrastructure/applications/tests/test_download_classification.py](../infrastructure/applications/tests/test_download_classification.py)；38行；.py；完整SHA256见基线清单。
- 职责：持续构建选择/网络切换回归保护。
- 阅读记录：符号：DownloadClassification, test_production_classifier。
- 处置：**保留原文件及行为**。保留回归检查；本轮仅阅读，没有运行。rehearse是真实构建且会消耗空间，其清理仅处理自有fixture。
- 维护说明归属：`infrastructure/applications/README.md`。

### C376 infrastructure/applications/tests/test_python_sources.py

- 源文件：[infrastructure/applications/tests/test_python_sources.py](../infrastructure/applications/tests/test_python_sources.py)；80行；.py；完整SHA256见基线清单。
- 职责：持续构建选择/网络切换回归保护。
- 阅读记录：符号：PythonSources, project, select, test_all_four_locks_roundtrip_without_dependency_changes, test_invalid_hash_rejected_before_any_write, test_unapproved_registry_rejected, test_symbolic_link_rejected, test_non_disposable_context_rejected。
- 处置：**保留原文件及行为**。保留回归检查；本轮仅阅读，没有运行。rehearse是真实构建且会消耗空间，其清理仅处理自有fixture。
- 维护说明归属：`infrastructure/applications/README.md`。

### C377 infrastructure/artifacts/bootstrap-archives.lock.json

- 源文件：[infrastructure/artifacts/bootstrap-archives.lock.json](../infrastructure/artifacts/bootstrap-archives.lock.json)；47行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`platform`；键`scope`；键`files`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C378 infrastructure/artifacts/files.lock.json

- 源文件：[infrastructure/artifacts/files.lock.json](../infrastructure/artifacts/files.lock.json)；482行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`platform`；键`resolved_at`；键`scope`；键`offline_ready`；键`files`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C379 infrastructure/artifacts/files.yaml

- 源文件：[infrastructure/artifacts/files.yaml](../infrastructure/artifacts/files.yaml)；176行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数16；入口任务“Validate operation and lock identity”；末任务“Require exact size and SHA256 after transfer”；显式include/引用3处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C380 infrastructure/artifacts/harbor-offline-images.lock.json

- 源文件：[infrastructure/artifacts/harbor-offline-images.lock.json](../infrastructure/artifacts/harbor-offline-images.lock.json)；143行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`installer_id`；键`installer_sha256`；键`platform`；键`inner_archive`；键`verified_blob_count`；键`images`；键`scope`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C381 infrastructure/artifacts/harbor-package-files.lock.json

- 源文件：[infrastructure/artifacts/harbor-package-files.lock.json](../infrastructure/artifacts/harbor-package-files.lock.json)；38行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`installer_id`；键`files`；键`installer_sha256`；键`image_archive_expanded_bytes`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C382 infrastructure/artifacts/host-archives.lock.json

- 源文件：[infrastructure/artifacts/host-archives.lock.json](../infrastructure/artifacts/host-archives.lock.json)；27行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`platform`；键`scope`；键`files`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C383 infrastructure/artifacts/image-archives.yaml

- 源文件：[infrastructure/artifacts/image-archives.yaml](../infrastructure/artifacts/image-archives.yaml)；109行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数10；入口任务“Validate image preparation mode and complete selection”；末任务“Require each loaded host tool identity”；显式include/引用5处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C384 infrastructure/artifacts/kind-build.lock.json

- 源文件：[infrastructure/artifacts/kind-build.lock.json](../infrastructure/artifacts/kind-build.lock.json)；36行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`platform`；键`kind_source_commit`；键`kind_file_id`；键`server_file_id`；键`base_image_id`；键`output_image`；键`build_type`；键`server_expanded_bytes`；键`peak_estimate_bytes`；键`estimate_note`；键`kubeadm_image_ids`；键`node_image_ids`；键`network_required_during_build`；键`source`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C385 infrastructure/artifacts/node-image.lock.json

- 源文件：[infrastructure/artifacts/node-image.lock.json](../infrastructure/artifacts/node-image.lock.json)；28行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`platform`；键`build_inputs`；键`images`；键`versions`；键`server_sha256`；键`kind_sha256`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C386 infrastructure/artifacts/publish.yaml

- 源文件：[infrastructure/artifacts/publish.yaml](../infrastructure/artifacts/publish.yaml)；75行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数8；入口任务“Require the selected locked images and supported action”；末任务“Process each selected image through the same path”；显式include/引用4处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C387 infrastructure/artifacts/tasks/image-archive.yaml

- 源文件：[infrastructure/artifacts/tasks/image-archive.yaml](../infrastructure/artifacts/tasks/image-archive.yaml)；188行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数27；入口任务“Set deterministic archive paths”；末任务“Report verified archive”；显式include/引用2处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C388 infrastructure/artifacts/tasks/publish-image.yaml

- 源文件：[infrastructure/artifacts/tasks/publish-image.yaml](../infrastructure/artifacts/tasks/publish-image.yaml)；130行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数20；入口任务“Set archive and target names from the immutable lock”；末任务“Remove only a confirmed application upload transport”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C389 infrastructure/artifacts/tasks/resumable-file.yaml

- 源文件：[infrastructure/artifacts/tasks/resumable-file.yaml](../infrastructure/artifacts/tasks/resumable-file.yaml)；70行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数7；入口任务“Inspect this locked file partial download”；末任务“Publish verified material without replacing an existing file”。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C390 infrastructure/artifacts/upstream-images.lock.json

- 源文件：[infrastructure/artifacts/upstream-images.lock.json](../infrastructure/artifacts/upstream-images.lock.json)；662行；.json；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：键`schema_version`；键`platform`；键`resolved_at`；键`source_method`；键`complete`；键`scope`；键`images`；键`offline_ready`。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C391 infrastructure/artifacts/verify-oci-archive.py

- 源文件：[infrastructure/artifacts/verify-oci-archive.py](../infrastructure/artifacts/verify-oci-archive.py)；128行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：verify, visit。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`infrastructure/artifacts/README.md`。

### C392 infrastructure/cluster/build-node.yaml

- 源文件：[infrastructure/cluster/build-node.yaml](../infrastructure/cluster/build-node.yaml)；247行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数27；入口任务“Validate selected build inputs”；末任务“Report actual node binaries”；显式include/引用5处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/cluster/README.md`。

### C393 infrastructure/cluster/calico-kustomization.yaml.j2

- 源文件：[infrastructure/cluster/calico-kustomization.yaml.j2](../infrastructure/cluster/calico-kustomization.yaml.j2)；47行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：calico_archives, cluster_pod_subnet。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/cluster/README.md`。

### C394 infrastructure/cluster/config.yaml

- 源文件：[infrastructure/cluster/config.yaml](../infrastructure/cluster/config.yaml)；20行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`cluster_enabled`；键`cluster_api_port`；键`cluster_ingress_port`；键`cluster_pod_subnet`；键`cluster_service_subnet`；键`cluster_data_root`；键`cluster_kubeconfig`；键`cluster_operator`；键`cluster_create_budget_bytes`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`infrastructure/cluster/README.md`。

### C395 infrastructure/cluster/deploy.yaml

- 源文件：[infrastructure/cluster/deploy.yaml](../infrastructure/cluster/deploy.yaml)；401行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数50；入口任务“Validate scope before writes”；末任务“Recheck the physical reserve after cluster operations”；显式include/引用16处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/cluster/README.md`。

### C396 infrastructure/cluster/kind.yaml.j2

- 源文件：[infrastructure/cluster/kind.yaml.j2](../infrastructure/cluster/kind.yaml.j2)；31行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：build_lock, cluster_api_port, cluster_ingress_port, cluster_name, cluster_pod_subnet, cluster_root, cluster_service_subnet, runtime。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/cluster/README.md`。

### C397 infrastructure/cluster/node.yaml

- 源文件：[infrastructure/cluster/node.yaml](../infrastructure/cluster/node.yaml)；110行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数13；入口任务“Read KIND network host gateway”；末任务“Require the same filesystems and inodes inside the node”。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/cluster/README.md`。

### C398 infrastructure/cluster/pull-check.yaml

- 源文件：[infrastructure/cluster/pull-check.yaml](../infrastructure/cluster/pull-check.yaml)；190行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数20；入口任务“Load independently recorded cluster identity”；末任务“Verify remaining reserve after pull acceptance”；显式include/引用7处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/cluster/README.md`。

### C399 infrastructure/entry/config.yaml

- 源文件：[infrastructure/entry/config.yaml](../infrastructure/entry/config.yaml)；38行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`entry_enabled`；键`entry_listen_address`；键`entry_port`；键`entry_cluster_backend`；键`entry_config_dir`；键`entry_runtime_dir`；键`entry_cluster_routes`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`infrastructure/entry/README.md`。

### C400 infrastructure/entry/service.yaml

- 源文件：[infrastructure/entry/service.yaml](../infrastructure/entry/service.yaml)；250行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数27；入口任务“Validate entry configuration”；末任务“Require the requested lifecycle outcome”；显式include/引用15处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/entry/README.md`。

### C401 infrastructure/entry/templates/entry-compose.yaml.j2

- 源文件：[infrastructure/entry/templates/entry-compose.yaml.j2](../infrastructure/entry/templates/entry-compose.yaml.j2)；24行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：entry_config_dir, entry_image。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/entry/README.md`。

### C402 infrastructure/entry/templates/haproxy.cfg.j2

- 源文件：[infrastructure/entry/templates/haproxy.cfg.j2](../infrastructure/entry/templates/haproxy.cfg.j2)；31行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：entry_cluster_backend, entry_cluster_routes, entry_listen_address, entry_port, registry_hostname, registry_https_port。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/entry/README.md`。

### C403 infrastructure/entry/templates/sunmoon-entry.service.j2

- 源文件：[infrastructure/entry/templates/sunmoon-entry.service.j2](../infrastructure/entry/templates/sunmoon-entry.service.j2)；26行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：entry_runtime_dir。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/entry/README.md`。

### C404 infrastructure/environments/kind/flux-source.yaml

- 源文件：[infrastructure/environments/kind/flux-source.yaml](../infrastructure/environments/kind/flux-source.yaml)；5行；.yaml；完整SHA256见基线清单。
- 职责：经明确晋级的Git revision与OCI digest来源。
- 阅读记录：键`digest`；键`path`；键`repository`；键`requires_sops`；键`revision`。
- 处置：**保留原文件及行为**。保留单一晋级来源；文档不再复制当前digest，publish候选不等同apply。
- 维护说明归属：`infrastructure/environments/kind/README.md`。

### C405 infrastructure/environments/kind/site.yaml

- 源文件：[infrastructure/environments/kind/site.yaml](../infrastructure/environments/kind/site.yaml)；9行；.yaml；完整SHA256见基线清单。
- 职责：环境共享身份、路径与命名空间权威来源。
- 阅读记录：键`cluster_name`；键`registry_address`；键`artifact_cache_root`；键`data_namespace`；键`messaging_namespace`；键`app_namespace`；键`ingress_namespace`。
- 处置：**保留原文件及行为**。保留共享来源；文档说明参数读取顺序，既有环境身份变更不能绕过receipt/卷守卫。
- 维护说明归属：`infrastructure/environments/kind/README.md`。

### C406 infrastructure/environments/kind/sops-recipient.txt

- 源文件：[infrastructure/environments/kind/sops-recipient.txt](../infrastructure/environments/kind/sops-recipient.txt)；1行；.txt；完整SHA256见基线清单。
- 职责：公共SOPS加密身份。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留；不等同age私钥，轮换需要独立方案。
- 维护说明归属：`infrastructure/environments/kind/README.md`。

### C407 infrastructure/flux/bootstrap.yaml

- 源文件：[infrastructure/flux/bootstrap.yaml](../infrastructure/flux/bootstrap.yaml)；187行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数27；入口任务“Validate explicit new-cluster ownership boundary”；末任务“Report actual Flux health”；显式include/引用11处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/flux/README.md`。

### C408 infrastructure/flux/config.yaml

- 源文件：[infrastructure/flux/config.yaml](../infrastructure/flux/config.yaml)；10行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`flux_enabled`；键`sops_enabled`；键`sops_config_dir`；键`sops_backup_dir`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`infrastructure/flux/README.md`。

### C409 infrastructure/flux/foundations-check.yaml

- 源文件：[infrastructure/flux/foundations-check.yaml](../infrastructure/flux/foundations-check.yaml)；168行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数16；入口任务“Require the exact enabled new environment”；末任务“Remove exactly the temporary Job and its owned pods”；显式include/引用5处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/flux/README.md`。

### C410 infrastructure/flux/materials.yaml

- 源文件：[infrastructure/flux/materials.yaml](../infrastructure/flux/materials.yaml)；67行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数8；入口任务“Require the four locked controllers and supported action”；末任务“Process each controller through the same path”；显式include/引用3处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/flux/README.md`。

### C411 infrastructure/flux/secrets.yaml

- 源文件：[infrastructure/flux/secrets.yaml](../infrastructure/flux/secrets.yaml)；298行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数38；入口任务“Validate the declared scope”；末任务“Compare cluster identity and public annotation without exposing the key”；显式include/引用12处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/flux/README.md`。

### C412 infrastructure/flux/source.yaml

- 源文件：[infrastructure/flux/source.yaml](../infrastructure/flux/source.yaml)；285行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数39；入口任务“Validate source action and target”；末任务“Verify the actual declared platform release marker”；显式include/引用14处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/flux/README.md`。

### C413 infrastructure/flux/tasks/apply.yaml

- 源文件：[infrastructure/flux/tasks/apply.yaml](../infrastructure/flux/tasks/apply.yaml)；16行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数2；入口任务“Compare owned declaration with the live API”；末任务“Apply only a changed declaration without forcing field ownership”。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/flux/README.md`。

### C414 infrastructure/flux/templates/kustomization.yaml.j2

- 源文件：[infrastructure/flux/templates/kustomization.yaml.j2](../infrastructure/flux/templates/kustomization.yaml.j2)；36行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, controllers, registry_address。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/flux/README.md`。

### C415 infrastructure/flux/templates/source.yaml.j2

- 源文件：[infrastructure/flux/templates/source.yaml.j2](../infrastructure/flux/templates/source.yaml.j2)；46行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：cluster_name, sops_enabled, source_lock。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/flux/README.md`。

### C416 infrastructure/flux/tools.yaml

- 源文件：[infrastructure/flux/tools.yaml](../infrastructure/flux/tools.yaml)；99行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数14；入口任务“Validate fixed package descriptor”；末任务“Verify client version without accessing any cluster”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/flux/README.md`。

### C417 infrastructure/host/config.yaml

- 源文件：[infrastructure/host/config.yaml](../infrastructure/host/config.yaml)；22行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`storage_uuid`；键`storage_mounts`；键`windows_powershell`；键`data_vhd_windows_path`；键`data_vhd_maximum_gib`；键`windows_minimum_free_gib`；键`windows_script_directory`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`infrastructure/host/README.md`。

### C418 infrastructure/host/inventory.yaml

- 源文件：[infrastructure/host/inventory.yaml](../infrastructure/host/inventory.yaml)；8行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：键`all`。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/host/README.md`。

### C419 infrastructure/host/preflight.yaml

- 源文件：[infrastructure/host/preflight.yaml](../infrastructure/host/preflight.yaml)；63行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数5；入口任务“Check tool version and required site settings”；末任务“Report the scope of this preflight”。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/host/README.md`。

### C420 infrastructure/host/tasks/capacity.yaml

- 源文件：[infrastructure/host/tasks/capacity.yaml](../infrastructure/host/tasks/capacity.yaml)；76行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数9；入口任务“Validate the capacity budget and site floor”；末任务“Enforce the approved batch ceiling as well as the reserve floor”；显式include/引用3处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/host/README.md`。

### C421 infrastructure/host/windows-capacity.ps1

- 源文件：[infrastructure/host/windows-capacity.ps1](../infrastructure/host/windows-capacity.ps1)；49行；.ps1；完整SHA256见基线清单。
- 职责：Windows容量只读采集程序。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留Windows/WSL侧分工；维护说明明确权限、实际占用和增长计算。
- 维护说明归属：`infrastructure/host/README.md`。

### C422 infrastructure/registry/accounts.yaml

- 源文件：[infrastructure/registry/accounts.yaml](../infrastructure/registry/accounts.yaml)；114行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数13；入口任务“Require explicit registry enablement”；末任务“Report account scope without credentials”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C423 infrastructure/registry/check-storage.py

- 源文件：[infrastructure/registry/check-storage.py](../infrastructure/registry/check-storage.py)；47行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：output, main。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`infrastructure/registry/README.md`。

### C424 infrastructure/registry/config.yaml

- 源文件：[infrastructure/registry/config.yaml](../infrastructure/registry/config.yaml)；20行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`registry_enabled`；键`registry_hostname`；键`registry_project`；键`registry_https_port`；键`registry_config_dir`；键`registry_runtime_dir`；键`registry_data_root`；键`registry_instance_dir`；键`registry_log_rotation_approved`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`infrastructure/registry/README.md`。

### C425 infrastructure/registry/materials.yaml

- 源文件：[infrastructure/registry/materials.yaml](../infrastructure/registry/materials.yaml)；209行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数24；入口任务“Require verified input lock agreement”；末任务“Report material readiness without claiming service installation”；显式include/引用7处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C426 infrastructure/registry/prepare-recovery.py

- 源文件：[infrastructure/registry/prepare-recovery.py](../infrastructure/registry/prepare-recovery.py)；143行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：require, digest, private_json, main。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`infrastructure/registry/README.md`。

### C427 infrastructure/registry/publish.yaml

- 源文件：[infrastructure/registry/publish.yaml](../infrastructure/registry/publish.yaml)；173行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数23；入口任务“Inspect Docker version before any endpoint or image changes”；末任务“Remove only this invocation verification download”；显式include/引用5处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C428 infrastructure/registry/recovery.yaml

- 源文件：[infrastructure/registry/recovery.yaml](../infrastructure/registry/recovery.yaml)；260行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数29；入口任务“Require explicit backup identity and isolated operation”；末任务“Report isolated acceptance and retained evidence”；显式include/引用4处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C429 infrastructure/registry/release.yaml

- 源文件：[infrastructure/registry/release.yaml](../infrastructure/registry/release.yaml)；23行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：键`certificate_days`；键`ca_days`；键`services`；键`readiness_dependencies`。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C430 infrastructure/registry/scan.yaml

- 源文件：[infrastructure/registry/scan.yaml](../infrastructure/registry/scan.yaml)；158行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数15；入口任务“Require reasonably recent vulnerability intelligence for acceptance”；末任务“Report verification scope without claiming vulnerability absence”；显式include/引用5处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C431 infrastructure/registry/scanner-databases.yaml

- 源文件：[infrastructure/registry/scanner-databases.yaml](../infrastructure/registry/scanner-databases.yaml)；66行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数7；入口任务“Validate scanner operation and release inputs”；末任务“Process each immutable database independently”；显式include/引用4处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C432 infrastructure/registry/service.yaml

- 源文件：[infrastructure/registry/service.yaml](../infrastructure/registry/service.yaml)；377行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数38；入口任务“Validate site and operation”；末任务“Display only non-secret state”；显式include/引用20处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C433 infrastructure/registry/tasks/robot.yaml

- 源文件：[infrastructure/registry/tasks/robot.yaml](../infrastructure/registry/tasks/robot.yaml)；158行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数19；入口任务“Set the single robot identity and expected permissions”；末任务“Require the authenticated identity and exact granted actions”；显式include/引用1处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C434 infrastructure/registry/tasks/scanner-database.yaml

- 源文件：[infrastructure/registry/tasks/scanner-database.yaml](../infrastructure/registry/tasks/scanner-database.yaml)；146行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数17；入口任务“Validate locked archive layout”；末任务“Require exact database bytes and scanner ownership”；显式include/引用2处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C435 infrastructure/registry/tasks/secrets.yaml

- 源文件：[infrastructure/registry/tasks/secrets.yaml](../infrastructure/registry/tasks/secrets.yaml)；161行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数16；入口任务“Inspect credential files without reading their values”；末任务“Require certificate private keys to match”；显式include/引用1处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/registry/README.md`。

### C436 infrastructure/registry/templates/compose.override.yaml.j2

- 源文件：[infrastructure/registry/templates/compose.override.yaml.j2](../infrastructure/registry/templates/compose.override.yaml.j2)；28行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：harbor_images, registry_https_port, registry_release。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/registry/README.md`。

### C437 infrastructure/registry/templates/sunmoon-registry.service.j2

- 源文件：[infrastructure/registry/templates/sunmoon-registry.service.j2](../infrastructure/registry/templates/sunmoon-registry.service.j2)；28行；.j2；完整SHA256见基线清单。
- 职责：配置生成模板。
- 阅读记录：模板输入：registry_data_root, registry_project, registry_release, registry_runtime_dir。
- 处置：**保留原文件及行为**。保留生成源；说明config→模板→声明关系；不因同时有生成YAML而当重复删除。
- 维护说明归属：`infrastructure/registry/README.md`。

### C438 infrastructure/services/chart.yaml

- 源文件：[infrastructure/services/chart.yaml](../infrastructure/services/chart.yaml)；98行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数13；入口任务“Verify local chart and Helm identities”；末任务“Remove this invocation chart staging”；显式include/引用2处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C439 infrastructure/services/config.yaml

- 源文件：[infrastructure/services/config.yaml](../infrastructure/services/config.yaml)；15行；.yaml；完整SHA256见基线清单。
- 职责：用户就近维护的参数来源。
- 阅读记录：键`services_enabled`；键`services_config_dir`；键`services_backup_dir`；键`service_image_ids`；键`service_material_timeout_seconds`。
- 处置：**保留原文件及行为**。保留参数与读取链；README逐字段说明类型、改动影响、已有环境限制；不复制secret值。
- 维护说明归属：`infrastructure/services/README.md`。

### C440 infrastructure/services/credentials.yaml

- 源文件：[infrastructure/services/credentials.yaml](../infrastructure/services/credentials.yaml)；92行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数12；入口任务“Validate private input boundaries”；末任务“Require byte-identical recoverable input”；显式include/引用14处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C441 infrastructure/services/layout.yaml

- 源文件：[infrastructure/services/layout.yaml](../infrastructure/services/layout.yaml)；53行；.yaml；完整SHA256见基线清单。
- 职责：组件路径、命名空间、卷与阶段依赖映射。
- 阅读记录：键`service_stage_paths`；键`service_candidate_roots`；键`component_namespaces`；键`services_volumes`；键`service_component_paths`。
- 处置：**保留原文件及行为**。保留组合映射；文档说明代码目录归属与对象命名空间不同，禁止机械改Casdoor数据库目录分类。
- 维护说明归属：`infrastructure/services/README.md`。

### C442 infrastructure/services/render.yaml

- 源文件：[infrastructure/services/render.yaml](../infrastructure/services/render.yaml)；435行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数54；入口任务“Require owned first-batch configuration”；末任务“Stage native service dependency declarations”；显式include/引用57处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C443 infrastructure/services/tasks/check-declaration.yaml

- 源文件：[infrastructure/services/tasks/check-declaration.yaml](../infrastructure/services/tasks/check-declaration.yaml)；33行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数4；入口任务“Read the committed and generated declaration structures”；末任务“Require matching encrypted semantic content before deployment”；显式include/引用2处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C444 infrastructure/services/tasks/component-input.yaml

- 源文件：[infrastructure/services/tasks/component-input.yaml](../infrastructure/services/tasks/component-input.yaml)；50行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数9；入口任务“Inspect the exact independent component input pair”；末任务“Decode component identity without exposing values”；显式include/引用3处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C445 infrastructure/services/tasks/component-tls.yaml

- 源文件：[infrastructure/services/tasks/component-tls.yaml](../infrastructure/services/tasks/component-tls.yaml)；96行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数19；入口任务“Validate exact service TLS names”；末任务“Collect internal TLS material in memory”；显式include/引用4处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C446 infrastructure/services/tasks/encrypt.yaml

- 源文件：[infrastructure/services/tasks/encrypt.yaml](../infrastructure/services/tasks/encrypt.yaml)；49行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数6；入口任务“Read prior ciphertext through the independent backup identity”；末任务“Verify candidate using independent recovery identity”。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C447 infrastructure/services/tasks/tls-identity.yaml

- 源文件：[infrastructure/services/tasks/tls-identity.yaml](../infrastructure/services/tasks/tls-identity.yaml)；128行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数22；入口任务“Inspect certificate responsibility directories without following links”；末任务“Read application TLS only in memory for SOPS encryption”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C448 infrastructure/services/tools.yaml

- 源文件：[infrastructure/services/tools.yaml](../infrastructure/services/tools.yaml)；99行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数14；入口任务“Validate fixed package descriptor”；末任务“Verify client version without accessing any cluster”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C449 infrastructure/services/validate-release.yaml

- 源文件：[infrastructure/services/validate-release.yaml](../infrastructure/services/validate-release.yaml)；47行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数6；入口任务“Require a clean declaration worktree”；末任务“Require enabled stages to match the release”；显式include/引用3处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C450 infrastructure/services/verify-live.py

- 源文件：[infrastructure/services/verify-live.py](../infrastructure/services/verify-live.py)；170行；.py；完整SHA256见基线清单。
- 职责：组件协议、初始化、受限验收或校验程序。
- 阅读记录：符号：AcceptanceError, require, verify_namespace_boundary, main, kubectl, request。
- 处置：**保留原文件及行为**。保留真正工具/初始化/验收实现；说明输入、权限和临时写入/清理范围。
- 维护说明归属：`infrastructure/services/README.md`。

### C451 infrastructure/services/verify.yaml

- 源文件：[infrastructure/services/verify.yaml](../infrastructure/services/verify.yaml)；295行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数44；入口任务“Verify ownership before workload operations”；末任务“Record the source, ownership, checks and physical capacity”；显式include/引用10处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/services/README.md`。

### C452 infrastructure/tools/install-age.yaml

- 源文件：[infrastructure/tools/install-age.yaml](../infrastructure/tools/install-age.yaml)；83行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数10；入口任务“Verify the original age package”；末任务“Install worktree-local tools”；显式include/引用6处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/tools/README.md`。

### C453 infrastructure/tools/install-binaries.yaml

- 源文件：[infrastructure/tools/install-binaries.yaml](../infrastructure/tools/install-binaries.yaml)；132行；.yaml；完整SHA256见基线清单。
- 职责：原生Ansible编排、任务或配置链。
- 阅读记录：任务数13；入口任务“Validate selected tools”；末任务“Require installed bytes to match the file lock”；显式include/引用4处。
- 处置：**保留原文件及行为**。保留部署行为；文档按真实plan/render/stage/apply/check副作用描述。
- 维护说明归属：`infrastructure/tools/README.md`。

### C454 infrastructure/tools/requirements.in

- 源文件：[infrastructure/tools/requirements.in](../infrastructure/tools/requirements.in)；1行；.in；完整SHA256见基线清单。
- 职责：基础设施Python依赖入口。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留与哈希lock关系；应用runtime与宿主工具分开说明。
- 维护说明归属：`infrastructure/tools/README.md`。

### C455 infrastructure/tools/requirements.lock

- 源文件：[infrastructure/tools/requirements.lock](../infrastructure/tools/requirements.lock)；349行；.lock；完整SHA256见基线清单。
- 职责：固定文件/镜像/构建/依赖身份的权威锁。
- 阅读记录：完整读取、摘要记录；职责由源码及所属模块确认。
- 处置：**保留原文件及行为**。保留全部身份；文档链接权威锁；不再并行维护手写版本/摘要表。
- 维护说明归属：`infrastructure/tools/README.md`。

## 四、审批后的覆盖核对

1. 67份文档按D编号逐项核对内容去向；52份保留重写，15份归并后删除。
2. 455份非Markdown按C编号核对完整SHA256保持一致；任何代码变更另列。
3. 8份新文档只承担表中责任，目标长期Markdown总数60。
4. 删除15份过程卡前查本轮三目录内所有相对链接和文本引用；未迁入的独有内容阻止删除。
5. 实施开始前复核基线；如其他开发提交已变化，仅重新审阅受影响项，不覆盖更新。
6. 测试、部署、维护切换和运行数据清理不是本轮静态文档方案的验收替代品。
