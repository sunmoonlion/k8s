# 工作台应用改名：investment → knowbench（0028）

> 状态：**名字已定，深度与数据去留待所有者定**。所有者 2026-10-17 提出改名（「investment其实不合适了，它实际上是测试平台和用户的bot的使用平台，不一定就是investment」），先考虑 incubator（「我选了incubator，你看如何」），最终定名（「就用knowbench」）。Opus 起草。做法照 0025：远程写代码、配置与逐条步骤，本地集群上的部分由 Qwen 跑。

## 一、为什么改、改成什么

`investment-app` 起家时只做投资工作台。现在它是：用户请来的分身在这里运行（0027 P4 第一部分）；knowlab 的分身测试也在这里跑（`knowbot-test-run/v1`）；本地代理、沙箱、预算、审批都是通用的，不绑投资。再叫 investment，读代码的人会以为它只管投资；对外也容易让人以为我们在做投资业务，和合规边界（投资逻辑与数据只来自用户）不一致。

| 现在 | 改成 | 管什么 | 域名（网页 / 管理端） |
| --- | --- | --- | --- |
| `investment-app` | **`knowbench-app`** | 工作台：运行用户的分身（自己请的、knowlab 测试中的），接本地代理与云端沙箱 | `knowbench.sunmoonai.com` / `knowbench-admin.sunmoonai.com` |

组件照现有规矩：`knowbench-backend`、`knowbench-web-frontend`、`knowbench-admin-frontend`。

**不改的**（是概念或历史，不是应用名）：

- 用户分身的内容，比如「中国 A 股上市公司财务分析与预测」专家包里的投资用语。
- 「工作台」这个词：页面上的「投资工作台」改成「工作台」，产品名显示为 knowbench。
- 历史回执、冻结原件、Git 历史。

**单列：文档目录 `k8s/docs/dev-investment-agent/`**。所有仓的 AGENTS.md、Qwen 的记忆、卡片都指向这个路径。改不改见第三节最后一段。

## 二、影响面（2026-10-17 盘点，文件数 / 出现次数）

| 类 | 例子 | 量 |
| --- | --- | --- |
| 仓 | gitee `sunmoonlion/investment-app`；五仓同步脚本 `config.sh` 的仓名表；两台机器上每个工位的检出目录（必须并列） | 1 仓 × 各工位 × 2 台 |
| 仓内 | `investment-backend/`（93 / 297）、`investment-web-frontend/`（36 / 104）、`investment-admin-frontend/`（27 / 84）、仓根说明（15 / 98） | 约 170 个文件 |
| k8s gitops 与部署机制 | `gitops/components/app-platform/investment-app/…` 整棵树（agent-releases、runtime、redis、rabbitmq、identity、database、migration、service-identity、test-computer）；`infrastructure/applications/` 的应用名表；`sources.yaml`；Makefile 里的 `agent-release-*` | gitops 67 / 630，infrastructure 22 / 89 |
| k8s 对象名 | `investment-api`、`investment-runner`、`investment-worker`、`investment-test-computer`、`investment-service-ca`、`investment-browser-identity` 等，由应用名派生 | 随应用名变 |
| 镜像 | Harbor 里 `investment-*` 镜像仓库 | 3 个 |
| 身份（Casdoor） | 应用 `sunmoonai-investment-web/admin`、客户端 `sunmoon-kind-investment-web/admin` 与回调地址；服务身份 `sunmoonai-investment-knowbase-retrieve`、`sunmoon-investment-knowmart-summon`、`sunmoon-knowlab-investment-testrun`；组织 `sunmoon-workload-investment-*`、`sunmoon-workload-knowlab-investment-testrun`；作用域 `investment:workbench`、`investment:testrun`、`investment:knowbase` 等 | 约 12 个 |
| **公网边缘** | `edge_domains` 里的 `investment.sunmoonai.com`；它的 Let's Encrypt 证书；新域名要所有者加 DNS 记录，`make edge-deploy` 要所有者批准 | 1 个域名 |
| **本地代理安装包** | runtime 的站点文件 `sites/edge-public.json`、`sites/dev-kind.json` 写着 `investment.sunmoonai.com`：Windows 安装包和 Linux 包都要按新域名重新出、重新钉摘要；已装好的 Windows 代理要重装、重新配对 | 2 个站点文件、2 个包 |
| 跨应用 | 各应用 `CROSS_APP_TARGETS` 的键 `investment`；knowlab / knowmart / knowbase / knowfeed / tpl 的说明与测试（knowlab 3 / 14、knowmart 4 / 14、knowbase 6 / 18、knowfeed 4 / 13、tpl 6 / 21）；tpl 的 `instance_sync_order` | 约 25 个文件 |
| 分身清单里的 `runtime` 值 | `knowbot-manifest/v1` 的 `runtime: investment`。清单带摘要，改值就是新版本：已在 knowmart 登记的分身要按新值重新发一版，旧版照删除规则保留 | 现有分身各一版 |
| **已存的数据** | 数据库 `investment` 与角色 `investment_runtime` / `investment_migrator`；Redis 用户与键前缀；RabbitMQ vhost；对象存储桶 `investment-agent-releases`（已发布的安装包）；私有目录 `/etc/sunmoon/applications/sunmoon-kind/investment`；SOPS 密文 15 份。**表名是 `workbench_*` / `agent_*`，不带应用名，不用改** | 见第四节 |
| 文档 | k8s `docs/` 120 / 1136，`scripts/` 112 / 1388（多为历史卡与回执，不改）；总览、PRD、SDD、各仓 AGENTS、`repos/investment-app.md` 要改 | 现行文档约 40 份 |

