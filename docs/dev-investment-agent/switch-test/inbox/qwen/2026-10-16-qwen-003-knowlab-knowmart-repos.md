# knowlab-app 与 knowmart-app 开工：建仓、实例化、跑通空应用

> **状态：所有者 2026-10-16 批准（「批准」），下面「要所有者先定的」四项按默认。现在做 A 段。** Opus 2026-10-16 在远程机写。设计：[0026 knowlab](../../../tree-build/SDD/modules/0026-knowlab.md)、[0018 knowmart](../../../tree-build/SDD/modules/0018-advisor-market.md)（私有模式）。本卡只做到「两个空应用在本地集群跑起来、能登录」，不写任何业务功能。
>
> 分四段，一段一停：A（Qwen 建远端仓）→ B（Opus 实例化并推代码）→ C（Opus 写部署声明、改各处仓清单）→ D（Qwen 在本地集群发布并在浏览器核对）。每段交回执，Opus 审过再开下一段。A、D 两段 Qwen 做；B、C 两段 Opus 做，这里写出来是让所有者一次看全。

## 要所有者先定的（批准时一起答）

| 项 | 默认 | 说明 |
| --- | --- | --- |
| 仓的可见性 | **公开**，与现有各仓一致（GitHub、gitee 上 tpl-app、knowfeed-*、k8s 等都是公开的） | 要私有就说一声，A 段按私有建 |
| gitee 镜像 | 8 个仓都建（同 knowfeed、knowbase 的父仓与子仓） | |
| 对外域名 | 先**不上公网边缘**，和 knowfeed、knowbase 一样只在所有者机器上可用：`knowlab.sunmoonai.com`、`knowlab-admin.sunmoonai.com`、`knowmart.sunmoonai.com`、`knowmart-admin.sunmoonai.com` | knowlab 要给外部用户用时，另开一张卡把它加到边缘 |
| knowmart 的界面叫法 | 「我的分身」，不出现「市场」「上架」「购买」「价格」（`C-L4`、`C-L5`） | 本卡只建空壳，叫法在后面的功能卡里落实 |

## A 段（Qwen，本地机）：建 8 个远端仓

在 GitHub 组织 `sunmoonlion` 与 gitee `sunmoonlion` 下各建 8 个**空仓**（不要勾选 README、.gitignore、LICENSE，否则 B 段推送会冲突）：

```text
knowlab-app   knowlab-backend   knowlab-web-frontend   knowlab-admin-frontend
knowmart-app  knowmart-backend  knowmart-web-frontend  knowmart-admin-frontend
```

用 R2 改名时那套权限（GitHub 组织管理员、gitee API 令牌）。**令牌不进回执、不进 git、不进日志。**

- 被测仓：无（只动远端）
- 跑：用 `gh repo create sunmoonlion/<名> --public`（可见性按上表）与 gitee API 逐个建；建完 `git ls-remote https://github.com/sunmoonlion/<名>.git`、`git ls-remote https://gitee.com/sunmoonlion/<名>.git` 逐个核：能连上、没有任何引用（空仓）
- 预计：15 分钟；要联网
- 看什么：16 个地址都存在且为空；任何一个已存在且非空就停，不覆盖
- 前提：所有者批准本卡
- 回传：`k8s/scripts/results/qwen-003-A.<时间>.md`（每个仓一行：平台、名字、可见性、`ls-remote` 是否为空）

## B 段（Opus，远程机）：实例化并推代码

1. 在临时目录各克隆一份 tpl-app（连子仓），按 `tpl-app/init.sh` 实例化成 `knowlab`、`knowmart`；先在临时目录跑通各后端测试与前端构建检查。
2. 推送：三个子仓先、父仓后，`master` 分支；推送地址 GitHub + gitee 两个（同 knowfeed 子仓）。
3. 两个应用的 `AGENTS.md`、`CLAUDE.md` 指向 k8s 的现行文档，README 写明定位（knowlab：用户的 idea 与数据做成分身；knowmart：分身的存放与「请」，私有模式）。
4. 回执 `k8s/scripts/results/opus-003-B.<时间>.md`。

## C 段（Opus，远程机）：部署声明与各处仓清单

1. `k8s/gitops/components/app-platform/knowlab-app/`、`knowmart-app/`：照 tpl-app 的组件（`database`、`migration`、`redis`、`rabbitmq`、`identity`、`runtime`、前后端），共用 `app-platform/common/`；`infrastructure/applications/sources.yaml` 加两个应用的钉；Casdoor 两套浏览器应用（管理端 `built-in`、网页端 `sunmoonai`）。
2. 渲染比对：除新增的两个应用，现有对象**一个都不变**（同改名 R5.1 的比对方法）。
3. 各处写死的仓清单加上两个新仓：同步脚本 `switch-test/human-local.sh`、`human-remote.sh` 的父仓与子仓列表，对齐工具 `docs/rename-tools/align_workstations.sh` 的 `REPOS`。两台机器上不在 Git 里的配置由所有者自己加：`~/five-repos-sync/config.sh` 的 `REPOS`，`toolboxes` 里 `model-switch/repos.conf`（`mb` 注册仓）。
4. 两台机器五个工位挂出两个新仓（`mb worktree add`，子仓初始化）。
5. 回执 `k8s/scripts/results/opus-003-C.<时间>.md`。

## D 段（Qwen，本地机）：发布与浏览器核对

照发布链（总览 §6）对 `APP=knowlab`、`APP=knowmart` 各做一遍：`platform-build` → `platform-stage` → `application-deployment-plan` → 提交 → `flux-release` → 晋级 → `flux-source-apply` → `application-check`。Windows hosts 加四个域名（UAC 由所有者点）。浏览器里：四个地址都能打开，网页端用 `sunmoonai` 账号、管理端用 admin 能登录（**登录由所有者自己输口令**，Qwen 只核截图）。`platform-status` 与六个 `application-check`（tpl、knowfeed、knowbase、investment、knowlab、knowmart）都是 0。具体命令 C 段审过后由 Opus 补进本卡。

- 回传：`k8s/scripts/results/qwen-003-D.<时间>.md`

## 不做的

业务功能（受理、工程化、测试、分身登记、「请」接口）、公网边缘、对外上架——都在后面的卡里。
