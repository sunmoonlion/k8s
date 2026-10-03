# 项目入口指针

本仓是 SunMoonAI 平台五个协作仓之一（`tpl-app` / `info-app` / `knowledge-app` /
`investment-app` / `k8s`，**必须并列放置**）。

**先读这一份**——我们在建什么、做到哪了：

`sunmoonai/docs/dev-investment-agent/pipeline.md`

一次 turn 的九站，以及**每一站现在谁做**（人还是脚本）。这个项目在做的事，
就是把那张表里的格子一个一个从「人」改成「脚本」；你接的活是其中哪一格，
从那张表上认。

**动代码前必读**——代码必须符合的规则（按主题分组）：

`sunmoonai/docs/dev-investment-agent/tree-build/rules/constraints.md`

违反其中任一条的方案不进入讨论。用法见该文件「怎么用」。

要先了解项目长什么样，读项目总览：

`sunmoonai/docs/project-guide/overall-architecture.md`

要建什么（需求的真源）：

`sunmoonai/docs/dev-investment-agent/tree-build/PRD/requirement.md`

任何开发任务都要遵守的通用开发规范：

`sunmoonai/docs/dev-investment-agent/turn/README.md`

开发 Agent 接任务前必须读取通用开发规范里自己那一类的规则：

`sunmoonai/docs/dev-investment-agent/turn/`（PRD、SDD、IMP、UAT 各一份）

涉及人的批准、裁量或终审时，同时读取（人介入、权力表、审批档位）：

`sunmoonai/docs/dev-investment-agent/turn/approvals.md`

不在此复述其中规则。

## 新部署代码的长期配置原则

所有者确定：新增或调整新部署模块时，用户配置、底层实现及说明放在同一职责目录；适用于宿主、集群、仓库、入口、Flux、应用和平台组件，不只限于 `gitops/components`。共享环境字段与版本锁保持单一来源，秘密留在私有目录或 SOPS 密文中。实施入口沿用原生 Make/Ansible/Flux，不新增重复 CLI 或兼容转接层。详见 `docs/platform-kind-v1/architecture.md` 的配置归属约定。

应用日常构建采用国内在线源优先；确认依赖下载网络失败后本次自动切官方源，探测HTTPS_PROXY可用才重试一次；代理不可用或重试失败给出明确提示并非零退出，不等待交互。非网络/证书/签名/哈希错误不自动切换。应用镜像发布到Harbor后按摘要部署，离线应用包不是部署前提。用户只在infrastructure/applications/config.yaml选择domestic或official-proxy，源与代理配套切换，Harbor始终直连；端点唯一在同目录download-modes.json维护；代理例外不改日常默认，证书、签名和依赖哈希校验不得关闭。

部署声明保留“平台 → 应用 → 组件”的分类：`gitops/components/app-platform/auth-app/casdoor/`、`gitops/components/app-platform/tpl-app/tpl-backend/`、`tpl-web-frontend/`、`tpl-admin-frontend/`。应用之下必须保留前后端组件层，database/migration/API/Worker/Scheduler归后端组件。后续实例沿用 `info-app/`、`knowledge-app/`、`investment-app/`；应用自己的配置、数据库初始化、迁移与运行声明同处，不新增平行的 GitOps 应用分类。目录归属不等于运行命名空间。

所有应用（Casdoor、tpl/info/knowledge/investment）统一使用环境 `app_namespace`，当前为 `app-platform-dev`；应用目录层级不派生新命名空间。平台基础对象由foundations唯一管理，应用引用共享网络策略与拉取凭据，避免重复声明同一资源。

## 当前开发阶段的维护窗口

2026-10-03所有者明确：项目尚未对外提供服务，后续维护窗口统一为2小时。对已明确批准范围的维护连续实施，不因旧文档的5/10/20分钟窗口反复请求延时；历史记录中的实际时间不改写。容量底线、数据保护、操作范围和故障回退要求仍有效；失败及时处理，不把2小时当作命令等待时长。进入实际服务阶段后重新确认停服约束。

同日所有者将当前开发阶段容量底线统一改为10 GiB，取代此前50 GiB及逐批40 GiB例外。真源为infrastructure/host/config.yaml；仍按C盘实测空闲扣除230 GiB数据盘未来增长和本次预算计算，不关闭容量检查，不因此授权删除数据。明确范围内无需反复请求容量例外。

应用共用部署机制的唯一来源为gitops/components/app-platform/common，应用配置/镜像锁/渲染声明/说明仍在各应用组件目录。所有APP直接复用原生deploy.yaml，不复制脚本、不通过tpl组件转接；变更须验证既有应用渲染对象不变，避免修改已完成的不可变Job。集群分别引用applications-<APP>.yaml，选中APP的stage不能覆盖其它应用依赖链。