## 三、改多深（待所有者定）

| 方案 | 改什么 | 不改什么 | 代价 |
| --- | --- | --- | --- |
| 甲：外壳全改，存数据的名字不动 | 仓、目录、组件、k8s 对象、镜像、域名、Casdoor、跨应用键、清单 `runtime` 值、代码里的应用键与环境变量、文档 | 库名与角色、Redis、vhost、桶、私有目录：config 里照旧写 `investment…`，注明「存储名，沿用改名前」 | 不停服搬数据。缺点是存储层还看得到旧名，和 0025 的做法不一致 |
| **乙（建议）：连存数据的名字一起改** | 甲的全部，加上库、角色、Redis、vhost、桶、私有目录、SOPS 全部换新名 | 无 | 和 0025 一样一次到位。表名本来就不带应用名，所以库里不用改结构，比 0025 还省一步 |
| 丙：只改用户看得见的 | 域名、Casdoor 显示名、页面上的名字 | 其余全部 | 最省事，但代码和配置里还是 investment，以后对不上；不建议 |

**建议乙**，理由有两条。一是 0025 已经立了「改完存储层也不出现旧名」的规矩。二是 investment 的 P1b–P5 本来就攒着没部署，要在 P6 一次发布（0027 §八）：改名的代码在 P6 之前做完，P6 直接用新名字部署，就不用先按旧名发布一次、再切换一次。

**文档目录 `dev-investment-agent/`：建议这次不改。** 它是项目文档的路径，不是应用名，所有仓的入口、Qwen 的记忆和历史卡都指着它。要改就单独做一轮，只动路径和指针，不和应用改名搅在一起。

## 四、工作台现有数据（待所有者定）

现网工作台库里的东西有：会话与对话记录、项目、本地记忆与资料库条目、电脑配对（所有者那台 Windows 电脑）、沙箱与凭据、预算账、审批记录。桶里是已发布的 Windows 安装包。

