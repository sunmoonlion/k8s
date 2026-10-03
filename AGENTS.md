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
