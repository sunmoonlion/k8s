# k8s

> 仓库 `sunmoonlion/k8s`。
> 最后更新：2026-08-14 ｜ 深读时间：2026-08-14（`sunmoonai/` 各平台部署编排、三个领域
> App 的部署 bundle）。App 之间的公共形态见 `baseline/app-platform/inter-apps/app-platform.md`。

## 1. 概要

sunmoonai 平台的**部署编排与治理仓**，不含任何 App 源码：KIND 集群上各平台的部署清单与
运维脚本 + 领域 App 的声明式部署 bundle、发布输入与验收门禁。源码在 `sunmoonlion/tpl-app`、
`info-app`、`knowledge-app`、`investment-app` 四个独立仓维护。

### 顶层结构（`sunmoonai/` 八平台 + 一个编排入口）

| 目录 | 内容 |
| --- | --- |
| `app-platform/` | 全部领域 App 的部署声明：auth-app（Casdoor，不套三仓模板）、info-app、knowledge-app、investment-app；`scripts/`（build-push-app-images.sh、verify-formal-instance.py bundle 静态门禁、formal_deploy_entry.py/formal_component_deploy.py 正式部署入口、各 App render_*_release_base.py）；`docs/`（平台文档与历史记录） |
| `cicd-platform/` | harbor、jenkins |
| `data-platform/` | postgresql、redis、elasticsearch、object-storage（MinIO AIStor）、mongodb、neo4j、kibana、logstash |
| `infrastructure/` | 集群基础设施步骤脚本：kubeadm、CNI 安装、namespace 等（`steps/`） |
| `ingress-platform/` | traefik（严格 TLS、高优先级 /api 路由） |
| `messaging-platform/` | rabbitmq |
| `kind-infrastructure/` | KIND 集群配置（长期 kindnet；一次性 Calico 集群用于报文级 NetworkPolicy 验证） |
| `ops-platform/`、`deploy-sunmoonai-all` | 运维与一键部署入口 |

`sunmoonai/` 下另有与九平台并列的 `docs/`（含本文档集）与 `utils/`；`app-platform/` 下另有
`deploy-app-platform-all/`（App Platform 整体编排）与 `utils/`。

### 运行与验证

每 App `deployment/bundle/` 五件套 YAML 按固定顺序部署；bundle 静态门禁
`app-platform/scripts/verify-formal-instance.py`（运行时门禁是另一套脚本，见 §3.3）；
正式部署入口 `formal_deploy_entry.py`。
本仓 `sunmoonai/docs/sunmoonai-architecture/` 即本文档集（AGENTS.md / baseline/ /
requests/）的所在目录。

## 2. 重要点

1. **不含源码**：本仓只有部署声明与运维脚本；四个 App 源码各自独立仓维护。
2. **五件套 + 固定部署顺序**：prerequisites → network-policies → migration → runtime →
   ingress（顺序由 `deploy.py` 的 `apply()` 定义，网络策略先于迁移落地）；
   **迁移失败不得继续部署运行角色**。
3. **release.json schema 2 只收 digest**：三镜像只收 `repository@sha256`，禁重构建打 tag、
   禁可变 tag；每文件 sha256 钉住。
4. **证据分层 L1-L7**：L1 静态 → L2 单元 → L3 契约 → L4 角色/DB 集成 → L5 配对 →
   L6 KIND/严格 TLS/真实 Casdoor/回滚 → L7 跨 App E2E；**smoke 通过不得宣称完成**。
5. **Calico 门禁诚实标记**：长期 kindnet 不执行 NetworkPolicy，不得伪报；一次性 Calico
   集群做报文级验证后删除，长期集群保留
   `production_network_policy_gate_satisfied=false`。
6. **数据库双角色**：`{app}_backend_user`（DML 无 DDL）+ `{app}_backend_user_migration`
   （唯一 DDL/owner）。
7. **auth-app 不套模板**：Casdoor 单独部署，提供 OIDC 但不替代各 Backend 的资源级授权。
8. **双远程纪律**：GitHub 权威、Gitee 镜像 SHA 对齐。

## 3. 架构

### 3.1 领域 App 部署 bundle 结构（每 App 一份，在 `{app}/deployment/` 下）

五件套 YAML 在 `deployment/bundle/`：`00-prerequisites.yaml`（ServiceAccount、ConfigMap、Service）、
`10-migration.yaml`（一次性 Job）、`20-runtime.yaml`（API/Worker/Scheduler + HPA/PDB）、
`30-network-policies.yaml`（默认拒绝 + 放行规则）、`40-ingress.yaml`（严格 TLS、`/api` 高优先级
+ `/` 低优先级双路由）；加 `bundle/release.json`、`deployment/render.py`、`deployment/deploy.py`。
资源名为稳定命名（如 `info-backend-api`，无阶段/过渡后缀）。
bundle 静态门禁：`app-platform/scripts/verify-formal-instance.py`（见 §3.3）。

