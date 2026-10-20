# k8s：部署与项目文档

> 最后更新：2026-10-16 ｜ 按 `k8s/sunmoonai/` 移出后的现状重写 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

宿主、Harbor、入口、Jenkins、建群、Flux 与全部平台组件、应用的部署声明都在这里；项目的设计、规则、派活卡与本目录也在这里。没有应用业务源码，只有三个自研组件镜像（会合点、沙箱、供给器）的源码。**地图位置**：按 [架构总纲](../../总纲/架构总纲.md)，本仓装着第 1 层物料、第 3 层宿主、第 4 层集群、第 5 层平台的全部，第 6 层应用的部署声明，和横切 A、B、C 的实现；下面两张表按层分组。逐文件的代码事实在 [平台代码地图](../../dev-investment-agent/tree-build/平台代码地图.md)。

## 结构

```text
k8s/
├── README.md、AGENTS.md          运维入口；代码与开发规则入口
├── Makefile → infrastructure/    公开入口（make -C infrastructure help）
├── infrastructure/               Make + Ansible：宿主到应用的实施入口
├── gitops/                       Flux 拥有的集群声明
├── docs/                         设计、规则、派活卡、本目录、平台文档、参考资料
├── scripts/                      回执 results/、本地联调 local-integration/、同步脚本的回归测试
├── CHECKPOINT.md                 开发期续接记录
└── 密码修改表.md                 所有者保留的开发密码查阅表（不是部署真源，不进对话与日志）
```

## infrastructure/（站点内、集群外的一切，加交付链与物料）

| 层 | 目录 | 管什么 |
| --- | --- | --- |
| 宿主层 | `host/` | WSL 宿主：数据盘与挂载、容量、开机恢复、维护账号；还装着整个平台的对象选择（`deployment.yaml`，B 段第 5 步挪出） |
| 宿主层 | `registry/` | 宿主上的 Harbor（集群外独立持久化）；平台 CA 在这里 |
| 宿主层 | `entry/` | 入口 HAProxy（`30443`，只看 SNI 分流，不持私钥）；没登记的域名默认仍转到原来的旧 kind 集群——旧集群受保护，新流程不接管它 |
| 宿主层 | `jenkins/` | 宿主上的 Jenkins 控制器（交付链的 CI，2026-10-20 起，[0033](../../dev-investment-agent/tree-build/SDD/modules/0033-jenkins-on-host.md)） |
| 宿主层（边缘机） | `edge/` | 公网边缘（只在东京云 VM 上跑：Traefik + frps） |
| 集群层 | `cluster/` | KIND 建群（三节点，节点挂载在数据盘）；生产集群的建法将是旁边的另一个模块 |
| 交付链 | `flux/` | Flux 安装、发布 OCI 候选、晋级与退回（D 段变 `argocd/`） |
| 交付链 | `components/` | 通用渲染器与组件阶段图：每个含 `stage.yaml` 的组件目录是一个可部署对象（`OBJECT`） |
| 交付链 | `services/` | 平台组件这一侧剩下的：共享口令初始化、chart 发布、平台真实检查（D 段并入 `components/` 后消失） |
| 交付链 | `applications/` | 应用构建与部署计划：`sources.yaml` 钉各应用父仓与子仓的提交；`component-images.yaml` 与 `component-images/`（会合点、沙箱、供给器源码）（B 段第 5 步改名 `build/`） |
| 物料层 | `artifacts/`、`tools/` | 物料与镜像锁、下载与发布器；工具链安装（D 段合成 `materials/`） |
| 横切 C | `environments/` | 站点参数（`kind/site.yaml`）、已晋级源（`flux-source.yaml`）、SOPS 公钥 |

## gitops/（平台层与应用层的集群内声明）

| 层 | 目录 | 装什么 | 命名空间 |
| --- | --- | --- | --- |
| 应用层 | `components/app-platform/` | `auth-app/casdoor`；六个应用 `tpl-app`、`knowfeed-app`、`knowbase-app`、`knowbench-app`、`knowlab-app`、`knowmart-app`（每个应用下分前后端组件，后端下有 database、migration、redis、rabbitmq、identity、runtime 等阶段）；`common/`（应用共用的部署机制） | `app-platform-dev` |
| 平台层 | `components/data-platform/` | PostgreSQL、Redis / Valkey、对象存储、RAGFlow（含 Infinity、text-embeddings）、ELK、Neo4j、MongoDB | `data-platform-dev` |
| 平台层 | `components/messaging-platform/` | RabbitMQ | `messaging-platform-dev` |
| 平台层 | `components/ingress-platform/` | 内网 Traefik（TLS 终止、按 Host 路由，不做授权）、frpc | `ingress-platform-dev` |
| 平台层 | `components/ops-platform/` | pgAdmin、RedisInsight、Flower、Mongo Express | `ops-platform-dev` |
| 平台层 | `components/relay-platform/`、`sandbox-platform/` | 会合点；供给器与沙箱镜像锁 | `relay-platform-dev`、`sandbox-platform-dev` |
| 平台层 | `components/foundations/` | 跨命名空间的基础对象（网络策略、拉取凭据、存储）；基础引导与发布标记在 `platform-system`，它不是业务运行的命名空间。`core/` 是旧残留，无人引用 | — |
| 集群根 | `clusters/kind/` | 阶段图 `stages.yaml`（由各组件 `stage.yaml` 汇总生成）；Flux 源与根 Kustomization 由 `infrastructure/flux/` 写入 | — |

每个组件目录里 `config.yaml`、`stage.yaml`、`README.md` 是真源；`workload.yaml`、`kustomization.yaml`、`*.sops.yaml`、`image.lock.yaml` 是渲染产物，**不手改**。所有应用统一用 `app_namespace`；目录归属不等于运行命名空间。

## docs/

| 目录 / 文件 | 内容 |
| --- | --- |
| [`dev-investment-agent/`](../../dev-investment-agent/pipeline.md) | 流水线、`turn/`（通用开发规范）、`tree-build/`（需求、设计、规则、决策）、`switch-test/`（派活卡与两台机器同步）、`tools/`（文档门禁） |
| [`project-guide/`](../README.md) | 本目录：项目现在是什么样 |
| [`reference/`](../../reference/) | 通用参考资料（行业、采集与数据、技术笔记、运维笔记） |
| `README.md`、`总纲/运行拓扑.md` | 维护导航；拓扑与发布路径 |
| （已删）改名手册、回执与工具 | 2026-10-16 删除，按 Git 历史 `3951246c` 取；遗留事项已移进待办账 97–101，对齐工具移到 `dev-investment-agent/switch-test/align_workstations.sh` |

## 门禁与钩子

`.githooks/`（`git config core.hooksPath .githooks`，全部工位共享）：提交时跑 `doc-gate.py --staged` 与 `anchor-gate.py`，范围是 `docs/dev-investment-agent/` 与 `docs/project-guide/`；缺脚本即判失败。

## 已不在本仓的

平台第一次重构时写的 `docs/platform/`（架构、验收记录、组件账号维护）2026-10-16 并入别处后删除：规矩进 `constraints.md`「发布」`C-R13`–`C-R19` 与 `C-I10`，还没做的进待办账 104–109，原文 Git 历史 `53767f6a`。

旧体系（`sunmoonai/` 下的旧部署、仓根 `utils/`、`legacy/`、`./sunmoon` 命令行）2026-10-16 删除，要看按 Git 历史取（最后包含它们的提交 `9a2abf12`）。`.gitignore` 里旧目录的条目保留，防止两台机器上残留的被忽略文件变成未跟踪。
