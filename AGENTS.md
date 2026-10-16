# 项目入口指针

本仓是 SunMoonAI 平台的部署与项目文档仓，与 `tpl-app`、`knowfeed-app`、`knowbase-app`、`investment-app` **并列放置**（`runtime` 是客户端仓，不要求并列）。

**先读这一份**——项目现在是什么样（产品定位、仓、拓扑、部署、红线、去哪查）：

`docs/project-guide/overall-architecture.md`

我们在建什么、做到哪了、每一站谁做：

`docs/dev-investment-agent/pipeline.md`

**动代码前必读**——代码必须符合的规则（按主题分组，含合规 `C-L*`）：

`docs/dev-investment-agent/tree-build/rules/constraints.md`

要建什么（需求的真源）：

`docs/dev-investment-agent/tree-build/PRD/requirement.md`

任何开发任务都要遵守的通用开发规范，以及自己那一类（PRD、SDD、IMP、UAT）的规则：

`docs/dev-investment-agent/turn/README.md`

涉及人的批准、裁量或终审时（人介入、权力表、审批档位）：

`docs/dev-investment-agent/turn/approvals.md`

部署、运维、某个组件怎么维护：

`README.md`（仓根）与 `docs/README.md`（维护导航）

不在此复述其中规则。

## 必须知道的几条（规矩原文在指向的位置）

| 规矩 | 原文 |
| --- | --- |
| **分身线的合规边界**：投资逻辑与数据只来自用户，我们只做工程化与测试，分身只归用户自己（所有者 2026-10-16 定） | `constraints.md`「合规」、`tree-build/SDD/modules/0026-knowlab.md` |
| 配置、实现与说明同职责目录放；版本与共享环境单一来源；秘密只在私有目录与 SOPS；实施入口只用原生 Make / Ansible / Flux，不加重复 CLI 或转接层 | `constraints.md`「发布」`C-R13`、`C-R14` |
| 部署声明保留平台 → 应用 → 组件三层；应用统一 `app_namespace`；应用共用机制只在 `app-platform/common`，改了要证明既有应用渲染对象不变、不碰已完成的不可变 Job | `constraints.md`「发布」`C-R11`、`C-R15`、`gitops/components/README.md`、`gitops/components/app-platform/common/README.md` |
| 应用构建国内源优先，失败按规则切一次官方源 + 代理；只在 `infrastructure/applications/config.yaml` 选 `domestic` 或 `official-proxy`；证书、签名、哈希校验不得关闭 | `infrastructure/applications/README.md` |
| 开发阶段维护窗口 2 小时、容量底线 10 GiB（真源 `infrastructure/host/config.yaml`），不关容量检查、不因此授权删数据 | `docs/README.md`、`infrastructure/host/README.md` |
| 正式文档以维护者日常操作为中心，入口只导航，不写未验证的功能，不放明文秘密 | `docs/README.md`「正式文档怎么写」 |

## 开发密码查阅表（所有者确认，2026-10-05）

仓根 `密码修改表.md` 由所有者保留，开发阶段允许保存实际登录密码供本人查阅。它不是部署真源，不得改成纯索引或删除密码；组件私有输入与 SOPS 机制照旧。实际账号轮换且登录验证通过后才同步本表；旧体系条目和待轮换目标须明确标注，不能冒充当前凭据。**不得在对话、日志或 diff 输出中显示密码，不得读出来代填**，不自动 push；生产上线前轮换开发凭据。其它文件继续遵守不保存明文秘密的规则。