部署顺序固定为 `00-prerequisites` → `30-network-policies` → `10-migration` → `20-runtime` →
`40-ingress`，权威定义在各 App `deployment/deploy.py` 的 `apply()`；迁移失败抛 `DeployError`，
不得继续部署运行角色（该阻断由 `deploy.py` 的 `run_migration` 实现，不是门禁脚本）。

平台职责与依赖方向的权威定义见总体架构文档（`../../../sunmoonai/architecture.md`）；
本仓实现遵循同一原则：基础能力向上提供、领域所有权不向下泄漏，部署顺序≠运行时耦合。

### 3.2 发布输入与版本语义

每 App 发布输入 `deployment/bundle/release.json`（schema_version 2、architecture
`app-platform-v2-formal`）：logical_app/resource_app、namespace、release_id、formal_release、
三镜像 digest（只收 `repository@sha256`）、每文件 sha256。release_id 无统一构词规则，
以各 App `release.json` 为准（info/knowledge 为 `v20-{app}-stable-001`，investment 为
`v20-investment-001`）。Knowledge 与 Investment 另有 App 特有字段
（`retrieval_dataset_allowlist`、`knowledge_binding`）。

流程：源码仓构建不可变镜像 digest → 写入 release.json → 脚手架 render/deploy
（模板仓 `tpl-app/k8s-deployment`）→ 门禁通过后正式发布。三个领域 App 均为正式发布
2.0.0（formal_release=true）。禁止为正式版本重新构建再打 tag、禁止用可变 tag 替代 digest。

### 3.3 验收门禁与证据分层

**证据分层 L1-L7**：L1 静态 → L2 单元 → L3 契约 → L4 角色/DB 集成 → L5 配对 →
L6 KIND/严格 TLS/真实 Casdoor/回滚 → L7 跨 App E2E。smoke 通过不得宣称完成。

门禁分两类，脚本不同，不可混谈：

| 类别 | 检查项 | 执行者 | 是否需 live 集群 |
| --- | --- | --- | --- |
| **bundle 静态门禁** | release.json schema、镜像 digest 形态、每文件 sha256、Deployment 副本数与镜像、IngressRoute/TLS、forbidden_markers | `app-platform/scripts/verify-formal-instance.py` | 否 |
| **运行时门禁** | 隔离 KIND namespace、数据库角色 principal、HPA + PDB + NetworkPolicy 实效、严格 TLS 双端真实 Casdoor 验证、原生 `rollout undo` 回滚再前滚 | `docs/architecture-v2/scripts/verify_r5_*`、`verify_r3_*` 等另一套脚本 | 是 |

双远端 GitHub 权威、Gitee 镜像 SHA 对齐属发布纪律，不由上述任一脚本强制。

**Calico 门禁**：长期 KIND 用 kindnet（不执行 NetworkPolicy），不得伪报运行态通过；用一次性
`disableDefaultCNI:true` KIND + Calico 做报文级矩阵验证，验证后删除集群；验收证据中诚实标记
`production_network_policy_gate_satisfied=false`（该标记出现在证据 JSON 与 gate 脚本输出中，
不是长期集群配置文件里的持久字段——`kind-infrastructure/deploy-kind/kind-cluster.yaml` 无此键）。

### 3.4 数据库角色模型

每 App 两个运行凭据：`{app}_backend_user`（DML 无 DDL）+ `{app}_backend_user_migration`
（唯一 DDL/owner）。数据所有权与迁移链规则见总体架构文档 §7
（`../../../sunmoonai/architecture.md`）。

### 3.5 边界与衔接

- auth-app（Casdoor）是身份提供方，不套三仓模板，单独部署；它提供 OIDC 但不替代各 Backend
  的资源级授权。
- 未来 research-app/tools-app 必须从已验收模板全新实例化，不从历史目录复制。
- 当前集群为 KIND 开发环境（namespace `app-platform-dev`），生产 NetworkPolicy 门禁由一次性
  Calico 集群单独闭合。
- `formal_deploy_entry.py` 禁止默认入口执行 uninstall/cleanup。
- production profile 显式禁用，仅 KIND profile 启用。
- Investment 在 migration 前额外做一步 DB 侧 formal 角色切换
  （`investment-app/deployment/deploy.py` 的 `set_formal_database_roles`），info/knowledge 无此逻辑。
- 数据库双角色的 DDL 定义在 R5 provision 脚本中，不在 bundle YAML；bundle 只引用两套 Secret。

## 4. 关联

- 九大平台之间的职责与依赖：`../../../sunmoonai/architecture.md`
- App 之间的公共形态与契约治理：`../../inter-apps/app-platform.md`
- 各 App 源码内部架构：`../tpl-app/tpl-app.md`、`../info-app/info-app.md`、
  `../knowledge-app/knowledge-app.md`、`../investment-app/investment-app.md`
- 平台部署文档与历史记录：本仓 `sunmoonai/app-platform/docs/`
