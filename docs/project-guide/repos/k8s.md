# k8s：部署与项目文档

> 最后更新：2026-10-16 ｜ 按 `k8s/sunmoonai/` 移出后的现状重写 ｜ 总览见 [`../overall-architecture.md`](../overall-architecture.md)

宿主、Harbor、入口、建群、Flux 与全部平台组件、应用的部署声明都在这里；项目的设计、规则、派活卡与本目录也在这里。没有应用业务源码，只有三个自研组件镜像（会合点、沙箱、供给器）的源码。

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

## infrastructure/

| 目录 | 管什么 |
| --- | --- |
| `host/` | WSL 宿主：数据盘与挂载、容量、开机恢复、维护账号；`wsl_interop.py` 源码 |
| `registry/` | 宿主上的 Harbor（集群外独立持久化） |
| `entry/` | 入口 HAProxy（`30443`，只看 SNI 分流，不持私钥）；没登记的域名默认仍转到原来的旧 kind 集群——旧集群受保护，新流程不接管它 |
| `cluster/` | KIND 建群（三节点，节点挂载在数据盘） |
| `flux/` | Flux 安装、发布 OCI 候选、晋级与退回 |
| `services/` | 平台组件的部署与维护编排（Make → Ansible → Flux / SOPS）；组件参数与模板在各组件目录 |
| `applications/` | 应用构建与部署：`sources.yaml` 钉各应用父仓与子仓的提交；`component-images.yaml` 与 `component-images/`（会合点 `relay/`、沙箱与供给器 `sandbox-platform/` 的源码） |
| `components/` | 组件阶段图：每个含 `stage.yaml` 的组件目录是一个可部署对象（`OBJECT`），由此汇总集群阶段声明 |
| `artifacts/`、`environments/` | 物料与上游镜像锁；环境（`kind/site.yaml` 的命名空间、根路径，`flux-source.yaml` 的已晋级源） |
| `edge/` | 公网边缘（只在东京云 VM 上跑：Traefik + frps） |
| `tools/` | 工具链安装（Flux、kubectl、mc、age 等） |

## gitops/

| 目录 | 装什么 | 命名空间 |
| --- | --- | --- |
| `components/app-platform/` | `auth-app/casdoor`；`tpl-app`、`knowfeed-app`、`knowbase-app`、`investment-app`（每个应用下分前后端组件，后端下有 database、migration、redis、rabbitmq、identity、runtime 等阶段）；`common/`（应用共用的部署机制） | `app-platform-dev` |
| `components/data-platform/` | PostgreSQL、Redis / Valkey、对象存储、RAGFlow（含 Infinity、text-embeddings）、ELK、Neo4j、MongoDB | `data-platform-dev` |
| `components/messaging-platform/` | RabbitMQ | `messaging-platform-dev` |
| `components/ingress-platform/` | 内网 Traefik（TLS 终止、按 Host 路由，不做授权）、frpc | `ingress-platform-dev` |
| `components/ops-platform/` | pgAdmin、RedisInsight、Flower、Mongo Express | `ops-platform-dev` |
| `components/relay-platform/`、`sandbox-platform/` | 会合点；供给器与沙箱镜像锁 | `relay-platform-dev`、`sandbox-platform-dev` |
| `components/foundations/`、`core/` | 跨命名空间的基础对象（网络策略、拉取凭据、存储）与核心；基础引导与发布标记在 `platform-system`，它不是业务运行的命名空间 | — |
| `clusters/kind/` | 集群根：阶段图 `stages.yaml`（由各组件 `stage.yaml` 汇总生成） | — |

每个组件目录里 `config.yaml`、`stage.yaml`、`README.md` 是真源；`workload.yaml`、`kustomization.yaml`、`*.sops.yaml`、`image.lock.yaml` 是渲染产物，**不手改**。所有应用统一用 `app_namespace`；目录归属不等于运行命名空间。

## docs/

| 目录 / 文件 | 内容 |
| --- | --- |
| [`dev-investment-agent/`](../../dev-investment-agent/pipeline.md) | 流水线、`turn/`（通用开发规范）、`tree-build/`（需求、设计、规则、决策）、`switch-test/`（派活卡与两台机器同步）、`tools/`（文档门禁） |
| [`project-guide/`](../README.md) | 本目录：项目现在是什么样 |
| [`reference/`](../../reference/) | 通用参考资料（行业、采集与数据、技术笔记、运维笔记） |
| `README.md`、`发布链.md`、`拓扑.md` | 维护导航、发布路径、拓扑 |
| （已删）改名手册、回执与工具 | 2026-10-16 删除，按 Git 历史 `3951246c` 取；遗留事项已移进待办账 97–101，对齐工具移到 `dev-investment-agent/switch-test/align_workstations.sh` |

## 门禁与钩子

`.githooks/`（`git config core.hooksPath .githooks`，全部工位共享）：提交时跑 `doc-gate.py --staged` 与 `anchor-gate.py`，范围是 `docs/dev-investment-agent/` 与 `docs/project-guide/`；缺脚本即判失败。

## 已不在本仓的

平台第一次重构时写的 `docs/platform/`（架构、验收记录、组件账号维护）2026-10-16 并入别处后删除：规矩进 `constraints.md`「发布」`C-R13`–`C-R19` 与 `C-I10`，还没做的进待办账 104–109，原文 Git 历史 `53767f6a`。

旧体系（`sunmoonai/` 下的旧部署、仓根 `utils/`、`legacy/`、`./sunmoon` 命令行）2026-10-16 删除，要看按 Git 历史取（最后包含它们的提交 `9a2abf12`）。`.gitignore` 里旧目录的条目保留，防止两台机器上残留的被忽略文件变成未跟踪。