| 做法 | 怎么做 | 代价 |
| --- | --- | --- |
| **不要，从空的开始（建议）** | 新名字用全新的库、角色、Redis、vhost、桶，私有目录全新生成，迁移链从头跑。旧的在新应用验收通过前原样保留作退路，通过后按清单删除，不备份 | 所有者要用新安装包重装 Windows 代理、重新配对；设置页的模型 key 重新填；以前的会话看不到了。安装包反正要因为域名换掉而重出，重装、重配对本来就免不了 |
| 要，搬过去 | 停服，`ALTER DATABASE … RENAME` 和角色改名，Redis 键改名，私有目录与 SOPS 按新名重做 | 停服搬迁，任何一步出错都要按备份恢复。搬过去的配对凭据也用不了，因为指向旧域名的代理还是要重装、重配对 |

建议不要，理由和 0025 一样：还在开发阶段，库里没有不能丢的东西。

## 五、怎么做（按乙 + 从空的开始写，所有者定了再细化成逐条手册）

分工同 0025。代码、配置、gitops、核对由远程（Opus）亲手写。gitee 改仓名、同步配置、DNS 记录、批准边缘部署由所有者做。本地集群上的部分由 Qwen 照远程写的步骤跑，远程逐段审回执。不经 Cursor。

| 步 | 谁 | 做什么 | 停点 |
| --- | --- | --- | --- |
| 0 | 所有者 | 通知各工位暂停碰 investment；Qwen 空闲 | — |
| 1 | 所有者 | gitee 把仓改名为 `knowbench-app`；`config.sh` 换仓名；两台机器上各工位的检出目录换名、改 remote | 远程核对各工位的 remote 与目录 |
| 2 | 远程 | knowbench 仓内：目录、构建、说明、代码里的应用键与环境变量、页面上的名字、契约锁文件；单测、构建全过 | 远程自测通过 |
| 3 | 远程 | 其它应用仓：跨应用键、knowlab 配置的 `runtime` 期望值、契约说明与测试；tpl 的同步清单；各仓自测通过 | 远程自测通过 |
| 4 | 远程 | runtime：两个站点文件换域名；Windows 与 Linux 包的配置留到第 7 步按新摘要钉 | 测试通过 |
| 5 | 远程 | k8s：gitops 目录、应用名表、存储名、Casdoor 声明、域名、服务身份与作用域、边缘 `edge_domains` 与路径放行；渲染比对（别的应用的渲染对象逐字不变，knowbench 除了名字逐项相同） | 渲染比对通过 |
| 6 | 所有者 | 加 DNS 记录 `knowbench.sunmoonai.com` → 边缘机；批准 `make edge-deploy`（只多一个域名，旧域名在第 9 步前保留） | 远程用 `--resolve` 核对证书与放行 |
| 7 | Qwen（本地） | 并进 P6：打新的 Windows 与 Linux 包、核摘要、上传到新桶；按新名字构建、发布、部署（新库、新 Casdoor 应用与服务身份、新私有目录）；其余照 0027 P6 | 远程审回执 |
| 8 | 所有者 + Qwen | 所有者用新安装包重装 Windows 代理、在 `knowbench.sunmoonai.com` 登录并配对；P6 的浏览器走查改用新域名 | 截图与回执 |
| 9 | Qwen（本地） | 下线旧的：旧 Deployment / Job / Secret、旧 Casdoor 应用与服务身份、旧库与角色、旧 Redis 与 vhost、旧桶、旧私有目录、边缘上的旧域名（要所有者批准）、Harbor 旧镜像仓库 | 远程审回执 |
| 10 | 远程 | 文档：总览、PRD、SDD、各仓 AGENTS、`repos/investment-app.md` 改为 `repos/knowbench-app.md` | — |

**时机**：0027 P5（运行时读数据）要新加一条 knowlab → 工作台的服务关系。改名放在 P5 之前，新关系直接用 knowbench 的名字，不用建了再改。所以顺序是：本方案第 1–5 步 → P5 → 第 6–9 步并进 P6。

**回退**：第 6 步之前现网什么都没碰。第 7、8 步失败：新名字停到 0 副本；旧 investment 还在原样运行，旧域名没下线，旧代理照常能用。第 9 步做完才不可逆，所以第 9 步只在第 8 步走查通过以后做。
